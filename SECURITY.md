# Security Policy

## Sicherheitslücken melden

Bitte melde Sicherheitslücken **nicht** als öffentliches GitHub-Issue.

Nutze stattdessen **GitHub Security Advisories**:
[Neue Sicherheitslücke melden](https://github.com/DHBW-AppStore-T3/.github/security/advisories/new)

Wir bestätigen den Eingang innerhalb von 2 Werktagen und kommunizieren den
weiteren Verlauf über den Advisory-Thread.

## Scope

Dieses Repository enthält Org-weite Harness-Konfiguration und Dokumentation.
Sicherheitsrelevant sind insbesondere:

- Secrets oder Credentials in `.claude/`-Konfigurationen
- Guardrail-Bypässe im `appstore-prod-guardrail.py`-Hook
- Unbeabsichtigte Weitergabe von Org-Zugriffsrechten durch Workflow-Änderungen
