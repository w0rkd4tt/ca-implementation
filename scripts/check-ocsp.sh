#!/bin/bash

################################################################################
# OCSP Status Checker Script
################################################################################
# Script này kiểm tra trạng thái certificate thông qua OCSP
# Hỗ trợ kiểm tra local certificate hoặc remote HTTPS server
#
# Tác giả: W0rkkd4tt
# Email: datnguyenlequoc@2001.com
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration defaults
CA_DIR="/root/ca"
INTERMEDIATE_DIR="$CA_DIR/intermediate"
OCSP_URL="http://localhost:8888"
OCSP_HOST=""
OCSP_PORT=""

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OCSP Status Checker - Kiểm tra trạng thái certificate qua OCSP

OPTIONS:
    -f <file>       Certificate file to check
    -h <host>       Remote HTTPS host to check
    -p <port>       Remote HTTPS port (default: 443)
    -u <url>        OCSP responder URL (default: http://localhost:8888)
    -i <issuer>     Issuer certificate path (default: auto-detect)
    -c <ca-file>    CA chain file (default: auto-detect)
    -v              Verbose output
    --help          Show this help message

EXAMPLES:
    # Check local certificate file
    $0 -f /root/ca/intermediate/certs/server.cert.pem

    # Check remote HTTPS server
    $0 -h www.example.com -p 443

    # Use custom OCSP URL
    $0 -f server.cert.pem -u http://ocsp.example.com:8888

    # Check with verbose output
    $0 -f server.cert.pem -v

EXIT CODES:
    0 - Certificate is GOOD
    1 - Certificate is REVOKED or ERROR
    2 - OCSP responder not available

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    CERT_FILE=""
    REMOTE_HOST=""
    REMOTE_PORT="443"
    ISSUER_CERT=""
    CA_CHAIN=""
    VERBOSE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
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
            -u)
                OCSP_URL="$2"
                shift 2
                ;;
            -i)
                ISSUER_CERT="$2"
                shift 2
                ;;
            -c)
                CA_CHAIN="$2"
                shift 2
                ;;
            -v)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate input
    if [[ -z "$CERT_FILE" && -z "$REMOTE_HOST" ]]; then
        log_error "Either -f (certificate file) or -h (remote host) must be specified"
        echo ""
        usage
    fi

    if [[ -n "$CERT_FILE" && -n "$REMOTE_HOST" ]]; then
        log_error "Cannot specify both -f and -h options"
        echo ""
        usage
    fi
}

# Auto-detect CA files
detect_ca_files() {
    if [[ -z "$CA_CHAIN" ]]; then
        if [[ -f "$INTERMEDIATE_DIR/certs/ca-chain.cert.pem" ]]; then
            CA_CHAIN="$INTERMEDIATE_DIR/certs/ca-chain.cert.pem"
            [[ "$VERBOSE" == true ]] && log_info "Auto-detected CA chain: $CA_CHAIN"
        else
            log_error "Cannot find CA chain file"
            exit 1
        fi
    fi

    if [[ -z "$ISSUER_CERT" ]]; then
        if [[ -f "$INTERMEDIATE_DIR/certs/intermediate.cert.pem" ]]; then
            ISSUER_CERT="$INTERMEDIATE_DIR/certs/intermediate.cert.pem"
            [[ "$VERBOSE" == true ]] && log_info "Auto-detected issuer cert: $ISSUER_CERT"
        else
            log_error "Cannot find issuer certificate"
            exit 1
        fi
    fi
}

# Get certificate from remote server
get_remote_certificate() {
    local host="$1"
    local port="$2"
    local temp_cert="/tmp/ocsp-check-$$.pem"

    log_info "Fetching certificate from ${host}:${port}..."

    # Use openssl s_client to get the certificate
    if ! echo | openssl s_client -connect "${host}:${port}" -servername "$host" 2>/dev/null | \
        openssl x509 -outform PEM > "$temp_cert" 2>/dev/null; then
        log_error "Failed to fetch certificate from ${host}:${port}"
        rm -f "$temp_cert"
        exit 1
    fi

    if [[ ! -s "$temp_cert" ]]; then
        log_error "Empty certificate received from ${host}:${port}"
        rm -f "$temp_cert"
        exit 1
    fi

    log_success "Certificate fetched successfully"
    echo "$temp_cert"
}

# Display certificate info
show_cert_info() {
    local cert="$1"

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  Certificate Information"
    echo "═══════════════════════════════════════════════════════════════════"

    # Subject
    local subject=$(openssl x509 -in "$cert" -noout -subject | sed 's/subject=//')
    echo -e "${CYAN}Subject:${NC} $subject"

    # Issuer
    local issuer=$(openssl x509 -in "$cert" -noout -issuer | sed 's/issuer=//')
    echo -e "${CYAN}Issuer:${NC} $issuer"

    # Serial
    local serial=$(openssl x509 -in "$cert" -noout -serial | sed 's/serial=//')
    echo -e "${CYAN}Serial:${NC} $serial"

    # Validity
    local not_before=$(openssl x509 -in "$cert" -noout -startdate | sed 's/notBefore=//')
    local not_after=$(openssl x509 -in "$cert" -noout -enddate | sed 's/notAfter=//')
    echo -e "${CYAN}Valid From:${NC} $not_before"
    echo -e "${CYAN}Valid Until:${NC} $not_after"

    # Check expiry
    if openssl x509 -in "$cert" -noout -checkend 0 >/dev/null 2>&1; then
        log_success "Certificate is not expired"
    else
        log_error "Certificate has expired"
    fi

    echo ""
}

# Check OCSP status
check_ocsp_status() {
    local cert="$1"
    local issuer="$2"
    local ca_chain="$3"
    local ocsp_url="$4"

    echo "═══════════════════════════════════════════════════════════════════"
    echo "  OCSP Status Check"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    log_info "OCSP Responder: $ocsp_url"
    log_info "Checking certificate status..."
    echo ""

    # Prepare OCSP request
    local temp_response="/tmp/ocsp-response-$$.txt"

    # Run OCSP query
    local ocsp_output=$(openssl ocsp \
        -CAfile "$ca_chain" \
        -issuer "$issuer" \
        -cert "$cert" \
        -url "$ocsp_url" \
        -resp_text 2>&1)

    local ocsp_status=$?

    # Parse output
    if [[ "$VERBOSE" == true ]]; then
        echo "$ocsp_output"
        echo ""
    fi

    # Check OCSP response
    if echo "$ocsp_output" | grep -q "Response verify OK"; then
        log_success "OCSP response verified successfully"

        if echo "$ocsp_output" | grep -q ": good"; then
            log_success "Certificate Status: GOOD ✓"
            echo ""
            log_success "Certificate is valid and not revoked"
            return 0
        elif echo "$ocsp_output" | grep -q ": revoked"; then
            log_error "Certificate Status: REVOKED ✗"
            echo ""

            # Extract revocation reason if available
            if echo "$ocsp_output" | grep -q "Revocation Reason:"; then
                local reason=$(echo "$ocsp_output" | grep "Revocation Reason:" | sed 's/.*Revocation Reason: //')
                log_error "Revocation Reason: $reason"
            fi

            # Extract revocation time if available
            if echo "$ocsp_output" | grep -q "Revocation Time:"; then
                local time=$(echo "$ocsp_output" | grep "Revocation Time:" | sed 's/.*Revocation Time: //')
                log_error "Revocation Time: $time"
            fi

            return 1
        elif echo "$ocsp_output" | grep -q ": unknown"; then
            log_warning "Certificate Status: UNKNOWN"
            log_warning "OCSP responder does not know about this certificate"
            return 2
        fi
    else
        if echo "$ocsp_output" | grep -q "Connection refused\|Failed to connect"; then
            log_error "OCSP Responder not available at $ocsp_url"
            log_error "Please check if OCSP responder is running"
            return 2
        elif echo "$ocsp_output" | grep -q "Responder Error"; then
            log_error "OCSP Responder returned an error"
            [[ "$VERBOSE" == true ]] && echo "$ocsp_output"
            return 2
        else
            log_error "OCSP verification failed"
            [[ "$VERBOSE" == true ]] && echo "$ocsp_output"
            return 1
        fi
    fi
}

# Main function
main() {
    # Parse arguments
    parse_args "$@"

    # Auto-detect CA files
    detect_ca_files

    # Determine which certificate to check
    local cert_to_check=""
    local cleanup_cert=false

    if [[ -n "$CERT_FILE" ]]; then
        # Check local certificate file
        if [[ ! -f "$CERT_FILE" ]]; then
            log_error "Certificate file not found: $CERT_FILE"
            exit 1
        fi
        cert_to_check="$CERT_FILE"
        [[ "$VERBOSE" == true ]] && log_info "Checking local certificate: $CERT_FILE"
    else
        # Get certificate from remote server
        cert_to_check=$(get_remote_certificate "$REMOTE_HOST" "$REMOTE_PORT")
        cleanup_cert=true
    fi

    # Show certificate info
    show_cert_info "$cert_to_check"

    # Check OCSP status
    check_ocsp_status "$cert_to_check" "$ISSUER_CERT" "$CA_CHAIN" "$OCSP_URL"
    local result=$?

    # Cleanup temporary files
    if [[ "$cleanup_cert" == true ]]; then
        rm -f "$cert_to_check"
    fi

    echo ""
    exit $result
}

# Run main function
main "$@"
