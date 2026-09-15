# Agent-Harness für den AppStore

Dieses Dokument beschreibt, wie Claude Code (oder ein vergleichbarer
Coding-Agent) in der `DHBW-AppStore-T3`-Organisation aufgesetzt ist und
warum die Struktur so aussieht, wie sie aussieht. Es ist die Erklärung
hinter dem Setup — die Schritt-für-Schritt-Anleitung, um es selbst
aufzubauen, steht in [`GET_STARTED_WITH_HARNESS.md`](GET_STARTED_WITH_HARNESS.md).

Eine visuell aufbereitete Version dieses Konzepts (Layer-Diagramm, Status
pro Komponente) liegt als [Claude-Artifact](https://claude.ai/code/artifact/8dd27aed-ef44-4cbd-bd81-bb3874e89af2).

## Warum ein Harness und nicht nur eine CLAUDE.md

Ein Agent ist nur so gut wie das, was er über das Projekt weiß, worauf er
zugreifen kann, und welche Leitplanken ihn stoppen, bevor er etwas kaputt
macht. Eine einzelne, wachsende `CLAUDE.md` beantwortet das für ein
Ein-Repo-Projekt — der AppStore ist aber **sechs eigenständige
Git-Repositories** unter einer gemeinsamen GitHub-Organisation, jedes mit
eigenem Lebenszyklus, eigener CI und eigenem Deploy-Ziel:

| Repo | Stack | Rolle |
|---|---|---|
| [`backend`](https://github.com/DHBW-AppStore-T3/backend) | FastAPI, SQLAlchemy 2.0, PostgreSQL | REST-API, liest/schreibt App-Definitionen, stößt Deploys an |
| [`frontend`](https://github.com/DHBW-AppStore-T3/frontend) | Vue 3, Pinia, Tailwind | Web-UI für Dozierende/Studierende |
| [`worker`](https://github.com/DHBW-AppStore-T3/worker) | Celery, RabbitMQ, Redis | führt Terraform/Packer-Deploys asynchron aus, streamt Logs per SSE |
| [`deployment`](https://github.com/DHBW-AppStore-T3/deployment) | Docker Compose, Terraform, Ansible, Caddy, Keycloak, Forgejo | hält dev/staging/prod-Umgebungen zusammen |
| [`moodle_appstore`](https://github.com/DHBW-AppStore-T3/moodle_appstore) | Moodle-Fork | LTI-Integrationsziel, Prototyp für die Anbindung an echtes DHBW-Moodle |
| [`self-service-ui`](https://github.com/DHBW-AppStore-T3/self-service-ui) | Fork von [pfisterer/self-service-ui](https://github.com/pfisterer/self-service-ui) | Referenz-/Vergleichsimplementierung für Self-Service-Deploy-UIs |

Jedes dieser Repos braucht sein eigenes `claude_docs/`, aber alle sechs
teilen dieselben zehn Bausteine. Diese Datei beschreibt die zehn Bausteine
einmal; jedes Repo verlinkt hierher statt sie zu duplizieren.

## Die zehn Bausteine

Sortiert danach, **wo** ein Baustein lebt — das entscheidet, ob er
committet, als Umgebungsvariable gehalten, oder einmalig als
Architekturentscheidung getroffen wird.

### Repo-lokal (versioniert, PR-pflichtig wie jeder andere Code)

**i · Filesystem Knowledge**
Jedes Repo bekommt ein `claude_docs/` statt einer wachsenden
`CLAUDE.md`: `architecture.md`, `decisions.md`, `debugging.md`. Das Repo
`deployment` bekommt statt `debugging.md` ein `topology.md` +
`rollback.md`, weil es keinen Code zum Debuggen hat, sondern Dienste in
fester Reihenfolge hochfahren muss (Caddy → Keycloak → backend → worker →
frontend). Das root-`CLAUDE.md` jedes Repos bleibt dünn und verlinkt nur.

**iv · Repo Knowledge Graph**
Ein Graphify-Lauf pro Repo — nicht ein Monorepo-Graph, weil es kein
Monorepo gibt. `worker/graphify-out/`
existiert bereits als Referenz. Was ein einzelner Graph nicht zeigen
kann — wie backend, frontend und worker über REST-Endpunkte und
Celery-Task-Namen zusammenhängen — muss explizit in
`claude_docs/architecture.md` jedes Repos stehen.

**vii · TDD / Verification**
Ein Skill, der nach Sprache verzweigt: `pytest` für backend/worker (beide
Poetry-basiert), `vitest` für frontend. Der Loop bleibt gleich:
fehlschlagender Test → minimale Implementierung → grün → Refactor → volle
Suite → erst dann zurück an den Nutzer.

**ix · Guardrails**
Mehrschichtig, vom Harness durchgesetzt statt per Anweisung, der sich ein
Agent entziehen könnte:

1. **Claude Permissions** — Tool-Allowlist pro Session; ein Docs-Agent
   bekommt nie Schreibzugriff auf `deployment/`.
2. **PreToolUse Hooks** — blockt `docker compose -f
   docker-compose.prod.yml` außerhalb eines expliziten Deploy-Flows,
   blockt Schreibzugriffe auf jede `.env`.
3. **Org- / Git-Regeln** — Branch-Protection auf `main` in allen sechs
   Repos (Stand jetzt: **fehlt überall**, siehe Statusabschnitt unten).
4. **CI-Checks** — Lint + Test müssen vor einem Merge grün sein, nicht
   nur vorhanden.
5. **Deployment Gate** — Staging → Prod nur wenn CI grün ist;
   Alembic-Migrationen brauchen immer explizite menschliche Bestätigung.

### Machine-/Account-lokal (nie committet, pro Agent gescoped)

**ii · Tool-/Repo-Zugriff**
Credentials als Umgebungsvariablen. Ein Agent, der nur am Frontend
arbeitet, sieht nie `KEYCLOAK_ADMIN_TOKEN` oder DB-Passwörter. Auf
Org-Ebene ist `default_repository_permission: write` gesetzt — alle
Mitglieder können in alle sechs Repos pushen, ohne repo-für-repo
Einladung.

**iii · Server Claude**
Claude Code (oder ein Diagnose-Agent) auf der OpenStack-VM, mit eigener
`~/.claude/`-Konfiguration. Setzt eine laufende VM voraus — siehe
Statusabschnitt.

**v · Remote Execution**
Ein dedizierter `ed25519`-Key und ein eigener, nicht-privilegierter
`agent`-User für SSH-Zugriffe — nie dieselbe Identität, mit der ein
Mensch sich einloggt.

### Architekturentscheidung (einmal bewerten, bewusst übernehmen)

**vi · Engineering Standards**
Everything Claude Code (ECC) als Ausgangs-Template für Rules, Agents,
Skills, Hooks. Wo Python (Ruff) und TypeScript (Vite) unterschiedliche
Lint-Konventionen brauchen, sitzen die Abweichungen in `claude_docs/` des
jeweiligen Repos — ECC bleibt der gemeinsame Boden.

**viii · Observability**
Kein `observability.md` mit "schau in die Logs". Ein Skill
(`/diagnose-production`) beschreibt den Ablauf — erst Health-Check, dann
Logs des betroffenen Dienstes, dann letzte Deployments, dann Metriken.
Eine kleine CLI/MCP-Oberfläche (`get_health()`, `get_logs(service)`,
`get_deployments()`, `get_errors()`) gibt dem Skill die tatsächliche
Fähigkeit. Solange keine echte VM den Stack betreibt, ist das ein
dünner Wrapper um `docker compose logs` — kein Grafana/Loki. Das ist
bewusst so; ein echter Metrik-Stack ist eine spätere, separate
Entscheidung.

**x · Persistent Context**
GCC (Git Context Controller) würde Git-Historie als strukturierten
Kontext über Sessions hinweg verwalten. Voraussetzung — ein echtes
Git-Repo pro Service — ist jetzt erfüllt. Ob GCC für ein
Sechs-Repo-Setup mit größtenteils kurzer Historie Mehrwert bringt, ist
noch offen und wird pro Repo einzeln evaluiert, nicht org-weit
ausgerollt.

## Woher der Stack kommt

`DHBW-AppStore-T3` ist der Fork unseres Teams (Team 3) vom
`six7-click-n-deploy`-Template. `frontend`, `backend`, `worker`,
`deployment` und `.github` (dieses Doku-Repo) sind alle als Forks
markiert und teilen diese Herkunft. `DHBW-AppStore` (ohne `-T3`) ist eine
**andere** Gruppe mit demselben Template — Ähnlichkeit im Namen, kein
gemeinsamer Betrieb. Frühere lokale Klone in diesem Projekt zeigten
teils fälschlich auf `DHBW-AppStore` statt `DHBW-AppStore-T3`; das wurde
korrigiert (siehe Statusabschnitt).

`moodle_appstore` und `self-service-ui` sind externe Forks
(`leamar1e/moodle_appstore` bzw. `pfisterer/self-service-ui`), die als
Referenz-/Integrationsprojekte in die Org geholt wurden — sie teilen
nicht die `six7-click-n-deploy`-Historie.

## Status (Stand 2026-09-15)

Was schon steht, was noch fehlt — damit diese Datei nicht wie ein
Idealbild wirkt, das nie überprüft wurde.

| Baustein | Status |
|---|---|
| i · Filesystem Knowledge | offen — noch kein `claude_docs/` in irgendeinem Repo |
| ii · Tool-/Repo-Zugriff | ✅ `default_repository_permission: write` org-weit gesetzt |
| iii · Server Claude | blockiert — OpenStack-Projekt `ma_wwi_24sea_appstore_g3` freigeschaltet, aber noch keine VM |
| iv · Repo Knowledge Graph | teilweise — nur `worker/graphify-out/` existiert |
| v · Remote Execution | offen — kein dedizierter Agent-Key/-User |
| vi · Engineering Standards | offen — ECC noch nicht als Basis eingezogen |
| vii · TDD / Verification | offen — kein `/tdd`-Skill, Tests laufen nur über CI |
| viii · Observability | offen — kein `/diagnose-production`-Skill, keine MCP-Oberfläche |
| ix · Guardrails | teilweise — CI-Workflows vorhanden (`ci.yml` in backend/frontend/worker, `secret-scan.yml` + `staging.yml` in deployment), aber **keine Branch-Protection auf `main` in irgendeinem der sechs Repos** |
| x · Persistent Context | zurückgestellt, bewusst |

**Bekannte Lücke außerhalb der zehn Bausteine:** `members_can_delete_repositories`
und `members_can_change_repo_visibility` stehen org-weit auf `true` und
ließen sich über die GitHub-API nicht auf Admin-only setzen (der PATCH-Call
gibt `200 OK` zurück, ändert den Wert aber nicht — vermutlich eine
Free-Plan-Einschränkung). Jedes der sechs Mitglieder kann aktuell ein
Repo löschen oder dessen Sichtbarkeit ändern. Nur manuell in den
Org-Settings prüfbar.

**Größter offener Punkt:** Branch-Protection auf `main` fehlt in allen
sechs Repos — Direct-Pushes ohne Review oder Pflicht-CI-Check sind
möglich. Das ist der Guardrail mit dem größten Hebel und sollte vor den
übrigen Bausteinen kommen.
