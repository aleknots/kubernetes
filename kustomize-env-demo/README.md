# Kustomize Environment Demo

A demonstration web application (colored background + environment badge) deployed using **Kustomize (base + overlays)** and **GitOps with Argo CD** on a local **kind** cluster.

---

## 📋 Environment Matrix

| Overlay | Namespace | Banner Text | Background Color | Docker Image |
| --- | --- | --- | --- | --- |
| `dev` | `app-banner-dev` | `DEVELOPMENT` | `#1e88e5` (Blue) | `aleknots/app-banner:v1` |
| `stg` | `app-banner-stg` | `STAGING` | `#fdd835` (Yellow) | `aleknots/app-banner:v1` |
| `prd` | `app-banner-prd` | `PRODUCTION` | `#43a047` (Green) | `aleknots/app-banner:v1` |

---

## 📥 Quick Download (Single Folder Clone)

If you want to clone **only this subfolder** directly without downloading the entire repository, use **`npx giget`** (modern successor to `degit`):

```bash
npx -y giget gh:aleknots/kubernetes/kustomize-env-demo kustomize-env-demo
cd kustomize-env-demo
```

---

## 🛠️ Prerequisites

To run this lab on your local machine, you only need the following tools installed:

- **Docker** (daemon running)
- **`kind`** (Kubernetes in Docker)
- **`kubectl`** (Kubernetes CLI). *(Note: `kubectl` natively supports Kustomize via `kubectl apply -k` and `kubectl kustomize`; installing Kustomize separately is not required).*

---

## 🚀 How to Run the Lab

Choose one of the two options below to provision the environment:

### Option 1: Step-by-step Manual Guide (Didactic / Educational)

Execute the commands from the root of the repository (`kubernetes/`):

#### Step 1 - Create the `kind` Cluster
```bash
kind create cluster --name kustomize-demo
kind export kubeconfig --name kustomize-demo
kubectl config use-context kind-kustomize-demo
kubectl get nodes
```

#### Step 2 - Install Argo CD
```bash
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### Step 3 - Create `lab` AppProject in Argo CD
```bash
kubectl apply -f kustomize-env-demo/argocd/appproject-lab.yaml
```

#### Step 4 - Adjust Git Reconciliation Interval (Optional - 60s)
```bash
kubectl -n argocd patch cm argocd-cm --type merge \
  -p '{"data":{"timeout.reconciliation":"60s"}}'
kubectl -n argocd rollout restart statefulset/argocd-application-controller
```

#### Step 5 - Wait for Argo CD to be Ready
```bash
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
```

#### Step 6 - Retrieve Initial Argo CD Admin Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

#### Step 7 - Apply Applications

You can register the applications using three different approaches:

##### Method A - Direct Kustomize via terminal:
```bash
# Apply DEV, STG, and PRD overlays to Kubernetes
kubectl apply -k kustomize-env-demo/overlays/dev
kubectl apply -k kustomize-env-demo/overlays/stg
kubectl apply -k kustomize-env-demo/overlays/prd
```

##### Method B - CLI via App-of-Apps:
```bash
kubectl apply -f kustomize-env-demo/argocd/app-root.yaml
```

##### Method C - Web Console UI (Argo CD Dashboard):
If you prefer creating the root application visually via browser (access `https://localhost:8088` after port-forwarding):

1. Click **`+ NEW APP`** button on top left.
2. Fill out form fields:
   - **GENERAL**:
     - **Application Name**: `app-banner-root`
     - **Project Name**: `lab`
     - **Sync Policy**: `Automatic` *(enable `PRUNE RESOURCES` and `SELF HEAL`)*
   - **SOURCE**:
     - **Repository URL**: `https://github.com/aleknots/Kubernetes.git`
     - **Revision**: `HEAD` (or `main`)
     - **Path**: `kustomize-env-demo/argocd/applications`
   - **DESTINATION**:
     - **Cluster URL**: `https://kubernetes.default.svc` *(or `in-cluster`)*
     - **Namespace**: `argocd`
   - **DIRECTORY**:
     - **Directory Recurse**: Check `DIRECTORY RECURSE` (true)
3. Click **`CREATE`** on top of screen. Argo CD will create parent application `app-banner-root`, which instantiates all 3 environment cards (`dev`, `stg`, `prd`) automatically.

#### 🌳 Why do we use the Root Application (`app-banner-root`)?

`app-banner-root` implements the **App-of-Apps** pattern in Argo CD. Instead of manually managing each environment individually, a single "parent" Application syncs manifests from `argocd/applications/`:

- **Single Entrypoint (Bootstrap)**: One command (`kubectl apply -f app-root.yaml`) allows Argo CD to discover and instantiate all cluster applications (`dev`, `stg`, `prd`).
- **Declarative Git Management**: Adding, modifying, or removing an environment YAML in `argocd/applications/` automatically updates or deletes the corresponding card in the cluster.
- **Self-Healing**: If an operator manually deletes an environment card (e.g. `app-banner-dev`) via Argo CD UI, the root application (`app-banner-root`) detects drift and **recreates the card automatically** in seconds.

---

### Option 2: Scripted Automation (Fast)

To provision the complete lab automatically with a single command:

```bash
kustomize-env-demo/scripts/create-lab.sh
```
*(The script creates the `kind` cluster, installs Argo CD, applies applications via App-of-Apps, and displays initial `admin` credentials).*

---

## 🌐 Accessing Applications & Argo CD UI

### 1. Access Environments via Browser (Port-Forward)

Open port-forwards for each environment (in separate terminals):

```bash
# DEV Environment
kubectl -n app-banner-dev port-forward svc/app-banner 8081:80
# Access in browser: http://localhost:8081  (Blue Banner - DEVELOPMENT)

# STG Environment
kubectl -n app-banner-stg port-forward svc/app-banner 8082:80
# Access in browser: http://localhost:8082  (Yellow Banner - STAGING)

# PRD Environment
kubectl -n app-banner-prd port-forward svc/app-banner 8083:80
# Access in browser: http://localhost:8083  (Green Banner - PRODUCTION)
```

Quick terminal verification:
```bash
curl -fsS http://localhost:8081 | grep DEVELOPMENT
curl -fsS http://localhost:8082 | grep STAGING
curl -fsS http://localhost:8083 | grep PRODUCTION
```

### 2. Access Argo CD Web Dashboard

```bash
kubectl -n argocd port-forward svc/argocd-server 8088:443
```
- **URL**: `https://localhost:8088`
- **Username**: `admin`
- **Password**: Retrieved in Step 6 (or shown in `create-lab.sh` output).

### 3. Access via Cloudflare Tunnel (Optional - No Port-Forward)

To expose environments (**DEV**, **STG**, **PRD**) and **Argo CD** publicly on the web with automatic HTTPS without opening local ports:
- 🌐 **[Cloudflare Tunnel Guide](CLOUDFLARE_GUIDE.md)** (`CLOUDFLARE_GUIDE.md`)

---

## 🧪 Testing Overlay Isolation

Kustomize allows modifying configurations for a single environment without impacting others:

1. Modify color or text in `kustomize-env-demo/overlays/dev/kustomization.yaml`.
2. Apply changes to DEV environment:
   ```bash
   kubectl apply -k kustomize-env-demo/overlays/dev
   ```
3. Verify STG and PRD maintained original configurations:
   ```bash
   kubectl kustomize kustomize-env-demo/overlays/stg | grep STAGING
   kubectl kustomize kustomize-env-demo/overlays/prd | grep PRODUCTION
   ```

---

## 💡 Building Multi-Arch Images (`docker buildx`)

To build images compatible with **both x86_64/amd64 and ARM64 clusters** (e.g. OCI Ampere nodes + local kind/Docker Desktop):

1. **Build & Push Multi-Arch Image (e.g. `v1` or `v2`)**:
   Navigate to the application directory `kustomize-env-demo/app` (or run from repo root passing `kustomize-env-demo/app` as context):

   ```bash
   cd kustomize-env-demo/app
   ```

   - **Option 1: Use Existing Builder or Create if Missing**
     Flag `--build-arg APP_VERSION=v1` embeds the version label directly into the HTML page:

     ```bash
     # 1) Enable multi-arch builder
     docker buildx create --use --name multi-builder || docker buildx use multi-builder

     # 2) Build and push multi-architecture image (x86_64 + ARM64)
     docker buildx build \
       --platform linux/amd64,linux/arm64 \
       --build-arg APP_VERSION=v1 \
       -t your-user/app-banner:v1 \
       --push .
     ```

   - **Option 2: Recreate / Reset Builder (If `multi-builder` instance already exists or encounters errors)**
     If you encounter `ERROR: existing instance for "multi-builder"` or want to reset the builder:

     ```bash
     # 1) Remove existing builder instance
     docker buildx rm multi-builder

     # 2) Recreate and bootstrap multi-arch builder
     docker buildx create --name multi-builder --use --bootstrap

     # 3) Build and push multi-architecture image
     docker buildx build \
       --platform linux/amd64,linux/arm64 \
       --build-arg APP_VERSION=v1 \
       -t your-user/app-banner:v1 \
       --push .
     ```

   > 💡 **Tip (creating version `v2` in the future):**
   > When testing application updates in Kustomize / Argo CD (e.g. `v2`), update the `--build-arg` and image tag `-t`:
   > ```bash
   > docker buildx build \
   >   --platform linux/amd64,linux/arm64 \
   >   --build-arg APP_VERSION=v2 \
   >   -t your-user/app-banner:v2 \
   >   --push .
   > ```

   > **Note:** To run `docker buildx build ...` with `.` as context, ensure you are inside `kustomize-env-demo/app`. If executing from repository root (`kubernetes/`), pass `kustomize-env-demo/app` as context path instead of `.`.

2. **Update Image in Kustomize**:
   Edit target overlay (e.g. `kustomize-env-demo/overlays/dev/kustomization.yaml`) adding or modifying image replacement patch:

   ```yaml
   patches:
     - target:
         kind: Deployment
         name: app-banner
       patch: |-
         - op: replace
           path: /spec/template/spec/containers/0/image
           value: your-user/app-banner:v2
   ```

3. **Apply & Verify Update**:
   ```bash
   kubectl apply -k kustomize-env-demo/overlays/dev
   ```
   Access application in browser (`http://localhost:8081`) and verify version **V2** banner displayed.

---

## 🧹 Teardown Lab

When finished testing and ready to clean up local resources:

### Option 1: Scripted Teardown
```bash
kustomize-env-demo/scripts/delete-lab.sh
```
*(The script prompts for confirmation before removing cluster `kustomize-demo` and resources).*

### Option 2: Manual Teardown

To delete `kind` cluster and all resources at once:
```bash
kind delete cluster --name kustomize-demo
```

To delete applications while keeping `kind` cluster active:
```bash
kubectl delete -k kustomize-env-demo/overlays/dev --ignore-not-found
kubectl delete -k kustomize-env-demo/overlays/stg --ignore-not-found
kubectl delete -k kustomize-env-demo/overlays/prd --ignore-not-found
kubectl delete ns app-banner-dev app-banner-stg app-banner-prd --ignore-not-found
```

---

## 📁 Repository Structure

```text
kustomize-env-demo/
├── app/                 # Source code for HTML template application
├── base/                # Base manifests (common Deployment + Service)
├── overlays/            # Environment-specific patches
│   ├── dev/             # DEV environment patch (blue, DEVELOPMENT)
│   ├── stg/             # STG environment patch (yellow, STAGING)
│   └── prd/             # PRD environment patch (green, PRODUCTION)
├── argocd/              # Argo CD manifests and configuration
│   ├── app-root.yaml    # Root Application (App-of-Apps)
│   └── applications/    # Child Applications (dev, stg, prd)
├── cloudflare/          # Manifests for Cloudflare Tunnel exposure
│   └── cloudflared.yaml # Cloudflared agent Deployment in cluster
├── scripts/             # Utility scripts
│   ├── create-lab.sh    # Creates kind cluster, installs Argo CD, Cloudflare, and applies apps
│   └── delete-lab.sh    # Removes resources and deletes kind cluster
├── .env.example         # Environment variable template (Cloudflare token)
└── CLOUDFLARE_GUIDE.md  # Complete guide for Cloudflare Tunnel exposure
```
