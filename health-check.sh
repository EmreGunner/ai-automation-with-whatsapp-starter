#!/bin/bash
# ==============================================================================
# AI & WhatsApp Automation Starter Kit — Health Check Script
# Verifies all services are properly configured and running
# ==============================================================================

set -euo pipefail

INSTALL_DIR="/opt/workshop"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     AI & WhatsApp Automation — Health Check                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

pass() {
  echo -e "${GREEN}✓${NC} $1"
}

fail() {
  echo -e "${RED}✗${NC} $1"
  ((ERRORS++))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  ((WARNINGS++))
}

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1: System Prerequisites
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. System Prerequisites"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check OS
if grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null; then
  pass "Operating System: Ubuntu 24.04 LTS"
elif grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
  warn "Operating System: $(grep VERSION= /etc/os-release | cut -d'"' -f2) (recommended: Ubuntu 24.04)"
else
  fail "Operating System: Not Ubuntu (unsupported)"
fi

# Check RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -ge 4 ]; then
  pass "RAM: ${TOTAL_RAM}GB (sufficient)"
elif [ "$TOTAL_RAM" -ge 2 ]; then
  warn "RAM: ${TOTAL_RAM}GB (minimum, may cause Ollama crashes)"
else
  fail "RAM: ${TOTAL_RAM}GB (insufficient - needs 4GB minimum)"
fi

# Check Docker
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
  pass "Docker: Installed (${DOCKER_VERSION})"
  
  if systemctl is-active --quiet docker; then
    pass "Docker Daemon: Running"
  else
    fail "Docker Daemon: Not running"
  fi
else
  fail "Docker: Not installed"
fi

# Check Docker Compose
if docker compose version &> /dev/null; then
  COMPOSE_VERSION=$(docker compose version | awk '{print $4}')
  pass "Docker Compose: Installed (${COMPOSE_VERSION})"
else
  fail "Docker Compose: Not installed"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2: Installation Directory
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Installation Directory"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "$INSTALL_DIR" ]; then
  pass "Directory: $INSTALL_DIR exists"
  
  if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
    pass "docker-compose.yml: Found"
  else
    fail "docker-compose.yml: Missing"
  fi
else
  fail "Directory: $INSTALL_DIR not found"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3: Firewall Configuration
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Firewall Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v ufw &> /dev/null; then
  if ufw status | grep -q "Status: active"; then
    pass "UFW: Active"
    
    # Check required ports
    for PORT in 22 5678 8081 8082 11434; do
      if ufw status | grep -q "$PORT"; then
        pass "Port $PORT: Allowed in UFW"
      else
        fail "Port $PORT: Not allowed in UFW"
      fi
    done
  else
    warn "UFW: Inactive (firewall disabled)"
  fi
else
  warn "UFW: Not installed"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4: Docker Containers
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Docker Containers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
  cd "$INSTALL_DIR"
  
  REQUIRED_SERVICES=("n8n" "postgres" "ollama" "qdrant" "evolution_api" "evolution_postgres" "evolution_redis" "evolution_manager")
  
  for SERVICE in "${REQUIRED_SERVICES[@]}"; do
    STATUS=$(docker compose ps --format json 2>/dev/null | jq -r "select(.Service==\"$SERVICE\") | .State" 2>/dev/null || echo "missing")
    
    if [ "$STATUS" = "running" ]; then
      pass "Container: $SERVICE (running)"
    elif [ "$STATUS" = "restarting" ]; then
      fail "Container: $SERVICE (crash-looping)"
    elif [ "$STATUS" = "exited" ]; then
      fail "Container: $SERVICE (stopped)"
    else
      fail "Container: $SERVICE (not found)"
    fi
  done
else
  fail "Cannot check containers: docker-compose.yml not found"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5: Port Accessibility
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Port Accessibility (localhost)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_port() {
  local PORT=$1
  local NAME=$2
  
  if timeout 2 bash -c "echo > /dev/tcp/localhost/$PORT" 2>/dev/null; then
    pass "$NAME (port $PORT): Accessible"
  else
    fail "$NAME (port $PORT): Not accessible"
  fi
}

check_port 5678 "n8n"
check_port 8081 "Evolution API"
check_port 8082 "Evolution Manager"
check_port 11434 "Ollama"
check_port 6333 "Qdrant"

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6: Service Health Checks
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Service Health (HTTP endpoints)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# n8n
if curl -s -f http://localhost:5678 > /dev/null 2>&1; then
  pass "n8n: HTTP 200 OK"
else
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "000" ]; then
    fail "n8n: Not responding"
  else
    warn "n8n: HTTP $HTTP_CODE (may be expected for setup page)"
  fi
fi

# Ollama
if curl -s http://localhost:11434 | grep -q "Ollama is running"; then
  pass "Ollama: Running"
else
  fail "Ollama: Not responding"
fi

# Qdrant
if curl -s http://localhost:6333 | grep -q '"title":"qdrant"'; then
  pass "Qdrant: Running"
else
  fail "Qdrant: Not responding"
fi

# Evolution API
EVOLUTION_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/manager 2>/dev/null || echo "000")
if [ "$EVOLUTION_RESPONSE" = "200" ] || [ "$EVOLUTION_RESPONSE" = "302" ] || [ "$EVOLUTION_RESPONSE" = "401" ]; then
  pass "Evolution API: Responding (HTTP $EVOLUTION_RESPONSE)"
else
  fail "Evolution API: Not responding (HTTP $EVOLUTION_RESPONSE)"
fi

# Evolution Manager
MANAGER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082 2>/dev/null || echo "000")
if [ "$MANAGER_RESPONSE" = "200" ]; then
  pass "Evolution Manager: Responding"
else
  fail "Evolution Manager: Not responding (HTTP $MANAGER_RESPONSE)"
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7: Database Connectivity
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Database Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
  cd "$INSTALL_DIR"
  
  # Check n8n postgres
  if docker compose exec -T postgres pg_isready -U n8n_user &>/dev/null; then
    pass "n8n PostgreSQL: Accepting connections"
  else
    fail "n8n PostgreSQL: Not accepting connections"
  fi
  
  # Check evolution postgres
  if docker compose exec -T evolution_postgres pg_isready -U evolution_user &>/dev/null; then
    pass "Evolution PostgreSQL: Accepting connections"
  else
    fail "Evolution PostgreSQL: Not accepting connections"
  fi
  
  # Check redis
  if docker compose exec -T evolution_redis redis-cli ping | grep -q "PONG"; then
    pass "Evolution Redis: Responding"
  else
    fail "Evolution Redis: Not responding"
  fi
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 8: Docker Volumes
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. Docker Volumes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

REQUIRED_VOLUMES=("n8n_storage" "n8n_postgres_data" "ollama_data" "qdrant_storage" "evolution_postgres_data" "evolution_redis_data")

for VOLUME in "${REQUIRED_VOLUMES[@]}"; do
  if docker volume ls | grep -q "$VOLUME"; then
    pass "Volume: $VOLUME exists"
  else
    fail "Volume: $VOLUME missing"
  fi
done

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 9: Common Configuration Issues
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. Configuration Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
  # Check N8N_SECURE_COOKIE
  if grep -q "N8N_SECURE_COOKIE=false" "$INSTALL_DIR/docker-compose.yml"; then
    pass "n8n: Secure cookie disabled for HTTP access"
  else
    fail "n8n: N8N_SECURE_COOKIE not set to false (will block HTTP access)"
  fi
  
  # Check Evolution database credentials match
  EVOLUTION_DB_USER=$(grep "POSTGRES_USER=" "$INSTALL_DIR/docker-compose.yml" | grep -A 5 "evolution_postgres:" | grep "POSTGRES_USER=" | cut -d'=' -f2)
  if echo "$EVOLUTION_DB_USER" | grep -q "evolution_user"; then
    pass "Evolution: Database credentials properly configured"
  else
    fail "Evolution: Database user mismatch detected"
  fi
  
  # Check separate databases
  if grep -q "evolution_postgres:" "$INSTALL_DIR/docker-compose.yml" && grep -q "postgres:" "$INSTALL_DIR/docker-compose.yml"; then
    pass "Databases: Separate postgres instances for n8n and Evolution"
  else
    fail "Databases: Missing separate postgres instances"
  fi
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 10: Logs Review
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "10. Recent Container Errors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
  cd "$INSTALL_DIR"
  
  ERROR_COUNT=$(docker compose logs --tail=100 2>/dev/null | grep -iE "error|fail|fatal" | wc -l)
  
  if [ "$ERROR_COUNT" -eq 0 ]; then
    pass "No recent errors in container logs"
  elif [ "$ERROR_COUNT" -lt 5 ]; then
    warn "$ERROR_COUNT error messages in recent logs (may be transient)"
  else
    fail "$ERROR_COUNT error messages in recent logs"
    echo ""
    echo "   Most recent errors:"
    docker compose logs --tail=100 2>/dev/null | grep -iE "error|fail|fatal" | tail -5 | sed 's/^/     /'
  fi
fi

echo ""

# ══════════════════════════════════════════════════════════════════════════════
# Final Summary
# ══════════════════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  echo ""
  echo "Your AI & WhatsApp Automation stack is healthy."
  echo ""
  echo "Access your services:"
  PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
  echo "  • n8n:              http://${PUBLIC_IP}:5678"
  echo "  • Evolution Manager: http://${PUBLIC_IP}:8082"
  echo "  • Ollama:           http://${PUBLIC_IP}:11434"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}⚠ Passed with $WARNINGS warning(s)${NC}"
  echo ""
  echo "The system is functional but some non-critical issues were found."
  exit 0
else
  echo -e "${RED}✗ Failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
  echo ""
  echo "Critical issues detected. Review the failures above."
  echo ""
  echo "Troubleshooting commands:"
  echo "  • View setup log:     cat /var/log/workshop-setup.log"
  echo "  • View cloud-init:    cat /var/log/cloud-init-output.log"
  echo "  • Check containers:   cd /opt/workshop && docker compose ps"
  echo "  • View all logs:      cd /opt/workshop && docker compose logs"
  exit 1
fi
