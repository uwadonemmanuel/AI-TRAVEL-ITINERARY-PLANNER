#!/bin/bash

# Get actual error messages from port-forward services

echo "=== Streamlit Port-Forward Errors ==="
journalctl --user -u streamlit-port-forward.service --since "5 minutes ago" --no-pager | grep -i "error\|fail\|unable\|cannot" | tail -10
echo ""

echo "=== Full Streamlit Log (last 10 lines) ==="
journalctl --user -u streamlit-port-forward.service -n 10 --no-pager
echo ""

echo "=== Kibana Port-Forward Errors ==="
journalctl --user -u kibana-port-forward.service --since "5 minutes ago" --no-pager | grep -i "error\|fail\|unable\|cannot" | tail -10
echo ""

echo "=== Full Kibana Log (last 10 lines) ==="
journalctl --user -u kibana-port-forward.service -n 10 --no-pager
echo ""

echo "=== Testing kubectl connectivity ==="
kubectl get svc streamlit-service 2>&1
echo ""
kubectl get svc -n logging kibana 2>&1
echo ""

echo "=== Testing manual port-forward (5 seconds) ==="
timeout 5 kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0 2>&1 &
PF_PID=$!
sleep 3
kill $PF_PID 2>/dev/null
wait $PF_PID 2>/dev/null

