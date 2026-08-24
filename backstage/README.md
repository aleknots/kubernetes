# Backstage no Kubernetes

Manifestos do Kubernetes para implantar uma instância do Portal do Desenvolvedor Backstage com PostgreSQL no namespace `backstage`.

## Estrutura

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

## Componentes

| Caminho | Descrição |
| --- | --- |
| `namespace.yaml` | Cria o namespace `backstage`. |
| `config/app-config.yaml` | ConfigMap contendo as configurações do Backstage. |
| `secrets/postgres-secrets.yaml` | Define `POSTGRES_USER` e `POSTGRES_PASSWORD` codificados em base64. |
| `secrets/backstage-secrets.yaml` | Define `GITHUB_TOKEN` codificado em base64. |
| `postgres/storage.yaml` | Cria PV e PVC locais (`2G`) usando `hostPath` em `/mnt/data`. |
| `postgres/deployment.yaml` | Implanta o PostgreSQL `13.2-alpine`. |
| `postgres/service.yaml` | Cria o Serviço interno `postgres` na porta `5432`. |
| `backstage/deployment.yaml` | Implanta o Backstage usando a imagem `iocanel/backstage:latest`. |
| `backstage/service.yaml` | Expõe o Backstage via Serviço `NodePort` na porta `30081`. |
| `start.sh` | Aplica os manifestos em ordem e abre o port-forward local. |

## Pré-requisitos

- Cluster Kubernetes ativo.
- `kubectl` configurado apontando para o cluster alvo.
- Permissões para criar `Namespace`, `PersistentVolume`, `PersistentVolumeClaim`, `Deployment`, `Service`, `ConfigMap` e `Secret`.
- Caminho `/mnt/data` disponível no nó que executará o PostgreSQL.

## Configuração Automatizada via Script

Execute a partir deste diretório:

```bash
chmod +x start.sh
./start.sh
```

O script realiza as seguintes etapas:

1. Cria o namespace.
2. Aplica secrets e o ConfigMap.
3. Provisiona armazenamento, Deployment e Serviço para o PostgreSQL.
4. Provisiona Deployment e Serviço para o Backstage.
5. Aguarda o pod do Backstage ficar pronto.
6. Abre o port-forward para `http://localhost:8081`.

## Configuração Manual

Execute a partir deste diretório:

```bash
kubectl apply -f namespace.yaml
```

Aplicar segredos e configurações:

```bash
kubectl apply -f secrets/postgres-secrets.yaml
kubectl apply -f secrets/backstage-secrets.yaml
kubectl apply -f config/app-config.yaml
```

Implantar o PostgreSQL:

```bash
kubectl apply -f postgres/storage.yaml
kubectl apply -f postgres/deployment.yaml
kubectl apply -f postgres/service.yaml
```

Implantar o Backstage:

```bash
kubectl apply -f backstage/deployment.yaml
kubectl apply -f backstage/service.yaml
```

Aguardar o Backstage ficar pronto:

```bash
kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=120s
```

Abrir acesso local:

```bash
kubectl port-forward svc/backstage 8081:8081 -n backstage
```

Acessar via navegador:

```text
http://localhost:8081
```

Ou via NodePort:

```text
http://localhost:30081
```

## Verificação

Listar recursos do namespace:

```bash
kubectl get all -n backstage
```

Verificar pods:

```bash
kubectl get pods -n backstage
```

Visualizar logs do Backstage:

```bash
kubectl logs -n backstage deployment/backstage
```

Visualizar logs do PostgreSQL:

```bash
kubectl logs -n backstage deployment/postgres
```

## Segredos (Secrets)

Segredos codificados em base64:

- `POSTGRES_USER`: `backstage`
- `POSTGRES_PASSWORD`: `hunter2`
- `GITHUB_TOKEN`: token utilizado pela aplicação Backstage

Para atualizar um valor, gere a codificação em base64:

```bash
echo -n 'novo-valor' | base64
```

Edite o arquivo alvo e aplique novamente:

```bash
kubectl apply -f secrets/postgres-secrets.yaml
kubectl apply -f secrets/backstage-secrets.yaml
kubectl rollout restart deployment/backstage -n backstage
```

## Configuração

O `config/app-config.yaml` define:

- `app.baseUrl`: `http://localhost:8081`
- `backend.baseUrl`: `http://localhost:8081`
- `backend.listen.port`: `7007`
- `backend.cors.origin`: `http://localhost:8081`
- `organization.name`: `Spotify`

## Limpeza

Deletar recursos do namespace:

```bash
kubectl delete namespace backstage
```

Nota: Como o PersistentVolume utiliza `persistentVolumeReclaimPolicy: Retain`, os dados em `/mnt/data` podem permanecer no nó após a exclusão do namespace.
