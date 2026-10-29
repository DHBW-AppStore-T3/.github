# App-Entwickler-Anleitung

Diese Anleitung richtet sich an App-Entwickler, die eine App für den AppStore bauen wollen. Alle Apps laufen im Kubernetes-Cluster der Plattform, entweder als **Pods** (`runtime: kubernetes`) oder als **KubeVirt-VM** (`runtime: kubevirt-vm`, z. B. ein Windows-Desktop). Beschrieben wird eine App in einer einzigen Datei, der `appstore.yaml`. Die Plattform erzeugt daraus alle Kubernetes-Objekte selbst.

> **Stand Oktober 2026:** Den früheren Ablauf mit Terraform, Packer und OpenStack-Credentials gibt es nicht mehr ([#12](https://github.com/DHBW-AppStore-T3/.github/issues/12)). Beispiele und der ausführliche Vertrag liegen im Repository [app-registry](https://github.com/DHBW-AppStore-T3/app-registry). Maßgeblich ist immer der Code: `backend/app/k8s/spec.py` (Schema und Grenzen) und `backend/app/k8s/render.py` (was daraus entsteht).

## 1. Was ist eine App?

Eine App ist ein **öffentliches Git-Repository** (GitHub) mit einer `appstore.yaml` im Wurzelverzeichnis. Die Plattform

1. liest die Datei genau an dem Commit, auf den der Release-Tag zeigt,
2. prüft sie gegen die Plattform-Grenzen (Abschnitt 5),
3. legt beim Deploy pro Team (oder pro Person) einen Pod bzw. eine VM in einem eigenen Namespace `dep-<8 hex>` an,
4. erzeugt Zugangsdaten und Links (Abschnitt 4.5) und zeigt sie im UI.

Es gibt **keinen** Build-Schritt im AppStore: Container-Images baust und veröffentlichst du selbst (Abschnitt 3). Es gibt auch keinen frei ausführbaren Code der App auf der Plattform, also kein Terraform, Packer oder Shell-Skript im Deploy.

Eine Version ohne gültige `appstore.yaml` lässt sich weder einreichen noch freigeben noch deployen (Fehler `appstore_yaml_missing` bzw. 422 mit Feldpfad).

---

## 2. Voraussetzungen für lokale Entwicklung

- **Git** und ein GitHub-Konto
- **Docker** (zum Bauen und Testen deines Images)
- Optional: der lokale AppStore-Stack in `k3d` (Anleitung: `deployment/docs/dev-setup.md`), um die App ohne Staging auszuprobieren

Du brauchst **keine** OpenStack-Zugangsdaten und keine `clouds.yaml`. Der AppStore kennt keine OpenStack-Credentials mehr.

---

## 3. Container-Image bereitstellen (nur `runtime: kubernetes`)

Images werden **nur per Digest** angegeben, nie per Tag (Tags sind veränderlich):

```
ghcr.io/dhbw-appstore-t3/apps/<name>@sha256:<64 hex>
```

- Erlaubt sind nur Registries aus der Allowlist `APP_IMAGE_REGISTRY_ALLOWLIST` (Standard: `ghcr.io/dhbw-appstore-t3/apps/`). Andere Quellen werden abgelehnt.
- Der Container läuft **ohne Root** (`runAsNonRoot`) und mit schreibgeschütztem Root-Dateisystem. Er muss auf einem Port ≥ 1024 lauschen. Verzeichnisse, in die er schreiben muss, gibst du in `writablePaths` an (Abschnitt 4.2).
- Den Digest erhältst du nach dem Push (`docker push` zeigt ihn an, oder `docker buildx imagetools inspect <image:tag>`).

---

## 4. Die `appstore.yaml`

### 4.1 Minimale Pod-App

```yaml
apiVersion: appstore/v2
name: meine-app            # Kleinbuchstaben, Ziffern, '-' (max. 31 Zeichen)
runtime: kubernetes
scope: team                # team (ein Pod je Team) oder user (ein Pod je Person)
workload:
  containers:
    - name: web
      image: ghcr.io/dhbw-appstore-t3/apps/meine-app@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
      expose:
        port: 8080         # 1024-65535
        path: /
      resources:
        cpu: "500m"
        memory: 512Mi
access:
  - type: url
    template: "https://{workload}-{deployment}.{zone}/"
```

Unbekannte Felder werden abgelehnt. Sicherheitsrelevantes (`securityContext`, Netzwerk-Policy, RBAC …) ist **nicht** Teil der Spec und lässt sich nicht setzen; das übernimmt die Plattform.

### 4.2 Felder im Überblick

| Feld | Bedeutung |
|---|---|
| `apiVersion` | immer `appstore/v2` |
| `name` | App-Name (`^[a-z][a-z0-9-]{0,30}$`) |
| `runtime` | `kubernetes` oder `kubevirt-vm` |
| `scope` | `team` (Standard) oder `user`; bei `user` erzwingt der Wizard ein eigenes Team pro Person |
| `workload.containers[]` | 1 bis 3 Container; genau **einer** hat `expose` |
| `containers[].image` | Digest-Image aus der Allowlist |
| `containers[].expose` | `port` und `path` des Ingress |
| `containers[].resources` | `cpu`/`memory` als Limits; optional `requests` (Standard: gleich den Limits) |
| `containers[].resourceBounds` | optional: Bereiche (`cpu.min/max`, `memory.min/max`), in denen die deployende Person CPU und Speicher wählen darf; `resources` ist dann der Standardwert |
| `containers[].env[]` | Umgebungsvariable mit **genau einem** von `value` oder `from` (`generated-password`, `team-name`, `user-name`) |
| `containers[].writablePaths[]` | absolute Pfade, die beschreibbar sein müssen (kurzlebiges Volume) |
| `workload.storage` | `size` (z. B. `5Gi`) und `mountPath` für ein dauerhaftes Volume; darf nicht in `writablePaths` stehen |
| `egress` | `none` (Standard) oder `internet`: ob die Pods ins Internet dürfen |
| `podNetwork` | `none` (Standard) oder `namespace`: ob die Pods eines Deployments einander erreichen |
| `userChoices` | opt-in: `internet` und/oder `podNetwork` darf die deployende Person im Wizard ändern |
| `variables[]` | Eingaben im Wizard (Abschnitt 4.4) |
| `access[]` | Wie Studierende auf die App zugreifen (Abschnitt 4.5) |

### 4.3 Beispiel: Webanwendung mit Speicher und Passwort

```yaml
apiVersion: appstore/v2
name: online-ide
runtime: kubernetes
scope: user
egress: none
userChoices:
  internet: true
workload:
  containers:
    - name: ide
      image: ghcr.io/dhbw-appstore-t3/apps/online-ide@sha256:<64 hex>
      expose: { port: 8443, path: / }
      resources:
        cpu: "2"
        memory: 4Gi
        requests: { cpu: 250m, memory: 512Mi }
      resourceBounds:
        cpu:    { min: 500m, max: "2" }
        memory: { min: 1Gi,  max: 4Gi }
      env:
        - name: PASSWORD
          from: generated-password
      writablePaths: [/tmp, /home/coder/.cache]
  storage:
    size: 5Gi
    mountPath: /home/coder/project
access:
  - type: url
    template: "https://{workload}-{deployment}.{zone}/"
  - type: password
    from: generated-password
    username: "{user}"
```

### 4.4 Variablen (`variables[]`)

Variablen erscheinen im Wizard und werden an die App weitergegeben.

| `type` | Pflichtangaben | Wirkung |
|---|---|---|
| `string` | optional `default` | freies Textfeld; ohne `default` Pflichtfeld |
| `enum` | `values[]`, optional `default` | Auswahlliste |
| `file` | `mountPath` (absolut), optional `ext[]`, `maxSize` (höchstens 1Mi) | Datei-Upload, die Datei erscheint unter `mountPath` im exponierten Container |

`scope: deployment` (Standard) gilt für alle, `scope: team` fragt je Team einen Wert ab. `mountPath`s müssen eindeutig sein: Zwei `file`-Variablen mit gleichem `mountPath` oder ein `mountPath`, der schon in `writablePaths` oder `storage` steht, werden abgelehnt.

Hochgeladene Dateien werden geprüft (Dateiendung, Inhalt von PDFs und Bildern, Virenscan, Größenlimit).

### 4.5 Zugang (`access[]`)

- `type: url`: ein Link, den Studierende im UI sehen. `template` **muss** mit `https://` beginnen. Platzhalter: `{workload}`, `{deployment}`, `{zone}`, `{domain}`.
- `type: password`: ein generiertes Passwort (`from: generated-password`). Optional `username` mit den Platzhaltern `{user}` und `{team}`.

Jede Person sieht über „Meine Zugänge“ nur **ihre eigene** Zeile. Die deployende Person (Operate-Recht) kann die Zugangsdaten einzelner Mitglieder auf Anfrage abrufen.

### 4.6 KubeVirt-VM (`runtime: kubevirt-vm`)

Für Desktop-Apps (z. B. Windows) startet die Plattform eine VM aus einem vorbereiteten Golden Image. Die VM wird im Browser über einen noVNC-Proxy bedient.

```yaml
apiVersion: appstore/v2
name: windows-matlab-vm
runtime: kubevirt-vm
scope: user
vm:
  cpuCores: 4            # 1-16
  memoryGiB: 8           # 2-32
  diskGiB: 80            # 40-200
  imageRef: windows11-matlab-golden   # PVC mit dem Golden Image
  imageNamespace: vm-poc              # nur Namespaces aus APP_VM_IMAGE_NAMESPACES
  storageClass: cinder
  bounds:                # optional: Bereiche zur Wahl im Wizard
    cpuCores:  { min: 2, max: 8 }
    memoryGiB: { min: 4, max: 16 }
access:
  - type: url
    template: "https://{workload}-novnc-{deployment}.apps.{zone}/"
```

Das Golden Image wird vom Plattform-Team im Cluster bereitgestellt (siehe `deployment/claude_docs/HANDOVER.md`, Abschnitt „KubeVirt-VM-Pfad“). Eine VM-App hat kein `workload`, und `vm` ist nur bei `kubevirt-vm` erlaubt. Zurzeit kann nur **eine** Windows-VM gleichzeitig laufen (Speicher-Quota).

---

## 5. Plattform-Grenzen

Die Grenzen gelten für jede Version und werden von Backend **und** Worker geprüft:

| Grenze | Standard |
|---|---|
| Container pro Workload | höchstens 3 |
| CPU pro Container | höchstens 2 |
| Speicher pro Container | höchstens 4Gi |
| Storage | höchstens 20Gi |
| Workloads pro Deployment | höchstens 60 |
| Image-Quelle | `ghcr.io/dhbw-appstore-t3/apps/…`, nur per Digest |
| VM-Image-Namespaces | `vm-poc` |

Die genauen Werte stehen in `backend/README.md` (Abschnitt Konfiguration). Fehler kommen als 422 mit einem Feldpfad, z. B. `workload.containers[0].image`.

---

## 6. Release, Registrierung und Freigabe

### 6.1 Release / Git-Tag erstellen

Die Plattform deployt ausschließlich versionierte Git-Tags, keinen Branch. Das Format ist:

```
v<Major>.<Minor>.<Patch>
```

Beispiel: `v1.0.0`, `v0.2.1`. Andere Formate sortieren nur lexikographisch und können im Wizard die falsche „neueste Version“ anzeigen. Zu jedem Release gehört eine umfassende Beschreibung (Abschnitt 6.3).

### 6.2 App registrieren und freigeben lassen

1. Repository auf GitHub veröffentlichen (**öffentlich**, die Plattform liest anonym). Erlaubte Git-Hosts stehen in `APP_GIT_ALLOWED_HOSTS` (Standard: `github.com`).
2. Im AppStore unter **„App hinzufügen“** die URL eintragen: `https://github.com/<user>/<repo>`.
3. Eine Version **einreichen**. Dabei fixiert die Plattform den Commit, den Spec-Hash und die Image-Digests.
4. Ein **Admin** prüft und gibt die Version frei (oder lehnt sie ab). Die Freigabe gilt für genau diesen Commit. Zeigt der Tag später auf einen anderen Commit, ist die Version nicht mehr deploybar (Fehler `version_moved`). Dann bitte einen neuen Tag erstellen.
5. Danach können Dozierende die App deployen.

### 6.3 Pflichtangaben in der App-Beschreibung

Bei der Registrierung und bei jedem neuen Release muss eine Beschreibung hinterlegt werden, die mindestens abdeckt:

- **Zugang:** Gibt es Zugangsdaten? Wie sind sie geregelt (ein Account pro Person, gemeinsame Zugangsdaten pro Team)?
- **Deployment-Umfang:** Wie viele Pods bzw. VMs entstehen (je Team, je Person, gemeinsam)?
- **Konfigurierbare Variablen:** Welche Variablen kann der Deployer setzen (Auswahl, Text, Datei-Upload)?
- **Änderungen im Release:** Was wurde geändert oder hinzugefügt?

---

## 7. Lokal ausprobieren

1. Image bauen, in die Registry pushen, Digest in die `appstore.yaml` eintragen.
2. Lokalen AppStore-Stack starten (`deployment/docs/dev-setup.md`, `make init`) und die App dort registrieren, einreichen, freigeben und deployen.
3. Für reine Spec-Prüfungen ohne Cluster genügt das Backend: Die Spec lässt sich mit `app.k8s.spec.parse_spec` laden, die Fehlermeldungen entsprechen denen im UI.

## 8. Aufräumen

Ein Deployment wird im UI gelöscht („Löschen“, bei Bedarf vorher „Pausieren“). Dabei entfernt die Plattform den Namespace `dep-<8 hex>` samt Volumes. Der Upload-Speicherplatz des Deployments wird dabei auf das Kontingent der Person zurückgebucht.
