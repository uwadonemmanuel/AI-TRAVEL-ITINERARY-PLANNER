#!/bin/bash

# Setup script for systemd user services for port-forwards
# This script sets up persistent port-forwards that auto-restart

set -e

USER=$(whoami)
HOME_DIR=$(eval echo ~$USER)
SYSTEMD_USER_DIR="$HOME_DIR/.config/systemd/user"

echo "Setting up systemd user services for port-forwards..."
echo "User: $USER"
echo "Systemd user directory: $SYSTEMD_USER_DIR"

# Create systemd user directory if it doesn't exist
mkdir -p "$SYSTEMD_USER_DIR"

# Create Streamlit port-forward service
cat > "$SYSTEMD_USER_DIR/streamlit-port-forward.service" <<EOF
[Unit]
Description=Kubectl Port Forward for Streamlit Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0
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
ExecStart=/usr/bin/kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0
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
loginctl enable-linger "$USER"

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

