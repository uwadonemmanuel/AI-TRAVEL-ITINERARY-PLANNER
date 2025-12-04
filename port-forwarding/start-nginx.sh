#!/bin/bash

# Script to start nginx with the custom configuration
# This needs to be run with sudo

# Get the actual user's home directory (not root's when using sudo)
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
else
    USER_HOME="$HOME"
fi

NGINX_DIR="$USER_HOME/nginx-https-proxy"

if [ ! -f "$NGINX_DIR/nginx.conf" ]; then
    echo "Error: nginx.conf not found at $NGINX_DIR/nginx.conf"
    echo "Please run ./tmux-port-forward-setup.sh first (as your regular user, not sudo)"
    exit 1
fi

echo "Using nginx config from: $NGINX_DIR/nginx.conf"

# Check if nginx is already running (check both systemd service and direct process)
if systemctl is-active nginx &>/dev/null; then
    echo "Stopping systemd nginx service..."
    sudo systemctl stop nginx
    sleep 2
fi

if pgrep nginx > /dev/null; then
    echo "Stopping existing nginx processes..."
    sudo nginx -s quit 2>/dev/null || sudo pkill nginx
    sleep 2
fi

# Test nginx configuration
echo "Testing nginx configuration..."
if sudo nginx -t -c "$NGINX_DIR/nginx.conf" 2>&1 | grep -q "successful"; then
    echo "✓ Configuration is valid"
else
    echo "✗ Configuration test failed:"
    sudo nginx -t -c "$NGINX_DIR/nginx.conf"
    exit 1
fi

# Start nginx with custom config
echo "Starting nginx with custom configuration..."
sudo nginx -c "$NGINX_DIR/nginx.conf"

sleep 2

# Verify nginx is running
if pgrep nginx > /dev/null; then
    echo "✓ Nginx started successfully"
    echo ""
    echo "HTTPS services should now be accessible:"
    echo "  Streamlit: https://34.9.116.136/"
    echo "  Kibana:    https://34.9.116.136:8443/"
    echo ""
    echo "Note: Nginx is running with custom config, not as systemd service."
    echo "To stop it, use: sudo nginx -s quit"
else
    echo "✗ Failed to start nginx"
    echo "Check error logs: sudo tail -f /var/log/nginx/error.log"
    exit 1
fi

