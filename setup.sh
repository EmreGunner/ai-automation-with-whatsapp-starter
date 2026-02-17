#!/bin/bash
# ==============================================================================
# AI & WhatsApp Automation Starter Kit — Server Bootstrap Script
# Repository: https://github.com/EmreGunner/ai-automation-with-whatsapp-starter
# Target OS : Ubuntu 24.04 LTS on DigitalOcean (4 GB RAM minimum)
#
# DEBUGGING: If something goes wrong, check these two log files via the
# DigitalOcean browser console (Droplet → Console → type "root" + your password):
#
#   cat /var/log/cloud-init-output.log   <- cloud-init official log
#   cat /var/log/workshop-setup.log      <- this script's detailed log
# ==============================================================================

# IMPORTANT: We do NOT use "set -euo pipefail" here.
# In a cloud-init User Data script, that flag causes the entire script to
# abort silently the moment any single command fails (e.g., a failed apt lock).
# Instead, every critical step is verified individually below.

export DEBIAN_FRONTEND=noninteractive

LOG_FILE="/var/log/workshop-setup.log"
REPO_URL="https://github.com/EmreGunner/ai-automation-with-whatsapp-starter.git"
INSTALL_DIR="/opt/workshop"

# ── Logging helper ─────────────────────────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "============================================================"
log "  Bootstrap Starting — $(date)"
log "  Running as: $(whoami)"
log "============================================================"

# ── STEP 1: Open firewall ports FIRST ─────────────────────────────────────────
# Do this before anything else — even if later steps fail, SSH stays open.
log "STEP 1/8: Configuring UFW firewall..."

ufw allow 22/tcp    >> "$LOG_FILE" 2>&1 || true
ufw allow 5678/tcp  >> "$LOG_FILE" 2>&1 || true   # n8n
ufw allow 8081/tcp  >> "$LOG_FILE" 2>&1 || true   # Evolution API
ufw allow 8082/tcp  >> "$LOG_FILE" 2>&1 || true   # Evolution Manager UI
ufw allow 11434/tcp >> "$LOG_FILE" 2>&1 || true   # Ollama
echo "y" | ufw enable  >> "$LOG_FILE" 2>&1 || true
ufw reload             >> "$LOG_FILE" 2>&1 || true
log "Firewall: ports 22, 5678, 8081, 8082, 11434 opened."
ufw status >> "$LOG_FILE" 2>&1

# ── STEP 2: System update ──────────────────────────────────────────────────────
log "STEP 2/8: Updating system packages..."

apt-get update -qq >> "$LOG_FILE" 2>&1 || log "WARNING: apt-get update failed, continuing..."

apt-get upgrade -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  -qq >> "$LOG_FILE" 2>&1 || log "WARNING: apt-get upgrade failed, continuing..."

apt-get install -y -qq \
  curl \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
  log "ERROR: Could not install prerequisites. Aborting."
  exit 1
fi
log "System packages ready."

# ── STEP 3: Install Docker ────────────────────────────────────────────────────
log "STEP 3/8: Installing Docker Engine..."

if command -v docker &> /dev/null; then
  log "Docker already installed: $(docker --version)"
else
  # Remove legacy packages
  apt-get remove -y docker docker-engine docker.io containerd runc >> "$LOG_FILE" 2>&1 || true

  # Add Docker GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc >> "$LOG_FILE" 2>&1
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add Docker apt repository
  ARCH=$(dpkg --print-architecture)
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list >> "$LOG_FILE"

  apt-get update -qq >> "$LOG_FILE" 2>&1

  apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin >> "$LOG_FILE" 2>&1

  if [ $? -ne 0 ]; then
    log "ERROR: Docker installation failed. Check $LOG_FILE"
    exit 1
  fi
fi

systemctl enable docker >> "$LOG_FILE" 2>&1
systemctl start docker  >> "$LOG_FILE" 2>&1

if ! systemctl is-active --quiet docker; then
  log "ERROR: Docker daemon is not running after install. Aborting."
  exit 1
fi

log "Docker ready: $(docker --version)"
log "Compose ready: $(docker compose version)"

# ── STEP 4: Clone repository ───────────────────────────────────────────────────
log "STEP 4/8: Cloning repository..."

if [ -d "$INSTALL_DIR/.git" ]; then
  log "Repo exists — pulling latest..."
  git -C "$INSTALL_DIR" pull >> "$LOG_FILE" 2>&1 || log "WARNING: git pull failed"
else
  git clone "$REPO_URL" "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
  if [ $? -ne 0 ]; then
    log "ERROR: git clone failed. Check your internet connection and repo URL."
    exit 1
  fi
fi
log "Repository ready at $INSTALL_DIR"
log "Repo contents: $(ls $INSTALL_DIR)"

# ── STEP 5: Verify docker-compose.yml exists ──────────────────────────────────
log "STEP 5/8: Verifying docker-compose.yml..."

if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
  log "ERROR: docker-compose.yml not found in repo!"
  log "Files present: $(ls -la $INSTALL_DIR)"
  exit 1
fi
log "docker-compose.yml found."

# ── STEP 6: Configure .env file ───────────────────────────────────────────────
log "STEP 6/8: Setting up .env..."

cd "$INSTALL_DIR"

if [ ! -f ".env" ]; then
  if [ -f "env.example" ]; then
    cp env.example .env
    log ".env created from env.example"
  else
    log "WARNING: env.example not found — writing minimal .env"
    cat > .env << 'ENVEOF'
N8N_ENCRYPTION_KEY=a3f7b92c1d4e8f0a6b5c2d9e1f4a7b3c8d0e5f2a
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=n8n_password_workshop
AUTHENTICATION_API_KEY=workshop-key-xyz
DATABASE_CONNECTION_URI=postgresql://evolution_user:evolution_password_workshop@evolution_postgres:5432/evolution_db
EVOLUTION_POSTGRES_USER=evolution_user
EVOLUTION_POSTGRES_PASSWORD=evolution_password_workshop
EVOLUTION_POSTGRES_DB=evolution_db
CACHE_REDIS_URI=redis://evolution_redis:6379/1
ENVEOF
    log "Minimal .env written."
  fi
else
  log ".env already exists — skipping copy."
fi

# ── STEP 7: Pull images and start services ────────────────────────────────────
log "STEP 7/8: Starting Docker services (this takes 5-10 min on first run)..."

cd "$INSTALL_DIR"

log "Pulling Docker images..."
docker compose pull >> "$LOG_FILE" 2>&1
PULL_EXIT=$?
if [ $PULL_EXIT -ne 0 ]; then
  log "WARNING: docker compose pull returned exit code $PULL_EXIT — attempting start anyway"
fi

log "Running docker compose up -d ..."
docker compose up -d >> "$LOG_FILE" 2>&1
UP_EXIT=$?
if [ $UP_EXIT -ne 0 ]; then
  log "ERROR: docker compose up -d failed with exit code $UP_EXIT"
  log "--- Compose config validation ---"
  docker compose config >> "$LOG_FILE" 2>&1
  log "--- Docker system info ---"
  docker info >> "$LOG_FILE" 2>&1
  exit 1
fi

sleep 8

log "Container status:"
docker compose ps >> "$LOG_FILE" 2>&1

# ── STEP 8: Write MOTD welcome screen ────────────────────────────────────────
log "STEP 8/8: Writing MOTD..."

PUBLIC_IP=$(curl -s --max-time 8 https://ifconfig.me 2>/dev/null)
[ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(curl -s --max-time 8 https://api.ipify.org 2>/dev/null)
[ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(curl -s --max-time 8 http://checkip.amazonaws.com 2>/dev/null)
[ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(hostname -I | awk '{print $1}')

log "Detected server IP: $PUBLIC_IP"

chmod -x /etc/update-motd.d/* 2>/dev/null || true

cat > /etc/motd << MOTD_EOF

==========================================================================
  AI + WhatsApp Automation — Workshop Server Ready
==========================================================================

  Server IP: ${PUBLIC_IP}

  YOUR TOOLS:
  ─────────────────────────────────────────────────────────────────────────
  n8n Automation      http://${PUBLIC_IP}:5678
  (first visit: create your owner account)

  Evolution Manager   http://${PUBLIC_IP}:8082
  (Server URL: http://${PUBLIC_IP}:8081  |  API Key: workshop-key-xyz)

  Ollama AI Engine    http://${PUBLIC_IP}:11434
  (Llama 3.2 downloads automatically on first start, ~2 GB / ~5 min)
  ─────────────────────────────────────────────────────────────────────────

  INSIDE n8n workflows, use these internal service names (NOT the public IP):
    Evolution API  ->  http://evolution_api:8080
    Ollama         ->  http://ollama:11434
    Qdrant         ->  http://qdrant:6333

  TROUBLESHOOTING LOGS:
    cat /var/log/workshop-setup.log
    cat /var/log/cloud-init-output.log
    cd /opt/workshop && docker compose logs -f

==========================================================================
MOTD_EOF

log "MOTD written."

# ── Done ──────────────────────────────────────────────────────────────────────
log "============================================================"
log "  SETUP COMPLETE — $(date)"
log "  n8n               -> http://${PUBLIC_IP}:5678"
log "  Evolution Manager -> http://${PUBLIC_IP}:8082"
log "  Ollama            -> http://${PUBLIC_IP}:11434"
log ""
log "  If browser says 'connection refused', check:"
log "  1. ufw status                     (server firewall)"
log "  2. DigitalOcean -> Networking -> Firewalls  (cloud firewall)"
log "  3. docker compose ps              (are containers actually up?)"
log "============================================================"
