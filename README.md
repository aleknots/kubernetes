# Kubernetes

[![YAML Lint & Syntax Validation](https://github.com/aleknots/kubernetes/actions/workflows/yaml-lint.yml/badge.svg?branch=main)](https://github.com/aleknots/kubernetes/actions/workflows/yaml-lint.yml)
![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes&logoColor=white)
![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-EF6C00?logo=argo&logoColor=white)
![Kong](https://img.shields.io/badge/Kong-API%20Gateway-003366?logo=kong&logoColor=white)
![Licença](https://img.shields.io/badge/License-MIT-green.svg)

Labs práticos de Kubernetes, fluxos GitOps com Kustomize e Argo CD, configurações de API Gateway usando Kong e implantações de portal do desenvolvedor executando no Linux e em clusters **kind**.

## Projetos

| Pasta | Descrição |
|---|---|
| [kustomize-env-demo/](kustomize-env-demo/) | Aplicação HTML multi-ambiente (DEV azul, STG amarelo, PRD verde) com `base` + overlays do **Kustomize**, imagem de contêiner no **GHCR** e **Argo CD** no kind. Isolamento de ambiente: alterar `overlays/dev` não afeta STG/PRD. |
| [kong+konga/](kong+konga/) | Kong Gateway 3.4 legado + Kong Ingress Controller + PostgreSQL + **Konga** (interface) e dois sites Nginx (público e admin com Basic Auth). |
| [kong+manager-oss/](kong+manager-oss/) | Kong Gateway **Community 3.8** + KIC + **Kong Manager OSS** (interface nativa) e site de demonstração. Sem imagens Enterprise. |
| [backstage/](backstage/) | Portal do Desenvolvedor Backstage + PostgreSQL no namespace `backstage` (ConfigMap, Secrets, PV local, Serviço NodePort). |

Guias detalhados (inicialização, port-forward, destruição) estão disponíveis no `README.md` de cada pasta.

## kustomize-env-demo (Resumo)

- Overlays: `dev` / `stg` / `prd` → namespaces `app-banner-*` (`app-banner-dev`, `app-banner-stg`, `app-banner-prd`)
- Imagem: `aleknots/app-banner:v1` (ou personalizada via `--build-arg APP_VERSION`)
- GitOps: Aplicação Pai `app-banner-root` (App-of-Apps) sincroniza todos os 3 ambientes
- Cluster Kind: `kustomize-demo`
- Clone Rápido de Pasta Única: `npx -y giget gh:aleknots/kubernetes/kustomize-env-demo kustomize-env-demo`

Para build/push da imagem no GHCR e bootstrap do kind+Argo: veja [kustomize-env-demo/README.md](kustomize-env-demo/README.md).

## Requisitos Gerais

- Docker
- `kind`, `kubectl`, `helm` (Labs do Kong)
- CLI `gh` autenticada para pushes no GitHub/GHCR

Repositórios pessoais via SSH utilizam o alias de host `github-personal` (separado da chave de trabalho no `github.com`):

```bash
git remote set-url origin git@github-personal:aleknots/kubernetes.git
```

## Licença

Distribuído sob a [Licença MIT](LICENSE).
