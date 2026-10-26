---
name: user-story
description: "Flow 1: Interaktiver Dialog für Feature-Wünsche. Triggert auf: 'Ich will Feature ...', 'Neue User Story', '/user-story'."
---

# Flow 1: User Story Generierung

Überführt Feature-Wünsche interaktiv in abnahmebereite GitHub-Issues für Flow 2 (`/harness-workflow`).

## Phasen (Sequentiell ausführen — nach jedem Schritt auf User-Antwort warten!)

1. **Klarifizierungsfragen:**
   - **Persona:** Für wen ist das Feature (Dozent / Student / Admin)?
   - **Scope:** Was ist minimaler Pflicht-Scope (MVP), was ist Out-of-Scope?
   - **Betroffene Repos:** `backend`, `frontend`, `worker`, `deployment`, `moodle_appstore`, `self-service-ui`?
   - **Randbedingungen:** Auth, Quotas, Performance, Einschränkungen?
   *-> Stoppe und warte auf Antwort.*

2. **Design Specs (Architektur):**
   - Entwickle mindestens 2 Architektur-Optionen (z. B. Option A: synchron REST vs. Option B: asynchron Celery/SSE).
   - Vergleiche Vor-/Nachteile, Komplexität und gib eine klare Empfehlung ab.
   *-> Stoppe und warte auf User-Auswahl.*

3. **Implementierungs-Specs (Technik):**
   - API & Contracts (Endpunkte, Request/Response-Schemas).
   - Datenmodell & Persistenz (Tabellen, Migrationen).
   - Asynchrone Jobs / Worker (falls erforderlich).
   - UI & Client Integration (Stores, Views, typisierte API-Clients).
   - Akzeptanzkriterien (Given-When-Then) & TDD-Testplan (Unit & Integration).
   - Biete 2 Detail-Optionen (z. B. Optimistic UI vs. Server-Confirm).
   *-> Stoppe und warte auf User-Bestätigung.*

4. **GitHub Issue anlegen:**
   - Erstelle das Issue via GitHub CLI:
     ```bash
     gh issue create --repo DHBW-AppStore-T3/<repo> --title "feat: <Titel>" --label "user-story,ready-for-dev" --body "<Spezifikation>"
     ```
   - Melde Issue-URL und #ID. Übergabe an Flow 2: `"Bau mir Issue #<ID>"`.
