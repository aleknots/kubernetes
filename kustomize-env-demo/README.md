# Demonstração de Ambientes com Kustomize

Uma aplicação web de demonstração (fundo colorido + badge de ambiente) implantada utilizando **Kustomize (base + overlays)** e **GitOps com Argo CD** em um cluster local do **kind**.

---

## 📋 Matriz de Ambientes

| Overlay | Namespace | Texto do Banner | Cor de Fundo | Imagem Docker |
| --- | --- | --- | --- | --- |
| `dev` | `app-banner-dev` | `DEVELOPMENT` | `#1e88e5` (Azul) | `aleknots/app-banner:v1` |
| `stg` | `app-banner-stg` | `STAGING` | `#fdd835` (Amarelo) | `aleknots/app-banner:v1` |
| `prd` | `app-banner-prd` | `PRODUCTION` | `#43a047` (Verde) | `aleknots/app-banner:v1` |

---

## 📥 Download Rápido (Clone de Pasta Única)

Se deseja clonar **apenas esta subpasta** diretamente sem baixar o repositório inteiro, utilize **`npx giget`** (sucessor moderno do `degit`):

```bash
npx -y giget gh:aleknots/kubernetes/kustomize-env-demo kustomize-env-demo
cd kustomize-env-demo
```

---

## 🛠️ Pré-requisitos

Para executar este lab na sua máquina local, você precisa ter instaladas as seguintes ferramentas:

- **Docker** (daemon rodando)
- **`kind`** (Kubernetes in Docker)
- **`kubectl`** (CLI do Kubernetes). *(Nota: O `kubectl` suporta nativamente o Kustomize via `kubectl apply -k` e `kubectl kustomize`; não é necessário instalar o Kustomize separadamente).*

---

## 🚀 Como Executar o Lab

Escolha uma das duas opções abaixo para provisionar o ambiente:

### Opção 1: Guia Manual Passo a Passo (Didático / Educacional)

Execute os comandos a partir da raiz do repositório (`kubernetes/`):

#### Passo 1 - Criar o Cluster `kind`
```bash
kind create cluster --name kustomize-demo
kind export kubeconfig --name kustomize-demo
kubectl config use-context kind-kustomize-demo
kubectl get nodes
```

#### Passo 2 - Instalar o Argo CD
```bash
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### Passo 3 - Criar AppProject `lab` no Argo CD
```bash
kubectl apply -f kustomize-env-demo/argocd/appproject-lab.yaml
```

#### Passo 4 - Ajustar Intervalo de Reconciliação do Git (Opcional - 60s)
```bash
kubectl -n argocd patch cm argocd-cm --type merge \
  -p '{"data":{"timeout.reconciliation":"60s"}}'
kubectl -n argocd rollout restart statefulset/argocd-application-controller
```

#### Passo 5 - Aguardar o Argo CD Ficar Pronto
```bash
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
```

#### Passo 6 - Obter Senha Inicial de Admin do Argo CD
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

#### Passo 7 - Aplicar Aplicações

Você pode registrar as aplicações utilizando três abordagens diferentes:

##### Método A - Kustomize direto via terminal:
```bash
# Aplica overlays DEV, STG e PRD no Kubernetes
kubectl apply -k kustomize-env-demo/overlays/dev
kubectl apply -k kustomize-env-demo/overlays/stg
kubectl apply -k kustomize-env-demo/overlays/prd
```

##### Método B - CLI via App-of-Apps:
```bash
kubectl apply -f kustomize-env-demo/argocd/app-root.yaml
```

##### Método C - UI do Console Web (Dashboard do Argo CD):
Se preferir criar a aplicação raiz visualmente via navegador (acesse `https://localhost:8088` após o port-forward):

1. Clique no botão **`+ NEW APP`** no canto superior esquerdo.
2. Preencha os campos do formulário:
   - **GENERAL**:
     - **Application Name**: `app-banner-root`
     - **Project Name**: `lab`
     - **Sync Policy**: `Automatic` *(habilite `PRUNE RESOURCES` e `SELF HEAL`)*
   - **SOURCE**:
     - **Repository URL**: `https://github.com/aleknots/Kubernetes.git`
     - **Revision**: `HEAD` (ou `main`)
     - **Path**: `kustomize-env-demo/argocd/applications`
   - **DESTINATION**:
     - **Cluster URL**: `https://kubernetes.default.svc` *(ou `in-cluster`)*
     - **Namespace**: `argocd`
   - **DIRECTORY**:
     - **Directory Recurse**: Marque `DIRECTORY RECURSE` (true)
3. Clique em **`CREATE`** no topo da tela. O Argo CD criará a aplicação pai `app-banner-root`, que instanciará todos os 3 cards de ambiente (`dev`, `stg`, `prd`) automaticamente.

#### 🌳 Por que usamos a Aplicação Raiz (`app-banner-root`)?

A `app-banner-root` implementa o padrão **App-of-Apps** no Argo CD. Em vez de gerenciar cada ambiente manualmente de forma individual, uma única aplicação "pai" sincroniza os manifestos contidos em `argocd/applications/`:

- **Ponto de Entrada Único (Bootstrap)**: Um único comando (`kubectl apply -f app-root.yaml`) permite que o Argo CD descubra e instancie todas as aplicações do cluster (`dev`, `stg`, `prd`).
- **Gerenciamento Declarativo via Git**: Adicionar, alterar ou remover um YAML de ambiente em `argocd/applications/` atualiza ou deleta automaticamente o card correspondente no cluster.
- **Self-Healing**: Se um operador excluir manualmente um card de ambiente (ex: `app-banner-dev`) pela UI do Argo CD, a aplicação raiz (`app-banner-root`) detecta a divergência e **recria o card automaticamente** em poucos segundos.

---

### Opção 2: Automação por Script (Rápida)

Para provisionar o lab completo automaticamente com um único comando:

```bash
kustomize-env-demo/scripts/create-lab.sh
```
*(O script cria o cluster `kind`, instala o Argo CD, aplica aplicações via App-of-Apps e exibe credenciais iniciais do `admin`).*

---

## 🌐 Acessando Aplicações & UI do Argo CD

### 1. Acessar Ambientes via Navegador (Port-Forward)

Abra port-forwards para cada ambiente (em terminais separados):

```bash
# Ambiente DEV
kubectl -n app-banner-dev port-forward svc/app-banner 8081:80
# Acessar no navegador: http://localhost:8081  (Banner Azul - DEVELOPMENT)

# Ambiente STG
kubectl -n app-banner-stg port-forward svc/app-banner 8082:80
# Acessar no navegador: http://localhost:8082  (Banner Amarelo - STAGING)

# Ambiente PRD
kubectl -n app-banner-prd port-forward svc/app-banner 8083:80
# Acessar no navegador: http://localhost:8083  (Banner Verde - PRODUCTION)
```

Verificação rápida no terminal:
```bash
curl -fsS http://localhost:8081 | grep DEVELOPMENT
curl -fsS http://localhost:8082 | grep STAGING
curl -fsS http://localhost:8083 | grep PRODUCTION
```

### 2. Acessar o Dashboard Web do Argo CD

```bash
kubectl -n argocd port-forward svc/argocd-server 8088:443
```
- **URL**: `https://localhost:8088`
- **Usuário**: `admin`
- **Senha**: Obtida no Passo 6 (ou exibida na saída do `create-lab.sh`).

### 3. Acessar via Cloudflare Tunnel (Opcional - Sem Port-Forward)

Para expor os ambientes (**DEV**, **STG**, **PRD**) e o **Argo CD** publicamente na web com HTTPS automático sem abrir portas locais:
- 🌐 **[Guia do Cloudflare Tunnel](CLOUDFLARE_GUIDE.md)** (`CLOUDFLARE_GUIDE.md`)

---

## 🧪 Testando Isolamento de Overlays

O Kustomize permite alterar configurações para um único ambiente sem impactar os demais:

1. Altere a cor ou o texto em `kustomize-env-demo/overlays/dev/kustomization.yaml`.
2. Aplique alterações no ambiente DEV:
   ```bash
   kubectl apply -k kustomize-env-demo/overlays/dev
   ```
3. Verifique se STG e PRD mantiveram suas configurações originais:
   ```bash
   kubectl kustomize kustomize-env-demo/overlays/stg | grep STAGING
   kubectl kustomize kustomize-env-demo/overlays/prd | grep PRODUCTION
   ```

---

## 💡 Gerando & Atualizando Tag da Imagem (Opcional - v2)

Para testar a atualização da versão da imagem no lab (gerando e enviando a tag `v2` para o Docker Hub):

1. **Gerar & Enviar Nova Imagem (`v2`)**:
   A flag `--build-arg APP_VERSION=v2` insere a tag **V2** diretamente no HTML da página:

   ```bash
   cd /caminho/para/kubernetes

   # 1) Build da imagem com a tag v2 (substitua 'seu-usuario' pela conta no Docker Hub)
   docker build --build-arg APP_VERSION=v2 -t seu-usuario/app-banner:v2 kustomize-env-demo/app

   # 2) Login & Push para o Docker Hub
   docker login -u seu-usuario
   docker push seu-usuario/app-banner:v2
   ```

2. **Atualizar Imagem no Kustomize**:
   Edite o overlay alvo (ex: `kustomize-env-demo/overlays/dev/kustomization.yaml`) adicionando ou modificando o patch de substituição de imagem:

   ```yaml
   patches:
     - target:
         kind: Deployment
         name: app-banner
       patch: |-
         - op: replace
           path: /spec/template/spec/containers/0/image
           value: seu-usuario/app-banner:v2
   ```

3. **Aplicar & Validar Atualização**:
   ```bash
   kubectl apply -k kustomize-env-demo/overlays/dev
   ```
   Acesse a aplicação no navegador (`http://localhost:8081`) e confirme a exibição do banner **V2**.

---

## 🧹 Limpeza do Lab

Ao finalizar os testes e quando desejar remover os recursos locais:

### Opção 1: Limpeza por Script
```bash
kustomize-env-demo/scripts/delete-lab.sh
```
*(O script solicitará confirmação antes de remover o cluster `kustomize-demo` e seus recursos).*

### Opção 2: Limpeza Manual

Para deletar o cluster `kind` e todos os recursos de uma vez:
```bash
kind delete cluster --name kustomize-demo
```

Para deletar as aplicações mantendo o cluster `kind` ativo:
```bash
kubectl delete -k kustomize-env-demo/overlays/dev --ignore-not-found
kubectl delete -k kustomize-env-demo/overlays/stg --ignore-not-found
kubectl delete -k kustomize-env-demo/overlays/prd --ignore-not-found
kubectl delete ns app-banner-dev app-banner-stg app-banner-prd --ignore-not-found
```

---

## 📁 Estrutura do Repositório

```text
kustomize-env-demo/
├── app/                 # Código fonte para aplicação de template HTML
├── base/                # Manifestos base (Deployment + Service comuns)
├── overlays/            # Patches específicos por ambiente
│   ├── dev/             # Patch do ambiente DEV (azul, DEVELOPMENT)
│   ├── stg/             # Patch do ambiente STG (amarelo, STAGING)
│   └── prd/             # Patch do ambiente PRD (verde, PRODUCTION)
├── argocd/              # Manifestos e configurações do Argo CD
│   ├── app-root.yaml    # Aplicação Raiz (App-of-Apps)
│   └── applications/    # Aplicações Filhas (dev, stg, prd)
├── cloudflare/          # Manifestos para exposição via Cloudflare Tunnel
│   └── cloudflared.yaml # Deployment do agente Cloudflared no cluster
├── scripts/             # Scripts utilitários
│   ├── create-lab.sh    # Cria cluster kind, instala Argo CD, Cloudflare e aplica apps
│   └── delete-lab.sh    # Remove recursos e deleta o cluster kind
├── .env.example         # Template de variáveis de ambiente (token Cloudflare)
└── CLOUDFLARE_GUIDE.md  # Guia completo para exposição via Cloudflare Tunnel
```
