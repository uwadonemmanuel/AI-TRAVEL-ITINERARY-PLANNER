#!/bin/bash

# Fix Caddy service conflicts and ensure our custom service runs

echo "=== Fixing Caddy Service Configuration ==="
echo ""

# Get user home directory
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
else
    USER_HOME="$HOME"
fi

CADDY_DIR="$USER_HOME/caddy-https-proxy"

# Stop and disable the default Caddy service (to avoid conflicts)
echo "1. Stopping default Caddy service..."
sudo systemctl stop caddy.service 2>/dev/null || true
sudo systemctl disable caddy.service 2>/dev/null || true
echo "  ✓ Default Caddy service stopped and disabled"

# Ensure our custom service exists
if [ ! -f "/etc/systemd/system/caddy-https-proxy.service" ]; then
    echo "2. Creating custom Caddy service..."
    
    # Create Caddyfile if it doesn't exist
    if [ ! -f "$CADDY_DIR/Caddyfile" ]; then
        echo "  Creating Caddyfile..."
        mkdir -p "$CADDY_DIR"
        cat > "$CADDY_DIR/Caddyfile" <<'CADDY_EOF'
# Streamlit HTTPS
:443 {
    reverse_proxy localhost:8501 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
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
    tls self_signed
}

# HTTP to HTTPS redirect
:80 {
    redir https://{host}{uri} permanent
}
CADDY_EOF
        echo "  ✓ Caddyfile created"
    fi
    
    # Create systemd service
    sudo tee /etc/systemd/system/caddy-https-proxy.service > /dev/null <<SERVICE_EOF
[Unit]
Description=Caddy HTTPS Reverse Proxy for Port-Forwards
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
    sudo sed -i "s|\\\$CADDY_DIR|$CADDY_DIR|g" /etc/systemd/system/caddy-https-proxy.service
    
    echo "  ✓ Custom Caddy service created"
else
    echo "2. Custom Caddy service already exists"
fi

# Reload systemd
echo "3. Reloading systemd..."
sudo systemctl daemon-reload
echo "  ✓ Systemd reloaded"

# Kill any existing Caddy processes
echo "4. Stopping any existing Caddy processes..."
sudo pkill caddy 2>/dev/null || true
sleep 2

# Start our custom service
echo "5. Starting custom Caddy service..."
sudo systemctl start caddy-https-proxy.service
sudo systemctl enable caddy-https-proxy.service

sleep 3

# Check status
echo ""
echo "6. Service status:"
if sudo systemctl is-active caddy-https-proxy.service &>/dev/null; then
    echo "  ✓ caddy-https-proxy.service: Running"
    sudo systemctl status caddy-https-proxy.service --no-pager -l | head -10
else
    echo "  ✗ caddy-https-proxy.service: Not running"
    echo "  Checking logs..."
    sudo journalctl -u caddy-https-proxy.service -n 20 --no-pager
fi

echo ""
echo "=== Summary ==="
echo "Default Caddy service: Disabled (to avoid conflicts)"
echo "Custom Caddy service: caddy-https-proxy.service"
echo ""
echo "To manage:"
echo "  sudo systemctl status caddy-https-proxy.service"
echo "  sudo systemctl restart caddy-https-proxy.service"
echo "  sudo journalctl -u caddy-https-proxy.service -f"

