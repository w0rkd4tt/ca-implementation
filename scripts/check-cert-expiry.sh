#!/bin/bash

################################################################################
# Script: check-cert-expiry.sh
# Description: Kiểm tra thời hạn của certificate (local hoặc remote web server)
# Usage: ./check-cert-expiry.sh [options]
#        ./check-cert-expiry.sh -f /path/to/cert.pem
#        ./check-cert-expiry.sh -h example.com -p 443
# Author: CA Implementation Project
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }

# Default values
WARNING_DAYS=30
CRITICAL_DAYS=7
CA_ROOT="/root/ca"

# Parse arguments
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Kiểm tra thời hạn certificate

OPTIONS:
    -f FILE         Check certificate file
    -h HOST         Check remote host certificate
    -p PORT         Port (default: 443)
    -w DAYS         Warning threshold in days (default: 30)
    -c DAYS         Critical threshold in days (default: 7)
    -a              Check all certificates in CA
    --help          Show this help message

EXAMPLES:
    # Check local certificate file
    $0 -f /root/ca/intermediate/certs/example.pki.cert.pem

    # Check remote web server
    $0 -h example.pki -p 443

    # Check all certificates in CA
    $0 -a

    # Check with custom thresholds
    $0 -h example.com -w 60 -c 14

EOF
}

# Check certificate expiry from file
check_cert_file() {
    local cert_file="$1"

    if [ ! -f "$cert_file" ]; then
        log_error "Certificate file not found: $cert_file"
        return 1
    fi

    # Get certificate info
    local subject=$(openssl x509 -noout -subject -in "$cert_file" | sed 's/subject=//')
    local issuer=$(openssl x509 -noout -issuer -in "$cert_file" | sed 's/issuer=//')
    local start_date=$(openssl x509 -noout -startdate -in "$cert_file" | cut -d= -f2)
    local end_date=$(openssl x509 -noout -enddate -in "$cert_file" | cut -d= -f2)
    local serial=$(openssl x509 -noout -serial -in "$cert_file" | cut -d= -f2)

    # Calculate days until expiry
    local end_epoch=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local days_left=$(( ($end_epoch - $now_epoch) / 86400 ))

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Certificate: $cert_file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Subject:     $subject"
    echo "Issuer:      $issuer"
    echo "Serial:      $serial"
    echo "Valid From:  $start_date"
    echo "Valid Until: $end_date"
    echo ""

    # Status check
    if [ $days_left -lt 0 ]; then
        log_error "EXPIRED $((-days_left)) days ago!"
        echo "Status: ❌ EXPIRED"
        return 1
    elif [ $days_left -le $CRITICAL_DAYS ]; then
        log_error "CRITICAL: Expires in $days_left days!"
        echo "Status: 🔴 CRITICAL - Expires in $days_left days"
        return 2
    elif [ $days_left -le $WARNING_DAYS ]; then
        log_warn "WARNING: Expires in $days_left days"
        echo "Status: ⚠️  WARNING - Expires in $days_left days"
        return 3
    else
        log_ok "Valid for $days_left days"
        echo "Status: ✅ OK - Valid for $days_left days"
        return 0
    fi
}

# Check remote host certificate
check_remote_cert() {
    local host="$1"
    local port="${2:-443}"

    log_info "Checking certificate for $host:$port..."

    # Get certificate from server
    local cert_info=$(echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null)

    if [ -z "$cert_info" ]; then
        log_error "Failed to retrieve certificate from $host:$port"
        return 1
    fi

    # Extract information
    local subject=$(echo "$cert_info" | grep "subject=" | sed 's/subject=//')
    local issuer=$(echo "$cert_info" | grep "issuer=" | sed 's/issuer=//')
    local start_date=$(echo "$cert_info" | grep "notBefore=" | cut -d= -f2)
    local end_date=$(echo "$cert_info" | grep "notAfter=" | cut -d= -f2)

    # Calculate days until expiry
    local end_epoch=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local days_left=$(( ($end_epoch - $now_epoch) / 86400 ))

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Remote Host: $host:$port"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Subject:     $subject"
    echo "Issuer:      $issuer"
    echo "Valid From:  $start_date"
    echo "Valid Until: $end_date"
    echo ""

    # Status check
    if [ $days_left -lt 0 ]; then
        log_error "EXPIRED $((-days_left)) days ago!"
        echo "Status: ❌ EXPIRED"
        return 1
    elif [ $days_left -le $CRITICAL_DAYS ]; then
        log_error "CRITICAL: Expires in $days_left days!"
        echo "Status: 🔴 CRITICAL - Expires in $days_left days"
        return 2
    elif [ $days_left -le $WARNING_DAYS ]; then
        log_warn "WARNING: Expires in $days_left days"
        echo "Status: ⚠️  WARNING - Expires in $days_left days"
        return 3
    else
        log_ok "Valid for $days_left days"
        echo "Status: ✅ OK - Valid for $days_left days"
        return 0
    fi
}

# Check all certificates in CA
check_all_ca_certs() {
    log_info "Checking all certificates in CA..."
    echo ""

    local exit_code=0

    # Check Root CA
    if [ -f "$CA_ROOT/rootca/certs/ca.cert.pem" ]; then
        echo -e "${BLUE}=== Root CA Certificate ===${NC}"
        check_cert_file "$CA_ROOT/rootca/certs/ca.cert.pem"
        [ $? -ne 0 ] && exit_code=1
    fi

    # Check Intermediate CA
    if [ -f "$CA_ROOT/intermediate/certs/intermediate.cert.pem" ]; then
        echo -e "\n${BLUE}=== Intermediate CA Certificate ===${NC}"
        check_cert_file "$CA_ROOT/intermediate/certs/intermediate.cert.pem"
        [ $? -ne 0 ] && exit_code=1
    fi

    # Check all issued certificates
    if [ -d "$CA_ROOT/intermediate/certs" ]; then
        echo -e "\n${BLUE}=== Issued Certificates ===${NC}"
        for cert in "$CA_ROOT/intermediate/certs"/*.cert.pem; do
            if [ -f "$cert" ] && [[ ! "$cert" =~ intermediate\.cert\.pem$ ]]; then
                check_cert_file "$cert"
                [ $? -ne 0 ] && exit_code=1
            fi
        done
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Thresholds:"
    echo "  Warning:  ≤ $WARNING_DAYS days"
    echo "  Critical: ≤ $CRITICAL_DAYS days"
    echo ""

    return $exit_code
}

# Parse command line arguments
CHECK_ALL=0
CERT_FILE=""
REMOTE_HOST=""
REMOTE_PORT=443

while [ $# -gt 0 ]; do
    case "$1" in
        -f)
            CERT_FILE="$2"
            shift 2
            ;;
        -h)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -p)
            REMOTE_PORT="$2"
            shift 2
            ;;
        -w)
            WARNING_DAYS="$2"
            shift 2
            ;;
        -c)
            CRITICAL_DAYS="$2"
            shift 2
            ;;
        -a)
            CHECK_ALL=1
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main logic
if [ $CHECK_ALL -eq 1 ]; then
    check_all_ca_certs
elif [ -n "$CERT_FILE" ]; then
    check_cert_file "$CERT_FILE"
elif [ -n "$REMOTE_HOST" ]; then
    check_remote_cert "$REMOTE_HOST" "$REMOTE_PORT"
else
    log_error "No option specified"
    echo ""
    show_usage
    exit 1
fi

exit $?
