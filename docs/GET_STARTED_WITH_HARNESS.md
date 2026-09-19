# Get Started with the Harness

Diese Anleitung baut dir das Agent-Harness aus [`HARNESS.md`](HARNESS.md)
Schritt für Schritt auf deinem eigenen Rechner auf. Sie richtet sich an
jedes Mitglied von `DHBW-AppStore-T3`, egal ob du am Backend, Frontend,
Worker oder Deployment arbeitest.

Sie ersetzt **nicht** die normale lokale Entwicklungsumgebung der App —
die steht in [`deployment/docs/dev-setup.md`](https://github.com/DHBW-AppStore-T3/deployment/blob/main/docs/dev-setup.md)
und startest du wie gewohnt mit `make dev-up` im `deployment`-Repo. Hier
geht es nur um den **Agent** drumherum: Zugriff, Wissen, Guardrails.

## 0. Voraussetzungen

- [GitHub CLI](https://cli.github.com/) (`gh`) installiert
- Claude Code installiert
- Mitglied der Organisation `DHBW-AppStore-T3` auf GitHub (frag im Team,
  falls du noch keine Einladung hast)

## 1. GitHub-Zugriff einrichten

```bash
gh auth login
```

Wähle `github.com`, HTTPS, und melde dich über den Browser an. Prüfe
danach, ob du Zugriff auf die Org hast:

```bash
gh api user/orgs --jq '.[].login'
# sollte "DHBW-AppStore-T3" in der Liste zeigen
```

Falls nicht: du bist eingeladen, aber die Einladung noch nicht
angenommen — check dein GitHub-Postfach oder frag im Team.

**Wichtig:** achte auf den Org-**Namen**. Es gibt zwei ähnlich benannte
Organisationen (`DHBW-AppStore` und `DHBW-AppStore-T3`) — nur
`DHBW-AppStore-T3` ist unsere. Ein falsch gesetzter Remote fällt nicht
sofort auf, weil beide dieselben Repo-Namen benutzen.

Manche Aktionen (z. B. Git-Push auf Workflow-Dateien unter
`.github/workflows/`) brauchen zusätzliche Token-Scopes. Falls ein Push
mit `refusing to allow ... without 'workflow' scope` abgelehnt wird:

```bash
gh auth refresh -h github.com -s workflow
gh auth setup-git
```

## 2. Die sechs Repos klonen

```bash
mkdir -p ~/dev/DHBW-AppStore && cd ~/dev/DHBW-AppStore

for repo in backend frontend worker deployment moodle_appstore self-service-ui; do
  gh repo clone "DHBW-AppStore-T3/$repo"
done
```

Das ergibt sechs eigenständige Git-Repositories nebeneinander — **kein**
Monorepo, kein gemeinsamer `.git`. Jedes hat seinen eigenen Remote,
seine eigene CI, seinen eigenen Branch-Stand.

Prüfe, dass jeder Remote wirklich auf `DHBW-AppStore-T3` zeigt (nicht auf
die andere Org):

```bash
for d in backend frontend worker deployment moodle_appstore self-service-ui; do
  echo "$d: $(git -C "$d" remote get-url origin)"
done
```

## 3. `claude_docs/` anlegen — mit lebendem Übergabedokument (HANDOVER.md)

Kein flaches `claude_docs/architecture.md` — siehe `HARNESS.md`
Abschnitt 1.1 für die volle Begründung und die genaue Struktur pro
Repo-Typ. Kurzfassung zum Nachbauen:

```bash
# backend, frontend, worker: architecture/ + decisions/ + debugging/ + HANDOVER.md
for d in backend frontend worker; do
  mkdir -p "$d/claude_docs"/{architecture,decisions,debugging}
  touch "$d/claude_docs/architecture/overview.md"
  touch "$d/claude_docs/HANDOVER.md"
done

# deployment: topology/ statt debugging/, plus rollback/ + HANDOVER.md
mkdir -p deployment/claude_docs/{topology,decisions,rollback}
touch deployment/claude_docs/topology/{environments,boot-order,networking}.md
touch deployment/claude_docs/HANDOVER.md

# moodle_appstore, self-service-ui: vorerst flach, siehe HARNESS.md 1.1
for d in moodle_appstore self-service-ui; do
  mkdir -p "$d/claude_docs"
  touch "$d/claude_docs/architecture.md" "$d/claude_docs/decisions.md" "$d/claude_docs/HANDOVER.md"
done
```

**`HANDOVER.md` ist das lebende Übergabedokument für jede Session:**
Statt unübersichtlicher Wochenlogs (`2026-W38.md`), die den Kontext
zerfasern und Aufgaben verschlucken, hat jedes Repo genau **eine**
lebende `claude_docs/HANDOVER.md`.

Jede Session (Agent oder Entwickler) liest `HANDOVER.md` zu Beginn
zwingend als Erstes und aktualisiert sie vor Session-Ende.
Grundstruktur:

```markdown
# Handover — <Repo-Name>

## 1. Status & Fokus
- Aktueller Branch: ...
- Was funktioniert: ...
- Letzter Merge / Deploy: ...

## 2. In Arbeit & Nächste Schritte
- [ ] Offener Punkt 1
- [ ] Offener Punkt 2

## 3. Bekannte Fallstricke & Blocker
- Fallstrick / Eigenheit / Gotcha

## 4. Letzte Übergaben (Historie)
- **YYYY-MM-DD (Autor):** Kurze Zusammenfassung der getätigten Änderungen.
```

In jedes root-`CLAUDE.md` (falls noch nicht vorhanden, anlegen) gehört
mindestens:

```markdown
# <Repo-Name>

Teil der DHBW-AppStore-T3 Organisation — sechs eigenständige Repos,
kein Monorepo. Harness-Gesamtkonzept: siehe
https://github.com/DHBW-AppStore-T3/.github/blob/main/docs/HARNESS.md

Details zu diesem Repo: siehe claude_docs/architecture/,
claude_docs/decisions/, claude_docs/debugging/ (bzw. topology/ +
rollback/ bei deployment), claude_docs/HANDOVER.md
```

Das hält jede einzelne `CLAUDE.md` klein und verhindert, dass fünf
Leute an fünf Kopien derselben Erklärung vorbeischreiben.

## 4. Repo Knowledge Graph (Graphify) — lokal und global

`worker/` hat bereits einen Graphen unter `worker/graphify-out/`. Für
die übrigen Repos: `/graphify` im jeweiligen Repo-Root ausführen —
das legt einen **lokalen** Graphen pro Repo an.

Zusätzlich gibt es einen **globalen, Repo-übergreifenden** Graphen
(`HARNESS.md` Abschnitt 1.4), der die sechs lokalen Graphen zu einem
zusammenführt:

```bash
graphify merge-graphs \
  backend/graphify-out/graph.json \
  frontend/graphify-out/graph.json \
  worker/graphify-out/graph.json \
  deployment/graphify-out/graph.json \
  moodle_appstore/graphify-out/graph.json \
  self-service-ui/graphify-out/graph.json \
  --out cross-repo-graph.json
```

Das läuft normalerweise **nicht** manuell — ein CI-Schritt pro Repo
hält den lokalen Graphen bei jedem Push auf `main` aktuell
(`graphify update <path>`, kein LLM-Call), ein separater Workflow im
`.github`-Repo führt den Merge periodisch aus. Solange dieser
Workflow noch nicht existiert (siehe Statusabschnitt in `HARNESS.md`):
lokale Graphen manuell pflegen, globalen Merge bei Bedarf von Hand
ausführen.

## 5. API-Contracts: OpenAPI Single Source of Truth

Keine manuellen Markdown-Listen (`api-contracts.md`) mehr! Die
Schnittstelle ist direkt im Code definiert:
- Im Backend erzeugt FastAPI automatisch die OpenAPI-3.1-Spezifikation.
- Mit `make openapi` (bzw. `python scripts/export_openapi.py`) im `backend`-Repo
  wird die aktuelle `openapi.json` generiert.
- Das Frontend konsumiert die generierte Spezifikation für Typensicherheit
  und API-Clients.

## 6. Offizielle Open-Source Plugins (Superpowers & ECC) & die 2 Projekt-Flows

Unser Team setzt direkt auf die **offiziellen Open-Source-Plugins** von Claude Code, kombiniert mit unseren maßgeschneiderten AppStore-Flows:

### 1. Offizielle Open-Source-Plugins:
- **`superpowers@superpowers-marketplace` ([`obra/superpowers`](https://github.com/obra/superpowers)):**
  Kern-Engineering-Tools: TDD (`test-driven-development`), 4-Phasen Ursachenanalyse (`systematic-debugging`), Brainstorming, Planning und Verification.
- **`ecc@ecc` ([`affaan-m/ECC`](https://github.com/affaan-m/ECC)):**
  Spezialisierte Agenten & Review-Layer: Automatisierter Pre-PR Code-Reviewer (`code-reviewer`, `/code-review`), Security-Checks (`security-reviewer`, `/security-scan`), Architekten- und Framework-Rollen.

### 2. Die 2 DHBW-AppStore Projekt-Flows (in `.github/.claude/skills/`):
- **Flow 1: User Story Generierung (`/user-story`):**
  Interaktiver Klärungsdialog: Feature-Wunsch -> Klarifizierungsfragen -> Design-Specs mit Optionen -> Implementierungs-Specs mit Optionen -> automatisches GitHub-Issue.
- **Flow 2: Harness Workflow (`/harness-workflow`):**
  "Bau mir Issue #ID" -> Branch von `dev` -> TDD (via Superpowers-Plugin) -> Pre-PR Review (via ECC Agent) -> PR auf `dev` -> CI Gates abwarten -> Auto-Merge auf `dev` -> Staging-Deployment -> Hermes Discord Meldung & System Health.

### Automatisches Setup für jedes Teammitglied:
Führe nach dem Klonen einfach das Setup-Skript im `.github`-Repo aus:
```bash
./.github/scripts/setup-harness.sh
```
Das Skript fügt automatisch die Marketplaces (`superpowers-marketplace`, `ecc`) hinzu, installiert die Plugins und verlinkt die beiden AppStore-Flows nach `~/.claude/skills/`.

*(Alternativ manuell über Claude Code CLI:)*
```bash
claude plugin marketplace add obra/superpowers-marketplace
claude plugin marketplace add https://github.com/affaan-m/ECC
claude plugin install superpowers@superpowers-marketplace
claude plugin install ecc@ecc
mkdir -p ~/.claude/skills
ln -sfn "$(pwd)/.github/.claude/skills/user-story" ~/.claude/skills/user-story
ln -sfn "$(pwd)/.github/.claude/skills/harness-workflow" ~/.claude/skills/harness-workflow
```

## 7. Guardrails

**Durchgesetzt, nicht nur Konvention:** Branch-Protection auf `main`
ist in allen sechs Repos aktiv — Direct-Push ist technisch blockiert,
ein PR ist Pflicht, und in backend/frontend/worker/deployment müssen
die jeweiligen CI-Checks grün sein, bevor GitHub den Merge-Button
überhaupt anbietet. Das heißt konkret: `git push origin main` schlägt
fehl, du merkst es sofort, nicht erst im Nachhinein.

Was davon noch **nicht** technisch erzwungen ist (siehe
`HARNESS.md`-Statusabschnitt), gilt weiterhin als Team-Konvention:

- **Nie `docker compose -f docker-compose.prod.yml`** von deinem
  lokalen Rechner aus — Prod läuft ausschließlich über die
  Staging→Prod-Pipeline in `deployment/`.
- **Nie eine `.env`-Datei committen.** Alle vier `docker-compose.*.yml`
  in `deployment/` erwarten Secrets aus lokalen, nicht versionierten
  `.env`-Dateien.
- **Alembic-Migrationen nie unbeaufsichtigt laufen lassen** — immer
  mit einem Menschen gegenlesen, bevor sie gegen eine geteilte
  Datenbank (staging/prod) angewendet werden.
- **Jedes der sechs Org-Mitglieder kann aktuell jedes Repo löschen**
  (bekannte, noch ungelöste Lücke — siehe `HARNESS.md`). Sei
  entsprechend vorsichtig mit `gh repo delete` und ähnlichen Befehlen.

## 8. GitHub Best Practices — was im `.github`-Repo jetzt drin ist

Diese Dateien sind committetes Standard-Setup und konfigurieren sich
bei GitHub automatisch — kein zusätzliches manuelles Einrichten nötig:

| Datei | Zweck |
|---|---|
| `SECURITY.md` | Org-weite Security Policy — wo Sicherheitslücken gemeldet werden (GitHub Security Advisories) |
| `.github/PULL_REQUEST_TEMPLATE.md` | Wird bei jedem neuen PR in diesem Repo vorab ausgefüllt — enthält Checkliste mit HANDOVER.md-Pflicht |
| `.github/dependabot.yml` | Erstellt wöchentlich automatische PRs für veraltete GitHub Actions Versionen |
| `.gitignore` | Schützt `.env`, `*.key`, `*.pem`, `clouds.yaml` u. a. vor versehentlichem Commit |

**Was das für dich bedeutet:**
- Beim Öffnen eines PRs im `.github`-Repo wird das Template automatisch geladen — bitte ausfüllen, nicht leeren.
- Secrets niemals committen — das `.gitignore` ist eine Sicherheitslinie, kein Netz. Prüfe vor jedem `git add` mit `git status`.

## 9. Server-Zugriff — `appstore-prod-01` (OpenStack-Projekt
`ma_wwi_24sea_appstore_g3`, 10 Docker-Container: nginx, frontend,
backend, worker, keycloak, postgres ×2, rabbitmq, redis). **Das ist
scharfe Produktion, keine Test-VM.**

Für Menschen: Zugriff läuft aktuell über den `ubuntu`-User (Public Key
in `authorized_keys` hinterlegt, frag im Team um Zugang). Dieser User
hat passwortlosen Sudo — sei entsprechend vorsichtig, jeder Befehl
läuft effektiv als root.

**Für einen Agenten gilt das nicht.** Ein Agent (egal ob lokal
gestartet und per SSH auf die VM zugreifend, oder direkt auf der VM
laufend) darf **nicht** den `ubuntu`-User verwenden. Solange der in
`HARNESS.md` beschriebene `claude-agent`-User samt PreToolUse-Hooks
noch nicht existiert, gilt: keine schreibenden Aktionen eines Agenten
gegen `appstore-prod-01`, nur Lesen (Logs, Health, `docker ps`) über
den `ubuntu`-Zugang, alles Schreibende geht über die reguläre
CI/CD-Pipeline in `deployment/`.

Falls du selbst noch keinen OpenStack-Zugriff (nicht denselben wie
SSH-auf-die-VM, sondern für Terraform/die OpenStack-API) eingerichtet
hast:

1. Login: <https://newstack.dhbw.cloud> über BWIDM/DHBW-Login
2. SSH-Public-Key hochladen: Project → Key Pairs → Import
   — nutze nach Möglichkeit einen **separaten** Key, nicht deinen
   privaten Alltags-Key
3. `clouds.yaml` herunterladen: Account → OpenStack RC File, ablegen
   unter `~/.config/openstack/clouds.yaml`
4. Testen: `openstack server list`

**VM-Namensregeln:** nur Buchstaben, Ziffern, Bindestriche — **keine
Umlaute**. Ein falscher Hostname bricht DNS und die VM lässt sich nur
löschen, nicht reparieren.

## 10. Deployment-Ops-Skills (im `deployment`-Repo)

Die deploy- und vm-spezifischen Ops-Skills liegen in `deployment/.claude/`:
- `/diagnose-production`: Feste Diagnosereihenfolge (Health → Logs → Deploys → OpenStack)
- `/deploy-status`: Status Staging vs. Prod
- `/restart-service`: Einzige erlaubte Schreibaktion, geschützt durch `deployment/.claude/hooks/appstore-prod-guardrail.py`

## 11. Die 2 Flows im Entwickler-Alltag

`HARNESS.md` Abschnitt 5 beschreibt die beiden Flows im Detail:

### Flow 1: User Story Generierung (`/user-story`)
1. User formuliert Feature: `"Ich will Feature <X>"`
2. Der Agent stellt gezielte **Klarifizierungsfragen** (Persona, Scope, betroffene Repos, Randbedingungen) -> User antwortet.
3. Der Agent erarbeitet **Design Specs** und bietet mindestens 2 Architektur-Optionen zur Auswahl an -> User wählt Option.
4. Der Agent erarbeitet **Implementierungs-Specs** (OpenAPI Endpunkte, DB-Modelle, Celery-Tasks, UI, TDD-Plan) und bietet technische Detailoptionen -> User wählt Option / bestätigt.
5. Der Agent legt das Issue vollautomatisch via `gh issue create` an und gibt die Issue-Nummer `#<ID>` zurück.

### Flow 2: Harness Workflow (`/harness-workflow`)
1. Entwickler sagt: `"Bau mir Issue #<ID>"`
2. Der Agent checkoutet `dev` und erstellt `feat/issue-<ID>-<slug>`.
3. TDD-Loop: Failing Tests -> minimale Implementierung -> grün -> Refactoring -> OpenAPI-Sync (`make openapi` / `npm run openapi:generate`) -> lokale Checks.
4. Agent öffnet PR auf `dev` (`gh pr create --base dev`).
5. Sobald alle Required CI-Checks grün sind, führt der Agent automatisch den Merge auf `dev` durch (`gh pr merge --squash`).
6. Staging-Deployment startet automatisch bei Push/Merge auf `dev` (`deployment/.github/workflows/staging.yml`).
7. Hermes meldet Status in Discord: `"Feature fertig & deployed! Issue #<ID>, System Health: GUT / SCHLECHT"`.
8. **Push auf `main` (Produktion):** Bleibt rein menschlich! Auf `main` erzwingt das **Test Coverage Gate**, dass die Testabdeckung nicht absinkt.

## Wenn etwas an diesem Setup schon wieder veraltet ist

`HARNESS.md` hat einen Statusabschnitt mit Datum. Wenn du hier etwas
liest, das dem widerspricht, was du im Repo tatsächlich vorfindest —
vertrau dem Repo, nicht diesem Dokument, und aktualisiere den
Statusabschnitt in `HARNESS.md` gleich mit.
