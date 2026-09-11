# Deployment do Docker Mailserver no Kubernetes (Oracle Cloud - OCI)

Este repositório contém o deployment completo e pronto para produção do **Docker Mailserver** (`setup.mailserver.tech`) no cluster Kubernetes da Oracle Cloud (OCI OKE), configurado para o domínio **`aleon.cloud.com.br`** e a caixa de e-mail **`contato@aleon.cloud.com.br`**.

---

## 📋 Arquitetura e Componentes

- **Namespace**: `mailserver`
- **Domínio Principal**: `aleon.cloud.com.br`
- **FQDN do Servidor**: `mail.aleon.cloud.com.br`
- **Armazenamento**: Volume `hostPath` montado em `/var/lib/docker-mailserver` no nó do servidor, utilizando `subPath` para organizar:
  - `mail/` (`/var/mail`): Mensagens e caixas de entrada.
  - `state/` (`/var/mail-state`): Chaves DKIM, bancos de dados e estados do serviço.
  - `config/` (`/tmp/docker-mailserver`): Contas de e-mail e aliases configurados.
- **Segurança SSL/TLS**: Configurado com `SSL_TYPE: snakeoil` para boot automático instantâneo (com suporte a certificados customizados Let's Encrypt / Cert-Manager).
- **Rede**: OCI Network Load Balancer (NLB Layer 4 TCP) preservando o IP de origem dos clientes.
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

### 1. Criar a Conta de E-mail (`contato@aleon.cloud.com.br`)

Com o Pod em status `1/1 READY`, execute no terminal do seu servidor:

```bash
# Criar a conta contato@aleon.cloud.com.br com a senha desejada
kubectl exec -it deployment/mailserver -n mailserver -- setup email add contato@aleon.cloud.com.br "SuaSenhaSeguraAqui123!"

# Listar as contas criadas para confirmar
kubectl exec -it deployment/mailserver -n mailserver -- setup email list
```

---

### 2. Gerar as Chaves DKIM

Para garantir a entregabilidade dos e-mails e evitar a caixa de SPAM no Gmail e Outlook:

```bash
# Gerar as chaves DKIM de 2048 bits
kubectl exec -it deployment/mailserver -n mailserver -- setup config dkim

# Exibir a chave pública DKIM para cadastrar no Cloudflare
kubectl exec -it deployment/mailserver -n mailserver -- cat /var/mail-state/lib-postfix/opendkim/keys/aleon.cloud.com.br/mail.txt
```

---

### 3. Obter o IP Público do Servidor OCI (`srv-k8s-01`)

Como o deployment utiliza `hostNetwork: true` para expor as portas nativas (25, 465, 587, 993) diretamente na VM:
- O IP público que você deve cadastrar no Cloudflare é o **IP Público da sua instância OCI** (`srv-k8s-01`).

---

## 🌐 Configuração de Registros DNS Obrigatórios (Cloudflare)

No painel do **Cloudflare** para o domínio `aleon.cloud.com.br` -> **DNS**:

| Tipo | Nome / Host | Valor / Destino | Proxy Status / TTL | Observação |
|---|---|---|---|---|
| **A** | `mail` | `<EXTERNAL-IP>` | ⚠️ **DNS Only** (Nuvem Cinza) | Aponta `mail.aleon.cloud.com.br` |
| **MX** | `@` | `mail.aleon.cloud.com.br` (Prioridade 10) | Auto | Recebimento de e-mails |
| **TXT** | `mail._domainkey` | `v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOC...` | Auto | Cole a chave DKIM gerada |
| **TXT** | `@` | `v=spf1 mx a include:relay.brevo.com ~all` | Auto | Validação SPF para o Brevo |
| **TXT** | `_dmarc` | `v=DMARC1; p=none; rua=mailto:contato@aleon.cloud.com.br` | Auto | Política DMARC |

---

## ⚠️ Configuração do SMTP Relay de Saída (Brevo)

A Oracle Cloud bloqueia o tráfego de saída na porta TCP 25 em todas as instâncias por padrão. O recebimento funciona normalmente na porta 25, mas os envios externos são repassados ao **Brevo** (plano gratuito com 300 e-mails/dia).

### Como configurar as credenciais no GitHub Secrets:

1. Crie uma conta gratuita em [brevo.com](https://www.brevo.com).
2. Em **SMTP & API Keys**, pegue seu login SMTP (ex: `b8ed55001@smtp-brevo.com`) e gere sua chave/senha de API.
3. No GitHub (*Settings > Secrets and variables > Actions*), adicione os 2 segredos:
   - `MAILSERVER_RELAY_USER`: Seu login SMTP do Brevo
   - `MAILSERVER_RELAY_PASS`: Sua chave de API SMTP do Brevo
4. Na aba **Actions** do GitHub, execute novamente a pipeline (*Run workflow*) para atualizar as credenciais com segurança no cluster.

---

## 🔍 Testes de Conexão e Validação

### Testar porta IMAPS (993)
```bash
openssl s_client -connect mail.aleon.cloud.com.br:993 -crlf
```

### Testar porta SMTP Submission com STARTTLS (587)
```bash
openssl s_client -starttls smtp -connect mail.aleon.cloud.com.br:587 -crlf
```

---

## 🔧 Comandos Úteis de Manutenção (`setup`)

- **Trocar senha de usuário**:
  ```bash
  kubectl exec -it deployment/mailserver -n mailserver -- setup email change password contato@aleon.cloud.com.br "NovaSenha123!"
  ```
- **Criar Alias (redirecionamento de e-mail)**:
  ```bash
  kubectl exec -it deployment/mailserver -n mailserver -- setup alias add suporte@aleon.cloud.com.br contato@aleon.cloud.com.br
  ```
- **Verificar logs do mailserver em tempo real**:
  ```bash
  kubectl logs -f deployment/mailserver -n mailserver
  ```
