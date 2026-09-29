# .github

Zentrales Organisations- und Dokumentations-Repository der `DHBW-AppStore-T3` Organisation.
Harness-Gesamtkonzept: siehe docs/HARNESS.md

## Die 2 primären Harness-Flows
1. **Flow 1: User Story Generierung (`.claude/skills/user-story/SKILL.md`):**
   - Trigger: *"Ich will Feature <X>"*
   - Ablauf: Klarifizierungsfragen -> Design Specs mit Optionen -> Implementierungs-Specs mit Optionen -> Issue auf GitHub anlegen.
2. **Flow 2: Autonomer Harness-Workflow (`.claude/skills/harness-workflow/SKILL.md`):**
   - Trigger: *"Bau mir Issue #<ID>"*
   - Ablauf: Branch von `dev` -> TDD-Loop -> PR auf `dev` -> CI Gates grün -> Auto-Merge auf `dev` -> Automatisches Staging Deployment -> Hermes Discord Notification (Feature fertig, System Health gut/schlecht).
   - Push auf `main` (Produktion) bleibt rein menschlich + Test Coverage Gate.

Details zu diesem Repo:
- Lebendes Übergabedokument: `claude_docs/HANDOVER.md` (zwingend zu Beginn jeder Session lesen und vor Session-Ende aktualisieren)
- Harness-Spezifikation: `docs/HARNESS.md`
- Universelle AppStore-Flows: `.claude/skills/` (`user-story`, `harness-workflow`)
- Offizielle Plugins: `superpowers` (TDD, Debugging) & `ecc` (Code-Reviewer, Security)
- Setup für Teammitglieder: `./scripts/setup-harness.sh` (oder `docs/GET_STARTED_WITH_HARNESS.md`)
- Issue Templates: `.github/ISSUE_TEMPLATE/user-story.md`
- Cross-Repo Knowledge Graph: `graphify-out/`
