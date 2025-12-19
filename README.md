# Homarr Automated Installation

This repository provides an automated installation system for [Homarr](https://homarr.dev/), a sleek, modern dashboard that puts all of your apps and services at your fingertips.

## 🚀 Quick Start

### One-Liner Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/suppg022312/stuff/main/setup_homarr.sh | bash
```

### Alternative Methods

```bash
# Download and execute
wget https://raw.githubusercontent.com/suppg022312/stuff/main/setup_homarr.sh
chmod +x setup_homarr.sh
./setup_homarr.sh

# With custom port
curl -fsSL https://raw.githubusercontent.com/suppg022312/stuff/main/setup_homarr.sh | bash -s -- --port 8575
```

## 📋 Requirements

- **Ubuntu** (18.04+ recommended)
- **Docker** installed and running
- **Git** installed
- **curl** installed
- **1GB+** available disk space

## 🛠️ Installation Process

The automated script performs the following steps:

1. **System Validation** - Checks Docker, tools, permissions, disk space
2. **Interactive Configuration** - Port selection, backup source choice
3. **Docker Setup** - Creates 4 named volumes for persistence
4. **Backup Restoration** - Downloads and extracts Homarr configuration
5. **Container Deployment** - Deploys Homarr with all settings
6. **Verification & Success** - Validates installation and provides info

## 🎯 What You Get

- **Fully Configured Homarr Dashboard** with your existing apps, boards, settings
- **Docker Container** with automatic restart and persistent storage
- **Access Methods**: Local (`http://localhost:7575`) and Network access

## 📁 Repository Structure

```
stuff/
├── setup_homarr.sh          # Main automated installation script
├── HostSetup.md             # Comprehensive setup documentation
├── homarr_backup.tar.gz      # Complete Homarr configuration backup
└── README.md                # This file
```

## 🔧 Management Commands

```bash
# View container status
docker ps | grep homarr

# View logs
docker logs homarr

# Restart Homarr
docker restart homarr

# Stop Homarr
docker stop homarr

# Remove Homarr (keeps data)
docker rm -f homarr
```

## 🔍 Troubleshooting

- **Port Already in Use**: Use `--port` option or choose different port
- **Docker Not Running**: Start with `sudo systemctl start docker`
- **Container Won't Start**: Check logs with `docker logs homarr --tail=50`
- **Web Interface Not Accessible**: Wait 30-60 seconds for full startup

## 📚 Additional Resources

- [Homarr Official Documentation](https://homarr.dev/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Repository Issues](https://github.com/suppg022312/stuff/issues)

---

**Installation Time**: ~5-10 minutes  
**Total Space Used**: ~2.1GB  
**Default Memory Usage**: ~50-200MB
