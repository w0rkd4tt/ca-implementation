#!/bin/bash

################################################################################
# OCSP Responder Setup Script
################################################################################
# Script này thiết lập OCSP (Online Certificate Status Protocol) Responder
# để kiểm tra trạng thái certificate real-time
#
# Tác giả: W0rkkd4tt
# Email: datnguyenlequoc@2001.com
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CA_DIR="/root/ca"
INTERMEDIATE_DIR="$CA_DIR/intermediate"
OCSP_CONFIG="$INTERMEDIATE_DIR/ocsp.cnf"

# Logging function
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print header
print_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  OCSP Responder Setup Script"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if CA exists
check_ca_exists() {
    log_info "Checking CA setup..."

    if [[ ! -d "$INTERMEDIATE_DIR" ]]; then
        log_error "Intermediate CA not found at $INTERMEDIATE_DIR"
        log_error "Please run setup-ca.sh first"
        exit 1
    fi

    if [[ ! -f "$INTERMEDIATE_DIR/private/intermediate.key.pem" ]]; then
        log_error "Intermediate CA private key not found"
        exit 1
    fi

    log_success "CA setup verified"
}

# Create OCSP configuration
create_ocsp_config() {
    log_info "Creating OCSP configuration..."

    # Use the config from config/ directory if available
    if [[ -f "$CA_DIR/../config/ocsp.cnf" ]]; then
        cp "$CA_DIR/../config/ocsp.cnf" "$OCSP_CONFIG"
        log_success "OCSP configuration copied from template"
        return
    fi

    # Otherwise create a basic config
    cat > "$OCSP_CONFIG" << 'EOF'
[ default ]
name                    = intermediate
domain_suffix           = example.com
ocsp_url                = http://ocsp.$domain_suffix:8888
default_ca              = CA_default

[ CA_default ]
home                    = /root/ca
base_dir                = $home/$name
certificate             = $base_dir/certs/$name.cert.pem
private_key             = $base_dir/private/$name.key.pem
database                = $base_dir/index.txt
default_days            = 375
default_md              = sha256
policy                  = policy_loose

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits            = 2048
distinguished_name      = req_distinguished_name
string_mask             = utf8only
default_md              = sha256

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

countryName_default             = VN
stateOrProvinceName_default     = Hanoi
0.organizationName_default      = Example Organization
organizationalUnitName_default  = OCSP Services
commonName_default              = OCSP Responder

[ ocsp_cert ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

    log_success "OCSP configuration created at $OCSP_CONFIG"
}

# Generate OCSP signing key
generate_ocsp_key() {
    log_info "Generating OCSP signing key..."

    local ocsp_key="$INTERMEDIATE_DIR/private/ocsp.key.pem"

    if [[ -f "$ocsp_key" ]]; then
        log_warning "OCSP key already exists at $ocsp_key"
        read -p "Do you want to regenerate it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping key generation"
            return
        fi
        rm -f "$ocsp_key"
    fi

    openssl genrsa -out "$ocsp_key" 2048
    chmod 400 "$ocsp_key"

    log_success "OCSP key generated at $ocsp_key"
}

# Create OCSP signing certificate
create_ocsp_certificate() {
    log_info "Creating OCSP signing certificate..."

    local ocsp_key="$INTERMEDIATE_DIR/private/ocsp.key.pem"
    local ocsp_csr="$INTERMEDIATE_DIR/csr/ocsp.csr.pem"
    local ocsp_cert="$INTERMEDIATE_DIR/certs/ocsp.cert.pem"

    # Create CSR directory if not exists
    mkdir -p "$INTERMEDIATE_DIR/csr"

    # Check if certificate already exists
    if [[ -f "$ocsp_cert" ]]; then
        log_warning "OCSP certificate already exists at $ocsp_cert"

        # Check if it's still valid
        if openssl x509 -in "$ocsp_cert" -noout -checkend 86400 >/dev/null 2>&1; then
            log_info "Existing OCSP certificate is still valid"
            read -p "Do you want to regenerate it? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Using existing OCSP certificate"
                return
            fi
        else
            log_warning "Existing OCSP certificate has expired or will expire soon"
        fi
    fi

    # Create CSR
    log_info "Creating OCSP CSR..."
    openssl req -new -sha256 \
        -config "$OCSP_CONFIG" \
        -key "$ocsp_key" \
        -out "$ocsp_csr" \
        -subj "/C=VN/ST=Hanoi/O=Example Organization/OU=OCSP Services/CN=OCSP Responder"

    # Sign certificate
    log_info "Signing OCSP certificate..."

    # Check if the intermediate CA config has ocsp extension
    if ! grep -q "\[ ocsp_cert \]" "$INTERMEDIATE_DIR/openssl.cnf" 2>/dev/null; then
        log_info "Adding OCSP extension to intermediate CA config..."
        cat >> "$INTERMEDIATE_DIR/openssl.cnf" << 'EOF'

[ ocsp_cert ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF
    fi

    openssl ca -batch \
        -config "$INTERMEDIATE_DIR/openssl.cnf" \
        -extensions ocsp_cert \
        -days 375 \
        -notext \
        -md sha256 \
        -in "$ocsp_csr" \
        -out "$ocsp_cert"

    chmod 444 "$ocsp_cert"

    log_success "OCSP certificate created at $ocsp_cert"

    # Verify certificate
    log_info "Verifying OCSP certificate..."
    openssl x509 -in "$ocsp_cert" -noout -text | grep -A 1 "X509v3 Extended Key Usage"
}

# Create OCSP startup script
create_startup_script() {
    log_info "Creating OCSP responder startup script..."

    local startup_script="$INTERMEDIATE_DIR/ocsp-responder.sh"

    cat > "$startup_script" << 'EOF'
#!/bin/bash
# OCSP Responder Startup Script

INTERMEDIATE_DIR="/root/ca/intermediate"
OCSP_PORT=8888
LOG_FILE="/var/log/ocsp-responder.log"
PID_FILE="/var/run/ocsp-responder.pid"

# Check if already running
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "OCSP responder is already running (PID: $PID)"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# Start OCSP responder
echo "Starting OCSP responder on port $OCSP_PORT..."

nohup openssl ocsp \
    -port "$OCSP_PORT" \
    -text \
    -sha256 \
    -index "$INTERMEDIATE_DIR/index.txt" \
    -CA "$INTERMEDIATE_DIR/certs/ca-chain.cert.pem" \
    -rkey "$INTERMEDIATE_DIR/private/ocsp.key.pem" \
    -rsigner "$INTERMEDIATE_DIR/certs/ocsp.cert.pem" \
    > "$LOG_FILE" 2>&1 &

echo $! > "$PID_FILE"

echo "OCSP responder started (PID: $(cat $PID_FILE))"
echo "Log file: $LOG_FILE"
echo "Test with: openssl ocsp -CAfile ca-chain.cert.pem -url http://localhost:$OCSP_PORT -issuer intermediate.cert.pem -cert <certificate>"
EOF

    chmod +x "$startup_script"
    log_success "Startup script created at $startup_script"
}

# Create OCSP stop script
create_stop_script() {
    log_info "Creating OCSP responder stop script..."

    local stop_script="$INTERMEDIATE_DIR/ocsp-stop.sh"

    cat > "$stop_script" << 'EOF'
#!/bin/bash
# OCSP Responder Stop Script

PID_FILE="/var/run/ocsp-responder.pid"

if [[ ! -f "$PID_FILE" ]]; then
    echo "OCSP responder is not running"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "Stopping OCSP responder (PID: $PID)..."
    kill "$PID"
    rm -f "$PID_FILE"
    echo "OCSP responder stopped"
else
    echo "OCSP responder is not running (stale PID file)"
    rm -f "$PID_FILE"
fi
EOF

    chmod +x "$stop_script"
    log_success "Stop script created at $stop_script"
}

# Create systemd service file
create_systemd_service() {
    log_info "Creating systemd service file..."

    local service_file="/etc/systemd/system/ocsp-responder.service"

    cat > "$service_file" << EOF
[Unit]
Description=OCSP Responder for Certificate Authority
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/openssl ocsp -port 8888 -text -sha256 -index $INTERMEDIATE_DIR/index.txt -CA $INTERMEDIATE_DIR/certs/ca-chain.cert.pem -rkey $INTERMEDIATE_DIR/private/ocsp.key.pem -rsigner $INTERMEDIATE_DIR/certs/ocsp.cert.pem
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    log_success "Systemd service file created at $service_file"
    log_info "To enable and start service:"
    log_info "  sudo systemctl daemon-reload"
    log_info "  sudo systemctl enable ocsp-responder"
    log_info "  sudo systemctl start ocsp-responder"
}

# Print summary
print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  OCSP Responder Setup Complete!"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    log_success "OCSP signing certificate created"
    log_success "OCSP responder scripts created"
    echo ""
    echo "Start OCSP responder:"
    echo "  Method 1 (Manual):"
    echo "    $INTERMEDIATE_DIR/ocsp-responder.sh"
    echo ""
    echo "  Method 2 (Systemd):"
    echo "    sudo systemctl daemon-reload"
    echo "    sudo systemctl start ocsp-responder"
    echo "    sudo systemctl enable ocsp-responder"
    echo ""
    echo "Test OCSP responder:"
    echo "  openssl ocsp \\"
    echo "    -CAfile $INTERMEDIATE_DIR/certs/ca-chain.cert.pem \\"
    echo "    -url http://localhost:8888 \\"
    echo "    -issuer $INTERMEDIATE_DIR/certs/intermediate.cert.pem \\"
    echo "    -cert <path-to-certificate>"
    echo ""
    echo "Stop OCSP responder:"
    echo "  $INTERMEDIATE_DIR/ocsp-stop.sh"
    echo "  OR: sudo systemctl stop ocsp-responder"
    echo ""
    echo "View logs:"
    echo "  tail -f /var/log/ocsp-responder.log"
    echo "  OR: sudo journalctl -u ocsp-responder -f"
    echo ""
}

# Main execution
main() {
    print_header
    check_root
    check_ca_exists
    create_ocsp_config
    generate_ocsp_key
    create_ocsp_certificate
    create_startup_script
    create_stop_script

    # Create systemd service only on Linux
    if [[ -d "/etc/systemd/system" ]]; then
        create_systemd_service
    fi

    print_summary
}

# Run main function
main "$@"
