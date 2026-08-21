# Kong + Konga Lab

Local **Kind** lab for validating Kong Gateway with PostgreSQL, Kong Ingress Controller, Konga, and two Nginx applications exposed via Kong Proxy.

## Components

| Component | Version | Purpose |
|---|---|---|
| Kong Gateway | `3.4.2` | Gateway runtime & proxy |
| Kong Ingress Controller | `3.2.1` | Ingress reconciliation & Kong CRDs |
| PostgreSQL | `11-alpine` | `kong` and `konga` databases |
| Konga | `0.14.9` | Admin UI connected to Kong Admin API |
| Nginx | `alpine` | Demo test web applications |

## Architecture Flow

```text
localhost:8000
  -> Kong Proxy
  -> Ingress
  -> Service
  -> apps/public-site or apps/admin-site

localhost:1337
  -> Konga UI
  -> Kong Admin API
  -> PostgreSQL
```

## Applications & Authentication

| Resource | Local URL | Authentication | Source |
|---|---|---|---|
| Public site | `http://localhost:8000/site` | None | `apps/public-site` |
| Public site | `http://localhost:8000/portal` | None | `apps/public-site` |
| Public site | `http://localhost:8000/home` | None | `apps/public-site` |
| Public site | `http://localhost:8000/app` | None | `apps/public-site` |
| Admin site | `http://localhost:8000/admin` | Kong Basic Auth Plugin | `apps/admin-site` |
| Konga UI | `http://localhost:1337` | User created on first login | `konga/konga.yaml` |

The `rate-limit` plugin is applied to public routes. The `admin-basic-auth` plugin protects only `/admin`.

## Lab Credentials

| Component | Username | Password |
|---|---|---|
| PostgreSQL database `kong` | `kong` | `kong` |
| PostgreSQL database `konga` | `konga` | `konga` |
| Kong Basic Auth on `/admin` | `admin` | `admin123` |

## Prerequisites

- Docker
- Kind
- kubectl
- Helm

## Provisioning Lab

```bash
cd ~/kubernetes/kong+konga
bash scripts/install-base.sh
```

The script:

1. Creates or reuses Kind cluster `lab`
2. Pulls fixed lab images
3. Applies namespaces and PostgreSQL
4. Installs Kong CRDs and Helm chart
5. Applies Konga, plugins, and Nginx applications

## Port-forwarding

Execute in separate terminals:

```bash
bash scripts/port-forward.sh
bash scripts/port-forward-konga.sh
```

| Script | Local Port | Destination |
|---|---|---|
| `scripts/port-forward.sh` | `8000` | Service `kong-kong-proxy` |
| `scripts/port-forward-konga.sh` | `1337` | Service `konga` |

## Verification

```bash
kubectl get nodes
kubectl get pods,svc -n lab-kong
kubectl get pods,ingress -n lab-app
kubectl get kongplugin,kongconsumer -n lab-app

curl -i http://localhost:8000/site
curl -i http://localhost:8000/admin
curl -i -u admin:admin123 http://localhost:8000/admin
```

## PostgreSQL

Lab PostgreSQL runs in namespace **`lab-kong`**, Service **`postgres:5432`**, image **PostgreSQL 11**. Inside cluster auth is in **`trust`** mode (no password required inside pod `psql`); credentials above apply when connecting externally via port-forward.

| Database | Owner / Usage |
| ------- | ----------------------------------------------------------- |
| `kong` | Kong Gateway data (routes, services, plugins, consumers) |
| `konga` | Konga UI data |

## Accessing Postgres Shell

```bash
kubectl config use-context kind-lab

# Interactive shell in Postgres pod
kubectl exec -it -n lab-kong deploy/postgres -- sh

# Inside pod, connect to kong database with kong user
psql -U kong -d kong
```

One-line shortcut without opening pod shell:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U kong -d kong
```

Connect directly to Konga database:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U konga -d konga
```

Switch databases inside `psql`:

```sql
\c konga    -- connect to konga database
\c kong     -- return to kong database
```

Check current connection:

```sql
\conninfo
```

Exit `psql`:

```sql
\q
```

Exit pod:

```bash
exit
```

## PostgreSQL Users vs Konga UI Users

The command below lists **PostgreSQL roles**:

```sql
\du
```

Expected output:

```text
Role name | Attributes
----------+------------------------------------------------------------
kong      | Superuser, Create role, Create DB, Replication, Bypass RLS
konga     |
```

These roles are used by application services to connect to PostgreSQL:

```text
kong  -> used by Kong Gateway
konga -> used by Konga Application
```

A user created inside Konga Web UI (e.g. `aleon`) does not appear in `\du` because it is an **application user**, saved in `konga` database tables.

## Inspecting Konga Web UI Users

Connect to `konga` database:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U konga -d konga
```

List tables:

```sql
\dt
```

Web UI users table is:

```text
konga_users
```

Query all web UI users:

```sql
SELECT id, username, email, admin, active, "createdAt", "updatedAt"
FROM konga_users;
```

Query specific user:

```sql
SELECT id, username, email, admin, active, "createdAt", "updatedAt"
FROM konga_users
WHERE username = 'aleon';
```

## Helpful `psql` Meta-commands

```text
\?                -- help on psql commands
\l                -- list databases
\du               -- list roles/users
\conninfo         -- show current connection
\dt               -- list tables
\d+ services      -- describe table
\x on             -- enable expanded output
\x off            -- disable expanded output
\q                -- quit
```

## Useful SQL Diagnostics

```sql
-- Databases
SELECT datname
FROM pg_database
WHERE datistemplate = false
ORDER BY 1;

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datistemplate = false
ORDER BY datname;
```

## Useful Queries in `kong` Database

Connect to `kong` database:

```sql
\c kong
```

View services created in Kong:

```sql
SELECT id, name, host, path, protocol, "created_at"
FROM services;
```

View routes created in Kong:

```sql
SELECT id, name, protocols, paths, hosts, "created_at"
FROM routes;
```

View active plugins:

```sql
SELECT id, name, enabled, "created_at"
FROM plugins;
```

View Kong consumers:

```sql
SELECT id, username, custom_id, "created_at"
FROM consumers;
```

## One-liners with `kubectl exec`

List databases:

```bash
kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY 1;"
```

List PostgreSQL roles:

```bash
kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "SELECT rolname, rolcanlogin FROM pg_roles ORDER BY 1;"
```

Connect as `kong` user:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U kong -d kong
```

## Connecting from Host via `psql`

Requires `psql` client installed on host machine.

Forward Postgres port:

```bash
kubectl port-forward -n lab-kong svc/postgres 5432:5432 --address 127.0.0.1
```

Connect from host:

```bash
psql -h 127.0.0.1 -p 5432 -U kong -d kong
```

## Quick Diagnostic Commands

```bash
kubectl get pods,svc,endpoints -n lab-kong -l app=postgres
kubectl logs -n lab-kong deploy/postgres --tail=30
kubectl exec -n lab-kong deploy/postgres -- pg_isready -U kong -d kong
```

## Teardown

```bash
bash scripts/cleanup.sh
bash scripts/cleanup.sh --yes
```
