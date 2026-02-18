#!/bin/bash
# ==============================================================================
# AI & WhatsApp Automation Starter Kit — Server Bootstrap Script
# Repository: https://github.com/EmreGunner/ai-automation-with-whatsapp-starter
# Target OS : Ubuntu 24.04 LTS on DigitalOcean (4 GB RAM minimum)
#
# This script creates a complete docker-compose.yml with all fixes baked in.
# No reliance on repo contents - everything is self-contained.
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

LOG_FILE="/var/log/workshop-setup.log"
INSTALL_DIR="/opt/workshop"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "============================================================"
log "  AI & WhatsApp Automation Starter Kit - Bootstrap Starting"
log "  $(date)"
log "============================================================"

# ── STEP 1: Configure firewall FIRST ──────────────────────────────────────────
log "STEP 1/7: Configuring firewall..."

ufw allow 22/tcp >> "$LOG_FILE" 2>&1 || true
ufw allow 5678/tcp >> "$LOG_FILE" 2>&1 || true
ufw allow 8081/tcp >> "$LOG_FILE" 2>&1 || true
ufw allow 8082/tcp >> "$LOG_FILE" 2>&1 || true
ufw allow 11434/tcp >> "$LOG_FILE" 2>&1 || true
echo "y" | ufw enable >> "$LOG_FILE" 2>&1 || true
ufw reload >> "$LOG_FILE" 2>&1 || true
log "Firewall configured."

# ── STEP 2: System update ─────────────────────────────────────────────────────
log "STEP 2/7: Updating system packages..."

apt-get update -qq >> "$LOG_FILE" 2>&1 || log "WARNING: apt-get update failed"
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qq >> "$LOG_FILE" 2>&1 || log "WARNING: apt-get upgrade failed"
apt-get install -y -qq curl git ca-certificates gnupg >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
  log "ERROR: Failed to install prerequisites"
  exit 1
fi
log "System packages ready."

# ── STEP 3: Install Docker ────────────────────────────────────────────────────
log "STEP 3/7: Installing Docker..."

if command -v docker &> /dev/null; then
  log "Docker already installed: $(docker --version)"
else
  apt-get remove -y docker docker-engine docker.io containerd runc >> "$LOG_FILE" 2>&1 || true
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc >> "$LOG_FILE" 2>&1
  chmod a+r /etc/apt/keyrings/docker.asc
  
  ARCH=$(dpkg --print-architecture)
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list >> "$LOG_FILE"
  
  apt-get update -qq >> "$LOG_FILE" 2>&1
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1
  
  if [ $? -ne 0 ]; then
    log "ERROR: Docker installation failed"
    exit 1
  fi
fi

systemctl enable docker >> "$LOG_FILE" 2>&1
systemctl start docker >> "$LOG_FILE" 2>&1

if ! systemctl is-active --quiet docker; then
  log "ERROR: Docker daemon not running"
  exit 1
fi

log "Docker ready: $(docker --version)"

# ── STEP 4: Create directory ──────────────────────────────────────────────────
log "STEP 4/7: Creating installation directory..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
log "Working directory: $INSTALL_DIR"

# ── STEP 5: Write docker-compose.yml with ALL FIXES BAKED IN ──────────────────
log "STEP 5/7: Writing docker-compose.yml..."

cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  # n8n - Workflow automation engine
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n_user
      - DB_POSTGRESDB_PASSWORD=n8n_password_workshop
      - N8N_SECURE_COOKIE=false
      - N8N_HOST=localhost
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=UTC
    depends_on:
      - postgres
    volumes:
      - n8n_storage:/home/node/.n8n
      - ./shared:/data/shared
    networks:
      - workshop_net

  # n8n's dedicated PostgreSQL database
  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      - POSTGRES_USER=n8n_user
      - POSTGRES_PASSWORD=n8n_password_workshop
      - POSTGRES_DB=n8n
    volumes:
      - n8n_postgres_data:/var/lib/postgresql/data
    networks:
      - workshop_net

  # Ollama - Local LLM engine
  ollama:
    image: ollama/ollama:latest
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - workshop_net

  # Qdrant - Vector database
  qdrant:
    image: qdrant/qdrant:latest
    restart: always
    ports:
      - "6333:6333"
    volumes:
      - qdrant_storage:/qdrant/storage
    networks:
      - workshop_net

  # Evolution API - WhatsApp integration
  evolution_api:
    image: atendai/evolution-api:latest
    restart: always
    ports:
      - "8081:8080"
    environment:
      - SERVER_URL=http://localhost:8081
      - SERVER_PORT=8080
      - AUTHENTICATION_API_KEY=workshop-key-xyz
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://evolution_user:evolution_password_workshop@evolution_postgres:5432/evolution_db
      - DATABASE_CONNECTION_CLIENT_NAME=evolution_v2
      - DATABASE_SAVE_DATA_INSTANCE=true
      - DATABASE_SAVE_DATA_NEW_MESSAGE=true
      - DATABASE_SAVE_MESSAGE_UPDATE=true
      - DATABASE_SAVE_DATA_CONTACTS=true
      - DATABASE_SAVE_DATA_CHATS=true
      - CACHE_REDIS_ENABLED=true
      - CACHE_REDIS_URI=redis://evolution_redis:6379/1
      - CACHE_REDIS_PREFIX_KEY=evolution
      - CACHE_LOCAL_ENABLED=false
      - DEL_INSTANCE=false
      - LOG_LEVEL=ERROR
      - LOG_COLOR=true
    depends_on:
      - evolution_postgres
      - evolution_redis
    networks:
      - workshop_net

  # Evolution's dedicated PostgreSQL database  
  evolution_postgres:
    image: postgres:15-alpine
    restart: always
    environment:
      - POSTGRES_USER=evolution_user
      - POSTGRES_PASSWORD=evolution_password_workshop
      - POSTGRES_DB=evolution_db
    volumes:
      - evolution_postgres_data:/var/lib/postgresql/data
    networks:
      - workshop_net

  # Evolution's Redis cache
  evolution_redis:
    image: redis:alpine
    restart: always
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - evolution_redis_data:/data
    networks:
      - workshop_net

  # Evolution Manager UI
  evolution_manager:
    image: atendai/evolution-manager:latest
    restart: always
    ports:
      - "8082:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8081
    networks:
      - workshop_net

volumes:
  n8n_storage:
  n8n_postgres_data:
  ollama_data:
  qdrant_storage:
  evolution_postgres_data:
  evolution_redis_data:

networks:
  workshop_net:
    driver: bridge
COMPOSE_EOF

log "docker-compose.yml created."

# ── STEP 6: Start services ────────────────────────────────────────────────────
log "STEP 6/7: Pulling images and starting services..."
log "(This takes 10-20 minutes on first run - downloading ~5GB of images)"

docker compose pull >> "$LOG_FILE" 2>&1 || log "WARNING: Some images failed to pull"
docker compose up -d >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
  log "ERROR: Failed to start services"
  docker compose logs >> "$LOG_FILE" 2>&1
  exit 1
fi

sleep 10
docker compose ps >> "$LOG_FILE" 2>&1
log "Services started."

# ── STEP 7: Write MOTD ─────────────────────────────────────────────────────────
log "STEP 7/7: Writing welcome message..."

PUBLIC_IP=$(curl -s --max-time 8 https://ifconfig.me 2>/dev/null || curl -s --max-time 8 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
log "Detected IP: $PUBLIC_IP"

chmod -x /etc/update-motd.d/* 2>/dev/null || true

cat > /etc/motd << MOTD_EOF

╔══════════════════════════════════════════════════════════════╗
║     AI & WhatsApp Automation — Workshop Server Ready         ║
╚══════════════════════════════════════════════════════════════╝

  Server IP: ${PUBLIC_IP}

  ┌─ YOUR TOOLS ────────────────────────────────────────────────┐
  │                                                              │
  │  n8n (Automation)     →  http://${PUBLIC_IP}:5678          │
  │    First visit: create your owner account                   │
  │                                                              │
  │  Evolution Manager    →  http://${PUBLIC_IP}:8082          │
  │    Login with API Key: workshop-key-xyz                     │
  │                                                              │
  │  Ollama (AI Engine)   →  http://${PUBLIC_IP}:11434         │
  │    Llama 3.2 auto-downloads on first use (~2 GB)           │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘

  INSIDE n8n workflows, use these internal addresses:
    Evolution API  →  http://evolution_api:8080
    Ollama         →  http://ollama:11434
    Qdrant         →  http://qdrant:6333

  LOGS:
    Setup log    →  cat /var/log/workshop-setup.log
    Cloud-init   →  cat /var/log/cloud-init-output.log
    Containers   →  cd /opt/workshop && docker compose logs -f

══════════════════════════════════════════════════════════════════

MOTD_EOF

log "============================================================"
log "  SETUP COMPLETE — $(date)"
log "  n8n:      http://${PUBLIC_IP}:5678"
log "  Manager:  http://${PUBLIC_IP}:8082"
log "  Ollama:   http://${PUBLIC_IP}:11434"
log "============================================================"
