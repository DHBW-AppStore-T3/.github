---
name: tdd
description: "Superpowers TDD: Red-Green-Refactor Loop. Triggert auf: 'implementiere mit TDD', 'schreibe erst einen Test', '/tdd'."
---

# Superpowers: Test-Driven Development (TDD)

Regel: **Kein Produktionscode ohne vorherigen fehlschlagenden Test.**

## Red-Green-Refactor Loop

1. **Rot:** Schreibe einen Test für das gewünschte Verhalten. Führe ihn aus und prüfe, dass er aus dem erwarteten Grund fehlschlägt.
2. **Grün:** Schreibe den minimalen Produktionscode, der den Test besteht.
3. **Refactor:** Optimiere Code & Tests bei grüner Testsuite.
4. **Full Suite:** Führe die gesamte Testsuite aus, um Regressionen auszuschließen.

## Repo-Befehle

### backend / worker (Python / Poetry)
```bash
poetry run pytest path/to/test.py -v     # Einzeleinheit (Rot/Grün)
poetry run pytest                       # Volle Testsuite
poetry run ruff check .                 # Linting (beide)
poetry run black --check .              # Format-Check (worker)
```

### frontend (Vue 3 / Vitest)
```bash
npm run test                            # Vitest Einzellauf
npm run test:watch                      # Watch-Modus während TDD
npm run test:coverage                   # Coverage prüfen
npx vue-tsc -b --noEmit                 # TypeScript Typecheck
```
