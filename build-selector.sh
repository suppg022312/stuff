#!/bin/bash
# Build Selector
clear
echo "========================================"
echo "      Ubuntu Docker Build Selector      "
echo "========================================"
echo "1) Personal Setup (Basic tools)"
echo "2) Full Stack Setup (Docker, Node, Python, Tailscale, AI Tools)"
echo "3) Custom Setup"
echo "4) Show Container Status"
echo "5) Exit"
echo "========================================"
read -p "Please choose an option [1-5]: " choice

case $choice in
    1)
        echo "Configuring Personal environment..."
        ;;
    2)
        echo "Full Stack Setup is already running/installed via cloud-init."
        echo "Checking services..."
        docker ps
        ;;
    3)
        echo "Configuring Custom environment..."
        ;;
    4)
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    5)
        exit 0
        ;;
    *)
        echo "Invalid option."
        ;;
esac
