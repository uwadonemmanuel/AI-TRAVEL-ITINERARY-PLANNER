#!/bin/bash

# Verification script for port-forward services
# Run this on your VM to diagnose connection issues

echo "=== Port-Forward Verification Script ==="
echo ""

# Check if services are running
echo "1. Checking service status..."
systemctl --user is-active streamlit-port-forward.service && echo "  ✓ Streamlit service: ACTIVE" || echo "  ✗ Streamlit service: INACTIVE"
systemctl --user is-active kibana-port-forward.service && echo "  ✓ Kibana service: ACTIVE" || echo "  ✗ Kibana service: INACTIVE"
echo ""

# Check if ports are listening
echo "2. Checking if ports are listening..."
if command -v ss &> /dev/null; then
    LISTENING=$(ss -tlnp 2>/dev/null | grep -E "8501|5601")
    if [ -n "$LISTENING" ]; then
        echo "  Listening ports found:"
        echo "$LISTENING" | sed 's/^/  /'
    else
        echo "  ✗ No processes listening on ports 8501 or 5601"
    fi
elif command -v netstat &> /dev/null; then
    LISTENING=$(netstat -tlnp 2>/dev/null | grep -E "8501|5601")
    if [ -n "$LISTENING" ]; then
        echo "  Listening ports found:"
        echo "$LISTENING" | sed 's/^/  /'
    else
        echo "  ✗ No processes listening on ports 8501 or 5601"
    fi
else
    echo "  ⚠ Cannot check (ss and netstat not available)"
fi
echo ""

# Check kubectl port-forward processes
echo "3. Checking kubectl port-forward processes..."
KUBECTL_PROCESSES=$(ps aux | grep "kubectl port-forward" | grep -v grep)
if [ -n "$KUBECTL_PROCESSES" ]; then
    echo "  Active kubectl port-forward processes:"
    echo "$KUBECTL_PROCESSES" | sed 's/^/  /'
else
    echo "  ✗ No kubectl port-forward processes found"
fi
echo ""

# Test local connectivity
echo "4. Testing local connectivity..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8501 --max-time 5 | grep -q "200\|302\|301"; then
    echo "  ✓ Streamlit (localhost:8501): ACCESSIBLE"
else
    echo "  ✗ Streamlit (localhost:8501): NOT ACCESSIBLE"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost:5601 --max-time 5 | grep -q "200\|302\|301"; then
    echo "  ✓ Kibana (localhost:5601): ACCESSIBLE"
else
    echo "  ✗ Kibana (localhost:5601): NOT ACCESSIBLE"
fi
echo ""

# Check service logs for errors
echo "5. Recent service logs (last 5 lines)..."
echo "  Streamlit service:"
journalctl --user -u streamlit-port-forward.service -n 5 --no-pager 2>/dev/null | tail -3 | sed 's/^/    /' || echo "    No logs available"
echo ""
echo "  Kibana service:"
journalctl --user -u kibana-port-forward.service -n 5 --no-pager 2>/dev/null | tail -3 | sed 's/^/    /' || echo "    No logs available"
echo ""

# Check if listening on 0.0.0.0 or 127.0.0.1
echo "6. Checking bind address..."
if command -v ss &> /dev/null; then
    BIND_8501=$(ss -tlnp 2>/dev/null | grep ":8501" | head -1)
    BIND_5601=$(ss -tlnp 2>/dev/null | grep ":5601" | head -1)
    
    if echo "$BIND_8501" | grep -q "0.0.0.0:8501"; then
        echo "  ✓ Port 8501: Listening on 0.0.0.0 (accessible from external IP)"
    elif echo "$BIND_8501" | grep -q "127.0.0.1:8501"; then
        echo "  ✗ Port 8501: Only listening on 127.0.0.1 (NOT accessible from external IP)"
    else
        echo "  ⚠ Port 8501: Status unknown"
    fi
    
    if echo "$BIND_5601" | grep -q "0.0.0.0:5601"; then
        echo "  ✓ Port 5601: Listening on 0.0.0.0 (accessible from external IP)"
    elif echo "$BIND_5601" | grep -q "127.0.0.1:5601"; then
        echo "  ✗ Port 5601: Only listening on 127.0.0.1 (NOT accessible from external IP)"
    else
        echo "  ⚠ Port 5601: Status unknown"
    fi
fi
echo ""

# Get external IP
echo "7. Network information..."
EXTERNAL_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "Unable to determine")
echo "  External IP: $EXTERNAL_IP"
echo ""

# Check firewall (if ufw is installed)
if command -v ufw &> /dev/null; then
    echo "8. UFW Firewall status..."
    ufw status | head -5 | sed 's/^/  /'
    echo ""
fi

echo "=== Verification Complete ==="
echo ""
echo "If ports are only listening on 127.0.0.1, the --address 0.0.0.0 flag may not be working."
echo "If ports are not listening at all, check service logs for errors."
echo "If localhost works but external IP doesn't, check firewall rules."


