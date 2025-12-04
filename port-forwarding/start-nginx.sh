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

# Check if nginx is already running
if pgrep nginx > /dev/null; then
    echo "Nginx is already running. Stopping it first..."
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

# Start nginx
echo "Starting nginx..."
sudo nginx -c "$NGINX_DIR/nginx.conf"

if [ $? -eq 0 ]; then
    echo "✓ Nginx started successfully"
    echo ""
    echo "HTTPS services should now be accessible:"
    echo "  Streamlit: https://34.9.116.136/"
    echo "  Kibana:    https://34.9.116.136:8443/"
else
    echo "✗ Failed to start nginx"
    exit 1
fi

