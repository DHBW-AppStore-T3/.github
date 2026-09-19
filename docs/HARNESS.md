# Agent-Harness für den AppStore

Wie Claude Code in der `DHBW-AppStore-T3`-Organisation aufgesetzt ist,
und warum. Die Setup-Anleitung steht in
[`GET_STARTED_WITH_HARNESS.md`](GET_STARTED_WITH_HARNESS.md).

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

Und es gibt eine **echte Produktions-VM**: `appstore-prod-01` auf
OpenStack, 10 Docker-Container (nginx, frontend, backend, worker,
keycloak, 2× postgres, rabbitmq, redis, tfstate-postgres), Uptime im
Wochenbereich. Jede Entscheidung unten gilt gegen dieses scharfe
System, nicht gegen ein Zielbild.

---

## 1. Wissen — wie der Agent das Projekt versteht

### 1.1 `claude_docs/` — tief geschachtelt, mit lebendem Übergabedokument

Struktur pro Repo-Typ:

**`backend/claude_docs/`**
```
claude_docs/
├── architecture/
│   ├── overview.md        # Module, Layering, Request-Flow
│   ├── database.md        # Schema, Alembic-Migrationsstrategie
│   └── auth.md            # Keycloak-Integration, Token-Flow
├── decisions/             # ein Eintrag pro architektur-relevanter Entscheidung
├── debugging/
│   ├── common-errors.md
│   └── local-setup-gotchas.md
└── HANDOVER.md
```

**`worker/claude_docs/`**
```
architecture/
├── overview.md
├── queues.md              # RabbitMQ-Routing, Retry-Verhalten
└── sse-streaming.md       # Redis-Pub/Sub → Server-Sent-Events ans Frontend
HANDOVER.md
```

**`frontend/claude_docs/`**
```
architecture/
├── overview.md
├── state.md               # Pinia-Stores, welcher State wo lebt
├── api-client.md          # Axios-Setup & OpenAPI-Typengenerierung
└── routing.md
HANDOVER.md
```

**`deployment/claude_docs/`**
```
claude_docs/
├── topology/
│   ├── environments.md    # dev / staging / prod, was sie unterscheidet
│   ├── boot-order.md      # Caddy → Keycloak → backend → worker → frontend
│   └── networking.md      # welcher Dienst spricht mit welchem, welche Ports
├── decisions/
├── rollback/
│   ├── database.md        # Alembic-Downgrade-Pfad
│   └── service.md         # einzelnen Container zurückrollen
└── HANDOVER.md
```

`moodle_appstore` und `self-service-ui` bekommen vorerst nur ein
flaches `claude_docs/` (architecture.md, decisions.md, HANDOVER.md).

Jedes root-`CLAUDE.md` bleibt dünn und verlinkt nur in die passenden
Unterordner statt Inhalte zu duplizieren.

### 1.2 `HANDOVER.md` — Ein einzelnes, lebendes Übergabedokument

**Ein einzelnes, lebendes Übergabedokument pro Repo: `claude_docs/HANDOVER.md`**.

- **Workflow:** Jede Session (Agent oder Mensch) liest `HANDOVER.md` als
  *allerersten Schritt*. Vor dem Ende der Session wird `HANDOVER.md`
  zwingend mit dem neuen Stand aktualisiert.
- **Aufbau:**
  1. **Status & Fokus:** Welcher Branch ist aktiv, was funktioniert, was zuletzt deployed/gemerged.
  2. **In Arbeit & Nächste Schritte:** Konkrete offene Punkte für die folgende Session.
  3. **Bekannte Fallstricke & Blocker:** Kürzlich entdeckte Fallen, temporäre CI-Probleme.
  4. **Übergabe-Historie (kompakt):** Rollierendes Protokoll der letzten Sitzungen.

### 1.3 OpenAPI als Single Source of Truth

**Code ist der Contract, OpenAPI ist die Schnittstelle.**

1. FastAPI generiert nativ OpenAPI 3.1 aus Pydantic-Modellen.
2. `make openapi` exportiert die aktuelle `openapi.json` im CI.
3. Das Frontend konsumiert das Schema via `npm run openapi:generate` —
   TypeScript-Typen werden generiert, nicht von Hand gepflegt.
   Ändert das Backend ein Feld, schlägt `vue-tsc` sofort fehl.
4. Celery-Tasks zwischen `backend` und `worker` nutzen typisierte
   Pydantic-Payload-Modelle statt Markdown-Tabellen.

### 1.4 Graphify — global über alle sechs Repos

```
# In jedem der sechs Repos: eigener, lokaler Graph
backend/graphify-out/graph.json
frontend/graphify-out/graph.json
worker/graphify-out/graph.json
deployment/graphify-out/graph.json
moodle_appstore/graphify-out/graph.json
self-service-ui/graphify-out/graph.json

# Zentral: alle sechs zu einem Graphen gemerged
.github/graphify-out/cross-repo-graph.json
```

Aktualität auf zwei Ebenen ohne teures LLM-Rebuild:

1. Jedes Repo hat einen CI-Schritt (`push` auf `main`), der
   `graphify update <path>` laufen lässt — **kein LLM-Call**,
   nur Re-Extraktion geänderter Dateien.
2. Ein Workflow in `.github/` führt täglich `graphify merge-graphs`
   aus und committet den zentralen Cross-Repo-Graphen.

---

## 2. Deployment-Ops — Skills & MCP

### 2.1 MCP-Server: `podman-mcp`

Läuft produktiv auf `appstore-prod-01` und ist der einzige schreibende
Server-Zugang von Hermes:

| MCP | Zweck |
|---|---|
| [`manusa/podman-mcp-server`](https://github.com/manusa/podman-mcp-server) | Container-Status, Logs, gezielte Restarts |
| [`openstack-kr/python-openstackmcp-server`](https://github.com/openstack-kr/python-openstackmcp-server) | Server-/Netzwerk-Status über OpenStack-REST-API (`clouds.yaml`) |

**GitHub-Interaktion erfolgt ausschließlich über `gh` CLI** — kein
`github-mcp-server`. Der Agent ruft direkt `gh issue view`, `gh pr create`,
`gh pr merge`, `gh run watch` etc. auf; das reicht für alle Flow-2-Schritte
ohne zusätzlichen MCP-Overhead.

**Drei echte Bugs beim `podman-mcp`-Rollout (dokumentiert, damit sie
nicht wiederholt werden):**

1. **`quay.io/manusa/podman-mcp-server` existiert nicht** — kein
   Container-Image veröffentlicht. Fix: eigenes Dockerfile
   (`deployment/agent/podman-mcp.Dockerfile`) mit dem offiziellen
   Release-Binary.
2. **`cli`-Implementierung sucht nur nach `podman`**, nie `docker`. Fix:
   `podman`→`docker` Symlink im Image, `--podman-impl cli` erzwingen.
3. **Prozess beendet sich sofort** — `ServeStdio(ctx)` blockiert auf
   Stdin, bekommt sofort EOF. Fix: `stdin_open: true` im Compose-File.

**Vierte Beobachtung:** Hermes verbindet MCP nur beim eigenen Start. Startet
`podman-mcp` nach `hermes-agent`, bleibt die Verbindung tot bis zum
Neustart von Hermes. `depends_on` in Compose reicht nicht — es ordnet
nur die Startreihenfolge. Fix: Healthcheck-Abhängigkeit oder `docker restart hermes-agent-prod` nach stabilem `podman-mcp`.

### 2.2 OpenStack-MCP — vorbereitet, nicht deployt

In `deployment/agent/config.yaml` konfiguriert, aber auskommentiert
bis zur lese-beschränkten `clouds.yaml`. Kein eingebauter Read-Only-Modus
(verifiziert gegen den Quellcode): `get_*`/`create_*`/`delete_*` liegen
gleichwertig nebeneinander. Die Allowlist in `agent/config.yaml` (nur
`get_*`) ist die Guardrail, kein Server-Flag.

### 2.3 Ops-Skills (im `deployment`-Repo)

```
deployment/.claude/skills/
├── /diagnose-production   # podman-mcp Health → Logs → OpenStack-Zustand
├── /deploy-status         # Container Health + CI-Status via gh run list
└── /restart-service       # einzige schreibende Aktion, feste Namens-Allowlist
```

---

## 3. Zugriff & Guardrails — durchgesetzt, nicht dokumentiert

### 3.1 GitHub-Org

| Einstellung | Zustand |
|---|---|
| `default_repository_permission` | `write` — alle 6 Mitglieder pushen in alle 6 Repos |
| Branch-Protection auf `main` | ✅ gesetzt in allen sechs Repos — PR-Pflicht, kein Force-Push |
| `members_can_delete_repositories` | 🔴 über API nicht abschaltbar (Free-Plan-Einschränkung) |
| `members_can_change_repo_visibility` | 🔴 dito |

**Required-Status-Checks:**

| Repo | Required Checks |
|---|---|
| `backend` | Lint, Test (unit), Test (integration), Security, Build, Image Scan |
| `frontend` | Type Check, Test, Security, Build, Image Scan |
| `worker` | Lint, Test (unit), Test (integration), Security, Build, Image Scan |
| `deployment` | Gitleaks (Secret-Scan) |
| `moodle_appstore`, `self-service-ui` | keine — externe Fork-CI, nur PR-Pflicht |

### 3.2 Server-Agent Hermes (`appstore-prod-01`)

**Discord ist der Kommunikationsweg, nicht SSH:**
- `DISCORD_ALLOWED_USERS` (Discord-User-IDs) ist die tatsächliche
  Zugriffsgrenze — jede Nachricht durchläuft diese Prüfung.
- Bot bleibt **"Public Bot: OFF"** — einladbar nur über manuell
  konstruierte URL.
- SSH bleibt parallel bestehen als direkter Wartungskanal.

**Rechte-Grenze:** Der `docker.sock`-Mount macht `podman-mcp`
root-äquivalent zum Host. Die tatsächliche Grenze ist deshalb der
**MCP-Tool-Filter in `agent/config.yaml`** — Hermes sieht nur
`container_list`/`container_inspect`/`container_logs`.

Ergänzend: **`appstore-prod-guardrail.py` PreToolUse-Hook** für direkten
Claude-Code-Zugriff per SSH — erlaubt nur `ps`, `logs`, `compose logs`,
`compose restart <name>` aus einer festen Allowlist. Beide Mechanismen
spiegeln dieselbe Allowlist an zwei Zugriffspunkten.

**Alembic-Migrationen:** Laufen nie automatisiert gegen staging/prod —
immer mit expliziter menschlicher Bestätigung.

---

## 4. Engineering-Loop — Plugins & die 2 Flows

### 4.1 Everything Claude Code (ECC) — Plugin `ecc@ecc`

Marketplace: `https://github.com/affaan-m/ECC.git`  
Liefert 68 spezialisierte Subagents (u. a. `code-reviewer`, `security-reviewer`).
Wird in Flow 2 vor dem PR als automatisches Review-Werkzeug aufgerufen.

### 4.2 Superpowers — Plugin `superpowers@superpowers-marketplace`

Quelle: [`obra/superpowers`](https://github.com/obra/superpowers)  
Kern-Disziplinen:
- **`test-driven-development`:** "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"
- **`systematic-debugging`:** "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"
- **`verification-before-completion`**

Wird in Flow 2 für den TDD-Loop genutzt.

### 4.3 Team-Setup

```bash
./.github/scripts/setup-harness.sh
```

Richtet Marketplaces, Plugins und Symlinks für alle Teammitglieder in
einem Schritt ein. Die Konfiguration liegt als Single Source of Truth in
`.github/.claude/settings.json`.

---

## 5. Die 2 Harness-Flows

Der Harness operiert in **zwei klar getrennten Flows**:

```
================================================================================
FLOW 1: USER STORY GENERIERUNG (/user-story)
================================================================================

User: "Ich will Feature <X>"
  │
  ├─► Klarifizierungsfragen               (Persona, Problem, MVP-Scope, Repositories)
  │     └─► User-Antwort
  │
  ├─► Design Specs zur Implementierung
  │     └─► Mindestens 2 architektonische Optionen mit Trade-offs
  │     └─► User-Auswahl
  │
  ├─► Implementierungs-Specs
  │     └─► OpenAPI 3.1, DB-Modelle, Celery-Tasks, TDD-Plan
  │     └─► User-Bestätigung
  │
  └─► GitHub Issue erstellt via gh issue create (#<ID>)
        Labels: user-story, ready-for-dev


================================================================================
FLOW 2: HARNESS WORKFLOW (/harness-workflow)
================================================================================

User: "Bau mir Issue #<ID>"
  │
  ├─► Issue einlesen & Kontext aufbauen
  │     └─► gh issue view <ID>, HANDOVER.md & Architecture lesen
  │
  ├─► Branch von `dev` erstellen
  │     └─► git fetch origin dev && git checkout -b feat/issue-<ID>-<slug> origin/dev
  │
  ├─► TDD implementieren
  │     └─► Test rot ──► Minimaler Code grün ──► Refactor
  │     └─► Schema-Sync: make openapi / npm run openapi:generate
  │     └─► Lokale Verifikation: Linters, volle Test-Suite, ECC code-reviewer
  │
  ├─► PR auf `dev` öffnen
  │     └─► gh pr create --base dev
  │
  ├─► CI Gates überwachen
  │     └─► gh run watch: Lint, Unit, Integration, Security, Build, Image Scan
  │     └─► Bei GRÜN: gh pr merge --squash (automatisch)
  │
  ├─► Automatisches Staging Deployment startet
  │     └─► Push auf `dev` triggert deployment/staging.yml (Self-Hosted Runner)
  │
  ├─► Hermes schreibt in Discord
  │     └─► Feature deployed auf Staging
  │     └─► System Health Check: GUT / SCHLECHT (Container-Status & Endpunkte)
  │
  └─► MENSCHLICHES GATE: Push auf `main`
        ├── 🛑 Kein automatischer Agenten-Merge auf main
        └── 🛡️ Test Coverage Gate: backend ≥ 70%, worker ≥ 60%
```

### 5.1 Flow 1 im Detail: User Story Generierung (`/user-story`)

1. **User sagt:** "Ich will Feature X"
2. **Klarifizierungsfragen:** Agent fragt nach Stakeholdern, MVP-Scope,
   betroffenen Repositories und Einschränkungen.
3. **Design Specs mit Optionen:** Mindestens 2 architektonische Optionen
   mit Trade-offs. Der Mensch wählt die Richtung.
4. **Implementierungs-Specs:** OpenAPI 3.1 Schemas, SQLAlchemy-Modelle,
   Celery-Tasks, UI-Komponenten. Nach User-Bestätigung:
5. **Issue-Erstellung:**
   ```bash
   gh issue create --label user-story,ready-for-dev
   ```
   Vollständig strukturiertes Issue mit Akzeptanzkriterien und TDD-Testplan.

### 5.2 Flow 2 im Detail: Harness Workflow (`/harness-workflow`)

1. **User sagt:** "Bau mir Issue #\<ID\>"
2. **Branching von `dev`:** `feat/issue-<ID>-<slug>` von `origin/dev`.
3. **TDD-Loop:** Erst fehlschlagender Test, dann minimale Implementierung,
   dann Refactoring. OpenAPI-Contract bei Schnittstellenänderungen synchen.
4. **PR auf `dev`:**
   ```bash
   gh pr create --base dev
   ```
5. **CI-Gates & Auto-Merge:**
   ```bash
   gh run watch            # wartet auf alle Required Checks
   gh pr merge --squash    # bei 100% grün
   ```
6. **Automatisches Staging-Deployment:** `dev`-Merge triggert `staging.yml`.
7. **Hermes Discord Status:** Container-Gesundheit (z. B. 10/10 UP),
   HTTP-Status. GUT / SCHLECHT.
8. **Menschliches Gate:** Agent stoppt nach Staging-Report.
   `main` bleibt ausnahmslos menschlich. Test Coverage Gate blockiert
   technisch bei Unterschreitung der Mindestwerte.

---

## Bewusst nicht Teil des Harness

- **`github-mcp-server`** — vollständig ersetzt durch `gh` CLI. Alle
  notwendigen GitHub-Operationen (Issue lesen, PR erstellen, Merge,
  CI-Status überwachen) laufen über native `gh`-Befehle, die direkter,
  einfacher und ohne MCP-Overhead funktionieren.
- **Eigener `appstore-ops`-MCP-Server** — zu viel Bau- und
  Wartungsaufwand gegenüber den bestehenden MCPs.
- **Web-UI für den Server-Agenten** — Discord deckt den Anwendungsfall
  bereits ab.
- **Alternativer Server-Agent** (Open-Weights-Modell) — keine
  konkrete Notwendigkeit, kein Plan.
- **Manuelle Markdown-API-Contracts** — ersetzt durch OpenAPI 3.1.
- **Wöchentliche Log-Dateien** — ersetzt durch `HANDOVER.md`.

---

## Status (Stand 2026-09-18)

| System | Status |
|---|---|
| 1 · Wissen | ✅ `claude_docs/` & `HANDOVER.md` in allen 6 Repos; OpenAPI 3.1 + CI-Export + Frontend-Codegen; lokale Graphen + Cross-Repo-Graph |
| 2 · Deployment-Ops | ✅ `podman-mcp` läuft produktiv; `python-openstackmcp-server` konfiguriert (wartet auf Credentials); Ops-Skills in `deployment`-Repo |
| 3 · Zugriff & Guardrails | ✅ Branch-Protection in allen 6 Repos; Hermes + Discord-Allowlist; `appstore-prod-guardrail.py`-Hook in `.github` und `deployment` aktiv |
| 4 · Engineering-Loop | ✅ Plugins `superpowers` & `ecc` via Marketplace; `setup-harness.sh` für Team-Setup |
| 5 · Die 2 Harness-Flows | ✅ Flow 1 `/user-story` + Flow 2 `/harness-workflow`; Push auf `main` rein menschlich + Test Coverage Gate |
| 6 · GitHub Best Practices | ✅ `SECURITY.md`, `PULL_REQUEST_TEMPLATE.md`, `dependabot.yml`, `.gitignore` |

**Verbleibend, kein Blocker:**
1. `python-openstackmcp-server` aktivieren, sobald lese-beschränkte `clouds.yaml` vorliegt.

**Bekannte, nicht behebbare Lücke:** `members_can_delete_repositories`
/ `members_can_change_repo_visibility` lassen sich über die GitHub-API
auf diesem Plan nicht deaktivieren.
