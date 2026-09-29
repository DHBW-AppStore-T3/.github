---
name: User Story
about: Standardisierte User Story aus Flow 1 (/user-story) für den Harness-Workflow
title: "feat: "
labels: ["user-story", "ready-for-dev"]
assignees: ""
---

## 1. User Story
**Als** [Persona: z. B. Dozent / Student / Admin]  
**möchte ich** [Funktionalität / Ziel]  
**damit** [Nutzen / Mehrwert].

---

## 2. Klarifizierungszusammenfassung
- **Zielgruppe & Stakeholder:**
- **Scope (In-Scope für MVP):**
- **Out-of-Scope:**
- **Betroffene Repos:** [`backend` | `frontend` | `worker` | `deployment` | `moodle_appstore` | `self-service-ui`]

---

## 3. Technische Design Specs (Gewählte Architektur)
- **Gewählte Architektur-Option:** [Beschreibung & Begründung der Wahl]
- **Komponenten & Datenfluss:**
- **Schnittstellen & Interaktionen:**

---

## 4. Implementierungs-Specs & Contracts
- **API Endpoints (FastAPI / OpenAPI 3.1):**
  - Method: `GET` / `POST` / `PUT` / `DELETE`
  - Route: `/api/v1/...`
  - Request Model: `...`
  - Response Model: `...`
- **Datenbank & Modelle (SQLAlchemy / Alembic):**
- **Worker Tasks & Queues (Celery / RabbitMQ / Redis):**
- **Frontend UI & State (Vue 3 / Pinia / Tailwind):**

---

## 5. Akzeptanzkriterien (Definition of Done)
- [ ] **Kriterium 1:** Given ... When ... Then ...
- [ ] **Kriterium 2:** Given ... When ... Then ...
- [ ] **Kriterium 3:** OpenAPI-Schema validiert und Frontend-Typen synchronisiert.

---

## 6. TDD Testplan
- **Unit Tests (rot zuerst):**
  - Testfall 1: ...
  - Testfall 2: ...
- **Integration Tests:**
  - Testfall 1: ...

---
*Erstellt via Harness Flow 1 (`/user-story`). Bereit zur Umsetzung via Harness Flow 2 (`/harness-workflow`).*
