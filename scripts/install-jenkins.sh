#!/bin/bash
# Run this on a fresh Ubuntu 22.04 EC2 instance to install Jenkins.
# Usage: chmod +x install-jenkins.sh && sudo ./install-jenkins.sh

set -e

echo ">>> Updating packages..."
sudo apt update -y

echo ">>> Installing Java 11 (required by Jenkins)..."
sudo apt install -y openjdk-11-jdk
java -version

echo ">>> Adding Jenkins repository key and source..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  "https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

echo ">>> Installing Jenkins..."
sudo apt update -y
sudo apt install -y jenkins

echo ">>> Starting Jenkins..."
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins --no-pager

echo ">>> Jenkins installed. Open http://<EC2_PUBLIC_IP>:8080 in your browser."
echo ">>> Initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
