#!/bin/bash
# 1. Install Docker
apt-get update -y
apt-get install -y ca-certificates curl gnupg git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 2. Setup Workshop
mkdir -p /opt/workshop
cd /opt/workshop
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git .

# 3. Setup Environment
cp env.example .env

# 4. Start everything
docker compose up -d

# 5. Show Success message
echo "SETUP FINISHED! Access n8n on port 5678 and Evolution on 8081" > /etc/motd
