#!/bin/bash

# Start Caddy HTTPS proxy service

echo "=== Starting Caddy HTTPS Proxy Service ==="
echo ""

# Get user home directory
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
else
    USER_HOME="$HOME"
fi

CADDY_DIR="$USER_HOME/caddy-https-proxy"

# Verify Caddyfile exists
if [ ! -f "$CADDY_DIR/Caddyfile" ]; then
    echo "Error: Caddyfile not found at $CADDY_DIR/Caddyfile"
    echo "Please run ./tmux-port-forward-setup.sh first"
    exit 1
fi

echo "Using Caddyfile: $CADDY_DIR/Caddyfile"
echo ""

# Verify service file exists
if [ ! -f "/etc/systemd/system/caddy-https-proxy.service" ]; then
    echo "Error: Service file not found"
    echo "Please run ./fix-caddy-service.sh first"
    exit 1
fi

# Test Caddyfile syntax
echo "Testing Caddyfile syntax..."
if sudo caddy validate --config "$CADDY_DIR/Caddyfile" 2>&1; then
    echo "✓ Caddyfile is valid"
else
    echo "✗ Caddyfile validation failed"
    exit 1
fi

# Enable and start service
echo "Enabling service..."
sudo systemctl enable caddy-https-proxy.service

echo "Starting service..."
sudo systemctl start caddy-https-proxy.service

sleep 3

# Check status
if sudo systemctl is-active caddy-https-proxy.service &>/dev/null; then
    echo "✓ Caddy HTTPS proxy service started successfully"
    echo ""
    echo "HTTPS services are now accessible:"
    echo "  Streamlit: https://34.9.116.136/"
    echo "  Kibana:    https://34.9.116.136:8443/"
    echo ""
    echo "Service status:"
    sudo systemctl status caddy-https-proxy.service --no-pager -l | head -15
else
    echo "✗ Failed to start Caddy service"
    echo ""
    echo "Checking logs..."
    sudo journalctl -u caddy-https-proxy.service -n 30 --no-pager
    exit 1
fi

