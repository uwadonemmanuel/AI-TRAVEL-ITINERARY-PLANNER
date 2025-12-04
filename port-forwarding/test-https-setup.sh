#!/bin/bash

# Test script for HTTPS port-forwarding setup

echo "=== HTTPS Port-Forward Test Suite ==="
echo ""

EXTERNAL_IP="34.9.116.136"
PASSED=0
FAILED=0

# Test function
test_connection() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    echo -n "Testing $name... "
    
    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "$url" --max-time 10 2>/dev/null)
    
    if echo "$HTTP_CODE" | grep -q "$expected_code"; then
        echo "✓ PASS (HTTP $HTTP_CODE)"
        ((PASSED++))
        return 0
    else
        echo "✗ FAIL (HTTP $HTTP_CODE, expected $expected_code)"
        ((FAILED++))
        return 1
    fi
}

# Test 1: Check tmux sessions
echo "1. Checking tmux sessions..."
if tmux has-session -t streamlit-port-forward 2>/dev/null; then
    echo "  ✓ Streamlit port-forward session: Running"
    ((PASSED++))
else
    echo "  ✗ Streamlit port-forward session: Not running"
    ((FAILED++))
fi

if tmux has-session -t kibana-port-forward 2>/dev/null; then
    echo "  ✓ Kibana port-forward session: Running"
    ((PASSED++))
else
    echo "  ✗ Kibana port-forward session: Not running"
    ((FAILED++))
fi

if tmux has-session -t nginx-proxy 2>/dev/null; then
    echo "  ✓ Nginx proxy session: Running"
    ((PASSED++))
else
    echo "  ⚠ Nginx proxy session: Not running (may be running as systemd service)"
fi
echo ""

# Test 2: Check if ports are listening locally
echo "2. Checking local port listeners..."
if ss -tlnp 2>/dev/null | grep -q ":8501"; then
    echo "  ✓ Port 8501: Listening"
    ((PASSED++))
else
    echo "  ✗ Port 8501: Not listening"
    ((FAILED++))
fi

if ss -tlnp 2>/dev/null | grep -q ":5601"; then
    echo "  ✓ Port 5601: Listening"
    ((PASSED++))
else
    echo "  ✗ Port 5601: Not listening"
    ((FAILED++))
fi

if ss -tlnp 2>/dev/null | grep -q ":443"; then
    echo "  ✓ Port 443: Listening (HTTPS)"
    ((PASSED++))
else
    echo "  ✗ Port 443: Not listening"
    ((FAILED++))
fi

if ss -tlnp 2>/dev/null | grep -q ":8443"; then
    echo "  ✓ Port 8443: Listening (HTTPS)"
    ((PASSED++))
else
    echo "  ✗ Port 8443: Not listening"
    ((FAILED++))
fi
echo ""

# Test 3: Test local HTTP connections
echo "3. Testing local HTTP connections..."
test_connection "Streamlit (localhost:8501)" "http://localhost:8501" "200\|302\|301"
test_connection "Kibana (localhost:5601)" "http://localhost:5601" "200\|302\|301"
echo ""

# Test 4: Test local HTTPS connections
echo "4. Testing local HTTPS connections..."
test_connection "Streamlit HTTPS (localhost:443)" "https://localhost/" "200\|302\|301"
test_connection "Kibana HTTPS (localhost:8443)" "https://localhost:8443/" "200\|302\|301"
echo ""

# Test 5: Test HTTP to HTTPS redirect
echo "5. Testing HTTP to HTTPS redirect..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/" --max-time 10 2>/dev/null)
if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "  ✓ HTTP redirect: Working (HTTP $HTTP_CODE)"
    ((PASSED++))
else
    echo "  ✗ HTTP redirect: Not working (HTTP $HTTP_CODE)"
    ((FAILED++))
fi
echo ""

# Test 6: Test external HTTPS (if accessible)
echo "6. Testing external HTTPS connections..."
if curl -k -s -o /dev/null -w "%{http_code}" "https://$EXTERNAL_IP/" --max-time 10 2>/dev/null | grep -q "200\|302\|301"; then
    echo "  ✓ Streamlit HTTPS (external): Accessible"
    ((PASSED++))
else
    echo "  ✗ Streamlit HTTPS (external): Not accessible (check firewall)"
    ((FAILED++))
fi

if curl -k -s -o /dev/null -w "%{http_code}" "https://$EXTERNAL_IP:8443/" --max-time 10 2>/dev/null | grep -q "200\|302\|301"; then
    echo "  ✓ Kibana HTTPS (external): Accessible"
    ((PASSED++))
else
    echo "  ✗ Kibana HTTPS (external): Not accessible (check firewall)"
    ((FAILED++))
fi
echo ""

# Test 7: Check SSL certificates
echo "7. Checking SSL certificates..."
if [ -f "$HOME/nginx-https-proxy/ssl/server.crt" ] && [ -f "$HOME/nginx-https-proxy/ssl/server.key" ]; then
    echo "  ✓ SSL certificates: Found"
    CERT_INFO=$(openssl x509 -in "$HOME/nginx-https-proxy/ssl/server.crt" -noout -subject -dates 2>/dev/null)
    if [ -n "$CERT_INFO" ]; then
        echo "  Certificate details:"
        echo "$CERT_INFO" | sed 's/^/    /'
        ((PASSED++))
    else
        echo "  ⚠ Could not read certificate details"
        ((FAILED++))
    fi
else
    echo "  ✗ SSL certificates: Not found"
    ((FAILED++))
fi
echo ""

# Test 8: Check kubectl connectivity
echo "8. Checking Kubernetes connectivity..."
if kubectl cluster-info &>/dev/null 2>&1; then
    echo "  ✓ Kubernetes cluster: Accessible"
    ((PASSED++))
else
    echo "  ✗ Kubernetes cluster: Not accessible"
    echo "    Run: minikube start"
    ((FAILED++))
fi

if kubectl get svc streamlit-service &>/dev/null 2>&1; then
    echo "  ✓ Streamlit service: Found"
    ((PASSED++))
else
    echo "  ✗ Streamlit service: Not found"
    ((FAILED++))
fi

if kubectl get svc -n logging kibana &>/dev/null 2>&1; then
    echo "  ✓ Kibana service: Found"
    ((PASSED++))
else
    echo "  ✗ Kibana service: Not found"
    ((FAILED++))
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ All tests passed! HTTPS setup is working correctly."
    echo ""
    echo "Access your services:"
    echo "  Streamlit: https://$EXTERNAL_IP/"
    echo "  Kibana:    https://$EXTERNAL_IP:8443/"
    exit 0
else
    echo "✗ Some tests failed. Please review the output above."
    echo ""
    echo "Common fixes:"
    echo "  1. Start services: ./tmux-port-forward-manage.sh start"
    echo "  2. Check Minikube: minikube status"
    echo "  3. Check firewall: sudo ufw status"
    exit 1
fi

