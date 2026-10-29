# Technologiestack

> **Stand Oktober 2026:** Alle Apps laufen als Pods oder KubeVirt-VMs im Kubernetes-Cluster und werden über eine `appstore.yaml` beschrieben (Vertrag und Beispiele: [app-registry](https://github.com/DHBW-AppStore-T3/app-registry)). Den früheren OpenStack-VM-Pfad mit Packer, Terraform und OpenStack-Credentials gibt es nicht mehr ([#12](https://github.com/DHBW-AppStore-T3/.github/issues/12)).

## 1. Frontend: React

**Beschreibung:** Das Frontend ist eine Single Page Application mit React 19, TypeScript und Vite. Zustand (Bibliothek `zustand`) verwaltet den globalen Anwendungszustand, React Router 7 das Routing, Axios die Kommunikation mit dem Backend. Das Styling erfolgt utility-first mit Tailwind CSS. Ausgeliefert wird die App von nginx, der zugleich als API-Gateway zum Backend dient. Die TypeScript-Typen der API werden aus dem OpenAPI-Schema des Backends generiert (`npm run gen:api-types`).

**Begründung:** Die Architektur trennt Oberfläche, Logik und Routing: pro View gibt es reine, getestete Logikmodule, Hooks und kleine Komponenten. TypeScript fängt viele Fehler schon zur Entwicklungszeit ab, die generierten API-Typen sorgen dafür, dass eine Änderung im Backend sofort im Typecheck auffällt. Tailwind CSS erlaubt schnelle UI-Entwicklung ohne die Wartungslast eigener CSS-Dateien. Das Frontend wurde im Oktober 2026 von Vue 3 nach React migriert (Entscheidung: `frontend/claude_docs/decisions/2026-react-migration.md`).

---

## 2. Backend: FastAPI (Python)

**Beschreibung:** Das Backend fungiert als asynchrone REST-API, basierend auf FastAPI und Python 3.11+. Als Webserver dient Uvicorn, ein High-Performance ASGI-Server. Die Datenhaltung erfolgt in einer PostgreSQL-Datenbank, die über SQLAlchemy 2.0 (ORM) angesprochen wird.

**Begründung:** Der Fokus liegt auf Performance und modernen Standards. Pydantic validiert alle Dateneingänge rigoros und generiert automatisch die OpenAPI-Dokumentation (Swagger UI), was die Integration für Frontend-Entwickler erleichtert. PostgreSQL wurde aufgrund seiner Stabilität (ACID-Compliance) und der Unterstützung für JSONB-Datentypen gewählt, was Flexibilität bei semi-strukturierten Daten erlaubt. Die Entscheidung fiel bewusst gegen klassische Frameworks wie Django oder Flask. FastAPI ist durch die native Unterstützung von asynchroner Programmierung (Async/Await) und die Nutzung von Starlette deutlich performanter. Zudem bietet SQLAlchemy 2.0 im Gegensatz zu simpleren ORMs die Flexibilität, nahtlos zwischen objektorientiertem Zugriff und Raw SQL zu wechseln.

---

## 3. Worker: asynchrone Verarbeitung über eine Postgres-Queue

**Beschreibung:** Langlaufende Aufgaben (Deployments anlegen, pausieren, fortsetzen, zerstören) führt der Worker aus, im Cluster die Komponente `pod-deployer`. Die Job-Queue liegt in derselben PostgreSQL-Datenbank wie die Anwendungsdaten (Tabelle `tasks`, Transport `pgq`, `FOR UPDATE SKIP LOCKED`, Benachrichtigung per `NOTIFY`). Der Worker rendert aus der `appstore.yaml` die Kubernetes-Objekte (bzw. die KubeVirt-VM), wendet sie im Namespace `dep-<8 hex>` an, wartet auf Bereitschaft und schreibt Fortschritt und Logs als Events in die Tabelle `task_events`. Das Backend streamt diese Events per Server-Sent-Events an das Frontend. Ergebnisse (z. B. generierte Passwörter) werden verschlüsselt (Fernet) in der Task-Zeile abgelegt.

**Begründung:** Die Entkopplung hält die UI reaktionsfähig: Die API nimmt den Auftrag sofort an, der Worker arbeitet im Hintergrund. Die frühere Kombination aus Celery, RabbitMQ und Redis kostete drei zustandsbehaftete Dienste und hatte belegte Fehler (mehrfach verarbeitete Events, nur prozesslokaler Live-Status, doppelt zugestellte lange Jobs, Ergebnisse im Klartext in Redis). Mit der Queue in PostgreSQL gibt es nur noch eine Wahrheit: Task-Zeile und Events entstehen transaktional mit dem Auftrag, ein toter Worker wird über eine Lease erkannt (Task endet als `worker_lost`, ohne zweiten Lauf), und ein Abbruch läuft über die Datenbank. Entscheidung und Messungen: `deployment/claude_docs/decisions/2026-postgres-queue.md`.

---

## 4. Deployment & Containerisierung: Docker, Kubernetes, Helm, Argo CD

**Beschreibung:** Alle Komponenten sind Container-Images in der GitHub Container Registry (`ghcr.io/dhbw-appstore-t3/…`). Betrieben werden sie auf einem k3s-Cluster im OpenStack-Projekt `ma_wwi_24sea_appstore_g3`. Ein Helm-Chart (`k8s/charts/appstore` im `deployment`-Repo) beschreibt je Umgebung `api`, `pod-deployer`, `frontend`, `self-service-ui`, einen Migrations-Job und einen stündlichen Orphan-Check; hinzu kommen `appstore-mcp` und `moodle`. Argo CD synchronisiert den Cluster aus dem Repository. Staging entspricht dem Branch `dev` (Namespace `appstore-staging`), Produktion dem Branch `main` (`appstore-prod`).

Die Plattform-Dienste sind:

| Komponente | Aufgabe |
|---|---|
| **PostgreSQL (CloudNativePG)** | Datenbanken `appstore_t3` (Anwendungsdaten, Job-Queue, Task-Events), `keycloak`, `moodle` |
| **Keycloak** | Identity Provider (Realms `dhbw`, `appstore`); OIDC-Anmeldung für Frontend und Backend |
| **Backend (`api`)** | REST-API; prüft Tokens gegen Keycloak, persistiert Daten, legt Jobs in die Queue, streamt Events per SSE, liest den Cluster-Status lesend |
| **Worker (`pod-deployer`)** | Führt die Jobs der Queue `pods` aus; rendert und wendet die Objekte der Apps an. Läuft ohne Root, mit eigener ServiceAccount-Rolle und Admission-Policy |
| **Frontend** | React-SPA, ausgeliefert von nginx, zugleich API-Gateway |
| **Traefik, cert-manager** | Ingress und Wildcard-Zertifikat `*.<zone>` für App-Hosts |
| **ClamAV** (optional) | Virenscan hochgeladener Dateien |
| **KubeVirt, noVNC-Proxy** | Windows-Desktop-Apps als VM im Cluster, Bedienung im Browser |

**Deploymentprozess:** Ein Push auf `dev` (oder `main`) in einem Service-Repository löst dessen CI aus (Lint, Tests, Image-Build, Trivy-Scan, Push). Danach startet `k8s-bump.yml` im `deployment`-Repo und trägt den neuen Image-Digest in `k8s/images/<umgebung>.yaml` ein. Argo CD rollt den Digest aus. Änderungen an Chart, Policies oder Realm gehen als PR auf `dev` (Staging) und werden mit `k8s/promote.sh` nach `main` (Produktion) befördert. Rollback eines Images heißt: Digest in der Datei zurücksetzen. Datenbankmigrationen laufen als Hook-Job (`migrate`) des Charts.

**Lokal:** Der gleiche Stack läuft in einem `k3d`-Cluster mit denselben Helm-Charts (`deployment/docs/dev-setup.md`, `make init`).

**Begründung:** Apps beliebiger Studierender brauchen Isolation, Ressourcengrenzen und schnelle Bereitstellung. Pods starten in Sekunden, verbrauchen weniger als VMs und lassen sich pro Namespace mit NetworkPolicy, ResourceQuota und Pod Security `restricted` absichern. Die Plattform rendert alle Kubernetes-Objekte selbst, App-Autoren liefern keinen ausführbaren Infrastruktur-Code mehr (siehe Abschnitt 5). Argo CD macht den Cluster-Zustand zu einem Git-Zustand: Änderungen sind nachvollziehbar, Rollbacks sind Commits. Die Entscheidung ist in `deployment/claude_docs/decisions/2026-appstore-on-kubernetes.md` und `2026-pods-instead-of-vms.md` dokumentiert.

---

## 5. App-Beschreibung statt Infrastructure as Code: `appstore.yaml`

**Beschreibung:** Früher lieferten App-Autoren Terraform- und Packer-Code, den der Worker mit den OpenStack-Zugangsdaten der deployenden Person ausführte. Heute beschreibt jede App eine kleine, deklarative Datei `appstore.yaml` (Schema `appstore/v2`, `backend/app/k8s/spec.py`): Laufzeit (`kubernetes` oder `kubevirt-vm`), Container-Image (nur per Digest aus der erlaubten Registry), Port, Ressourcen innerhalb der Plattform-Grenzen, Speicher, Variablen und Zugang. Sicherheitsrelevante Felder (securityContext, Netzwerk-Policy, RBAC) lassen sich nicht setzen. Die Freigabe durch einen Admin bindet Commit, Spec-Hash und Image-Digests aneinander.

**Begründung:** Fremder Infrastruktur-Code im Worker war ein Sicherheitsproblem, außerdem eine Lizenzfrage (BSL bei Terraform/Packer), langsam (Packer-Builds) und betriebsintensiv (State, Locks, Credentials). Mit der Spec entfallen OpenStack-Credentials, Terraform-State und Image-Builds im AppStore vollständig. Wer ein eigenes Image braucht, baut es in der eigenen CI und gibt den Digest an. Für Windows-Desktops gibt es die Laufzeit `kubevirt-vm`: ein vorbereitetes Golden Image wird im Cluster geklont.
