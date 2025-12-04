#!/bin/bash

# Comprehensive HTTPS diagnostics

echo "=== HTTPS Accessibility Diagnostics ==="
echo ""

EXTERNAL_IP="34.9.116.136"

# 1. Check Caddy service status
echo "1. Caddy Service Status:"
if sudo systemctl is-active caddy-https-proxy.service &>/dev/null; then
    echo "  ✓ Caddy service is running"
    sudo systemctl status caddy-https-proxy.service --no-pager -l | head -10
else
    echo "  ✗ Caddy service is NOT running"
    echo "  Start with: sudo systemctl start caddy-https-proxy.service"
fi
echo ""

# 2. Check Caddy logs
echo "2. Recent Caddy Logs (last 20 lines):"
sudo journalctl -u caddy-https-proxy.service -n 20 --no-pager | tail -15
echo ""

# 3. Check if ports are listening
echo "3. Port Listening Status:"
for port in 80 443 8443 8501 5601; do
    if sudo ss -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "  ✓ Port $port: Listening"
        sudo ss -tlnp 2>/dev/null | grep ":$port " | head -1 | sed 's/^/    /'
    else
        echo "  ✗ Port $port: NOT listening"
    fi
done
echo ""

# 4. Check port-forwards
echo "4. Port-Forward Status:"
if tmux has-session -t streamlit-port-forward 2>/dev/null; then
    echo "  ✓ Streamlit port-forward: Running"
else
    echo "  ✗ Streamlit port-forward: Not running"
fi

if tmux has-session -t kibana-port-forward 2>/dev/null; then
    echo "  ✓ Kibana port-forward: Running"
else
    echo "  ✗ Kibana port-forward: Not running"
fi
echo ""

# 5. Test local connectivity
echo "5. Local Connectivity Tests:"
echo -n "  Streamlit (localhost:8501): "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8501 --max-time 5 | grep -q "200\|302\|301"; then
    echo "✓ Accessible"
else
    echo "✗ NOT accessible"
fi

echo -n "  Kibana (localhost:5601): "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5601 --max-time 5 | grep -q "200\|302\|301"; then
    echo "✓ Accessible"
else
    echo "✗ NOT accessible"
fi

echo -n "  Streamlit HTTPS (localhost:443): "
if curl -k -s -o /dev/null -w "%{http_code}" https://localhost/ --max-time 5 | grep -q "200\|302\|301"; then
    echo "✓ Accessible"
else
    echo "✗ NOT accessible"
fi

echo -n "  Kibana HTTPS (localhost:8443): "
if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443/ --max-time 5 | grep -q "200\|302\|301"; then
    echo "✓ Accessible"
else
    echo "✗ NOT accessible"
fi
echo ""

# 6. Check firewall
echo "6. Firewall Status:"
if command -v ufw &> /dev/null; then
    ufw status | head -5 | sed 's/^/  /'
    echo ""
    echo "  Checking if ports are allowed:"
    for port in 80 443 8443; do
        if ufw status | grep -q "$port"; then
            echo "    Port $port: $(ufw status | grep $port)"
        else
            echo "    Port $port: Not explicitly allowed (may be blocked)"
        fi
    done
else
    echo "  UFW not installed, checking GCP firewall rules..."
    echo "  (You may need to allow ports 80, 443, 8443 in GCP Console)"
fi
echo ""

# 7. Check Minikube/Kubernetes
echo "7. Kubernetes Cluster Status:"
if kubectl cluster-info &>/dev/null 2>&1; then
    echo "  ✓ Kubernetes cluster is accessible"
    kubectl cluster-info 2>&1 | head -1 | sed 's/^/    /'
else
    echo "  ✗ Kubernetes cluster is NOT accessible"
    echo "  This will prevent port-forwards from working"
    echo "  Check: minikube status"
fi
echo ""

# 8. Test external connectivity (if possible)
echo "8. External Connectivity Test:"
echo -n "  Testing https://$EXTERNAL_IP/ ... "
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$EXTERNAL_IP/" --max-time 10 2>&1)
if echo "$HTTP_CODE" | grep -qE "^[0-9]+$"; then
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo "✓ Accessible (HTTP $HTTP_CODE)"
    else
        echo "✗ Got HTTP $HTTP_CODE (may be firewall or connection issue)"
    fi
else
    echo "✗ Connection failed: $HTTP_CODE"
fi

echo -n "  Testing https://$EXTERNAL_IP:8443/ ... "
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$EXTERNAL_IP:8443/" --max-time 10 2>&1)
if echo "$HTTP_CODE" | grep -qE "^[0-9]+$"; then
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo "✓ Accessible (HTTP $HTTP_CODE)"
    else
        echo "✗ Got HTTP $HTTP_CODE (may be firewall or connection issue)"
    fi
else
    echo "✗ Connection failed: $HTTP_CODE"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "If HTTPS is not accessible from browser, check:"
echo "  1. Caddy service is running (sudo systemctl status caddy-https-proxy.service)"
echo "  2. Ports 443 and 8443 are listening (check step 3 above)"
echo "  3. Firewall allows ports 443 and 8443 (GCP Console → Firewall Rules)"
echo "  4. Port-forwards are working (check step 4 above)"
echo "  5. Minikube API server is running (minikube status)"
echo ""

