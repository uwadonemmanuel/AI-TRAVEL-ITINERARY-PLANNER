#!/bin/bash

# Management script for tmux-based port-forwards

case "$1" in
    start)
        echo "Starting port-forwards..."
        
        # Check if Minikube is running
        if ! kubectl cluster-info &>/dev/null; then
            echo "Error: Kubernetes cluster not accessible"
            echo "Please start Minikube: minikube start"
            exit 1
        fi
        
        # Start Streamlit port-forward
        if ! tmux has-session -t streamlit-port-forward 2>/dev/null; then
            tmux new-session -d -s streamlit-port-forward \
                "kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0"
            echo "✓ Streamlit port-forward started"
        else
            echo "⚠ Streamlit port-forward already running"
        fi
        
        # Start Kibana port-forward
        if ! tmux has-session -t kibana-port-forward 2>/dev/null; then
            tmux new-session -d -s kibana-port-forward \
                "kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0"
            echo "✓ Kibana port-forward started"
        else
            echo "⚠ Kibana port-forward already running"
        fi
        
        # Start Caddy if service exists
        if systemctl list-unit-files | grep -q caddy-https-proxy.service; then
            if ! sudo systemctl is-active caddy-https-proxy.service &>/dev/null; then
                sudo systemctl start caddy-https-proxy.service
                echo "✓ Caddy HTTPS proxy started"
            else
                echo "⚠ Caddy HTTPS proxy already running"
            fi
        fi
        ;;
        
    stop)
        echo "Stopping port-forwards..."
        tmux kill-session -t streamlit-port-forward 2>/dev/null && echo "✓ Streamlit stopped" || echo "⚠ Streamlit not running"
        tmux kill-session -t kibana-port-forward 2>/dev/null && echo "✓ Kibana stopped" || echo "⚠ Kibana not running"
        sudo systemctl stop caddy-https-proxy.service 2>/dev/null && echo "✓ Caddy stopped" || echo "⚠ Caddy not running"
        ;;
        
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
        
    status)
        echo "=== Port-Forward Status ==="
        echo ""
        if tmux has-session -t streamlit-port-forward 2>/dev/null; then
            echo "✓ Streamlit port-forward: Running"
            echo "  Session: streamlit-port-forward"
            echo "  Port: 8501 (HTTP) -> 443 (HTTPS via nginx)"
        else
            echo "✗ Streamlit port-forward: Not running"
        fi
        echo ""
        if tmux has-session -t kibana-port-forward 2>/dev/null; then
            echo "✓ Kibana port-forward: Running"
            echo "  Session: kibana-port-forward"
            echo "  Port: 5601 (HTTP) -> 8443 (HTTPS via nginx)"
        else
            echo "✗ Kibana port-forward: Not running"
        fi
        echo ""
        if sudo systemctl is-active caddy-https-proxy.service &>/dev/null; then
            echo "✓ Caddy HTTPS proxy: Running"
            echo "  Service: caddy-https-proxy.service"
            echo "  HTTPS Port: 443 (Streamlit), 8443 (Kibana)"
        else
            echo "✗ Caddy HTTPS proxy: Not running"
            echo "  Start with: sudo systemctl start caddy-https-proxy.service"
        fi
        echo ""
        echo "All tmux sessions:"
        tmux ls 2>/dev/null || echo "No tmux sessions"
        ;;
        
    logs)
        SESSION="${2:-streamlit-port-forward}"
        if [ "$SESSION" = "caddy" ]; then
            echo "Viewing Caddy logs (Ctrl+C to exit)..."
            sudo journalctl -u caddy-https-proxy.service -f
        elif tmux has-session -t "$SESSION" 2>/dev/null; then
            echo "Attaching to $SESSION (Ctrl+B then D to detach)..."
            tmux attach -t "$SESSION"
        else
            echo "Session $SESSION not found"
            echo "Available sessions:"
            tmux ls 2>/dev/null || echo "No sessions"
            echo ""
            echo "To view Caddy logs: $0 logs caddy"
        fi
        ;;
        
    test)
        echo "=== Testing HTTPS Connections ==="
        echo ""
        echo "Testing Streamlit (HTTPS on port 443)..."
        if curl -k -s -o /dev/null -w "%{http_code}" https://localhost/ --max-time 5 | grep -q "200\|302\|301"; then
            echo "✓ Streamlit HTTPS: ACCESSIBLE"
        else
            echo "✗ Streamlit HTTPS: NOT ACCESSIBLE"
        fi
        
        echo ""
        echo "Testing Kibana (HTTPS on port 8443)..."
        if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443/ --max-time 5 | grep -q "200\|302\|301"; then
            echo "✓ Kibana HTTPS: ACCESSIBLE"
        else
            echo "✗ Kibana HTTPS: NOT ACCESSIBLE"
        fi
        
        echo ""
        echo "Testing HTTP redirects..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ --max-time 5)
        if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
            echo "✓ HTTP to HTTPS redirect: WORKING"
        else
            echo "⚠ HTTP redirect: Got code $HTTP_CODE"
        fi
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [session]|test}"
        echo ""
        echo "Commands:"
        echo "  start   - Start all port-forwards and Caddy"
        echo "  stop    - Stop all port-forwards and Caddy"
        echo "  restart - Restart all services"
        echo "  status  - Show status of all services"
        echo "  logs    - Attach to a tmux session or view Caddy logs"
        echo "           Examples: $0 logs streamlit-port-forward"
        echo "                     $0 logs caddy"
        echo "  test    - Test HTTPS connectivity"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 status"
        echo "  $0 logs streamlit-port-forward"
        echo "  $0 logs caddy"
        exit 1
        ;;
esac

