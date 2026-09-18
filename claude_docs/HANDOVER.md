# Handover — .github (Organisation Doku & Standards)

Lebendes Übergabedokument gemäß [HARNESS.md](docs/HARNESS.md) Abschnitt 1.2.
Jede Session liest dieses Dokument zu Beginn und aktualisiert es vor dem Abschluss.

---

## 1. Status & Fokus
- **Rolle:** Zentrales Dokumentations-, Governance- und Standard-Repository der Organisation `DHBW-AppStore-T3`.
- **Harness Core:** Vollständig auf die 2 Flows ausgerichtet (`docs/HARNESS.md`, `docs/GET_STARTED_WITH_HARNESS.md`).
- **Die 2 Flows & Toolkits (Best Practice, schlanke Skills ohne Kontext-Bloat):**
  - **Flow 1 (`.claude/skills/user-story`):** Interaktive Spezifikation (Klarifizierung -> Design-Optionen -> Impl-Optionen -> Issue via `gh`).
  - **Flow 2 (`.claude/skills/harness-workflow`):** Autonomer Issue-Bau (`dev`-Trunk -> TDD -> PR auf `dev` -> Auto-Merge -> Staging-Deploy -> Hermes Discord Status).
  - **Superpowers (`.claude/skills/tdd`, `.claude/skills/systematic-debugging`):** Knackige Red-Green-Refactor- und Ursachenanalyse-Engines.
  - **ECC (`.claude/agents/code-reviewer.md`):** Schlanker Pre-PR-Reviewer für den DHBW-AppStore-Stack.
- **Trunk-Struktur:** `dev` org-weit als Integrations-Branch ausgerollt; `main` rein menschlich reserviert mit Test Coverage Gate.
- **Issue Templates:** `.github/ISSUE_TEMPLATE/user-story.md`.
- **Knowledge Graph:** Hält den konsolidierten Cross-Repo Graph (`graphify-out/cross-repo-graph.json`, `graphify-out/graph.html`) und den Update-Workflow (`.github/workflows/merge-graphs.yml`).

---

## 2. In Arbeit & Nächste Schritte
- [x] Offene grüne PRs gemergt (`.github #1`, `backend #3`, `deployment #33`, `frontend #3`, `self-service-ui #3`, `worker #2`, `worker #3`).
- [x] `dev`-Branch org-weit angelegt und gepusht.
- [x] CI-Workflows in allen Repositories auf `dev`-Trunk + Test Coverage Gate für `main` umgestellt.
- [x] Skills aufgeräumt, redundant gewordene Aliase (`ship-feature`) entfernt, Skills radikal gekürzt (kontext-schonend) und Superpowers `systematic-debugging` ergänzt.

---

## 3. Bekannte Fallstricke & Blocker
1. **Scope von .github:** Hier liegen nur org-weite Standards und Doku. Keine anwendungs-spezifischen Code-Dateien ablegen.
2. **Kontext-Fenster-Effizienz:** Skills müssen kurz und imperativ gehalten werden (unter 40 Zeilen). Ausführliche Doku gehört nach `docs/`, nicht in `SKILL.md`.
3. **Menschliches Main Gate:** Der Agent darf niemals direkt auf `main` mergen oder pushen.

---

## 4. Letzte Übergaben (Historie)
- **2026-09-18 (Harness Streamlining & Best Practice):** Skills radikal verschlankt (kein Kontext-Bloat); `ship-feature`-Duplikat entfernt; Superpowers-Sammlung (`tdd`, `systematic-debugging`) und ECC (`code-reviewer`) sauber als Core-Toolkits neben den 2 Projekt-Flows (`user-story`, `harness-workflow`) geordnet; globale Symlinks aktualisiert.
- **2026-09-18:** Reengineering auf 2 Flows (`user-story`, `harness-workflow`); alle 7 offenen grünen PRs gemergt; `dev`-Branches org-weit ausgerollt.
