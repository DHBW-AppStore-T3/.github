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

## 3. Claude Code pro Repo konfigurieren

Jedes Repo braucht sein eigenes `claude_docs/` — das ist der Layer-i-
Baustein aus `HARNESS.md`. Lege ihn in jedem der vier Kern-Repos an:

```bash
for d in backend frontend worker; do
  mkdir -p "$d/claude_docs"
  touch "$d/claude_docs/architecture.md" "$d/claude_docs/decisions.md" "$d/claude_docs/debugging.md"
done

mkdir -p deployment/claude_docs
touch deployment/claude_docs/architecture.md deployment/claude_docs/decisions.md
touch deployment/claude_docs/topology.md deployment/claude_docs/rollback.md
```

In jedes root-`CLAUDE.md` (falls noch nicht vorhanden, anlegen) gehört
mindestens:

```markdown
# <Repo-Name>

Teil der DHBW-AppStore-T3 Organisation — sechs eigenständige Repos,
kein Monorepo. Harness-Gesamtkonzept: siehe
https://github.com/DHBW-AppStore-T3/.github/blob/main/docs/HARNESS.md

Details zu diesem Repo: siehe claude_docs/architecture.md,
claude_docs/decisions.md, claude_docs/debugging.md
```

Das hält jede einzelne `CLAUDE.md` klein und verhindert, dass fünf
Leute an fünf Kopien derselben Erklärung vorbeischreiben.

## 4. Repo Knowledge Graph (Graphify)

`worker/` hat bereits einen Graphen unter `worker/graphify-out/`. Für
die übrigen Repos: `/graphify` im jeweiligen Repo-Root ausführen. Ein
Graph pro Repo, kein Graph fürs Gesamtsystem — die Verbindungen
zwischen den Services (welcher REST-Endpunkt, welcher Celery-Task-Name)
gehören stattdessen in `claude_docs/architecture.md`.

## 5. TDD-Skill nutzen

- In `backend/` oder `worker/`: Tests laufen über `pytest` (Poetry-
  basiert, siehe `pyproject.toml` im jeweiligen Repo).
- In `frontend/`: Tests laufen über `vitest`
  (`frontend/vitest.config.ts`).

Bis der `/tdd`-Skill existiert (siehe Statusabschnitt in `HARNESS.md`):
halte dich manuell an den Loop — Test schreiben, der fehlschlägt →
minimal implementieren → Test grün → refactoren → volle Suite laufen
lassen, bevor du den Agenten etwas als "fertig" melden lässt.

## 6. Guardrails, die du kennen solltest (auch ohne dass sie technisch erzwungen sind)

Diese sind laut `HARNESS.md`-Statusabschnitt noch **nicht** durch Hooks
oder Branch-Protection erzwungen — bis das nachgezogen ist, gilt als
Team-Konvention:

- **Kein Direct-Push auf `main`** in irgendeinem der sechs Repos, auch
  wenn GitHub es aktuell technisch zulässt. Immer über einen Branch +
  Pull Request, auch wenn kein Review-Gate erzwungen wird.
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

## 7. Server-Zugriff — `appstore-prod-01`

Die Produktions-VM läuft bereits (OpenStack-Projekt
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

## 8. Deployment-Ops-MCP (sobald verfügbar)

Noch nicht gebaut (siehe Statusabschnitt in `HARNESS.md`). Zielbild:
ein MCP-Server `appstore-ops`, der `get_health()`, `get_logs(service)`,
`get_deployments()`, `get_errors()` sowie eine eng begrenzte
`restart_service(name)`-Aktion bereitstellt, plus lesenden
OpenStack-API-Zugriff (`openstack_server_list()`,
`openstack_server_status()`, `openstack_quota()`). Bis dahin: Diagnose
läuft über manuelles `ssh appstore-vm "docker compose logs ..."`, nie
über direktes `sudo`.

## Wenn etwas an diesem Setup schon wieder veraltet ist

`HARNESS.md` hat einen Statusabschnitt mit Datum. Wenn du hier etwas
liest, das dem widerspricht, was du im Repo tatsächlich vorfindest —
vertrau dem Repo, nicht diesem Dokument, und aktualisiere den
Statusabschnitt in `HARNESS.md` gleich mit.
