#!/bin/bash
# Integrated Setup Script from https://github.com/suppg022312/stuff/main/setup.sh
# Optimized for unattended cloud-init execution

echo "Starting Integrated Setup..."

# Disable interactive prompts
export DEBIAN_FRONTEND=noninteractive

echo "--- Updating and upgrading system packages ---"
apt-get update -y
apt-get upgrade -y

echo "--- Installing base dependencies (curl, gnupg, samba, python, etc.) ---"
apt-get install -y ca-certificates curl gnupg lsb-release net-tools samba python3 python3-pip python3-dev build-essential python3-venv

echo "--- Configuring Docker Repository ---"
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "--- Installing Docker Engine ---"
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "--- Installing Python packages (numpy, pandas, jupyter, etc.) ---"
pip3 install --break-system-packages virtualenv virtualenvwrapper numpy pandas requests flask django ipython jupyter docker

echo "--- Installing Node.js v18 and global tools ---"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
npm install -g yarn nodemon pm2 typescript eslint

echo "--- Installing Tailscale ---"
curl -fsSL https://tailscale.com/install.sh | sh

echo "--- Applying system optimizations (swappiness) ---"
sysctl vm.swappiness=30
sysctl -p

echo "--- Installing specialized tools (OpenCode, Dokploy) ---"
curl -fsSL https://opencode.ai/install | bash || true
curl -sSL https://dokploy.com/install.sh | sh || true

# Docker Containers Setup
echo "Launching Docker Containers..."

echo "--- Launching Portainer ---"
docker run -d --name portainer --restart=always -p 9000:8000 -p 9443:9443 -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/portainer/data:/data portainer/portainer-ce:latest

echo "--- Launching Filebrowser ---"
docker run -d --name filebrowser -p 8070:80 -v /:/srv --restart unless-stopped filebrowser/filebrowser:latest

echo "--- Launching n8n ---"
docker run -d --name n8n -p 5678:5678 -e N8N_BASIC_AUTH_ACTIVE=true -e N8N_BASIC_AUTH_USER=suppg02 -e N8N_BASIC_AUTH_PASSWORD=Mu02ckca -e N8N_HOST=localhost -e N8N_PORT=5678 -v /var/lib/n8n:/home/node/.n8n docker.n8n.io/n8nio/n8n:latest

echo "--- Installing Homarr with backup restoration ---"
# Non-interactive Homarr setup based on https://github.com/suppg022312/stuff/blob/main/setup_homarr.sh
HOMARR_PORT=7575
BACKUP_URL="https://raw.githubusercontent.com/suppg022312/stuff/main/homarr_backup.tar.gz"
TEMP_DIR="/tmp/homarr_install_$$"
mkdir -p "$TEMP_DIR"

# Download backup
echo "Downloading Homarr backup from GitHub..."
curl -fsSL "$BACKUP_URL" -o "$TEMP_DIR/homarr_backup.tar.gz"

# Create Docker volumes
echo "Creating Homarr Docker volumes..."
docker volume create homarr_config
docker volume create homarr_icons
docker volume create homarr_data
docker volume create homarr_appdata

# Get volume paths
APPDATA_VOLUME=$(docker volume inspect homarr_appdata --format '{{ .Mountpoint }}')
CONFIG_VOLUME=$(docker volume inspect homarr_config --format '{{ .Mountpoint }}')
ICONS_VOLUME=$(docker volume inspect homarr_icons --format '{{ .Mountpoint }}')
DATA_VOLUME=$(docker volume inspect homarr_data --format '{{ .Mountpoint }}')

# Extract backup
echo "Extracting backup to volumes..."
tar -xzf "$TEMP_DIR/homarr_backup.tar.gz" -C "$APPDATA_VOLUME"

# Copy database files to correct location
mkdir -p "$APPDATA_VOLUME/db" "$APPDATA_VOLUME/redis"
if [ -d "$APPDATA_VOLUME/appdata/db" ]; then
    cp -r "$APPDATA_VOLUME/appdata/db/"* "$APPDATA_VOLUME/db/" 2>/dev/null || true
fi
if [ -d "$APPDATA_VOLUME/appdata/redis" ]; then
    cp -r "$APPDATA_VOLUME/appdata/redis/"* "$APPDATA_VOLUME/redis/" 2>/dev/null || true
fi

# Set proper permissions (Homarr runs with UID:GID 1000:1000)
chown -R 1000:1000 "$CONFIG_VOLUME" "$ICONS_VOLUME" "$DATA_VOLUME" "$APPDATA_VOLUME"

# Cleanup temp directory
rm -rf "$TEMP_DIR"

# Deploy Homarr container with restored configuration
echo "Deploying Homarr container..."
docker run -d \
    --name homarr \
    --restart unless-stopped \
    -p "$HOMARR_PORT:7575" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v homarr_config:/app/data/configs \
    -v homarr_icons:/app/public/icons \
    -v homarr_data:/data \
    -v homarr_appdata:/appdata \
    -e "SECRET_ENCRYPTION_KEY=481add341be488c933756ac0383e408f3572a4eb472fc0de5d953ae0529aafb8" \
    -e "DB_URL=/appdata/db/db.sqlite" \
    -e "DB_DIALECT=sqlite" \
    -e "DB_DRIVER=better-sqlite3" \
    -e "AUTH_PROVIDERS=credentials" \
    -e "REDIS_IS_EXTERNAL=false" \
    -e "NODE_ENV=production" \
    ghcr.io/homarr-labs/homarr:latest

echo "Homarr installed with backup restoration complete!"

echo "--- Launching Qdrant ---"
docker run -d --name qdrant -p 6333:6333 -p 6334:6334 -v /var/lib/qdrant:/qdrant/storage qdrant/qdrant:latest

echo "--- Launching ArangoDB ---"
docker run -d --name arangodb-membership --restart unless-stopped -p 8529:8529 -e ARANGO_ROOT_PASSWORD="securepassword123" -v arangodb_membership_data:/var/lib/arangodb3 arangodb/arangodb:3.11

echo "--- Launching Postgres ---"
docker run --name postgres-db -e POSTGRES_PASSWORD=mysecretpassword -e POSTGRES_USER=myuser -e POSTGRES_DB=mydatabase -p 5432:5432 -d postgres:latest

echo "--- Launching AnythingLLM ---"
docker run -d --name anythingllm1 -p 3009:3001 -v /var/lib/anythingllm:/app/server/storage -e STORAGE_DIR=/app/server/storage -e NODE_ENV=production -e ANYTHING_LLM_RUNTIME=docker mintplexlabs/anythingllm:latest

echo "Setup complete. Some services may take a moment to pull and start."
