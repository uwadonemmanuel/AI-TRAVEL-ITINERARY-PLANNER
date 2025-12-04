#!/bin/bash

# Fix Minikube API server issues

echo "=== Diagnosing Minikube API Server Issues ==="
echo ""

# Check Minikube status
echo "1. Current Minikube status:"
minikube status
echo ""

# Check Minikube logs for API server errors
echo "2. Checking Minikube logs for API server errors..."
minikube logs --node=minikube 2>&1 | grep -i "apiserver\|error\|fatal" | tail -20
echo ""

# Check system resources
echo "3. Checking system resources:"
echo "  Memory:"
free -h | head -2
echo "  Disk:"
df -h / | tail -1
echo ""

# Check Docker
echo "4. Checking Docker status:"
if systemctl is-active docker &>/dev/null; then
    echo "  ✓ Docker is running"
else
    echo "  ✗ Docker is not running"
    echo "  Starting Docker..."
    sudo systemctl start docker
fi
echo ""

# Try to restart Minikube
echo "5. Attempting to restart Minikube..."
minikube stop
sleep 5
minikube start

echo ""
echo "6. Waiting for API server to be ready..."
for i in {1..60}; do
    if kubectl cluster-info &>/dev/null 2>&1; then
        echo "  ✓ API server is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "  ✗ API server not ready after 60 seconds"
        echo "  Checking detailed status..."
        minikube status
        exit 1
    fi
    sleep 1
    if [ $((i % 10)) -eq 0 ]; then
        echo "  Still waiting... ($i/60 seconds)"
    fi
done

echo ""
echo "7. Final status:"
minikube status
kubectl cluster-info

echo ""
echo "=== Fix Complete ==="

