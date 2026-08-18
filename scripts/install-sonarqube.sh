#!/bin/bash
# Run this on a DEDICATED EC2 instance for SonarQube (t3.medium or larger — it needs 2GB+ RAM).
# Runs SonarQube inside Docker, which is the simplest reliable setup.
# Usage: chmod +x install-sonarqube.sh && sudo ./install-sonarqube.sh

set -e

echo ">>> Installing Docker (if not already installed)..."
sudo apt update -y
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

echo ">>> Required kernel setting for Elasticsearch (used internally by SonarQube)..."
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

echo ">>> Running SonarQube container..."
sudo docker run -d --name sonarqube \
  -p 9000:9000 \
  --restart unless-stopped \
  sonarqube:lts-community

echo ">>> SonarQube starting. Give it 1-2 minutes, then open:"
echo ">>> http://<EC2_PUBLIC_IP>:9000  (default login: admin / admin)"
