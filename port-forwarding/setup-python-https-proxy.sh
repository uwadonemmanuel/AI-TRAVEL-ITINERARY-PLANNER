#!/bin/bash

# Alternative: Python-based HTTPS reverse proxy (lightweight, no nginx needed)

set -e

echo "=== Setting up Python HTTPS Reverse Proxy ==="
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found"
    exit 1
fi

# Install required Python packages
echo "Installing Python dependencies..."
pip3 install --user pyopenssl 2>/dev/null || {
    sudo apt-get update
    sudo apt-get install -y python3-pip python3-venv
    pip3 install --user pyopenssl
}

# Create proxy directory
PROXY_DIR="$HOME/python-https-proxy"
mkdir -p "$PROXY_DIR"

# Create Python HTTPS proxy script
cat > "$PROXY_DIR/https_proxy.py" <<'PYTHON_EOF'
#!/usr/bin/env python3
"""
Simple HTTPS reverse proxy using Python
"""
import http.server
import socketserver
import urllib.request
import ssl
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

class ProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.proxy_request()
    
    def do_POST(self):
        self.proxy_request()
    
    def do_PUT(self):
        self.proxy_request()
    
    def do_DELETE(self):
        self.proxy_request()
    
    def proxy_request(self):
        # Determine target based on port
        if self.server.server_port == 443:
            target = 'http://localhost:8501'  # Streamlit
        elif self.server.server_port == 8443:
            target = 'http://localhost:5601'  # Kibana
        else:
            self.send_error(404)
            return
        
        url = target + self.path
        
        try:
            # Create request
            req = urllib.request.Request(url, method=self.command)
            
            # Copy headers
            for header, value in self.headers.items():
                if header.lower() not in ['host', 'connection']:
                    req.add_header(header, value)
            
            # Handle body for POST/PUT
            if self.command in ['POST', 'PUT']:
                content_length = int(self.headers.get('Content-Length', 0))
                if content_length > 0:
                    body = self.rfile.read(content_length)
                    req.data = body
            
            # Make request
            with urllib.request.urlopen(req, timeout=30) as response:
                # Send response
                self.send_response(response.getcode())
                
                # Copy headers
                for header, value in response.headers.items():
                    if header.lower() not in ['connection', 'transfer-encoding']:
                        self.send_header(header, value)
                
                self.end_headers()
                
                # Copy body
                self.wfile.write(response.read())
        
        except Exception as e:
            self.send_error(502, str(e))
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

def create_ssl_context():
    """Create SSL context with self-signed certificate"""
    import tempfile
    import subprocess
    import os
    
    cert_dir = os.path.expanduser('~/python-https-proxy/ssl')
    os.makedirs(cert_dir, exist_ok=True)
    
    cert_file = os.path.join(cert_dir, 'server.crt')
    key_file = os.path.join(cert_dir, 'server.key')
    
    # Generate self-signed certificate if it doesn't exist
    if not os.path.exists(cert_file):
        subprocess.run([
            'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
            '-keyout', key_file, '-out', cert_file,
            '-days', '365', '-nodes',
            '-subj', '/C=US/ST=State/L=City/O=Organization/CN=34.9.116.136'
        ], check=True, capture_output=True)
    
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert_file, key_file)
    return context

def run_proxy(port, handler_class):
    """Run HTTPS proxy on specified port"""
    with socketserver.TCPServer(("0.0.0.0", port), handler_class) as httpd:
        httpd.socket = create_ssl_context().wrap_socket(httpd.socket, server_side=True)
        print(f"HTTPS proxy running on port {port}")
        httpd.serve_forever()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 443
    run_proxy(port, ProxyHandler)
PYTHON_EOF

chmod +x "$PROXY_DIR/https_proxy.py"

# Create startup script
cat > "$PROXY_DIR/start-proxies.sh" <<'START_EOF'
#!/bin/bash
cd "$(dirname "$0")"

# Start Streamlit proxy (port 443)
python3 https_proxy.py 443 > /tmp/streamlit-proxy.log 2>&1 &
echo $! > /tmp/streamlit-proxy.pid

# Start Kibana proxy (port 8443)
python3 https_proxy.py 8443 > /tmp/kibana-proxy.log 2>&1 &
echo $! > /tmp/kibana-proxy.pid

echo "Python HTTPS proxies started"
echo "  Streamlit: https://34.9.116.136/"
echo "  Kibana:    https://34.9.116.136:8443/"
START_EOF

chmod +x "$PROXY_DIR/start-proxies.sh"

echo "✓ Python HTTPS proxy setup complete"
echo ""
echo "To start the proxies, run:"
echo "  $PROXY_DIR/start-proxies.sh"
echo ""
echo "Or start them in tmux:"
echo "  tmux new-session -d -s https-proxy-streamlit \"python3 $PROXY_DIR/https_proxy.py 443\""
echo "  tmux new-session -d -s https-proxy-kibana \"python3 $PROXY_DIR/https_proxy.py 8443\""

