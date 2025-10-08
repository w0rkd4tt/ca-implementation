#!/bin/bash

################################################################################
# Script: issue-certificate.sh
# Description: Cấp phát SSL/TLS certificate
# Usage: ./issue-certificate.sh <type> <common_name> [san_names...]
#        Types: server, client, email
# Example: ./issue-certificate.sh server www.example.com example.com mail.example.com
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
CA_ROOT="/root/ca"
INTERMEDIATE_CA_DIR="$CA_ROOT/intermediate"
CERT_TYPE="$1"
COMMON_NAME="$2"
shift 2
SAN_NAMES=("$@")

# Validate arguments
if [ -z "$CERT_TYPE" ] || [ -z "$COMMON_NAME" ]; then
    echo "Usage: $0 <type> <common_name> [san_names...]"
    echo ""
    echo "Certificate Types:"
    echo "  server  - Server certificate (TLS/SSL)"
    echo "  client  - Client certificate (mTLS, VPN)"
    echo "  email   - Email certificate (S/MIME)"
    echo ""
    echo "Examples:"
    echo "  $0 server www.example.com example.com"
    echo "  $0 client user@example.com"
    echo "  $0 email john.doe@example.com"
    exit 1
fi

# Validate certificate type
if [[ ! "$CERT_TYPE" =~ ^(server|client|email)$ ]]; then
    log_error "Invalid certificate type: $CERT_TYPE"
    log_error "Valid types: server, client, email"
    exit 1
fi

# Sanitize common name for filename
SAFE_CN=$(echo "$COMMON_NAME" | tr '/' '_' | tr ' ' '_')
KEY_FILE="$INTERMEDIATE_CA_DIR/private/${SAFE_CN}.key.pem"
CSR_FILE="$INTERMEDIATE_CA_DIR/csr/${SAFE_CN}.csr.pem"
CERT_FILE="$INTERMEDIATE_CA_DIR/certs/${SAFE_CN}.cert.pem"

# Check if certificate already exists
if [ -f "$CERT_FILE" ]; then
    log_warn "Certificate already exists: $CERT_FILE"
    read -p "Overwrite? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi
fi

# Certificate validity days
case $CERT_TYPE in
    server)
        VALIDITY_DAYS=398  # CA/Browser Forum requirement: max 398 days
        EXTENSIONS="server_cert"
        ;;
    client|email)
        VALIDITY_DAYS=365  # 1 year
        EXTENSIONS="client_cert"
        ;;
esac

log_info "Generating certificate for: $COMMON_NAME"
log_info "Type: $CERT_TYPE"
log_info "Validity: $VALIDITY_DAYS days"

# Generate private key
log_info "Generating private key (2048-bit RSA)..."
openssl genrsa -out "$KEY_FILE" 2048
chmod 400 "$KEY_FILE"

# Create CSR
log_info "Creating Certificate Signing Request..."

# Build subject string
SUBJECT="/CN=$COMMON_NAME"

# Additional subject fields
read -p "Country (2 letters) [VN]: " COUNTRY
COUNTRY=${COUNTRY:-VN}
SUBJECT="$SUBJECT/C=$COUNTRY"

read -p "State/Province [Hanoi]: " STATE
STATE=${STATE:-Hanoi}
SUBJECT="$SUBJECT/ST=$STATE"

read -p "Locality/City [Hanoi]: " LOCALITY
LOCALITY=${LOCALITY:-Hanoi}
SUBJECT="$SUBJECT/L=$LOCALITY"

read -p "Organization []: " ORG
if [ -n "$ORG" ]; then
    SUBJECT="$SUBJECT/O=$ORG"
fi

read -p "Organizational Unit []: " OU
if [ -n "$OU" ]; then
    SUBJECT="$SUBJECT/OU=$OU"
fi

read -p "Email Address []: " EMAIL
if [ -n "$EMAIL" ]; then
    SUBJECT="$SUBJECT/emailAddress=$EMAIL"
fi

# For server certificates, handle SAN (Subject Alternative Names)
if [ "$CERT_TYPE" = "server" ]; then
    # Create temporary config for SAN
    SAN_CONFIG=$(mktemp)
    cat "$INTERMEDIATE_CA_DIR/openssl.cnf" > "$SAN_CONFIG"

    # Add SAN section
    echo "" >> "$SAN_CONFIG"
    echo "[ san_ext ]" >> "$SAN_CONFIG"
    echo "subjectAltName = @alt_names" >> "$SAN_CONFIG"
    echo "" >> "$SAN_CONFIG"
    echo "[ alt_names ]" >> "$SAN_CONFIG"
    echo "DNS.1 = $COMMON_NAME" >> "$SAN_CONFIG"

    # Add additional SAN names
    COUNTER=2
    for san in "${SAN_NAMES[@]}"; do
        echo "DNS.$COUNTER = $san" >> "$SAN_CONFIG"
        ((COUNTER++))
    done

    # Create CSR with SAN
    openssl req -config "$SAN_CONFIG" \
        -key "$KEY_FILE" \
        -new -sha256 \
        -out "$CSR_FILE" \
        -subj "$SUBJECT" \
        -reqexts san_ext

    rm "$SAN_CONFIG"
else
    # Create CSR without SAN
    openssl req -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
        -key "$KEY_FILE" \
        -new -sha256 \
        -out "$CSR_FILE" \
        -subj "$SUBJECT"
fi

# Display CSR
log_info "Certificate Signing Request created"
log_info "CSR Details:"
openssl req -text -noout -in "$CSR_FILE" | grep -A 1 "Subject:"

# Sign certificate
log_info "Signing certificate with Intermediate CA..."
log_warn "You will be prompted for Intermediate CA passphrase"

if [ "$CERT_TYPE" = "server" ]; then
    # For server certs, we need to preserve SAN extensions
    SAN_CONFIG=$(mktemp)
    cat "$INTERMEDIATE_CA_DIR/openssl.cnf" > "$SAN_CONFIG"

    echo "" >> "$SAN_CONFIG"
    echo "[ san_ext ]" >> "$SAN_CONFIG"
    echo "subjectAltName = @alt_names" >> "$SAN_CONFIG"
    echo "" >> "$SAN_CONFIG"
    echo "[ alt_names ]" >> "$SAN_CONFIG"
    echo "DNS.1 = $COMMON_NAME" >> "$SAN_CONFIG"

    COUNTER=2
    for san in "${SAN_NAMES[@]}"; do
        echo "DNS.$COUNTER = $san" >> "$SAN_CONFIG"
        ((COUNTER++))
    done

    # Modify server_cert section to include SAN
    cat >> "$SAN_CONFIG" << 'EOFSAN'

[ server_cert_with_san ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
EOFSAN

    openssl ca -config "$SAN_CONFIG" \
        -extensions server_cert_with_san \
        -days "$VALIDITY_DAYS" -notext -md sha256 \
        -in "$CSR_FILE" \
        -out "$CERT_FILE" \
        -batch

    rm "$SAN_CONFIG"
else
    openssl ca -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
        -extensions "$EXTENSIONS" \
        -days "$VALIDITY_DAYS" -notext -md sha256 \
        -in "$CSR_FILE" \
        -out "$CERT_FILE" \
        -batch
fi

chmod 444 "$CERT_FILE"

# Verify certificate
log_info "Verifying certificate..."
if openssl verify -CAfile "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem" "$CERT_FILE"; then
    log_info "Certificate verification: SUCCESS"
else
    log_error "Certificate verification: FAILED"
    exit 1
fi

# Create bundle for deployment
BUNDLE_FILE="$INTERMEDIATE_CA_DIR/certs/${SAFE_CN}.bundle.pem"
cat "$CERT_FILE" "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem" > "$BUNDLE_FILE"
chmod 444 "$BUNDLE_FILE"

# Display certificate info
log_info "Certificate issued successfully!"
echo ""
echo "========================================"
echo "Certificate Information"
echo "========================================"
openssl x509 -noout -text -in "$CERT_FILE" | grep -A 5 "Subject:"
openssl x509 -noout -text -in "$CERT_FILE" | grep -A 1 "Validity"
openssl x509 -noout -text -in "$CERT_FILE" | grep "DNS:" || true

echo ""
echo "========================================"
echo "Files Generated"
echo "========================================"
echo "Private Key:       $KEY_FILE"
echo "CSR:               $CSR_FILE"
echo "Certificate:       $CERT_FILE"
echo "Bundle (cert+chain): $BUNDLE_FILE"
echo ""

# Usage instructions
echo "========================================"
echo "Usage Instructions"
echo "========================================"

case $CERT_TYPE in
    server)
        echo "For Apache:"
        echo "  SSLCertificateFile      $CERT_FILE"
        echo "  SSLCertificateKeyFile   $KEY_FILE"
        echo "  SSLCertificateChainFile $INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem"
        echo ""
        echo "For Nginx:"
        echo "  ssl_certificate         $BUNDLE_FILE"
        echo "  ssl_certificate_key     $KEY_FILE"
        ;;
    client)
        echo "For client authentication:"
        echo "  1. Combine cert and key:"
        echo "     cat $CERT_FILE $KEY_FILE > client.pem"
        echo "  2. Create PKCS#12 bundle:"
        echo "     openssl pkcs12 -export -out ${SAFE_CN}.p12 \\"
        echo "       -inkey $KEY_FILE \\"
        echo "       -in $CERT_FILE \\"
        echo "       -certfile $INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem"
        ;;
    email)
        echo "For S/MIME email signing:"
        echo "  1. Create PKCS#12 for email client:"
        echo "     openssl pkcs12 -export -out ${SAFE_CN}.p12 \\"
        echo "       -inkey $KEY_FILE \\"
        echo "       -in $CERT_FILE \\"
        echo "       -certfile $INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem"
        echo "  2. Import ${SAFE_CN}.p12 into your email client"
        ;;
esac

echo ""
log_warn "Keep private key secure!"
log_info "Certificate Serial Number: $(openssl x509 -noout -serial -in $CERT_FILE | cut -d= -f2)"
