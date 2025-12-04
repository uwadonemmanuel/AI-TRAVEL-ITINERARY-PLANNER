# Port-Forwarding Scripts and Services

This folder contains all scripts and configuration files for managing persistent `kubectl port-forward` connections for the AI Travel Itinerary Planner application.

## 📁 File Organization

### Setup Scripts

- **`tmux-port-forward-setup.sh`** - **NEW**: Tmux-based setup with HTTPS support
  - Usage: `./tmux-port-forward-setup.sh`
  - Creates tmux sessions for port-forwards
  - Sets up nginx reverse proxy with HTTPS
  - Generates self-signed SSL certificates
  - Recommended for development/testing

- **`setup-systemd-services.sh`** - Main setup script that creates and configures systemd user services for port-forwarding
  - Usage: `./setup-systemd-services.sh`
  - Creates service files and wrapper scripts
  - Sets up auto-restart on failure
  - Recommended for production

- **`fix-minikube-port-forward.sh`** - Fixes port-forward services when Minikube connectivity issues occur
  - Usage: `./fix-minikube-port-forward.sh`
  - Ensures Minikube is running
  - Updates service files with Minikube-specific configuration

### Wrapper Scripts

- **`port-forward-wrapper.sh`** - Basic wrapper that waits for services to be ready before starting port-forward
  - Used by systemd services
  - Waits for Kubernetes services to be available

- **`port-forward-keepalive-wrapper.sh`** - Advanced wrapper with auto-restart and keepalive
  - Automatically restarts on failure
  - Implements exponential backoff
  - Recommended for production use

### Management Scripts

- **`tmux-port-forward-manage.sh`** - **NEW**: Management script for tmux-based port-forwards
  - Usage: `./tmux-port-forward-manage.sh {start|stop|restart|status|logs|test}`
  - Manages tmux sessions and nginx
  - Includes HTTPS testing
  - Simple and intuitive

- **`port-forward-service.sh`** - Simple bash script for managing port-forwards (Option 1 from docs)
  - Usage: `./port-forward-service.sh {start|stop|restart|status}`
  - Uses `nohup` for basic persistence
  - Good for quick setup but less reliable than systemd

### Verification & Debugging Scripts

- **`verify-port-forwards.sh`** - Comprehensive verification script
  - Checks service status
  - Verifies ports are listening
  - Tests local connectivity
  - Usage: `./verify-port-forwards.sh`

- **`check-port-forward-errors.sh`** - Detailed error analysis
  - Shows full service logs
  - Tests kubectl connectivity
  - Checks if services exist
  - Usage: `./check-port-forward-errors.sh`

- **`get-port-forward-errors.sh`** - Quick error checker
  - Shows recent errors from logs
  - Tests manual port-forward
  - Usage: `./get-port-forward-errors.sh`

- **`stop-existing-services.sh`** - **NEW**: Stops all existing port-forward services
  - Stops systemd services
  - Kills tmux sessions
  - Stops kubectl port-forward processes
  - Stops nginx
  - Checks for port conflicts
  - Usage: `./stop-existing-services.sh`
  - **Run this before setting up tmux if you have existing services**

- **`test-https-setup.sh`** - **NEW**: Comprehensive test suite for HTTPS setup
  - Tests all components (tmux, nginx, HTTPS)
  - Verifies SSL certificates
  - Tests external connectivity
  - Usage: `./test-https-setup.sh`

### Service Files

- **`streamlit-port-forward.service`** - systemd user service file for Streamlit (port 8501)
- **`kibana-port-forward.service`** - systemd user service file for Kibana (port 5601)

These are automatically created by `setup-systemd-services.sh` but can be manually edited if needed.

### Documentation

- **`PERSISTENT_PORT_FORWARD_SETUP.md`** - Complete setup guide with multiple options
  - Option 1: Service script (nohup)
  - Option 2: systemd services (recommended)
  - Option 3: screen sessions
  - Option 4: tmux sessions

- **`PORT_FORWARD_STABILITY.md`** - Documentation on port-forward failure times and solutions
  - Typical failure scenarios
  - Why port-forwards are unstable
  - Best practices for production
  - Monitoring and health checks

- **`TMUX_HTTPS_SETUP.md`** - **NEW**: Complete guide for tmux-based HTTPS setup
  - Tmux session management
  - HTTPS configuration
  - SSL certificate setup (self-signed and Let's Encrypt)
  - Troubleshooting guide
  - Comparison with systemd approach

## 🚀 Quick Start

### Option A: Tmux with HTTPS (Recommended for Testing)

**HTTPS-enabled port-forwarding using tmux and nginx:**

```bash
cd port-forwarding

# Make all scripts executable
chmod +x *.sh

# IMPORTANT: Stop existing services first (if any)
./stop-existing-services.sh

# Setup everything (tmux + nginx + HTTPS)
./tmux-port-forward-setup.sh

# Test the setup
./test-https-setup.sh

# Manage services
./tmux-port-forward-manage.sh status
```

**Note**: If you have existing port-forwards running (systemd, screen, or manual), run `./stop-existing-services.sh` first to avoid port conflicts.

**Access services:**
- Streamlit: `https://34.9.116.136/`
- Kibana: `https://34.9.116.136:8443/`

See `TMUX_HTTPS_SETUP.md` for detailed documentation.

### Option B: Systemd Services (Recommended for Production)

```bash
cd port-forwarding
chmod +x *.sh
./setup-systemd-services.sh
```

### Verify Setup

```bash
# For tmux setup
./test-https-setup.sh

# For systemd setup
./verify-port-forwards.sh
```

### Check for Issues

```bash
./get-port-forward-errors.sh
```

### Fix Minikube Issues

```bash
./fix-minikube-port-forward.sh
```

## 📋 Service Management

### Tmux-Based (HTTPS)

```bash
# Manage all services
./tmux-port-forward-manage.sh start
./tmux-port-forward-manage.sh stop
./tmux-port-forward-manage.sh restart
./tmux-port-forward-manage.sh status
./tmux-port-forward-manage.sh test

# View logs
./tmux-port-forward-manage.sh logs streamlit-port-forward
./tmux-port-forward-manage.sh logs kibana-port-forward

# Or attach directly
tmux attach -t streamlit-port-forward
tmux attach -t kibana-port-forward
```

### Systemd-Based

```bash
# Check status
systemctl --user status streamlit-port-forward.service
systemctl --user status kibana-port-forward.service

# View logs
journalctl --user -u streamlit-port-forward.service -f
journalctl --user -u kibana-port-forward.service -f

# Restart services
systemctl --user restart streamlit-port-forward.service
systemctl --user restart kibana-port-forward.service

# Stop services
systemctl --user stop streamlit-port-forward.service
systemctl --user stop kibana-port-forward.service
```

## 🔧 Troubleshooting

1. **Services failing**: Run `./get-port-forward-errors.sh` to see errors
2. **Minikube issues**: Run `./fix-minikube-port-forward.sh`
3. **Ports not accessible**: Run `./verify-port-forwards.sh` to diagnose
4. **Connection timeouts**: See `PORT_FORWARD_STABILITY.md` for solutions

## 📝 Notes

- All scripts should be run from the VM, not locally
- Ensure Minikube is running for port-forwards to work
- Services are configured to auto-restart on failure
- Port-forwards may fail after idle time (see stability docs)

## 🔗 Related Files

- Main project README: `../README.md`
- Kubernetes deployment: `../k8s-deployment.yaml`
- Service definitions: `../elasticsearch.yaml`, `../kibana.yaml`

---

**Last Updated**: 2025-12-03

