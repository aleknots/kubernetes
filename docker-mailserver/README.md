# Deployment do Docker Mailserver no Kubernetes (Oracle Cloud - OCI)

Este repositório contém o deployment completo e pronto para produção do **Docker Mailserver** (`setup.mailserver.tech`) no cluster Kubernetes da Oracle Cloud (OCI OKE), configurado para um domínio customizado (ex: **`seu-dominio.com.br`**) e endereço de e-mail (ex: **`contato@seu-dominio.com.br`**).

---

## 📋 Arquitetura e Componentes

- **Namespace**: `mailserver`
- **Domínio Principal**: `seu-dominio.com.br`
- **FQDN do Servidor**: `mail.seu-dominio.com.br`
- **Armazenamento**: Volume `hostPath` montado em `/var/lib/docker-mailserver` no nó do servidor, utilizando `subPath` para organizar:
  - `mail/` (`/var/mail`): Mensagens e caixas de entrada.
  - `state/` (`/var/mail-state`): Chaves DKIM, bancos de dados e estados do serviço.
  - `config/` (`/tmp/docker-mailserver`): Contas de e-mail e aliases configurados.
- **Segurança SSL/TLS**: Configurado com `SSL_TYPE: snakeoil` para boot automático instantâneo (com suporte a certificados customizados Let's Encrypt / Cert-Manager).
- **Rede**: Service `ClusterIP` com roteamento interno para o Cloudflare Tunnel / Bastion Host.
- **Recursos**: Otimizado com `ENABLE_CLAMAV=0` para baixo consumo de RAM (~300MB), ideal para a cota **OCI Free Tier**.

---

## ⚙️ Pipeline de CI/CD (GitHub Actions)

A implantação é totalmente automatizada via GitHub Actions pelo arquivo [`.github/workflows/deploy-docker-mailserver.yml`](../.github/workflows/deploy-docker-mailserver.yml).

Toda vez que arquivos na pasta `docker-mailserver/` forem alterados e enviados via `git push origin main`, a pipeline:
1. Conecta-se ao cluster OCI via túnel SSH no Bastion Host.
2. Injeta as credenciais de SMTP Relay (se configuradas nos Secrets do GitHub).
3. Aplica os manifestos via `kubectl apply -k docker-mailserver/` e valida a prontidão do Pod.

---

## 🚀 Passo a Passo de Pós-Instalação

### 1. Criar a Conta de E-mail (`contato@seu-dominio.com.br`)

Com o Pod em status `1/1 READY`, execute no terminal do seu servidor:

```bash
# Criar a conta contato@seu-dominio.com.br com a senha desejada
kubectl exec -it deployment/mailserver -n mailserver -- setup email add contato@seu-dominio.com.br "SuaSenhaSeguraAqui123!"

# Listar as contas criadas para confirmar
kubectl exec -it deployment/mailserver -n mailserver -- setup email list
```

---

### 2. Gerar as Chaves DKIM

Para garantir a entregabilidade dos e-mails e evitar a caixa de SPAM no Gmail e Outlook:

```bash
# Gerar as chaves DKIM de 2048 bits
kubectl exec -it deployment/mailserver -n mailserver -- setup config dkim

# Exibir a chave pública DKIM gerada para cadastrar no Cloudflare
kubectl exec -it deployment/mailserver -n mailserver -- cat /tmp/docker-mailserver/opendkim/keys/seu-dominio.com.br/mail.txt
```

---

## 🌐 Configuração de Registros DNS Obrigatórios (Cloudflare)

No painel do **Cloudflare** para o seu domínio (`seu-dominio.com.br`) -> **DNS**:

| Tipo | Nome / Host | Valor / Destino | Proxy Status / TTL | Observação |
|---|---|---|---|---|
| **MX** | `@` | `mail.seu-dominio.com.br` (Prioridade 10) | Auto | Recebimento via Cloudflare Email Routing |
| **TXT** | `mail._domainkey` | `v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOC...` | Auto | Cole a chave DKIM gerada no Passo 2 |
| **TXT** | `@` | `v=spf1 mx a include:relay.brevo.com ~all` | Auto | Validação SPF para envio via Brevo |
| **TXT** | `_dmarc` | `v=DMARC1; p=none; rua=mailto:contato@seu-dominio.com.br` | Auto | Política DMARC |

---

## ⚠️ Configuração do SMTP Relay de Saída (Brevo)

A Oracle Cloud bloqueia o tráfego de saída na porta TCP 25 em todas as instâncias por padrão. Os envios externos são repassados ao **Brevo** (plano gratuito com 300 e-mails/dia).

### Como configurar as credenciais no GitHub Secrets:

1. Crie uma conta gratuita em [brevo.com](https://www.brevo.com).
2. Em **SMTP & API Keys**, pegue seu login SMTP (ex: `seu-login@smtp-brevo.com`) e gere sua chave/senha de API.
3. No GitHub (*Settings > Secrets and variables > Actions*), adicione os 2 segredos:
   - `MAILSERVER_RELAY_USER`: Seu login SMTP do Brevo (ex: `seu-login@smtp-brevo.com`)
   - `MAILSERVER_RELAY_PASS`: Sua chave de API SMTP do Brevo
4. Na aba **Actions** do GitHub, execute novamente a pipeline (*Run workflow*) para atualizar as credenciais com segurança no cluster.

---

## 📩 Configuração no Gmail (Enviar e Receber como `contato@seu-dominio.com.br`)

Para enviar e receber e-mails da sua caixa customizada diretamente na interface web ou app do Gmail:

### 1. Configurar Recebimento (Cloudflare Email Routing)
- No painel do **Cloudflare** -> **Email Routing** -> **Routing rules**:
- Crie uma regra direcionando `contato@seu-dominio.com.br` para a sua conta principal do Gmail (ex: `seu-email@gmail.com`).

### 2. Configurar Envio no Gmail (via Brevo SMTP Relay)
1. No Gmail, acesse **Configurações** (engrenagem) -> **Ver todas as configurações** -> **Contas e Importação**.
2. Na seção **Enviar e-mail como**, clique em **Adicionar outro endereço de e-mail**.
3. Na primeira tela:
   - **Nome**: `Seu Nome / Sua Empresa`
   - **Endereço de e-mail**: `contato@seu-dominio.com.br`
   - Mantenha a opção **Tratar como um alias** marcada e clique em **Próxima etapa ».**
4. Na tela de Servidor SMTP:
   - **Servidor SMTP**: `smtp-relay.brevo.com`
   - **Porta**: `587`
   - **Nome de usuário**: `seu-login@smtp-brevo.com` *(Seu login SMTP do Brevo)*
   - **Senha**: *(Sua Chave API / Senha SMTP gerada no Brevo)*
   - **Conexão segura**: Selecione **Conexão segura usando TLS (recomendado)**
5. Clique em **Adicionar conta »**.
6. Digite o código de confirmação recebido por e-mail no seu Gmail para validar a associação.

---

## 🔧 Comandos Úteis de Manutenção (`setup`)

- **Trocar senha de usuário**:
  ```bash
  kubectl exec -it deployment/mailserver -n mailserver -- setup email change password contato@seu-dominio.com.br "NovaSenha123!"
  ```
- **Criar Alias (redirecionamento de e-mail)**:
  ```bash
  kubectl exec -it deployment/mailserver -n mailserver -- setup alias add suporte@seu-dominio.com.br contato@seu-dominio.com.br
  ```
- **Verificar logs do mailserver em tempo real**:
  ```bash
  kubectl logs -f deployment/mailserver -n mailserver
  ```
