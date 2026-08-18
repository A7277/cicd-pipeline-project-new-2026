#!/bin/bash
# Run this on a DEDICATED EC2 instance for Nexus (t3.medium or larger recommended).
# Runs Nexus Repository OSS inside Docker.
# Usage: chmod +x install-nexus.sh && sudo ./install-nexus.sh

set -e

echo ">>> Installing Docker (if not already installed)..."
sudo apt update -y
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

echo ">>> Running Nexus container (this can take a few minutes to become ready)..."
sudo docker run -d --name nexus \
  -p 8081:8081 \
  --restart unless-stopped \
  -v nexus-data:/nexus-data \
  sonatype/nexus3

echo ">>> Nexus starting. Give it 2-3 minutes, then open:"
echo ">>> http://<EC2_PUBLIC_IP>:8081"
echo ">>> Default admin password (once container is up), run:"
echo "sudo docker exec nexus cat /nexus-data/admin.password"
