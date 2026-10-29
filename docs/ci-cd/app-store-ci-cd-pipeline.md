# Build-Prozess & CI/CD Pipeline Appstore

> **Hinweis (Oktober 2026, [#12](https://github.com/DHBW-AppStore-T3/.github/issues/12)):** Dieses Dokument beschreibt teilweise den früheren Ablauf, bei dem Apps als OpenStack-VMs ausgerollt wurden (Packer, Terraform, OpenStack-Credentials, Quotas, Infrastructure-Ansicht). Alle Apps laufen inzwischen als **Pods** im Kubernetes-Cluster und werden über eine `appstore.yaml` beschrieben (Vertrag und Beispiele: [app-registry](https://github.com/DHBW-AppStore-T3/app-registry)). Die Windows-App folgt über KubeVirt. Aussagen zu den genannten VM-Themen sind überholt; das Dokument wird bei Gelegenheit überarbeitet.

Diese Pipeline beschreibt den Entwicklungsprozess, das Bauen und das Deployment der Hauptplattform selbst (Frontend, Backend, Worker).

---

## Phase 1: Local Development & Pre-commit Hooks

Bereits vor dem Commit wird Code-Qualität durch **automatische Pre-commit Hooks** sichergestellt.

### Technologie: Pre-commit Framework

**Installation:**
```bash
pip install pre-commit
pre-commit install
```

**Konfiguration:** `.pre-commit-config.yaml`

### Automatische Checks bei jedem Commit:

#### 1. Allgemeine Checks (pre-commit-hooks)
- **trailing-whitespace**: Entfernt überflüssige Leerzeichen am Zeilenende
- **end-of-file-fixer**: Stellt sicher, dass Dateien mit Newline enden
- **check-yaml**: Validiert YAML-Syntax
- **check-json**: Validiert JSON-Syntax
- **check-toml**: Validiert TOML-Syntax (pyproject.toml)
- **check-merge-conflict**: Erkennt Merge-Konflikt-Marker
- **debug-statements**: Findet vergessene Debug-Statements (pdb, print)
- **check-added-large-files**: Verhindert versehentliches Committen großer Dateien

#### 2. Python Code Formatting
- **Black (v24.1.1)**
  - Line Length: 120 Zeichen
  - Target Version: Python 3.11
  - Automatisches Formatieren nach PEP 8 Standard
  
- **isort (v5.13.2)**
  - Automatisches Sortieren von Python Imports
  - Gruppierung: Standard Library → Third Party → Local
  - Kompatibel mit Black

#### 3. Linting
- **Ruff (v0.3.0)**
  - Moderner, extrem schneller Python Linter
  - `--fix`: Automatisches Beheben einfacher Fehler
  - `--exit-non-zero-on-fix`: Commit wird blockiert wenn Fixes nötig sind
  
**Ruff Rules (pyproject.toml):**
  - **E, W**: pycodestyle errors & warnings (PEP 8)
  - **F**: pyflakes (logische Fehler, unused imports/variables)
  - **I**: isort (Import-Sortierung)
  - **N**: pep8-naming (Naming Conventions)
  - **UP**: pyupgrade (Python Version Upgrades)
  - **B**: flake8-bugbear (Bug-anfällige Patterns)
  - **C4**: flake8-comprehensions (List/Dict Comprehensions)
  - **SIM**: flake8-simplify (Code-Vereinfachungen)
  - **TCH**: flake8-type-checking (Type Import Optimization)

**Ergebnis:**
- Code ist formatiert, gelintet und bereit für Commit
- Bei Fehlern: Commit wird blockiert, Developer muss Fehler beheben

---

## Phase 2: Pull Request & CI Quality Checks

Sobald ein Pull Request erstellt wird, startet die **GitHub Actions CI Pipeline**.

### Trigger
- `pull_request` Event auf Branches: `main`, `develop`

### Job 1: Lint & Format Check

**Runner:** `ubuntu-latest`  
**Python Version:** 3.11  
**Dependency Management:** Poetry

**Steps:**
1. **Checkout Code**: `actions/checkout@v4`
2. **Setup Python**: `actions/setup-python@v5` mit pip cache
3. **Install Poetry**: Offizielle Installation via curl
4. **Install Dependencies**: `poetry install --with dev`
5. **Run Checks:**
   - `poetry run ruff check .` - Linting (alle Ruff Rules)
   - `poetry run black --check .` - Format Check (kein Auto-Fix)
   - `poetry run isort --check-only .` - Import-Sortierung Check
   - `poetry run mypy app/ --ignore-missing-imports` - Type Checking (optional)

**Quality Standards:**
- Ruff darf keine Fehler finden
- Black darf keine Formatierungsfehler finden
- isort darf keine Sortierungsfehler finden
- MyPy: Type Errors werden aktuell toleriert (`continue-on-error: true`)

---

### Job 2: Run Tests

**Runner:** `ubuntu-latest`  
**Strategie:** Matrix Build  

**Steps:**
1. **Setup Python**
2. **Install Poetry & Dependencies**
3. **Run Tests:**
   ```bash
   poetry run pytest -v \
     -m "unit or not integration" \
     --cov=app \
     --cov-report=xml \
     --cov-report=term
   ```

**Test-Standards:**
- **Unit Tests**: Schnelle, isolierte Tests
- **Integration Tests**: Optional (markiert mit `@pytest.mark.integration`)
- **Coverage-Report**

**Ergebnis:**
- Tests bestanden → weiter zu Build
- Tests fehlgeschlagen → PR blockiert

---

### Job 3: Build Docker Image (Test Build)

**Steps:**
1. **Checkout Code**
2. **Setup Docker Buildx**: Multi-Platform Build Support
3. **Extract Metadata**: `docker/metadata-action@v5`
   - Tags generieren (branch, sha, PR number)
4. **Build Image:**
   ```yaml
   uses: docker/build-push-action@v5
   with:
     context: .
     file: ./Dockerfile
     push: false  # Kein Push bei PR!
     cache-from: type=gha
     cache-to: type=gha,mode=max
     outputs: type=docker,dest=/tmp/worker-image.tar
   ```
5. **Upload Artifact**: Image als GitHub Artifact speichern

**Build Cache:**
- GitHub Actions Cache wird genutzt
- Beschleunigt nachfolgende Builds erheblich

**Ergebnis:**
- Build erfolgreich → PR kann gemerged werden
- Build fehlgeschlagen → PR blockiert

---

## Phase 3: Code Review

**Manueller Schritt:**
- Ein anderer Entwickler reviewt den Code
- Prüft auf Logik-Fehler, Design-Patterns, Best Practices
- Erst nach **Approval** + **Alle CI Checks bestanden** kann gemerged werden

---

## Phase 4: Build & Registry (Main Branch)

Nach erfolgreichem Merge in `main` startet die **Production Build Pipeline**.

### Trigger
- `push` Event auf Branch: `main`
- Nur wenn alle Quality Checks bestanden

### Job 1: Quality Assurance (erneut)

Alle Checks aus Phase 2 werden **nochmal ausgeführt**:
- Lint (Ruff)
- Format (Black, isort)
- Type Check (MyPy)
- Tests (beide Python Versionen)
- Coverage Upload

**Quality Gate:**
- Alle Checks müssen bestehen
- Verhindert, dass fehlerhafte Merges durchrutschen

---

### Job 2: Build Docker Image

**Steps:**
1. **Download Artifact** (falls vorhanden)
2. **Log in to GitHub Container Registry:**
   ```yaml
   uses: docker/login-action@v3
   with:
     registry: ghcr.io
     username: ${{ github.actor }}
     password: ${{ secrets.GITHUB_TOKEN }}
   ```

3. **Extract Metadata** für Production Tags:
   ```yaml
   tags: |
     type=ref,event=branch           # → main
     type=semver,pattern={{version}} # → v1.2.3
     type=semver,pattern={{major}}.{{minor}} # → 1.2
     type=sha,prefix={{branch}}-     # → main-abc1234
     type=raw,value=latest,enable={{is_default_branch}} # → latest
   ```

4. **Build & Push Multi-Platform Image:**
   ```yaml
   uses: docker/build-push-action@v5
   with:
     context: .
     file: ./Dockerfile  # Production Dockerfile
     push: true          # Push aktiviert!
     platforms: linux/amd64,linux/arm64
     tags: ${{ steps.meta.outputs.tags }}
     cache-from: type=gha
     cache-to: type=gha,mode=max
   ```

---

## Phase 5: Production Deployment (DHBW OpenStack)

### Problem: VPN-Beschränkung
**DHBW OpenStack ist nur via VPN erreichbar**
- GitHub Actions kann nicht direkt deployen
- Keine eingehenden Webhooks möglich
- Keine SSH-Verbindung von außen

### Deployment-Methode: Docker Compose mit Watchtower

**docker-compose.prod.yml:**
```yaml
services:
  backend:
    image: ghcr.io/six7-click-n-deploy/backend:latest
    # ... weitere Konfiguration
  
  frontend:
    image: ghcr.io/six7-click-n-deploy/frontend:latest
    # ... weitere Konfiguration
  
  worker:
    image: ghcr.io/six7-click-n-deploy/worker:latest
    # ... weitere Konfiguration
```

**Automatisiertes Pull-basiertes Deployment**

### Watchtower Konfiguration

```yaml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_POLL_INTERVAL=300  # 5 Minuten
      - WATCHTOWER_CLEANUP=true       # Alte Images löschen
      - WATCHTOWER_INCLUDE_STOPPED=false
      - WATCHTOWER_ROLLING_RESTART=true
    command: backend frontend worker
    restart: unless-stopped
```

**Funktionsweise:**
1. Watchtower prüft alle 5 Minuten die Registry
2. Vergleicht Image Digest/Hash mit lokalem Container
3. Bei neuem Image:
   - Pull neues Image
   - Stop Container
   - Start Container mit neuem Image
   - Health Check
4. Bei Fehler: Automatischer Rollback

---
