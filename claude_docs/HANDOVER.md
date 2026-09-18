# Handover — .github (Organisation Doku & Standards)

Lebendes Übergabedokument gemäß [HARNESS.md](docs/HARNESS.md) Abschnitt 1.2.
Jede Session liest dieses Dokument zu Beginn und aktualisiert es vor dem Abschluss.

---

## 1. Status & Fokus
- **Rolle:** Zentrales Dokumentations-, Governance- und Standard-Repository der Organisation `DHBW-AppStore-T3`.
- **Harness Core:** Enthält `docs/HARNESS.md` und `docs/GET_STARTED_WITH_HARNESS.md`.
- **Universelle Werkzeuge:** Beherbergt universelle Claude-Skills (`.claude/skills/tdd`, `.claude/skills/ship-feature`) und Agents (`.claude/agents/code-reviewer.md`).
- **Knowledge Graph:** Hält den konsolidierten Cross-Repo Graph (`graphify-out/cross-repo-graph.json`, `graphify-out/graph.html`) und den Update-Workflow (`.github/workflows/merge-graphs.yml`).

---

## 2. In Arbeit & Nächste Schritte
- [ ] PR #1 reviewen und in `main` mergen (Human Gate).
- [ ] PRs in den übrigen Repos (backend#3, deployment#33, frontend#2, worker#3, moodle_appstore#5, self-service-ui#4) mergen.

---

## 3. Bekannte Fallstricke & Blocker
1. **Scope von .github:** Hier liegen nur org-weite Standards und Doku. Keine anwendungs-spezifischen Code-Dateien ablegen.
2. **GitHub API Beschränkungen:** `members_can_delete_repositories` und `members_can_change_repo_visibility` können auf dem aktuellen GitHub-Plan nicht deaktiviert werden.

---

## 4. Letzte Übergaben (Historie)
- **2026-09-18:** Cross-Repo Graph gemergt (`cross-repo-graph.json`, `graph.html`); Workflow `merge-graphs.yml` angelegt; `HANDOVER.md` und `CLAUDE.md` für `.github` hinzugefügt; Dokumentationsstatus in `HARNESS.md` aktualisiert.
- **2026-09-17:** Universelle Skills und `code-reviewer` aus `deployment` nach `.github` umgezogen; `HANDOVER.md`-Standard definiert (#1).
