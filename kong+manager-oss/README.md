# Kong Lab (Kind)

Local lab with **Kind**, **PostgreSQL 11**, **Kong Gateway Community 3.8.0**, **Kong Ingress Controller 3.2**, **Kong Manager OSS** (default UI), and Nginx demo site.

Standard workflow uses OSS image `kong:3.8.0`. Inside Kong Manager, Gateway displays `Edition: community`; this lab does not use Enterprise images in free mode.

## Repository Structure

```text
.
├── cluster.yaml                 # Kind: 1 control-plane + 2 workers
├── namespaces.yaml              # lab-kong, lab-app
├── postgres/                    # Kong PostgreSQL (core)
├── kong/
│   ├── values.yaml              # Helm: Gateway Community + Manager OSS + KIC
│   └── rate-limit.yaml
├── manager-auth/                # Basic Auth proxy in front of Kong Manager + Admin API
├── apps/                        # Demo public site (Ingress → Kong)
└── scripts/
    ├── install-base.sh          # Provisions base stack
    ├── port-forward-site.sh     # Public site via Proxy :8000
    ├── port-forward-manager.sh  # Authenticated Manager :8002
    └── cleanup.sh               # Removes Kind cluster
```

## Architecture (Standard)

```text
Browser → localhost:8000
    → Kong Proxy → Ingress → apps (lab-app)

Browser → localhost:8002/manager/
    → Nginx Basic Auth → Kong Manager OSS (Gateway edition: community)
    → /admin-api → Kong Admin API
    → PostgreSQL (kong database)
```

## Credentials (Lab Only)

| Service | Username | Password |
|---------|---------|-------|
| Postgres Kong | `kong` | `kong` |
| Basic Auth Kong Manager | `admin` | `admin123` |

## Prerequisites

- Docker, Kind, kubectl, Helm 3

## Quick Installation (Standard Stack)

```bash
cd ~/kubernetes/kong+manager-oss   # root of this project

# Images
docker pull postgres:11-alpine
docker pull kong:3.8.0
docker pull kong/kubernetes-ingress-controller:3.2.1
docker pull nginx:alpine

bash scripts/install-base.sh
```

## Port-forwarding

| Terminal | Command | URL |
|----------|---------|-----|
| 1 | `bash scripts/port-forward-site.sh` | `http://localhost:8000/site` |
| 2 | `bash scripts/port-forward-manager.sh` | `http://localhost:8002/manager/` |

Verification:

```bash
curl -i http://localhost:8000/site
curl -i http://localhost:8002/manager/
curl -i -u admin:admin123 http://localhost:8002/manager/
```

## Manual Installation (Step by Step)

### 1. Kind Cluster

```bash
kind create cluster --config cluster.yaml
kind export kubeconfig --name lab
kubectl config use-context kind-lab
kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl label node lab-worker node-role.kubernetes.io/worker=worker --overwrite
kubectl label node lab-worker2 node-role.kubernetes.io/worker=worker --overwrite
```

### 2. Namespaces and Postgres

```bash
kubectl apply -f namespaces.yaml
kubectl apply -f postgres/secret.yaml
kubectl apply -f postgres/deployment.yaml
kubectl wait --for=condition=Ready pod -l app=postgres -n lab-kong --timeout=180s
kubectl exec -n lab-kong deploy/postgres -- pg_isready -U kong -d kong
```

### 3. Kong (Helm)

The [values](kong/values.yaml) configures `image.repository: kong`, `image.tag: 3.8.0`, `enterprise.enabled: false`, and `manager.enabled: true`.

```bash
helm repo add kong https://charts.konghq.com
helm repo update

helm show crds kong/kong | kubectl apply -f -

helm upgrade --install kong kong/kong \
  --namespace lab-kong \
  --create-namespace \
  --values kong/values.yaml \
  --skip-crds \
  --wait \
  --timeout 8m

kubectl rollout status deployment/kong-kong -n lab-kong --timeout=600s
kubectl get svc -n lab-kong | grep -E 'proxy|admin|manager'

kubectl apply -f manager-auth/
kubectl rollout status deployment/kong-manager-auth -n lab-kong --timeout=120s
```

### 4. Plugins and Apps

```bash
kubectl apply -f kong/rate-limit.yaml
kubectl apply -f apps/public-site/
```

## Administrative UI

| UI | Status | Local URL | Dedicated Database |
|----|--------|-----------|---------------|
| **Kong Manager OSS** | default, Gateway `community`, Basic Auth | `http://localhost:8002/manager/` | No (uses Admin API → `kong`) |

## Verification

```bash
kubectl get nodes
kubectl get pods,svc -n lab-kong
kubectl get pods,ingress -n lab-app
kubectl get kongplugin,kongconsumer -n lab-app
```

Expected status:

```text
lab-control-plane   Ready
lab-worker          Ready
lab-worker2         Ready

kong-kong-xxxxx                 2/2   Running
kong-kong-yyyyy                 2/2   Running
kong-kong-init-migrations-xxx   0/1   Completed
postgres-xxxxx                  1/1   Running
kong-manager-auth-xxxxx         1/1   Running

public-site-xxxxx               1/1   Running
```

## PostgreSQL

Lab PostgreSQL runs in namespace `lab-kong`, uses Service `postgres:5432`, image `postgres:11-alpine`, and contains only `kong` database.

| Database | Owner / Usage |
|---|---|
| `kong` | Kong Gateway data: routes, services, plugins, consumers |

### Connecting to Postgres

```bash
kubectl config use-context kind-lab

# Interactive shell in Postgres pod
kubectl exec -it -n lab-kong deploy/postgres -- sh

# Inside pod
psql -U kong -d kong
```

One-line shortcut:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U kong -d kong
```

### Inspecting `kong` Database

```sql
SELECT id, name, host, path, protocol, "created_at"
FROM services;

SELECT id, name, protocols, paths, hosts, "created_at"
FROM routes;

SELECT id, name, enabled, "created_at"
FROM plugins;

SELECT id, username, custom_id, "created_at"
FROM consumers;
```

### One-liners with `kubectl exec`

```bash
kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY 1;"

kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "SELECT rolname, rolcanlogin FROM pg_roles ORDER BY 1;"

kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "\dt"
```

## Teardown

```bash
bash scripts/cleanup.sh        # prompts for confirmation
bash scripts/cleanup.sh --yes
```
