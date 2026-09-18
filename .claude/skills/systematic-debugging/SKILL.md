---
name: systematic-debugging
description: "Superpowers Debugging: Ursachenanalyse vor Fixes. Triggert auf: 'finde den Fehler', 'warum schlägt der Test fehl', '/debug'."
---

# Superpowers: Systematic Debugging

Regel: **Kein Code-Fix ohne nachgewiesene Root Cause.**

## 4-Phasen Debugging Loop

1. **Fehler isolieren:** Reproduziere den Fehler mit minimalem Setup oder einem isolierten Testfall.
2. **Quellcode & Logs lesen:** Lies den echten Quellcode und die genauen Stacktraces, statt aus Fehlermeldungen zu raten.
3. **Hypothese aufstellen & belegen:** Bestätige die vermutete Ursache durch Logs, Breakpoints oder temporäre Assertions.
4. **Minimalen Fix verifizieren:** Behebe die Root Cause gezielt und führe die Regressionstests aus.
