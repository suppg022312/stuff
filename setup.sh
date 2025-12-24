#stop  prompting to restart network services and does the default automatically
sudo DEBIAN_FRONTEND=noninteractive 

# Update and upgrade the package list
sudo apt update -y
sudo apt upgrade -y

# Install required dependencies
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker’s APT repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker 
sudo apt install docker.io

# Verify Docker installation
docker --version

#################################################################################################################
# Add current user to the Docker group
sudo usermod -aG docker $USER

# Install Python
sudo apt install -y python3 python3-pip

sudo apt install -y python3 python3-pip python3-dev build-essential python3-venv
sudo pip3 install virtualenv virtualenvwrapper numpy pandas requests flask django ipython jupyter docker

# Reload the system groups
newgrp docker

echo "Installation complete. Please reboot your system for all changes to take effect."




#nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
node -v
npm -v
npm install -g yarn
npm install -g nodemon pm2 typescript eslint
sudo apt install net-tools -y
sudo apt install samba -y

############################################################################################################################################
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --advertise-exit-node
sudo sysctl vm.swappiness=30
sudo sysctl -p


########################    The Basics  #########################################################################################################
sudo sysctl vm.swappiness=30
sudo sysctl -p

curl -fsSL https://opencode.ai/install | bash
curl -sSL https://dokploy.com/install.sh | sh

######Docker Containw=ers###########
sudo docker run -d --name portainer --restart=always -p 9000:8000 -p 9443:9443 -v /var/run/docker.sock:/var/run/docker.sock -v /media/docker/portainer:/data -e EDGE=1 -e EDGE_ID=10.2.1.183 portainer/portainer-ce:latest

sudo docker run -d --name filebrowser -p 8070:80 -v /:/srv --restart unless-stopped filebrowser/filebrowser:latest
#sudo docker run -d --name nginx-proxy-manager -p 80:80 -p 81:81 -p 443:443 -v /media/docker/proxy/data:/data -v /media/docker/proxy/lets:/etc/letsencrypt jc21/nginx-proxy-manager
docker run -d --name n8n -p 5678:5678 -e N8N_BASIC_AUTH_ACTIVE=true -e N8N_BASIC_AUTH_USER=suppg02 -e N8N_BASIC_AUTH_PASSWORD=Mu02ckca -e N8N_HOST=ubhost3 -e N8N_PORT=5678 -v /media


sudo docker run -d --name homarr -p 7575:7575 -v /media/docker/homarr:/app/data -v /var/run/docker.sock:/var/run/docker.sock -e SECRET_ENCRYPTION_KEY="b9bc7ffc665daf9928c9336ec8d008b3aacbc637b8abad0ae3e4a146953a8a33" -e NEXTAUTH_SECRET="$(openssl rand -base64 32)" -e NEXTAUTH_URL="http://localhost:7575" -e BASE_URL="/" -e HOMARR_API_ENABLED="true" -e DISABLE_AUTH="true" -e ALLOW_GUESTS="true" --restart unless-stopped ghcr.io/homarr-labs/homarr:latest




 sudo docker run -d --name qdrant -p 6333:6333 -p 6334:6334 -v $(pwd)/qdrant_storage:/media/docker/qdrant/storage qdrant/qdrant:latest
 sudo docker run -d --name arangodb-membership --restart unless-stopped -p 8529:8529 -e ARANGO_ROOT_PASSWORD="securepassword123" -v arangodb_membership_data:/var/lib/arangodb3 arangodb/arangodb:3.11
 docker run --name postgres-db -e POSTGRES_PASSWORD=mysecretpassword -e POSTGRES_USER=myuser -e POSTGRES_DB=mydatabase -p 5432:5432 -d postgres:latest
 
 sudo usermod -aG docker $USER && newgrp docker
 
 docker run -d --name anythingllm1 -p 3009:3001 -v /media/docker/anything:/app/server/storage -e STORAGE_DIR=/app/server/storage -e NODE_ENV=production -e ANYTHING_LLM_RUNTIME=docker -e DEPLOYMENT_VERSION=1.9.0 mintplexlabs/anythingllm:latest
 

curl -fsSL https://opencode.ai/install | bash
