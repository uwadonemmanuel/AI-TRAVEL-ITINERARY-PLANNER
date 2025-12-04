#!/bin/bash

# Aggressively find and kill processes using ports 80, 443, 8443

echo "=== Finding and killing processes on ports 80, 443, 8443 ==="
echo ""

for port in 80 443 8443; do
    echo "Port $port:"
    
    # Method 1: Using lsof
    PIDS=$(sudo lsof -ti :$port 2>/dev/null)
    if [ -n "$PIDS" ]; then
        for PID in $PIDS; do
            echo "  Found PID $PID using lsof"
            ps -p $PID -o pid,cmd --no-headers 2>/dev/null | sed 's/^/    /'
            sudo kill -9 $PID 2>/dev/null && echo "  ✓ Killed PID $PID" || echo "  ✗ Failed to kill PID $PID"
        done
    fi
    
    # Method 2: Using fuser
    FUSER_PIDS=$(sudo fuser $port/tcp 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/) print $i}')
    if [ -n "$FUSER_PIDS" ]; then
        for PID in $FUSER_PIDS; do
            if ! echo "$PIDS" | grep -q "^$PID$"; then
                echo "  Found PID $PID using fuser"
                ps -p $PID -o pid,cmd --no-headers 2>/dev/null | sed 's/^/    /'
                sudo kill -9 $PID 2>/dev/null && echo "  ✓ Killed PID $PID" || echo "  ✗ Failed to kill PID $PID"
            fi
        done
    fi
    
    # Method 3: Using netstat/ss
    NETSTAT_PIDS=$(sudo netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | grep -E '^[0-9]+$')
    if [ -n "$NETSTAT_PIDS" ]; then
        for PID in $NETSTAT_PIDS; do
            if ! echo "$PIDS $FUSER_PIDS" | grep -q "$PID"; then
                echo "  Found PID $PID using netstat"
                ps -p $PID -o pid,cmd --no-headers 2>/dev/null | sed 's/^/    /'
                sudo kill -9 $PID 2>/dev/null && echo "  ✓ Killed PID $PID" || echo "  ✗ Failed to kill PID $PID"
            fi
        done
    fi
    
    # Method 4: Using ss
    SS_PIDS=$(sudo ss -tlnp 2>/dev/null | grep ":$port " | grep -oP 'pid=\K[0-9]+')
    if [ -n "$SS_PIDS" ]; then
        for PID in $SS_PIDS; do
            if ! echo "$PIDS $FUSER_PIDS $NETSTAT_PIDS" | grep -q "$PID"; then
                echo "  Found PID $PID using ss"
                ps -p $PID -o pid,cmd --no-headers 2>/dev/null | sed 's/^/    /'
                sudo kill -9 $PID 2>/dev/null && echo "  ✓ Killed PID $PID" || echo "  ✗ Failed to kill PID $PID"
            fi
        done
    fi
    
    # Check if still in use
    sleep 1
    if sudo lsof -ti :$port &>/dev/null || sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "  ⚠ Port $port is still in use after killing processes"
    else
        echo "  ✓ Port $port is now free"
    fi
    echo ""
done

# Kill all nginx processes
echo "Killing all nginx processes..."
sudo pkill -9 nginx 2>/dev/null && echo "✓ Killed nginx processes" || echo "⚠ No nginx processes found"
sleep 2

echo ""
echo "=== Final Verification ==="
for port in 80 443 8443; do
    if sudo lsof -ti :$port &>/dev/null || sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "✗ Port $port is still in use:"
        sudo lsof -i :$port 2>/dev/null | tail -2
        sudo netstat -tlnp 2>/dev/null | grep ":$port " | head -2
    else
        echo "✓ Port $port is free"
    fi
done

