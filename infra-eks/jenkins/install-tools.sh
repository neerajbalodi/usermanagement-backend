#!/usr/bin/env bash
# ------------------------------------------------------------------
# Run ONCE on the Jenkins server (Ubuntu) for the Day 4 (EKS) pipelines:
#   bash install-tools.sh
# Adds: Docker, AWS CLI v2, kubectl, Helm   (Terraform is already there from Day 1)
# ------------------------------------------------------------------
set -euo pipefail

sudo apt-get update
sudo apt-get install -y curl unzip ca-certificates

# --- Docker (the app pipelines build images) ---
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker jenkins          # let the jenkins user run docker

# --- AWS CLI v2 ---
if ! aws --version 2>/dev/null | grep -q "aws-cli/2"; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install --update
fi

# --- kubectl (same minor version as the cluster: 1.35) ---
curl -fsSL "https://dl.k8s.io/release/v1.35.9/bin/linux/amd64/kubectl" -o /tmp/kubectl
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl

# --- Helm ---
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Jenkins must restart to pick up the new "docker" group
sudo systemctl restart jenkins

echo
docker --version
aws --version
kubectl version --client
helm version --short
terraform -version | head -n 1
echo
echo "Done. Next: add the extra AWS permissions (see README.md in this folder)."
