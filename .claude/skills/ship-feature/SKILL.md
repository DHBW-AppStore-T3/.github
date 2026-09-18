---
name: ship-feature
description: "Alias für Flow 2 (/harness-workflow). Führt den autonomen Harness-Loop für ein GitHub-Issue aus: 'Bau mir Issue #<id>' -> Branch von dev erstellen -> TDD-Implementierung -> PR auf dev -> CI-Gates grün -> Merge auf dev -> Automatisches Staging Deployment -> Hermes Discord Statusmeldung. Push auf main erfolgt manuell durch Menschen mit Test Coverage Gate."
---

# /ship-feature (Alias für /harness-workflow)

Dieser Skill verweist direkt auf **Flow 2: `/harness-workflow`**. Siehe vollständige Dokumentation und Ablauf in:
[`../harness-workflow/SKILL.md`](../harness-workflow/SKILL.md).

## Kurzübersicht Flow 2:
1. `gh issue view <id>`
2. Branch erstellen von `dev`: `git checkout -b feat/issue-<id>-<slug> origin/dev`
3. TDD-Loop: Test rot -> minimal implementieren -> grün -> refactoren
4. PR öffnen auf `dev`
5. Bei grünen CI-Gates automatisch auf `dev` mergen
6. Automatisches Staging-Deployment startet
7. Hermes schreibt in Discord: Feature fertig & deployed, System Health gut/schlecht
8. Push to main machen Menschen selbst (+ Test Coverage Gate)
