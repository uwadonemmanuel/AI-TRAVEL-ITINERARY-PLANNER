#!/bin/bash

# Script to stop all existing port-forward services before setting up tmux
# This prevents port conflicts

echo "=== Stopping Existing Port-Forward Services ==="
echo ""

# Stop systemd services
echo "1. Stopping systemd services..."
if systemctl --user is-active streamlit-port-forward.service &>/dev/null; then
    systemctl --user stop streamlit-port-forward.service
    echo "  ✓ Stopped streamlit-port-forward.service"
else
    echo "  ⚠ streamlit-port-forward.service not running"
fi

if systemctl --user is-active kibana-port-forward.service &>/dev/null; then
    systemctl --user stop kibana-port-forward.service
    echo "  ✓ Stopped kibana-port-forward.service"
else
    echo "  ⚠ kibana-port-forward.service not running"
fi

# Disable systemd services (optional - comment out if you want to keep them)
# systemctl --user disable streamlit-port-forward.service 2>/dev/null
# systemctl --user disable kibana-port-forward.service 2>/dev/null

echo ""

# Stop tmux sessions (if any exist)
echo "2. Stopping existing tmux sessions..."
if tmux has-session -t streamlit-port-forward 2>/dev/null; then
    tmux kill-session -t streamlit-port-forward
    echo "  ✓ Stopped streamlit-port-forward tmux session"
else
    echo "  ⚠ No streamlit-port-forward tmux session"
fi

if tmux has-session -t kibana-port-forward 2>/dev/null; then
    tmux kill-session -t kibana-port-forward
    echo "  ✓ Stopped kibana-port-forward tmux session"
else
    echo "  ⚠ No kibana-port-forward tmux session"
fi

if tmux has-session -t nginx-proxy 2>/dev/null; then
    tmux kill-session -t nginx-proxy
    echo "  ✓ Stopped nginx-proxy tmux session"
else
    echo "  ⚠ No nginx-proxy tmux session"
fi

echo ""

# Kill any kubectl port-forward processes
echo "3. Killing kubectl port-forward processes..."
pkill -f "kubectl port-forward svc/streamlit-service" 2>/dev/null && echo "  ✓ Killed Streamlit port-forward processes" || echo "  ⚠ No Streamlit port-forward processes"
pkill -f "kubectl port-forward -n logging svc/kibana" 2>/dev/null && echo "  ✓ Killed Kibana port-forward processes" || echo "  ⚠ No Kibana port-forward processes"
pkill -f "kubectl port-forward.*8501" 2>/dev/null && echo "  ✓ Killed processes on port 8501" || echo "  ⚠ No processes on port 8501"
pkill -f "kubectl port-forward.*5601" 2>/dev/null && echo "  ✓ Killed processes on port 5601" || echo "  ⚠ No processes on port 5601"

echo ""

# Stop nginx if running
echo "4. Stopping nginx..."
if pgrep nginx > /dev/null; then
    sudo nginx -s quit 2>/dev/null && echo "  ✓ Stopped nginx" || {
        echo "  ⚠ Could not stop nginx gracefully, trying kill..."
        sudo pkill nginx && echo "  ✓ Killed nginx processes" || echo "  ⚠ No nginx processes found"
    }
else
    echo "  ⚠ Nginx not running"
fi

echo ""

# Check for processes using ports
echo "5. Checking for processes using ports 80, 443, 8443, 8501, 5601..."
PORTS_IN_USE=0

for port in 80 443 8443 8501 5601; do
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "  ⚠ Port $port is in use:"
        ss -tlnp 2>/dev/null | grep ":$port " | sed 's/^/    /'
        PORTS_IN_USE=1
    else
        echo "  ✓ Port $port is free"
    fi
done

echo ""

# Wait a moment for processes to fully stop
sleep 2

# Final check
echo "6. Final status check..."
if systemctl --user is-active streamlit-port-forward.service &>/dev/null || \
   systemctl --user is-active kibana-port-forward.service &>/dev/null || \
   tmux has-session -t streamlit-port-forward 2>/dev/null || \
   tmux has-session -t kibana-port-forward 2>/dev/null || \
   pgrep -f "kubectl port-forward" > /dev/null; then
    echo "  ⚠ Some services may still be running"
    echo "  You may need to manually stop them"
else
    echo "  ✓ All port-forward services stopped"
fi

echo ""
echo "=== Cleanup Complete ==="
echo ""
if [ $PORTS_IN_USE -eq 1 ]; then
    echo "⚠ Warning: Some ports are still in use."
    echo "You may need to manually stop those processes before running tmux setup."
    echo ""
    echo "To see what's using the ports:"
    echo "  sudo lsof -i :80 -i :443 -i :8443 -i :8501 -i :5601"
else
    echo "✓ All ports are free. You can now run:"
    echo "  ./tmux-port-forward-setup.sh"
fi
echo ""

