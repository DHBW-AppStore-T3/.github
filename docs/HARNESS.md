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

### 1.1 `claude_docs/` — tief geschachtelt, mit eingebautem Log

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
│   ├── auth.md            # Keycloak-Integration, Token-Flow
│   └── api-contracts.md   # welche Endpunkte frontend/worker konsumieren
├── decisions/
│   ├── 2026-03-fastapi-vs-django.md
│   └── ...                # ein Eintrag pro architektur-relevanter Entscheidung
├── debugging/
│   ├── common-errors.md
│   └── local-setup-gotchas.md
└── log/
    └── 2026-W38.md         # laufendes Änderungsprotokoll, siehe 1.2
```

**`worker/claude_docs/`** — gleiches Muster, aber `architecture/`
verschiebt sich auf das, was dort tatsächlich komplex ist:
```
architecture/
├── overview.md
├── task-contracts.md       # Celery-Task-Namen + Payload-Schema, das backend aufruft
├── queues.md                # RabbitMQ-Routing, Retry-Verhalten
└── sse-streaming.md         # Redis-Pub/Sub → Server-Sent-Events ans Frontend
```

**`frontend/claude_docs/`**
```
architecture/
├── overview.md
├── state.md                 # Pinia-Stores, welcher State wo lebt
├── api-client.md             # Axios-Setup, wie Backend-Fehler gemapped werden
└── routing.md
```

**`deployment/claude_docs/`** — kein Code zum Debuggen, sondern
Dienste in fester Reihenfolge, deshalb andere Unterordner:
```
claude_docs/
├── topology/
│   ├── environments.md      # dev / staging / prod, was sie unterscheidet
│   ├── boot-order.md        # Caddy → Keycloak → backend → worker → frontend
│   └── networking.md        # welcher Dienst spricht mit welchem, welche Ports
├── decisions/
├── rollback/
│   ├── database.md           # Alembic-Downgrade-Pfad
│   └── service.md            # einzelnen Container zurückrollen
└── log/
```

`moodle_appstore` und `self-service-ui` bekommen vorerst nur ein
flaches `claude_docs/` (architecture.md, decisions.md) — sie sind
Referenz-/Integrationsrepos, keine aktiv weiterentwickelten
Kernservices; das wird nachgezogen, sobald sich das ändert.

Jedes root-`CLAUDE.md` bleibt dünn und verlinkt nur in die passenden
Unterordner statt Inhalte zu duplizieren.

### 1.2 `claude_docs/log/` — der GCC-Ersatz

Statt eines Git Context Controllers, der Commit-Historie nachträglich
strukturiert: **jede Session, die etwas architekturrelevantes ändert,
schreibt einen Eintrag in `claude_docs/log/<jahr>-W<kalenderwoche>.md`**
(ISO-Wochennummer, z. B. `2026-W38.md`), bevor sie endet. Eine Datei
pro Kalenderwoche statt pro Monat, weil in aktiven Wochen mehrere
Sessions mit eigenen Einträgen zusammenkommen und eine Monatsdatei
dann schnell unübersichtlich wird, während ruhige Wochen einfach keine
Datei erzeugen. Ein Eintrag ist kurz — Datum, was sich geändert hat,
warum, was der Stand am Ende war:

```markdown
### 2026-09-15 — CORS_ORIGINS Fix gemerged, Remotes auf T3 korrigiert
Lokale Remotes zeigten auf die falsche, gleichnamige Org
(DHBW-AppStore statt DHBW-AppStore-T3). Divergenz gemerged (1 Commit
von T3, 30 von hier), auf T3 gepusht, alle vier Remotes umgebogen.
Stand danach: alle Repos zeigen korrekt auf DHBW-AppStore-T3.
```

Das löst dasselbe Problem, das GCC lösen würde — Kontext über Sessions
hinweg, ohne dass jemand die Git-Historie durchforsten muss — aber
ohne ein zusätzliches Tool: es ist nur Disziplin plus eine
Ordnerkonvention. Der Unterschied zu `decisions/`: `log/` ist
chronologisch und auch für kleinere, nicht architekturrelevante
Ereignisse gedacht (Repo-Reparaturen, Guardrail-Änderungen,
Recherche-Ergebnisse); `decisions/` ist thematisch und nur für Dinge,
die eine spätere Entscheidung beeinflussen.

### 1.3 Graphify — global über alle sechs Repos, nicht nur pro Repo

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
| [`avinas234/openstack-mcp`](https://github.com/avinas234/openstack-mcp) | 70+ **read-only** Tools für OpenStack (Server-Liste, Quotas, Volumes) | rein lesend konzipiert — passt zur Governance-Regel unten, keine schreibenden OpenStack-Aktionen über den Agenten |

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

---

## 3. Zugriff & Guardrails — durchgesetzt, nicht dokumentiert

Zwei Ebenen, ein System: GitHub-Org und Server. Die Kernfrage auf
beiden Ebenen ist dieselbe — **kann ein Agent (oder ein Mensch über
den Agenten) mehr, als er für seine Aufgabe braucht?**

### 3.1 GitHub-Org

| Einstellung | Zustand | Bewertung |
|---|---|---|
| `default_repository_permission` | `write` | ✅ gesetzt — alle 6 Mitglieder pushen in alle 6 Repos ohne Einzel-Einladung |
| Branch-Protection auf `main` | fehlt in **allen sechs Repos** | 🔴 größte Lücke — macht jeden Pre-Merge-CI-Check wirkungslos, weil ein Direct-Push ihn umgeht |
| `members_can_delete_repositories` | `true`, über API nicht abschaltbar | 🔴 bekannte, nicht behebbare Plan-Einschränkung (PATCH gibt `200 OK`, Wert bleibt) |
| `members_can_change_repo_visibility` | `true`, gleiche Einschränkung | 🔴 dito |

Zielzustand für Branch-Protection (sobald umgesetzt): Pull Request
vor Merge auf `main` in allen sechs Repos, mindestens ein
Required-Status-Check (`ci.yml` bzw. `secret-scan.yml` +
`staging.yml` bei `deployment`), kein Force-Push auf `main`.

### 3.2 Server (`appstore-prod-01`) — die eigentliche Governance-Frage

Der heutige Zustand: der einzige SSH-Zugang ist der `ubuntu`-User mit
**passwortlosem Sudo** — dasselbe Login für Menschen und (potenziell)
für einen Agenten. Das ist der Punkt, an dem "wer darf mit dem Agenten
reden" und "was darf der Agent tun" zusammenlaufen, deshalb hier im
Detail:

**Wer darf mit einem Server-Agenten sprechen — SSH-only, kein
Netzwerk-Endpoint.** Kein Chat-Bot, kein Web-Interface, kein
zusätzlicher Dienst mit eigener Angriffsfläche. Zugriff ist exakt
deckungsgleich mit GitHub-Org-Mitgliedschaft plus hinterlegtem
Public Key — wer nicht in der Org ist, kommt nicht auf den Server,
unabhängig davon, ob dort ein Agent läuft oder nicht. Das beantwortet
"nur wir, keine Externen" vollständig, ohne einen zusätzlichen
Auth-Layer zu brauchen.

**Was der Agent auf dem Server darf — eigener User, aber ehrlich
begrenzt.** Zielzustand: ein `claude-agent`-Systemuser, Mitglied der
`docker`-Gruppe, ohne `sudo`, mit eigenem `ed25519`-Key statt des
geteilten `ubuntu`-Keys.

**Das reicht allein nicht als Sandbox, und das wird hier nicht
verschwiegen:** Mitgliedschaft in der `docker`-Gruppe ist selbst
root-äquivalent — `docker run -v /:/host ...` gibt vollen
Host-Dateisystemzugriff, unabhängig vom Linux-User. Das ist kein
Konfigurationsfehler, sondern wie Docker grundsätzlich funktioniert.
Der eigene User trennt also Audit-Spuren (wessen Aktion war das) und
verhindert versehentliche `sudo`-Nutzung, ist aber **keine Grenze
gegen absichtlichen oder fehlerhaften destruktiven Einsatz**.

Die tatsächliche Grenze sind **PreToolUse-Hooks auf Claude-Seite**:
eine feste Allowlist erlaubter `docker`/`podman`-Unterbefehle (`ps`,
`logs`, `compose logs`, `compose restart <name>` mit Namen aus einer
festen Liste), alles andere wird geblockt, bevor es überhaupt die
Shell erreicht. Die Skills aus System 2 (`/restart-service` etc.)
spiegeln dieselbe Allowlist — Hook und Skill sind zwei Formulierungen
derselben Grenze, nicht zwei unabhängige.

**Nie unabhängig vom Menschen:** Alembic-Migrationen laufen nie
automatisiert gegen staging/prod, egal welcher User sie ausführt —
immer mit expliziter menschlicher Bestätigung im selben Moment.

---

## 4. Engineering-Loop — ECC und Superpowers im Detail

Nicht "irgendein Regelwerk", sondern zwei konkrete, bestehende
Skill-Quellen, plus was aus jeder davon tatsächlich übernommen wird.

### 4.1 Everything Claude Code (ECC)

Basis-Layout für `.claude/agents/`, `.claude/hooks/`, Rule-Struktur.
Übernommen wird das Grundgerüst; wo Python (Ruff-Konventionen) und
TypeScript (Vite/Vue-Konventionen) eigene Regeln brauchen, liegen die
in `claude_docs/architecture/` des jeweiligen Repos, nicht in einer
globalen Regel, die für beide Sprachen gleich sein müsste.

### 4.2 Superpowers ([obra/superpowers](https://github.com/obra/superpowers))

Community-Skill-Sammlung. Relevant für uns, konkret:

- **Brainstorming-Skill** — für Architekturentscheidungen, bevor sie
  in `claude_docs/decisions/` landen.
- **TDD-/Verification-Skills** — Basis für den sprachspezifischen Loop
  unten, statt ihn komplett neu zu schreiben.
- **Debugging-Workflow-Skills** — Vorlage für die
  `claude_docs/debugging/`-Einträge, damit sie alle demselben Muster
  folgen (Symptom → Reproduktion → Ursache → Fix → wie man es beim
  nächsten Mal schneller findet).

Nicht übernommen: alles, was auf einen Einzel-Repo-Kontext ausgelegt
ist und unsere Sechs-Repo-Struktur ignoriert (z. B. Skills, die von
einem einzigen `CLAUDE.md` als Wissensquelle ausgehen).

### 4.3 Verifikation

Ein Skill, der nach Sprache verzweigt: `pytest` für backend/worker
(Poetry-basiert), `vitest` für frontend. Loop: Test rot → minimal
implementieren → grün → Refactor → volle Suite → erst dann als fertig
melden. CI-Stand heute: `ci.yml` in backend/frontend/worker
(Ruff-Lint + Pytest gegen Postgres-Service), `secret-scan.yml` +
`staging.yml` in `deployment` — vorhanden, aber ohne Branch-Protection
(Abschnitt 3.1) nicht Merge-Pflicht.

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
  │     └─ 🔴 heute nicht erzwungen — Branch-Protection fehlt, siehe Status
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
- **System 3.1** (sobald Branch-Protection steht) stellt sicher, dass
  kein Code ohne grüne CI auf `main` landet — unabhängig davon, ob ein
  Mensch oder ein Agent den Merge-Button drückt.
- **System 1** (`claude_docs/decisions/` + `log/`) stellt sicher, dass
  der nächste Durchlauf des Loops — egal ob derselbe Agent in einer
  neuen Session oder ein anderes Teammitglied — den Grund für
  vergangene Entscheidungen kennt, statt sie versehentlich rückgängig
  zu machen.

Ohne Branch-Protection (Status: fehlt) ist der zweite Punkt aktuell
nur eine Konvention, keine durchgesetzte Regel — das ist der Grund,
warum sie weiterhin an erster Stelle der offenen Punkte steht.

### 5.4 Der Agent als Deploy-Werkzeug, nicht nur als Zaungast

Bisher lief der gesamte Deploy-Teil der Kette (Staging automatisch,
Prod manuell) ausschließlich über GitHub Actions — der Agent
beobachtet nur (System 2: `/deploy-status`, `/diagnose-production`).
Der `claude-agent`-SSH-Zugang aus System 3.2 ist aber genau das
Werkzeug, das diese Rolle erweitert: **nach** einer menschlichen
Freigabe kann der Agent selbst auf `appstore-prod-01` aktiv werden,
statt dass ein Mensch die letzte Meile händisch nachvollzieht:

- Staging-Verifikation direkt gegen die laufenden Container statt nur
  gegen CI-Logs (`ssh` + Allowlist-Befehle aus System 3.2).
- Nach expliziter Prod-Freigabe: den eigentlichen Rollout-Schritt
  ausführen (z. B. Compose-Pull + Restart über die feste Allowlist),
  statt dass diese Aktion nur manuell am Server passiert.

**Das verschiebt nicht die Freigabegrenze aus 5.2** — der Mensch gibt
weiterhin frei, *bevor* irgendeine Prod-Aktion stattfindet. Es
verschiebt nur, *wer die Tasten drückt*, nachdem freigegeben wurde:
statt eines Menschen mit vollem `ubuntu`+Sudo-Zugang übernimmt der
`claude-agent`-User mit der PreToolUse-Allowlist aus System 3.2 die
Ausführung — was tendenziell sicherer ist als der heutige Zustand,
weil die Allowlist enger ist als das, was ein Mensch mit Sudo-Zugriff
tun könnte.

---

## Bewusst nicht Teil des Harness

Diese Punkte wurden geprüft und **abgelehnt** — nicht "später
vielleicht", sondern eine getroffene Entscheidung, damit sie nicht
wieder aufgemacht werden muss:

- **Eigener `appstore-ops`-MCP-Server.** Zu viel Bau- und
  Wartungsaufwand gegenüber den drei bestehenden MCPs in System 2.
- **Chat-/Web-Endpoint für den Server-Agenten** (z. B. Slack-Bot,
  Keycloak-gesichertes Web-UI). SSH-only deckt die Zugriffsfrage
  bereits vollständig ab; ein zusätzlicher Dienst wäre nur zusätzliche
  Angriffsfläche ohne zusätzlichen Nutzen.
- **Alternative Agent-Runtime auf dem Server** (z. B. ein
  Open-Weights-Modell wie Nous Hermes statt Claude Code, wegen
  potenzieller Lernfähigkeit/Fine-Tuning über Zeit). Reine
  Forschungsfrage ohne konkreten Plan — nicht Teil des aktuellen
  Harness. Falls das später verfolgt wird, gehört es als eigener
  Abschnitt hierher, mit einem echten Vergleich statt einer Idee.
- **GCC (Git Context Controller)** als separates Tool. Ersetzt durch
  `claude_docs/log/` (Abschnitt 1.2) — löst dasselbe Problem ohne ein
  zusätzliches System.

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

## Status (Stand 2026-09-15)

| System | Status |
|---|---|
| 1 · Wissen | offen — kein geschachteltes `claude_docs/` in irgendeinem Repo; nur `worker/graphify-out/` existiert, kein Cross-Repo-Graph, `.gitattributes` mit Merge-Driver liegt lokal vor, aber uncommitted |
| 2 · Deployment-Ops-Skills | offen — keiner der drei MCPs (github, podman, openstack) ist angebunden, keine Skills geschrieben |
| 3 · Zugriff & Guardrails | teilweise — Org-Write-Zugriff ✅ gesetzt; Branch-Protection fehlt überall; Server-Zugang nur über geteilten `ubuntu`+Sudo-User, kein `claude-agent`-User, keine PreToolUse-Hooks |
| 4 · Engineering-Loop | offen — ECC-Grundgerüst nicht eingezogen, Superpowers nicht evaluiert, kein `/tdd`-Skill |
| 5 · Autonomer Feature-Loop | offen — Kette existiert bereits teilweise (Staging-Auto-Deploy bei Push auf `main` läuft schon), aber ohne Systeme 1–4 hat der Agent weder die Werkzeuge noch die Guardrails, um den Loop tatsächlich selbst zu durchlaufen |

**Die vier größten offenen Punkte, in Reihenfolge:**

1. **Branch-Protection auf `main`** in allen sechs Repos — ohne das
   ist der Merge-Freigabepunkt aus System 5.2 wirkungslos.
2. **`claude-agent`-User + PreToolUse-Hooks auf `appstore-prod-01`** —
   Voraussetzung sowohl für sichere Diagnose (System 3.2) als auch für
   agentengestützte Deploy-Ausführung (System 5.4).
3. **Die drei Deployment-Ops-MCPs anbinden** (github, podman,
   openstack) und die ersten Skills (`/diagnose-production`,
   `/deploy-status`, `/restart-service`) schreiben.
4. **Den `/ship-feature`-artigen Loop-Skill schreiben** (System 5.1),
   der die ersten drei Punkte tatsächlich zu einer Kette verbindet —
   ergibt ohne 1–3 keinen Sinn, deshalb bewusst an vierter Stelle.

**Bekannte, nicht behebbare Lücke:** `members_can_delete_repositories`
/ `members_can_change_repo_visibility` lassen sich über die GitHub-API
auf diesem Plan nicht deaktivieren.
