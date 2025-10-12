# Certificate Policy (CP) và Certificate Practice Statement (CPS)

## Mục lục

- [1. Giới thiệu](#1-giới-thiệu)
- [2. Certificate Policy (CP)](#2-certificate-policy-cp)
- [3. Certificate Practice Statement (CPS)](#3-certificate-practice-statement-cps)
- [4. Policy Framework](#4-policy-framework)
- [5. Implementation Guidelines](#5-implementation-guidelines)

## 1. Giới thiệu

### 1.1. Tại sao cần CP và CPS?

```
┌─────────────────────────────────────────────────────────────────┐
│ Problem: Làm sao người dùng biết CA có đáng tin không?         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Scenario:                                                       │
│ - Bạn nhận được 1 certificate từ CA "Example PKI"             │
│ - Làm sao biết CA này có verify identity đúng không?          │
│ - CA có bảo vệ private key tốt không?                         │
│ - Quy trình revocation như thế nào?                            │
│ - Ai chịu trách nhiệm nếu có vấn đề?                          │
│                                                                 │
│ Solution: Certificate Policy (CP) & CPS                        │
│ - CP: "Chúng tôi CAM KẾT làm gì" (WHAT)                       │
│ - CPS: "Chúng tôi THỰC HIỆN như thế nào" (HOW)                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Real-world analogy:**

```
Certificate Policy (CP) ≈ Privacy Policy của website
- Công khai cho users đọc
- Commitment về cách hoạt động
- Legal binding document

Certificate Practice Statement (CPS) ≈ Internal SOP (Standard Operating Procedure)
- Chi tiết cách implement
- Technical procedures
- Operational guidelines
```

### 1.2. Legal và Compliance Context

**Tại sao CP/CPS quan trọng?**

1. **Legal Protection:**
   - Định nghĩa liability limits
   - Clarify responsibilities
   - Protection trong lawsuit

2. **Trust Framework:**
   - Users biết CA hoạt động như thế nào
   - Relying parties có basis để trust
   - Auditors có checklist để verify

3. **Compliance Requirements:**
   - WebTrust for CAs yêu cầu CP/CPS
   - CA/Browser Forum Baseline Requirements
   - Industry standards (PCI DSS, SOC 2)

4. **Interoperability:**
   - Cross-certification giữa CAs
   - Policy mapping trong certificate chains
   - International recognition

## 2. Certificate Policy (CP)

### 2.1. Định nghĩa

**RFC 3647 Definition:**

> "A certificate policy is a named set of rules that indicates the applicability of a certificate to a particular community and/or class of application with common security requirements."

**Dịch đơn giản:**

CP là **BẢN CAM KẾT CÔNG KHAI** của CA về:
- Loại certificates nào được cấp (server, client, email, code signing)
- Mức độ trust/assurance level
- Requirements để được cấp certificate
- Responsibilities của các parties
- Liability limits

### 2.2. Cấu trúc CP (theo RFC 3647)

```
Certificate Policy Structure:
├── 1. Introduction
│   ├── 1.1. Overview
│   ├── 1.2. Document name and identification
│   ├── 1.3. PKI participants
│   ├── 1.4. Certificate usage
│   └── 1.5. Policy administration
│
├── 2. Publication and Repository Responsibilities
│   ├── 2.1. Repositories
│   ├── 2.2. Publication of certification information
│   └── 2.3. Time or frequency of publication
│
├── 3. Identification and Authentication
│   ├── 3.1. Naming
│   ├── 3.2. Initial identity validation
│   ├── 3.3. Identification and authentication for re-key
│   └── 3.4. Identification and authentication for revocation
│
├── 4. Certificate Life-Cycle Operational Requirements
│   ├── 4.1. Certificate Application
│   ├── 4.2. Certificate issuance
│   ├── 4.3. Certificate acceptance
│   ├── 4.4. Certificate suspension and revocation
│   └── 4.5. Security audit procedures
│
├── 5. Facility, Management, and Operational Controls
│   ├── 5.1. Physical controls
│   ├── 5.2. Procedural controls
│   ├── 5.3. Personnel controls
│   └── 5.4. Audit logging procedures
│
├── 6. Technical Security Controls
│   ├── 6.1. Key pair generation and installation
│   ├── 6.2. Private key protection
│   ├── 6.3. Other aspects of key pair management
│   └── 6.4. Computer security controls
│
├── 7. Certificate, CRL, and OCSP Profiles
│   ├── 7.1. Certificate profile
│   ├── 7.2. CRL profile
│   └── 7.3. OCSP profile
│
├── 8. Compliance Audit and Other Assessments
│   └── 8.1. Frequency of entity compliance audit
│
└── 9. Other Business and Legal Matters
    ├── 9.1. Fees
    ├── 9.2. Financial responsibility
    ├── 9.3. Confidentiality of business information
    ├── 9.4. Privacy of personal information
    ├── 9.5. Intellectual property rights
    ├── 9.6. Representations and warranties
    ├── 9.7. Disclaimers of warranties
    ├── 9.8. Limitations of liability
    └── 9.9. Term and termination
```

### 2.3. Example Certificate Policy

```
═══════════════════════════════════════════════════════════════════
EXAMPLE PKI - CERTIFICATE POLICY
Version 1.0 - December 2024
═══════════════════════════════════════════════════════════════════

1. INTRODUCTION

1.1. Overview
This Certificate Policy (CP) defines the policies and practices for
the Example PKI Certificate Authority in issuing, managing, and
revoking X.509 public key certificates.

1.2. Document Name and Identification
Document Name: Example PKI Certificate Policy
OID: 1.3.6.1.4.1.99999.1.1.1
Version: 1.0
Effective Date: 2024-12-15
Status: Final

1.3. PKI Participants

A. Certificate Authority (CA)
   - Organization: Example Organization
   - Country: Vietnam
   - Contact: pki-admin@example.com
   - Responsibilities:
     * Issue and revoke certificates
     * Maintain certificate status information
     * Publish CRLs and operate OCSP responder
     * Protect CA private keys

B. Registration Authority (RA)
   - Responsibilities:
     * Verify subscriber identity
     * Validate certificate requests
     * Initiate certificate issuance/revocation
   - In this PKI: RA functions performed by CA

C. Subscribers
   - Entity receiving certificate
   - Responsibilities:
     * Protect private key
     * Use certificate per policy
     * Request revocation if compromised
     * Notify CA of information changes

D. Relying Parties
   - Entities that trust certificates
   - Responsibilities:
     * Verify certificate validity
     * Check revocation status (CRL/OCSP)
     * Comply with certificate usage restrictions

1.4. Certificate Usage

1.4.1. Appropriate Certificate Uses
✅ Permitted Uses:
   - TLS/SSL server authentication (HTTPS websites)
   - TLS client authentication (mTLS)
   - Email signing and encryption (S/MIME)
   - Code signing (applications, scripts)
   - Document signing

❌ Prohibited Uses:
   - Financial transactions exceeding liability limits
   - Life-critical systems (medical devices, aircraft)
   - Nuclear facilities
   - Military/classified communications
   - Any illegal purposes

1.4.2. Prohibited Certificate Uses
Certificates SHALL NOT be used for:
   - Timestamping services
   - CA certificate signing (unless explicitly CA cert)
   - Any purpose not explicitly stated in certificate
   - After expiration or revocation

1.5. Policy Administration

1.5.1. Organization Administering the Document
Example Organization PKI Team
Email: pki-policy@example.com

1.5.2. Contact Information
Policy Authority: John Doe, PKI Manager
Email: john.doe@example.com
Phone: +84-xxx-xxx-xxx

1.5.3. Policy Approval Procedures
- Annual review by PKI Policy Authority
- Changes require approval from Security Officer
- Major changes require 30-day public comment period
- Version control maintained in Git repository

═══════════════════════════════════════════════════════════════════

3. IDENTIFICATION AND AUTHENTICATION

3.1. Naming

3.1.1. Types of Names
All certificates issued SHALL contain:
- Subject Distinguished Name (DN) format:
  * Country (C): Required
  * Organization (O): Required
  * Organizational Unit (OU): Optional
  * Common Name (CN): Required
  * Email Address: Required for email certificates

3.1.2. Need for Names to be Meaningful
Common Name (CN) SHALL be:
- For server certificates: Fully Qualified Domain Name (FQDN)
- For user certificates: Full legal name or email address
- For device certificates: Unique device identifier

3.2. Initial Identity Validation

3.2.1. Method to Prove Possession of Private Key
Applicant MUST prove possession by:
- Signing CSR with private key
- CA verifies CSR signature before issuance

3.2.2. Authentication of Organization Identity

For Server Certificates:
✅ Required Evidence:
   - Domain ownership verification via:
     * DNS TXT record
     * HTTP file validation
     * Email confirmation to domain admin
   - Organization registration documents
   - Authorization letter from organization

Validation Process:
1. Applicant submits CSR with domain name
2. RA verifies domain ownership (one of above methods)
3. RA verifies organization registration
4. RA obtains authorization from organization officer
5. RA approves and forwards to CA for issuance

For User Certificates:
✅ Required Evidence:
   - Government-issued photo ID
   - Proof of employment/affiliation
   - Email verification

Validation Process:
1. In-person verification OR video call with ID
2. Verify email ownership
3. Check employment records
4. Approve by manager/supervisor

3.2.3. Authentication of Individual Identity
For individual subscribers:
- Government-issued ID (passport, national ID card)
- Face-to-face verification OR notarized documents
- Two-factor authentication for certificate retrieval

3.3. Identification and Authentication for Re-key
Certificate renewal with same key:
- Simplified validation if previous cert not revoked
- Verify current contact information
- No full re-validation required if within 13 months

Certificate renewal with new key:
- Full validation required if >13 months
- Simplified if <13 months and no information changed

3.4. Identification and Authentication for Revocation
Certificate revocation requests SHALL be:
- Authenticated via:
  * Signed with certificate private key OR
  * Authenticated via original RA channel OR
  * Phone verification with passphrase
- Processed within 24 hours of verification
- Emergency revocation: processed within 4 hours

═══════════════════════════════════════════════════════════════════

4. CERTIFICATE LIFE-CYCLE OPERATIONAL REQUIREMENTS

4.1. Certificate Application
Application process:
1. Subscriber generates key pair
2. Subscriber creates CSR
3. Subscriber submits CSR + required documents
4. RA validates identity and authority
5. RA approves/rejects request
6. If approved, CA issues certificate

4.2. Certificate Issuance
Issuance timeline:
- Standard: Within 5 business days
- Urgent: Within 24 hours (additional fee)

Certificate delivery:
- Electronic delivery via secure channel
- PKCS#12 file for user certificates
- PEM file for server certificates

4.3. Certificate Acceptance
Subscriber acceptance:
- Implicit acceptance upon certificate usage
- 30-day grace period to report issuance errors
- After 30 days, certificate presumed accepted

4.4. Certificate Suspension and Revocation

4.4.1. Circumstances for Revocation
Certificate SHALL be revoked if:
✅ Mandatory Revocation:
   - Private key compromised or suspected compromise
   - False information in certificate application
   - Subscriber violated terms of service
   - Certificate used for prohibited purposes
   - Subscriber deceased (individual) or dissolved (organization)

⚠️ Optional Revocation:
   - Subscriber requests revocation
   - Certificate no longer needed
   - Information in certificate changed

4.4.2. Who Can Request Revocation
- Certificate subscriber
- Subscriber's organization (for employee certs)
- RA/CA personnel (with proper authorization)
- Law enforcement with valid court order

4.4.3. Procedure for Revocation Request
1. Submit revocation request via:
   - Online portal with authentication
   - Email signed with certificate
   - Phone call with verification
2. Provide reason for revocation
3. RA validates request authenticity
4. CA processes revocation
5. CRL updated within 24 hours
6. OCSP updated immediately

4.4.4. Revocation Request Grace Period
- Standard: 24 hours
- Emergency (key compromise): 4 hours
- Critical (CA compromise): 1 hour

4.4.5. Circumstances for Suspension
Suspension NOT SUPPORTED in this PKI.
Rationale:
- Creates uncertainty about certificate status
- Complicates revocation checking
- Better to revoke and reissue if needed

4.5. Security Audit Procedures
All CA operations SHALL be logged:
- Certificate issuance
- Certificate revocation
- Administrative access to CA systems
- Changes to CA configuration
- Access to private keys

Logs SHALL be:
- Tamper-evident (digitally signed)
- Retained for minimum 7 years
- Reviewed monthly by Security Officer
- Available for external audits

═══════════════════════════════════════════════════════════════════

5. FACILITY, MANAGEMENT, AND OPERATIONAL CONTROLS

5.1. Physical Controls

5.1.1. Site Location and Construction
CA facility SHALL:
- Be located in secure building with 24/7 monitoring
- Have controlled access (badge + biometric)
- Have redundant power (UPS + generator)
- Have environmental controls (HVAC, fire suppression)

5.1.2. Physical Access
Access restrictions:
- Tier 1 (Server Room): PKI Administrators only
- Tier 2 (Operations): PKI Staff + approved vendors
- Tier 3 (Office): All company staff

Access requires:
- Background check
- Two-factor authentication
- Access logged and audited

5.2. Procedural Controls

5.2.1. Trusted Roles
Defined roles:
- PKI Administrator: Full CA access
- RA Officer: Approve certificate requests
- Security Officer: Audit and compliance
- System Administrator: Infrastructure maintenance

Segregation of duties:
- No single person can issue certificate alone
- Minimum 2-person rule for critical operations
- CA private key requires M-of-N key ceremony (3-of-5)

5.2.2. Number of Persons Required per Task
Critical operations requiring multiple persons:
- CA key generation: 5 persons (3-of-5 ceremony)
- CA certificate signing: 3 persons
- Policy changes: 2 approvals (Security Officer + PKI Manager)
- Disaster recovery: 3 key custodians

5.3. Personnel Controls

5.3.1. Qualifications, Experience, and Clearance Requirements
PKI Administrators SHALL:
- Have minimum 3 years PKI/security experience
- Hold security certification (CISSP, CISM, or equivalent)
- Pass background check
- Sign non-disclosure agreement
- Complete PKI training program

5.3.2. Background Check Procedures
All PKI personnel SHALL undergo:
- Criminal background check
- Employment history verification
- Education verification
- Reference checks (minimum 3)
- Renewed every 2 years

5.3.3. Training Requirements
Initial training:
- 40 hours PKI fundamentals
- 20 hours CA system operations
- 10 hours security awareness
- Hands-on lab exercises

Ongoing training:
- 16 hours annual refresher
- Security updates as needed
- Incident response drills (quarterly)

5.4. Audit Logging Procedures

5.4.1. Types of Events Recorded
ALL following events SHALL be logged:
- Certificate lifecycle events:
  * Certificate requests
  * Issuance, renewal, revocation
  * CRL generation
  * OCSP responses
- Security events:
  * Login/logout (successful and failed)
  * Administrative actions
  * Configuration changes
  * Access to private keys
  * System errors

5.4.2. Frequency of Processing Logs
- Real-time: Critical security events (alerts)
- Daily: Review high-priority events
- Weekly: Comprehensive log review
- Monthly: Security Officer audit
- Annual: External audit

5.4.3. Retention Period for Audit Logs
- Online: 90 days
- Archive: 7 years
- Critical events: Permanent retention

5.4.4. Protection of Audit Logs
Logs SHALL be:
- Digitally signed (tamper-evident)
- Encrypted at rest
- Backed up to separate system daily
- Access restricted to Security Officer
- Immutable (write-once storage)

═══════════════════════════════════════════════════════════════════

6. TECHNICAL SECURITY CONTROLS

6.1. Key Pair Generation and Installation

6.1.1. Key Pair Generation
CA key pair:
- Algorithm: RSA 4096-bit (minimum)
- Generated in FIPS 140-2 Level 3 HSM
- Key ceremony with 3-of-5 quorum
- Witnessed and documented

Subscriber key pair:
- Algorithm: RSA 2048-bit (minimum)
- Generated by subscriber (on their system)
- CA verifies CSR signature to prove possession

6.1.2. Private Key Delivery to Subscriber
CA SHALL NOT generate subscriber private keys.
Rationale:
- Subscribers must maintain exclusive control
- Key generation on CA side creates security risk
- Non-repudiation requires subscriber-only key control

Exception: Legacy systems requiring CA-generated keys
- Generate in HSM
- Encrypt with subscriber's public key
- Immediate secure delivery
- Key material deleted from CA systems

6.1.3. Public Key Delivery to Certificate Issuer
- Delivered via CSR
- Verified via CSR signature
- No separate public key delivery required

6.2. Private Key Protection and Cryptographic Module Engineering Controls

6.2.1. Cryptographic Module Standards and Controls
CA private keys SHALL:
- Be stored in FIPS 140-2 Level 3 (or higher) HSM
- Never exist in plaintext outside HSM
- Require M-of-N authentication to access
- Have separate backup key in offline HSM

6.2.2. Private Key (n out of m) Multi-Person Control
CA private key access:
- 3-of-5 key custodians required
- Each custodian has smartcard + PIN
- Custodians from different departments
- Key ceremonies documented and witnessed

6.2.3. Private Key Escrow
Private key escrow: NOT PERMITTED
Rationale:
- Security risk (creates additional attack surface)
- Legal issues (privacy concerns)
- Technical complexity
- Better alternatives exist (key recovery via backup)

Exception: Enterprise key recovery for data encryption
- Separate key recovery policy
- Not applicable to authentication certificates

6.2.4. Private Key Backup
CA private key backup:
- Encrypted backup in separate HSM
- Stored in geographically separate location
- Tested annually during disaster recovery drill
- Requires same M-of-N ceremony to access

Subscriber private key backup:
- Subscriber's responsibility
- CA provides guidelines
- Recommended: Encrypted backup to secure storage

6.2.5. Private Key Archival
Long-term archival:
- Not performed for authentication keys
- Only for encryption keys (if policy permits)
- Archived keys: Encrypted, offline, access logged

6.2.6. Private Key Transfer Into or From a Cryptographic Module
CA private key: Never transferred outside HSM
Subscriber private key:
- Generated on subscriber's system
- Transfer via PKCS#12 (password-protected)
- Secure deletion from temporary storage

6.2.7. Private Key Storage on Cryptographic Module
Storage requirements:
- HSM: FIPS 140-2 Level 3+
- Software storage: Encrypted keystore
- Operating system: Secure key storage (macOS Keychain, Windows DPAPI)

6.2.8. Method of Activating Private Key
CA private key activation:
- Requires M-of-N smartcards + PINs
- Logged and audited
- Time-limited session

Subscriber private key:
- Password/PIN protection
- Biometric authentication (optional)
- Hardware token (recommended for high-assurance)

6.2.9. Method of Deactivating Private Key
Deactivation:
- Automatic timeout after inactivity
- Logout/system shutdown
- Manual deactivation command

6.2.10. Method of Destroying Private Key
Secure destruction:
- HSM: Cryptographic erasure
- Software: DoD 5220.22-M (7-pass wipe) or similar
- Hardware: Physical destruction (shredding, degaussing)
- Documentation: Certificate of destruction

6.3. Other Aspects of Key Pair Management

6.3.1. Public Key Archival
Public keys archived:
- In issued certificates
- In certificate database
- Retention: Same as audit logs (7 years minimum)

6.3.2. Certificate Operational Periods and Key Pair Usage Periods

Maximum validity periods:
| Certificate Type | Max Validity | Rationale |
|-----------------|--------------|-----------|
| Root CA | 20 years | Stability, but not too long |
| Intermediate CA | 10 years | Balance between stability and security |
| Server (TLS) | 398 days | CA/Browser Forum requirement |
| Client | 365 days | Annual re-validation |
| Code Signing | 3 years | Industry standard |
| Email (S/MIME) | 2 years | Balance convenience and security |

Rationale for short validity:
- Limits damage from compromised keys
- Forces periodic re-validation
- Aligns with current security best practices
- Compliance with CA/Browser Forum Baseline Requirements

Key pair usage period:
- Same as certificate validity
- Key should not be reused after certificate expires
- New key recommended for renewal

═══════════════════════════════════════════════════════════════════

9. OTHER BUSINESS AND LEGAL MATTERS

9.1. Fees

9.1.1. Certificate Issuance or Renewal Fees
Fee schedule:
- Server Certificate: $100/year
- Wildcard Certificate: $300/year
- Client Certificate: $50/year
- Code Signing: $200/3 years
- Organization Validation (OV): +$50
- Extended Validation (EV): +$200

Free options:
- Internal use only (non-public)
- Educational institutions
- Open source projects (case-by-case)

9.1.2. Certificate Access Fees
- CRL download: Free
- OCSP queries: Free
- Certificate repository access: Free

9.1.3. Revocation or Status Information Access Fees
- Certificate revocation: Free
- Urgent revocation (<4 hours): Free
- Status checking (OCSP/CRL): Free

9.1.4. Fees for Other Services
- Certificate re-issuance (lost): $25
- Priority processing: $50
- Custom OID: $500 (one-time)
- Audit reports: $200/copy

9.2. Financial Responsibility

9.2.1. Insurance Coverage
CA maintains:
- Professional liability insurance: $5,000,000
- Cyber insurance: $2,000,000
- Errors and omissions: $1,000,000

9.2.2. Other Assets
- Capitalization: $1,000,000 minimum
- Reserve fund: $500,000
- Updated annually based on risk assessment

9.3. Confidentiality of Business Information

9.3.1. Scope of Confidential Information
Confidential information includes:
- Subscriber identity validation documents
- Audit reports (internal)
- Security procedures
- Business financial information
- Trade secrets

9.3.2. Information Not Within the Scope of Confidential Information
Public information:
- Issued certificates
- This Certificate Policy
- CRL and OCSP responses
- CA certificates
- Contact information

9.3.3. Responsibility to Protect Confidential Information
CA SHALL:
- Encrypt confidential data at rest and in transit
- Access control (need-to-know basis)
- Staff sign NDAs
- Data retention and destruction policies
- Comply with data protection regulations (GDPR, etc.)

9.4. Privacy of Personal Information

9.4.1. Privacy Plan
CA complies with:
- GDPR (General Data Protection Regulation)
- Local privacy laws
- Industry standards

Data minimization:
- Collect only necessary information
- Retain only as long as required
- Secure deletion after retention period

9.4.2. Information Treated as Private
Private information:
- Email addresses (not in certificate)
- Phone numbers
- Physical addresses
- Government ID numbers
- Payment information

9.4.3. Information Not Deemed Private
Non-private (public) information:
- Organization name
- Domain names
- Certificate subject DN
- Certificate serial numbers
- Revocation status

9.4.4. Responsibility to Protect Private Information
CA responsibilities:
- Encryption of personal data
- Access logging and auditing
- Data breach notification (<72 hours)
- Individual rights (access, correction, deletion)

9.4.5. Notice and Consent to Use Private Information
Consent obtained:
- At certificate application
- Explicit opt-in required
- Separate consent for marketing
- Right to withdraw consent

9.4.6. Disclosure Pursuant to Judicial or Administrative Process
CA may disclose information if:
- Required by law
- Valid court order
- Law enforcement request with proper authority
- National security (with legal constraints)

Procedure:
- Legal review before disclosure
- Notify affected parties (if permitted)
- Minimal disclosure (only what's required)
- Document disclosure for audit

9.4.7. Other Information Disclosure Circumstances
CA may disclose if:
- Preventing fraud
- Protecting CA legal rights
- Responding to security incident
- Subscriber consent

9.5. Intellectual Property Rights
CA owns:
- CA certificates and keys
- CRL and OCSP responses
- CA software and infrastructure
- This Certificate Policy

Subscriber owns:
- Subscriber private key
- Subscriber certificates (but not CA signature)

9.6. Representations and Warranties

9.6.1. CA Representations and Warranties
CA represents that:
✅ Will issue certificates per this policy
✅ Will verify subscriber identity per stated procedures
✅ Will maintain secure infrastructure
✅ Will publish CRL and operate OCSP
✅ Will respond to revocation requests
✅ Will maintain required insurance
✅ Will undergo annual audits

9.6.2. RA Representations and Warranties
RA (if separate) represents:
✅ Will verify subscriber identity accurately
✅ Will follow CA procedures
✅ Will protect confidential information
✅ Will report suspected fraud

9.6.3. Subscriber Representations and Warranties
Subscriber represents:
✅ Information provided is accurate
✅ Will protect private key
✅ Will use certificate per policy
✅ Will request revocation if compromised
✅ Will notify CA of information changes
✅ Authorized to receive certificate

9.6.4. Relying Party Representations and Warranties
Relying party agrees to:
✅ Verify certificate validity
✅ Check revocation status
✅ Comply with certificate usage restrictions
✅ Not rely on expired/revoked certificates

9.6.5. Representations and Warranties of Other Participants
Other participants:
✅ Will comply with applicable laws
✅ Will maintain confidentiality
✅ Will report security incidents

9.7. Disclaimers of Warranties
CA DISCLAIMS warranties for:
❌ Fitness for particular purpose (unless specified)
❌ Merchantability (unless specified)
❌ Third-party content or services
❌ Force majeure events

9.8. Limitations of Liability

9.8.1. Limitation on Damages
CA liability LIMITED TO:
- Insurance coverage amounts
- Certificate fees paid
- Direct damages only (no consequential)

Maximum liability per certificate:
- Server certificate: $100,000
- Code signing: $500,000
- Extended Validation: $1,000,000

9.8.2. Exclusions of Liability
CA NOT LIABLE for:
❌ Subscriber's failure to protect private key
❌ Relying party's failure to check revocation
❌ Use of certificate outside policy
❌ Force majeure (natural disasters, war, etc.)
❌ Government actions
❌ Subscriber's violations

9.9. Indemnities

9.9.1. Indemnification by CA
CA will indemnify subscribers/relying parties for:
- CA's negligence
- CA's breach of policy
- CA's failure to perform stated duties

9.9.2. Indemnification by Subscriber
Subscriber will indemnify CA for:
- Subscriber's misrepresentation
- Subscriber's key compromise (if not reported)
- Subscriber's unauthorized use
- Subscriber's breach of terms

9.10. Term and Termination

9.10.1. Term
This policy effective until superseded.
Review: Annually (minimum)
Updates: As needed for security/compliance

9.10.2. Termination
Policy terminates when:
- CA ceases operations
- Superseded by new version
- Regulatory requirement changes

9.10.3. Effect of Termination and Survival
Upon termination:
- No new certificates issued
- Existing certificates remain valid until expiry
- Revocation services continue until last cert expires
- Audit logs retained per policy
- Confidentiality obligations survive

═══════════════════════════════════════════════════════════════════
END OF CERTIFICATE POLICY
═══════════════════════════════════════════════════════════════════
```

### 2.4. Policy OID

**Object Identifier (OID):**

```
Certificate Policy OID Structure:

1.3.6.1.4.1.99999        - Example Organization (Private Enterprise)
    └── 1                 - PKI Branch
        └── 1             - Certificate Policies
            ├── 1         - General Purpose Certificates
            ├── 2         - Server Certificates
            ├── 3         - Client Certificates
            ├── 4         - Code Signing Certificates
            └── 5         - Email Certificates
```

**OID trong certificate:**

```bash
# View certificate policy OID
openssl x509 -in cert.pem -noout -text | grep -A 5 "Certificate Policies"

# Output:
# X509v3 Certificate Policies:
#     Policy: 1.3.6.1.4.1.99999.1.1.2
#       CPS: https://pki.example.com/cps
```

## 3. Certificate Practice Statement (CPS)

### 3.1. CP vs CPS

| Aspect | Certificate Policy (CP) | Certificate Practice Statement (CPS) |
|--------|------------------------|--------------------------------------|
| **Audience** | Public, relying parties | Internal, auditors, technical staff |
| **Focus** | WHAT (commitments) | HOW (implementation) |
| **Level** | High-level policies | Detailed procedures |
| **Stability** | Relatively stable | Updated frequently |
| **Legal** | Legal commitments | Operational details |
| **Example** | "We verify domain ownership" | "We verify via DNS TXT record with SHA-256 hash at _pki-validation.example.com" |

### 3.2. CPS Content (Technical Details)

**Example CPS Section:**

```
═══════════════════════════════════════════════════════════════════
CERTIFICATE PRACTICE STATEMENT
Example PKI Certificate Authority
═══════════════════════════════════════════════════════════════════

3.2. Initial Identity Validation - DETAILED PROCEDURES

3.2.1. Domain Validation Procedure

Step-by-step process for server certificate domain validation:

METHOD 1: DNS TXT Record Validation

1. Generate random token:
   - Length: 32 bytes
   - Encoding: Base64
   - Validity: 7 days
   - Example: "XyZ123...abc"

2. Instruct applicant to create DNS TXT record:
   - Hostname: _pki-validation.example.com
   - Type: TXT
   - Value: <random-token>
   - TTL: 300 seconds (minimum)

3. Verify DNS record:
   - Query: dig TXT _pki-validation.example.com
   - Retry: 3 attempts with 10-second delay
   - Timeout: 30 seconds per query
   - Check: Token matches exactly
   - Multiple DNS servers checked (minimum 2):
     * 8.8.8.8 (Google Public DNS)
     * 1.1.1.1 (Cloudflare DNS)
     * Authoritative nameserver

4. Document validation:
   - Timestamp validation success
   - DNS query results logged
   - Record verification screenshot
   - Validation evidence retained 7 years

5. Proceed to certificate issuance

METHOD 2: HTTP File Validation

1. Generate random filename and content:
   - Filename: /.well-known/pki-validation/<random>.txt
   - Content: <random-token>
   - Format: Plain text, UTF-8

2. Instruct applicant to place file:
   - URL: http://example.com/.well-known/pki-validation/<random>.txt
   - HTTP (not HTTPS) - avoids chicken-egg problem
   - File publicly accessible

3. Verify HTTP file:
   - HTTP GET request to URL
   - Follow redirects (maximum 5)
   - Verify status code 200 OK
   - Verify content matches token
   - User-Agent: "ExamplePKI-Validator/1.0"
   - Timeout: 10 seconds

4. Document validation:
   - HTTP request/response logged
   - Timestamp validation success
   - Validation evidence retained 7 years

5. Proceed to certificate issuance

METHOD 3: Email Verification

1. Send verification email to:
   - admin@example.com
   - administrator@example.com
   - webmaster@example.com
   - hostmaster@example.com
   - postmaster@example.com

2. Email contains:
   - Random verification code
   - Expiration time (24 hours)
   - Unique verification URL
   - Instructions

3. Applicant clicks verification URL OR enters code in portal

4. System validates:
   - Code matches
   - Not expired
   - Not previously used
   - IP address logged

5. Document validation:
   - Email sent/received logged
   - Timestamp verification
   - Validation evidence retained 7 years

VALIDATION COMPLETION:

After successful domain validation:
- Validation recorded in database
- Valid for 90 days (may reuse for multiple certs)
- After 90 days, must re-validate
- If domain ownership changes, must re-validate immediately

ERROR HANDLING:

If validation fails:
- Log failure reason
- Notify applicant with specific error
- Allow retry (maximum 5 attempts per 24 hours)
- After 5 failures, require manual review
- Flag for potential fraud investigation

═══════════════════════════════════════════════════════════════════
```

### 3.3. CPS Implementation Checklist

```
✅ CA Infrastructure:
   □ HSM procurement and configuration
   □ Physical security implementation
   □ Network segmentation
   □ Backup systems
   □ Monitoring and alerting

✅ Personnel:
   □ Background checks completed
   □ Training program developed
   □ Role-based access control implemented
   □ NDA signed by all staff

✅ Processes:
   □ Certificate issuance workflow
   □ Revocation procedures
   □ Incident response plan
   □ Business continuity plan
   □ Disaster recovery procedures

✅ Technical:
   □ CA software installed and configured
   □ Certificate profiles created
   □ CRL generation automated
   □ OCSP responder operational
   □ Logging and monitoring

✅ Documentation:
   □ Certificate Policy published
   □ CPS documented
   □ Operational procedures (SOPs)
   □ Training materials
   □ Audit trail

✅ Compliance:
   □ WebTrust audit (for public CAs)
   □ Policy OID registered
   □ Legal review completed
   □ Insurance obtained
```

## 4. Policy Framework

### 4.1. Policy Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                    Policy Hierarchy                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Level 1: Information Security Policy                          │
│           (Organization-wide, board-approved)                   │
│                     │                                           │
│                     ↓                                           │
│  Level 2: PKI Policy                                           │
│           (Specific to PKI operations)                          │
│                     │                                           │
│                     ↓                                           │
│  Level 3: Certificate Policy (CP)                              │
│           (Public commitments)                                  │
│           ├─> Server Certificate Policy                        │
│           ├─> Client Certificate Policy                        │
│           └─> Code Signing Certificate Policy                  │
│                     │                                           │
│                     ↓                                           │
│  Level 4: Certificate Practice Statement (CPS)                 │
│           (Implementation details)                              │
│                     │                                           │
│                     ↓                                           │
│  Level 5: Standard Operating Procedures (SOPs)                 │
│           (Step-by-step instructions)                           │
│           ├─> SOP-001: Certificate Issuance                    │
│           ├─> SOP-002: Certificate Revocation                  │
│           ├─> SOP-003: Key Ceremony                            │
│           ├─> SOP-004: Incident Response                       │
│           └─> SOP-005: Audit Log Review                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2. Policy Maintenance

**Update frequency:**

| Document | Review Cycle | Update Trigger |
|----------|--------------|----------------|
| Information Security Policy | Annual | Major organizational changes |
| PKI Policy | Annual | Technology/threat landscape changes |
| Certificate Policy | Annual | Standards updates (CA/BF, RFC) |
| CPS | Quarterly | Operational changes |
| SOPs | As needed | Process improvements |

**Change management:**

```
Change Process:
1. Identify need for change
2. Draft proposed changes
3. Impact analysis
4. Stakeholder review
5. Approval (Security Officer + PKI Manager)
6. Public comment period (30 days for CP)
7. Finalize changes
8. Update version number
9. Communicate changes
10. Train staff on changes
11. Update audit checklist
```

## 5. Implementation Guidelines

### 5.1. How to Create Your Own CP/CPS

**Step 1: Use RFC 3647 as template**

```bash
# Download RFC 3647
wget https://www.rfc-editor.org/rfc/rfc3647.txt

# Use framework but adapt to your needs
```

**Step 2: Identify your requirements**

- What types of certificates will you issue?
- What assurance level do you need?
- What are your legal/compliance requirements?
- What resources do you have?

**Step 3: Write your CP**

Focus on:
- Your commitments to users
- What you will and won't do
- Liability limits
- Terms of service

**Step 4: Write your CPS**

Document:
- Actual technical procedures
- System architecture
- Operational processes
- Security controls

**Step 5: Review and approve**

- Legal review
- Technical review
- Management approval
- Publish publicly

**Step 6: Audit and maintain**

- Annual review minimum
- Update as processes change
- Track version history
- Maintain change log

### 5.2. Example Policy Files for This Project

Create these files in your CA:

```bash
/root/ca/policies/
├── certificate-policy.pdf        # Public-facing CP
├── cps-internal.pdf               # Detailed CPS
├── sop-certificate-issuance.md    # Issuance procedure
├── sop-certificate-revocation.md  # Revocation procedure
├── sop-key-ceremony.md            # CA key generation ceremony
├── sop-incident-response.md       # Security incident handling
└── policy-oids.txt                # OID assignments
```

---

**Next**: [PKI Design Rationale](08-design-rationale.md) - Giải thích tại sao thiết kế như vậy
