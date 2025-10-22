# 🚀 HNG13 Stage 1 DevOps Task – Automated Deployment Script

## Author
**Name:** Helen Efebe  
**Slack Username:** `the_helenefebe`  
**GitHub Username:** `HelenJonathan`

---

## 🎯 Task Objective
To develop a **production-grade Bash script** (`deploy.sh`) that automates:
- The setup, configuration, and deployment of a Dockerized application
- On a **remote Linux (Linode)** server
- With proper logging, error handling, and idempotency

---

## ⚙️ Features
✅ Accepts parameters for repo, branch, SSH credentials, and port  
✅ Clones or updates the GitHub repo automatically  
✅ Installs Docker, Docker Compose, and Nginx on the remote host  
✅ Deploys containerized app (Dockerfile or docker-compose)  
✅ Configures Nginx as reverse proxy  
✅ Validates deployment and logs all activities

---

## 🧰 Requirements
- **Ubuntu 22.04 LTS** (local and remote)
- **Git**, **Docker**, **Docker Compose**, **Nginx**
- SSH key authentication configured for both GitHub and Linode

---

## 🚀 Usage
1. Make the script executable:
   ```bash
   chmod +x deploy.sh
