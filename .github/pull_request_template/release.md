## Release `dev` → `main`

<!--
Release-PR: bringt den aktuellen Stand von `dev` auf `main`. Dieses Repo
wird nicht deployt, aber `main` ist die Referenz der Organisation:
- `.github/workflows/pr-checklist.yml` ist der wiederverwendbare Check
  (Aufruf über `@main`),
- PR-/Issue-Templates und `SECURITY.md` sind die Org-Standards,
  `profile/README.md` ist die öffentliche Org-Seite,
- `docs/` und `.claude/` sind die Harness-Referenz.

Anlegen:
  gh pr create --base main --head dev --title "release: <Datum>" \
    --body-file .github/pull_request_template/release.md
oder im Browser: .../compare/main...dev?expand=1&template=release.md

Mit Merge-Commit mergen, nicht squashen, damit `dev` und `main` nicht
auseinanderlaufen.
-->

**Enthaltene PRs:**

<!-- Alle PRs seit dem letzten Release, z. B. aus `git log --oneline origin/main..origin/dev`. -->

-

## Release-Checkliste

<!--
Jeder Punkt wird abgehakt, bevor der PR gemergt werden kann. Trifft ein
Punkt nicht zu: mit "n/a" markieren UND abhaken, z. B.
- [x] n/a, Workflows: keine Änderung an wiederverwendbaren Workflows

Die Änderungs-Checklisten der enthaltenen PRs werden hier nicht wiederholt.
-->

- [ ] Enthaltene PRs: Liste oben vollständig; jeder enthaltene PR hat eine vollständige Checkliste; PRs, die ohne Review auf `dev` gemergt wurden, sind in diesem PR reviewt
- [ ] Workflows: Geänderte wiederverwendbare Workflows (z. B. `pr-checklist.yml`) passen zu den Aufrufern und PR-Templates; offene PRs dort werden nach dem Merge nicht ungewollt blockiert
- [ ] Org-Standards: Änderungen an Templates, `SECURITY.md` oder `profile/` sind für alle betroffenen Repos und die öffentliche Org-Seite gewollt
- [ ] Harness: Geänderte Skills, Hooks und Docs sind mit den Repos konsistent (genannte Befehle, Pfade und Branches existieren), und das Team ist über geänderte Abläufe informiert
- [ ] Sicherheit: Keine Secrets, Tokens oder Credentials im gesamten Release-Diff
- [ ] Doku: `docs/` (Endnutzer-Doku, Entwicklerguide, Technologiestack, Diagramme) und `profile/README.md` beschreiben den Stand der Repos, der jetzt gilt
