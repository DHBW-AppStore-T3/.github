---
name: user-story
description: "Führt den interaktiven User-Story-Generierungs-Flow (Flow 1) durch: User formuliert Feature-Wunsch -> 1. Klarifizierungsfragen -> 2. Design-Specs mit Architekturoptionen zur Auswahl -> 3. Implementierungs-Specs mit technischen Optionen zur Auswahl -> 4. Erstellung des fertigen GitHub-Issues mit Akzeptanzkriterien und TDD-Testplan. Triggers on: ich will Feature ..., erstelle User Story für ..., /user-story, neue Story anlegen."
---

# /user-story (Flow 1: User Story Generierung)

Dieser Skill implementiert **Flow 1** des Harness-Engineerings. Er führt einen interaktiven Klärungs- und Spezifikationsdialog mit dem User durch, um aus einem informellen Feature-Wunsch ein abnahmebereites, technisch präzises GitHub-Issue für den autonomen **Flow 2** (`/harness-workflow`) zu generieren.

## Übersicht des Ablaufs

```
User: "Ich will Feature <X>"
   │
   ├─► Schritt 1: Klarifizierungsfragen
   │     └─► Scope, Persona, betroffene Repos, Randbedingungen abfragen
   │     └─► Auf Antwort des Users warten
   │
   ├─► Schritt 2: Design Specs zur technischen Implementierung
   │     └─► Architektonische Optionen ausarbeiten (Option A vs. Option B mit Vor-/Nachteilen)
   │     └─► Auf Auswahl des Users warten
   │
   ├─► Schritt 3: Implementierungs-Specs
   │     └─► OpenAPI-Contracts, DB-Modelle, Celery-Tasks, UI-State, TDD-Testplan
   │     └─► Technische Umsetzungsoptionen anbieten
   │     └─► Auf Auswahl / Bestätigung des Users warten
   │
   └─► Schritt 4: GitHub-Issue anlegen
         └─► gh issue create mit Labels (user-story, ready-for-dev)
         └─► Fertige Issue-Nummer (#ID) ausgeben für Flow 2: "Bau mir Issue #ID"
```

---

## Protokoll für den Agenten

### Phase 1: Klarifizierungsfragen
Sobald der User sagt "Ich will Feature <X>" (oder ähnlich), **keinen** Code schreiben und **noch keine** Implementierung vorschlagen! Stelle gezielte, nummerierte Fragen:

1. **Zielgruppe & Stakeholder:** Wer nutzt das Feature konkret (Dozent, Student, System-Admin)?
2. **Fachlicher Kern & Problem:** Welches Problem wird gelöst, was ist der Mehrwert?
3. **Scope-Abgrenzung:** Was ist minimaler Pflicht-Scope (MVP), was ist optional oder Out-of-Scope?
4. **System-Komponenten:** Welche Repositories sind voraussichtlich betroffen?
   - `backend` (FastAPI, PostgreSQL, Alembic)
   - `frontend` (Vue 3, Pinia, Tailwind)
   - `worker` (Celery, Redis, RabbitMQ, Terraform)
   - `deployment` (Docker Compose, Caddy, Keycloak)
   - `moodle_appstore` / `self-service-ui`
5. **Randbedingungen & Nicht-Funktionales:** Besondere Performance-, Auth-, Quota- oder Sicherheitsanforderungen?

*Stoppe hier und warte auf die Antwort des Users.*

---

### Phase 2: Design Specs zur technischen Implementierung
Nachdem der User geantwortet hat, erstelle die architektonischen Design-Spezifikationen.
**Pflicht:** Biete immer mindestens 2 sinnvolle Architektur-Optionen zur Auswahl an:

- **Option A (z. B. Synchron / Direkt):**
  - Architektur & Datenfluss
  - Vorteile & Nachteile
  - Komplexität / Aufwand
- **Option B (z. B. Asynchron / Entkoppelt via Celery/SSE):**
  - Architektur & Datenfluss
  - Vorteile & Nachteile
  - Komplexität / Aufwand
- **Empfehlung des Agenten:** Klare begründete Empfehlung.

*Frage den User nach seiner Wahl (z. B. "Welche Option bevorzugst du: Option A oder Option B?"). Stoppe hier und warte auf die Antwort.*

---

### Phase 3: Implementierungs-Specs
Nachdem die Design-Option gewählt wurde, arbeite die konkreten technischen Verträge und Specs aus:

1. **API Contracts (OpenAPI 3.1 / FastAPI):**
   - Endpunkte (`METHOD /api/v1/...`)
   - Pydantic Request- und Response-Schemas (Feldnamen, Datentypen, Validierungen)
   - Fehlercodes (`400`, `401`, `403`, `404`, `422`)
2. **Datenbank & Persistenz:**
   - SQLAlchemy-Modelle, Relationen, Indizes
   - Notwendigkeit einer Alembic-Migration
3. **Worker / Asynchrone Tasks (falls relevant):**
   - Celery Task Name, Payload-Typisierung, Retry-Policies, SSE-Events
4. **Frontend UI & State Management (falls relevant):**
   - Vue-Views und Komponenten
   - Pinia Store Actions & State
   - Konsumierung der typisierten API (`src/types/api.generated.ts`)
5. **Akzeptanzkriterien (Definition of Done):**
   - Formuliert als konkrete Given-When-Then Kriterien
6. **TDD-Testplan:**
   - Liste konkreter Unit-Tests (zuerst fehlschlagend)
   - Liste konkreter Integration-Tests
7. **Optionen zur Implementierungsdetail:**
   - Biete 2 Detail-Optionen an (z. B. Option 1: Optimistic UI vs. Option 2: Server-Confirm, oder Caching vs. Fresh Query).

*Frage den User nach Bestätigung oder Option-Wahl. Stoppe hier und warte auf die Antwort.*

---

### Phase 4: User Story fertig & GitHub-Issue anlegen
Sobald der User bestätigt hat, formatiere die Spezifikation als standardisierte User Story und lege das Issue über das GitHub CLI (`gh`) an:

```bash
gh issue create \
  --repo "DHBW-AppStore-T3/<ziel-repo oder .github>" \
  --title "feat: <Feature-Titel>" \
  --label "user-story,ready-for-dev" \
  --body "..."
```

**Struktur des Issue-Bodys:**
- **1. User Story** (Als / Möchte ich / Damit)
- **2. Klarifizierungszusammenfassung** (Stakeholder, MVP-Scope, Out-of-Scope)
- **3. Gewählte Technische Design Spec** (Architektur & Komponenten)
- **4. Implementierungs-Specs & Contracts** (OpenAPI Endpoints, DB, Worker, UI)
- **5. Akzeptanzkriterien** (Checkliste mit `- [ ]`)
- **6. TDD Testplan** (Unit & Integration Tests)

Gib dem User die Issue-URL und die Issue-Nummer aus und schließe ab mit:
> "✅ User Story ist fertig und auf GitHub als Issue **#<ID>** angelegt!
> Du kannst den autonomen Bau jetzt starten mit:
> **`Bau mir Issue #<ID>`** (Flow 2: `/harness-workflow`)."
