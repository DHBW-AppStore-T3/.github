---
name: harness-workflow
description: "Flow 2: Autonomer Issue-Bau bis Staging. Triggert auf: 'Bau mir Issue #ID', '/build-issue', '/harness-workflow'."
---

# Flow 2: Autonomer Harness Workflow

Setzt ein spezifiziertes GitHub-Issue autonom via TDD um, mergt auf `dev` und verifiziert auf Staging.

## Ablauf

1. **Issue analysieren:**
   - `gh issue view <id>` ausführen, Specs und Akzeptanzkriterien erfassen.
   - Ziel-Repo öffnen, `claude_docs/HANDOVER.md` und Architektur lesen.

2. **Branch von `dev` erstellen:**
   - `git fetch origin dev && git checkout -b feat/issue-<id>-<slug> origin/dev`

3. **TDD-Implementierung (Superpowers `tdd`):**
   - **Rot:** Test schreiben, der fehlschlägt (`pytest tests/...` bzw. `npm run test`).
   - **Grün:** Minimalen Code implementieren, bis Test besteht.
   - **Refactor:** Code bereinigen, volle Testsuite & Linters ausführen.
   - Bei API-Änderungen: `make openapi` (Backend) bzw. `npm run openapi:generate` (Frontend).
   - Self-Review via Agent `code-reviewer` (ECC).

4. **PR auf `dev`:**
   - `git push -u origin feat/issue-<id>-<slug>`
   - `gh pr create --base dev --title "feat(<scope>): <Titel> (#<id>)" --body "Closes #<id>..."`

5. **CI Gates & Auto-Merge:**
   - `gh pr checks <pr-nr>` überwachen.
   - Sobald alle Checks grün sind: `gh pr merge <pr-nr> --squash --delete-branch`.
   - `claude_docs/HANDOVER.md` im Repo aktualisieren.

6. **Automatisches Staging Deployment:**
   - Push auf `dev` startet `deployment/.github/workflows/staging.yml` automatisch.

7. **Hermes Discord Status:**
   - Staging-Healthcheck prüft Container & Endpunkte.
   - Meldet Status & System Health (GUT / SCHLECHT) nach Discord.

8. **Menschliches Gate (Push to `main`):**
   - Push/Merge auf `main` (Produktion) ist **strikt menschlich**.
   - Auf `main` erzwingt das **Test Coverage Gate** die Codequalität vor jedem Produktionsdeploy.
