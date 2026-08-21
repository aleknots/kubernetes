# Backstage on Kubernetes

Kubernetes manifests to deploy a Backstage Developer Portal instance with PostgreSQL in the `backstage` namespace.

## Structure

```text
backstage/
|-- README.md
|-- namespace.yaml
|-- start.sh
|-- config/
|   `-- app-config.yaml
|-- secrets/
|   |-- backstage-secrets.yaml
|   `-- postgres-secrets.yaml
|-- postgres/
|   |-- deployment.yaml
|   |-- service.yaml
|   `-- storage.yaml
`-- backstage/
    |-- deployment.yaml
    `-- service.yaml
```

## Components

| Path | Description |
| --- | --- |
| `namespace.yaml` | Creates `backstage` namespace. |
| `config/app-config.yaml` | ConfigMap containing Backstage configuration. |
| `secrets/postgres-secrets.yaml` | Defines base64-encoded `POSTGRES_USER` and `POSTGRES_PASSWORD`. |
| `secrets/backstage-secrets.yaml` | Defines base64-encoded `GITHUB_TOKEN`. |
| `postgres/storage.yaml` | Creates local PV and PVC (`2G`) using `hostPath` at `/mnt/data`. |
| `postgres/deployment.yaml` | Deploys PostgreSQL `13.2-alpine`. |
| `postgres/service.yaml` | Creates internal Service `postgres` on port `5432`. |
| `backstage/deployment.yaml` | Deploys Backstage using image `iocanel/backstage:latest`. |
| `backstage/service.yaml` | Exposes Backstage via `NodePort` Service on port `30081`. |
| `start.sh` | Applies manifests in order and opens local port-forward. |

## Prerequisites

- Active Kubernetes cluster.
- `kubectl` configured pointing to target cluster.
- Permissions to create `Namespace`, `PersistentVolume`, `PersistentVolumeClaim`, `Deployment`, `Service`, `ConfigMap`, and `Secret`.
- Path `/mnt/data` available on node running PostgreSQL.

## Automated Setup via Script

Execute from this directory:

```bash
chmod +x start.sh
./start.sh
```

The script performs the following steps:

1. Creates namespace.
2. Applies secrets and ConfigMap.
3. Provisions storage, Deployment, and Service for PostgreSQL.
4. Provisions Deployment and Service for Backstage.
5. Waits for Backstage pod to become ready.
6. Opens port-forward for `http://localhost:8081`.

## Manual Setup

Execute from this directory:

```bash
kubectl apply -f namespace.yaml
```

Apply secrets and configurations:

```bash
kubectl apply -f secrets/postgres-secrets.yaml
kubectl apply -f secrets/backstage-secrets.yaml
kubectl apply -f config/app-config.yaml
```

Deploy PostgreSQL:

```bash
kubectl apply -f postgres/storage.yaml
kubectl apply -f postgres/deployment.yaml
kubectl apply -f postgres/service.yaml
```

Deploy Backstage:

```bash
kubectl apply -f backstage/deployment.yaml
kubectl apply -f backstage/service.yaml
```

Wait for Backstage to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=120s
```

Open local access:

```bash
kubectl port-forward svc/backstage 8081:8081 -n backstage
```

Access via browser:

```text
http://localhost:8081
```

Or via NodePort:

```text
http://localhost:30081
```

## Verification

List namespace resources:

```bash
kubectl get all -n backstage
```

Verify pods:

```bash
kubectl get pods -n backstage
```

View Backstage logs:

```bash
kubectl logs -n backstage deployment/backstage
```

View PostgreSQL logs:

```bash
kubectl logs -n backstage deployment/postgres
```

## Secrets

Base64 encoded secrets:

- `POSTGRES_USER`: `backstage`
- `POSTGRES_PASSWORD`: `hunter2`
- `GITHUB_TOKEN`: token used by Backstage application

To update a value, generate base64 encoding:

```bash
echo -n 'new-value' | base64
```

Edit target file and re-apply:

```bash
kubectl apply -f secrets/postgres-secrets.yaml
kubectl apply -f secrets/backstage-secrets.yaml
kubectl rollout restart deployment/backstage -n backstage
```

## Configuration

`config/app-config.yaml` defines:

- `app.baseUrl`: `http://localhost:8081`
- `backend.baseUrl`: `http://localhost:8081`
- `backend.listen.port`: `7007`
- `backend.cors.origin`: `http://localhost:8081`
- `organization.name`: `Spotify`

## Teardown

Delete namespace resources:

```bash
kubectl delete namespace backstage
```

Note: Since PersistentVolume uses `persistentVolumeReclaimPolicy: Retain`, data in `/mnt/data` may persist on node after namespace deletion.
