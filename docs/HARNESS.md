# Agent-Harness für den AppStore

Wie Claude Code in der `DHBW-AppStore-T3`-Organisation aufgesetzt ist,
und warum. Die Setup-Anleitung dazu steht in
[`GET_STARTED_WITH_HARNESS.md`](GET_STARTED_WITH_HARNESS.md); eine
visuelle Fassung als [Claude-Artifact](https://claude.ai/code/artifact/8dd27aed-ef44-4cbd-bd81-bb3874e89af2)
(wird nach dieser Überarbeitung aktualisiert).

## Der Rahmen: sechs Repos, eine laufende Prod-VM

Der AppStore ist **sechs eigenständige Git-Repositories** unter einer
gemeinsamen GitHub-Org, kein Monorepo:

| Repo | Stack | Rolle |
|---|---|---|
| [`backend`](https://github.com/DHBW-AppStore-T3/backend) | FastAPI, SQLAlchemy 2.0, PostgreSQL | REST-API, App-Definitionen, stößt Deploys an |
| [`frontend`](https://github.com/DHBW-AppStore-T3/frontend) | Vue 3, Pinia, Tailwind | Web-UI für Dozierende/Studierende |
| [`worker`](https://github.com/DHBW-AppStore-T3/worker) | Celery, RabbitMQ, Redis | führt Terraform/Packer-Deploys asynchron aus, streamt Logs per SSE |
| [`deployment`](https://github.com/DHBW-AppStore-T3/deployment) | Docker Compose, Terraform, Ansible, Caddy, Keycloak, Forgejo | hält dev/staging/prod zusammen |
| [`moodle_appstore`](https://github.com/DHBW-AppStore-T3/moodle_appstore) | Moodle-Fork | LTI-Integrationsziel |
| [`self-service-ui`](https://github.com/DHBW-AppStore-T3/self-service-ui) | Fork von [pfisterer/self-service-ui](https://github.com/pfisterer/self-service-ui) | Referenzimplementierung |

Und es gibt bereits eine **echte Produktions-VM**: `appstore-prod-01`
auf OpenStack, 10 Docker-Container (nginx, frontend, backend, worker,
keycloak, 2× postgres, rabbitmq, redis, tfstate-postgres), Uptime im
Wochenbereich. Das ist kein Zielbild mehr — der Harness muss ab jetzt
mit einem scharfen Produktivsystem rechnen, nicht mit einer
hypothetischen zukünftigen VM.

Das ändert, wie dieses Dokument aufgebaut ist: statt zehn einzelnen
Bausteinen gibt es **vier Systeme**. Jedes davon ist entweder ein
Tool, das etwas tatsächlich kann, oder eine durchgesetzte Regel — keine
Markdown-Datei, die nur beschreibt, was jemand tun sollte.

## Die vier Systeme

### 1. Wissen — wie der Agent das Projekt versteht

Zwei Dinge, beide repo-lokal, beide committet:

- **`claude_docs/`** pro Repo (`architecture.md`, `decisions.md`,
  `debugging.md`; bei `deployment`: `topology.md` + `rollback.md`
  statt `debugging.md`, weil es dort keinen Code, sondern eine feste
  Hochfahr-Reihenfolge gibt — Caddy → Keycloak → backend → worker →
  frontend). Jedes root-`CLAUDE.md` bleibt dünn und verlinkt nur
  hierher.
- **Graphify** pro Repo (`worker/graphify-out/` existiert bereits als
  Referenz). Zeigt Struktur *innerhalb* eines Repos. Was ein Graph
  nicht zeigen kann — wie backend, frontend und worker über
  REST-Endpunkte und Celery-Task-Namen zusammenhängen — muss explizit
  in `claude_docs/architecture.md` stehen.

**Warum als ein System zusammengefasst:** beides beantwortet dieselbe
Frage ("was muss der Agent über *dieses* Repo wissen, bevor er etwas
anfasst") mit unterschiedlicher Granularität — Graphify für Struktur,
`claude_docs/` für Kontext und Entscheidungen, die kein Graph zeigen
kann.

### 2. Deployment-Ops — das eine große fehlende Tool

Das ist der Baustein mit dem größten Hebel und dem größten Risiko,
weil er direkt gegen `appstore-prod-01` wirkt. Bisher war das über vier
Punkte verteilt (Server Claude, Remote Execution, Observability,
OpenStack-Zugriff) — das bündelt sich zu **einem MCP-Server**, den ein
Agent (egal ob lokal oder auf dem Server selbst) anspricht:

```
Agent
  │
  ├── Skill: /diagnose-production
  │       beschreibt die Reihenfolge: Health → Logs → letzte
  │       Deployments → Metriken, nie andersrum
  │
  └── MCP: appstore-ops
          ├── get_health()               [lesend]
          ├── get_logs(service)          [lesend]
          ├── get_deployments()          [lesend]
          ├── get_errors()               [lesend]
          ├── restart_service(name)      [schreibend, Allowlist]
          ├── openstack_server_list()    [lesend, OpenStack API]
          ├── openstack_server_status()  [lesend, OpenStack API]
          └── openstack_quota()          [lesend, OpenStack API]
```

Der bisher fehlende Teil ist die OpenStack-Anbindung: aktuell gibt es
keinen MCP/CLI-Zugriff auf die OpenStack-API selbst (Server-Liste,
Quotas, Volume-Status) — nur auf das, was via SSH auf der VM sichtbar
ist. Das MCP läuft gegen `clouds.yaml` (Layer aus dem alten Punkt ii)
und ergänzt die Docker-Ebene um die Infrastruktur-Ebene darunter.

**Wo dieses MCP laufen darf, ist eine Governance-Frage, kein
Implementierungsdetail** — siehe nächster Abschnitt.

### 3. Zugriff & Guardrails — durchgesetzt, nicht dokumentiert

Ein System, zwei Ebenen: GitHub-Org-Ebene und Server-Ebene.

**GitHub-Org:**
- `default_repository_permission: write` ist gesetzt — alle sechs
  Mitglieder können in alle sechs Repos pushen.
- Branch-Protection auf `main` fehlt in **allen sechs Repos** — das
  ist aktuell der größte offene Guardrail, weil er alles andere
  wirkungslos macht: ein Pre-Merge-CI-Check bringt nichts, wenn ein
  Direct-Push ihn umgeht.
- `members_can_delete_repositories` / `members_can_change_repo_visibility`
  stehen auf `true` und lassen sich über die API auf diesem Plan nicht
  abschalten (GitHub nimmt den PATCH mit `200 OK` an, ändert den Wert
  aber nicht) — jedes Mitglied kann aktuell ein Repo löschen.

**Server (`appstore-prod-01`):**
- Der einzige aktuell existierende Zugang ist der `ubuntu`-User mit
  **passwortlosem Sudo** — dasselbe Login, mit dem sich auch ein
  Mensch einloggt. Für einen Agenten ist das kein Zugang, den man
  wiederverwenden sollte, selbst für reine Diagnose.
- Geplanter Zielzustand: ein eigener, nicht-privilegierter
  `claude-agent`-User, Mitglied der `docker`-Gruppe (nötig, um
  `docker`-Befehle auszuführen), aber **ohne `sudo`**, mit eigenem
  `ed25519`-Key statt des geteilten `ubuntu`-Keys.
- **Wichtige Einschränkung, die nicht verschwiegen werden soll:**
  Mitgliedschaft in der `docker`-Gruppe ist selbst schon
  root-äquivalent (`docker run -v /:/host ...` gibt vollen
  Host-Zugriff — das ist kein Konfigurationsfehler, sondern wie Docker
  grundsätzlich funktioniert). Der eigene Linux-User trennt also nur
  Audit-Spuren und verhindert versehentliche `sudo`-Nutzung — er ist
  **keine echte Sandbox** gegen einen Agenten, der absichtlich oder
  durch einen Fehler etwas Destruktives ausführt.
- Die tatsächliche Grenze kommt deshalb nicht vom Linux-User, sondern
  von **PreToolUse-Hooks auf Claude-Seite**: eine feste Allowlist an
  `docker`-Unterbefehlen (`ps`, `logs`, `compose logs`, `compose
  restart <name>`), alles andere wird geblockt, bevor es die Shell
  erreicht. Das MCP aus System 2 spiegelt dieselbe Allowlist — beide
  Ebenen zusammen sind der Guardrail, keine einzelne für sich.

Dazu kommen die klassischen Repo-Guardrails: CI muss vor Merge grün
sein (nicht nur vorhanden — `ci.yml` existiert in backend/frontend/
worker, `secret-scan.yml` + `staging.yml` in deployment, aber ohne
Branch-Protection erzwingt das nichts), und Alembic-Migrationen
brauchen immer explizite menschliche Bestätigung, nie automatisiert.

### 4. Engineering-Loop — wie Code entsteht und geprüft wird

- **Standards:** Everything Claude Code (ECC) als gemeinsamer Boden;
  wo Python (Ruff) und TypeScript (Vite) unterschiedliche
  Lint-Konventionen brauchen, stehen die Abweichungen in
  `claude_docs/` des jeweiligen Repos.
- **Verifikation:** ein Skill, der nach Sprache verzweigt — `pytest`
  für backend/worker (Poetry-basiert), `vitest` für frontend. Der Loop
  bleibt gleich: fehlschlagender Test → minimale Implementierung →
  grün → Refactor → volle Suite → erst dann zurück an den Nutzer.

## Bewusst nicht (jetzt) Teil des Harness

**Persistent Context (GCC):** würde Git-Historie als strukturierten
Kontext über Sessions verwalten. Die Voraussetzung — echte
Git-Repos — ist erfüllt, aber bei sechs Repos mit größtenteils kurzer
Historie ist unklar, ob es Mehrwert bringt. Wird pro Repo einzeln
evaluiert, nicht vorab org-weit eingeführt.

## Woher der Stack kommt

`DHBW-AppStore-T3` ist der Fork unseres Teams vom
`six7-click-n-deploy`-Template. `frontend`, `backend`, `worker`,
`deployment`, `.github` teilen diese Herkunft. `DHBW-AppStore` (ohne
`-T3`) ist eine **andere** Gruppe mit demselben Template — Ähnlichkeit
im Namen, kein gemeinsamer Betrieb; frühere lokale Klone zeigten
fälschlich dorthin und wurden korrigiert. `moodle_appstore` und
`self-service-ui` sind externe Forks
(`leamar1e/moodle_appstore`, `pfisterer/self-service-ui`) ohne
gemeinsame Historie mit dem Template.

## Status (Stand 2026-09-15)

| System | Status |
|---|---|
| 1 · Wissen | offen — kein `claude_docs/` in irgendeinem Repo; Graphify nur in `worker/` |
| 2 · Deployment-Ops-MCP | offen — VM läuft produktiv, aber kein MCP, kein `/diagnose-production`-Skill, keine OpenStack-API-Anbindung |
| 3 · Zugriff & Guardrails | teilweise — Org-Write-Zugriff ✅ gesetzt; Branch-Protection fehlt überall; Server-Zugang aktuell nur über geteilten `ubuntu`+Sudo-User, kein `claude-agent`-User |
| 4 · Engineering-Loop | offen — kein `/tdd`-Skill, ECC nicht eingezogen; CI existiert, ist aber nicht Merge-Pflicht |

**Die drei größten offenen Punkte, in Reihenfolge:**

1. **Branch-Protection auf `main`** in allen sechs Repos — ohne das
   ist jeder andere Guardrail umgehbar.
2. **Eigener `claude-agent`-User auf `appstore-prod-01`** statt
   Wiederverwendung von `ubuntu`+Sudo, kombiniert mit den
   PreToolUse-Hooks aus System 3 — sonst hat ein Agent auf dem Server
   dieselbe Macht wie ein Mensch mit vollem SSH-Zugriff.
3. **Deployment-Ops-MCP inkl. OpenStack-Anbindung** bauen — aktuell
   gibt es kein Werkzeug, nur SSH-Handarbeit.

**Bekannte, nicht behebbare Lücke:** `members_can_delete_repositories`
/ `members_can_change_repo_visibility` lassen sich über die GitHub-API
auf diesem Plan nicht deaktivieren. Nur manuell in den Org-Settings
prüfbar, falls der Plan das überhaupt zulässt.
