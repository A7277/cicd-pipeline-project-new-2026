#!/bin/bash
# Run this on the SAME EC2 instance as Jenkins (or the build agent).
# Installs Docker + Maven and lets the Jenkins user run Docker commands.
# Usage: chmod +x install-docker-maven.sh && sudo ./install-docker-maven.sh

set -e

echo ">>> Installing Maven..."
sudo apt update -y
sudo apt install -y maven
mvn -version

echo ">>> Installing Docker..."
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo ">>> Allowing Jenkins user to run Docker without sudo..."
sudo usermod -aG docker jenkins
sudo usermod -aG docker ubuntu
sudo systemctl restart docker
sudo systemctl restart jenkins

echo ">>> Done. IMPORTANT: restart the Jenkins service/instance for group changes to take effect."
docker --version
