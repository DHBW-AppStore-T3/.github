---
name: harness-workflow
description: "Führt den autonomen Harness-Entwicklungs-Flow (Flow 2) für ein GitHub-Issue aus: 'Bau mir Issue #<id>' -> Issue abrufen -> Branch von dev erstellen -> TDD-Implementierung (rot-grün-refactor) -> PR auf dev öffnen -> CI-Gates abwarten -> bei Grün automatisch auf dev mergen -> Automatisches Staging-Deployment startet -> Hermes meldet in Discord Feature fertig & System Health. Push auf main bleibt rein menschlich mit Test Coverage Gate. Triggers on: bau mir Issue #..., baue Issue ..., implementiere Issue #..., /harness-workflow, /build-issue."
---

# /harness-workflow (Flow 2: Autonomer Harness-Workflow)

Dieser Skill implementiert **Flow 2** des Harness-Engineerings. Er übernimmt ein fertig spezifiziertes Issue (aus Flow 1 `/user-story`) und führt die Entwicklung autonom durch, bis das Feature auf Staging bereitgestellt und via Hermes in Discord verifiziert ist.

## Übersicht des Ablaufs

```
User: "Bau mir Issue #<id>"
   │
   ├─► Schritt 1: Issue analysieren (gh issue view <id>)
   │     └─► Ziel-Repo identifizieren
   │     └─► claude_docs/HANDOVER.md & Architecture lesen
   │
   ├─► Schritt 2: Feature-Branch von `dev` erstellen
   │     └─► git fetch origin dev
   │     └─► git checkout -b feat/issue-<id>-<slug> origin/dev
   │
   ├─► Schritt 3: TDD-Implementierung (System 4 / SKILL: tdd)
   │     └─► 1. Failing Test schreiben (rot)
   │     └─► 2. Minimale Implementierung schreiben (grün)
   │     └─► 3. Refactoring durchführen
   │     └─► 4. Bei API-Änderung: make openapi (Backend) & npm run openapi:generate (Frontend)
   │     └─► 5. Volle Test-Suite & Linter lokal ausführen
   │     └─► 6. Code-Reviewer Agent Checklist prüfen
   │
   ├─► Schritt 4: PR auf `dev` öffnen
   │     └─► git push -u origin feat/issue-<id>-<slug>
   │     └─► gh pr create --base dev --title "feat(<scope>): <title> (#<id>)" --body "Closes #<id>..."
   │
   ├─► Schritt 5: CI Gates überwachen & bei Grün auf `dev` mergen
   │     └─► gh pr checks abwarten
   │     └─► Alle Required Checks grün?
   │           ├─► JA: gh pr merge <pr-nr> --squash --delete-branch
   │           └─► NEIN: Fehler analysieren, fixen, pushen
   │     └─► claude_docs/HANDOVER.md im Repo aktualisieren
   │
   ├─► Schritt 6: Automatisches Staging Deployment startet
   │     └─► Merge auf `dev` triggert CD - Staging Deployment (staging.yml)
   │
   ├─► Schritt 7: Hermes meldet in Discord: Feature fertig & deployed, System Health
   │     └─► Staging Health Check prüft Container & Endpoints
   │     └─► Discord-Benachrichtigung:
   │           "🚀 Staging Deployment: Feature fertig & deployed!
   │            Issue: #<id>
   │            System Health: GUT / SCHLECHT (Container-Status)"
   │
   └─► Schritt 8: Push auf `main` (Produktion)
         └─► ⚠️ BLEIBT REIN MENSCHLICH! Der Agent mergt NIEMALS auf main.
         └─► Test Coverage Gate auf main stellt sicher, dass Codequalität nicht sinkt.
```

---

## Detaillierte Schritt-für-Schritt-Instruktionen

### Schritt 1: Issue einlesen & Kontext aufbauen
1. Rufe das Issue über das GitHub CLI ab:
   ```bash
   gh issue view <id>
   ```
2. Lies die Akzeptanzkriterien, OpenAPI-Schnittstellen und den TDD-Plan.
3. Wechsle in das betroffene Repository (z. B. `backend`, `frontend`, `worker`, etc.).
4. Lies **vor** jeder Codeänderung das lebende Übergabedokument:
   `cat claude_docs/HANDOVER.md`
   und relevante Architekturdateien in `claude_docs/architecture/`.

### Schritt 2: Branch von `dev` erstellen
Entwickelt wird immer gegen den `dev`-Branch (Staging-Trunk):
```bash
git fetch origin dev
git checkout -b feat/issue-<id>-<slug> origin/dev
```

### Schritt 3: TDD-Loop durchsetzen (System 4)
Halte dich strikt an das Red-Green-Refactor-Prinzip:
1. **Rot:** Schreibe zuerst die Unit- und/oder Integrationstests für das Feature aus dem TDD-Plan des Issues. Führe den Test aus und bestätige, dass er fehlschlägt.
   - `backend`/`worker`: `poetry run pytest tests/... -v`
   - `frontend`: `npm run test`
2. **Grün:** Schreibe den minimalen Produktionscode, der die Tests erfüllt. Führe den Test erneut aus.
3. **Refactor:** Optimiere Code-Struktur, Lesbarkeit und Typ-Annotationen ohne Testbrüche.
4. **Contract-Synchronisation:**
   - Falls Backend-Endpoints geändert wurden: `poetry run python scripts/export_openapi.py` ausführen.
   - Falls Frontend API-Typen nutzt: `npm run openapi:generate` ausführen.
5. **Lokale Verifikation:**
   - Backend/Worker: `poetry run ruff check .` und volle Pytest-Suite.
   - Frontend: `npm run build` (`vue-tsc -b`) und `npm run test`.
6. **Code-Review:**
   - Führe die Checkliste aus `.github/.claude/agents/code-reviewer.md` mental oder via Subagent gegen das Git-Diff aus.

### Schritt 4: PR auf `dev` öffnen
```bash
git add .
git commit -m "feat(<scope>): <Titel> (#<id>)"
git push -u origin "feat/issue-<id>-<slug>"

gh pr create \
  --base dev \
  --title "feat(<scope>): <Titel> (#<id>)" \
  --body "Closes #<id>

## Zusammenfassung
- Implementiert Funktionalität aus Issue #<id>
- TDD-Tests erfolgreich durchgelaufen

## Akzeptanzkriterien
- [x] Alle Kriterien aus Issue erfüllt
"
```

### Schritt 5: CI Gates abwarten & bei Grün auf `dev` mergen
1. Warte auf die CI-Checks:
   ```bash
   gh pr checks <pr-nr>
   ```
2. Sobald alle Required Checks grün sind:
   ```bash
   gh pr merge <pr-nr> --squash --delete-branch
   ```
3. Aktualisiere `claude_docs/HANDOVER.md` im betroffenen Repo mit dem neuen Feature-Stand.

### Schritt 6: Automatisches Staging-Deployment
Durch den Push/Merge auf `dev` startet das Staging-Deployment automatisch (`deployment/.github/workflows/staging.yml` auf dem Self-Hosted-Runner).

### Schritt 7: Hermes Discord-Benachrichtigung & System Health
Nach Abschluss des Deployments meldet Hermes (oder das Deployment-Skript) den Status in Discord:
- **Feature fertig & deployed!**
- **Issue:** `#<id>`
- **Staging-URL:** `http://<staging-ip>`
- **System Health:** `GUT` (alle 10 Docker-Container gesund und API antwortet mit 200 OK) bzw. `SCHLECHT` (Container degraded/abgestürzt).

### Schritt 8: Übergabe an Menschen (Push to `main`)
Der Agent beendet seine Arbeit nach Schritt 7 und informiert den User:
> "✅ Issue **#<id>** ist erfolgreich implementiert, auf `dev` gemergt und auf Staging deployed!
> Hermes meldet: **System Health ist GUT**.
> 
> 🛑 **Nächster Schritt:** Die Freigabe und der Push/Merge auf `main` (Produktion) erfolgt manuell durch Menschen.
> Auf `main` ist das **Test Coverage Gate** aktiv, um sicherzustellen, dass keine Qualitätsdegradation stattfindet."
