#!/bin/bash

# Setup Caddy as HTTPS reverse proxy (simpler alternative to nginx)
# Caddy automatically handles HTTPS with Let's Encrypt or self-signed certs

set -e

echo "=== Setting up Caddy HTTPS Reverse Proxy ==="
echo ""

# Check if Caddy is installed
if ! command -v caddy &> /dev/null; then
    echo "Installing Caddy..."
    
    # Install Caddy
    sudo apt-get update
    sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt-get update
    sudo apt-get install -y caddy
    
    echo "✓ Caddy installed"
else
    echo "✓ Caddy is already installed"
fi

# Stop any existing Caddy
sudo systemctl stop caddy 2>/dev/null || true
pkill caddy 2>/dev/null || true
sleep 2

# Create Caddy configuration directory
CADDY_DIR="$HOME/caddy-https-proxy"
mkdir -p "$CADDY_DIR"

# Create Caddyfile
cat > "$CADDY_DIR/Caddyfile" <<'CADDY_EOF'
# Streamlit HTTPS
:443 {
    reverse_proxy localhost:8501 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Use self-signed certificate for testing
    tls self_signed
}

# Kibana HTTPS
:8443 {
    reverse_proxy localhost:5601 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Use self-signed certificate for testing
    tls self_signed
}

# HTTP to HTTPS redirect
:80 {
    redir https://{host}{uri} permanent
}
CADDY_EOF

echo "✓ Caddyfile created at $CADDY_DIR/Caddyfile"

# Create systemd service for Caddy
sudo tee /etc/systemd/system/caddy-https-proxy.service > /dev/null <<SERVICE_EOF
[Unit]
Description=Caddy HTTPS Reverse Proxy
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/caddy run --config $CADDY_DIR/Caddyfile
ExecReload=/usr/bin/caddy reload --config $CADDY_DIR/Caddyfile --force
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Replace home directory in service file
sudo sed -i "s|$CADDY_DIR|$CADDY_DIR|g" /etc/systemd/system/caddy-https-proxy.service

# Reload systemd
sudo systemctl daemon-reload

# Start Caddy
echo "Starting Caddy..."
sudo systemctl start caddy-https-proxy.service
sudo systemctl enable caddy-https-proxy.service

sleep 3

# Check status
if sudo systemctl is-active caddy-https-proxy.service &>/dev/null; then
    echo "✓ Caddy started successfully"
    echo ""
    echo "HTTPS services are now accessible:"
    echo "  Streamlit: https://34.9.116.136/"
    echo "  Kibana:    https://34.9.116.136:8443/"
    echo ""
    echo "Note: Using self-signed certificates. You'll see a security warning."
    echo ""
    echo "Manage Caddy:"
    echo "  Status:  sudo systemctl status caddy-https-proxy.service"
    echo "  Restart: sudo systemctl restart caddy-https-proxy.service"
    echo "  Stop:    sudo systemctl stop caddy-https-proxy.service"
    echo "  Logs:    sudo journalctl -u caddy-https-proxy.service -f"
else
    echo "✗ Failed to start Caddy"
    echo "Check logs: sudo journalctl -u caddy-https-proxy.service -n 20"
    exit 1
fi

