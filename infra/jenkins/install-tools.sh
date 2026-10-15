#!/usr/bin/env bash
# Run ONCE on the Jenkins server (Ubuntu 22.04 / 24.04):
#   bash install-tools.sh
# Installs what the pipeline needs: Terraform, Ansible, Git, curl.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y curl git unzip gnupg lsb-release software-properties-common

# --- Terraform (official HashiCorp repository) ---
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

# --- Ansible (official Ansible PPA) ---
sudo add-apt-repository -y ppa:ansible/ansible

sudo apt-get update
sudo apt-get install -y terraform ansible

echo
terraform -version
ansible --version | head -n 1
git --version
echo
echo "Done. Now attach an IAM role with AmazonEC2FullAccess to this EC2 instance."
