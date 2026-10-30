# Agent-Harness für den AppStore

Wie Claude Code in der `DHBW-AppStore-T3`-Organisation aufgesetzt ist,
und warum. Die Setup-Anleitung steht in
[`GET_STARTED_WITH_HARNESS.md`](GET_STARTED_WITH_HARNESS.md).

## Der Rahmen: sechs Repos, ein Kubernetes-Cluster

Der AppStore ist **sechs eigenständige Git-Repositories** unter einer
gemeinsamen GitHub-Org, kein Monorepo:

| Repo | Stack | Rolle |
|---|---|---|
| [`backend`](https://github.com/DHBW-AppStore-T3/backend) | FastAPI, SQLAlchemy 2.0, PostgreSQL | REST-API, App-Definitionen, stößt Deploys an |
| [`frontend`](https://github.com/DHBW-AppStore-T3/frontend) | React 19, Vite, Zustand, Tailwind | Web-UI für Dozierende/Studierende |
| [`worker`](https://github.com/DHBW-AppStore-T3/worker) | Python, Job-Queue auf PostgreSQL (`pgq`) | der `pod-deployer`: rendert und wendet die Kubernetes-/KubeVirt-Objekte einer App an, schreibt Fortschritt als Events (das Backend streamt sie per SSE) |
| [`deployment`](https://github.com/DHBW-AppStore-T3/deployment) | Helm-Charts, Argo CD, k3s, CloudNativePG, Keycloak, Traefik | hält lokal/staging/prod zusammen (Digest-Dateien je Umgebung) |
| [`moodle_appstore`](https://github.com/DHBW-AppStore-T3/moodle_appstore) | Moodle-Fork | LTI-Integrationsziel |
| [`self-service-ui`](https://github.com/DHBW-AppStore-T3/self-service-ui) | Fork von [pfisterer/self-service-ui](https://github.com/pfisterer/self-service-ui) | Referenzimplementierung |

Und es gibt ein **echtes Produktivsystem**: einen k3s-Cluster im
OpenStack-Projekt `ma_wwi_24sea_appstore_g3` (ein Node), den Argo CD aus dem
`deployment`-Repo bespielt. Staging (Branch `dev`, Namespace
`appstore-staging`) und Produktion (Branch `main`, Namespace `appstore-prod`)
teilen sich den Node. Alle Apps laufen als Pods oder KubeVirt-VMs im Cluster;
den früheren OpenStack-VM-Pfad (Packer, OpenTofu, Credentials) gibt es seit
[#12](https://github.com/DHBW-AppStore-T3/.github/issues/12) nicht mehr.
Jede Entscheidung unten gilt gegen dieses scharfe System, nicht gegen ein
Zielbild.

---

---

## 0. Prozess 1 — Issue Creation: vom Wunsch zur Spezifikation

Bevor ein Feature die Kette in System 5 betritt, braucht es eine
Spezifikation, die ein Mensch freigegeben hat. Dieser Prozess ist
vollständig in `/issue-creation` (`deployment/.claude/skills/
issue-creation/SKILL.md`) abgebildet.

### Die Kette

```
1. MENSCH    Anforderung rein
2. AGENT     Klarifizieren — liest HANDOVER.md + claude_docs/ aller
                             betroffenen Repos, stellt gezielte Rückfragen
3. MENSCH    Antworten
4. AGENT     Brainstorming (/brainstorming) — Cross-Repo-Graphify +
                             OpenAPI-Contract, Optionen mit Trade-offs
             ── MENSCH wählt Option ──
5. AGENT     Specs: /design-spec → Design Spec (was + warum)
                    /implementation-spec → Impl Spec (wie, null Platzhalter)
6. MENSCH    Freigabe (explizite Bestätigung, nicht implizit)
             ── danach: gh issue create ──
```

Zwei HITL-Stopps (Klarifizierung, Freigabe), kein "Agent rät Architektur"
ohne explizite Bestätigung. Die Spec landet als GitHub-Issue-Body und
ist der Startpunkt für `/ship-feature #<issue-number>`.

### Ablageorte der Skills

| Skill | Datei | Kern-Referenz |
|---|---|---|
| `/issue-creation` | `deployment/.claude/skills/issue-creation/SKILL.md` | Org-spezifisch |
| `/brainstorming` | `deployment/.claude/skills/brainstorming/SKILL.md` | [Superpowers upstream](https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md) + Org-Ergänzungen |
| `/design-spec` | `deployment/.claude/skills/design-spec/SKILL.md` | Org-spezifisch (OpenAPI-first, Sechs-Repo) |
| `/implementation-spec` | `deployment/.claude/skills/implementation-spec/SKILL.md` | [Superpowers writing-plans](https://github.com/obra/superpowers/blob/main/skills/writing-plans/SKILL.md) Prinzip + Org-Ergänzungen |

### Warum hier und nicht in `.github/.claude/skills/`

`/issue-creation` braucht Zugriff auf Org-weite HANDOVER.md-Dateien,
den Cross-Repo-Graphify-Graphen (`.github/graphify-out/`) und die
`gh`-CLI gegen alle sechs Repos. Das sind Abhängigkeiten, die im
`deployment`-Repo bündelbar sind — im zentralen `.github`-Repo liegen
Skills, die repo-übergreifend für die *Entwicklung* gelten (`/tdd`,
`/ship-feature`); Prozess-1-Skills sind dichter am Kontext-Layer
und bleiben im `deployment`-Repo, analog zu den Ops-Skills.

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
├── queues.md              # Postgres-Queue (pgq), Lease, Wiederzustellung
└── sse-streaming.md       # task_events → Server-Sent-Events (im Backend)
HANDOVER.md
```

**`frontend/claude_docs/`**
```
architecture/
├── overview.md
├── state.md               # Zustand (Zustand-Stores), welcher State wo lebt
├── api-client.md          # Axios-Setup & OpenAPI-Typengenerierung
└── routing.md
HANDOVER.md
```

**`deployment/claude_docs/`**
```
claude_docs/
├── decisions/             # z. B. appstore-on-kubernetes, postgres-queue
└── HANDOVER.md
k8s/README.md              # Aufbau, Komponenten, Rechte, Netzwerk-Policies
docs/                      # dev-setup (lokaler k3d-Stack), prod-setup
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
3. Das Frontend konsumiert das Schema via `npm run gen:api-types` —
   TypeScript-Typen werden generiert, nicht von Hand gepflegt.
   Ändert das Backend ein Feld, schlägt der Typecheck sofort fehl.
4. Jobs zwischen `backend` und `worker` laufen über die Postgres-Queue
   (`task_contract.py`, in beiden Repos identisch und per Hash-Test
   abgesichert) statt über Markdown-Tabellen.

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

### 2.1 MCP-Server: `appstore-mcp`

Ersetzt den früheren VM-Agenten Hermes (Discord, `podman-mcp`, OpenStack-MCP).
`appstore-mcp` ist ein öffentlicher Remote-MCP-Server (Repo `appstore-mcp`),
läuft als Pod im Cluster (Argo-App `staging-mcp`) und gibt Agents einen
**read-only** Einblick in Cluster, Argo CD und CI. Nach einem automatischen
Staging-Push holt sich der Agent damit Health-Feedback, ohne Schreibrechte.

| Eigenschaft | Wert |
|---|---|
| Endpoint Staging | `https://appstore-mcp-staging.<zone>/mcp` (Streamable HTTP) |
| Auth | OAuth 2.1 (Dynamic Client Registration, Login über GitHub-OAuth-App, Scope `read:org`) oder statische Tokens; ohne Token `401` mit `WWW-Authenticate` |
| Image | per Digest gepinnt (`k8s/images/<env>.yaml`, geschrieben von `k8s-bump.yml`) |
| Rechte | ClusterRole + RoleBindings nur `get`/`list`/`watch` (Pods, Logs, Events, Deployments, Jobs, Ingresses, Argo-Applications, CNPG, cert-manager, Metrics); **keine Secrets, kein `exec`, kein Schreiben**. CI-Test: `k8s/tests/check_mcp_rbac.py` |

Einbindung in Claude Code:

```bash
claude mcp add --transport http appstore https://appstore-mcp-staging.<zone>/mcp
```

Beim ersten Aufruf öffnet sich der GitHub-Login. Die Prod-Instanz bleibt
deaktiviert, bis die Staging-Abnahme durch ist.

**GitHub-Interaktion erfolgt weiterhin ausschließlich über `gh` CLI** — kein
`github-mcp-server`.

### 2.2 Ops-Skills (im `deployment`-Repo)

Die Skills `/diagnose-production`, `/deploy-status` und `/restart-service`
gehörten zum Hermes-/Podman-Modell (VMs) und sind durch `appstore-mcp`
(Diagnose) sowie Argo CD (Rollout, Self-Heal) abgelöst. Es gibt keinen
schreibenden Server-Zugang für Agents mehr.

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

### 3.2 Agent-Zugriff auf den Cluster (`appstore-mcp`)

Agents erhalten **keinen** Schreibzugriff auf Cluster oder Server:
- Lesender Zugriff nur über `appstore-mcp` (OAuth/GitHub-Login bzw. Token),
  RBAC strikt `get`/`list`/`watch`, keine Secrets.
- Änderungen laufen ausschließlich über Git: Push auf `dev` -> CI -> Digest-Bump
  -> Argo CD (Staging); `main` -> Bump-PR mit Required Check `🔒 Gitleaks` (Prod).
- Es gibt keine Discord-Anbindung und keinen SSH-Pfad mehr; der
  `appstore-prod-guardrail.py`-Hook entfällt mit den VMs.

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
  │     └─► OpenAPI 3.1, DB-Modelle, Worker-Jobs, TDD-Plan
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
  │     └─► Push auf `dev` -> Image-CI -> k8s-bump.yml pinnt den Digest -> Argo CD rollt aus
  │
  ├─► Agent prüft Staging über `appstore-mcp`
  │     └─► Pods, Events, Logs, Argo-Health (read-only)
  │     └─► System Health Check: GUT / SCHLECHT
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
   Worker-Jobs, UI-Komponenten. Nach User-Bestätigung:
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
6. **Automatisches Staging-Deployment:** `dev`-Merge -> Image-CI -> Digest-Bump -> Argo CD.
7. **Health-Status über `appstore-mcp`:** Pod-/Argo-Zustand, Events und Logs
   der Staging-Komponenten (read-only). GUT / SCHLECHT.
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

## Status (Stand 2026-10-29)

| System | Status |
|---|---|
| 1 · Wissen | ✅ `claude_docs/` & `HANDOVER.md` in allen 6 Repos; OpenAPI 3.1 + CI-Export + Frontend-Codegen; lokale Graphen + Cross-Repo-Graph |
| 2 · Deployment-Ops | ✅ `appstore-mcp` (read-only Remote-MCP, OAuth/Token) läuft auf Staging; ersetzt Hermes/`podman-mcp` |
| 3 · Zugriff & Guardrails | ✅ Branch-Protection in allen 6 Repos; Agents ohne Schreibzugriff (`appstore-mcp` read-only RBAC, Änderungen nur via Git/Argo CD) |
| 4 · Engineering-Loop | ✅ Plugins `superpowers` & `ecc` via Marketplace; `setup-harness.sh` für Team-Setup |
| 5 · Die 2 Harness-Flows | ✅ Flow 1 `/user-story` + Flow 2 `/harness-workflow`; Push auf `main` rein menschlich + Test Coverage Gate |
| 6 · GitHub Best Practices | ✅ `SECURITY.md`, `pull_request_template.md`, `dependabot.yml`, `.gitignore` |

**Verbleibend, kein Blocker:** keiner. Ein OpenStack-MCP ist nicht mehr vorgesehen: Agents haben keinen OpenStack-Zugang, Cluster-Einblick liefert `appstore-mcp`.

**Bekannte, nicht behebbare Lücke:** `members_can_delete_repositories`
/ `members_can_change_repo_visibility` lassen sich über die GitHub-API
auf diesem Plan nicht deaktivieren.
