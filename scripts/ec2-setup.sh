#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# EC2 Ubuntu Setup Script
# Run this on a fresh Ubuntu 22.04 EC2 instance
# Usage: chmod +x ec2-setup.sh && sudo ./ec2-setup.sh
# ─────────────────────────────────────────────────────────────────

set -e  # exit immediately if any command fails

echo "=============================="
echo " Step 1: Update system packages"
echo "=============================="
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget git unzip apt-transport-https ca-certificates gnupg lsb-release

# ─────────────────────────────────────────────
# Install Docker
# ─────────────────────────────────────────────
echo "=============================="
echo " Step 2: Install Docker"
echo "=============================="

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group (so you don't need sudo for docker commands)
usermod -aG docker ubuntu

echo "Docker installed: $(docker --version)"

# ─────────────────────────────────────────────
# Install kubectl
# ─────────────────────────────────────────────
echo "=============================="
echo " Step 3: Install kubectl"
echo "=============================="

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
  | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubectl

echo "kubectl installed: $(kubectl version --client)"

# ─────────────────────────────────────────────
# Install Minikube (single-node K8s for dev/testing)
# For production, use kubeadm or AWS EKS instead
# ─────────────────────────────────────────────
echo "=============================="
echo " Step 4: Install Minikube"
echo "=============================="

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo "Minikube installed: $(minikube version)"

# Start Minikube using Docker driver (no VM needed)
# Run as ubuntu user (not root)
sudo -u ubuntu minikube start --driver=docker --cpus=2 --memory=4096

# Enable the ingress addon
sudo -u ubuntu minikube addons enable ingress
sudo -u ubuntu minikube addons enable metrics-server

echo "Minikube status:"
sudo -u ubuntu minikube status

# ─────────────────────────────────────────────
# Install Jenkins
# ─────────────────────────────────────────────
echo "=============================="
echo " Step 5: Install Jenkins"
echo "=============================="

# Jenkins requires Java
apt-get install -y openjdk-17-jdk

# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

# Add jenkins user to docker group so Jenkins can run docker commands
usermod -aG docker jenkins

# Restart Jenkins to pick up group change
systemctl restart jenkins

echo "Jenkins installed and running on port 8080"
echo "Initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword

# ─────────────────────────────────────────────
# Configure firewall (UFW)
# ─────────────────────────────────────────────
echo "=============================="
echo " Step 6: Configure Firewall"
echo "=============================="

ufw allow OpenSSH          # SSH access
ufw allow 8080/tcp         # Jenkins UI
ufw allow 80/tcp           # HTTP
ufw allow 443/tcp          # HTTPS
ufw allow 30000:32767/tcp  # Kubernetes NodePort range
ufw allow 9090/tcp         # Prometheus
ufw allow 3000/tcp         # Grafana
ufw --force enable

echo "Firewall configured."

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "=============================="
echo " Setup Complete!"
echo "=============================="
echo "Jenkins UI:    http://$(curl -s ifconfig.me):8080"
echo "Minikube IP:   $(sudo -u ubuntu minikube ip)"
echo ""
echo "NEXT STEPS:"
echo "1. Open Jenkins at the URL above"
echo "2. Use the initial admin password printed above"
echo "3. Install suggested plugins + Pipeline plugin"
echo "4. Add Docker Hub credentials (ID: dockerhub-credentials)"
echo "5. Create a Pipeline job pointing to your GitHub repo"
echo "6. Configure GitHub webhook to trigger Jenkins on push"
