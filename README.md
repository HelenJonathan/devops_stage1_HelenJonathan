# HNG13 Stage 1 DevOps Task

## 🚀 Overview
This project automates the setup, deployment, and configuration of a Dockerized application on a remote Linux (Linode) server using a single Bash script.


## ⚙️ Configuration Details

REMOTE_USER="root"
REMOTE_IP="172.233.145.169"
SSH_KEY="~/.ssh/id_ed25519"
APP_PORT=8080
REMOTE_NAME="hng13-stage1"
REPO="git@github.com:HelenJonathan/hng13-stage1-devops.git"
BRANCH="main"

---

echo "Starting deployment to $REMOTE_NAME ($REMOTE_IP)..."

# Clone or update repository on local
if [ ! -d "./repo" ]; then
echo "Cloning repository..."
git clone -b $BRANCH $REPO repo
else
echo "Updating existing repository..."
cd repo && git pull origin $BRANCH && cd ..
fi

# Compress the repo
tar -czf app.tar.gz -C repo .

# Copy compressed files to remote server
echo "Transferring files to remote server..."
scp -i $SSH_KEY app.tar.gz $REMOTE_USER@$REMOTE_IP:/root/

# Connect and deploy remotely
echo "Deploying on remote server..."
ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_IP << EOF
echo "Setting up on remote server..."
mkdir -p /root/app
tar -xzf /root/app.tar.gz -C /root/app

cd /root/app

echo "Pulling latest Docker image and rebuilding container..."
docker compose down || true
docker compose up -d --build

echo "Deployment complete on $REMOTE_NAME!"
docker ps
EOF

# Cleanup
rm app.tar.gz
echo "Local cleanup done."