---
name: tdd
description: "Superpowers TDD: Red-Green-Refactor Loop. Triggert auf: 'implementiere mit TDD', 'schreibe erst einen Test', '/tdd'."
---

# Superpowers: Test-Driven Development (TDD)

Regel: **Kein Produktionscode ohne vorherigen fehlschlagenden Test.**

## Red-Green-Refactor Loop

1. **Rot:** Testbefehl aus lokaler `CLAUDE.md` ermitteln. Isolierten Test für das gewünschte Verhalten schreiben. Ausführen und prüfen, dass er aus dem exakt erwarteten Grund fehlschlägt.
2. **Grün:** Minimalen Produktionscode schreiben, bis der Test besteht.
3. **Refactor:** Code & Tests optimieren. Linter und Formatter des aktuellen Repos ausführen.
4. **Full Suite:** Vollständige Testsuite des Repos ausführen, um Regressionen auszuschließen.

