# Technologiestack

> **Hinweis (Oktober 2026, [#12](https://github.com/DHBW-AppStore-T3/.github/issues/12)):** Dieses Dokument beschreibt teilweise den früheren Ablauf, bei dem Apps als OpenStack-VMs ausgerollt wurden (Packer, Terraform, OpenStack-Credentials, Quotas, Infrastructure-Ansicht). Alle Apps laufen inzwischen als **Pods** im Kubernetes-Cluster und werden über eine `appstore.yaml` beschrieben (Vertrag und Beispiele: [app-registry](https://github.com/DHBW-AppStore-T3/app-registry)). Die Windows-App folgt über KubeVirt. Aussagen zu den genannten VM-Themen sind überholt; das Dokument wird bei Gelegenheit überarbeitet.

## 1. Frontend: Vue.js

**Beschreibung:** Das Frontend wird als Single Page Application (SPA) mit Vue.js 3 realisiert. Für das State Management (die Verwaltung des globalen Anwendungszustands) kommt Pinia zum Einsatz, während Axios die Kommunikation mit dem Backend übernimmt. Das Styling erfolgt utility-first mittels Tailwind CSS.

**Begründung:** Die Architektur setzt auf eine strikte Trennung von Benutzeroberfläche (UI), Geschäftslogik und Routing. Der Einsatz von TypeScript sorgt hierbei für Typsicherheit, wodurch viele Fehler bereits zur Entwicklungszeit und nicht erst zur Laufzeit abgefangen werden. Tailwind CSS ermöglicht eine schnelle UI-Entwicklung ohne die Wartungslast komplexer, selbstgeschriebener CSS-Dateien. Vue.js wurde gewählt, da es als leichtgewichtig und performant gilt und sich perfekt für Frontends dieser Skalierung eignet. Im Vergleich zu oft schwergewichtigeren Enterprise-Lösungen (wie Angular) bietet es eine geringere Einstiegshürde bei gleicher Leistungsfähigkeit für diesen Anwendungsfall.

---

## 2. Backend: FastAPI (Python)

**Beschreibung:** Das Backend fungiert als asynchrone REST-API, basierend auf FastAPI und Python 3.11+. Als Webserver dient Uvicorn, ein High-Performance ASGI-Server. Die Datenhaltung erfolgt in einer PostgreSQL-Datenbank, die über SQLAlchemy 2.0 (ORM) angesprochen wird.

**Begründung:** Der Fokus liegt auf Performance und modernen Standards. Pydantic validiert alle Dateneingänge rigoros und generiert automatisch die OpenAPI-Dokumentation (Swagger UI), was die Integration für Frontend-Entwickler erleichtert. PostgreSQL wurde aufgrund seiner Stabilität (ACID-Compliance) und der Unterstützung für JSONB-Datentypen gewählt, was Flexibilität bei semi-strukturierten Daten erlaubt. Die Entscheidung fiel bewusst gegen klassische Frameworks wie Django oder Flask. FastAPI ist durch die native Unterstützung von asynchroner Programmierung (Async/Await) und die Nutzung von Starlette deutlich performanter. Zudem bietet SQLAlchemy 2.0 im Gegensatz zu simpleren ORMs die Flexibilität, nahtlos zwischen objektorientiertem Zugriff und Raw SQL zu wechseln.

---

## 3. Worker: Asynchrone Verarbeitung — Celery, RabbitMQ & Redis

**Beschreibung:** Um langlaufende Prozesse zu handhaben, wird eine Task-Queue-Architektur eingesetzt. Celery übernimmt die Verwaltung der Hintergrundaufgaben und setzt dabei auf zwei spezialisierte Infrastruktur-Komponenten: **RabbitMQ** als Message Broker (Aufgaben werden vom Backend an den Worker zugestellt) und **Redis** als Result Backend (Task-Ergebnisse + Live-Status werden für Abfragen aus dem Frontend zwischengespeichert). Zusätzlich dient Redis als Pub/Sub-Layer für die Server-Sent-Events, über die das Frontend Deployment-Logs in Echtzeit empfängt.

**Begründung:** Durch Celery wird die Ausführung entkoppelt: Die API nimmt den Auftrag im Millisekunden-Bereich entgegen, während der Worker ihn im Hintergrund abarbeitet. Dies hält die UI reaktionsfähig. RabbitMQ und Redis übernehmen dabei bewusst unterschiedliche Rollen, weil ihre Stärken komplementär sind: RabbitMQ ist auf zuverlässige Task-Zustellung ausgelegt (persistente Queues, Acknowledgements, Retry-Mechanismen) und stellt sicher, dass Deployment-Tasks auch bei Worker-Ausfällen nicht verloren gehen — diese Garantien wären bei einem reinen Redis-Broker schwächer. Redis hingegen ist als schneller In-Memory-Speicher genau richtig für flüchtige Daten: Task-Ergebnisse, die das Frontend kurz nach Abschluss abfragt, sowie das Pub/Sub-Forwarding der Live-Log-Events an die SSE-Streams. Die Kombination ist gegenüber einer reinen RabbitMQ- oder reinen Redis-Lösung robuster und gleichzeitig performanter.

---

## 4. Deployment & Containerisierung: Docker

**Beschreibung:** Die gesamte Anwendung wird mittels Docker containerisiert. Für die lokale Entwicklung kommt `docker-compose.dev.yml` zum Einsatz, das die Services mit hot-reload und gemounteten Source-Dateien startet. Für das Deployment auf der OpenStack-VM existiert `docker-compose.staging.yml` (CD-Pipeline, Image-Versionen festlegbar) bzw. `docker-compose.prod.yml` (always-latest aus der Registry); beide ziehen fertige Images aus der GitHub Container Registry (GHCR) und führen keine Build-Schritte auf der Zielmaschine aus.

Der Stack besteht aus folgenden Containern:

| Container | Aufgaben |
|---|---|
| **PostgreSQL** | Zentrale Datenhaltung der Anwendung (Benutzer, Apps, Deployments) |
| **PostgreSQL (tfstate)** | Separater Postgres-Container ausschließlich für Terraform Remote State. Läuft isoliert im Worker-Netzwerk und ist für das Backend nicht erreichbar |
| **RabbitMQ** | Entkoppelt zeitintensive Deployment-Prozesse vom Backend; erhöht Skalierbarkeit und Ausfallsicherheit |
| **Redis** | Celery Result Backend; speichert Task-Ergebnisse im Arbeitsspeicher |
| **Keycloak** | Identity Provider; Verwaltung von Benutzern, Rollen und Rechten; OIDC-basierte Authentifizierung für Frontend und Backend |
| **Backend** | REST-API; nimmt Anfragen entgegen, validiert Tokens gegen Keycloak, persistiert Daten und dispatcht Deployment-Tasks an RabbitMQ |
| **Worker** | Konsumiert Tasks aus RabbitMQ; klont App-Repositories; führt Packer und Terraform aus; provisioniert Infrastruktur auf OpenStack |
| **Frontend** | Vue 3 SPA, ausgeliefert von nginx im Container; kommuniziert ausschließlich über die Backend API |
| **nginx** | Reverse Proxy und TLS-Terminierung. Leitet eingehende HTTPS-Requests (Port 443) an Frontend, Backend (`/api/`) und Keycloak (`/realms/`) weiter. Das Self-Signed-Zertifikat wird von Ansible beim ersten Deploy erzeugt und bei Folgedeploys wiederverwendet |

**Deploymentprozess:** Ein Push auf `main` in einem der Service-Repositories (Backend, Frontend, Worker) löst zunächst die jeweilige CI-Pipeline aus, die das Image baut und in die GHCR pusht. Sobald das erfolgreich abgeschlossen ist, triggert die Pipeline automatisch den Deployment-Workflow im deployment-Repository. Terraform provisioniert die OpenStack-VM (oder stellt sicher, dass sie läuft) und gibt die IP-Adresse aus. Anschließend führt Ansible das Deployment-Playbook auf der VM aus: es synchronisiert das Repository, schreibt die `.env`-Datei aus dem GitHub-Secret, rendert `keycloak/realm-export.json.j2` mit der öffentlichen URL der VM, zieht die GHCR-Images und startet den Stack via `docker compose up`. Datenbankmigrationen werden als expliziter Ansible-Task ausgeführt, damit Fehler sichtbar im Pipeline-Log erscheinen und nicht im Compose-Output verschwinden.

Der Keycloak-Realm wird beim ersten Hochfahren automatisch aus `realm-export.json` importiert, das Ansible zuvor mit der korrekten APP_BASE_URL befüllt hat. Dadurch entfällt manuelles Klicken im Admin-UI bei jedem frischen Deploy.

**Begründung:** Docker garantiert Portabilität: Entwicklung und Deployment laufen in identischen Umgebungen, was die Gefahr umgebungsbedingter Fehler deutlich reduziert. Multi-Stage Builds halten die Images klein und frei von Build-Werkzeugen. Gegen Kubernetes wurde bewusst entschieden, da der Konfigurationsaufwand für diesen Projektrahmen unverhältnismäßig wäre. Docker Compose ist hier die schlanke, wartbare Lösung. Kubernetes bleibt eine Option, falls zukünftig Skalierung über mehrere Server hinweg notwendig wird.

---

## 5. Infrastructure as Code (IaC): Terraform & Packer

**Beschreibung:** Die Infrastruktur wird nicht manuell, sondern durch Code definiert. Terraform provisioniert die Ressourcen (VMs, Netzwerke, Security Groups) auf OpenStack. Packer wird genutzt, um Abbilder für die VMs zu bauen.

**Begründung:** Dieser Ansatz ermöglicht Disaster Recovery "per Knopfdruck" und vollständige Versionierung der Infrastruktur in Git. Ein entscheidender Vorteil ist der "Golden Image"-Workflow mit Packer. Anstatt eine leere VM zu starten und dann minutenlang Software zu installieren (wie bei reinem Ansible/Shell-Scripting oft üblich), erstellt Packer ein fertiges Image (Snapshot).
