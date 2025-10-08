# Best Practices - Bảo mật PKI

## Mục lục

- [1. Key Management](#1-key-management)
- [2. CA Security](#2-ca-security)
- [3. Certificate Lifecycle](#3-certificate-lifecycle)
- [4. Operational Security](#4-operational-security)
- [5. Monitoring và Audit](#5-monitoring-và-audit)
- [6. Disaster Recovery](#6-disaster-recovery)

## 1. Key Management

### 1.1. Key Generation

**Best Practices:**

✅ **DO:**
- Sử dụng cryptographically secure random number generator (CSPRNG)
- Root CA: Minimum 4096-bit RSA hoặc P-384 ECDSA
- Intermediate CA: Minimum 4096-bit RSA
- End-entity: Minimum 2048-bit RSA
- Generate keys offline khi có thể

❌ **DON'T:**
- Sử dụng RSA < 2048 bits
- Sử dụng weak random number generators
- Reuse keys across different purposes
- Generate keys trên shared/untrusted systems

**Example:**

```bash
# Good: Strong key with secure RNG
openssl genrsa -out ca.key.pem 4096

# Better: With passphrase protection
openssl genrsa -aes256 -out ca.key.pem 4096

# Best: ECDSA (faster, smaller, equally secure)
openssl ecparam -name secp384r1 -genkey -noout -out ca.key.pem
```

### 1.2. Key Storage

**Root CA Private Key:**

```bash
# Offline storage options:
# 1. Hardware Security Module (HSM)
#    - FIPS 140-2 Level 3 or higher
#    - Example: YubiHSM, AWS CloudHSM

# 2. Air-gapped machine
#    - No network connection
#    - Encrypted disk
#    - Physical security

# 3. Encrypted USB in safe
#    - Strong passphrase
#    - Multiple copies in different locations

# Encrypt private key
openssl rsa -aes256 \
    -in ca.key.pem \
    -out ca.key.encrypted.pem

# Store encrypted backup
tar czf ca-backup.tar.gz rootca/
openssl enc -aes-256-cbc -salt \
    -in ca-backup.tar.gz \
    -out ca-backup.tar.gz.enc
```

**File Permissions:**

```bash
# Private keys: Only root read
chmod 400 /root/ca/*/private/*.key.pem
chown root:root /root/ca/*/private/*.key.pem

# Directories
chmod 700 /root/ca/*/private/
chmod 755 /root/ca/*/certs/

# Audit
auditctl -w /root/ca/rootca/private -p wa -k ca_root_key_access
auditctl -w /root/ca/intermediate/private -p wa -k ca_int_key_access
```

### 1.3. Key Rotation

**Schedule:**

- **Root CA**: 15-20 years (rarely rotated)
- **Intermediate CA**: 5-10 years
- **Server certificates**: 1 year (398 days max)
- **Client certificates**: 1 year
- **OCSP signing**: 6-12 months

**Rotation Process:**

```bash
# 1. Generate new Intermediate CA
# 2. Dual operation period (old + new)
# 3. Migrate certificates to new CA
# 4. Revoke old CA certificate
# 5. Update CRL and OCSP
```

### 1.4. Key Backup

```bash
#!/bin/bash
# secure-backup.sh

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/secure/backups/ca-$BACKUP_DATE"

mkdir -p "$BACKUP_DIR"

# Backup Root CA (most critical)
tar czf "$BACKUP_DIR/rootca.tar.gz" /root/ca/rootca/

# Encrypt with strong passphrase
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
    -salt -in "$BACKUP_DIR/rootca.tar.gz" \
    -out "$BACKUP_DIR/rootca.tar.gz.enc"

# Remove unencrypted
shred -u "$BACKUP_DIR/rootca.tar.gz"

# Create checksum
sha256sum "$BACKUP_DIR/rootca.tar.gz.enc" > "$BACKUP_DIR/checksum.txt"

# Store in:
# - Offline USB drive in safe
# - Different physical location
# - Bank safety deposit box
```

## 2. CA Security

### 2.1. Root CA Offline

**Why:**
- Root CA compromise = entire PKI compromised
- Root CA rarely needed (only to sign Intermediate CAs)
- Offline = no remote attack surface

**Implementation:**

```bash
# After initial setup:
# 1. Sign all necessary Intermediate CAs
# 2. Generate initial Root CRL
# 3. Backup everything
# 4. Shutdown Root CA
# 5. Disconnect network
# 6. Store in secure location

# Only bring online to:
# - Create new Intermediate CA
# - Renew Intermediate CA
# - Revoke compromised Intermediate CA
# - Update Root CRL (quarterly)
```

**Air-gapped Setup:**

```bash
# Transfer files via encrypted USB only
# Never connect to network
# Physical access control
# Video surveillance
# Two-person rule for access
```

### 2.2. Intermediate CA Hardening

**System Security:**

```bash
# Minimal OS installation
# Disable unnecessary services
systemctl list-unit-files --state=enabled

# Firewall rules
ufw default deny incoming
ufw default deny outgoing
ufw allow from 10.0.0.0/8 to any port 22  # SSH from internal only
ufw enable

# Disable SSH password auth
# /etc/ssh/sshd_config:
# PasswordAuthentication no
# PermitRootLogin prohibit-password
# PubkeyAuthentication yes

# Keep system updated
apt update && apt upgrade -y

# Install security tools
apt install -y fail2ban aide tripwire
```

**Access Control:**

```bash
# Sudo access only for specific commands
# /etc/sudoers.d/ca-operators:
%ca_operators ALL=(root) NOPASSWD: /usr/bin/openssl ca
%ca_operators ALL=(root) NOPASSWD: /root/ca/scripts/issue-certificate.sh

# No direct shell access to private keys
# All operations via controlled scripts
```

### 2.3. Network Security

```bash
# Isolate in DMZ or separate VLAN
# Network diagram:
#
#   Internet
#      |
#   Firewall
#      |
#   +--+--+
#   |     |
#  Web   CA Subnet (isolated)
#        |
#     Intermediate CA
#        |
#   OCSP/CRL Server

# Firewall rules:
# - Block all inbound except HTTPS for OCSP/CRL
# - Log all access
# - IDS/IPS monitoring
```

## 3. Certificate Lifecycle

### 3.1. Certificate Policy

**Validation Levels:**

```yaml
Level 1 - Domain Validation (DV):
  Validation: Email or DNS
  Issuance: Automated
  Use: Internal testing, dev environments
  Validity: 90 days

Level 2 - Organization Validation (OV):
  Validation: Domain + Business verification
  Issuance: Manual approval
  Use: Production websites
  Validity: 1 year (398 days max)

Level 3 - Extended Validation (EV):
  Validation: Extensive legal/business verification
  Issuance: Manual with background check
  Use: High-security sites (banking, e-commerce)
  Validity: 1 year (398 days max)
```

### 3.2. Certificate Approval Workflow

```bash
# 1. Request received
# 2. Identity verification
# 3. Domain ownership verification
# 4. Approval from authorized person
# 5. Certificate issuance
# 6. Notification to requester
# 7. Log all actions

# Example approval script:
#!/bin/bash
# approve-certificate.sh

CSR_FILE="$1"
APPROVER="$2"

# Verify CSR
openssl req -text -noout -verify -in "$CSR_FILE"

# Log approval
echo "$(date) | $APPROVER | $CSR_FILE" >> /var/log/ca/approvals.log

# Require 2FA for approval
# require-2fa-token "$APPROVER"

# Issue certificate
./issue-certificate.sh "$CSR_FILE"
```

### 3.3. Validity Periods

**Follow CA/Browser Forum Baseline Requirements:**

```bash
# Server certificates: Max 398 days (13 months)
-days 398

# Intermediate CA: 10 years
-days 3650

# Root CA: 20 years
-days 7300

# NEVER issue certificates > 398 days for public TLS
# Browsers will reject them
```

### 3.4. Revocation Strategy

**When to Revoke:**

- ✅ Private key compromised
- ✅ CA compromised
- ✅ Employee termination (client certs)
- ✅ Server decommissioned
- ✅ Certificate superseded
- ✅ Domain ownership changed

**Don't Revoke If:**
- ❌ Certificate expired (already invalid)
- ❌ Minor configuration change (issue new instead)

## 4. Operational Security

### 4.1. Separation of Duties

```yaml
Roles:
  CA Administrator:
    - Root CA key access
    - Create Intermediate CAs
    - Policy decisions

  RA (Registration Authority):
    - Verify certificate requests
    - Approve/deny requests
    - Identity verification

  CA Operator:
    - Issue certificates (after RA approval)
    - Revoke certificates
    - Update CRL/OCSP

  Security Officer:
    - Audit logs
    - Security monitoring
    - Incident response

  Backup Manager:
    - Secure backups
    - Disaster recovery
    - Key escrow (if applicable)
```

### 4.2. Two-Person Rule

```bash
# Critical operations require 2 people:
# - Root CA key access
# - Intermediate CA signing
# - Key backup/restore
# - Configuration changes

# Implementation example:
#!/bin/bash
# two-person-auth.sh

require_two_person_auth() {
    echo "This operation requires two-person authorization"

    # Person 1
    read -p "Person 1 username: " USER1
    read -sp "Person 1 password: " PASS1
    echo

    # Person 2
    read -p "Person 2 username: " USER2
    read -sp "Person 2 password: " PASS2
    echo

    # Verify both users
    # Verify they are different
    # Verify they have required roles
    # Log the authorization
}

# Usage in sensitive operations:
require_two_person_auth
openssl ca -config rootca/openssl.cnf ...
```

### 4.3. Secure Communication

```bash
# Transfer CSRs and certificates securely:

# Option 1: SFTP
sftp ca-server:/root/ca/intermediate/csr/ <<< "put server.csr.pem"

# Option 2: SCP
scp server.csr.pem ca-server:/root/ca/intermediate/csr/

# Option 3: Encrypted email (S/MIME)
# Encrypt CSR with CA's public key

# Option 4: Web portal with TLS + authentication
# Use client certificates for authentication

# DON'T: Email unencrypted private keys
# DON'T: Slack/Teams for sensitive data
```

## 5. Monitoring và Audit

### 5.1. Logging

```bash
# Log all CA operations
# /etc/rsyslog.d/ca-audit.conf:
local0.* /var/log/ca/operations.log

# In scripts:
logger -t CA -p local0.info "Certificate issued: $SERIAL for $CN"
logger -t CA -p local0.warning "Certificate revoked: $SERIAL reason: $REASON"

# Log format:
# Timestamp | Operation | User | Serial | Subject | Result
2024-01-15 10:30:00 | ISSUE | operator1 | 1234 | CN=www.example.com | SUCCESS
2024-01-15 14:20:00 | REVOKE | operator2 | 1234 | CN=www.example.com | SUCCESS
```

### 5.2. Monitoring

```bash
#!/bin/bash
# monitor-ca.sh - Daily monitoring checks

# Check certificate expiration
find /root/ca/intermediate/certs -name "*.pem" | while read cert; do
    if openssl x509 -in "$cert" -noout -checkend $((30*86400)); then
        : # OK
    else
        echo "ALERT: Certificate expiring soon: $cert"
        # Send notification
    fi
done

# Check disk space
USAGE=$(df -h /root/ca | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$USAGE" -gt 80 ]; then
    echo "ALERT: Disk usage high: $USAGE%"
fi

# Check for failed operations
FAILED=$(grep FAILED /var/log/ca/operations.log | wc -l)
if [ "$FAILED" -gt 0 ]; then
    echo "ALERT: $FAILED failed operations"
fi

# Check CRL validity
CRL_NEXT=$(openssl crl -in /root/ca/intermediate/crl/intermediate.crl.pem \
    -noout -nextupdate)
# Alert if CRL will expire soon
```

### 5.3. Audit Trail

```bash
# Comprehensive audit log
# What to log:
# - All certificate issuance (who, when, what)
# - All revocations (who, when, why)
# - All key access (who, when)
# - All configuration changes
# - All login attempts
# - All failed operations

# Audit log protection:
# - Write-only for operators
# - Sent to remote syslog
# - Tamper-proof (digitally signed)

# Example tamper-proof logging:
log_and_sign() {
    MESSAGE="$1"
    echo "$MESSAGE" >> /var/log/ca/audit.log

    # Sign log entry
    echo "$MESSAGE" | openssl dgst -sha256 -sign /root/ca/audit-key.pem \
        >> /var/log/ca/audit.sig
}

# Verify log integrity:
verify_audit_log() {
    openssl dgst -sha256 -verify /root/ca/audit-key.pub \
        -signature /var/log/ca/audit.sig /var/log/ca/audit.log
}
```

### 5.4. Regular Audits

```yaml
Daily:
  - Review certificate issuance
  - Check for anomalies
  - Verify CRL updates
  - Monitor system health

Weekly:
  - Review access logs
  - Check certificate expirations
  - Verify backups
  - Security scan

Monthly:
  - Comprehensive audit
  - Review policies
  - Update documentation
  - Test disaster recovery

Quarterly:
  - External security audit
  - Penetration testing
  - Compliance review
  - Training update

Annually:
  - Full security assessment
  - Policy review
  - Key rotation review
  - Disaster recovery drill
```

## 6. Disaster Recovery

### 6.1. Backup Strategy

**3-2-1 Rule:**
- **3** copies of data
- **2** different storage media
- **1** copy offsite

```bash
#!/bin/bash
# comprehensive-backup.sh

BACKUP_ROOT="/backups/ca"
DATE=$(date +%Y%m%d)

# Full backup
tar czf "$BACKUP_ROOT/full-$DATE.tar.gz" /root/ca/

# Encrypt
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
    -salt -in "$BACKUP_ROOT/full-$DATE.tar.gz" \
    -out "$BACKUP_ROOT/full-$DATE.tar.gz.enc"

shred -u "$BACKUP_ROOT/full-$DATE.tar.gz"

# Split for distribution
split -b 100M "$BACKUP_ROOT/full-$DATE.tar.gz.enc" \
    "$BACKUP_ROOT/full-$DATE.part-"

# Locations:
# 1. Local encrypted backup
cp "$BACKUP_ROOT/full-$DATE.tar.gz.enc" /local/backup/

# 2. Offsite storage
# rsync to offsite server

# 3. Physical media
# Copy to encrypted USB, store in safe

# Verify backup
sha256sum "$BACKUP_ROOT/full-$DATE.tar.gz.enc" > \
    "$BACKUP_ROOT/full-$DATE.sha256"
```

### 6.2. Recovery Procedures

```bash
# Test recovery quarterly!

# Recovery steps:
# 1. Restore from backup
# 2. Verify integrity
# 3. Test CA operations
# 4. Update CRL/OCSP
# 5. Notify stakeholders

# Recovery script:
#!/bin/bash
# restore-ca.sh

BACKUP_FILE="$1"

# Decrypt
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
    -in "$BACKUP_FILE" -out ca-restore.tar.gz

# Verify checksum
sha256sum -c ca-restore.sha256

# Extract
tar xzf ca-restore.tar.gz -C /root/

# Verify CA certificates
openssl verify -CAfile /root/ca/rootca/certs/ca.cert.pem \
    /root/ca/intermediate/certs/intermediate.cert.pem

# Test certificate issuance
./test-ca-operations.sh

echo "Recovery completed. Manual verification required."
```

### 6.3. Business Continuity

**RTO/RPO:**
```yaml
Recovery Time Objective (RTO):
  Critical: 4 hours
  High: 24 hours
  Medium: 72 hours

Recovery Point Objective (RPO):
  Critical data: 1 hour
  Configuration: 24 hours
```

**Failover Plan:**

```
Primary CA Down:
  1. Assess damage/compromise
  2. If compromised:
     - Revoke Intermediate CA
     - Activate backup Intermediate CA
     - Update CRL/OCSP
     - Notify relying parties
  3. If hardware failure:
     - Restore from backup
     - Verify integrity
     - Resume operations

Root CA Compromised (worst case):
  1. EMERGENCY: Stop all operations
  2. Revoke ALL certificates
  3. Notify all relying parties
  4. Generate new Root CA
  5. Re-issue all certificates
  6. Post-mortem analysis
```

### 6.4. Contact List

```yaml
Emergency Contacts:
  CA Administrator:
    Name: [Name]
    Phone: [24/7 number]
    Email: [Email]

  Security Officer:
    Name: [Name]
    Phone: [24/7 number]
    Email: [Email]

  Management:
    Name: [Name]
    Phone: [Number]
    Email: [Email]

External:
  Certificate Users: [Mailing list]
  Security Team: [Contact]
  Legal: [Contact]
  Public Relations: [Contact]
```

## 7. Compliance

### 7.1. Standards

Follow industry standards:

- **RFC 5280**: X.509 PKI Certificate and CRL Profile
- **CA/Browser Forum**: Baseline Requirements
- **NIST SP 800-57**: Key Management
- **PCI DSS**: Payment Card Industry (if applicable)
- **SOC 2**: Service Organization Controls
- **ISO 27001**: Information Security Management

### 7.2. Certificate Policy (CP)

Document your CA's policies:

```markdown
# Certificate Policy

## 1. Introduction
   1.1 Overview
   1.2 Document Name and Identification
   1.3 PKI Participants

## 2. Publication and Repository Responsibilities
   2.1 Repositories
   2.2 Publication of Certification Information

## 3. Identification and Authentication
   3.1 Naming
   3.2 Initial Identity Validation
   3.3 Authentication for Re-key

## 4. Certificate Life-Cycle Operational Requirements
   4.1 Certificate Application
   4.2 Certificate Issuance
   4.3 Certificate Acceptance
   4.4 Certificate Suspension and Revocation
   4.5 Security Audit Procedures

## 5. Physical, Procedural, and Personnel Security Controls
   5.1 Physical Controls
   5.2 Procedural Controls
   5.3 Personnel Controls

## 6. Technical Security Controls
   6.1 Key Pair Generation and Installation
   6.2 Private Key Protection
   6.3 Other Aspects of Key Pair Management
   6.4 Activation Data
   6.5 Computer Security Controls
   6.6 Life Cycle Technical Controls
   6.7 Network Security Controls

## 7. Certificate, CRL, and OCSP Profiles

## 8. Compliance Audit and Other Assessment

## 9. Other Business and Legal Matters
```

## Tổng kết Best Practices

✅ **DO:**
- Keep Root CA offline
- Use strong keys (4096-bit RSA minimum)
- Encrypt all private keys with strong passphrases
- Regular backups (3-2-1 rule)
- Comprehensive logging and monitoring
- Follow two-person rule for critical operations
- Regular security audits
- Document everything
- Test disaster recovery

❌ **DON'T:**
- Use weak keys (< 2048-bit)
- Store private keys unencrypted
- Skip backups
- Ignore expiring certificates
- Share private keys
- Use email for sensitive data
- Skip logging
- Ignore security updates
- Trust without verification

**Remember**: PKI security is only as strong as its weakest link!
