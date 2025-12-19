# Homarr Host Setup Guide - Enhanced with GitHub Support

This guide provides step-by-step instructions for setting up Homarr with your existing configuration on a new Ubuntu host, supporting both local backup files and GitHub repository downloads.

## Prerequisites

- Ubuntu host with Docker installed
- Docker service running
- Sudo or root access
- Internet connection (for GitHub downloads)
- Either:
  - Homarr backup file (homarr_backup.tar.gz) available, OR
  - GitHub repository URL containing Homarr configuration

## Section 1: Directory Structure Setup

Create the necessary directory structure for Homarr:

```bash
sudo mkdir -p /media/docker/homarrdir
sudo chown -R $USER:$USER /media/docker/homarrdir
cd /media/docker/homarrdir
```

## Section 2A: Transfer Backup File (Local Method)

If you have a local backup file:

```bash
# If transferring from another machine, use scp:
# scp user@source-host:/media/docker/homarr1/homarr_backup.tar.gz /media/docker/homarrdir/

# If backup is already on the host in a different location:
# cp /path/to/homarr_backup.tar.gz /media/docker/homarrdir/

# Make sure the backup file exists:
ls -la /media/docker/homarrdir/homarr_backup.tar.gz
```

## Section 2B: Download from GitHub Repository (Remote Method)

If you want to download from a GitHub repository:

```bash
# Set your repository URL
GITHUB_REPO="https://github.com/suppg022312/md.git"
BRANCH="main"  # or your default branch

# Clone the repository
git clone "$GITHUB_REPO" temp_config

# Copy the backup file (it should be named homarr_backup.tar.gz in your repo)
if [ -f "temp_config/homarr_backup.tar.gz" ]; then
    cp temp_config/homarr_backup.tar.gz .
    echo "Successfully downloaded homarr_backup.tar.gz from GitHub"
else
    echo "Error: homarr_backup.tar.gz not found in repository"
    echo "Available files:"
    ls -la temp_config/
    exit 1
fi

# Clean up
rm -rf temp_config

# Verify the download
ls -la /media/docker/homarrdir/homarr_backup.tar.gz
```

## Section 2C: Alternative GitHub Download (Raw File Method)

For direct file download without cloning:

```bash
# Set your repository details
GITHUB_USER="your-username"
REPO_NAME="your-homarr-config"
BRANCH="main"
FILE_PATH="homarr_backup.tar.gz"

# Download the file
wget "https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/$BRANCH/$FILE_PATH" -O homarr_backup.tar.gz

# Verify the download
ls -la /media/docker/homarrdir/homarr_backup.tar.gz
```

## Section 3: Docker Volume Creation

Create the necessary Docker volumes for Homarr:

```bash
docker volume create homarr_config
docker volume create homarr_icons  
docker volume create homarr_data
docker volume create homarr_appdata
```

## Section 4: Extract Backup to Volumes

Extract the backup data to the appropriate Docker volumes:

```bash
# Get the volume paths
CONFIG_VOLUME=$(docker volume inspect homarr_config --format '{{ .Mountpoint }}')
ICONS_VOLUME=$(docker volume inspect homarr_icons --format '{{ .Mountpoint }}')
DATA_VOLUME=$(docker volume inspect homarr_data --format '{{ .Mountpoint }}')
APPDATA_VOLUME=$(docker volume inspect homarr_appdata --format '{{ .Mountpoint }}')

# Extract backup to appdata volume (main configuration)
sudo tar -xzf /media/docker/homarrdir/homarr_backup.tar.gz -C "$APPDATA_VOLUME"

# Copy database files to the correct location within appdata
sudo mkdir -p "$APPDATA_VOLUME/db"
sudo mkdir -p "$APPDATA_VOLUME/redis"
sudo cp -r "$APPDATA_VOLUME/appdata/db/"* "$APPDATA_VOLUME/db/" 2>/dev/null || true
sudo cp -r "$APPDATA_VOLUME/appdata/redis/"* "$APPDATA_VOLUME/redis/" 2>/dev/null || true

# Set proper permissions
sudo chown -R 1000:1000 "$CONFIG_VOLUME" "$ICONS_VOLUME" "$DATA_VOLUME" "$APPDATA_VOLUME"
```

## Section 5: Homarr Container Deployment

Deploy the Homarr container with the restored configuration:

```bash
docker run -d \
  --name homarr \
  --restart unless-stopped \
  -p 7575:7575 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v homarr_config:/app/data/configs \
  -v homarr_icons:/app/public/icons \
  -v homarr_data:/data \
  -v homarr_appdata:/appdata \
  -e SECRET_ENCRYPTION_KEY="481add341be488c933756ac0383e408f3572a4eb472fc0de5d953ae0529aafb8" \
  -e DB_URL="/appdata/db/db.sqlite" \
  -e DB_DIALECT="sqlite" \
  -e DB_DRIVER="better-sqlite3" \
  -e AUTH_PROVIDERS="credentials" \
  -e REDIS_IS_EXTERNAL="false" \
  -e NODE_ENV="production" \
  ghcr.io/homarr-labs/homarr:latest
```

## Section 6: Verification and Access

Verify the setup and access your Homarr dashboard:

```bash
# Check container status
docker ps | grep homarr

# Check container logs
docker logs homarr --tail=20

# Verify database was restored
docker exec homarr ls -la /appdata/db/

# Verify the database file exists and has content
docker exec homarr stat /appdata/db/db.sqlite
```

Access your Homarr dashboard at:
- **URL**: `http://your-server-ip:7575`
- **Alternative**: `http://localhost:7575` (if accessing from the same machine)

## Section 7: GitHub Repository Setup Guide

### How to Create Your Homarr Config Repository

1. **Create a new GitHub repository:**
   ```bash
   mkdir my-homarr-config
   cd my-homarr-config
   git init
   ```

2. **Add your Homarr backup:**
   ```bash
   cp /media/docker/homarr1/homarr_backup.tar.gz .
   git add homarr_backup.tar.gz
   git commit -m "Add Homarr configuration backup"
   ```

3. **Push to GitHub:**
   ```bash
   git branch -M main
   git remote add origin https://github.com/your-username/your-homarr-config.git
   git push -u origin main
   ```

4. **Optional: Add additional configuration files:**
   ```bash
   # Add a README with setup instructions
   cat > README.md << 'EOF'
   # Homarr Configuration
   
   This repository contains the Homarr configuration backup.
   
   ## Usage
   
   Use the setup script in `/media/docs/HostSetup.md` with the GitHub download option.
   
   ## Files
   
   - `homarr_backup.tar.gz` - Complete Homarr database and configuration backup
   EOF
   
   git add README.md
   git commit -m "Add README documentation"
   git push
   ```

### Repository Structure Example

```
your-homarr-config/
├── README.md
├── homarr_backup.tar.gz
└── setup-info.md (optional)
```

## Section 8: Troubleshooting

### GitHub-Related Issues

#### Repository not found or private:
```bash
# For private repositories, use:
git clone https://username:token@github.com/your-username/your-homarr-config.git temp_config

# Or set up SSH keys:
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
# Add the public key to your GitHub account, then:
git clone git@github.com:your-username/your-homarr-config.git temp_config
```

#### Download failed:
```bash
# Check if the file exists in the repository
curl -I "https://raw.githubusercontent.com/your-username/your-homarr-config/main/homarr_backup.tar.gz"

# Alternative download method
curl -L "https://github.com/your-username/your-homarr-config/raw/main/homarr_backup.tar.gz" -o homarr_backup.tar.gz
```

#### Authentication issues:
```bash
# Use GitHub CLI (if installed)
gh repo clone your-username/your-homarr-config temp_config

# Or create a personal access token and use it:
GITHUB_TOKEN="your-token-here"
wget --header="Authorization: token $GITHUB_TOKEN" "https://raw.githubusercontent.com/your-username/your-homarr-config/main/homarr_backup.tar.gz" -O homarr_backup.tar.gz
```

### Common Issues and Solutions

#### Container fails to start with "Invalid environment variables"
```bash
# Verify the SECRET_ENCRYPTION_KEY is set
docker inspect homarr --format='{{range .Config.Env}}{{println .}}{{end}}' | grep SECRET_ENCRYPTION_KEY

# Recreate container if needed
docker stop homarr && docker rm homarr
# Then re-run Section 5
```

#### Database not found or empty
```bash
# Check if database file exists in the container
docker exec homarr ls -la /appdata/db/

# If database is missing, re-extract backup
docker stop homarr
# Re-run Section 4, then start container again
docker start homarr
```

## Section 9: Enhanced Quick Setup Script

### GitHub-Enabled Setup Script

```bash
#!/bin/bash
# Enhanced Homarr Setup Script with GitHub Support

set -e

# Configuration variables
METHOD="github"  # Change to "local" for local backup file
GITHUB_REPO="https://github.com/suppg022312/md.git"
BRANCH="main"
LOCAL_BACKUP_PATH="/path/to/local/homarr_backup.tar.gz"  # Only used if METHOD="local"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Homarr Setup Script ===${NC}"

# Setup directories
echo -e "${YELLOW}Setting up directories...${NC}"
sudo mkdir -p /media/docker/homarrdir
cd /media/docker/homarrdir

# Download or copy backup file
if [ "$METHOD" = "github" ]; then
    echo -e "${YELLOW}Downloading from GitHub: $GITHUB_REPO${NC}"
    git clone "$GITHUB_REPO" temp_config
    if [ -f "temp_config/homarr_backup.tar.gz" ]; then
        cp temp_config/homarr_backup.tar.gz .
        echo -e "${GREEN}✓ Successfully downloaded homarr_backup.tar.gz${NC}"
    else
        echo -e "${RED}✗ Error: homarr_backup.tar.gz not found in repository${NC}"
        echo "Available files:"
        ls -la temp_config/
        rm -rf temp_config
        exit 1
    fi
    rm -rf temp_config
else
    echo -e "${YELLOW}Using local backup file: $LOCAL_BACKUP_PATH${NC}"
    if [ -f "$LOCAL_BACKUP_PATH" ]; then
        cp "$LOCAL_BACKUP_PATH" .
        echo -e "${GREEN}✓ Successfully copied local backup file${NC}"
    else
        echo -e "${RED}✗ Error: Local backup file not found${NC}"
        exit 1
    fi
fi

# Create volumes
echo -e "${YELLOW}Creating Docker volumes...${NC}"
docker volume create homarr_config homarr_icons homarr_data homarr_appdata

# Extract backup
echo -e "${YELLOW}Extracting backup to volumes...${NC}"
APPDATA_VOLUME=$(docker volume inspect homarr_appdata --format '{{ .Mountpoint }}')
sudo tar -xzf homarr_backup.tar.gz -C "$APPDATA_VOLUME"
sudo mkdir -p "$APPDATA_VOLUME/db" "$APPDATA_VOLUME/redis"
sudo cp -r "$APPDATA_VOLUME/appdata/db/"* "$APPDATA_VOLUME/db/" 2>/dev/null || true
sudo cp -r "$APPDATA_VOLUME/appdata/redis/"* "$APPDATA_VOLUME/redis/" 2>/dev/null || true

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
sudo chown -R 1000:1000 $(docker volume inspect homarr_config --format '{{ .Mountpoint }}') $(docker volume inspect homarr_icons --format '{{ .Mountpoint }}') $(docker volume inspect homarr_data --format '{{ .Mountpoint }}') $(docker volume inspect homarr_appdata --format '{{ .Mountpoint }}')

# Stop existing container if it exists
if docker ps -a | grep -q homarr; then
    echo -e "${YELLOW}Stopping existing Homarr container...${NC}"
    docker stop homarr 2>/dev/null || true
    docker rm homarr 2>/dev/null || true
fi

# Deploy container
echo -e "${YELLOW}Deploying Homarr container...${NC}"
docker run -d \
  --name homarr \
  --restart unless-stopped \
  -p 7575:7575 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v homarr_config:/app/data/configs \
  -v homarr_icons:/app/public/icons \
  -v homarr_data:/data \
  -v homarr_appdata:/appdata \
  -e SECRET_ENCRYPTION_KEY="481add341be488c933756ac0383e408f3572a4eb472fc0de5d953ae0529aafb8" \
  -e DB_URL="/appdata/db/db.sqlite" \
  -e DB_DIALECT="sqlite" \
  -e DB_DRIVER="better-sqlite3" \
  -e AUTH_PROVIDERS="credentials" \
  -e REDIS_IS_EXTERNAL="false" \
  -e NODE_ENV="production" \
  ghcr.io/homarr-labs/homarr:latest

# Verification
echo -e "${YELLOW}Verifying installation...${NC}"
sleep 5
if docker ps | grep -q homarr; then
    echo -e "${GREEN}✓ Homarr container is running${NC}"
    
    # Check database
    if docker exec homarr test -f /appdata/db/db.sqlite; then
        echo -e "${GREEN}✓ Database file found and accessible${NC}"
    else
        echo -e "${RED}✗ Database file not found${NC}"
    fi
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}=== Setup Complete! ===${NC}"
    echo -e "${GREEN}Access your Homarr dashboard at: http://$SERVER_IP:7575${NC}"
    echo -e "${GREEN}Or locally at: http://localhost:7575${NC}"
else
    echo -e "${RED}✗ Homarr container failed to start${NC}"
    echo "Checking logs:"
    docker logs homarr --tail=20
    exit 1
fi

echo -e "${GREEN}=== Setup Complete! ===${NC}"
```

Save this script as `/media/docker/homarrdir/setup_with_github.sh` and make it executable:

```bash
chmod +x /media/docker/homarrdir/setup_with_github.sh
```

**Usage:**
```bash
# For GitHub download (default)
sudo /media/docker/homarrdir/setup_with_github.sh

# For local backup file
sudo METHOD=local LOCAL_BACKUP_PATH="/path/to/homarr_backup.tar.gz" /media/docker/homarrdir/setup_with_github.sh
```

## Section 10: Automated Updates from GitHub

### Update Script

```bash
#!/bin/bash
# Update Homarr configuration from GitHub

GITHUB_REPO="https://github.com/your-username/your-homarr-config.git"
BRANCH="main"

cd /media/docker/homarrdir

# Download latest backup
git clone "$GITHUB_REPO" temp_update
cp temp_update/homarr_backup.tar.gz .
rm -rf temp_update

# Stop container
docker stop homarr

# Restore backup
APPDATA_VOLUME=$(docker volume inspect homarr_appdata --format '{{ .Mountpoint }}')
sudo rm -rf "$APPDATA_VOLUME"/*
sudo tar -xzf homarr_backup.tar.gz -C "$APPDATA_VOLUME"
sudo mkdir -p "$APPDATA_VOLUME/db" "$APPDATA_VOLUME/redis"
sudo cp -r "$APPDATA_VOLUME/appdata/db/"* "$APPDATA_VOLUME/db/" 2>/dev/null || true
sudo cp -r "$APPDATA_VOLUME/appdata/redis/"* "$APPDATA_VOLUME/redis/" 2>/dev/null || true
sudo chown -R 1000:1000 "$APPDATA_VOLUME"

# Start container
docker start homarr

echo "Homarr configuration updated from GitHub"
```

This enhanced setup gives you the flexibility to deploy Homarr from either local backups or GitHub repositories, making it perfect for managing multiple installations or sharing configurations across different hosts.