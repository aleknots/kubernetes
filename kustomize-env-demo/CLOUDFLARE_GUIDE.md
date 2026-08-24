# 🌐 Guia Passo a Passo: Expondo o Lab via Cloudflare Tunnel

Este guia explica como expor suas aplicações de **DEV**, **STG**, **PRD** e o **Argo CD** gratuitamente na web usando o **Cloudflare Tunnel (`cloudflared`)** e um domínio personalizado (ex: `empresa.cloud`), integrando a solução diretamente no seu cluster Kubernetes sem a necessidade de `kubectl port-forward` ou redirecionamento de portas no roteador.

---

## 🎯 Principais Vantagens
* **100% Gratuito**: Incluído no plano gratuito do Cloudflare.
* **HTTPS/SSL Automático**: Certificados emitidos e renovados automaticamente pelo Cloudflare.
* **Segurança (DevSecOps)**: Não expõe o IP residencial/público nem exige portas abertas de entrada. O token é salvo localmente em `.env` (ignorado pelo Git).
* **Zero Port-Forward**: O pod `cloudflared` roda diretamente dentro do cluster Kind e faz proxy das requisições para os serviços via DNS interno do K8s.

---

## 📋 Pré-requisitos
1. Um domínio registrado (ex: `empresa.cloud`) com DNS delegado para o **Cloudflare**.
2. Lab do Kubernetes em execução (via `create-lab.sh` ou `kind`).

---

## 🚀 Guia de Configuração

### Passo 1: Criar o Túnel no Cloudflare Zero Trust

1. Acesse o [Dashboard do Cloudflare](https://dash.cloudflare.com/).
2. No menu lateral, navegue até **Zero Trust** > **Networks** > **Tunnels**.
3. Clique em **Create a Tunnel** (selecione a opção `Cloudflared`).
4. Nomeie o túnel (ex: `kustomize-lab`) e clique em **Save tunnel**.
5. Na tela de instalação do agente, selecione **Docker**.
6. Copie o **Token** exibido no comando (a string longa após `--token`).

---

## Passo 2: Configurar o Token com Segurança (DevSecOps)

Para evitar a exposição de tokens em repositórios públicos:

1. Na raiz do `kustomize-env-demo`, crie um arquivo `.env`:
   ```bash
   cp kustomize-env-demo/.env.example kustomize-env-demo/.env
   ```

2. Edite o arquivo `.env` e adicione seu token:
   ```env
   CLOUDFLARE_TUNNEL_TOKEN=eyJh... (seu token completo aqui)
   ```

> 🔒 **Nota**: O arquivo `.env` e os guias locais estão adicionados ao `.gitignore` para garantir que tokens secretos não sejam commitados no Git.

---

### Passo 3: Mapear Rotas Públicas no Cloudflare

No dashboard do Túnel (**Public Hostnames**), adicione as 4 rotas públicas apontando para os serviços internos do Kubernetes:

| Subdomínio | Domínio | Caminho | Tipo | URL do Serviço Interno | Configurações Adicionais |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `dev` | `empresa.cloud` | *(vazio)* | `HTTP` | `app-banner.app-banner-dev:80` | Padrão |
| `stg` | `empresa.cloud` | *(vazio)* | `HTTP` | `app-banner.app-banner-stg:80` | Padrão |
| `prd` | `empresa.cloud` | *(vazio)* | `HTTP` | `app-banner.app-banner-prd:80` | Padrão |
| `argocd` | `empresa.cloud` | *(vazio)* | `HTTPS` | `argocd-server.argocd:443` | TLS > **No TLS Verify** = Habilitado |

*(Nota: Para o Argo CD, se preferir HTTP simples, configure `HTTP` ➔ `argocd-server.argocd:80`).*

---

### Passo 4: Implantar o Agente no Kubernetes

Você tem duas opções para implantar o agente no seu cluster:

#### Opção A: Script automatizado (Recomendado)
O `create-lab.sh` lê o arquivo `.env` e provisiona tudo automaticamente:
```bash
kustomize-env-demo/scripts/create-lab.sh
```

#### Opção B: Manual via kubectl
```bash
# 1. Criar Secret com o token
kubectl create secret generic cloudflared-token \
  -n kube-system \
  --from-literal=token="SEU_TOKEN_AQUI"

# 2. Aplicar o Deployment do cloudflared
kubectl apply -f kustomize-env-demo/cloudflare/cloudflared.yaml
```

---

## 🌐 URLs de Acesso

Após concluir a configuração, suas aplicações estarão acessíveis a partir de qualquer dispositivo:

* 🔵 **DEV**: `https://dev.empresa.cloud`
* 🟡 **STG**: `https://stg.empresa.cloud`
* 🟢 **PRD**: `https://prd.empresa.cloud`
* 🐙 **Argo CD**: `https://argocd.empresa.cloud`

---

## 🔍 Solução de Problemas

### 1. Erro: *"A DNS record with this name already exists"*
* **Causa**: Um registro DNS existente (A ou CNAME) com o mesmo nome já existe no dashboard de DNS do Cloudflare.
* **Solução**: Vá até **Cloudflare** > **empresa.cloud** > **DNS** > **Records**, localize o registro antigo com o mesmo nome e clique em **Delete**. Em seguida, salve novamente no Túnel.

### 2. Erro: *502 Bad Gateway no Argo CD*
* **Causa**: O Argo CD utiliza certificados SSL internos autoassinados.
* **Solução**: Edite o hostname do Argo CD no Túnel em **Additional Application Settings** > **TLS** e habilite **No TLS Verify**.
