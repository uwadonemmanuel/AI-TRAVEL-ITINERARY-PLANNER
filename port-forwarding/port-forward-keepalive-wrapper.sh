#!/bin/bash

# Port-forward wrapper with keepalive and auto-reconnect
# This script maintains persistent port-forward connections

NAMESPACE="${1:-default}"
SERVICE="$2"
PORTS="$3"
ADDRESS="${4:-0.0.0.0}"

KUBECTL_PATH=$(which kubectl)

# Function to start port-forward
start_port_forward() {
    if [ "$NAMESPACE" = "default" ]; then
        $KUBECTL_PATH port-forward svc/"$SERVICE" "$PORTS" --address "$ADDRESS"
    else
        $KUBECTL_PATH port-forward -n "$NAMESPACE" svc/"$SERVICE" "$PORTS" --address "$ADDRESS"
    fi
}

# Wait for Minikube/Kubernetes to be ready
for i in {1..120}; do
    if minikube status &>/dev/null 2>&1 && $KUBECTL_PATH cluster-info &>/dev/null 2>&1; then
        break
    fi
    if [ $i -eq 120 ]; then
        echo "Error: Kubernetes cluster not accessible"
        exit 1
    fi
    sleep 1
done

# Main loop: restart port-forward if it dies
while true; do
    echo "$(date): Starting port-forward for $SERVICE"
    start_port_forward
    
    EXIT_CODE=$?
    echo "$(date): Port-forward exited with code $EXIT_CODE"
    
    # If exit code is 0, it was intentional (shouldn't happen in loop)
    if [ $EXIT_CODE -eq 0 ]; then
        break
    fi
    
    # Wait before restarting (exponential backoff, max 30 seconds)
    WAIT_TIME=$((RANDOM % 10 + 5))
    echo "$(date): Waiting $WAIT_TIME seconds before restart..."
    sleep $WAIT_TIME
    
    # Verify cluster is still accessible
    if ! $KUBECTL_PATH cluster-info &>/dev/null 2>&1; then
        echo "$(date): Cluster not accessible, waiting longer..."
        sleep 30
    fi
done

