# Tmux-Based Port-Forwarding with HTTPS

This guide explains how to use tmux for persistent port-forwarding with HTTPS support using nginx as a reverse proxy.

## Overview

Instead of using systemd services, this solution uses **tmux** (terminal multiplexer) to maintain persistent port-forward connections. An **nginx reverse proxy** provides HTTPS termination.

### Architecture

```
Internet (HTTPS)
    ↓
Nginx Reverse Proxy (Port 443/8443)
    ↓ (HTTP)
kubectl port-forward (Port 8501/5601)
    ↓
Kubernetes Services
```

## Prerequisites

- tmux installed
- nginx installed
- kubectl configured
- Minikube running
- OpenSSL (for certificate generation)

## Quick Start

### 1. Run Setup Script

```bash
cd port-forwarding

# Make all scripts executable
chmod +x *.sh

# IMPORTANT: Stop existing services first (if any)
./stop-existing-services.sh

# Setup everything (tmux + nginx + HTTPS)
./tmux-port-forward-setup.sh
```

This script will:
- Install tmux and nginx if needed
- Create tmux sessions for port-forwards
- Generate self-signed SSL certificates
- Configure nginx as HTTPS reverse proxy
- Start all services

### 2. Test the Setup

```bash
# Test the setup
./test-https-setup.sh
```

### 3. Access Services

- **Streamlit**: `https://34.9.116.136/`
- **Kibana**: `https://34.9.116.136:8443/`

**Note**: You'll see a security warning for self-signed certificates. Click "Advanced" → "Proceed" to continue.

### 4. Manage Services

```bash
# Check status
./tmux-port-forward-manage.sh status

# Start services
./tmux-port-forward-manage.sh start

# Stop services
./tmux-port-forward-manage.sh stop

# Restart services
./tmux-port-forward-manage.sh restart

# Test HTTPS
./tmux-port-forward-manage.sh test
```

## Tmux Session Management

### List All Sessions

```bash
tmux ls
```

### Attach to a Session

```bash
# Attach to Streamlit port-forward
tmux attach -t streamlit-port-forward

# Attach to Kibana port-forward
tmux attach -t kibana-port-forward

# Attach to nginx proxy
tmux attach -t nginx-proxy
```

### Detach from Session

Press: `Ctrl+B` then `D`

### Kill a Session

```bash
tmux kill-session -t streamlit-port-forward
tmux kill-session -t kibana-port-forward
tmux kill-session -t nginx-proxy
```

## HTTPS Configuration

### Self-Signed Certificates (Testing)

The setup script automatically generates self-signed certificates. These are fine for testing but will show security warnings in browsers.

**Certificate Location:**
- Certificate: `~/nginx-https-proxy/ssl/server.crt`
- Private Key: `~/nginx-https-proxy/ssl/server.key`

### Using Let's Encrypt (Production)

For production, use Let's Encrypt certificates:

```bash
# Install certbot
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx

# Get certificate (replace with your domain)
sudo certbot --nginx -d yourdomain.com

# Certificates will be in /etc/letsencrypt/live/yourdomain.com/
```

Then update nginx config to use Let's Encrypt certificates:

```nginx
ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
```

## Nginx Configuration

The nginx configuration is located at: `~/nginx-https-proxy/nginx.conf`

### Key Features

- **HTTP to HTTPS Redirect**: All HTTP traffic redirects to HTTPS
- **Streamlit on Port 443**: Main HTTPS port
- **Kibana on Port 8443**: Alternative HTTPS port
- **WebSocket Support**: For Streamlit's real-time features
- **Long Timeouts**: 24-hour timeout for persistent connections

### Customizing Configuration

Edit the nginx config:

```bash
nano ~/nginx-https-proxy/nginx.conf
```

Then reload nginx:

```bash
sudo nginx -s reload -c ~/nginx-https-proxy/nginx.conf
```

## Troubleshooting

### Port-Forwards Not Working

```bash
# Check if sessions exist
tmux ls

# Check kubectl connectivity
kubectl cluster-info

# Check if Minikube is running
minikube status

# View session logs
tmux attach -t streamlit-port-forward
```

### Nginx Not Starting

```bash
# Check nginx configuration
sudo nginx -t -c ~/nginx-https-proxy/nginx.conf

# Check if ports are in use
sudo netstat -tlnp | grep -E "443|8443"

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### HTTPS Not Accessible

```bash
# Test local HTTPS
curl -k https://localhost/

# Check firewall rules
sudo ufw status
# Ensure ports 443 and 8443 are open

# Test from external
curl -k https://34.9.116.136/
```

### Certificate Issues

```bash
# Regenerate certificates
rm ~/nginx-https-proxy/ssl/*
./tmux-port-forward-setup.sh
```

## Advantages of Tmux Approach

1. **Simple**: No systemd configuration needed
2. **Visible**: Can attach to sessions to see what's happening
3. **Flexible**: Easy to start/stop individual services
4. **Persistent**: Sessions survive SSH disconnects (with proper setup)
5. **HTTPS**: Built-in HTTPS support via nginx

## Disadvantages

1. **Manual Management**: Need to manually start after reboot
2. **No Auto-Restart**: If a session dies, it doesn't auto-restart
3. **Requires SSH**: Need to SSH in to manage sessions

## Making Tmux Sessions Survive Reboots

### Option 1: Add to .bashrc

```bash
# Add to ~/.bashrc
if [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ]; then
    # Auto-start port-forwards on SSH login
    if ! tmux has-session -t streamlit-port-forward 2>/dev/null; then
        tmux new-session -d -s streamlit-port-forward \
            "kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0"
    fi
    if ! tmux has-session -t kibana-port-forward 2>/dev/null; then
        tmux new-session -d -s kibana-port-forward \
            "kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0"
    fi
fi
```

### Option 2: Create a Startup Script

```bash
# Create ~/start-port-forwards.sh
#!/bin/bash
cd ~/AI-TRAVEL-ITINERARY-PLANNER/port-forwarding
./tmux-port-forward-manage.sh start

# Add to crontab for boot
crontab -e
# Add: @reboot /home/blessedman776/start-port-forwards.sh
```

## Comparison: Tmux vs Systemd

| Feature | Tmux | Systemd |
|---------|------|---------|
| Auto-restart | Manual | Automatic |
| Boot persistence | Requires setup | Built-in |
| Visibility | Can attach/view | Logs only |
| HTTPS support | Via nginx | Via nginx |
| Complexity | Simple | Moderate |
| Best for | Development | Production |

## Security Considerations

1. **Self-Signed Certificates**: Only for testing. Use Let's Encrypt for production.
2. **Firewall**: Ensure only necessary ports are open (443, 8443)
3. **Access Control**: Consider adding authentication to nginx
4. **Certificate Renewal**: Set up automatic renewal for Let's Encrypt

## Next Steps

1. **Set up domain**: Point a domain to your IP
2. **Get real certificates**: Use Let's Encrypt
3. **Add authentication**: Protect services with basic auth or OAuth
4. **Monitor**: Set up monitoring for port-forward health
5. **Backup**: Backup nginx configuration

## References

- [Tmux Wiki](https://github.com/tmux/tmux/wiki)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)

---

**Last Updated**: 2025-12-03

