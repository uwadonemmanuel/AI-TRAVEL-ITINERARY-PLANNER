#!/bin/bash

# Port Forward Service Script
# This script manages kubectl port-forward processes

STREAMLIT_PID_FILE="/tmp/streamlit-port-forward.pid"
KIBANA_PID_FILE="/tmp/kibana-port-forward.pid"

start_streamlit() {
    if [ -f "$STREAMLIT_PID_FILE" ] && kill -0 $(cat "$STREAMLIT_PID_FILE") 2>/dev/null; then
        echo "Streamlit port-forward is already running (PID: $(cat $STREAMLIT_PID_FILE))"
        return 1
    fi
    
    nohup kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0 > /tmp/streamlit-port-forward.log 2>&1 &
    echo $! > "$STREAMLIT_PID_FILE"
    echo "Streamlit port-forward started (PID: $(cat $STREAMLIT_PID_FILE))"
}

stop_streamlit() {
    if [ -f "$STREAMLIT_PID_FILE" ]; then
        PID=$(cat "$STREAMLIT_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "Streamlit port-forward stopped (PID: $PID)"
        else
            echo "Streamlit port-forward process not found"
        fi
        rm -f "$STREAMLIT_PID_FILE"
    else
        echo "Streamlit port-forward is not running"
    fi
}

start_kibana() {
    if [ -f "$KIBANA_PID_FILE" ] && kill -0 $(cat "$KIBANA_PID_FILE") 2>/dev/null; then
        echo "Kibana port-forward is already running (PID: $(cat $KIBANA_PID_FILE))"
        return 1
    fi
    
    nohup kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0 > /tmp/kibana-port-forward.log 2>&1 &
    echo $! > "$KIBANA_PID_FILE"
    echo "Kibana port-forward started (PID: $(cat $KIBANA_PID_FILE))"
}

stop_kibana() {
    if [ -f "$KIBANA_PID_FILE" ]; then
        PID=$(cat "$KIBANA_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "Kibana port-forward stopped (PID: $PID)"
        else
            echo "Kibana port-forward process not found"
        fi
        rm -f "$KIBANA_PID_FILE"
    else
        echo "Kibana port-forward is not running"
    fi
}

status() {
    echo "=== Port-Forward Status ==="
    if [ -f "$STREAMLIT_PID_FILE" ] && kill -0 $(cat "$STREAMLIT_PID_FILE") 2>/dev/null; then
        echo "Streamlit: Running (PID: $(cat $STREAMLIT_PID_FILE))"
    else
        echo "Streamlit: Not running"
    fi
    
    if [ -f "$KIBANA_PID_FILE" ] && kill -0 $(cat "$KIBANA_PID_FILE") 2>/dev/null; then
        echo "Kibana: Running (PID: $(cat $KIBANA_PID_FILE))"
    else
        echo "Kibana: Not running"
    fi
}

case "$1" in
    start)
        start_streamlit
        start_kibana
        ;;
    stop)
        stop_streamlit
        stop_kibana
        ;;
    restart)
        stop_streamlit
        stop_kibana
        sleep 2
        start_streamlit
        start_kibana
        ;;
    status)
        status
        ;;
    start-streamlit)
        start_streamlit
        ;;
    stop-streamlit)
        stop_streamlit
        ;;
    start-kibana)
        start_kibana
        ;;
    stop-kibana)
        stop_kibana
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|start-streamlit|stop-streamlit|start-kibana|stop-kibana}"
        exit 1
        ;;
esac

exit 0


