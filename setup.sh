#!/bin/bash
# ==============================================================================
# AI & WhatsApp Automation Workshop — Setup Script
# Uses Official Evolution API: https://github.com/EvolutionAPI/evolution-api
# Target: Ubuntu 24.04 LTS on DigitalOcean (4GB+ RAM)
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="/var/log/workshop-setup.log"
INSTALL_DIR="/opt/workshop"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

fatal() {
  echo "[FATAL] $*" | tee -a "$LOG_FILE"
  exit 1
}

log "╔══════════════════════════════════════════════════════════════╗"
log "║  AI & WhatsApp Automation — Setup Starting                   ║"
log "╚══════════════════════════════════════════════════════════════╝"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1: Configure Firewall
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 1/7: Configuring firewall..."

ufw --force enable >> "$LOG_FILE" 2>&1
ufw allow 22/tcp >> "$LOG_FILE" 2>&1
ufw allow 5678/tcp >> "$LOG_FILE" 2>&1
ufw allow 8081/tcp >> "$LOG_FILE" 2>&1
ufw allow 8082/tcp >> "$LOG_FILE" 2>&1
ufw allow 11434/tcp >> "$LOG_FILE" 2>&1
ufw reload >> "$LOG_FILE" 2>&1

log "✓ Firewall configured"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2: Install Docker
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 2/7: Installing Docker..."

if ! command -v docker &> /dev/null; then
  apt-get update -qq >> "$LOG_FILE" 2>&1
  apt-get install -y -qq curl ca-certificates gnupg >> "$LOG_FILE" 2>&1
  
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc >> "$LOG_FILE" 2>&1
  chmod a+r /etc/apt/keyrings/docker.asc
  
  ARCH=$(dpkg --print-architecture)
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list >> "$LOG_FILE"
  
  apt-get update -qq >> "$LOG_FILE" 2>&1
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin >> "$LOG_FILE" 2>&1 \
    || fatal "Docker installation failed"
fi

systemctl enable docker >> "$LOG_FILE" 2>&1
systemctl start docker >> "$LOG_FILE" 2>&1

log "✓ Docker installed: $(docker --version)"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3: Create Installation Directory
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 3/7: Setting up installation directory..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || fatal "Cannot cd to $INSTALL_DIR"

log "✓ Working directory: $INSTALL_DIR"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4: Download Official Evolution API Configuration
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 4/7: Downloading official Evolution API setup..."

curl -fsSL https://raw.githubusercontent.com/EvolutionAPI/evolution-api/main/Docker/.env.example -o .env.example >> "$LOG_FILE" 2>&1 \
  || log "Warning: Could not download .env.example"

# Create .env from Evolution's template
cat > .env << 'ENV_EOF'
# Server
SERVER_URL=http://localhost:8081
SERVER_PORT=8080
CORS_ORIGIN=*
CORS_METHODS=POST,GET,PUT,DELETE
CORS_CREDENTIALS=true

# Authentication
AUTHENTICATION_TYPE=apikey
AUTHENTICATION_API_KEY=workshop-key-xyz
AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true

# Database
DATABASE_ENABLED=true
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=postgresql://evolution_user:evolution_password@evolution-postgres:5432/evolution_db
DATABASE_CONNECTION_CLIENT_NAME=evolution_v2
DATABASE_SAVE_DATA_INSTANCE=true
DATABASE_SAVE_DATA_NEW_MESSAGE=true
DATABASE_SAVE_MESSAGE_UPDATE=true
DATABASE_SAVE_DATA_CONTACTS=true
DATABASE_SAVE_DATA_CHATS=true

# PostgreSQL
POSTGRES_DATABASE=evolution_db
POSTGRES_USERNAME=evolution_user
POSTGRES_PASSWORD=evolution_password

# Redis
CACHE_REDIS_ENABLED=true
CACHE_REDIS_URI=redis://redis:6379
CACHE_REDIS_PREFIX_KEY=evolution
CACHE_REDIS_SAVE_INSTANCES=false
CACHE_LOCAL_ENABLED=false

# Logs
LOG_LEVEL=ERROR
LOG_COLOR=true
LOG_BAILEYS=error

# Other
DEL_INSTANCE=false
QRCODE_LIMIT=30
WEBHOOK_GLOBAL_URL=
WEBHOOK_GLOBAL_ENABLED=false
WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS=false
ENV_EOF

log "✓ Evolution .env created"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5: Create Complete docker-compose.yml
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 5/7: Creating docker-compose.yml with all services..."

cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  # ============= n8n Stack =============
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=n8n_postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n_user
      - DB_POSTGRESDB_PASSWORD=n8n_password
      - N8N_SECURE_COOKIE=false
      - N8N_HOST=localhost
      - WEBHOOK_URL=http://localhost:5678/
    depends_on:
      - n8n_postgres
    volumes:
      - n8n_storage:/home/node/.n8n
    networks:
      - workshop_net

  n8n_postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      - POSTGRES_USER=n8n_user
      - POSTGRES_PASSWORD=n8n_password
      - POSTGRES_DB=n8n
    volumes:
      - n8n_postgres_data:/var/lib/postgresql/data
    networks:
      - workshop_net

  # ============= AI Stack =============
  ollama:
    image: ollama/ollama:latest
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - workshop_net

  qdrant:
    image: qdrant/qdrant:latest
    restart: always
    ports:
      - "6333:6333"
    volumes:
      - qdrant_storage:/qdrant/storage
    networks:
      - workshop_net

  # ============= Official Evolution API Stack =============
  api:
    container_name: evolution_api
    image: evoapicloud/evolution-api:latest
    restart: always
    ports:
      - "8081:8080"
    env_file:
      - .env
    volumes:
      - evolution_instances:/evolution/instances
    depends_on:
      - redis
      - evolution-postgres
    networks:
      - workshop_net

  frontend:
    container_name: evolution_frontend
    image: evoapicloud/evolution-manager:latest
    restart: always
    ports:
      - "8082:80"
    networks:
      - workshop_net

  redis:
    container_name: evolution_redis
    image: redis:latest
    restart: always
    command: redis-server --port 6379 --appendonly yes
    volumes:
      - evolution_redis:/data
    networks:
      - workshop_net

  evolution-postgres:
    container_name: evolution_postgres
    image: postgres:15
    restart: always
    command:
      - postgres
      - -c
      - max_connections=1000
    environment:
      - POSTGRES_DB=${POSTGRES_DATABASE}
      - POSTGRES_USER=${POSTGRES_USERNAME}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    env_file:
      - .env
    volumes:
      - evolution_postgres_data:/var/lib/postgresql/data
    networks:
      - workshop_net

volumes:
  n8n_storage:
  n8n_postgres_data:
  ollama_data:
  qdrant_storage:
  evolution_instances:
  evolution_redis:
  evolution_postgres_data:

networks:
  workshop_net:
    driver: bridge
COMPOSE_EOF

log "✓ docker-compose.yml created"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6: Start All Services
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 6/7: Pulling images and starting services (10-20 min)..."

docker compose pull >> "$LOG_FILE" 2>&1
docker compose up -d >> "$LOG_FILE" 2>&1 || fatal "Failed to start services"

log "✓ Services started, waiting for initialization..."
sleep 30

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7: Verify Services
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 7/7: Verifying services..."

docker compose ps >> "$LOG_FILE" 2>&1

log "✓ Setup complete"

# ══════════════════════════════════════════════════════════════════════════════
# Display Summary
# ══════════════════════════════════════════════════════════════════════════════
PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

cat > /etc/motd << MOTD_EOF

╔══════════════════════════════════════════════════════════════╗
║     AI & WhatsApp Automation Workshop — Ready                ║
╚══════════════════════════════════════════════════════════════╝

  Access your services:

    n8n                →  http://${PUBLIC_IP}:5678
    Evolution Manager  →  http://${PUBLIC_IP}:8082
    Evolution API      →  http://${PUBLIC_IP}:8081
    Ollama (AI)        →  http://${PUBLIC_IP}:11434
    Qdrant (Vector DB) →  http://${PUBLIC_IP}:6333

  Evolution API Key: workshop-key-xyz

  Check services: cd /opt/workshop && docker compose ps
  View logs:      cd /opt/workshop && docker compose logs -f

══════════════════════════════════════════════════════════════════

MOTD_EOF

log ""
log "╔══════════════════════════════════════════════════════════════╗"
log "║  SETUP COMPLETE ✓                                            ║"
log "╚══════════════════════════════════════════════════════════════╝"
log ""
log "  n8n:              http://${PUBLIC_IP}:5678"
log "  Evolution Manager: http://${PUBLIC_IP}:8082"
log "  Evolution API:    http://${PUBLIC_IP}:8081"
log "  Ollama:           http://${PUBLIC_IP}:11434"
log "  Qdrant:           http://${PUBLIC_IP}:6333"
log ""
log "Using official Evolution API from GitHub"
log "Check status: cd /opt/workshop && docker compose ps"
log ""
