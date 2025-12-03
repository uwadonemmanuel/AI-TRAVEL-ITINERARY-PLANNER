# Persistent Port-Forward Setup Guide

This guide explains how to keep `kubectl port-forward` processes running even after SSH sessions are closed.

## 🎯 Problem

When you run `kubectl port-forward` in an SSH session and disconnect, the port-forward processes are terminated, making your services inaccessible.

## ✅ Solutions

### Option 1: Using the Service Script (Quick & Simple)

This is the easiest solution using a bash script with `nohup`.

#### Setup

1. **Copy the script to your VM**:
   ```bash
   # On your local machine, copy the script to your VM
   scp port-forward-service.sh username@34.9.116.136:~/
   ```

2. **On your VM, make it executable**:
   ```bash
   chmod +x ~/port-forward-service.sh
   ```

3. **Start both port-forwards**:
   ```bash
   ~/port-forward-service.sh start
   ```

4. **Verify they're running**:
   ```bash
   ~/port-forward-service.sh status
   ```

#### Usage

```bash
# Start both services
~/port-forward-service.sh start

# Stop both services
~/port-forward-service.sh stop

# Restart both services
~/port-forward-service.sh restart

# Check status
~/port-forward-service.sh status

# Start/stop individually
~/port-forward-service.sh start-streamlit
~/port-forward-service.sh stop-streamlit
~/port-forward-service.sh start-kibana
~/port-forward-service.sh stop-kibana
```

#### View Logs

```bash
# Streamlit logs
tail -f /tmp/streamlit-port-forward.log

# Kibana logs
tail -f /tmp/kibana-port-forward.log
```

---

### Option 2: Using systemd Services (Recommended for Production)

This is the most robust solution - services will automatically restart on failure and start on boot.

#### Setup

1. **Copy service files to your VM**:
   ```bash
   scp streamlit-port-forward.service username@34.9.116.136:~/
   scp kibana-port-forward.service username@34.9.116.136:~/
   ```

2. **On your VM, install the services**:
   ```bash
   # Copy to systemd directory (requires sudo)
   sudo cp streamlit-port-forward.service /etc/systemd/user/
   sudo cp kibana-port-forward.service /etc/systemd/user/
   
   # Or use user systemd (no sudo needed)
   mkdir -p ~/.config/systemd/user
   cp streamlit-port-forward.service ~/.config/systemd/user/
   cp kibana-port-forward.service ~/.config/systemd/user/
   ```

3. **Edit the service files** to replace `%i` with your username:
   ```bash
   # For user systemd
   sed -i "s/%i/$(whoami)/g" ~/.config/systemd/user/streamlit-port-forward.service
   sed -i "s/%i/$(whoami)/g" ~/.config/systemd/user/kibana-port-forward.service
   ```

4. **Reload systemd and enable services**:
   ```bash
   # For user systemd
   systemctl --user daemon-reload
   systemctl --user enable streamlit-port-forward.service
   systemctl --user enable kibana-port-forward.service
   
   # Start the services
   systemctl --user start streamlit-port-forward.service
   systemctl --user start kibana-port-forward.service
   
   # Enable lingering (keeps services running after logout)
   loginctl enable-linger $(whoami)
   ```

#### Usage

```bash
# Start services
systemctl --user start streamlit-port-forward.service
systemctl --user start kibana-port-forward.service

# Stop services
systemctl --user stop streamlit-port-forward.service
systemctl --user stop kibana-port-forward.service

# Restart services
systemctl --user restart streamlit-port-forward.service
systemctl --user restart kibana-port-forward.service

# Check status
systemctl --user status streamlit-port-forward.service
systemctl --user status kibana-port-forward.service

# View logs
journalctl --user -u streamlit-port-forward.service -f
journalctl --user -u kibana-port-forward.service -f

# Enable on boot
systemctl --user enable streamlit-port-forward.service
systemctl --user enable kibana-port-forward.service
```

---

### Option 3: Using screen (Simple Alternative)

If you prefer a simpler approach without scripts:

1. **Install screen** (if not already installed):
   ```bash
   sudo apt-get update && sudo apt-get install -y screen
   ```

2. **Create a screen session**:
   ```bash
   screen -S port-forwards
   ```

3. **Start port-forwards in the screen session**:
   ```bash
   kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0
   # Press Ctrl+A then D to detach
   ```

4. **Start Kibana in another screen session**:
   ```bash
   screen -S kibana-forward
   kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0
   # Press Ctrl+A then D to detach
   ```

5. **Reattach to sessions**:
   ```bash
   screen -r port-forwards
   screen -r kibana-forward
   ```

6. **List all screen sessions**:
   ```bash
   screen -ls
   ```

---

### Option 4: Using tmux (Alternative to screen)

1. **Install tmux** (if not already installed):
   ```bash
   sudo apt-get update && sudo apt-get install -y tmux
   ```

2. **Create a tmux session**:
   ```bash
   tmux new -s port-forwards
   ```

3. **Start port-forwards**:
   ```bash
   kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0
   # Press Ctrl+B then D to detach
   ```

4. **Create another pane for Kibana** (in the same session):
   - Press `Ctrl+B` then `%` to split vertically
   - In the new pane:
     ```bash
     kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0
     ```

5. **Detach**: Press `Ctrl+B` then `D`

6. **Reattach**:
   ```bash
   tmux attach -t port-forwards
   ```

---

## 🔍 Verification

After setting up any method, verify the services are accessible:

```bash
# Test Streamlit
curl http://localhost:8501

# Test Kibana
curl http://localhost:5601

# Check if ports are listening
netstat -tlnp | grep -E "8501|5601"
# Or
ss -tlnp | grep -E "8501|5601"
```

## 🐛 Troubleshooting

### Port-forward dies after a few minutes

**Solution**: Use systemd services with `Restart=always` (Option 2)

### Can't access from external IP

**Check**:
1. Firewall rules allow the ports
2. Port-forward is using `--address 0.0.0.0`
3. Service is actually running: `ps aux | grep "kubectl port-forward"`

### Services don't start on boot

**For systemd (Option 2)**:
```bash
# Ensure lingering is enabled
loginctl enable-linger $(whoami)

# Verify services are enabled
systemctl --user list-unit-files | grep port-forward
```

### Permission denied errors

**Solution**: Ensure kubectl is accessible and you have proper permissions:
```bash
which kubectl
kubectl get pods
```

## 📝 Quick Reference

### Option 1 (Script) - Quick Commands
```bash
~/port-forward-service.sh start    # Start both
~/port-forward-service.sh status   # Check status
~/port-forward-service.sh stop    # Stop both
```

### Option 2 (systemd) - Quick Commands
```bash
systemctl --user start streamlit-port-forward.service
systemctl --user start kibana-port-forward.service
systemctl --user status streamlit-port-forward.service
```

### Option 3/4 (screen/tmux) - Quick Commands
```bash
screen -ls              # List sessions
screen -r port-forwards # Reattach
tmux ls                 # List sessions
tmux attach -t port-forwards
```

## 🎯 Recommendation

- **For quick setup**: Use **Option 1** (Service Script)
- **For production**: Use **Option 2** (systemd services)
- **For temporary/testing**: Use **Option 3 or 4** (screen/tmux)

---

**Last Updated**: 2025-11-23

