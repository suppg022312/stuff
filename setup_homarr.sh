#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# =============================================
# Homarr Automated Installation Script
# Author: suppg022312
# Version: 1.0.0
# Repository: https://github.com/suppg022312/stuff
# =============================================

# === Script Metadata ===
SCRIPT_VERSION="1.0.0"
SCRIPT_AUTHOR="suppg022312"
GITHUB_REPO="suppg022312/stuff"
BACKUP_FILENAME="homarr_backup.tar.gz"
DEFAULT_PORT="7575"

# === Color Codes ===
RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# === Logging Functions ===
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_command() { echo -e "${CYAN}[COMMAND]${NC} $1"; }

# === Utility Functions ===
validate_port() {
    local port=$1
    if [[ ! $port =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Invalid port number. Please enter a value between 1-65535."
        return 1
    fi
    return 0
}

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# === System Validation ===
validate_system() {
    log_info "Validating system requirements..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_warning "Running without root privileges. Some operations may fail."
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Installation cancelled."
            exit 1
        fi
    fi
    
    # Check Docker
    if ! command_exists docker; then
        log_error "Docker is required but not installed."
        log_info "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker daemon is not running."
        log_info "Start Docker with: sudo systemctl start docker"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("curl" "tar" "git")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Required command '$cmd' is not installed."
            exit 1
        fi
    done
    
    log_success "System validation passed"
}

# === Interactive Configuration ===
setup_interactive_config() {
    log_info "Setting up Homarr configuration..."
    
    # Port selection
    while true; do
        echo ""
        read -p "Enter port for Homarr [$DEFAULT_PORT]: " HOMARR_PORT
        HOMARR_PORT=${HOMARR_PORT:-$DEFAULT_PORT}
        if validate_port "$HOMARR_PORT"; then 
            break
        fi
    done
    
    # Installation method
    echo ""
    echo -e "${YELLOW}Select backup source:${NC}"
    echo "1) Download from GitHub repository (recommended)"
    echo "2) Local backup file"
    while true; do
        read -p "Enter choice [1-2]: " -n 1 -r
        echo
        case $REPLY in
            1) 
                BACKUP_METHOD="github"
                BACKUP_SOURCE="https://raw.githubusercontent.com/$GITHUB_REPO/main/$BACKUP_FILENAME"
                break
                ;;
            2) 
                BACKUP_METHOD="local"
                while true; do
                    read -p "Enter path to $BACKUP_FILENAME: " BACKUP_PATH
                    if [ -f "$BACKUP_PATH" ]; then
                        BACKUP_SOURCE="$BACKUP_PATH"
                        break
                    else
                        log_error "File not found: $BACKUP_PATH"
                    fi
                done
                break
                ;;
            *) 
                log_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    
    # Show selection summary
    echo ""
    echo -e "${YELLOW}Configuration Summary:${NC}"
    echo "• Port: $HOMARR_PORT"
    echo "• Backup Method: $BACKUP_METHOD"
    if [ "$BACKUP_METHOD" = "github" ]; then
        echo "• Source: GitHub repository ($GITHUB_REPO)"
        echo "• File: $BACKUP_FILENAME"
    else
        echo "• Source: Local file"
        echo "• Path: $BACKUP_SOURCE"
    fi
}

# === Download Backup ===
download_backup() {
    log_info "Processing Homarr backup..."
    
    local temp_dir="/tmp/homarr_install_$$"
    mkdir -p "$temp_dir"
    local backup_file="$temp_dir/$BACKUP_FILENAME"
    
    if [ "$BACKUP_METHOD" = "github" ]; then
        log_command "curl -fsSL $BACKUP_SOURCE -o $backup_file"
        curl -fsSL "$BACKUP_SOURCE" -o "$backup_file"
    else
        log_command "cp $BACKUP_SOURCE $backup_file"
        cp "$BACKUP_SOURCE" "$backup_file"
    fi
    
    # Verify backup file
    if [ ! -f "$backup_file" ]; then
        log_error "Failed to obtain backup file."
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_success "Backup file downloaded and validated"
    echo "$temp_dir"
}

# === Docker Volume Setup ===
create_docker_volumes() {
    log_info "Creating Docker volumes..."
    
    local volumes=("homarr_config" "homarr_icons" "homarr_data" "homarr_appdata")
    
    for volume in "${volumes[@]}"; do
        if docker volume inspect "$volume" > /dev/null 2>&1; then
            log_warning "Volume '$volume' already exists. It will be reused."
        else
            log_command "docker volume create $volume"
            docker volume create "$volume"
            log_success "Created volume: $volume"
        fi
    done
    
    log_success "All Docker volumes ready"
}

# === Extract Backup to Volumes ===
extract_backup_to_volumes() {
    local temp_dir=$1
    local backup_file="$temp_dir/$BACKUP_FILENAME"
    
    log_info "Extracting backup to Docker volumes..."
    
    # Get volume paths
    local appdata_volume=$(docker volume inspect homarr_appdata --format '{{ .Mountpoint }}')
    local config_volume=$(docker volume inspect homarr_config --format '{{ .Mountpoint }}')
    local icons_volume=$(docker volume inspect homarr_icons --format '{{ .Mountpoint }}')
    local data_volume=$(docker volume inspect homarr_data --format '{{ .Mountpoint }}')
    
    # Extract backup to appdata volume first
    log_command "tar -xzf $backup_file -C $appdata_volume"
    tar -xzf "$backup_file" -C "$appdata_volume"
    
    # Copy database files to correct location
    log_command "mkdir -p $appdata_volume/db $appdata_volume/redis"
    mkdir -p "$appdata_volume/db" "$appdata_volume/redis"
    
    if [ -d "$appdata_volume/appdata/db" ]; then
        cp -r "$appdata_volume/appdata/db/"* "$appdata_volume/db/" 2>/dev/null || true
    fi
    
    if [ -d "$appdata_volume/appdata/redis" ]; then
        cp -r "$appdata_volume/appdata/redis/"* "$appdata_volume/redis/" 2>/dev/null || true
    fi
    
    # Set proper permissions (Homarr runs with UID:GID 1000:1000)
    log_command "chown -R 1000:1000 $config_volume $icons_volume $data_volume $appdata_volume"
    chown -R 1000:1000 "$config_volume" "$icons_volume" "$data_volume" "$appdata_volume"
    
    log_success "Backup extracted successfully"
    
    # Cleanup temp directory
    rm -rf "$temp_dir"
}

# === Deploy Homarr Container ===
deploy_homarr_container() {
    log_info "Deploying Homarr container..."
    
    # Stop and remove existing container if it exists
    if docker ps -a | grep -q homarr; then
        log_warning "Existing Homarr container found. It will be replaced."
        log_command "docker stop homarr && docker rm homarr"
        docker stop homarr 2>/dev/null || true
        docker rm homarr 2>/dev/null || true
    fi
    
    # Pull latest image
    log_command "docker pull ghcr.io/homarr-labs/homarr:latest"
    docker pull ghcr.io/homarr-labs/homarr:latest
    
    # Deploy container
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
    
    log_success "Homarr container deployed"
}

# === Installation Verification ===
verify_installation() {
    log_info "Verifying installation..."
    
    # Wait for container to start
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker ps | grep -q homarr; then
            break
        fi
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "Container failed to start within expected time."
        docker logs homarr --tail=20
        exit 1
    fi
    
    # Check container status
    local container_status=$(docker ps --format '{{.Status}}' --filter name=homarr)
    if [[ $container_status == *"Up"* ]]; then
        log_success "Container is running: $container_status"
    else
        log_error "Container is not running properly: $container_status"
        docker logs homarr --tail=20
        exit 1
    fi
    
    # Wait a bit more for full initialization
    sleep 5
    
    # Test network connectivity
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HOMARR_PORT" | grep -q "200\|302"; then
        log_success "Web interface is accessible"
    else
        log_warning "Web interface not yet accessible (may still be initializing)"
    fi
    
    log_success "Installation verification completed"
}

# === Display Success Information ===
display_success_info() {
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}"
    echo "=========================================="
    echo "    HOMARR INSTALLATION SUCCESSFUL"
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}📡 Access Information:${NC}"
    echo "   • Local access: ${CYAN}http://localhost:$HOMARR_PORT${NC}"
    if [ "$server_ip" != "127.0.0.1" ] && [ -n "$server_ip" ]; then
        echo "   • Network access: ${CYAN}http://$server_ip:$HOMARR_PORT${NC}"
    fi
    echo ""
    
    echo -e "${YELLOW}🐳 Container Information:${NC}"
    echo "   • Name: homarr"
    echo "   • Image: ghcr.io/homarr/labs/homarr:latest"
    echo "   • Port: $HOMARR_PORT:7575"
    echo "   • Restart: unless-stopped"
    echo "   • Status: $(docker ps --format '{{.Status}}' --filter name=homarr)"
    echo ""
    
    echo -e "${YELLOW}🎯 Next Steps:${NC}"
    echo "   1. Open Homarr in your browser"
    echo "   2. Verify all your apps and configurations are loaded"
    echo "   3. Configure any additional services as needed"
    echo ""
    
    echo -e "${YELLOW}🛠️  Management Commands:${NC}"
    echo "   • View logs: ${CYAN}docker logs homarr${NC}"
    echo "   • Restart: ${CYAN}docker restart homarr${NC}"
    echo "   • Stop: ${CYAN}docker stop homarr${NC}"
    echo "   • Remove: ${CYAN}docker rm -f homarr${NC}"
    echo "   • Check status: ${CYAN}docker ps | grep homarr${NC}"
    echo ""
    
    echo -e "${GREEN}✅ Installation completed successfully!${NC}"
}

# === Main Installation Function ===
main() {
    echo -e "${WHITE}"
    echo "=========================================="
    echo "    Homarr Automated Installation"
    echo "    Version $SCRIPT_VERSION"
    echo "=========================================="
    echo -e "${NC}"
    
    # System validation
    validate_system
    
    # Interactive configuration
    setup_interactive_config
    
    # Get final confirmation
    echo ""
    read -p "Proceed with installation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Installation cancelled."
        exit 1
    fi
    
    echo ""
    log_info "Starting Homarr installation..."
    
    # Download backup
    local temp_dir
    temp_dir=$(download_backup)
    
    # Create Docker volumes
    create_docker_volumes
    
    # Extract backup
    extract_backup_to_volumes "$temp_dir"
    
    # Deploy container
    deploy_homarr_container
    
    # Verify installation
    verify_installation
    
    # Display success information
    display_success_info
}

# === Script Entry Point ===
# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            HOMARR_PORT="$2"
            shift 2
            ;;
        --version)
            echo "Homarr Installation Script v$SCRIPT_VERSION"
            exit 0
            ;;
        --help)
            echo "Usage: $0 [--port PORT] [--version] [--help]"
            echo ""
            echo "Options:"
            echo "  --port PORT     Set custom port (overrides interactive prompt)"
            echo "  --version       Show script version"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Run main function
main
