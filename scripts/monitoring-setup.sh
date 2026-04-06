#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# Complete Monitoring Setup Script
# Run this on your EC2 instance AFTER the app is deployed
# Usage: chmod +x monitoring-setup.sh && ./monitoring-setup.sh
# ─────────────────────────────────────────────────────────────────

set -e

echo "=============================="
echo " Step 1: Install Helm"
echo "=============================="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

echo "=============================="
echo " Step 2: Add Prometheus Helm repo"
echo "=============================="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "=============================="
echo " Step 3: Install kube-prometheus-stack"
echo " (Prometheus + Grafana + Alertmanager)"
echo "=============================="
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --wait

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=grafana \
  -n monitoring \
  --timeout=120s

echo "=============================="
echo " Step 4: Apply ServiceMonitor & Alert Rules"
echo "=============================="
kubectl apply -f k8s/monitoring/service-monitor.yaml
kubectl apply -f k8s/monitoring/alert-rules.yaml

echo "=============================="
echo " Step 5: Verify Setup"
echo "=============================="
echo "Pods in monitoring namespace:"
kubectl get pods -n monitoring

echo ""
echo "ServiceMonitor:"
kubectl get servicemonitor -n markdown-editor

echo ""
echo "PrometheusRules:"
kubectl get prometheusrule -n markdown-editor

echo ""
echo "=============================="
echo " Setup Complete!"
echo "=============================="
echo ""
echo "To access Grafana:"
echo "  kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo "  Open: http://localhost:3000"
echo "  Login: admin / admin123"
echo ""
echo "To access Prometheus UI:"
echo "  kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring"
echo "  Open: http://localhost:9090"
