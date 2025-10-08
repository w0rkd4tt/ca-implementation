#!/bin/bash

################################################################################
# Script: revoke-certificate.sh
# Description: Thu hồi certificate và cập nhật CRL
# Usage: ./revoke-certificate.sh <certificate_file> [reason]
# Reasons: unspecified, keyCompromise, CACompromise, affiliationChanged,
#          superseded, cessationOfOperation, certificateHold
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
CERT_FILE="$1"
REVOKE_REASON="${2:-unspecified}"

# Usage
if [ -z "$CERT_FILE" ]; then
    echo "Usage: $0 <certificate_file> [reason]"
    echo ""
    echo "Revocation Reasons:"
    echo "  unspecified          - Default, no specific reason"
    echo "  keyCompromise        - Private key has been compromised"
    echo "  CACompromise         - CA has been compromised"
    echo "  affiliationChanged   - Subject's affiliation has changed"
    echo "  superseded           - Certificate has been superseded"
    echo "  cessationOfOperation - Certificate is no longer needed"
    echo "  certificateHold      - Temporary suspension (can be removed)"
    echo ""
    echo "Examples:"
    echo "  $0 /root/ca/intermediate/certs/www.example.com.cert.pem keyCompromise"
    echo "  $0 /root/ca/intermediate/certs/user.cert.pem superseded"
    exit 1
fi

# Validate certificate file
if [ ! -f "$CERT_FILE" ]; then
    log_error "Certificate file not found: $CERT_FILE"
    exit 1
fi

# Validate revocation reason
VALID_REASONS="unspecified keyCompromise CACompromise affiliationChanged superseded cessationOfOperation certificateHold"
if ! echo "$VALID_REASONS" | grep -qw "$REVOKE_REASON"; then
    log_error "Invalid revocation reason: $REVOKE_REASON"
    log_error "Valid reasons: $VALID_REASONS"
    exit 1
fi

# Display certificate information
log_info "Certificate to be revoked:"
echo ""
openssl x509 -noout -subject -issuer -serial -dates -in "$CERT_FILE"
echo ""

SERIAL=$(openssl x509 -noout -serial -in "$CERT_FILE" | cut -d= -f2)
log_info "Serial Number: $SERIAL"
log_info "Revocation Reason: $REVOKE_REASON"

# Confirm revocation
log_warn "This action cannot be undone (except for certificateHold)!"
read -p "Are you sure you want to revoke this certificate? (yes/NO): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "Revocation cancelled"
    exit 0
fi

# Revoke certificate
log_info "Revoking certificate..."

openssl ca -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
    -revoke "$CERT_FILE" \
    -crl_reason "$REVOKE_REASON"

log_info "Certificate revoked successfully"

# Update CRL
log_info "Updating Certificate Revocation List (CRL)..."

openssl ca -config "$INTERMEDIATE_CA_DIR/openssl.cnf" \
    -gencrl -out "$INTERMEDIATE_CA_DIR/crl/intermediate.crl.pem"

# Convert to DER format (for web distribution)
openssl crl -in "$INTERMEDIATE_CA_DIR/crl/intermediate.crl.pem" \
    -outform DER \
    -out "$INTERMEDIATE_CA_DIR/crl/intermediate.crl"

log_info "CRL updated successfully"

# Display CRL information
log_info "CRL Information:"
openssl crl -in "$INTERMEDIATE_CA_DIR/crl/intermediate.crl.pem" \
    -noout -text | grep -A 5 "Revoked Certificates:" || log_info "No details to display"

echo ""
echo "========================================"
echo "Revocation Summary"
echo "========================================"
echo "Serial Number:     $SERIAL"
echo "Reason:            $REVOKE_REASON"
echo "CRL Location:      $INTERMEDIATE_CA_DIR/crl/intermediate.crl.pem"
echo "CRL (DER):         $INTERMEDIATE_CA_DIR/crl/intermediate.crl"
echo ""

# Next steps
echo "========================================"
echo "Next Steps"
echo "========================================"
echo "1. Distribute updated CRL to web server:"
echo "   cp $INTERMEDIATE_CA_DIR/crl/intermediate.crl /var/www/html/crl/"
echo ""
echo "2. Verify revocation:"
echo "   openssl verify -crl_check -CAfile <ca-chain> -CRLfile <crl> $CERT_FILE"
echo ""
echo "3. For OCSP, restart OCSP responder if running"
echo ""

log_info "Revocation complete"

# Check if this was a hold - can be removed
if [ "$REVOKE_REASON" = "certificateHold" ]; then
    log_warn "This certificate is on HOLD and can be removed from CRL if needed"
    log_warn "To remove from CRL, manually edit: $INTERMEDIATE_CA_DIR/index.txt"
    log_warn "Change 'R' to 'V' for the certificate entry and regenerate CRL"
fi
