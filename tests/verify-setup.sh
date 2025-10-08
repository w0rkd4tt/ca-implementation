#!/bin/bash

################################################################################
# Script: verify-setup.sh
# Description: Kiểm tra và xác minh CA setup
# Usage: sudo ./verify-setup.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

CA_ROOT="/root/ca"

echo "========================================"
echo "  CA Setup Verification"
echo "========================================"
echo ""

# 1. Check OpenSSL
log_info "Checking OpenSSL..."
if command -v openssl &> /dev/null; then
    VERSION=$(openssl version | awk '{print $2}')
    log_pass "OpenSSL installed: $VERSION"
else
    log_fail "OpenSSL not found"
    exit 1
fi

# 2. Check directory structure
log_info "Checking directory structure..."

if [ -d "$CA_ROOT/rootca" ]; then
    log_pass "Root CA directory exists"
else
    log_fail "Root CA directory not found"
fi

if [ -d "$CA_ROOT/intermediate" ]; then
    log_pass "Intermediate CA directory exists"
else
    log_fail "Intermediate CA directory not found"
fi

# 3. Check Root CA files
log_info "Checking Root CA files..."

if [ -f "$CA_ROOT/rootca/private/ca.key.pem" ]; then
    log_pass "Root CA private key exists"

    # Check permissions
    PERMS=$(stat -c %a "$CA_ROOT/rootca/private/ca.key.pem" 2>/dev/null || stat -f %A "$CA_ROOT/rootca/private/ca.key.pem" 2>/dev/null)
    if [ "$PERMS" = "400" ]; then
        log_pass "Root CA key permissions correct (400)"
    else
        log_warn "Root CA key permissions: $PERMS (should be 400)"
    fi
else
    log_fail "Root CA private key not found"
fi

if [ -f "$CA_ROOT/rootca/certs/ca.cert.pem" ]; then
    log_pass "Root CA certificate exists"

    # Verify certificate
    if openssl x509 -in "$CA_ROOT/rootca/certs/ca.cert.pem" -noout -text &>/dev/null; then
        log_pass "Root CA certificate is valid"

        # Check if self-signed
        SUBJECT=$(openssl x509 -in "$CA_ROOT/rootca/certs/ca.cert.pem" -noout -subject | cut -d= -f2-)
        ISSUER=$(openssl x509 -in "$CA_ROOT/rootca/certs/ca.cert.pem" -noout -issuer | cut -d= -f2-)

        if [ "$SUBJECT" = "$ISSUER" ]; then
            log_pass "Root CA is self-signed"
        else
            log_fail "Root CA is not self-signed!"
        fi

        # Check expiration
        if openssl x509 -in "$CA_ROOT/rootca/certs/ca.cert.pem" -noout -checkend 0; then
            log_pass "Root CA certificate not expired"
        else
            log_fail "Root CA certificate is EXPIRED!"
        fi
    else
        log_fail "Root CA certificate is invalid"
    fi
else
    log_fail "Root CA certificate not found"
fi

# 4. Check Intermediate CA files
log_info "Checking Intermediate CA files..."

if [ -f "$CA_ROOT/intermediate/private/intermediate.key.pem" ]; then
    log_pass "Intermediate CA private key exists"

    PERMS=$(stat -c %a "$CA_ROOT/intermediate/private/intermediate.key.pem" 2>/dev/null || stat -f %A "$CA_ROOT/intermediate/private/intermediate.key.pem" 2>/dev/null)
    if [ "$PERMS" = "400" ]; then
        log_pass "Intermediate CA key permissions correct (400)"
    else
        log_warn "Intermediate CA key permissions: $PERMS (should be 400)"
    fi
else
    log_fail "Intermediate CA private key not found"
fi

if [ -f "$CA_ROOT/intermediate/certs/intermediate.cert.pem" ]; then
    log_pass "Intermediate CA certificate exists"

    # Verify certificate
    if openssl x509 -in "$CA_ROOT/intermediate/certs/intermediate.cert.pem" -noout -text &>/dev/null; then
        log_pass "Intermediate CA certificate is valid"

        # Check expiration
        if openssl x509 -in "$CA_ROOT/intermediate/certs/intermediate.cert.pem" -noout -checkend 0; then
            log_pass "Intermediate CA certificate not expired"
        else
            log_fail "Intermediate CA certificate is EXPIRED!"
        fi
    else
        log_fail "Intermediate CA certificate is invalid"
    fi
else
    log_fail "Intermediate CA certificate not found"
fi

# 5. Verify certificate chain
log_info "Verifying certificate chain..."

if [ -f "$CA_ROOT/intermediate/certs/ca-chain.cert.pem" ]; then
    log_pass "Certificate chain file exists"

    if openssl verify -CAfile "$CA_ROOT/rootca/certs/ca.cert.pem" \
        "$CA_ROOT/intermediate/certs/intermediate.cert.pem" &>/dev/null; then
        log_pass "Certificate chain verification: SUCCESS"
    else
        log_fail "Certificate chain verification: FAILED"
    fi
else
    log_fail "Certificate chain file not found"
fi

# 6. Check database files
log_info "Checking database files..."

if [ -f "$CA_ROOT/rootca/index.txt" ]; then
    log_pass "Root CA database exists"
else
    log_fail "Root CA database not found"
fi

if [ -f "$CA_ROOT/intermediate/index.txt" ]; then
    log_pass "Intermediate CA database exists"
else
    log_fail "Intermediate CA database not found"
fi

if [ -f "$CA_ROOT/rootca/serial" ]; then
    log_pass "Root CA serial file exists"
else
    log_fail "Root CA serial file not found"
fi

if [ -f "$CA_ROOT/intermediate/serial" ]; then
    log_pass "Intermediate CA serial file exists"
else
    log_fail "Intermediate CA serial file not found"
fi

# 7. Check CRL files
log_info "Checking CRL files..."

if [ -f "$CA_ROOT/intermediate/crl/intermediate.crl.pem" ]; then
    log_pass "Intermediate CA CRL exists"

    # Verify CRL
    if openssl crl -in "$CA_ROOT/intermediate/crl/intermediate.crl.pem" -noout &>/dev/null; then
        log_pass "CRL is valid"

        # Check CRL expiration
        NEXT_UPDATE=$(openssl crl -in "$CA_ROOT/intermediate/crl/intermediate.crl.pem" -noout -nextupdate | cut -d= -f2)
        log_info "CRL valid until: $NEXT_UPDATE"
    else
        log_fail "CRL is invalid"
    fi
else
    log_warn "Intermediate CA CRL not found (run: openssl ca -gencrl)"
fi

# 8. Check configuration files
log_info "Checking configuration files..."

if [ -f "$CA_ROOT/rootca/openssl.cnf" ]; then
    log_pass "Root CA config exists"
else
    log_fail "Root CA config not found"
fi

if [ -f "$CA_ROOT/intermediate/openssl.cnf" ]; then
    log_pass "Intermediate CA config exists"
else
    log_fail "Intermediate CA config not found"
fi

# 9. Security checks
log_info "Performing security checks..."

# Check private directory permissions
ROOT_PRIV_PERMS=$(stat -c %a "$CA_ROOT/rootca/private" 2>/dev/null || stat -f %A "$CA_ROOT/rootca/private" 2>/dev/null)
if [ "$ROOT_PRIV_PERMS" = "700" ]; then
    log_pass "Root CA private directory permissions correct (700)"
else
    log_warn "Root CA private directory permissions: $ROOT_PRIV_PERMS (should be 700)"
fi

INT_PRIV_PERMS=$(stat -c %a "$CA_ROOT/intermediate/private" 2>/dev/null || stat -f %A "$CA_ROOT/intermediate/private" 2>/dev/null)
if [ "$INT_PRIV_PERMS" = "700" ]; then
    log_pass "Intermediate CA private directory permissions correct (700)"
else
    log_warn "Intermediate CA private directory permissions: $INT_PRIV_PERMS (should be 700)"
fi

# 10. Test certificate operations (optional)
log_info "Testing certificate operations..."

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Generate test key
if openssl genrsa -out "$TEST_DIR/test.key.pem" 2048 &>/dev/null; then
    log_pass "Can generate private keys"
else
    log_fail "Cannot generate private keys"
fi

# Generate test CSR
if openssl req -new \
    -key "$TEST_DIR/test.key.pem" \
    -out "$TEST_DIR/test.csr.pem" \
    -subj "/C=VN/ST=Test/O=Test/CN=test.example.com" &>/dev/null; then
    log_pass "Can generate CSRs"
else
    log_fail "Cannot generate CSRs"
fi

echo ""
echo "========================================"
echo "  Summary"
echo "========================================"
echo -e "${GREEN}Passed:${NC} $PASS"
echo -e "${YELLOW}Warnings:${NC} $WARN"
echo -e "${RED}Failed:${NC} $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ CA setup verification: SUCCESS${NC}"
    echo ""
    echo "Your CA is ready to use!"
    echo ""
    echo "Next steps:"
    echo "  - Issue certificates: ./scripts/issue-certificate.sh"
    echo "  - Read documentation: docs/"
    echo "  - Check examples: examples/"
    exit 0
else
    echo -e "${RED}✗ CA setup verification: FAILED${NC}"
    echo ""
    echo "Please fix the issues above before proceeding."
    echo "See docs/05-troubleshooting.md for help."
    exit 1
fi
