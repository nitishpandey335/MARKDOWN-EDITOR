#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# EC2 One-Command Deploy Script
# Runs: Frontend + Backend + Prometheus + Grafana + Node Exporter
#
# Usage on EC2:
#   git clone https://github.com/nitishpandey335/MARKDOWN-EDITOR.git
#   cd MARKDOWN-EDITOR
#   chmod +x scripts/deploy-ec2.sh
#   ./scripts/deploy-ec2.sh
# ─────────────────────────────────────────────────────────────────

set -e

# Get EC2 public IP automatically
EC2_IP=$(curl -s http://checkip.amazonaws.com || curl -s http://ifconfig.me)
echo "EC2 Public IP: $EC2_IP"

# Create .env file for docker-compose
cat > .env << EOF
MONGO_URI=mongodb+srv://nitishkumarpandey05:dURQVZtECK6dUrSi@cluster0.6ksxmdl.mongodb.net/?appName=Cluster0
JWT_SECRET=mySuperSecretKey123@nitish
NODE_ENV=production
EC2_IP=${EC2_IP}
EOF

echo "Environment file created."

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    newgrp docker
fi

# Install Docker Compose plugin if not present
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo apt-get update -y
    sudo apt-get install -y docker-compose-plugin
fi

echo "=============================="
echo " Stopping old containers..."
echo "=============================="
docker compose -f docker-compose.prod.yml down 2>/dev/null || true

echo "=============================="
echo " Building and starting all services..."
echo "=============================="
docker compose -f docker-compose.prod.yml up -d --build

echo "Waiting for services to be healthy..."
sleep 15

echo "=============================="
echo " Service Status:"
echo "=============================="
docker compose -f docker-compose.prod.yml ps

echo ""
echo "=============================="
echo " All Services Started!"
echo "=============================="
echo ""
echo "  Frontend:   http://${EC2_IP}:80"
echo "  Backend:    http://${EC2_IP}:5000"
echo "  Prometheus: http://${EC2_IP}:9090"
echo "  Grafana:    http://${EC2_IP}:3000"
echo "              Login: admin / admin123"
echo ""
echo "  Health check: http://${EC2_IP}:5000/api/health"
echo "  Metrics:      http://${EC2_IP}:5000/metrics"
echo ""
