# Handover — .github (Organisation Doku & Standards)

Lebendes Übergabedokument gemäß [HARNESS.md](docs/HARNESS.md) Abschnitt 1.2.
Jede Session liest dieses Dokument zu Beginn und aktualisiert es vor dem Abschluss.

---

## 1. Status & Fokus
- **Rolle:** Zentrales Dokumentations-, Governance- und Standard-Repository der Organisation `DHBW-AppStore-T3`.
- **Harness Core:** `docs/HARNESS.md` und `docs/GET_STARTED_WITH_HARNESS.md` vollständig auf 2 Flows reengineered.
- **Die 2 Flows:**
  - **Flow 1 (`/user-story`):** Interaktive Spezifikation (Klarifizierung -> Design-Optionen -> Impl-Optionen -> Issue-Erstellung via `gh`).
  - **Flow 2 (`/harness-workflow`):** Autonomer Issue-Bau (Branch von `dev` -> TDD -> PR auf `dev` -> Auto-Merge bei grünen CI Gates -> Staging Deployment -> Hermes Discord Status).
- **Trunk-Struktur:** `dev` org-weit als Integrations-Branch ausgerollt; `main` rein menschlich reserviert mit Test Coverage Gate.
- **Universelle Werkzeuge:** `.claude/skills/user-story`, `.claude/skills/harness-workflow`, `.claude/skills/ship-feature`, `.claude/skills/tdd`, `.claude/agents/code-reviewer.md`.
- **Issue Templates:** `.github/ISSUE_TEMPLATE/user-story.md`.
- **Knowledge Graph:** Hält den konsolidierten Cross-Repo Graph (`graphify-out/cross-repo-graph.json`, `graphify-out/graph.html`) und den Update-Workflow (`.github/workflows/merge-graphs.yml`).

---

## 2. In Arbeit & Nächste Schritte
- [x] Offene grüne PRs gemergt (`.github #1`, `backend #3`, `deployment #33`, `frontend #3`, `self-service-ui #3`, `worker #2`, `worker #3`).
- [x] `dev`-Branch org-weit angelegt und gepusht.
- [x] Flow 1 (`user-story`) & Flow 2 (`harness-workflow`) Skills und Issue-Template erstellt.
- [ ] CI-Workflows in `backend`, `frontend`, `worker`, `deployment` auf `dev`-Trunk + Test Coverage Gate für `main` finalisieren.

---

## 3. Bekannte Fallstricke & Blocker
1. **Scope von .github:** Hier liegen nur org-weite Standards und Doku. Keine anwendungs-spezifischen Code-Dateien ablegen.
2. **GitHub API Beschränkungen:** `members_can_delete_repositories` und `members_can_change_repo_visibility` können auf dem aktuellen GitHub-Plan nicht deaktiviert werden.
3. **Menschliches Main Gate:** Der Agent darf niemals direkt auf `main` mergen oder pushen.

---

## 4. Letzte Übergaben (Historie)
- **2026-09-18 (Harness Reengineering):** Reengineering auf 2 Flows abgeschlossen: Flow 1 `/user-story`, Flow 2 `/harness-workflow` (inkl. Alias `/ship-feature`), Issue-Template `user-story.md` ergänzt; `HARNESS.md`, `GET_STARTED_WITH_HARNESS.md` und `CLAUDE.md` aktualisiert; alle 7 offenen grünen PRs gemergt; `dev`-Branches org-weit ausgerollt.
- **2026-09-18:** Cross-Repo Graph gemergt (`cross-repo-graph.json`, `graph.html`); Workflow `merge-graphs.yml` angelegt; `HANDOVER.md` und `CLAUDE.md` für `.github` hinzugefügt; Dokumentationsstatus in `HARNESS.md` aktualisiert.
- **2026-09-17:** Universelle Skills und `code-reviewer` aus `deployment` nach `.github` umgezogen; `HANDOVER.md`-Standard definiert (#1).
