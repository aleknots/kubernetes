# 🌐 Step-by-Step Guide: Exposing the Lab via Cloudflare Tunnel

This guide explains how to expose your **DEV**, **STG**, **PRD**, and **Argo CD** applications for free on the web using **Cloudflare Tunnel (`cloudflared`)** and a custom domain (e.g. `company.cloud`), integrating the solution directly into your Kubernetes cluster without requiring `kubectl port-forward` or port forwarding on your router.

---

## 🎯 Key Advantages
* **100% Free**: Included in Cloudflare Free plan.
* **Automatic HTTPS/SSL**: Certificates issued and renewed automatically by Cloudflare.
* **Security (DevSecOps)**: Does not expose residential/public IP or require inbound open ports. Token is saved locally in `.env` (ignored by Git).
* **Zero Port-Forward**: The `cloudflared` pod runs directly inside the Kind cluster and proxies requests to services via internal K8s DNS.

---

## 📋 Prerequisites
1. A registered domain (e.g. `company.cloud`) with DNS delegated to **Cloudflare**.
2. Kubernetes lab running (via `create-lab.sh` or `kind`).

---

## 🚀 Configuration Guide

### Step 1: Create Tunnel in Cloudflare Zero Trust

1. Access [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. On sidebar menu, navigate to **Zero Trust** > **Networks** > **Tunnels**.
3. Click **Create a Tunnel** (select `Cloudflared` option).
4. Name the tunnel (e.g. `kustomize-lab`) and click **Save tunnel**.
5. On agent installation screen, select **Docker**.
6. Copy the **Token** displayed in the command (long string following `--token`).

---

### Step 2: Securely Configure Token (DevSecOps)

To avoid exposing tokens in public repositories:

1. At the root of `kustomize-env-demo`, create a `.env` file:
   ```bash
   cp kustomize-env-demo/.env.example kustomize-env-demo/.env
   ```

2. Edit `.env` file and add your token:
   ```env
   CLOUDFLARE_TUNNEL_TOKEN=eyJh... (your complete token here)
   ```

> 🔒 **Note**: The `.env` file and local guide are added to `.gitignore` to ensure secret tokens are not committed to Git.

---

### Step 3: Map Public Routes in Cloudflare

In the Tunnel dashboard (**Public Hostnames**), add the 4 public routes pointing to internal Kubernetes services:

| Subdomain | Domain | Path | Type | Internal Service URL | Additional Settings |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `dev` | `company.cloud` | *(empty)* | `HTTP` | `app-banner.app-banner-dev:80` | Default |
| `stg` | `company.cloud` | *(empty)* | `HTTP` | `app-banner.app-banner-stg:80` | Default |
| `prd` | `company.cloud` | *(empty)* | `HTTP` | `app-banner.app-banner-prd:80` | Default |
| `argocd` | `company.cloud` | *(empty)* | `HTTPS` | `argocd-server.argocd:443` | TLS > **No TLS Verify** = Enabled |

*(Note: For Argo CD, if you prefer plain HTTP, configure `HTTP` ➔ `argocd-server.argocd:80`).*

---

### Step 4: Deploy Agent to Kubernetes

You have two options to deploy the agent to your cluster:

#### Option A: Automated script (Recommended)
`create-lab.sh` reads `.env` and provisions everything automatically:
```bash
kustomize-env-demo/scripts/create-lab.sh
```

#### Option B: Manual via kubectl
```bash
# 1. Create Secret with token
kubectl create secret generic cloudflared-token \
  -n kube-system \
  --from-literal=token="YOUR_TOKEN_HERE"

# 2. Apply cloudflared Deployment
kubectl apply -f kustomize-env-demo/cloudflare/cloudflared.yaml
```

---

## 🌐 Access URLs

After completing setup, your applications will be accessible from any device:

* 🔵 **DEV**: `https://dev.company.cloud`
* 🟡 **STG**: `https://stg.company.cloud`
* 🟢 **PRD**: `https://prd.company.cloud`
* 🐙 **Argo CD**: `https://argocd.company.cloud`

---

## 🔍 Troubleshooting

### 1. Error: *"A DNS record with this name already exists"*
* **Cause**: An existing DNS record (A or CNAME) with the same name exists in Cloudflare DNS dashboard.
* **Solution**: Go to **Cloudflare** > **company.cloud** > **DNS** > **Records**, locate older record with same name and click **Delete**. Then save again in Tunnel.

### 2. Error: *502 Bad Gateway on Argo CD*
* **Cause**: Argo CD uses self-signed internal SSL certificates.
* **Solution**: Edit Argo CD hostname in Tunnel under **Additional Application Settings** > **TLS** and enable **No TLS Verify**.
