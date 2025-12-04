#!/bin/bash

# Tmux-based port-forwarding setup with HTTPS support
# This script sets up persistent port-forwards using tmux sessions

set -e

echo "=== Tmux Port-Forward Setup with HTTPS ==="
echo ""

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "Installing tmux..."
    sudo apt-get update
    sudo apt-get install -y tmux
fi

# Check if kubectl is accessible, wait for Minikube if needed
echo "Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "Kubernetes cluster not accessible. Checking Minikube status..."
    
    if ! command -v minikube &> /dev/null; then
        echo "Error: minikube not found. Please install Minikube first."
        exit 1
    fi
    
    MINIKUBE_STATUS=$(minikube status 2>/dev/null | head -1)
    if echo "$MINIKUBE_STATUS" | grep -q "Stopped\|not found"; then
        echo "Minikube is not running. Starting Minikube..."
        minikube start
        if [ $? -ne 0 ]; then
            echo "Warning: Minikube start had some issues, but continuing..."
        fi
    else
        echo "Minikube appears to be starting. Waiting for it to be ready..."
    fi
    
    # Wait for cluster to be ready (max 2 minutes)
    echo "Waiting for Kubernetes cluster to be ready..."
    for i in {1..120}; do
        if kubectl cluster-info &>/dev/null 2>&1; then
            echo "✓ Kubernetes cluster is ready"
            break
        fi
        if [ $i -eq 120 ]; then
            echo "Error: Kubernetes cluster not ready after 2 minutes"
            echo "Please check Minikube status: minikube status"
            exit 1
        fi
        sleep 1
        if [ $((i % 10)) -eq 0 ]; then
            echo "  Still waiting... ($i/120 seconds)"
        fi
    done
else
    echo "✓ Kubernetes cluster is accessible"
fi

# Check for existing services and warn
echo "Checking for existing services..."
EXISTING_SERVICES=0

if systemctl --user is-active streamlit-port-forward.service &>/dev/null || \
   systemctl --user is-active kibana-port-forward.service &>/dev/null; then
    echo "⚠ Warning: systemd services are running"
    echo "  Run './stop-existing-services.sh' first to avoid conflicts"
    EXISTING_SERVICES=1
fi

if tmux has-session -t streamlit-port-forward 2>/dev/null || \
   tmux has-session -t kibana-port-forward 2>/dev/null; then
    echo "⚠ Warning: Existing tmux sessions found"
    EXISTING_SERVICES=1
fi

if pgrep -f "kubectl port-forward" > /dev/null; then
    echo "⚠ Warning: kubectl port-forward processes are running"
    EXISTING_SERVICES=1
fi

if [ $EXISTING_SERVICES -eq 1 ]; then
    echo ""
    read -p "Stop existing services and continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping existing services..."
        ./stop-existing-services.sh 2>/dev/null || {
            # Manual cleanup if script doesn't exist
            systemctl --user stop streamlit-port-forward.service 2>/dev/null || true
            systemctl --user stop kibana-port-forward.service 2>/dev/null || true
            tmux kill-session -t streamlit-port-forward 2>/dev/null || true
            tmux kill-session -t kibana-port-forward 2>/dev/null || true
            pkill -f "kubectl port-forward" 2>/dev/null || true
        }
        sleep 2
    else
        echo "Aborting. Please stop existing services first."
        exit 1
    fi
fi

# Kill any remaining tmux sessions
tmux kill-session -t streamlit-port-forward 2>/dev/null || true
tmux kill-session -t kibana-port-forward 2>/dev/null || true
tmux kill-session -t nginx-proxy 2>/dev/null || true

# Wait a moment
sleep 2

# Create Streamlit port-forward session
echo "Setting up Streamlit port-forward (HTTP on 8501)..."
tmux new-session -d -s streamlit-port-forward \
    "kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0"

# Create Kibana port-forward session
echo "Setting up Kibana port-forward (HTTP on 5601)..."
tmux new-session -d -s kibana-port-forward \
    "kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0"

# Wait for port-forwards to establish and verify
echo "Waiting for port-forwards to establish..."
sleep 5

# Verify port-forwards are working
for i in {1..30}; do
    if ss -tlnp 2>/dev/null | grep -q ":8501 " || netstat -tlnp 2>/dev/null | grep -q ":8501 "; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Warning: Port 8501 not listening after 30 seconds"
    fi
    sleep 1
done

# Check if port-forwards are running
if tmux has-session -t streamlit-port-forward 2>/dev/null; then
    echo "✓ Streamlit port-forward session created"
else
    echo "✗ Failed to create Streamlit port-forward session"
fi

if tmux has-session -t kibana-port-forward 2>/dev/null; then
    echo "✓ Kibana port-forward session created"
else
    echo "✗ Failed to create Kibana port-forward session"
fi

echo ""
echo "=== Setting up HTTPS Reverse Proxy with Caddy ==="
echo ""

# Check if Caddy is installed
if ! command -v caddy &> /dev/null; then
    echo "Installing Caddy..."
    sudo apt-get update
    sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
    
    # Add Caddy repository
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null || {
        echo "Installing GPG key..."
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    }
    
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt-get update
    sudo apt-get install -y caddy
    
    echo "✓ Caddy installed"
else
    echo "✓ Caddy is already installed"
fi

# Stop any existing Caddy
sudo systemctl stop caddy 2>/dev/null || true
sudo systemctl stop caddy-https-proxy 2>/dev/null || true
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
sudo sed -i "s|\$CADDY_DIR|$CADDY_DIR|g" /etc/systemd/system/caddy-https-proxy.service
sudo sed -i "s|$HOME|$HOME|g" /etc/systemd/system/caddy-https-proxy.service

# Reload systemd
sudo systemctl daemon-reload

# Start Caddy
echo "Starting Caddy..."
sudo systemctl start caddy-https-proxy.service
sudo systemctl enable caddy-https-proxy.service

sleep 3

sleep 2

# Verify all sessions
echo ""
echo "=== Verification ==="
echo ""

if tmux has-session -t streamlit-port-forward 2>/dev/null; then
    echo "✓ Streamlit port-forward: Running"
else
    echo "✗ Streamlit port-forward: Not running"
fi

if tmux has-session -t kibana-port-forward 2>/dev/null; then
    echo "✓ Kibana port-forward: Running"
else
    echo "✗ Kibana port-forward: Not running"
fi

if sudo systemctl is-active caddy-https-proxy.service &>/dev/null; then
    echo "✓ Caddy HTTPS proxy: Running"
else
    echo "✗ Caddy HTTPS proxy: Not running"
    echo "  Check status: sudo systemctl status caddy-https-proxy.service"
    echo "  Check logs: sudo journalctl -u caddy-https-proxy.service -n 20"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Access your services via HTTPS:"
echo "  Streamlit: https://34.9.116.136/"
echo "  Kibana:    https://34.9.116.136:8443/"
echo ""
echo "Note: You'll see a security warning because we're using self-signed certificates."
echo "This is normal for testing. Click 'Advanced' and 'Proceed' to continue."
echo ""
echo "Tmux session management:"
echo "  List sessions:    tmux ls"
echo "  Attach to session: tmux attach -t streamlit-port-forward"
echo "  Detach:           Press Ctrl+B then D"
echo "  Kill session:     tmux kill-session -t streamlit-port-forward"
echo ""
echo "Caddy management:"
echo "  Status:  sudo systemctl status caddy-https-proxy.service"
echo "  Restart: sudo systemctl restart caddy-https-proxy.service"
echo "  Stop:    sudo systemctl stop caddy-https-proxy.service"
echo "  Logs:    sudo journalctl -u caddy-https-proxy.service -f"
echo ""

