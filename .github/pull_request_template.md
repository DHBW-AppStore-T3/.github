## Zusammenfassung

<!-- Was ändert dieser PR und warum? 1–3 Sätze. -->

Closes #

**Art der Änderung:** <!-- feat | fix | refactor | docs | ci | harness | chore — bei Breaking Change zusätzlich "BREAKING" -->

## Prüfung

<!-- Wie wurde geprüft, dass die Änderung funktioniert? Konkrete Schritte oder Belege (Links zu Läufen, Screenshots). -->

## Checkliste

<!--
Org-weite Standard-Checkliste. Sie gilt für dieses Repo und für jedes Repo
ohne eigenes .github/pull_request_template.md. frontend, backend, worker und
deployment haben eigene, spezialisierte Checklisten.

Release-PRs (`dev` oder `promote/*` → `main`) verwenden stattdessen
`.github/pull_request_template/release.md`.

Jeder Punkt wird abgehakt, bevor der PR gemergt werden kann. Der CI-Check
"PR Checklist" blockiert den Merge, solange hier noch ein offenes "- [ ]" steht.

Trifft ein Punkt nicht zu: mit "n/a" markieren UND abhaken, z. B.
- [x] n/a — HARNESS.md: keine Harness-Entscheidung geändert

Die reviewende Person prüft, dass die Häkchen stimmen, und bestätigt das mit
ihrem Approval. Die Pflicht-CI-Checks werden separat über die
Branch-Protection erzwungen und hier nicht wiederholt.
-->

**Funktionale Eignung**

- [ ] Vollständigkeit: Alle Akzeptanzkriterien des verlinkten Issues sind umgesetzt; Abweichungen oder offene Punkte sind oben begründet
- [ ] Korrektheit: Die Änderung wurde wie unter „Prüfung" beschrieben nachvollziehbar geprüft (Test, Lauf oder manuelle Probe)
- [ ] Auswirkungen: Betroffene andere Repos sind geprüft; nötige Folge-PRs sind verlinkt

**Sicherheit & Doku**

- [ ] Keine Secrets, Tokens oder Credentials im Diff
- [ ] Doku: `claude_docs/HANDOVER.md` aktualisiert; `docs/HARNESS.md`, falls eine Harness-Entscheidung geändert wurde; übrige `docs/` (Endnutzer-Doku, Entwicklerguide, Technologiestack, Diagramme in `c4/`, `er/`, `sequenz/`, `ci-cd/`) nachgezogen, falls betroffen
