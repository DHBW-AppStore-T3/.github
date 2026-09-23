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

## 6. Engineering-Loop: ECC, Superpowers, TDD

Universelle Werkzeuge liegen zentral im `.github`-Repo unter `.claude/`:
- **Code-Reviewer Agent (`.github/.claude/agents/code-reviewer.md`):**
  Reviewt Diffs speziell für unseren Stack (Vue 3, Python/Poetry,
  Terraform/OpenStack, Docker Compose).
- **TDD-Skill (`.github/.claude/skills/tdd/SKILL.md`):**
  Repo-spezifischer Red-Green-Refactor-Loop (`pytest` für Python,
  `vitest` + `vue-tsc` für Frontend).
- **Feature-Shipping (`.github/.claude/skills/ship-feature/SKILL.md`):**
  Führt durch den gesamten Prozess vom Branch bis zum Merge. Mergt
  autonom in `dev` (→ Staging) sobald CI grün ist. STOP vor `main`
  (→ Prod) — das ist immer eine menschliche Entscheidung.

**Prozess 1 — Issue Creation** läuft über vier Skills in
`deployment/.claude/skills/`:
- `/issue-creation` — Klarifizierung → Brainstorming → Design Spec →
  Impl Spec → Freigabe (STOP) → `gh issue create`
- `/brainstorming` — Cross-Repo-Analyse (Graphify + OpenAPI), Optionen
  mit Trade-offs, Superpowers-linked
- `/design-spec` — Was wird gebaut? OpenAPI-first, kein Placeholder
- `/implementation-spec` — Wie wird es gebaut? Zero placeholders, jede
  Task mit eigenem Testschritt

**Lokale Einbindung:**
Um die universellen Skills aus dem `.github`-Repo in Claude Code global
oder in den Einzel-Repos zu nutzen, symlinke oder kopiere sie:
```bash
# Skills global für deinen User bereitstellen:
mkdir -p ~/.claude/skills ~/.claude/agents
ln -sfn "$(pwd)/.github/.claude/skills/tdd" ~/.claude/skills/tdd
ln -sfn "$(pwd)/.github/.claude/skills/ship-feature" ~/.claude/skills/ship-feature
ln -sfn "$(pwd)/.github/.claude/agents/code-reviewer.md" ~/.claude/agents/code-reviewer.md
```

- **Tests:** `pytest` in `backend`/`worker` (Poetry-basiert), `vitest`
  in `frontend` (`frontend/vitest.config.ts`).
- Halte dich an den TDD-Loop: Test schreiben, der fehlschlägt → minimal
  implementieren → Test grün → refactoren → volle Suite laufen lassen.

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

## 8. Server-Zugriff — `appstore-prod-01`

Die Produktions-VM läuft bereits (OpenStack-Projekt
`ma_wwi_24sea_appstore_g3`, 10 Docker-Container: nginx, frontend,
backend, worker, keycloak, postgres ×2, rabbitmq, redis). **Das ist
scharfe Produktion, keine Test-VM.**

Für Menschen: Zugriff läuft aktuell über den `ubuntu`-User (Public Key
in `authorized_keys` hinterlegt, frag im Team um Zugang). Dieser User
hat passwortlosen Sudo — sei entsprechend vorsichtig, jeder Befehl
läuft effektiv als root.

**Für einen Agenten gilt das nicht.** Der einzige Server-Agent ist
**Hermes** — er läuft containerisiert auf der VM und kommuniziert über
Discord (Allowlist: `DISCORD_ALLOWED_USERS`). Ein separater
`claude-agent`-Host-User wurde bewusst verworfen (siehe `HARNESS.md`
Abschnitt 3.2). Der Coding-Agent (Claude Code auf deinem Rechner) hat
keinen direkten SSH-Zugriff auf `appstore-prod-01` — alles Schreibende
läuft über die CI/CD-Pipeline oder über Hermes nach expliziter
menschlicher Freigabe.

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

## 9. Deployment-Ops-Skills (im `deployment`-Repo)

Die deploy- und vm-spezifischen Ops-Skills liegen in `deployment/.claude/skills/`:
- `/diagnose-production` — Feste Diagnosereihenfolge (Health → Logs → Deploys → OpenStack)
- `/deploy-status` — Status Staging vs. Prod
- `/restart-service` — Einzige erlaubte Schreibaktion auf der VM, geschützt durch `appstore-prod-guardrail.py`
- `/verify-staging` — Nach einem Merge in `dev`: postet `@hermes /verify-staging`
  als Comment auf den PR; Hermes prüft Container-Health und postet das Ergebnis auf Discord

## 10. Der vollständige End-to-End-Loop

Zwei Prozesse tragen eine Anforderung von der Idee bis in Prod:

**Prozess 1 — Issue Creation (Wunsch → freigegebenes Issue):**
```
/issue-creation → Klarifizierung (STOP) → /brainstorming →
/design-spec + /implementation-spec → Freigabe (STOP) → gh issue create
```

**Prozess 2 — Development & Deploy (Issue → Prod):**
```
/ship-feature → Branch → /tdd → PR → CI-Gate →
gh pr merge (dev) ← Agent autonom
  → Staging-Deploy (automatisch)
  → /verify-staging via Hermes
dev→main PR → STOP (Mensch entscheidet)
  → Prod-Deploy (manuell)
```

| Schritt | Wer | Warum |
|---|---|---|
| Merge in `dev` | Agent | Staging ist wegwerfbar, kein Nutzerzustand |
| Merge in `main` | Mensch | Prod hat Keycloak-Realm, laufende Deployments |
| Spec freigeben | Mensch | Agent rät keine Architektur ohne Bestätigung |
| Issue erstellen | Agent (nach Freigabe) | Audit-Trail, Startpunkt für /ship-feature |

## Wenn etwas an diesem Setup schon wieder veraltet ist

`HARNESS.md` hat einen Statusabschnitt mit Datum. Wenn du hier etwas
liest, das dem widerspricht, was du im Repo tatsächlich vorfindest —
vertrau dem Repo, nicht diesem Dokument, und aktualisiere den
Statusabschnitt in `HARNESS.md` gleich mit.
