#!/bin/bash

# Setup script for systemd user services for port-forwards
# This script sets up persistent port-forwards that auto-restart

set -e

USER=$(whoami)

# Check if running as root
if [ "$USER" = "root" ]; then
    echo "Error: This script should NOT be run as root or with sudo."
    echo "Please run it as your regular user (blessedman776)."
    echo ""
    echo "If you need to enable lingering, run this command separately:"
    echo "  sudo loginctl enable-linger blessedman776"
    exit 1
fi

HOME_DIR=$(eval echo ~$USER)
SYSTEMD_USER_DIR="$HOME_DIR/.config/systemd/user"

echo "Setting up systemd user services for port-forwards..."
echo "User: $USER"
echo "Systemd user directory: $SYSTEMD_USER_DIR"

# Find kubectl path
KUBECTL_PATH=$(which kubectl)
if [ -z "$KUBECTL_PATH" ]; then
    echo "Error: kubectl not found in PATH"
    echo "Please ensure kubectl is installed and in your PATH"
    exit 1
fi

echo "Found kubectl at: $KUBECTL_PATH"

# Create systemd user directory if it doesn't exist
mkdir -p "$SYSTEMD_USER_DIR"

# Create wrapper script for port-forward
WRAPPER_SCRIPT="$HOME/port-forward-wrapper.sh"
if [ ! -f "$WRAPPER_SCRIPT" ]; then
    echo "Creating port-forward wrapper script..."
    cat > "$WRAPPER_SCRIPT" <<'WRAPPER_EOF'
#!/bin/bash
# Wrapper script for kubectl port-forward that waits for services to be ready
NAMESPACE="${1:-default}"
SERVICE="$2"
PORTS="$3"
ADDRESS="${4:-0.0.0.0}"

KUBECTL_PATH=$(which kubectl)

# Wait for service (max 60 seconds)
for i in {1..60}; do
    if [ "$NAMESPACE" = "default" ]; then
        $KUBECTL_PATH get svc "$SERVICE" &>/dev/null && break
    else
        $KUBECTL_PATH get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null && break
    fi
    [ $i -eq 60 ] && exit 1
    sleep 1
done

# Start port-forward
if [ "$NAMESPACE" = "default" ]; then
    exec $KUBECTL_PATH port-forward svc/"$SERVICE" "$PORTS" --address "$ADDRESS"
else
    exec $KUBECTL_PATH port-forward -n "$NAMESPACE" svc/"$SERVICE" "$PORTS" --address "$ADDRESS"
fi
WRAPPER_EOF
    chmod +x "$WRAPPER_SCRIPT"
    echo "Wrapper script created at $WRAPPER_SCRIPT"
fi

# Get KUBECONFIG path
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Warning: KUBECONFIG not found at $KUBECONFIG_PATH"
    echo "Trying default location: $HOME/.kube/config"
    KUBECONFIG_PATH="$HOME/.kube/config"
fi

# Create Streamlit port-forward service
cat > "$SYSTEMD_USER_DIR/streamlit-port-forward.service" <<EOF
[Unit]
Description=Kubectl Port Forward for Streamlit Service
After=network.target

[Service]
Type=simple
Environment="KUBECONFIG=$KUBECONFIG_PATH"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
ExecStart=$WRAPPER_SCRIPT default streamlit-service 8501:80 0.0.0.0
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# Create Kibana port-forward service
cat > "$SYSTEMD_USER_DIR/kibana-port-forward.service" <<EOF
[Unit]
Description=Kubectl Port Forward for Kibana Service
After=network.target

[Service]
Type=simple
Environment="KUBECONFIG=$KUBECONFIG_PATH"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
ExecStart=$WRAPPER_SCRIPT logging kibana 5601:5601 0.0.0.0
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

echo "Service files created successfully!"

# Reload systemd
echo "Reloading systemd daemon..."
systemctl --user daemon-reload

# Enable lingering (keeps services running after logout)
echo "Enabling user lingering..."
if sudo loginctl enable-linger "$USER" 2>/dev/null; then
    echo "User lingering enabled successfully."
else
    echo "Warning: Could not enable lingering automatically."
    echo "You may need to run manually: sudo loginctl enable-linger $USER"
    echo "Continuing with setup anyway..."
fi

# Stop any existing port-forwards
echo "Stopping any existing port-forwards..."
systemctl --user stop streamlit-port-forward.service 2>/dev/null || true
systemctl --user stop kibana-port-forward.service 2>/dev/null || true

# Kill any existing kubectl port-forward processes
pkill -f "kubectl port-forward svc/streamlit-service" 2>/dev/null || true
pkill -f "kubectl port-forward -n logging svc/kibana" 2>/dev/null || true

sleep 2

# Enable and start services
echo "Enabling services to start on boot..."
systemctl --user enable streamlit-port-forward.service
systemctl --user enable kibana-port-forward.service

echo "Starting services..."
systemctl --user start streamlit-port-forward.service
systemctl --user start kibana-port-forward.service

sleep 3

# Check status
echo ""
echo "=== Service Status ==="
systemctl --user status streamlit-port-forward.service --no-pager -l || true
echo ""
systemctl --user status kibana-port-forward.service --no-pager -l || true

echo ""
echo "=== Setup Complete ==="
echo "Services are now running and will auto-restart on failure."
echo "They will also start automatically on system boot."
echo ""
echo "Useful commands:"
echo "  Check status:  systemctl --user status streamlit-port-forward.service"
echo "  View logs:     journalctl --user -u streamlit-port-forward.service -f"
echo "  Restart:       systemctl --user restart streamlit-port-forward.service"
echo "  Stop:          systemctl --user stop streamlit-port-forward.service"

