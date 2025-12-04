#!/bin/bash

# Script to free up ports 80, 443, and 8443

echo "=== Finding processes using ports 80, 443, and 8443 ==="
echo ""

for port in 80 443 8443; do
    echo "Checking port $port..."
    
    # Find process using the port
    PID=$(sudo lsof -ti :$port 2>/dev/null || sudo fuser $port/tcp 2>/dev/null | awk '{print $1}')
    
    if [ -n "$PID" ]; then
        echo "  Port $port is in use by PID: $PID"
        ps -p $PID -o pid,cmd --no-headers 2>/dev/null | sed 's/^/    /'
        
        read -p "  Kill this process? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo kill -9 $PID 2>/dev/null && echo "  ✓ Killed PID $PID" || echo "  ✗ Failed to kill PID $PID"
        fi
    else
        # Try alternative method
        PROCESS=$(sudo netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | head -1)
        if [ -n "$PROCESS" ] && [ "$PROCESS" != "-" ]; then
            echo "  Port $port is in use by PID: $PROCESS"
            ps -p $PROCESS -o pid,cmd --no-headers 2>/dev/null | sed 's/^/    /'
            
            read -p "  Kill this process? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo kill -9 $PROCESS 2>/dev/null && echo "  ✓ Killed PID $PROCESS" || echo "  ✗ Failed to kill PID $PROCESS"
            fi
        else
            echo "  ✓ Port $port is free"
        fi
    fi
    echo ""
done

echo "=== Final Check ==="
for port in 80 443 8443; do
    if sudo lsof -ti :$port &>/dev/null || sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "⚠ Port $port is still in use"
    else
        echo "✓ Port $port is free"
    fi
done

