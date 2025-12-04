#!/bin/bash

# Tmux-based port-forwarding setup with HTTPS support
# This script sets up persistent port-forwards using tmux sessions

set -e

echo "=== Tmux Port-Forward Setup with HTTPS ==="
echo ""

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "Installing tmux..."
    sudo apt-get update
    sudo apt-get install -y tmux
fi

# Check if kubectl is accessible, wait for Minikube if needed
echo "Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "Kubernetes cluster not accessible. Checking Minikube status..."
    
    if ! command -v minikube &> /dev/null; then
        echo "Error: minikube not found. Please install Minikube first."
        exit 1
    fi
    
    MINIKUBE_STATUS=$(minikube status 2>/dev/null | head -1)
    if echo "$MINIKUBE_STATUS" | grep -q "Stopped\|not found"; then
        echo "Minikube is not running. Starting Minikube..."
        minikube start
        if [ $? -ne 0 ]; then
            echo "Warning: Minikube start had some issues, but continuing..."
        fi
    else
        echo "Minikube appears to be starting. Waiting for it to be ready..."
    fi
    
    # Wait for cluster to be ready (max 2 minutes)
    echo "Waiting for Kubernetes cluster to be ready..."
    for i in {1..120}; do
        if kubectl cluster-info &>/dev/null 2>&1; then
            echo "✓ Kubernetes cluster is ready"
            break
        fi
        if [ $i -eq 120 ]; then
            echo "Error: Kubernetes cluster not ready after 2 minutes"
            echo "Please check Minikube status: minikube status"
            exit 1
        fi
        sleep 1
        if [ $((i % 10)) -eq 0 ]; then
            echo "  Still waiting... ($i/120 seconds)"
        fi
    done
else
    echo "✓ Kubernetes cluster is accessible"
fi

# Check for existing services and warn
echo "Checking for existing services..."
EXISTING_SERVICES=0

if systemctl --user is-active streamlit-port-forward.service &>/dev/null || \
   systemctl --user is-active kibana-port-forward.service &>/dev/null; then
    echo "⚠ Warning: systemd services are running"
    echo "  Run './stop-existing-services.sh' first to avoid conflicts"
    EXISTING_SERVICES=1
fi

if tmux has-session -t streamlit-port-forward 2>/dev/null || \
   tmux has-session -t kibana-port-forward 2>/dev/null; then
    echo "⚠ Warning: Existing tmux sessions found"
    EXISTING_SERVICES=1
fi

if pgrep -f "kubectl port-forward" > /dev/null; then
    echo "⚠ Warning: kubectl port-forward processes are running"
    EXISTING_SERVICES=1
fi

if [ $EXISTING_SERVICES -eq 1 ]; then
    echo ""
    read -p "Stop existing services and continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping existing services..."
        ./stop-existing-services.sh 2>/dev/null || {
            # Manual cleanup if script doesn't exist
            systemctl --user stop streamlit-port-forward.service 2>/dev/null || true
            systemctl --user stop kibana-port-forward.service 2>/dev/null || true
            tmux kill-session -t streamlit-port-forward 2>/dev/null || true
            tmux kill-session -t kibana-port-forward 2>/dev/null || true
            pkill -f "kubectl port-forward" 2>/dev/null || true
        }
        sleep 2
    else
        echo "Aborting. Please stop existing services first."
        exit 1
    fi
fi

# Kill any remaining tmux sessions
tmux kill-session -t streamlit-port-forward 2>/dev/null || true
tmux kill-session -t kibana-port-forward 2>/dev/null || true
tmux kill-session -t nginx-proxy 2>/dev/null || true

# Wait a moment
sleep 2

# Create Streamlit port-forward session
echo "Setting up Streamlit port-forward (HTTP on 8501)..."
tmux new-session -d -s streamlit-port-forward \
    "kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0"

# Create Kibana port-forward session
echo "Setting up Kibana port-forward (HTTP on 5601)..."
tmux new-session -d -s kibana-port-forward \
    "kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0"

# Wait for port-forwards to establish and verify
echo "Waiting for port-forwards to establish..."
sleep 5

# Verify port-forwards are working
for i in {1..30}; do
    if ss -tlnp 2>/dev/null | grep -q ":8501 " || netstat -tlnp 2>/dev/null | grep -q ":8501 "; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Warning: Port 8501 not listening after 30 seconds"
    fi
    sleep 1
done

# Check if port-forwards are running
if tmux has-session -t streamlit-port-forward 2>/dev/null; then
    echo "✓ Streamlit port-forward session created"
else
    echo "✗ Failed to create Streamlit port-forward session"
fi

if tmux has-session -t kibana-port-forward 2>/dev/null; then
    echo "✓ Kibana port-forward session created"
else
    echo "✗ Failed to create Kibana port-forward session"
fi

echo ""
echo "=== Setting up HTTPS Reverse Proxy ==="
echo ""

# Create nginx configuration directory
NGINX_DIR="$HOME/nginx-https-proxy"
mkdir -p "$NGINX_DIR/conf.d"
mkdir -p "$NGINX_DIR/ssl"

# Generate self-signed certificates (for testing)
echo "Generating self-signed SSL certificates..."
if [ ! -f "$NGINX_DIR/ssl/server.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$NGINX_DIR/ssl/server.key" \
        -out "$NGINX_DIR/ssl/server.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=34.9.116.136" \
        2>/dev/null || {
        echo "Warning: OpenSSL not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y openssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$NGINX_DIR/ssl/server.key" \
            -out "$NGINX_DIR/ssl/server.crt" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=34.9.116.136"
    }
    echo "✓ SSL certificates generated"
else
    echo "✓ SSL certificates already exist"
fi

# Create nginx configuration
cat > "$NGINX_DIR/nginx.conf" <<'NGINX_EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss;

    # Upstream servers
    upstream streamlit {
        server 127.0.0.1:8501;
    }

    upstream kibana {
        server 127.0.0.1:5601;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name 34.9.116.136;
        return 301 https://$server_name$request_uri;
    }

    # Streamlit HTTPS
    server {
        listen 443 ssl http2;
        server_name 34.9.116.136;

        ssl_certificate /home/blessedman776/nginx-https-proxy/ssl/server.crt;
        ssl_certificate_key /home/blessedman776/nginx-https-proxy/ssl/server.key;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://streamlit;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400;
        }
    }

    # Kibana HTTPS (on different port)
    server {
        listen 8443 ssl http2;
        server_name 34.9.116.136;

        ssl_certificate /home/blessedman776/nginx-https-proxy/ssl/server.crt;
        ssl_certificate_key /home/blessedman776/nginx-https-proxy/ssl/server.key;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://kibana;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400;
        }
    }
}
NGINX_EOF

# Replace username in nginx config
sed -i "s|/home/blessedman776|$HOME|g" "$NGINX_DIR/nginx.conf"

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    sudo apt-get update
    sudo apt-get install -y nginx
fi

# Create nginx log directory
sudo mkdir -p /var/log/nginx
sudo chown www-data:www-data /var/log/nginx

# Test nginx configuration
echo "Testing nginx configuration..."
sudo nginx -t -c "$NGINX_DIR/nginx.conf" 2>/dev/null || {
    echo "Creating nginx test configuration..."
    # Use a simpler approach - run nginx in a container or as user
    echo "Note: Running nginx as user (requires nginx to support this)"
}

# Create tmux session for nginx
echo "Setting up nginx reverse proxy in tmux..."
tmux new-session -d -s nginx-proxy \
    "sudo nginx -c $NGINX_DIR/nginx.conf -g 'pid /tmp/nginx.pid;' || echo 'Nginx failed to start. You may need to run: sudo nginx -c $NGINX_DIR/nginx.conf'"

sleep 2

# Verify all sessions
echo ""
echo "=== Verification ==="
echo ""

if tmux has-session -t streamlit-port-forward 2>/dev/null; then
    echo "✓ Streamlit port-forward: Running"
else
    echo "✗ Streamlit port-forward: Not running"
fi

if tmux has-session -t kibana-port-forward 2>/dev/null; then
    echo "✓ Kibana port-forward: Running"
else
    echo "✗ Kibana port-forward: Not running"
fi

if tmux has-session -t nginx-proxy 2>/dev/null; then
    echo "✓ Nginx proxy: Running"
else
    echo "✗ Nginx proxy: Not running (may need sudo)"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Access your services via HTTPS:"
echo "  Streamlit: https://34.9.116.136/"
echo "  Kibana:    https://34.9.116.136:8443/"
echo ""
echo "Note: You'll see a security warning because we're using self-signed certificates."
echo "This is normal for testing. Click 'Advanced' and 'Proceed' to continue."
echo ""
echo "Tmux session management:"
echo "  List sessions:    tmux ls"
echo "  Attach to session: tmux attach -t streamlit-port-forward"
echo "  Detach:           Press Ctrl+B then D"
echo "  Kill session:     tmux kill-session -t streamlit-port-forward"
echo ""

