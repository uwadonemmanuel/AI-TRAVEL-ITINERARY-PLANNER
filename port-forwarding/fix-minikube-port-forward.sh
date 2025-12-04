#!/bin/bash

# Fix port-forward services to work with Minikube
# This script ensures Minikube is running and updates services accordingly

echo "=== Fixing Port-Forward Services for Minikube ==="
echo ""

# Check if Minikube is running
echo "1. Checking Minikube status..."
if minikube status &>/dev/null; then
    echo "  ✓ Minikube is running"
    minikube status
else
    echo "  ✗ Minikube is NOT running"
    echo "  Starting Minikube..."
    minikube start
    if [ $? -ne 0 ]; then
        echo "  ✗ Failed to start Minikube"
        exit 1
    fi
fi
echo ""

# Get Minikube's kubeconfig
echo "2. Setting up kubectl context..."
eval $(minikube docker-env 2>/dev/null) || true
kubectl config use-context minikube
KUBECONFIG_PATH="$HOME/.kube/config"

echo "  KUBECONFIG: $KUBECONFIG_PATH"
echo ""

# Update service files to include Minikube environment
echo "3. Updating service files..."

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
KUBECTL_PATH=$(which kubectl)

# Create a wrapper that ensures Minikube is running
cat > "$HOME/port-forward-minikube-wrapper.sh" <<'WRAPPER_EOF'
#!/bin/bash
# Wrapper that ensures Minikube is running before port-forward

# Wait for Minikube to be ready (max 2 minutes)
for i in {1..120}; do
    if minikube status &>/dev/null && kubectl cluster-info &>/dev/null; then
        break
    fi
    if [ $i -eq 120 ]; then
        echo "Error: Minikube not accessible after 2 minutes"
        exit 1
    fi
    sleep 1
done

# Set Minikube environment
eval $(minikube docker-env 2>/dev/null) || true

# Execute the port-forward command
exec "$@"
WRAPPER_EOF

chmod +x "$HOME/port-forward-minikube-wrapper.sh"

# Update Streamlit service
cat > "$SYSTEMD_USER_DIR/streamlit-port-forward.service" <<EOF
[Unit]
Description=Kubectl Port Forward for Streamlit Service
After=network.target

[Service]
Type=simple
Environment="KUBECONFIG=$KUBECONFIG_PATH"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/usr/local/go/bin"
ExecStart=$HOME/port-forward-minikube-wrapper.sh $KUBECTL_PATH port-forward svc/streamlit-service 8501:80 --address 0.0.0.0
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# Update Kibana service
cat > "$SYSTEMD_USER_DIR/kibana-port-forward.service" <<EOF
[Unit]
Description=Kubectl Port Forward for Kibana Service
After=network.target

[Service]
Type=simple
Environment="KUBECONFIG=$KUBECONFIG_PATH"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/usr/local/go/bin"
ExecStart=$HOME/port-forward-minikube-wrapper.sh $KUBECTL_PATH port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

echo "  ✓ Service files updated"
echo ""

# Reload systemd
echo "4. Reloading systemd..."
systemctl --user daemon-reload
echo "  ✓ Systemd reloaded"
echo ""

# Stop and restart services
echo "5. Restarting services..."
systemctl --user stop streamlit-port-forward.service 2>/dev/null || true
systemctl --user stop kibana-port-forward.service 2>/dev/null || true
sleep 2

systemctl --user start streamlit-port-forward.service
systemctl --user start kibana-port-forward.service

sleep 3

# Check status
echo ""
echo "6. Service status:"
systemctl --user status streamlit-port-forward.service --no-pager -l | head -10
echo ""
systemctl --user status kibana-port-forward.service --no-pager -l | head -10

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Note: Minikube must be running for port-forwards to work."
echo "If Minikube stops, the services will fail until Minikube is restarted."
echo ""
echo "To ensure Minikube starts on boot, you may want to set up a Minikube service as well."


