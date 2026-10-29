---
name: harness-workflow
description: "Flow 2: Autonomer Issue-Bau bis Staging. Triggert auf: 'Bau mir Issue #ID', '/build-issue', '/harness-workflow'."
---

# Flow 2: Autonomer Harness Workflow

Setzt ein spezifiziertes GitHub-Issue autonom via TDD um, mergt auf `dev` und verifiziert auf Staging.

## Ablauf

1. **Issue analysieren:**
   - `gh issue view <id>` ausführen, Specs und Akzeptanzkriterien erfassen.
   - Ziel-Repo öffnen, lokale `CLAUDE.md` und `claude_docs/HANDOVER.md` lesen.

2. **Branch von `dev` erstellen:**
   - `git fetch origin dev && git checkout -b feat/issue-<id>-<slug> origin/dev`

3. **TDD-Implementierung (Plugins `superpowers` & `ecc`):**
   - Folge dem TDD-Workflow des installierten `superpowers`-Plugins (`test-driven-development`):
     - **Rot:** Test schreiben, der fehlschlägt (Testbefehl aus lokaler `CLAUDE.md`).
     - **Grün:** Minimalen Code implementieren, bis Test besteht.
     - **Refactor:** Code bereinigen, volle Testsuite & Linters laut lokaler `CLAUDE.md` ausführen.
   - Bei Schnittstellenänderungen: Schema-/Codegen-Befehle laut lokaler `CLAUDE.md` ausführen.
   - Self-Review vor PR via installiertem `ecc`-Plugin: `/code-review` (Agent `code-reviewer`).

4. **PR auf `dev`:**
   - `git push -u origin feat/issue-<id>-<slug>`
   - `gh pr create --base dev --title "feat(<scope>): <Titel> (#<id>)" --body "Closes #<id>..."`

5. **CI Gates & Auto-Merge:**
   - `gh pr checks <pr-nr>` überwachen.
   - Sobald alle Checks grün sind: `gh pr merge <pr-nr> --squash --delete-branch`.
   - `claude_docs/HANDOVER.md` im Repo aktualisieren.

6. **Automatisches Staging Deployment:**
   - Push auf `dev` startet `deployment/.github/workflows/staging.yml` automatisch.

7. **Staging-Health über `appstore-mcp`:**
   - Einmalige Anbindung: `claude mcp add --transport http appstore https://appstore-mcp-staging.t3-k8s.s242437-at-student-dhbw-mannheim-de.users.dhbw.site/mcp` (beim ersten Aufruf GitHub-Login).
   - Nach dem Staging-Rollout (Argo CD) prüft der Agent read-only Pods, Events, Logs und Argo-Health über `appstore-mcp`.
   - Meldet Status & System Health (GUT / SCHLECHT) im Chat/PR; kein Discord, kein Schreibzugriff auf den Cluster.

8. **Menschliches Gate (Push to `main`):**
   - Push/Merge auf `main` (Produktion) ist **strikt menschlich**.
   - Auf `main` erzwingt das **Test Coverage Gate** die Codequalität vor jedem Produktionsdeploy.
