# Handover — .github (Organisation Doku & Standards)

Lebendes Übergabedokument gemäß [HARNESS.md](docs/HARNESS.md) Abschnitt 1.2.
Jede Session liest dieses Dokument zu Beginn und aktualisiert es vor dem Abschluss.

---

> **Stand Oktober 2026:** Epic [#12](https://github.com/DHBW-AppStore-T3/.github/issues/12) entfernt den OpenStack-VM-Pfad aus allen Repos; alle Apps laufen als Pods, die Windows-App folgt über KubeVirt.

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
- [ ] `frontend/claude_docs/` mit Architektur-Inhalten befüllen (Unterordner angelegt, Dateien noch leer).

---

## 3. Bekannte Fallstricke & Blocker
1. **Scope von .github:** Hier liegen nur org-weite Standards und Doku. Keine anwendungs-spezifischen Code-Dateien ablegen.
2. **Kontext-Fenster-Effizienz:** Skills müssen kurz und imperativ gehalten werden (unter 40 Zeilen). Ausführliche Doku gehört nach `docs/`, nicht in `SKILL.md`.
3. **Menschliches Main Gate:** Der Agent darf niemals direkt auf `main` mergen oder pushen.

---

## 4. Letzte Übergaben (Historie)
- **2026-10-29 (Doku nach #12 bereinigt, Branch `docs/remove-openstack-leftovers`):** `HARNESS.md`, `GET_STARTED_WITH_HARNESS.md`, `technologiestack.md`, `AppentwicklerGuide.md` (jetzt `appstore.yaml`-basiert, Beispiele gegen `parse_spec` geprüft), `DokumentationEndnutzer.md` (Credentials-, Quota- und Infrastruktur-Abschnitte entfernt), `ci-cd/*` (GitOps statt Compose/Watchtower) und die Sequenzdiagramme (Postgres-Queue statt RabbitMQ/Celery, Pod-Deployer statt Terraform/Packer) auf den Stand Kubernetes/KubeVirt gebracht; Issue-Template und `user-story`-Skill ohne Celery/Vue. **Offen:** `docs/c4/*.drawio` (C1–C3 zeigen noch OpenStack, RabbitMQ, Celery-Worker mit Packer/Terraform, Vue) und `docs/er/er.dbml`/`er.svg` (Stand vor Postgres-Queue und #12) müssen im Editor bzw. aus dem Backend-Schema neu erzeugt werden; Screenshots in `DokumentationEndnutzer.md` (Dashboard, Deployment-Details) zeigen teils noch die alte Oberfläche; `QS-Massnahmen-Beleg.md` ist ein historischer Beleg und blieb unverändert.
- **2026-09-23:** Lokales Harness-Setup durchgeführt: alle 6 Repos auf `DHBW-AppStore-T3` umgestellt und gepullt; globale Symlinks für `/tdd`, `/ship-feature`, `code-reviewer` nach `~/.claude/` gesetzt; `frontend/claude_docs/` Unterordner angelegt; `moodle_appstore` + `self-service-ui` geklont und mit `HANDOVER.md` ausgestattet.
- **2026-09-18 (Harness Streamlining & Best Practice):** Skills radikal verschlankt (kein Kontext-Bloat); `ship-feature`-Duplikat entfernt; Superpowers-Sammlung (`tdd`, `systematic-debugging`) und ECC (`code-reviewer`) sauber als Core-Toolkits neben den 2 Projekt-Flows (`user-story`, `harness-workflow`) geordnet; globale Symlinks aktualisiert.
- **2026-09-18:** Reengineering auf 2 Flows (`user-story`, `harness-workflow`); alle 7 offenen grünen PRs gemergt; `dev`-Branches org-weit ausgerollt.
