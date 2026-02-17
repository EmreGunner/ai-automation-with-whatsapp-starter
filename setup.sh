#!/bin/bash
# ==============================================================================
# AI & WhatsApp Automation Starter Kit — Server Bootstrap Script
# Repository: https://github.com/EmreGunner/ai-automation-with-whatsapp-starter
# Designed for: Ubuntu 24.04 LTS on DigitalOcean (4GB RAM minimum)
# ==============================================================================

set -euo pipefail

LOG_FILE="/var/log/workshop-setup.log"
REPO_URL="https://github.com/EmreGunner/ai-automation-with-whatsapp-starter.git"
INSTALL_DIR="/opt/workshop"

# ── Logging helper ─────────────────────────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "============================================================"
log "  AI & WhatsApp Automation Starter Kit — Bootstrap Starting"
log "============================================================"

# ── 1. System update ──────────────────────────────────────────────────────────
log "Step 1/7: Updating system packages..."
apt-get update -qq >> "$LOG_FILE" 2>&1
apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1
apt-get install -y -qq \
  curl \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common >> "$LOG_FILE" 2>&1
log "System packages updated."

# ── 2. Install Docker Engine ──────────────────────────────────────────────────
log "Step 2/7: Installing Docker Engine..."

# Remove any old Docker installations
apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc >> "$LOG_FILE" 2>&1
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list >> "$LOG_FILE"

apt-get update -qq >> "$LOG_FILE" 2>&1
apt-get install -y -qq \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin >> "$LOG_FILE" 2>&1

# Ensure Docker daemon is running
systemctl enable docker >> "$LOG_FILE" 2>&1
systemctl start docker >> "$LOG_FILE" 2>&1

DOCKER_VERSION=$(docker --version)
COMPOSE_VERSION=$(docker compose version)
log "Docker installed: $DOCKER_VERSION"
log "Docker Compose installed: $COMPOSE_VERSION"

# ── 3. Clone the repository ───────────────────────────────────────────────────
log "Step 3/7: Cloning repository to $INSTALL_DIR..."

if [ -d "$INSTALL_DIR" ]; then
  log "Directory $INSTALL_DIR already exists — pulling latest changes..."
  cd "$INSTALL_DIR"
  git pull >> "$LOG_FILE" 2>&1
else
  git clone "$REPO_URL" "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
  cd "$INSTALL_DIR"
fi
log "Repository ready at $INSTALL_DIR"

# ── 4. Configure environment ──────────────────────────────────────────────────
log "Step 4/7: Configuring environment variables..."

if [ ! -f "$INSTALL_DIR/.env" ]; then
  cp "$INSTALL_DIR/env.example" "$INSTALL_DIR/.env"
  log ".env file created from env.example"
else
  log ".env file already exists — skipping copy to preserve any edits"
fi

# ── 5. Set directory permissions ──────────────────────────────────────────────
log "Step 5/7: Setting directory permissions..."
mkdir -p "$INSTALL_DIR/shared"
chmod -R 755 "$INSTALL_DIR"
log "Permissions set."

# ── 6. Start all services with Docker Compose ────────────────────────────────
log "Step 6/7: Pulling Docker images and starting services..."
log "(This may take 5–8 minutes on first run — images are ~1.5GB total)"

cd "$INSTALL_DIR"
docker compose pull >> "$LOG_FILE" 2>&1
docker compose up -d >> "$LOG_FILE" 2>&1

# Give services a moment to initialise
sleep 5

log "Docker services started. Checking status..."
docker compose ps >> "$LOG_FILE" 2>&1
log "All containers launched."

# ── 7. Detect public IP and write MOTD ────────────────────────────────────────
log "Step 7/7: Detecting server IP and writing welcome message..."

# Try multiple methods to get the public IP
PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
  || curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
  || curl -s --max-time 5 http://checkip.amazonaws.com 2>/dev/null \
  || hostname -I | awk '{print $1}')

# Disable default Ubuntu MOTD dynamic components
chmod -x /etc/update-motd.d/* 2>/dev/null || true

# Write the custom Workshop MOTD
cat > /etc/motd << EOF

╔══════════════════════════════════════════════════════════════════════════════╗
║        🤖  AI & WhatsApp Automation — Workshop Server Ready!  📱            ║
╚══════════════════════════════════════════════════════════════════════════════╝

  Your server IP: ${PUBLIC_IP}

  ┌─ ACCESS YOUR TOOLS ──────────────────────────────────────────────────────┐
  │                                                                            │
  │  📊  n8n (Automation Engine)                                               │
  │      http://${PUBLIC_IP}:5678                                              │
  │      → First visit: Create your owner account to get started              │
  │                                                                            │
  │  📱  Evolution Manager (WhatsApp)                                          │
  │      http://${PUBLIC_IP}:8082                                              │
  │      → Server URL: http://${PUBLIC_IP}:8081                               │
  │      → API Key: workshop-key-xyz                                           │
  │                                                                            │
  │  🧠  Ollama (Local AI)                                                     │
  │      http://${PUBLIC_IP}:11434                                             │
  │      → Llama 3.2 is downloading in background (~2GB, give it ~5 min)      │
  │                                                                            │
  └────────────────────────────────────────────────────────────────────────────┘

  ⚡ INTERNAL URLs (use these INSIDE n8n workflows):
     Evolution API  →  http://evolution_api:8080
     Ollama         →  http://ollama:11434
     Qdrant         →  http://qdrant:6333

  📁 Files: /opt/workshop
  📋 Logs:  tail -f /var/log/workshop-setup.log
            docker compose -f /opt/workshop/docker-compose.yml logs -f

══════════════════════════════════════════════════════════════════════════════

EOF

log "MOTD written with server IP: $PUBLIC_IP"

# ── Done ──────────────────────────────────────────────────────────────────────
log "============================================================"
log "  SETUP COMPLETE!"
log ""
log "  n8n:                http://${PUBLIC_IP}:5678"
log "  Evolution Manager:  http://${PUBLIC_IP}:8082"
log "  Ollama:             http://${PUBLIC_IP}:11434"
log ""
log "  Note: Ollama is downloading Llama 3.2 in the background."
log "  Monitor: docker logs \$(docker ps -qf name=ollama) -f"
log "============================================================"
