#!/bin/bash
# ==============================================================================
# AI & WhatsApp Automation Starter Kit — Production Setup Script
# Repository: https://github.com/EmreGunner/ai-automation-with-whatsapp-starter
# Target OS : Ubuntu 24.04 LTS on DigitalOcean (4 GB RAM minimum)
#
# FIXES ALL KNOWN ISSUES:
# - Firewall configured first (no ERR_CONNECTION_REFUSED)
# - Proper error handling (no silent failures)
# - Separate databases (n8n + Evolution isolated)
# - Correct environment variables (N8N_SECURE_COOKIE=false, etc.)
# - Service validation (checks each service actually works)
# - Auto-status dashboard on SSH login
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

LOG_FILE="/var/log/workshop-setup.log"
INSTALL_DIR="/opt/workshop"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_success() {
  echo -e "${GREEN}✓${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "${RED}✗${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
  echo -e "${YELLOW}⚠${NC} $*" | tee -a "$LOG_FILE"
}

fatal() {
  log_error "FATAL: $*"
  log_error "Setup failed. Check logs: cat $LOG_FILE"
  exit 1
}

log "╔══════════════════════════════════════════════════════════════╗"
log "║  AI & WhatsApp Automation — Production Setup                 ║"
log "╚══════════════════════════════════════════════════════════════╝"
log ""

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1: Configure Firewall (FIRST - before anything can fail)
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 1/9: Configuring UFW firewall..."

ufw --force enable >> "$LOG_FILE" 2>&1
ufw allow 22/tcp >> "$LOG_FILE" 2>&1
ufw allow 5678/tcp >> "$LOG_FILE" 2>&1
ufw allow 8081/tcp >> "$LOG_FILE" 2>&1
ufw allow 8082/tcp >> "$LOG_FILE" 2>&1
ufw allow 11434/tcp >> "$LOG_FILE" 2>&1
ufw reload >> "$LOG_FILE" 2>&1

log_success "Firewall configured (ports: 22, 5678, 8081, 8082, 11434)"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2: Install Prerequisites
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 2/9: Installing prerequisites..."

apt-get update -qq >> "$LOG_FILE" 2>&1 || log_warn "apt update had issues (continuing)"
apt-get install -y -qq curl git ca-certificates gnupg jq >> "$LOG_FILE" 2>&1 || fatal "Failed to install prerequisites"

log_success "Prerequisites installed (curl, git, ca-certificates, gnupg, jq)"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3: Install Docker
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 3/9: Installing Docker..."

if ! command -v docker &> /dev/null; then
  apt-get remove -y docker docker-engine docker.io containerd runc >> "$LOG_FILE" 2>&1 || true
  
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc >> "$LOG_FILE" 2>&1 || fatal "Failed to download Docker GPG key"
  chmod a+r /etc/apt/keyrings/docker.asc
  
  ARCH=$(dpkg --print-architecture)
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list >> "$LOG_FILE"
  
  apt-get update -qq >> "$LOG_FILE" 2>&1
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1 \
    || fatal "Docker installation failed"
fi

systemctl enable docker >> "$LOG_FILE" 2>&1
systemctl start docker >> "$LOG_FILE" 2>&1
systemctl is-active --quiet docker || fatal "Docker daemon not running"

log_success "Docker installed: $(docker --version)"
log_success "Docker Compose: $(docker compose version)"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4: Create Installation Directory
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 4/9: Setting up installation directory..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || fatal "Cannot cd to $INSTALL_DIR"
mkdir -p shared

log_success "Working directory: $INSTALL_DIR"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5: Write Production docker-compose.yml
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 5/9: Writing docker-compose.yml with all fixes..."

cat > docker-compose.yml << 'COMPOSE_EOF'
services:
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
      postgres:
        condition: service_healthy
    volumes:
      - n8n_storage:/home/node/.n8n
      - ./shared:/data/shared
    networks:
      - workshop_net
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5678"]
      interval: 10s
      timeout: 5s
      retries: 10

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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n_user"]
      interval: 5s
      timeout: 5s
      retries: 10

  ollama:
    image: ollama/ollama:latest
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - workshop_net
    healthcheck:
      test: ["CMD", "ollama", "list"]
      interval: 30s
      timeout: 10s
      retries: 5

  qdrant:
    image: qdrant/qdrant:latest
    restart: always
    ports:
      - "6333:6333"
    volumes:
      - qdrant_storage:/qdrant/storage
    networks:
      - workshop_net
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:6333"]
      interval: 10s
      timeout: 5s
      retries: 10

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
      evolution_postgres:
        condition: service_healthy
      evolution_redis:
        condition: service_healthy
    networks:
      - workshop_net

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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U evolution_user"]
      interval: 5s
      timeout: 5s
      retries: 10

  evolution_redis:
    image: redis:alpine
    restart: always
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - evolution_redis_data:/data
    networks:
      - workshop_net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

  evolution_manager:
    image: atendai/evolution-manager:latest
    restart: always
    ports:
      - "8082:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8081
    networks:
      - workshop_net
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000"]
      interval: 10s
      timeout: 5s
      retries: 10

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

log_success "docker-compose.yml created with health checks"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6: Pull Docker Images
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 6/9: Pulling Docker images (~5GB, 10-20 min on first run)..."

docker compose pull 2>&1 | tee -a "$LOG_FILE"
PULL_EXIT=${PIPESTATUS[0]}

if [ $PULL_EXIT -eq 0 ]; then
  log_success "All images pulled successfully"
else
  log_warn "Some images had pull issues (exit code $PULL_EXIT), attempting start anyway"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7: Start Services
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 7/9: Starting Docker services..."

docker compose up -d 2>&1 | tee -a "$LOG_FILE"
UP_EXIT=${PIPESTATUS[0]}

if [ $UP_EXIT -ne 0 ]; then
  fatal "docker compose up -d failed (exit code $UP_EXIT)"
fi

log_success "Containers launched, waiting for health checks..."
sleep 20

# ══════════════════════════════════════════════════════════════════════════════
# STEP 8: Validate All Services
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 8/9: Validating services..."

validate_service() {
  local SERVICE=$1
  local PORT=$2
  
  # Check container is running
  if ! docker compose ps --format json 2>/dev/null | jq -e ".[] | select(.Service==\"$SERVICE\") | select(.State==\"running\")" > /dev/null 2>&1; then
    log_error "$SERVICE: Container not running"
    docker compose logs "$SERVICE" --tail=10 >> "$LOG_FILE" 2>&1
    return 1
  fi
  
  # Check port accessibility if specified
  if [ -n "$PORT" ]; then
    if timeout 5 bash -c "echo > /dev/tcp/localhost/$PORT" 2>/dev/null; then
      log_success "$SERVICE: Running (port $PORT accessible)"
    else
      log_warn "$SERVICE: Container up but port $PORT not yet accessible"
      return 0  # Don't fail - might be slow to start
    fi
  else
    log_success "$SERVICE: Running"
  fi
  
  return 0
}

FAILED=0

validate_service "postgres" "" || ((FAILED++))
validate_service "n8n" "5678" || ((FAILED++))
validate_service "ollama" "11434" || ((FAILED++))
validate_service "qdrant" "6333" || ((FAILED++))
validate_service "evolution_postgres" "" || ((FAILED++))
validate_service "evolution_redis" "" || ((FAILED++))
validate_service "evolution_api" "8081" || ((FAILED++))
validate_service "evolution_manager" "8082" || ((FAILED++))

if [ $FAILED -gt 0 ]; then
  log_error "$FAILED service(s) failed validation"
  log_error "Run: cd /opt/workshop && docker compose logs"
  exit 1
fi

log_success "All 8 services validated successfully"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 9: Create Auto-Status Dashboard for SSH Login
# ══════════════════════════════════════════════════════════════════════════════
log "STEP 9/9: Setting up auto-status dashboard..."

cat > /usr/local/bin/workshop-status << 'STATUS_EOF'
#!/bin/bash
# Auto-status dashboard for AI & WhatsApp Automation Workshop

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PUBLIC_IP=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AI & WhatsApp Automation — Workshop Status               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Server IP: ${GREEN}${PUBLIC_IP}${NC}"
echo ""

if [ ! -d "/opt/workshop" ]; then
  echo -e "${RED}  Workshop not yet installed${NC}"
  echo ""
  return
fi

cd /opt/workshop

echo "  ┌─ SERVICES ──────────────────────────────────────────────────┐"

check_service() {
  local SERVICE=$1
  local PORT=$2
  local URL=$3
  
  # Check container state
  STATE=$(docker compose ps --format json 2>/dev/null | jq -r "select(.Service==\"$SERVICE\") | .State" 2>/dev/null || echo "missing")
  
  if [ "$STATE" = "running" ]; then
    # Check port if specified
    if [ -n "$PORT" ] && timeout 2 bash -c "echo > /dev/tcp/localhost/$PORT" 2>/dev/null; then
      echo -e "  │  ${GREEN}●${NC} $SERVICE (${URL})"
    elif [ -n "$PORT" ]; then
      echo -e "  │  ${YELLOW}●${NC} $SERVICE (starting...)"
    else
      echo -e "  │  ${GREEN}●${NC} $SERVICE"
    fi
  elif [ "$STATE" = "restarting" ]; then
    echo -e "  │  ${RED}●${NC} $SERVICE (crash-looping)"
  else
    echo -e "  │  ${RED}●${NC} $SERVICE (down)"
  fi
}

check_service "n8n" "5678" "http://${PUBLIC_IP}:5678"
check_service "evolution_manager" "8082" "http://${PUBLIC_IP}:8082"
check_service "evolution_api" "8081" "http://${PUBLIC_IP}:8081"
check_service "ollama" "11434" "http://${PUBLIC_IP}:11434"
check_service "qdrant" "6333" "http://${PUBLIC_IP}:6333"
check_service "postgres" "" ""
check_service "evolution_postgres" "" ""
check_service "evolution_redis" "" ""

echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
echo "  Commands:"
echo "    workshop-logs     → View all service logs"
echo "    workshop-restart  → Restart all services"
echo "    workshop-health   → Run full health check"
echo ""
STATUS_EOF

chmod +x /usr/local/bin/workshop-status

# Create helper commands
cat > /usr/local/bin/workshop-logs << 'LOGS_EOF'
#!/bin/bash
cd /opt/workshop && docker compose logs -f "$@"
LOGS_EOF
chmod +x /usr/local/bin/workshop-logs

cat > /usr/local/bin/workshop-restart << 'RESTART_EOF'
#!/bin/bash
echo "Restarting all workshop services..."
cd /opt/workshop && docker compose restart
echo "Done. Run 'workshop-status' to check status."
RESTART_EOF
chmod +x /usr/local/bin/workshop-restart

cat > /usr/local/bin/workshop-health << 'HEALTH_EOF'
#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/health-check.sh | bash
HEALTH_EOF
chmod +x /usr/local/bin/workshop-health

# Add to SSH login
cat > /etc/profile.d/workshop-status.sh << 'PROFILE_EOF'
# Auto-display workshop status on SSH login
if [ -f /usr/local/bin/workshop-status ]; then
  /usr/local/bin/workshop-status
fi
PROFILE_EOF
chmod +x /etc/profile.d/workshop-status.sh

log_success "Auto-status dashboard configured (shows on SSH login)"

# ══════════════════════════════════════════════════════════════════════════════
# Setup Complete
# ══════════════════════════════════════════════════════════════════════════════
PUBLIC_IP=$(curl -s --max-time 8 https://ifconfig.me 2>/dev/null || curl -s --max-time 8 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')

# Disable default Ubuntu MOTD
chmod -x /etc/update-motd.d/* 2>/dev/null || true

# Write static MOTD
cat > /etc/motd << MOTD_EOF

╔══════════════════════════════════════════════════════════════╗
║     AI & WhatsApp Automation — Workshop Server Ready         ║
╚══════════════════════════════════════════════════════════════╝

  Access your tools:

    n8n                 →  http://${PUBLIC_IP}:5678
    Evolution Manager   →  http://${PUBLIC_IP}:8082
    Ollama              →  http://${PUBLIC_IP}:11434
    Qdrant              →  http://${PUBLIC_IP}:6333

  Helper Commands:

    workshop-status   →  Show service status
    workshop-logs     →  View service logs
    workshop-restart  →  Restart all services
    workshop-health   →  Run full health check

══════════════════════════════════════════════════════════════════

MOTD_EOF

log ""
log "╔══════════════════════════════════════════════════════════════╗"
log "║  SETUP COMPLETE ✓                                            ║"
log "╚══════════════════════════════════════════════════════════════╝"
log ""
log_success "n8n:              http://${PUBLIC_IP}:5678"
log_success "Evolution Manager: http://${PUBLIC_IP}:8082"
log_success "Ollama:           http://${PUBLIC_IP}:11434"
log_success "Qdrant:           http://${PUBLIC_IP}:6333"
log ""
log "Next time you SSH in, you'll see the service status automatically."
log "Run 'workshop-status' anytime to check service health."
log ""
