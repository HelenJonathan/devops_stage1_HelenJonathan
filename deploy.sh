#!/bin/bash

# ============================================
# HNG13 Stage 1 DevOps Task
# Automated Deployment Bash Script
# Author: Helen Efebe
# ============================================

set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error
set -o pipefail  # Catch errors in piped commands

LOG_FILE="deploy_$(date +%Y%m%d).log"

# Logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handler
trap 'log "❌ An unexpected error occurred. Check $LOG_FILE for details." ; exit 1' ERR

# ============================================
# CONFIGURATION (Static — No input required)
# ============================================

GIT_REPO="git@github.com:HelenJonathan/hng13-stage1-devops.git"
BRANCH="main"

REMOTE_USER="root"
REMOTE_HOST="172.233.145.169"
SSH_KEY="~/.ssh/id_ed25519"

APP_PORT="8080"
REMOTE_APP_DIR="/opt/hng13-stage1"
NGINX_CONF="/etc/nginx/sites-available/hng13-stage1"
NGINX_ENABLED="/etc/nginx/sites-enabled/hng13-stage1"

# ============================================
# STEP 1: Clone or Update Repo
# ============================================

log "🚀 Starting deployment process..."
if [ ! -d "hng13-stage1-devops" ]; then
  log "📦 Cloning repository from GitHub..."
  git clone -b "$BRANCH" "$GIT_REPO" | tee -a "$LOG_FILE"
else
  log "🔁 Repository already exists. Pulling latest changes..."
  cd hng13-stage1-devops
  git fetch origin "$BRANCH"
  git reset --hard "origin/$BRANCH"
  cd ..
fi

cd hng13-stage1-devops
log "✅ Switched to project directory: $(pwd)"

# ============================================
# STEP 2: Validate Docker Files
# ============================================

if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
  log "🧱 Docker configuration found."
else
  log "❌ No Dockerfile or docker-compose.yml found. Exiting."
  exit 1
fi

# ============================================
# STEP 3: Verify SSH Connection
# ============================================

log "🔐 Verifying SSH connection to remote server..."
if ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo SSH connection established"; then
  log "✅ SSH connection verified."
else
  log "❌ Unable to connect to remote server via SSH."
  exit 1
fi

# ============================================
# STEP 4: Prepare Remote Environment
# ============================================

log "🧰 Setting up remote environment (Docker, Nginx)..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" bash <<EOF
  set -e
  apt update -y
  apt install -y docker.io docker-compose nginx
  systemctl enable docker
  systemctl start docker
  systemctl enable nginx
  systemctl start nginx
  usermod -aG docker $REMOTE_USER || true
EOF
log "✅ Remote environment ready."

# ============================================
# STEP 5: Transfer Files to Remote Server
# ============================================

log "📤 Transferring project files to remote server..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $REMOTE_APP_DIR"
rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" ./ "$REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR" --exclude '.git'
log "✅ Files transferred successfully."

# ============================================
# STEP 6: Deploy Docker Container
# ============================================

log "🐳 Deploying Docker container on remote server..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" bash <<EOF
  set -e
  cd $REMOTE_APP_DIR
  if [ -f docker-compose.yml ]; then
    docker-compose down || true
    docker-compose up -d --build
  else
    docker stop hng13-container || true
    docker rm hng13-container || true
    docker build -t hng13-app .
    docker run -d --name hng13-container -p $APP_PORT:$APP_PORT hng13-app
  fi
EOF
log "✅ Docker container deployed successfully."

# ============================================
# STEP 7: Configure Nginx Reverse Proxy
# ============================================

log "🌐 Configuring Nginx reverse proxy..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" bash <<EOF
  cat <<NGINX_CONF > $NGINX_CONF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGINX_CONF

  ln -sf $NGINX_CONF $NGINX_ENABLED
  nginx -t
  systemctl reload nginx
EOF
log "✅ Nginx reverse proxy configured successfully."

# ============================================
# STEP 8: Validate Deployment
# ============================================

log "🔎 Validating deployment..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" bash <<EOF
  docker ps
  systemctl status nginx | head -n 10
  curl -I http://localhost
EOF

log "✅ Deployment validation complete."
log "🎉 Application successfully deployed at: http://$REMOTE_HOST"
log "📜 Logs saved to $LOG_FILE"
