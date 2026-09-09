# Deployment do Docker Mailserver no Kubernetes (Oracle Cloud - OCI)

Este repositório contém o deployment completo e pronto para produção do **Docker Mailserver** (`setup.mailserver.tech`) no Kubernetes da Oracle Cloud (OCI OKE), configurado para o domínio **`airqloud.com.br`** e o e-mail **`contato@airqloud.com.br`**.

---

## 📋 Arquitetura e Componentes

- **Namespace**: `mailserver`
- **Domínio Principal**: `airqloud.com.br`
- **FQDN do Servidor**: `mail.airqloud.com.br`
- **Armazenamento**: 3 PVCs utilizando o StorageClass `oci-bv` (Oracle Block Volume):
  - `mailserver-data-pvc` (`/var/mail`): Caixas de e-mail e mensagens.
  - `mailserver-state-pvc` (`/var/mail-state`): Chaves DKIM, bancos de dados e estado dos serviços.
  - `mailserver-config-pvc` (`/tmp/docker-mailserver`): Configurações dinâmicas de contas e aliases.
- **Rede**: OCI Network Load Balancer (NLB) Layer 4 preservando o IP dos clientes.
- **Recursos**: Otimizado com `ENABLE_CLAMAV=0` para economia de memória RAM.

---

## 🚀 Passo a Passo de Instalação

### 1. Configurar Credenciais e TLS

Antes de aplicar os manifestos, edite o arquivo [`secret.yaml`](secret.yaml):

1. Defina as credenciais do seu provedor de **SMTP Relay** (ver seção sobre bloqueio da porta 25 no OCI):
   ```yaml
   RELAY_USER: "seu-usuario-relay"
   RELAY_PASS: "sua-senha-ou-api-key"
   ```
2. Adicione os certificados SSL/TLS do seu domínio em `mailserver-tls` (ou utilize o `cert-manager`).

---

### 2. Aplicar os Manifestos no Cluster

Execute o comando a seguir na raiz do diretório `docker-mailserver`:

```bash
kubectl apply -k .
```

Verifique o status do deploy:

```bash
# Ver os pods em execução
kubectl get pods -n mailserver -w

# Verificar o armazenamento persistente (PVCs)
kubectl get pvc -n mailserver

# Obter o IP Público do Network Load Balancer provisionado pelo OCI
kubectl get svc -n mailserver mailserver-service
```

---

### 3. Criar o Primeiro Usuário de E-mail (`contato@airqloud.com.br`)

Com o Pod em status `Running`, utilize o utilitário `setup` para criar o e-mail:

```bash
# Criar a conta contato@airqloud.com.br
kubectl exec -it deployment/mailserver -n mailserver -- setup email add contato@airqloud.com.br "SuaSenhaSeguraAqui123!"

# Listar as contas criadas para confirmar
kubectl exec -it deployment/mailserver -n mailserver -- setup email list
```

---

### 4. Gerar as Chaves DKIM

Para garantir a entregabilidade dos e-mails e passar nos filtros antispam (Gmail, Outlook), gere as chaves DKIM:

```bash
# Gerar as chaves DKIM de 2048 bits
kubectl exec -it deployment/mailserver -n mailserver -- setup config dkim
```

Exibir o registro TXT do DKIM gerado para adicionar ao seu DNS:

```bash
kubectl exec -it deployment/mailserver -n mailserver -- cat /var/mail-state/lib-postfix/opendkim/keys/airqloud.com.br/mail.txt
```

---

## 🌐 Configuração de Registros DNS Obrigatórios

No seu provedor de DNS (ex: Cloudflare, GoDaddy, OCI DNS), configure os seguintes registros para o IP Público retornado pelo `kubectl get svc -n mailserver`:

| Tipo | Nome / Host | Valor / Destino | TTL | Observação |
|---|---|---|---|---|
| **A** | `mail` | `<IP_PUBLICO_DO_LOAD_BALANCER>` | Auto / 300 | Aponta `mail.airqloud.com.br` |
| **MX** | `@` | `mail.airqloud.com.br` (Prioridade 10) | Auto / 300 | Define o servidor de recebimento |
| **TXT** | `@` | `v=spf1 mx a include:relay.brevo.com ~all` | Auto / 300 | SPF (Ajuste o `include:` se usar SES/Brevo) |
| **TXT** | `mail._domainkey` | `v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AM...` | Auto / 300 | Cole a chave gerada pelo comando `setup config dkim` |
| **TXT** | `_dmarc` | `v=DMARC1; p=none; rua=mailto:contato@airqloud.com.br` | Auto / 300 | Política DMARC |

---

## ⚠️ Nota Importante: Bloqueio da Porta 25 de Saída na Oracle Cloud (OCI)

A Oracle Cloud bloqueia o tráfego de saída na porta TCP 25 em todas as instâncias por padrão para prevenção de spam.

### Como funciona o envio (Outbound Relay)?

1. O e-mail de entrada continua chegando normalmente na porta 25 (o OCI **não** bloqueia entrada).
2. Para **enviar** e-mails para domínios externos (Gmail, Outlook, etc.), o Docker Mailserver utiliza um **SMTP Relay de Saída** na porta 587/465 com TLS.

### Configurando o SMTP Relay (ex: Brevo ou Amazon SES)

1. Crie uma conta em um serviço de envio (ex: **Brevo** [plano gratuito de 300 e-mails/dia] ou **Amazon SES**).
2. No [`configmap.yaml`](configmap.yaml), defina:
   ```yaml
   DEFAULT_RELAY_HOST: "[smtp-relay.brevo.com]:587"
   RELAY_HOST: "[smtp-relay.brevo.com]"
   RELAY_PORT: "587"
   ```
3. No [`secret.yaml`](secret.yaml), insira suas credenciais:
   ```yaml
   RELAY_USER: "7a8b9c... (Sua chave ou e-mail no provedor)"
   RELAY_PASS: "xsmtpsib-... (Sua chave de API / senha SMTP)"
   ```
4. Aplique as mudanças:
   ```bash
   kubectl apply -k .
   ```

---

## 🔍 Testes de Conexão e Validação

### Testar porta IMAPS (993)
```bash
openssl s_client -connect mail.airqloud.com.br:993 -crlf
```

### Testar porta SMTP Submission com STARTTLS (587)
```bash
openssl s_client -starttls smtp -connect mail.airqloud.com.br:587 -crlf
```

---

## 🔧 Comandos Úteis de Manutenção (`setup`)

- **Trocar senha de usuário**:
  ```bash
  kubectl exec -it deployment/mailserver -n mailserver -- setup email change password contato@airqloud.com.br "NovaSenha123!"
  ```
- **Criar Alias (redirecionamento de e-mail)**:
  ```bash
  kubectl exec -it deployment/mailserver -n mailserver -- setup alias add suporte@airqloud.com.br contato@airqloud.com.br
  ```
- **Verificar logs do mailserver em tempo real**:
  ```bash
  kubectl logs -f deployment/mailserver -n mailserver
  ```
