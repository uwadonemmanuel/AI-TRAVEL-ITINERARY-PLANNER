#!/bin/bash

# Check detailed error logs for port-forward services

echo "=== Detailed Error Analysis ==="
echo ""

echo "1. Full Streamlit service logs (last 20 lines):"
echo "----------------------------------------"
journalctl --user -u streamlit-port-forward.service -n 20 --no-pager 2>/dev/null
echo ""

echo "2. Full Kibana service logs (last 20 lines):"
echo "----------------------------------------"
journalctl --user -u kibana-port-forward.service -n 20 --no-pager 2>/dev/null
echo ""

echo "3. Testing kubectl connectivity:"
echo "----------------------------------------"
kubectl cluster-info 2>&1 | head -3
echo ""

echo "4. Checking if services exist:"
echo "----------------------------------------"
kubectl get svc streamlit-service 2>&1
echo ""
kubectl get svc -n logging kibana 2>&1
echo ""

echo "5. Testing manual port-forward (will timeout after 5 seconds):"
echo "----------------------------------------"
echo "Testing Streamlit port-forward manually..."
timeout 5 kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0 2>&1 || echo "Manual test completed or failed"
echo ""

echo "6. Checking kubectl context:"
echo "----------------------------------------"
kubectl config current-context 2>&1
echo ""

echo "7. Checking if pods are running:"
echo "----------------------------------------"
kubectl get pods 2>&1 | head -5
echo ""
kubectl get pods -n logging 2>&1 | head -5
echo ""


