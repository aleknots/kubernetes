# Lab Kong (Kind)

Lab local com **Kind**, **PostgreSQL 11**, **Kong Gateway Community 3.8.0**, **Kong Ingress Controller 3.2**, **Kong Manager OSS** (UI padrão) e site de demonstração em Nginx.

O fluxo de trabalho padrão utiliza a imagem OSS `kong:3.8.0`. Dentro do Kong Manager, o Gateway exibe `Edition: community`; este lab não utiliza imagens Enterprise em modo gratuito.

## Estrutura do Repositório

```text
.
├── cluster.yaml                 # Kind: 1 control-plane + 2 workers
├── namespaces.yaml              # lab-kong, lab-app
├── postgres/                    # PostgreSQL do Kong (núcleo)
├── kong/
│   ├── values.yaml              # Helm: Gateway Community + Manager OSS + KIC
│   └── rate-limit.yaml
├── manager-auth/                # Proxy Basic Auth em frente ao Kong Manager + Admin API
├── apps/                        # Site público de demonstração (Ingress → Kong)
└── scripts/
    ├── install-base.sh          # Provisiona a stack base
    ├── port-forward-site.sh     # Site público via Proxy na porta :8000
    ├── port-forward-manager.sh  # Manager autenticado na porta :8002
    └── cleanup.sh               # Remove o cluster Kind
```

## Arquitetura (Padrão)

```text
Navegador → localhost:8000
    → Kong Proxy → Ingress → apps (lab-app)

Navegador → localhost:8002/manager/
    → Nginx Basic Auth → Kong Manager OSS (Edição do Gateway: community)
    → /admin-api → Kong Admin API
    → PostgreSQL (banco de dados kong)
```

## Credenciais (Apenas para o Lab)

| Serviço | Usuário | Senha |
|---------|---------|-------|
| Postgres Kong | `kong` | `kong` |
| Basic Auth Kong Manager | `admin` | `admin123` |

## Pré-requisitos

- Docker, Kind, kubectl, Helm 3

## Instalação Rápida (Stack Padrão)

```bash
cd ~/kubernetes/kong+manager-oss   # raiz deste projeto

# Imagens
docker pull postgres:11-alpine
docker pull kong:3.8.0
docker pull kong/kubernetes-ingress-controller:3.2.1
docker pull nginx:alpine

bash scripts/install-base.sh
```

## Redirecionamento de Portas (Port-forwarding)

| Terminal | Comando | URL |
|----------|---------|-----|
| 1 | `bash scripts/port-forward-site.sh` | `http://localhost:8000/site` |
| 2 | `bash scripts/port-forward-manager.sh` | `http://localhost:8002/manager/` |

Verificação:

```bash
curl -i http://localhost:8000/site
curl -i http://localhost:8002/manager/
curl -i -u admin:admin123 http://localhost:8002/manager/
```

## Instalação Manual (Passo a Passo)

### 1. Cluster Kind

```bash
kind create cluster --config cluster.yaml
kind export kubeconfig --name lab
kubectl config use-context kind-lab
kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl label node lab-worker node-role.kubernetes.io/worker=worker --overwrite
kubectl label node lab-worker2 node-role.kubernetes.io/worker=worker --overwrite
```

### 2. Namespaces e Postgres

```bash
kubectl apply -f namespaces.yaml
kubectl apply -f postgres/secret.yaml
kubectl apply -f postgres/deployment.yaml
kubectl wait --for=condition=Ready pod -l app=postgres -n lab-kong --timeout=180s
kubectl exec -n lab-kong deploy/postgres -- pg_isready -U kong -d kong
```

### 3. Kong (Helm)

O [values](kong/values.yaml) configura `image.repository: kong`, `image.tag: 3.8.0`, `enterprise.enabled: false` e `manager.enabled: true`.

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

### 4. Plugins e Apps

```bash
kubectl apply -f kong/rate-limit.yaml
kubectl apply -f apps/public-site/
```

## Interface de Administração

| UI | Status | URL Local | Banco de Dados Dedicado |
|----|--------|-----------|---------------|
| **Kong Manager OSS** | padrão, Gateway `community`, Basic Auth | `http://localhost:8002/manager/` | Não (utiliza Admin API → `kong`) |

## Verificação

```bash
kubectl get nodes
kubectl get pods,svc -n lab-kong
kubectl get pods,ingress -n lab-app
kubectl get kongplugin,kongconsumer -n lab-app
```

Status esperado:

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

O PostgreSQL do lab roda no namespace `lab-kong`, utiliza o Serviço `postgres:5432`, imagem `postgres:11-alpine` e contém apenas o banco de dados `kong`.

| Banco de Dados | Proprietário / Uso |
|---|---|
| `kong` | Dados do Kong Gateway: rotas, serviços, plugins, consumidores |

### Conectando ao Postgres

```bash
kubectl config use-context kind-lab

# Shell interativo no pod do Postgres
kubectl exec -it -n lab-kong deploy/postgres -- sh

# Dentro do pod
psql -U kong -d kong
```

Atalho de linha única:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U kong -d kong
```

### Inspecionando o Banco de Dados `kong`

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

### Linhas Únicas com `kubectl exec`

```bash
kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY 1;"

kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "SELECT rolname, rolcanlogin FROM pg_roles ORDER BY 1;"

kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "\dt"
```

## Limpeza

```bash
bash scripts/cleanup.sh        # solicita confirmação
bash scripts/cleanup.sh --yes
```
