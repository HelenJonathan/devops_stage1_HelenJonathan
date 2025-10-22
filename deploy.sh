#!/bin/bash
# =============================================
# HNG Stage 1 DevOps Deployment Script
# Author: Helen Efebe
# =============================================

set -euo pipefail
IFS=$'\n\t'

# ----------- LOGGING FUNCTION -----------
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ----------- ERROR HANDLING -------------
trap 'log "❌ An unexpected error occurred. Exiting..."; exit 1' ERR

# ----------- USER INPUT COLLECTION -------
log "🔧 Collecting user input..."

read -p "Enter your GitHub repository URL: " GIT_URL
read -p "Enter your Personal Access Token: " TOKEN
read -p "Enter your SSH username: " SSH_USER
read -p "Enter your SSH host (IP or domain): " SSH_HOST
read -p "Enter SSH private key path (default: ~/.ssh/id_rsa): " SSH_KEY
SSH_KEY=${SSH_KEY:-~/.ssh/id_rsa}
read -p "Enter your application port (e.g. 8000): " APP_PORT
read -p "Enter branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

# ----------- INPUT VALIDATION ------------
if [[ -z "$GIT_URL" || -z "$TOKEN" || -z "$SSH_USER" || -z "$SSH_HOST" || -z "$APP_PORT" ]]; then
  log "❌ One or more required inputs are missing."
  exit 1
fi

# ----------- GIT OPERATIONS --------------
log "🌀 Preparing repository..."

if [ -d "repo" ]; then
  log "🔁 Repository already exists. Pulling latest changes..."
  cd repo && git pull
else
  log "📦 Cloning repository..."
  git clone "https://${TOKEN}@${GIT_URL#https://}" repo
  cd repo
fi

log "🔀 Switching to branch: $BRANCH"
git checkout "$BRANCH" || git checkout -b "$BRANCH"

cd ..

# ----------- SSH CONNECTIVITY ------------
log "🔐 Testing SSH connectivity..."
if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SSH_HOST" "echo connected" >/dev/null 2>&1; then
  log "✅ SSH connection successful."
else
  log "❌ SSH connection failed."
  exit 1
fi

# ----------- SERVER PREPARATION ----------
log "⚙️ Preparing remote server..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" bash <<EOF
set -e
log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1"; }

log "🔄 Updating system packages..."
sudo apt update -y

log "📦 Installing dependencies..."
sudo apt install -y docker.io docker-compose nginx git || true

log "👥 Configuring Docker group..."
sudo usermod -aG docker \$USER

log "🚀 Enabling and starting services..."
sudo systemctl enable docker nginx
sudo systemctl start docker nginx
EOF

# ----------- FILE TRANSFER ---------------
log "📤 Copying project files to remote server..."
scp -i "$SSH_KEY" -r repo "$SSH_USER@$SSH_HOST":/root/app

# ----------- DOCKER DEPLOYMENT -----------
log "🐳 Deploying Docker application..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" bash <<EOF
set -e
cd /root/app

log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1"; }

if [ -f "docker-compose.yml" ]; then
  log "🧱 Using docker-compose for deployment..."
  sudo docker-compose down || true
  sudo docker-compose up -d --build
else
  log "⚙️ Building Docker image manually..."
  sudo docker build -t app_image .
  sudo docker run -d --name app_container -p ${APP_PORT}:${APP_PORT} app_image
fi

log "✅ Docker containers running:"
sudo docker ps
EOF

# ----------- NGINX CONFIGURATION ----------
log "🌐 Setting up Nginx reverse proxy..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" bash <<EOF
set -e

cat <<NGINXCONF | sudo tee /etc/nginx/sites-available/app.conf
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGINXCONF

sudo ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
EOF

# ----------- DEPLOYMENT VALIDATION -------
log "🔍 Validating deployment..."

ssh -i "$SSH_KEY" "$SSH_USER@$SSH_HOST" bash <<EOF
set -e
log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1"; }

log "🔎 Checking Docker service..."
if ! systemctl is-active --quiet docker; then
  log "❌ Docker service not running!"
  exit 1
fi

log "🔎 Checking Docker containers..."
if ! docker ps | grep -q "app"; then
  log "❌ Docker container not found!"
  exit 1
fi

log "🔎 Checking Nginx..."
if ! systemctl is-active --quiet nginx; then
  log "❌ Nginx not active!"
  exit 1
fi

log "✅ All services are running properly."
EOF

# ----------- CLEANUP & SUMMARY -----------
log "🧹 Cleaning up..."
rm -rf repo
log "✅ Deployment complete! Your app should now be live on http://${SSH_HOST}"
