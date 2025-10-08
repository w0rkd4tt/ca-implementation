#!/bin/bash

################################################################################
# Script: setup-ca.sh
# Description: Tự động thiết lập Root CA và Intermediate CA
# Usage: sudo ./setup-ca.sh
# Author: CA Implementation Project
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Check OpenSSL version
check_openssl() {
    log_info "Checking OpenSSL version..."
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL is not installed. Please install it first."
        exit 1
    fi

    OPENSSL_VERSION=$(openssl version | awk '{print $2}')
    log_info "OpenSSL version: $OPENSSL_VERSION"
}

# Configuration variables
CA_ROOT="/root/ca"
ROOT_CA_DIR="$CA_ROOT/rootca"
INTERMEDIATE_CA_DIR="$CA_ROOT/intermediate"

# Default certificate information
COUNTRY="VN"
STATE="Hanoi"
LOCALITY="Hanoi"
ORGANIZATION="Example Organization"
ROOT_CN="Example Root CA"
INTERMEDIATE_CN="Example Intermediate CA"
EMAIL="ca@example.com"

# Prompt for custom values
configure_ca() {
    log_info "Configuring CA settings..."

    read -p "Country (2 letters) [$COUNTRY]: " input
    COUNTRY="${input:-$COUNTRY}"

    read -p "State/Province [$STATE]: " input
    STATE="${input:-$STATE}"

    read -p "Locality/City [$LOCALITY]: " input
    LOCALITY="${input:-$LOCALITY}"

    read -p "Organization Name [$ORGANIZATION]: " input
    ORGANIZATION="${input:-$ORGANIZATION}"

    read -p "Root CA Common Name [$ROOT_CN]: " input
    ROOT_CN="${input:-$ROOT_CN}"

    read -p "Intermediate CA Common Name [$INTERMEDIATE_CN]: " input
    INTERMEDIATE_CN="${input:-$INTERMEDIATE_CN}"

    read -p "Email Address [$EMAIL]: " input
    EMAIL="${input:-$EMAIL}"

    log_info "Configuration complete."
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."

    # Root CA directories
    mkdir -p "$ROOT_CA_DIR"/{certs,crl,newcerts,private}
    chmod 700 "$ROOT_CA_DIR/private"
    touch "$ROOT_CA_DIR/index.txt"
    echo 1000 > "$ROOT_CA_DIR/serial"
    echo 1000 > "$ROOT_CA_DIR/crlnumber"

    # Intermediate CA directories
    mkdir -p "$INTERMEDIATE_CA_DIR"/{certs,crl,csr,newcerts,private}
    chmod 700 "$INTERMEDIATE_CA_DIR/private"
    touch "$INTERMEDIATE_CA_DIR/index.txt"
    echo 1000 > "$INTERMEDIATE_CA_DIR/serial"
    echo 1000 > "$INTERMEDIATE_CA_DIR/crlnumber"

    log_info "Directory structure created at $CA_ROOT"
}

# Create Root CA OpenSSL configuration
create_root_ca_config() {
    log_info "Creating Root CA configuration file..."

    cat > "$ROOT_CA_DIR/openssl.cnf" << 'EOF'
# OpenSSL Root CA configuration file

[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /root/ca/rootca
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

private_key       = $dir/private/ca.key.pem
certificate       = $dir/certs/ca.cert.pem

crlnumber         = $dir/crlnumber
crl               = $dir/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ crl_ext ]
authorityKeyIdentifier=keyid:always

[ ocsp ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

    log_info "Root CA configuration created"
}

# Create Intermediate CA OpenSSL configuration
create_intermediate_ca_config() {
    log_info "Creating Intermediate CA configuration file..."

    cat > "$INTERMEDIATE_CA_DIR/openssl.cnf" << 'EOF'
# OpenSSL Intermediate CA configuration file

[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /root/ca/intermediate
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

private_key       = $dir/private/intermediate.key.pem
certificate       = $dir/certs/intermediate.cert.pem

crlnumber         = $dir/crlnumber
crl               = $dir/crl/intermediate.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_loose

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ client_cert ]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ crl_ext ]
authorityKeyIdentifier=keyid:always

[ ocsp ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

    log_info "Intermediate CA configuration created"
}

# Create Root CA
create_root_ca() {
    log_info "Creating Root CA..."

    # Generate Root CA private key
    log_info "Generating Root CA private key (4096-bit RSA)..."
    log_warn "You will be prompted to enter a passphrase. REMEMBER THIS PASSPHRASE!"

    # Prompt for passphrase
    read -s -p "Enter passphrase for Root CA private key: " ROOT_CA_PASS
    echo ""
    read -s -p "Verify passphrase for Root CA private key: " ROOT_CA_PASS_VERIFY
    echo ""

    if [ "$ROOT_CA_PASS" != "$ROOT_CA_PASS_VERIFY" ]; then
        log_error "Passphrases do not match!"
        exit 1
    fi

    if [ -z "$ROOT_CA_PASS" ]; then
        log_error "Passphrase cannot be empty!"
        exit 1
    fi

    openssl genpkey -algorithm RSA \
        -aes-256-cbc \
        -pkeyopt rsa_keygen_bits:4096 \
        -pass pass:"$ROOT_CA_PASS" \
        -out "$ROOT_CA_DIR/private/ca.key.pem"

    chmod 400 "$ROOT_CA_DIR/private/ca.key.pem"

    # Create Root CA certificate
    log_info "Creating Root CA certificate (20 years validity)..."

    openssl req -config "$ROOT_CA_DIR/openssl.cnf" \
        -key "$ROOT_CA_DIR/private/ca.key.pem" \
        -new -x509 -days 7300 -sha256 \
        -extensions v3_ca \
        -passin pass:"$ROOT_CA_PASS" \
        -out "$ROOT_CA_DIR/certs/ca.cert.pem" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGANIZATION Root CA/CN=$ROOT_CN/emailAddress=$EMAIL"

    chmod 444 "$ROOT_CA_DIR/certs/ca.cert.pem"

    log_info "Root CA created successfully"

    # Display certificate info
    log_info "Root CA Certificate Information:"
    openssl x509 -noout -text -in "$ROOT_CA_DIR/certs/ca.cert.pem" | grep -A 2 "Subject:"
}

# Create Intermediate CA
create_intermediate_ca() {
    log_info "Creating Intermediate CA..."

    # Generate Intermediate CA private key
    log_info "Generating Intermediate CA private key (4096-bit RSA)..."
    log_warn "You will be prompted to enter a passphrase for Intermediate CA."

    # Prompt for Intermediate CA passphrase
    read -s -p "Enter passphrase for Intermediate CA private key: " INTERMEDIATE_CA_PASS
    echo ""
    read -s -p "Verify passphrase for Intermediate CA private key: " INTERMEDIATE_CA_PASS_VERIFY
    echo ""

    if [ "$INTERMEDIATE_CA_PASS" != "$INTERMEDIATE_CA_PASS_VERIFY" ]; then
        log_error "Passphrases do not match!"
        exit 1
    fi

    if [ -z "$INTERMEDIATE_CA_PASS" ]; then
        log_error "Passphrase cannot be empty!"
        exit 1
    fi

    openssl genpkey -algorithm RSA \
        -aes-256-cbc \
        -pkeyopt rsa_keygen_bits:4096 \
        -pass pass:"$INTERMEDIATE_CA_PASS" \
        -out "$INTERMEDIATE_CA_DIR/private/intermediate.key.pem"

    chmod 400 "$INTERMEDIATE_CA_DIR/private/intermediate.key.pem"

    # Create Intermediate CA CSR
    log_info "Creating Intermediate CA CSR..."

    openssl req -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
        -new -sha256 \
        -key "$INTERMEDIATE_CA_DIR/private/intermediate.key.pem" \
        -passin pass:"$INTERMEDIATE_CA_PASS" \
        -out "$INTERMEDIATE_CA_DIR/csr/intermediate.csr.pem" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGANIZATION Intermediate CA/CN=$INTERMEDIATE_CN/emailAddress=$EMAIL"

    # Root CA signs Intermediate CA certificate
    log_info "Root CA signing Intermediate CA certificate (10 years validity)..."

    openssl ca -config "$ROOT_CA_DIR/openssl.cnf" \
        -extensions v3_intermediate_ca \
        -days 3650 -notext -md sha256 \
        -passin pass:"$ROOT_CA_PASS" \
        -in "$INTERMEDIATE_CA_DIR/csr/intermediate.csr.pem" \
        -out "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem" \
        -batch

    chmod 444 "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem"

    log_info "Intermediate CA created successfully"

    # Verify certificate chain
    log_info "Verifying certificate chain..."
    if openssl verify -CAfile "$ROOT_CA_DIR/certs/ca.cert.pem" \
        "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem"; then
        log_info "Certificate chain verification: SUCCESS"
    else
        log_error "Certificate chain verification: FAILED"
        exit 1
    fi

    # Create certificate chain file
    log_info "Creating certificate chain file..."
    cat "$INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem" \
        "$ROOT_CA_DIR/certs/ca.cert.pem" > \
        "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem"

    chmod 444 "$INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem"
}

# Generate initial CRLs
generate_crls() {
    log_info "Generating initial CRLs..."

    # Root CA CRL
    openssl ca -config "$ROOT_CA_DIR/openssl.cnf" \
        -passin pass:"$ROOT_CA_PASS" \
        -gencrl -out "$ROOT_CA_DIR/crl/ca.crl.pem"

    # Intermediate CA CRL
    openssl ca -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
        -passin pass:"$INTERMEDIATE_CA_PASS" \
        -gencrl -out "$INTERMEDIATE_CA_DIR/crl/intermediate.crl.pem"

    log_info "CRLs generated successfully"

    # Clear passphrases from memory
    unset ROOT_CA_PASS
    unset INTERMEDIATE_CA_PASS
}

# Create summary
create_summary() {
    log_info "========================================"
    log_info "CA Setup Complete!"
    log_info "========================================"
    echo ""
    echo "Root CA:"
    echo "  Location: $ROOT_CA_DIR"
    echo "  Certificate: $ROOT_CA_DIR/certs/ca.cert.pem"
    echo "  Private Key: $ROOT_CA_DIR/private/ca.key.pem"
    echo ""
    echo "Intermediate CA:"
    echo "  Location: $INTERMEDIATE_CA_DIR"
    echo "  Certificate: $INTERMEDIATE_CA_DIR/certs/intermediate.cert.pem"
    echo "  Private Key: $INTERMEDIATE_CA_DIR/private/intermediate.key.pem"
    echo "  Chain: $INTERMEDIATE_CA_DIR/certs/ca-chain.cert.pem"
    echo ""
    echo "Next steps:"
    echo "  1. Backup private keys securely"
    echo "  2. Use issue-certificate.sh to create certificates"
    echo "  3. Distribute Root CA certificate to clients"
    echo ""
    log_warn "IMPORTANT: Keep private keys and passphrases secure!"
    log_warn "IMPORTANT: Consider taking Root CA offline after setup"
}

# Main execution
main() {
    echo "========================================"
    echo "  CA Setup Script"
    echo "========================================"
    echo ""

    check_openssl
    configure_ca
    create_directories
    create_root_ca_config
    create_intermediate_ca_config
    create_root_ca
    create_intermediate_ca
    generate_crls
    create_summary
}

# Run main function
main
