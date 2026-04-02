# Markdown Editor — Full DevOps Setup

React + Node.js app with Docker, Kubernetes, Jenkins CI/CD, and Prometheus/Grafana monitoring.

---

## Architecture Overview

```
Developer pushes code to GitHub
        │
        ▼
  GitHub Webhook
        │
        ▼
  Jenkins Pipeline
  ┌─────────────────────────────────────┐
  │ 1. Checkout code                    │
  │ 2. Install dependencies             │
  │ 3. Lint + Build test                │
  │ 4. Build Docker images              │
  │ 5. Push to Docker Hub               │
  │ 6. kubectl set image (rolling update│
  │ 7. Wait for rollout                 │
  └─────────────────────────────────────┘
        │
        ▼
  Kubernetes Cluster
  ┌──────────────────────────────────────────┐
  │  Namespace: markdown-editor              │
  │                                          │
  │  [Ingress Controller]                    │
  │       │                                  │
  │  /api/* → backend-service:5000           │
  │  /*     → frontend-service:80            │
  │                                          │
  │  frontend-deployment (2 pods, HPA 2-6)   │
  │  backend-deployment  (2 pods, HPA 2-10)  │
  │                                          │
  │  ConfigMap (env vars)                    │
  │  Secret    (MONGO_URI, JWT_SECRET)       │
  └──────────────────────────────────────────┘
        │
        ▼
  Namespace: monitoring
  ┌──────────────────────────────────────────┐
  │  Prometheus (scrapes pod/node metrics)   │
  │  Grafana    (dashboards + alerts)        │
  └──────────────────────────────────────────┘
```

---

## Project Structure

```
MARKDOWN-EDITOR/
├── backend/                  # Node.js/Express API
├── frontend/                 # React/Vite app
├── docker/
│   ├── backend/Dockerfile    # Multi-stage backend image
│   └── frontend/
│       ├── Dockerfile        # Multi-stage frontend image
│       └── nginx.conf        # Nginx config with SPA routing
├── docker-compose.yml        # Local dev setup
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   └── monitoring/
│       ├── prometheus.yaml
│       └── grafana.yaml
├── Jenkinsfile               # CI/CD pipeline definition
└── scripts/
    └── ec2-setup.sh          # EC2 bootstrap script
```

---

## Quick Start — Local Development

```bash
# Build and run everything locally
docker-compose up --build

# Frontend: http://localhost:3000
# Backend:  http://localhost:5000
# MongoDB:  localhost:27017
```

---

## EC2 Setup

Launch an Ubuntu 22.04 EC2 instance (t3.medium or larger recommended).

Required security group inbound rules:
| Port  | Purpose              |
|-------|----------------------|
| 22    | SSH                  |
| 8080  | Jenkins UI           |
| 80    | HTTP                 |
| 443   | HTTPS                |
| 30000-32767 | K8s NodePort |
| 9090  | Prometheus           |
| 3000  | Grafana              |

```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>

# Upload and run the setup script
chmod +x scripts/ec2-setup.sh
sudo ./scripts/ec2-setup.sh
```

---

## Jenkins Setup

1. Open `http://<EC2_IP>:8080`
2. Enter the initial admin password (printed by setup script)
3. Install suggested plugins + "Pipeline" plugin
4. Go to Manage Jenkins → Credentials → Add:
   - Kind: Username with password
   - ID: `dockerhub-credentials`
   - Username/Password: your Docker Hub credentials
5. Create a new Pipeline job:
   - Source: GitHub repository URL
   - Script path: `Jenkinsfile`
6. Configure GitHub webhook:
   - GitHub repo → Settings → Webhooks
   - Payload URL: `http://<EC2_IP>:8080/github-webhook/`
   - Content type: `application/json`
   - Event: "Just the push event"

---

## Kubernetes Deployment

```bash
# Before deploying, encode your secrets
echo -n "your_mongo_uri" | base64
echo -n "your_jwt_secret" | base64
# Paste the output into k8s/secret.yaml

# Replace YOUR_DOCKERHUB_USERNAME in the deployment files, then:
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

# Check status
kubectl get all -n markdown-editor

# Watch rolling update
kubectl rollout status deployment/backend-deployment -n markdown-editor
```

---

## Monitoring

```bash
# Deploy Prometheus + Grafana
kubectl apply -f k8s/monitoring/prometheus.yaml
kubectl apply -f k8s/monitoring/grafana.yaml

# Get Minikube IP
minikube ip

# Prometheus: http://<minikube-ip>:30090
# Grafana:    http://<minikube-ip>:30030
#             Login: admin / admin123
```

### Grafana Dashboard Setup

1. Login to Grafana
2. Go to Dashboards → Import
3. Import dashboard ID `3119` (Kubernetes cluster monitoring)
4. Import dashboard ID `6417` (Kubernetes pods)
5. Select "Prometheus" as the data source

---

## CI/CD Flow Explained

1. You push code to GitHub
2. GitHub sends a webhook to Jenkins
3. Jenkins runs the Jenkinsfile pipeline:
   - Installs deps and lints code
   - Builds Docker images tagged with the Git commit SHA
   - Pushes images to Docker Hub
   - Runs `kubectl set image` which updates the deployment
4. Kubernetes performs a rolling update:
   - Starts new pods with the new image
   - Waits for them to pass readiness probes
   - Only then terminates old pods
   - Zero downtime throughout
5. If the rollout fails, Jenkins automatically runs `kubectl rollout undo`

---

## Useful Commands

```bash
# View logs
kubectl logs -f deployment/backend-deployment -n markdown-editor

# Scale manually
kubectl scale deployment backend-deployment --replicas=4 -n markdown-editor

# Rollback
kubectl rollout undo deployment/backend-deployment -n markdown-editor

# Check HPA status
kubectl get hpa -n markdown-editor

# Port-forward for local testing
kubectl port-forward svc/backend-service 5000:5000 -n markdown-editor
```

---

## Production Checklist

- [ ] Replace placeholder secrets in `k8s/secret.yaml` with real base64-encoded values
- [ ] Replace `YOUR_DOCKERHUB_USERNAME` in deployment files and Jenkinsfile
- [ ] Replace `yourdomain.com` in `k8s/ingress.yaml`
- [ ] Use a PersistentVolumeClaim for Prometheus and Grafana storage
- [ ] Set up cert-manager for automatic TLS certificates
- [ ] Change Grafana admin password from default
- [ ] Use AWS Secrets Manager or HashiCorp Vault instead of K8s Secrets for sensitive data
- [ ] Set up Grafana alerting rules for pod crashes and high CPU
