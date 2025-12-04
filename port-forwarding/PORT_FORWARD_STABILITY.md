# Port-Forward Stability and Failure Times

## Typical Failure Times

Based on observations and Kubernetes behavior:

### Common Failure Scenarios

1. **Idle Timeout**: 5-30 minutes
   - Most common cause
   - Connection closes after no traffic
   - Varies by cluster configuration

2. **Network Timeout**: 1-2 hours
   - TCP keepalive issues
   - Network infrastructure timeouts
   - Load balancer/proxy timeouts

3. **Pod Restart**: Immediate
   - When target pod restarts, connection breaks
   - Service endpoints change

4. **Cluster Changes**: Variable
   - Node restarts
   - Network reconfiguration
   - API server restarts

5. **Resource Limits**: Variable
   - Too many connections
   - Rate limiting
   - Memory/CPU constraints

## Why Port-Forwards Are Unstable

### Technical Reasons

1. **No Built-in Keepalive**: `kubectl port-forward` doesn't send keepalive packets by default
2. **Single Connection**: One TCP connection that can break
3. **No Auto-Reconnect**: When connection dies, it doesn't automatically restart
4. **Stateful Connection**: Maintains state that can be lost

### Kubernetes API Server Behavior

- API server may close idle connections
- Load balancers/proxies have their own timeouts
- Network policies may affect connection stability

## Solutions for Persistent Port-Forwards

### Solution 1: Auto-Restart Wrapper (Recommended)

Use the `port-forward-keepalive-wrapper.sh` script that:
- Automatically restarts on failure
- Implements exponential backoff
- Verifies cluster connectivity before restarting

**Update service files to use it:**

```bash
# In service file, change ExecStart to:
ExecStart=/home/blessedman776/port-forward-keepalive-wrapper.sh default streamlit-service 8501:80 0.0.0.0
```

### Solution 2: Use NodePort or LoadBalancer (Best for Production)

Instead of port-forward, expose services directly:

```yaml
# In your service YAML
spec:
  type: NodePort  # or LoadBalancer
  ports:
    - port: 80
      nodePort: 30080  # External port
```

**Advantages:**
- More stable
- No connection timeouts
- Better for production
- Survives pod restarts

### Solution 3: Add Keepalive Traffic

Create a simple keepalive script that sends periodic requests:

```bash
#!/bin/bash
# keepalive.sh - Send periodic requests to keep connection alive
while true; do
    curl -s http://localhost:8501 > /dev/null 2>&1
    sleep 300  # Every 5 minutes
done
```

### Solution 4: Use Ingress (Production Best Practice)

Set up an Ingress controller:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: streamlit-ingress
spec:
  rules:
  - host: streamlit.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: streamlit-service
            port:
              number: 80
```

## Monitoring Port-Forward Health

### Check if Port-Forward is Active

```bash
# Check if process is running
ps aux | grep "kubectl port-forward"

# Check if port is listening
ss -tlnp | grep 8501

# Test connectivity
curl http://localhost:8501
```

### Monitor Service Logs

```bash
# Watch for failures
journalctl --user -u streamlit-port-forward.service -f

# Check restart count
systemctl --user status streamlit-port-forward.service | grep "restart"
```

## Expected Behavior with systemd

With `Restart=always` in systemd:

- **Immediate Restart**: Service restarts within 10 seconds (RestartSec=10)
- **Infinite Retries**: Will keep trying indefinitely
- **Auto-Recovery**: Recovers from temporary failures

**However**, if the underlying issue persists (e.g., Minikube not running), it will keep failing.

## Best Practices

1. **Use NodePort/LoadBalancer for Production**
   - More stable than port-forward
   - Better performance
   - No connection timeouts

2. **Keep Minikube Running**
   - Ensure Minikube starts on boot
   - Monitor Minikube health

3. **Monitor and Alert**
   - Set up monitoring for port-forward health
   - Alert on repeated failures

4. **Use Health Checks**
   - Implement application-level health checks
   - Verify connectivity regularly

## Typical Failure Timeline

Based on observations:

| Scenario | Typical Failure Time | Solution |
|----------|---------------------|----------|
| Idle connection | 5-30 minutes | Keepalive traffic |
| Network timeout | 1-2 hours | Auto-restart wrapper |
| Pod restart | Immediate | Auto-restart (systemd) |
| Cluster down | Immediate | Ensure cluster is running |
| Resource exhaustion | Variable | Monitor resources |

## Recommendations

### For Development (Current Setup)
- ✅ Use systemd with `Restart=always` (you have this)
- ✅ Use keepalive wrapper script
- ✅ Monitor logs regularly
- ⚠️ Accept occasional restarts

### For Production
- ✅ Use NodePort or LoadBalancer
- ✅ Use Ingress with proper domain
- ✅ Set up monitoring
- ✅ Use health checks
- ❌ Don't rely on port-forward

## Quick Fix for Current Setup

Update your services to use the keepalive wrapper:

```bash
# 1. Copy keepalive wrapper
chmod +x port-forward-keepalive-wrapper.sh
cp port-forward-keepalive-wrapper.sh ~/port-forward-keepalive-wrapper.sh

# 2. Update service files
nano ~/.config/systemd/user/streamlit-port-forward.service
# Change ExecStart to:
# ExecStart=/home/blessedman776/port-forward-keepalive-wrapper.sh default streamlit-service 8501:80 0.0.0.0

# 3. Reload and restart
systemctl --user daemon-reload
systemctl --user restart streamlit-port-forward.service
```

---

**Last Updated**: 2025-12-03  
**Based on**: Kubernetes 1.28+, Minikube observations, common failure patterns

