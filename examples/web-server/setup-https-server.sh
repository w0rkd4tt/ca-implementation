#!/bin/bash

################################################################################
# Script: setup-https-server.sh
# Description: Demo HTTPS web server với SSL/TLS certificate từ CA
# Usage: ./setup-https-server.sh
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
DOMAIN="${1:-localhost}"
CA_ROOT="/root/ca"
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_DIR="$WORK_DIR/certs"

mkdir -p "$CERT_DIR"

log_info "Setting up HTTPS server for: $DOMAIN"

# Check if running as root (needed for cert creation)
if [[ $EUID -ne 0 ]]; then
   log_warn "Not running as root - will use existing certificates if available"
   USE_EXISTING=1
fi

# Generate certificate if needed
if [ -z "$USE_EXISTING" ]; then
    log_info "Generating SSL certificate..."

    # Generate private key
    openssl genrsa -out "$CERT_DIR/$DOMAIN.key" 2048

    # Generate CSR
    openssl req -new \
        -key "$CERT_DIR/$DOMAIN.key" \
        -out "$CERT_DIR/$DOMAIN.csr" \
        -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Example Org/CN=$DOMAIN"

    # Sign with CA (if available)
    if [ -d "$CA_ROOT/intermediate" ]; then
        log_info "Signing certificate with CA..."

        # Create temp config with SAN
        TMP_CONF=$(mktemp)
        cat "$CA_ROOT/intermediate/openssl.cnf" > "$TMP_CONF"
        cat >> "$TMP_CONF" << EOF

[ server_cert_san ]
basicConstraints = CA:FALSE
nsCertType = server
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $DOMAIN
DNS.2 = www.$DOMAIN
IP.1 = 127.0.0.1
EOF

        sudo openssl ca -config "$TMP_CONF" \
            -extensions server_cert_san \
            -days 375 -notext -md sha256 \
            -in "$CERT_DIR/$DOMAIN.csr" \
            -out "$CERT_DIR/$DOMAIN.crt" \
            -batch

        # Create bundle (server cert + intermediate cert)
        cat "$CERT_DIR/$DOMAIN.crt" \
            "$CA_ROOT/intermediate/certs/intermediate.cert.pem" > \
            "$CERT_DIR/$DOMAIN.bundle.crt"

        rm "$TMP_CONF"
    else
        log_warn "CA not found, creating self-signed certificate..."
        openssl x509 -req \
            -in "$CERT_DIR/$DOMAIN.csr" \
            -signkey "$CERT_DIR/$DOMAIN.key" \
            -out "$CERT_DIR/$DOMAIN.crt" \
            -days 365

        cp "$CERT_DIR/$DOMAIN.crt" "$CERT_DIR/$DOMAIN.bundle.crt"
    fi
else
    log_info "Using existing certificates or self-signed fallback"

    # Create self-signed cert for demo
    if [ ! -f "$CERT_DIR/$DOMAIN.key" ]; then
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout "$CERT_DIR/$DOMAIN.key" \
            -out "$CERT_DIR/$DOMAIN.crt" \
            -days 365 \
            -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Example Org/CN=$DOMAIN"

        cp "$CERT_DIR/$DOMAIN.crt" "$CERT_DIR/$DOMAIN.bundle.crt"
    fi
fi

# Create simple HTML page
cat > "$WORK_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>HTTPS Demo Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #2c3e50; }
        .success { color: #27ae60; font-weight: bold; }
        .info { background: #ecf0f1; padding: 15px; border-radius: 4px; margin: 20px 0; }
        code { background: #34495e; color: #ecf0f1; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 HTTPS Server Demo</h1>
        <p class="success">✓ Connection is secure!</p>

        <div class="info">
            <h3>Certificate Information</h3>
            <p>This server is using a certificate issued by your Custom CA.</p>
            <p>Check your browser's security indicator to view certificate details.</p>
        </div>

        <h3>Verify SSL/TLS:</h3>
        <pre><code>openssl s_client -connect localhost:8443 -showcerts</code></pre>

        <h3>Test with curl:</h3>
        <pre><code>curl --cacert /root/ca/intermediate/certs/ca-chain.cert.pem https://localhost:8443</code></pre>
    </div>
</body>
</html>
EOF

# Create Nginx configuration
cat > "$WORK_DIR/nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    server {
        listen 8080;
        server_name $DOMAIN;

        # Redirect to HTTPS
        return 301 https://\$server_name:8443\$request_uri;
    }

    server {
        listen 8443 ssl;
        server_name $DOMAIN;

        # SSL Certificate
        ssl_certificate $CERT_DIR/$DOMAIN.bundle.crt;
        ssl_certificate_key $CERT_DIR/$DOMAIN.key;

        # SSL Configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Security Headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;

        root $WORK_DIR;
        index index.html;

        location / {
            try_files \$uri \$uri/ =404;
        }
    }
}
EOF

# Create Apache configuration
cat > "$WORK_DIR/apache.conf" << EOF
<VirtualHost *:8080>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN:8443/
</VirtualHost>

<VirtualHost *:8443>
    ServerName $DOMAIN
    DocumentRoot $WORK_DIR

    SSLEngine on
    SSLCertificateFile $CERT_DIR/$DOMAIN.crt
    SSLCertificateKeyFile $CERT_DIR/$DOMAIN.key
    SSLCertificateChainFile $CA_ROOT/intermediate/certs/ca-chain.cert.pem

    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    SSLHonorCipherOrder on

    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"

    <Directory $WORK_DIR>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Create simple Python HTTPS server
cat > "$WORK_DIR/simple-https-server.py" << 'EOFPY'
#!/usr/bin/env python3
import http.server
import ssl
import os

PORT = 8443
CERT_FILE = os.path.join(os.path.dirname(__file__), 'certs', 'localhost.bundle.crt')
KEY_FILE = os.path.join(os.path.dirname(__file__), 'certs', 'localhost.key')

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Strict-Transport-Security', 'max-age=31536000; includeSubDomains')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'SAMEORIGIN')
        super().end_headers()

httpd = http.server.HTTPServer(('0.0.0.0', PORT), MyHTTPRequestHandler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(CERT_FILE, KEY_FILE)
context.minimum_version = ssl.TLSVersion.TLSv1_2

httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print(f"🔒 HTTPS Server running on https://localhost:{PORT}")
print(f"📄 Serving files from: {os.getcwd()}")
print("Press Ctrl+C to stop")

try:
    httpd.serve_forever()
except KeyboardInterrupt:
    print("\n🛑 Server stopped")
EOFPY

chmod +x "$WORK_DIR/simple-https-server.py"

# Summary
log_info "========================================"
log_info "HTTPS Server Setup Complete!"
log_info "========================================"
echo ""
echo "Certificates:"
echo "  Private Key: $CERT_DIR/$DOMAIN.key"
echo "  Certificate: $CERT_DIR/$DOMAIN.crt"
echo "  Bundle:      $CERT_DIR/$DOMAIN.bundle.crt"
echo ""
echo "Configuration Files:"
echo "  Nginx:  $WORK_DIR/nginx.conf"
echo "  Apache: $WORK_DIR/apache.conf"
echo ""
echo "Quick Start Options:"
echo ""
echo "1. Python Simple Server:"
echo "   cd $WORK_DIR && python3 simple-https-server.py"
echo ""
echo "2. Nginx:"
echo "   nginx -c $WORK_DIR/nginx.conf"
echo ""
echo "3. Apache:"
echo "   apache2 -f $WORK_DIR/apache.conf"
echo ""
echo "4. OpenSSL s_server (testing):"
echo "   openssl s_server -cert $CERT_DIR/$DOMAIN.crt \\"
echo "     -key $CERT_DIR/$DOMAIN.key -port 8443 -HTTP"
echo ""
echo "Test with:"
echo "  curl -k https://localhost:8443"
echo "  curl --cacert $CA_ROOT/intermediate/certs/ca-chain.cert.pem https://localhost:8443"
echo ""
log_warn "Add CA certificate to your browser to avoid security warnings!"
