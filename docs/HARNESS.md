# Agent-Harness für den AppStore

Wie Claude Code in der `DHBW-AppStore-T3`-Organisation aufgesetzt ist,
und warum. Die Setup-Anleitung dazu steht in
[`GET_STARTED_WITH_HARNESS.md`](GET_STARTED_WITH_HARNESS.md); eine
visuelle Fassung als [Claude-Artifact](https://claude.ai/code/artifact/8dd27aed-ef44-4cbd-bd81-bb3874e89af2).

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

Vier Systeme, jedes entweder ein Tool, das etwas tatsächlich tut, oder
eine durchgesetzte Regel — keine Markdown-Datei, die nur beschreibt,
was jemand tun sollte.

---

## 1. Wissen — wie der Agent das Projekt versteht

Zwei Werkzeuge, beide repo-lokal, beide committet.

### 1.1 `claude_docs/` — tief geschachtelt, mit lebendem Übergabedokument

Ein flaches `claude_docs/architecture.md` reicht bei einem
FastAPI-Backend mit Alembic-Migrationen, Celery-Aufrufen und
Keycloak-Auth nicht — die Themen sind zu verschieden, um in einer
Datei nebeneinanderzustehen, ohne dass sie beim Lesen ineinander
verschwimmen. Struktur pro Repo-Typ:

**`backend/claude_docs/`**
```
claude_docs/
├── architecture/
│   ├── overview.md        # Module, Layering, Request-Flow
│   ├── database.md        # Schema, Alembic-Migrationsstrategie
│   └── auth.md            # Keycloak-Integration, Token-Flow
├── decisions/
│   ├── 2026-03-fastapi-vs-django.md
│   └── ...                # ein Eintrag pro architektur-relevanter Entscheidung
├── debugging/
│   ├── common-errors.md
│   └── local-setup-gotchas.md
└── HANDOVER.md            # lebendes Übergabedokument (Single Source of Session Truth), siehe 1.2
```

**`worker/claude_docs/`** — gleiches Muster, aber `architecture/`
verschiebt sich auf das, was dort tatsächlich komplex ist:
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
├── api-client.md           # Axios-Setup & OpenAPI-Typengenerierung
├── routing.md
└── HANDOVER.md
```

**`deployment/claude_docs/`** — kein Code zum Debuggen, sondern
Dienste in fester Reihenfolge, deshalb andere Unterordner:
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
flaches `claude_docs/` (architecture.md, decisions.md, HANDOVER.md) — sie sind
Referenz-/Integrationsrepos, keine aktiv weiterentwickelten
Kernservices; das wird nachgezogen, sobald sich das ändert.

Jedes root-`CLAUDE.md` bleibt dünn und verlinkt nur in die passenden
Unterordner statt Inhalte zu duplizieren.

### 1.2 `claude_docs/HANDOVER.md` — Ein einzelnes, lebendes Übergabedokument statt wöchentlicher Logs

Der ursprüngliche Entwurf sah wöchentliche Log-Dateien vor
(`claude_docs/log/<jahr>-W<kalenderwoche>.md`). In der Praxis hat sich
das als hinderlich erwiesen:
1. **Kontext-Fragmentierung:** Ein Agent oder Entwickler zu Beginn einer
   Session musste raten, in welcher KW die letzte Änderung lag, oder
   mehrere Dateien durchsuchen.
2. **Vergessene Aufgaben:** Was in KW37 offen blieb, wanderte nicht
   automatisch in KW38 weiter und geriet aus dem Blickfeld.
3. **Dateileichen:** Dutzende Wochenlogs blähen das Repo auf, ohne
   Mehrwert gegenüber `git log` zu bieten.

Deshalb gilt jetzt: **Ein einzelnes, lebendes Übergabedokument pro Repo:
`claude_docs/HANDOVER.md`**.

- **Workflow:** Jede Session (Agent oder Mensch) liest `HANDOVER.md` als
  *allerersten Schritt*, um sofort den aktuellen Projektzustand, offene
  Punkte und Blocker zu erfassen. Vor dem Ende der Session wird
  `HANDOVER.md` zwingend mit dem neuen Stand aktualisiert.
- **Aufbau von `HANDOVER.md`:**
  - **1. Status & Fokus:** Welcher Branch ist aktiv, was funktioniert,
    was wurde zuletzt deployed/gemerged.
  - **2. In Arbeit & Nächste Schritte:** Konkrete offene Punkte für die
    folgende Session.
  - **3. Bekannte Fallstricke & Blocker:** Kürzlich entdeckte Fallen,
    temporäre CI-Probleme oder Umgebungsspezifika.
  - **4. Übergabe-Historie (kompakt):** Rollierendes Protokoll der
    letzten Sitzungen (Datum, wer, was geändert wurde). Ältere Einträge
    werden verdichtet.

Der Unterschied zu `decisions/`: `HANDOVER.md` ist der flüchtige,
aktuelle Session-Kontext; `decisions/` ist thematisch und archiviert
dauerhafte Architektur-Entscheidungen.

### 1.3 API- & Task-Contracts — OpenAPI als Single Source of Truth statt Markdown

Manuelle Markdown-Dateien für API-Contracts (`api-contracts.md`,
`task-contracts.md`) sind ein bekanntes Anti-Pattern: Sie driften bereits
nach wenigen Tagen vom echten Code ab, werden bei Refactorings vergessen
und erzeugen doppelte Pflege ohne automatische Verifikation.

Stattdessen gilt: **Code ist der Contract, OpenAPI ist die Schnittstelle.**

1. **FastAPI als Single Source of Truth:**
   Das Backend definiert alle Datenmodelle via Pydantic (`schemas.py`)
   und alle Endpunkte via FastAPI-Router. FastAPI generiert daraus
   nativ eine voll-spezifizierte OpenAPI-3.1-Definition (`/openapi.json`).
2. **Automatisierter Schema-Export:**
   Über `backend/scripts/export_openapi.py` bzw. `make openapi` kann die
   aktuelle `openapi.json` direkt exportiert und im CI validiert werden.
3. **Typengenerierung im Frontend:**
   Das Frontend (`frontend/`) pflegt keine manuellen Request/Response-
   Interfaces auf Verdacht, sondern konsumiert das generierte OpenAPI-Schema
   (z. B. via `openapi-typescript` oder typisierte Axios-Clients). Ändert
   das Backend ein Feld, schlägt der Frontend-Typcheck `vue-tsc` sofort
   beim Build/Test fehl, bevor der Fehler Staging erreicht.
4. **Celery Task Contracts (Worker):**
   Auch für Celery-Tasks zwischen `backend` und `worker` werden keine
   flüchtigen Markdown-Tabellen gepflegt, sondern typisierte Pydantic-
   Payload-Modelle, die bei Deserialisierung validieren.

### 1.4 Graphify — global über alle sechs Repos, nicht nur pro Repo

Graphify unterstützt Cross-Repo-Graphen nativ (`merge-graphs`, jeder
Node behält ein `repo`-Attribut). Zielstruktur:

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

**Aktualität bei jedem Push** — zwei Ebenen, damit es nicht bei jedem
Push das volle LLM-gestützte Re-Extract kostet:

1. Jedes Repo hat einen CI-Schritt (`push` auf `main`), der
   `graphify update <path>` laufen lässt — das ist **kein LLM-Call**,
   nur Re-Extraktion geänderter Dateien — und `graphify-out/graph.json`
   committet.
2. Ein Workflow in `.github/` (org-weites Doku-Repo, wo auch diese
   Datei liegt) läuft auf ein Schedule (z. B. täglich, nicht pro Push)
   und holt die aktuellen `graph.json` der sechs Repos via
   `repository_dispatch` oder einfachem Checkout, führt
   `graphify merge-graphs` aus und committet den zentralen
   Cross-Repo-Graphen.
3. Für den Merge-Konflikt-Fall (zwei Branches ändern `graph.json`
   gleichzeitig) existiert bereits ein Git-Merge-Driver
   (`graphify-out/graph.json merge=graphify` in `.gitattributes`,
   aktuell nur lokal vorbereitet, noch nicht committet) — der
   übernimmt das Zusammenführen ohne manuellen Konflikt-Fix.

Damit ist "das große Ganze immer connected" ohne dass jeder Push einen
teuren LLM-Rebuild aller sechs Repos auslöst — nur der betroffene
Teilgraph wird pro Push aktualisiert, der Merge zum Gesamtbild läuft
separat und günstig.

---

## 2. Deployment-Ops — Skills statt eigenem MCP

Kein selbst gebautes MCP — der Aufwand steht in keinem Verhältnis zum
Nutzen, wenn es fertige Bausteine gibt. Stattdessen: eine Sammlung von
Skill-Markdown-Dateien, die Schritt für Schritt beschreiben, welche
Befehle in welcher Reihenfolge laufen — angedockt an zwei bestehende,
etablierte MCP-Server statt an rohes Bash/SSH:

| MCP | Zweck | Warum dieser |
|---|---|---|
| [`github/github-mcp-server`](https://github.com/github/github-mcp-server) | Deployment-Status, letzte Workflow-Runs, Commit-Historie, PR-Status | offizieller GitHub-MCP, deckt System 3 (Guardrails) und Deployment-Diagnose gleichzeitig ab |
| [`manusa/podman-mcp-server`](https://github.com/manusa/podman-mcp-server) | Container-Status, Logs, gezielte Restarts | fokussiert auf Container-Runtimes (Docker + Podman), keine überladene Cloud-CLI-Oberfläche |
| [`openstack-kr/python-openstackmcp-server`](https://github.com/openstack-kr/python-openstackmcp-server) | Server-/Netzwerk-/Identity-Status über die OpenStack-REST-API | nutzt `clouds.yaml` + OpenStack SDK, genau der Zugriff, den `openstack server list` auch hat — **korrigiert**: `avinas234/openstack-mcp` (frühere Wahl) braucht SSH-Zugriff auf den OpenStack-*Controller* selbst, den diese Org nicht hat, nur projektbezogenen API-Zugriff |

Die Skill-Ebene:

```
Agent
  │
  ├── Skill: /diagnose-production
  │       Ablauf: Health (podman-mcp) → Logs (podman-mcp) →
  │       letzte Deployments (github-mcp) → OpenStack-Zustand
  │       (openstack-mcp, nur wenn die ersten drei nichts erklären)
  │
  ├── Skill: /deploy-status
  │       liest github-mcp workflow runs + podman-mcp container health,
  │       fasst zusammen ob staging/prod synchron mit main sind
  │
  └── Skill: /restart-service
      einzige schreibende Aktion: ein Service-Restart über
      podman-mcp, mit fester Namens-Allowlist (kein `down`, kein `rm`,
      kein Compose-File-Wechsel)
```

Alle drei MCPs laufen mit denselben minimal-scoped Credentials wie der
Rest des Harness (Layer aus System 3): der GitHub-MCP mit einem
Token ohne `admin:org`, der OpenStack-MCP mit einer eigenen
`clouds.yaml`, die nur Lese-Rollen hat, nicht der Admin-Projektzugang.

**Bewusst nicht verfolgt:** ein eigener `appstore-ops`-MCP-Server, wie
in einer früheren Fassung dieses Dokuments skizziert. Die drei
bestehenden MCPs oben decken denselben Bedarf ab, ohne dass wir Server
und Sicherheitsgrenzen selbst bauen und pflegen müssten.

### 2.1 `podman-mcp` — drei echte Bugs beim ersten Deploy gefunden

Der erste tatsächliche Rollout von `podman-mcp` auf
`appstore-prod-01` (nicht nur `docker compose config`, sondern ein
echter Container-Start) hat drei unabhängige Probleme aufgedeckt, die
keine reine Config-Prüfung gefunden hätte:

1. **`quay.io/manusa/podman-mcp-server` existiert nicht.** Das Projekt
   veröffentlicht überhaupt kein Container-Image — nur npm-/PyPI-
   Wrapper und rohe GitHub-Release-Binaries (verifiziert gegen die
   eigenen `.github/workflows/`: kein Docker-Push-Schritt irgendwo).
   Fix: eigenes, minimales Dockerfile
   (`deployment/agent/podman-mcp.Dockerfile`), das das offizielle
   `linux-amd64`-Release-Binary lädt.
2. **Die `cli`-Implementierung sucht nur nach `podman`, nie nach
   `docker`** — trotz `AGENTS.md`, die behauptet "available when
   podman or docker binary is in PATH". Die `api`-Implementierung
   spricht das Podman-REST-Protokoll, das mit der Docker Engine API
   nicht kompatibel ist, würde aber trotzdem ausgewählt (`Available()`
   pingt den Docker-Socket nur, ohne das Protokoll zu prüfen). Fix:
   `podman` im Image auf `docker` symlinken, `--podman-impl cli`
   erzwingen, damit die Auto-Erkennung nicht in die kaputte
   `api`-Variante läuft.
3. **Der Prozess beendet sich sofort nach dem Start**, obwohl der
   HTTP-Server im Hintergrund läuft — `cmd.Execute()` blockiert
   unbedingt auf `ServeStdio(ctx)` im Hauptthread, auch im
   `--port`-Modus. Ohne offenes Stdin bekommt das sofort EOF, der
   Hauptthread kehrt zurück, der Container stirbt mit ihm — ein
   stiller Neustart-Loop ohne Fehlermeldung im Log. Fix:
   `stdin_open: true` auf dem Service.

**Vierte, kleinere Beobachtung:** Hermes selbst versucht die
MCP-Verbindung nur beim eigenen Start und "parkt" den Server nach drei
gescheiterten Versuchen, statt automatisch weiter zu retryen — startet
`podman-mcp` also *nach* `hermes-agent` (oder crasht es zuerst wie
hier), bleibt die MCP-Verbindung tot, bis `hermes-agent` manuell neu
gestartet wird. `depends_on: podman-mcp` in
`docker-compose.agent.yml` reicht dafür nicht, weil Compose damit nur
die Start-*Reihenfolge* ordnet, nicht auf einen erfolgreichen
Healthcheck wartet. Verifiziert: nach `docker restart hermes-agent-prod`
— einmal, nachdem `podman-mcp` stabil lief — verband sich Hermes
sofort ohne weiteren Fehler.

**Warum das hier steht statt nur im PR:** Das nächste MCP, das an
diesen Harness angebunden wird, sollte denselben Fehler nicht
wiederholen — bei einem fertigen Docker-Image "wird schon existieren"
annehmen, oder `docker compose config` als ausreichenden Test ansehen.
Ein realer Deploy-Versuch ist Pflicht, keine Kür.

### 2.2 `github-mcp-server` und OpenStack-MCP — vorbereitet, nicht deployt

Beide sind in `deployment/agent/config.yaml` vollständig konfiguriert,
aber auskommentiert — Config+Skills vorbereiten, kein Live-Deploy ohne
die nötigen Credentials, analog zur Entscheidung aus System 2.

**`github-mcp-server` braucht keinen eigenen Container.** GitHub
hostet den MCP-Server selbst unter
`https://api.githubcopilot.com/mcp/`, erreichbar per Streamable HTTP
mit `Authorization: Bearer <PAT>` — kein Docker-Image, kein
Socket-Mount, keines der `podman-mcp`-Probleme aus 2.1 kann hier
überhaupt auftreten. `X-MCP-Readonly: true` erzwingt read-only
serverseitig, zusätzlich zu einem ohnehin nur-lesenden PAT.

**Bei OpenStack war die ursprüngliche Wahl falsch, vor jedem Deploy
korrigiert:** `avinas234/openstack-mcp` (frühere Version dieses
Dokuments) verbindet per SSH zum OpenStack-*Controller* und führt dort
CLI-Befehle aus — das setzt Controller-Zugriff voraus, den diese Org
nicht hat, nur projektbezogenen `clouds.yaml`-API-Zugriff wie jeder
andere OpenStack-Tenant auch. Ersetzt durch
`openstack-kr/python-openstackmcp-server`, das die OpenStack SDK gegen
die REST-API nutzt — exakt der Zugriffslevel, den `openstack server
list` bereits hat. Kein eingebauter Read-Only-Modus (verifiziert
gegen den Quellcode, nicht angenommen): `get_*`/`create_*`/`delete_*`
existieren nebeneinander als gleichwertige Tools. Gleiches Muster wie
bei `podman-mcp` — die Allowlist in `agent/config.yaml` (nur `get_*`)
ist die Guardrail, kein Server-Flag.

---

## 3. Zugriff & Guardrails — durchgesetzt, nicht dokumentiert

Zwei Ebenen, ein System: GitHub-Org und Server. Die Kernfrage auf
beiden Ebenen ist dieselbe — **kann ein Agent (oder ein Mensch über
den Agenten) mehr, als er für seine Aufgabe braucht?**

### 3.1 GitHub-Org

| Einstellung | Zustand | Bewertung |
|---|---|---|
| `default_repository_permission` | `write` | ✅ gesetzt — alle 6 Mitglieder pushen in alle 6 Repos ohne Einzel-Einladung |
| Branch-Protection auf `main` | gesetzt in **allen sechs Repos** | ✅ PR-Pflicht, kein Force-Push, keine Branch-Löschung überall; Required-Status-Checks siehe unten |
| `members_can_delete_repositories` | `true`, über API nicht abschaltbar | 🔴 bekannte, nicht behebbare Plan-Einschränkung (PATCH gibt `200 OK`, Wert bleibt) |
| `members_can_change_repo_visibility` | `true`, gleiche Einschränkung | 🔴 dito |

**Required-Status-Checks pro Repo** — nur Jobs, die tatsächlich auf
einem PR laufen (Build/Push/Deploy-Jobs mit
`if: github.event_name == 'push'` laufen nie auf PRs und wurden
deshalb bewusst *nicht* als Required-Check eingetragen, sonst würde
jeder PR ewig blockieren):

| Repo | Required Checks |
|---|---|
| `backend` | 🔍 Lint, 🧪 Test (unit), 🧪 Test (integration), 🔒 Security, 🐳 Build, 🔒 Image Scan |
| `frontend` | 📐 Type Check, 🧪 Test, 🔒 Security, 🐳 Build, 🔒 Image Scan |
| `worker` | 🔍 Lint, 🧪 Test (unit), 🧪 Test (integration), 🔒 Security, 🐳 Build, 🔒 Image Scan |
| `deployment` | 🔒 Gitleaks (Secret-Scan; `staging.yml` hat keinen `pull_request`-Trigger, kann kein Required-Check sein) |
| `moodle_appstore`, `self-service-ui` | keine — externe Fork-CI, Job-Namen/Verhalten nicht verifiziert, deshalb nur PR-Pflicht ohne Required-Check |

Approval-Anzahl ist aktuell `0` (kein zweites Augenpaar erzwungen) —
bewusst niedrig gehalten, weil das Team klein ist; kann später erhöht
werden, sobald das im Alltag als zu locker auffällt.

### 3.2 Server (`appstore-prod-01`) — die eigentliche Governance-Frage

Der heutige Zustand: der einzige SSH-Zugang ist der `ubuntu`-User mit
**passwortlosem Sudo** — dasselbe Login für Menschen und (potenziell)
für einen Agenten. Das ist der Punkt, an dem "wer darf mit dem Agenten
reden" und "was darf der Agent tun" zusammenlaufen, deshalb hier im
Detail:

**Wer darf mit einem Server-Agenten sprechen — SSH war der erste
Entwurf, Discord ist die bewusste Revision.** Diese Datei legte
zunächst fest: kein Chat-Bot, kein Web-Interface, kein zusätzlicher
Dienst mit eigener Angriffsfläche, Zugriff exakt deckungsgleich mit
GitHub-Org-Mitgliedschaft plus hinterlegtem Public Key. Das beantwortet
"nur wir, keine Externen" ohne einen zusätzlichen Auth-Layer — und
gilt unverändert für alles, was diesen Server sonst betrifft
(Deployment, Diagnose per Hand).

Für den Agenten selbst wurde das revidiert: **Discord ist der
tatsächliche Kommunikationsweg des Teams**, SSH ist es nicht. Ein
Chat-Interface, das niemand benutzt, ist keine Sicherheit, nur
Reibung. Die Regel ist deshalb nicht mehr "kein Netzwerk-Endpoint",
sondern **"ein Netzwerk-Endpoint mit einer echten Allowlist, kein
offener"**:

- `DISCORD_ALLOWED_USERS` (Discord-User-IDs, kommagetrennt) ist die
  tatsächliche Zugriffsgrenze — jede Nachricht durchläuft diese Prüfung,
  bevor sie überhaupt zur Session wird.
- Der Bot selbst bleibt auf Discord-Seite **"Public Bot: OFF"** —
  einladbar nur über eine manuell konstruierte URL, nicht über den
  öffentlichen Discord-Installations-Flow. Das ist die zweite Hälfte
  der Grenze: selbst wer die Allowlist umgehen wollte, kann den Bot
  gar nicht erst in einen fremden Server einladen.
- Start-Allowlist: nur der Betreiber selbst (Stand
  Ersteinrichtung), weitere Org-Mitglieder werden einzeln über ihre
  Discord-User-ID ergänzt, nicht pauschal für "jeder in der Org"
  geöffnet.
- SSH bleibt parallel bestehen — Discord ersetzt es nicht, es ist ein
  zusätzlicher, aber ebenso begrenzter Kanal zum selben Agenten.

**Was der Agent auf dem Server darf — Hermes ist der eine Agent, kein
zweiter Host-User daneben.** Ein früherer Entwurf sah einen separaten
`claude-agent`-Systemuser vor (Mitglied der `docker`-Gruppe, ohne
`sudo`, eigener `ed25519`-Key) — bewusst wieder verworfen: zwei
parallele Agent-Identitäten auf demselben Host (ein Claude-Code-Login
per SSH *und* Hermes im Container) hätten zwei Guardrail-Flächen
bedeutet, die im Alltag auseinanderlaufen können, ohne einen
zusätzlichen Nutzen zu bringen. **Hermes selbst ist der Server-Agent**
— er läuft bereits containerisiert, mit dem gemounteten
`docker.sock` als seinem einzigen direkten Systemzugriff (siehe System
2.1), erreichbar über SSH (Mensch) oder Discord (Hermes selbst, System
oben).

**Das reicht allein nicht als Sandbox, und das wird hier nicht
verschwiegen:** der `docker.sock`-Mount macht den Container, der ihn
hält (`podman-mcp`), selbst root-äquivalent zum Host — `docker run -v
/:/host ...` gibt vollen Host-Dateisystemzugriff, unabhängig davon, in
welchem Container das ausgeführt wird. Das ist kein
Konfigurationsfehler, sondern wie Docker grundsätzlich funktioniert.
Ein separater Linux-User hätte daran nichts geändert — er hätte nur
Audit-Spuren getrennt, nicht die eigentliche Rechte-Grenze verschoben.

Die tatsächliche Grenze ist deshalb nicht der Linux-User, sondern
**der MCP-Tool-Filter in `agent/config.yaml`** (System 2.1): Hermes
sieht nur `container_list`/`container_inspect`/`container_logs`, alles
andere ist nicht als Tool vorhanden, egal wie mächtig `podman-mcp`
selbst wäre. Ergänzend dazu: **PreToolUse-Hooks auf Claude-Code-Seite**
für den Fall, dass ein Mensch (oder ein zukünftiger Claude-Code-Agent)
direkt per SSH auf dem Server arbeitet — eine feste Allowlist erlaubter
`docker`-Unterbefehle (`ps`, `logs`, `compose logs`, `compose restart
<name>` mit Namen aus einer festen Liste), alles andere wird geblockt,
bevor es überhaupt die Shell erreicht. Beide Mechanismen spiegeln
dieselbe Allowlist an zwei verschiedenen Zugriffspunkten (Hermes über
MCP, ein Mensch/Claude-Code über SSH), nicht zwei unabhängige
Konzepte.

**Nie unabhängig vom Menschen:** Alembic-Migrationen laufen nie
automatisiert gegen staging/prod, egal welcher User sie ausführt —
immer mit expliziter menschlicher Bestätigung im selben Moment.

---

## 4. Engineering-Loop — ECC und Superpowers im Detail

Nicht "irgendein Regelwerk", sondern zwei konkrete, bestehende
Skill-Quellen, plus was aus jeder davon tatsächlich übernommen wird.

### 4.1 Everything Claude Code (ECC)

Basis-Layout für `.claude/agents/`, `.claude/hooks/`, Rule-Struktur.
Übernommen wird das Grundgerüst — konkret, nicht der komplette
68+-Agenten-Katalog: `.github/.claude/agents/code-reviewer.md`,
adaptiert aus
[affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)s
gleichnamigem Agenten. Struktur übernommen (Prompt-Defense-Baseline,
Confidence-basierte Findings-Filterung mit Pre-Report-Gate, Approval-
Kriterien), Inhalt ersetzt: das Original ist auf React/Next.js/Node
zugeschnitten, unser Stack ist Vue 3 + Python/Poetry +
Terraform/OpenStack + Docker Compose — die Checklisten sind komplett
neu auf diese vier Bereiche gemappt, inklusive eines projektspezifischen
Punkts (Erweiterung einer MCP-Tool-Allowlist in `agent/config.yaml`
oder Lockerung von `appstore-prod-guardrail.py` gilt automatisch als
CRITICAL, siehe System 3).

**Ablageort:** `.github/.claude/agents/code-reviewer.md` — als universelles
Review-Tool für alle Repos liegt der Agent zentral im `.github`-Repo der
Organisation, nicht versteckt im `deployment`-Repo.

Bewusst NICHT übernommen: der `architect`-Agent aus ECC — würde
größtenteils duplizieren, was `claude_docs/decisions/` pro Repo bereits
festhält, und der komplette Node-basierte Installer (`install.sh`) —
zu viel Umfang für Einzel-Repo-Kontext, siehe "Nicht übernommen" unten.
Wo Python (Ruff-Konventionen) und TypeScript (Vite/Vue-Konventionen)
eigene Regeln brauchen, liegen die weiterhin in
`claude_docs/architecture/` des jeweiligen Repos, nicht in einer
globalen Regel, die für beide Sprachen gleich sein müsste.

### 4.2 Superpowers ([obra/superpowers](https://github.com/obra/superpowers), 287k★)

Community-Skill-Sammlung, per Referenz genutzt (verlinkt aus unseren
eigenen Skills, nicht kopiert — bei einem 287k★-Projekt mit eigenem
Update-Rhythmus ist eine Kopie sofort veraltet):

- **[`test-driven-development`](https://github.com/obra/superpowers/blob/main/skills/test-driven-development/SKILL.md)**
  — liefert das Prinzip ("NO PRODUCTION CODE WITHOUT A FAILING TEST
  FIRST"), unser eigener `.github/.claude/skills/tdd/SKILL.md`
  verlinkt darauf und liefert nur noch das repo-spezifische Wie (welche
  CLI-Befehle in backend/worker/frontend).
- **[`systematic-debugging`](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)**
  — "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST", verlinkt aus
  `/diagnose-production`. Genau das Muster, mit dem die vier
  `podman-mcp`-Bugs in 2.1 gefunden wurden (Quellcode lesen statt aus
  der Fehlermeldung raten) — kein Zufall, sondern der Grund, warum
  dieser Skill hier zitiert wird und nicht nur als gute Idee dasteht.
- **`brainstorming`** — für Architekturentscheidungen, bevor sie in
  `claude_docs/decisions/` landen. Noch nicht in einen eigenen Skill
  eingebunden (kein konkreter Anwendungsfall bisher, anders als TDD und
  Debugging, die schon real gebraucht wurden).

Nicht übernommen: alles, was auf einen Einzel-Repo-Kontext ausgelegt
ist und unsere Sechs-Repo-Struktur ignoriert (z. B. Skills, die von
einem einzigen `CLAUDE.md` als Wissensquelle ausgehen).

### 4.3 Verifikation — `/tdd`

`.github/.claude/skills/tdd/SKILL.md`, verzweigt nach Sprache:
`pytest` für backend/worker (Poetry-basiert; worker zusätzlich mit
Black+isort neben Ruff, backend nur Ruff), `vitest` + `vue-tsc` für
frontend. Loop: Test rot → minimal implementieren → grün → Refactor →
volle Suite → erst dann als fertig melden. CI-Stand: `ci.yml` in
backend/frontend/worker (Ruff-Lint + Pytest gegen Postgres-Service),
`secret-scan.yml` + `staging.yml` in `deployment` — jetzt mit
Branch-Protection (Abschnitt 3.1) tatsächlich Merge-Pflicht, nicht nur
vorhanden.

**Organisations- vs. Deployment-Skills:**
- **Universelle Entwicklungs-Skills (`.github/.claude/skills/`):**
  `/tdd` und `/ship-feature` gelten repo-übergreifend und liegen im
  zentralen `.github`-Repo.
- **Host- & Deployment-spezifische Ops-Skills (`deployment/.claude/skills/`):**
  `/deploy-status`, `/diagnose-production`, `/restart-service` und der
  `appstore-prod-guardrail.py`-Hook steuern direkt die `appstore-prod-01`-VM
  und Docker Compose und verbleiben deshalb im `deployment`-Repo.

---

## 5. Autonomer Feature-Loop — die Kette, nicht nur die Teile

Die Systeme 1–4 sind Fähigkeiten. Dieses System ist die **Verkettung**:
was tatsächlich passiert, nachdem eine Anforderung spezifiziert wurde,
bis sie geprüft im Einsatz ist — und an welchen Stellen ein Mensch
zwingend bestehen muss, statt dass der Agent einfach weiterläuft.

### 5.1 Der Loop

```
Anforderung spezifiziert
  │
  ├─► Branch anlegen                                  [System 1: claude_docs/ lesen — Kontext, Grenzen, bekannte Fallstricke]
  │
  ├─► TDD-Loop (System 4)                              Test rot → Implementierung → grün → Refactor
  │     └─ bei Unklarheit: Graphify-Query (System 1)   statt Vermutung über Code-Struktur
  │
  ├─► Pull Request öffnen
  │
  ├─► CI-Gate (System 3.1)                             Lint + Test müssen grün sein
  │     └─ ✅ durchgesetzt — Required-Status-Checks in Branch-Protection
  │
  ├─► Merge auf main                                   ── MENSCHLICHE FREIGABE, siehe 5.2 ──
  │
  ├─► Staging-Deploy — AUTOMATISCH                     bereits heute so: deployment/staging.yml
  │     triggert bei push auf main                      läuft bei jedem Merge, kein Zutun nötig
  │
  ├─► Verifikation auf Staging (System 2)               /diagnose-production gegen Staging,
  │                                                      nicht nur gegen Prod
  │
  └─► Prod-Promotion                                   ── MENSCHLICHE FREIGABE, siehe 5.2 ──
        kein automatischer Trigger vorhanden
        (kein prod.yml mit push-Trigger existiert —
         das ist heute schon so, nicht neu eingeführt)
```

Der Agent kann diesen Loop **selbstständig durchlaufen** von der
Spezifikation bis zur Staging-Verifikation. Die Kette bricht nicht,
weil ihm ein Werkzeug fehlt, sondern an zwei bewusst gesetzten
Freigabepunkten.

### 5.2 Wo ein Mensch bestehen muss, und warum genau dort

**Vor dem Merge auf `main`.** Nicht weil der TDD-Loop dem Agenten
nicht zugetraut wird, sondern weil der Merge der Punkt ist, an dem
Staging *automatisch* deployed (5.1) — ein Fehler hier pflanzt sich
ohne weiteres Zutun fort. Ein Mensch bestätigt den PR, danach läuft
alles bis Staging von selbst.

**Vor der Prod-Promotion.** Staging-Verifikation durch den Agenten
(System 2) ersetzt keine menschliche Prüfung, weil `appstore-prod-01`
ein Live-System mit eingeschriebenem Nutzerzustand ist (Keycloak-Realm,
laufende Deployments Dritter) — ein Rollback auf Staging kostet
nichts, auf Prod kostet er echte Nutzungsunterbrechung.

**Nicht an weiteren Stellen.** Insbesondere nicht vor dem PR-Öffnen
und nicht vor dem CI-Gate selbst — beides sind reversible, risikofreie
Schritte, ein Mensch dort einzubinden würde nur Latenz ohne
Sicherheitsgewinn hinzufügen. Genau diese Beschränkung auf zwei
Stellen ist der Unterschied zwischen "Agent arbeitet zu" und "Agent
läuft eigenständig los" — jede zusätzliche Freigabestufe wäre wieder
Handarbeit unter neuem Namen.

**Alembic-Migrationen sind ein Sonderfall innerhalb dieser Kette:**
selbst wenn CI grün ist und ein Mensch den Merge freigegeben hat, läuft
eine Schema-Migration gegen eine geteilte Datenbank (staging oder prod)
nie ohne zusätzliche, migration-spezifische Bestätigung im selben
Moment — das steht bereits in System 3, gilt hier unverändert weiter.

### 5.3 Was das für "ohne Degradierung der Codebasis" konkret heißt

Die Anforderung, dass die Codebasis dabei nicht degradiert, ist keine
zusätzliche Regel, sondern die Summe von drei bereits bestehenden
Systemen, hier nur einmal explizit zusammengeführt:

- **System 4** stellt sicher, dass neuer Code getestet ist, bevor er
  überhaupt einen PR erreicht.
- **System 3.1** (Branch-Protection, ✅ gesetzt) stellt sicher, dass
  kein Code ohne grüne CI auf `main` landet — unabhängig davon, ob ein
  Mensch oder ein Agent den Merge-Button drückt.
- **System 1** (`claude_docs/decisions/` + `log/`) stellt sicher, dass
  der nächste Durchlauf des Loops — egal ob derselbe Agent in einer
  neuen Session oder ein anderes Teammitglied — den Grund für
  vergangene Entscheidungen kennt, statt sie versehentlich rückgängig
  zu machen.

Der zweite Punkt ist damit eine durchgesetzte Regel, keine Konvention
mehr — der Server-Zugang (System 3.2) ist jetzt der größte
verbleibende Guardrail, siehe Statusabschnitt.

### 5.4 Der Agent als Deploy-Werkzeug, nicht nur als Zaungast

Bisher lief der gesamte Deploy-Teil der Kette (Staging automatisch,
Prod manuell) ausschließlich über GitHub Actions — der Agent
beobachtet nur (System 2: `/deploy-status`, `/diagnose-production`).
Hermes selbst (System 3.2) ist das Werkzeug, das diese Rolle
erweitert: **nach** einer menschlichen Freigabe kann Hermes über seine
MCP-Tools aktiv werden, statt dass ein Mensch die letzte Meile
händisch nachvollzieht:

- Staging-Verifikation direkt gegen die laufenden Container statt nur
  gegen CI-Logs (`container_list`/`container_logs` über `podman-mcp`).
- Nach expliziter Prod-Freigabe: ein enger begrenzter Restart-Schritt
  (`/restart-service`, System 2), sobald dieser Skill existiert —
  aktuell hat Hermes nur Lesezugriff (System 2.1: `container_run` und
  `container_stop` sind bewusst nicht in der Allowlist).

**Das verschiebt nicht die Freigabegrenze aus 5.2** — der Mensch gibt
weiterhin frei, *bevor* irgendeine Prod-Aktion stattfindet. Es
verschiebt nur, *wer die Tasten drückt*, nachdem freigegeben wurde:
statt eines Menschen mit vollem `ubuntu`+Sudo-Zugang übernimmt Hermes
über eine explizite MCP-Tool-Allowlist die Ausführung — enger als das,
was ein Mensch mit Sudo-Zugriff tun könnte, weil die Allowlist auf
Tool-Ebene sitzt, nicht auf Shell-Ebene.

---

## Bewusst nicht Teil des Harness

Diese Punkte wurden geprüft und **abgelehnt** — nicht "später
vielleicht", sondern eine getroffene Entscheidung, damit sie nicht
wieder aufgemacht werden muss:

- **Eigener `appstore-ops`-MCP-Server.** Zu viel Bau- und
  Wartungsaufwand gegenüber den drei bestehenden MCPs in System 2.
- **~~Chat-/Web-Endpoint für den Server-Agenten~~ — revidiert, siehe
  3.2.** Diese Ablehnung galt bis zur Discord-Integration: Discord ist
  der tatsächliche Kommunikationsweg des Teams, SSH ist es nicht, und
  ein Kanal mit echter User-Allowlist plus einem nicht öffentlich
  auffindbaren Bot ist kein offener Endpunkt. Weiterhin abgelehnt:
  ein Web-UI (Keycloak-gesichert oder sonst) — dafür gibt es keinen
  vergleichbaren Bedarf, Discord deckt den Anwendungsfall bereits ab.
- **Alternative Agent-Runtime auf dem Server** (z. B. ein
  Open-Weights-Modell wie Nous Hermes statt Claude Code, wegen
  potenzieller Lernfähigkeit/Fine-Tuning über Zeit). Reine
  Forschungsfrage ohne konkreten Plan — nicht Teil des aktuellen
  Harness. Falls das später verfolgt wird, gehört es als eigener
  Abschnitt hierher, mit einem echten Vergleich statt einer Idee.
- **GCC (Git Context Controller)** als separates Tool. Ersetzt durch
  `claude_docs/HANDOVER.md` (Abschnitt 1.2) — ein einzelnes, lebendes
  Übergabedokument löst dasselbe Problem ohne Kontext-Fragmentierung und
  ohne ein zusätzliches System.
- **Manuelle Markdown-API-Contracts** (`api-contracts.md`). Ersetzt durch
  die automatische OpenAPI-3.1-Schnittstellengenerierung aus FastAPI
  (Abschnitt 1.3) als Single Source of Truth.

---

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

---

## Status (Stand 2026-09-17, modernisiertes Harness & Bereinigung)

| System | Status |
|---|---|
| 1 · Wissen | ✅ `claude_docs/` in allen Repos; `HANDOVER.md` als lebendes Übergabedokument eingeführt (ersetzt fragmentierte Wochenlogs); OpenAPI 3.1 als automatisierte Single Source of Truth für API-Contracts; Graphify-Graphen committet |
| 2 · Deployment-Ops-Skills | ✅ `podman-mcp` läuft produktiv (2.1); `github-mcp-server`/`python-openstackmcp-server` vollständig konfiguriert; Ops-Skills verbleiben spezifisch im `deployment`-Repo (`/diagnose-production`, `/deploy-status`, `/restart-service`) |
| 3 · Zugriff & Guardrails | ✅ Org-Write-Zugriff, Branch-Protection in allen sechs Repos, Server-Agent-Zugang läuft (Hermes + Discord-Allowlist), PreToolUse-Hook für direkten SSH-Zugriff (`appstore-prod-guardrail.py`) |
| 4 · Engineering-Loop | ✅ Universeller ECC-`code-reviewer`-Agent und `/tdd`-Skill ins zentrale `.github`-Repo umgezogen (`.github/.claude/`); Superpowers per Referenz eingebunden |
| 5 · Autonomer Feature-Loop | ✅ Kette vollständig: `/ship-feature` ins zentrale `.github`-Repo umgezogen; verbindet claude_docs/ (1) → TDD + Code-Review (4) → CI-Gate (3.1) → menschliche Freigabepunkte (5.2) |

**Was in dieser Runde fertig wurde:**
1. **Lebendes Übergabedokument (`HANDOVER.md`):** Die fehleranfälligen,
   fragmentierten Wochenlogs (`claude_docs/log/YYYY-Wxx.md`) wurden durch
   ein einzelnes, lebendes Übergabedokument `claude_docs/HANDOVER.md` pro
   Repo ersetzt. Jede Session startet dort und schließt dort ab.
2. **OpenAPI-first statt manueller API-Contracts:** Verzicht auf veraltende
   Markdown-Dateien (`api-contracts.md`, `task-contracts.md`). FastAPI dient
   als Single Source of Truth mit automatisierter Schema-Generierung und
   Export (`backend/scripts/export_openapi.py`).
3. **Verschiebung universeller Dateien nach `.github`:** Die universellen
   Entwickler-Werkzeuge (`code-reviewer.md`, `/tdd`, `/ship-feature`) wurden
   aus `deployment/.claude/` in das zentrale `.github/.claude/`-Repo verschoben.
   `deployment` behält nur die tatsächlich VM- und deploymentspezifischen
   Ops-Skills (`/deploy-status`, `/diagnose-production`, `/restart-service`,
   Guardrail-Hook).

**Verbleibend, kein Blocker mehr:**

1. **github-mcp-server / python-openstackmcp-server aktivieren**,
   sobald ein `GITHUB_TOKEN` (read-only PAT) bzw. eine
   lese-beschränkte `clouds.yaml` vorliegen.
2. **`brainstorming`-Skill aus Superpowers einbinden**, sobald ein
   konkreter Anwendungsfall ansteht.

**Bekannte, nicht behebbare Lücke:** `members_can_delete_repositories`
/ `members_can_change_repo_visibility` lassen sich über die GitHub-API
auf diesem Plan nicht deaktivieren.
