#!/bin/bash

# Wrapper script for kubectl port-forward that waits for services to be ready
# Usage: port-forward-wrapper.sh <namespace> <service> <local-port>:<remote-port>

NAMESPACE="${1:-default}"
SERVICE="$2"
PORTS="$3"
ADDRESS="${4:-0.0.0.0}"

if [ -z "$SERVICE" ] || [ -z "$PORTS" ]; then
    echo "Usage: $0 [namespace] <service> <local-port>:<remote-port> [address]"
    exit 1
fi

KUBECTL_PATH=$(which kubectl)

# Wait for service to be available (max 60 seconds)
echo "Waiting for service $SERVICE in namespace $NAMESPACE to be ready..."
for i in {1..60}; do
    if [ "$NAMESPACE" = "default" ]; then
        if $KUBECTL_PATH get svc "$SERVICE" &>/dev/null; then
            echo "Service $SERVICE found"
            break
        fi
    else
        if $KUBECTL_PATH get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
            echo "Service $SERVICE found in namespace $NAMESPACE"
            break
        fi
    fi
    if [ $i -eq 60 ]; then
        echo "Error: Service $SERVICE not found after 60 seconds"
        exit 1
    fi
    sleep 1
done

# Wait for endpoints to be ready
echo "Waiting for endpoints to be ready..."
for i in {1..60}; do
    if [ "$NAMESPACE" = "default" ]; then
        ENDPOINTS=$($KUBECTL_PATH get endpoints "$SERVICE" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
    else
        ENDPOINTS=$($KUBECTL_PATH get endpoints -n "$NAMESPACE" "$SERVICE" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
    fi
    
    if [ -n "$ENDPOINTS" ] && [ "$ENDPOINTS" != "null" ]; then
        echo "Endpoints ready: $ENDPOINTS"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "Warning: Endpoints not ready, but proceeding anyway"
    fi
    sleep 1
done

# Start port-forward
if [ "$NAMESPACE" = "default" ]; then
    exec $KUBECTL_PATH port-forward svc/"$SERVICE" "$PORTS" --address "$ADDRESS"
else
    exec $KUBECTL_PATH port-forward -n "$NAMESPACE" svc/"$SERVICE" "$PORTS" --address "$ADDRESS"
fi

