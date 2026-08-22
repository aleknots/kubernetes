# Kubernetes

[![YAML Lint & Syntax Validation](https://github.com/aleknots/kubernetes/actions/workflows/yaml-lint.yml/badge.svg?branch=main)](https://github.com/aleknots/kubernetes/actions/workflows/yaml-lint.yml)
![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes&logoColor=white)
![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-EF6C00?logo=argo&logoColor=white)
![Kong](https://img.shields.io/badge/Kong-API%20Gateway-003366?logo=kong&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

Hands-on Kubernetes labs, GitOps workflows with Kustomize and Argo CD, API Gateway configurations using Kong, and developer portal deployments running on Linux and **kind** clusters.

## Projects

| Folder | Description |
|---|---|
| [sre-portfolio/](sre-portfolio/) | 🚀 **Main Portal (`aleon.cloud`)**: Ultra-modern glassmorphic SRE & Cloud Engineering Hub built with HTML5/CSS3 and deployed on Kubernetes with Nginx. |
| [kustomize-env-demo/](kustomize-env-demo/) | Multi-environment HTML App (DEV blue, STG yellow, PRD green) with **Kustomize** `base` + overlays, container image on **GHCR/Docker Hub**, and **Argo CD** on kind. Environment isolation: modifying `overlays/dev` does not affect STG/PRD. |
| [kong+konga/](kong+konga/) | Legacy Kong Gateway 3.4 + Kong Ingress Controller + PostgreSQL + **Konga** (UI) and two Nginx sites (public and admin with Basic Auth). |
| [kong+manager-oss/](kong+manager-oss/) | Kong Gateway **Community 3.8** + KIC + **Kong Manager OSS** (native UI) and demo site. No Enterprise images. |
| [backstage/](backstage/) | Backstage Developer Portal + PostgreSQL in `backstage` namespace (ConfigMap, Secrets, local PV, NodePort Service). |

Detailed runbooks (spin up, port-forward, teardown) are provided in each folder's `README.md`.

## kustomize-env-demo (Summary)

- Overlays: `dev` / `stg` / `prd` → namespaces `app-banner-*` (`app-banner-dev`, `app-banner-stg`, `app-banner-prd`)
- Image: `aleknots/app-banner:v1` (or customized via `--build-arg APP_VERSION`)
- GitOps: Parent Application `app-banner-root` (App-of-Apps) syncs all 3 environments
- Kind Cluster: `kustomize-demo`
- Quick Single-Folder Clone: `npx -y giget gh:aleknots/kubernetes/kustomize-env-demo kustomize-env-demo`

For image build/push to GHCR and kind+Argo bootstrap: see [kustomize-env-demo/README.md](kustomize-env-demo/README.md).

## General Requirements

- Docker
- `kind`, `kubectl`, `helm` (Kong labs)
- `gh` CLI authenticated for GitHub/GHCR pushes

Personal repositories via SSH use the host alias `github-personal` (separate from work key on `github.com`):

```bash
git remote set-url origin git@github-personal:aleknots/kubernetes.git
```

## License

Distributed under the [MIT License](LICENSE).
