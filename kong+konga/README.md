# Lab Kong + Konga

Lab local do **Kind** para validação do Kong Gateway com PostgreSQL, Kong Ingress Controller, Konga e duas aplicações Nginx expostas via Kong Proxy.

## Componentes

| Componente | Versão | Objetivo |
|---|---|---|
| Kong Gateway | `3.4.2` | Runtime e proxy do Gateway |
| Kong Ingress Controller | `3.2.1` | Reconciliação de Ingress e CRDs do Kong |
| PostgreSQL | `11-alpine` | Bancos de dados `kong` e `konga` |
| Konga | `0.14.9` | Interface de administração conectada à Admin API do Kong |
| Nginx | `alpine` | Aplicações web de teste para demonstração |

## Fluxo de Arquitetura

```text
localhost:8000
  -> Kong Proxy
  -> Ingress
  -> Service
  -> apps/public-site ou apps/admin-site

localhost:1337
  -> Konga UI
  -> Kong Admin API
  -> PostgreSQL
```

## Aplicações & Autenticação

| Recurso | URL Local | Autenticação | Origem |
|---|---|---|---|
| Site Público | `http://localhost:8000/site` | Nenhuma | `apps/public-site` |
| Site Público | `http://localhost:8000/portal` | Nenhuma | `apps/public-site` |
| Site Público | `http://localhost:8000/home` | Nenhuma | `apps/public-site` |
| Site Público | `http://localhost:8000/app` | Nenhuma | `apps/public-site` |
| Site Admin | `http://localhost:8000/admin` | Plugin Kong Basic Auth | `apps/admin-site` |
| Konga UI | `http://localhost:1337` | Usuário criado no primeiro acesso | `konga/konga.yaml` |

O plugin de `rate-limit` é aplicado às rotas públicas. O plugin `admin-basic-auth` protege exclusivamente a rota `/admin`.

## Credenciais do Lab

| Componente | Usuário | Senha |
|---|---|---|
| Banco de dados PostgreSQL `kong` | `kong` | `kong` |
| Banco de dados PostgreSQL `konga` | `konga` | `konga` |
| Kong Basic Auth no `/admin` | `admin` | `admin123` |

## Pré-requisitos

- Docker
- Kind
- kubectl
- Helm

## Provisionamento do Lab

```bash
cd ~/kubernetes/kong+konga
bash scripts/install-base.sh
```

O script:

1. Cria ou reutiliza o cluster Kind `lab`
2. Baixa imagens fixas do lab
3. Aplica namespaces e o PostgreSQL
4. Instala as CRDs do Kong e o chart Helm
5. Aplica o Konga, plugins e aplicações Nginx

## Redirecionamento de Portas (Port-forwarding)

Execute em terminais separados:

```bash
bash scripts/port-forward.sh
bash scripts/port-forward-konga.sh
```

| Script | Porta Local | Destino |
|---|---|---|
| `scripts/port-forward.sh` | `8000` | Serviço `kong-kong-proxy` |
| `scripts/port-forward-konga.sh` | `1337` | Serviço `konga` |

## Verificação

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

O PostgreSQL do lab roda no namespace **`lab-kong`**, Serviço **`postgres:5432`**, imagem **PostgreSQL 11**. A autenticação interna no cluster está em modo **`trust`** (não exige senha dentro do pod `psql`); as credenciais acima se aplicam ao conectar externamente via port-forward.

| Banco de Dados | Proprietário / Uso |
| ------- | ----------------------------------------------------------- |
| `kong` | Dados do Kong Gateway (rotas, serviços, plugins, consumidores) |
| `konga` | Dados da interface Konga |

## Acessando o Shell do Postgres

```bash
kubectl config use-context kind-lab

# Shell interativo no pod do Postgres
kubectl exec -it -n lab-kong deploy/postgres -- sh

# Dentro do pod, conecte-se ao banco kong com o usuário kong
psql -U kong -d kong
```

Atalho de linha única sem abrir o shell do pod:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U kong -d kong
```

Conectar diretamente ao banco de dados do Konga:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U konga -d konga
```

Alternar entre bancos de dados dentro do `psql`:

```sql
\c konga    -- conecta ao banco de dados konga
\c kong     -- retorna ao banco de dados kong
```

Verificar conexão atual:

```sql
\conninfo
```

Sair do `psql`:

```sql
\q
```

Sair do pod:

```bash
exit
```

## Usuários do PostgreSQL vs Usuários da UI do Konga

O comando abaixo lista os **roles do PostgreSQL**:

```sql
\du
```

Saída esperada:

```text
Role name | Attributes
----------+------------------------------------------------------------
kong      | Superuser, Create role, Create DB, Replication, Bypass RLS
konga     |
```

Estes roles são utilizados pelos serviços de aplicação para conectar ao PostgreSQL:

```text
kong  -> utilizado pelo Kong Gateway
konga -> utilizado pela aplicação Konga
```

Um usuário criado dentro da interface Web do Konga (ex: `aleon`) não aparece no `\du` por ser um **usuário de aplicação**, salvo nas tabelas do banco de dados `konga`.

## Inspecionando Usuários da UI Web do Konga

Conecte-se ao banco de dados `konga`:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U konga -d konga
```

Listar tabelas:

```sql
\dt
```

A tabela de usuários da UI Web é:

```text
konga_users
```

Consultar todos os usuários da UI Web:

```sql
SELECT id, username, email, admin, active, "createdAt", "updatedAt"
FROM konga_users;
```

Consultar usuário específico:

```sql
SELECT id, username, email, admin, active, "createdAt", "updatedAt"
FROM konga_users
WHERE username = 'aleon';
```

## Meta-comandos Úteis do `psql`

```text
\?                -- ajuda sobre comandos do psql
\l                -- listar bancos de dados
\du               -- listar roles/usuários
\conninfo         -- exibir conexão atual
\dt               -- listar tabelas
\d+ services      -- descrever tabela
\x on             -- habilitar saída expandida
\x off            -- desabilitar saída expandida
\q                -- sair
```

## Diagnósticos SQL Úteis

```sql
-- Bancos de dados
SELECT datname
FROM pg_database
WHERE datistemplate = false
ORDER BY 1;

-- Tamanho dos bancos de dados
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datistemplate = false
ORDER BY datname;
```

## Consultas Úteis no Banco `kong`

Conecte-se ao banco de dados `kong`:

```sql
\c kong
```

Visualizar serviços criados no Kong:

```sql
SELECT id, name, host, path, protocol, "created_at"
FROM services;
```

Visualizar rotas criadas no Kong:

```sql
SELECT id, name, protocols, paths, hosts, "created_at"
FROM routes;
```

Visualizar plugins ativos:

```sql
SELECT id, name, enabled, "created_at"
FROM plugins;
```

Visualizar consumidores do Kong:

```sql
SELECT id, username, custom_id, "created_at"
FROM consumers;
```

## Linhas Únicas com `kubectl exec`

Listar bancos de dados:

```bash
kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY 1;"
```

Listar roles do PostgreSQL:

```bash
kubectl exec -n lab-kong deploy/postgres -- \
  psql -U kong -d kong -c "SELECT rolname, rolcanlogin FROM pg_roles ORDER BY 1;"
```

Conectar como usuário `kong`:

```bash
kubectl exec -it -n lab-kong deploy/postgres -- psql -U kong -d kong
```

## Conectando a partir do Host via `psql`

Requer cliente `psql` instalado na máquina host.

Redirecionar porta do Postgres:

```bash
kubectl port-forward -n lab-kong svc/postgres 5432:5432 --address 127.0.0.1
```

Conectar a partir do host:

```bash
psql -h 127.0.0.1 -p 5432 -U kong -d kong
```

## Comandos Rápidos de Diagnóstico

```bash
kubectl get pods,svc,endpoints -n lab-kong -l app=postgres
kubectl logs -n lab-kong deploy/postgres --tail=30
kubectl exec -n lab-kong deploy/postgres -- pg_isready -U kong -d kong
```

## Limpeza

```bash
bash scripts/cleanup.sh
bash scripts/cleanup.sh --yes
```
