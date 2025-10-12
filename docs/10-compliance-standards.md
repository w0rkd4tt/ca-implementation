# Compliance và Standards Rationale

## Mục lục

- [1. Why Standards Matter](#1-why-standards-matter)
- [2. Key Standards and RFCs](#2-key-standards-and-rfcs)
- [3. Industry Requirements](#3-industry-requirements)
- [4. Compliance Frameworks](#4-compliance-frameworks)
- [5. Audit and Certification](#5-audit-and-certification)

## 1. Why Standards Matter

### 1.1. Tại sao cần follow standards?

```
┌─────────────────────────────────────────────────────────────────┐
│ Problem: Homegrown PKI không được trust                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Scenario 1: Tự inventing PKI                                   │
│ "Chúng tôi tự thiết kế PKI riêng, secure hơn X.509!"          │
│                                                                 │
│ Problems:                                                       │
│ ❌ No interoperability (chỉ mình bạn dùng)                      │
│ ❌ No third-party review (bugs không ai phát hiện)              │
│ ❌ No tooling support (phải tự viết mọi thứ)                    │
│ ❌ No trust (ai tin hệ thống không ai biết?)                    │
│ ❌ No audit (auditor không có checklist)                        │
│                                                                 │
│ Example failures:                                               │
│ - WEP (Wi-Fi security): Tự designed, broken in 2 years        │
│ - Custom crypto in Adobe: Broken                               │
│ - Proprietary DRM: All broken                                  │
│                                                                 │
│ ─────────────────────────────────────────────────────────────  │
│                                                                 │
│ Solution: Follow established standards                          │
│                                                                 │
│ Benefits:                                                       │
│ ✅ Interoperability (works with existing systems)               │
│ ✅ Peer review (thousands of experts reviewed)                  │
│ ✅ Tooling (OpenSSL, libraries, browsers)                       │
│ ✅ Trust (proven in production for decades)                     │
│ ✅ Audit (standard checklists exist)                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2. Standards Hierarchy

```
Standards Hierarchy (từ abstract → concrete):

Level 1: Cryptographic Standards
├─> FIPS 140-2/3: Cryptographic Module Validation
├─> NIST SP 800-57: Key Management
└─> NIST SP 800-131A: Cryptographic Algorithm Policy

Level 2: PKI Protocol Standards
├─> X.509 (ITU-T): Certificate format
├─> RFC 5280: X.509 PKI Certificate and CRL Profile
├─> RFC 6960: OCSP (Online Certificate Status Protocol)
└─> RFC 6066: TLS Extensions (OCSP Stapling)

Level 3: Industry Requirements
├─> CA/Browser Forum Baseline Requirements
├─> WebTrust Principles and Criteria
└─> ETSI EN 319 411: Policy requirements for CAs

Level 4: Application-Specific
├─> PCI DSS: Payment card industry
├─> HIPAA: Healthcare
├─> FedRAMP: US Government
└─> eIDAS: EU Digital Identity
```

## 2. Key Standards and RFCs

### 2.1. RFC 5280 - X.509 PKI Certificate and CRL Profile

**Tại sao quan trọng?**

```
RFC 5280: The Bible của PKI

Published: May 2008
Status: Proposed Standard (de facto standard)
Supersedes: RFC 3280

Định nghĩa:
✅ Certificate format (X.509 v3)
✅ Certificate extensions
✅ CRL format
✅ Certification paths and validation
✅ Certificate policies

Nếu không follow RFC 5280:
❌ Certificates không được browsers chấp nhận
❌ OpenSSL không parse được
❌ Audit fails
❌ Legal issues

Our implementation compliance:
✅ Certificate structure per RFC 5280 Section 4.1
✅ Extensions per RFC 5280 Section 4.2
✅ CRL format per RFC 5280 Section 5
✅ Name constraints per RFC 5280 Section 4.2.1.10
```

**Key Requirements:**

| Requirement | RFC Section | Implementation |
|-------------|------------|----------------|
| Version 3 certificates | 4.1.2.1 | ✅ `version=3` in all certs |
| Serial number uniqueness | 4.1.2.2 | ✅ Auto-increment serial |
| Signature algorithm | 4.1.2.3 | ✅ SHA-256 with RSA |
| Subject DN | 4.1.2.6 | ✅ Proper DN formatting |
| basicConstraints | 4.2.1.9 | ✅ CA:TRUE for CAs, CA:FALSE for end-entity |
| keyUsage | 4.2.1.3 | ✅ Appropriate for each cert type |
| subjectAltName | 4.2.1.6 | ✅ Required for server certs |

### 2.2. RFC 6960 - OCSP

**Tại sao cần OCSP?**

```
Problem: CRL không scale

Scenario:
- CA has 1 million certificates
- 1% revoked = 10,000 revoked certs
- CRL file size: ~1MB
- Client must download full CRL
- Check if specific certificate is in CRL

Problems:
❌ Large file size (bandwidth)
❌ Slow parsing (performance)
❌ Stale data (updated daily)
❌ Privacy (download reveals interest)

RFC 6960 Solution: OCSP (Online Certificate Status Protocol)

Client → OCSP Responder: "Is cert 1234 revoked?"
OCSP Responder → Client: "No, status=good"

Benefits:
✅ Small request/response (~1KB)
✅ Fast (milliseconds)
✅ Real-time (up-to-date)
✅ Selective (only query needed certs)

Our implementation compliance:
✅ OCSP responder per RFC 6960
✅ OCSP request/response format
✅ OCSP signing certificate with extendedKeyUsage=OCSPSigning
✅ OCSP nonce support (replay prevention)
```

### 2.3. RFC 6066 - TLS Extensions (OCSP Stapling)

**Tại sao cần OCSP Stapling?**

```
Problem: Traditional OCSP leaks privacy

Traditional OCSP flow:
1. Client connects to website.com
2. Client gets certificate
3. Client queries OCSP responder: "Is cert for website.com valid?"
4. OCSP responder: "Yes"

Privacy leak:
❌ OCSP provider knows: Client is visiting website.com
❌ Can track user browsing history
❌ Single point of tracking

RFC 6066 Solution: OCSP Stapling

1. Server pre-queries OCSP responder
2. Server caches OCSP response
3. Client connects to website.com
4. Server sends: certificate + OCSP response (stapled)
5. Client verifies OCSP response

Benefits:
✅ No privacy leak (client doesn't contact OCSP)
✅ Faster (no extra round-trip)
✅ More reliable (works even if OCSP down)

Our implementation compliance:
✅ OCSP Stapling configuration examples (Nginx, Apache)
✅ OCSP response caching
✅ Testing instructions
```

## 3. Industry Requirements

### 3.1. CA/Browser Forum Baseline Requirements

**Tại sao quan trọng?**

```
CA/Browser Forum:
- Consortium of CAs and browser vendors
- Google, Mozilla, Apple, Microsoft, Let's Encrypt, DigiCert, etc.
- Publishes "Baseline Requirements"
- Browsers REJECT certificates not compliant

If not compliant:
❌ Chrome: "Your connection is not private"
❌ Firefox: "Warning: Potential Security Risk"
❌ Safari: "This Connection Is Not Private"

Compliance = MANDATORY for public CAs
```

**Key Requirements:**

| Requirement | Baseline Req Section | Rationale |
|-------------|---------------------|-----------|
| Max validity: 398 days | 6.3.2 | ✅ Limits key compromise exposure |
| Domain validation | 3.2.2.4 | ✅ Prevents domain hijacking |
| CAA checking | 3.2.2.8 | ✅ Domain owner controls which CAs can issue |
| Certificate Transparency | 7.1.2.7 | ✅ Public log of all certificates (detect fraud) |
| OCSP required | 4.9.7 | ✅ Real-time revocation checking |
| SHA-256 minimum | 7.1.3.1 | ✅ No SHA-1 (broken) |
| RSA 2048-bit minimum | 6.1.5 | ✅ Adequate security |
| Subject Alt Name required | 7.1.4.2.1 | ✅ Modern browsers require SAN |

**Our Implementation Compliance:**

```
✅ Certificate validity: 398 days for servers
✅ Domain validation: DNS TXT, HTTP file, email
✅ CAA checking: Documented in docs/06-ocsp-guide.md
✅ Certificate Transparency: Recommendation in docs
✅ OCSP: Full implementation (setup-ocsp.sh)
✅ SHA-256: Default hash algorithm
✅ RSA 2048-bit: Minimum key size
✅ Subject Alt Name: Required in server certificates
```

### 3.2. WebTrust Principles

**Tại sao cần WebTrust?**

```
WebTrust:
- Audit framework for CAs
- Required to be in browser root programs
- Annual audit required

Without WebTrust:
❌ Cannot distribute Root CA with browsers
❌ Users must manually import Root CA
❌ Not trusted by default

With WebTrust:
✅ Root CA in browser trust stores
✅ Automatic trust (no manual import)
✅ Industry credibility

WebTrust principles:
1. Business practices disclosure
2. Service integrity
3. Environmental controls
4. Information security

Our project:
⚠️ WebTrust not applicable (internal/educational CA)
✅ But we follow WebTrust principles for learning
✅ Documented in Certificate Policy (docs/07-certificate-policy.md)
```

### 3.3. Certificate Transparency (CT)

**Tại sao cần CT?**

```
Problem: Fraudulent certificates undetected

Before Certificate Transparency:
- CA issues certificate
- Nobody knows (unless they see it in use)
- Fraudulent certificate can exist for years

Example: DigiNotar (2011)
- Issued 531 fraudulent certificates
- Discovered accidentally (user noticed fake cert)
- If not noticed, attacks would continue

RFC 6962 Solution: Certificate Transparency

All certificates must be logged in public CT logs:

1. CA issues certificate
2. CA submits to CT log (Google, Cloudflare, etc.)
3. CT log returns Signed Certificate Timestamp (SCT)
4. Certificate includes SCT
5. Browsers reject certificates without SCT

Benefits:
✅ Public visibility (anyone can monitor)
✅ Domain owners can monitor for their domains
✅ Detect fraudulent certificates quickly
✅ Accountability (CA actions are public)

How to use CT:
```

**Monitor your domain:**

```bash
# Check Certificate Transparency logs for your domain
curl "https://crt.sh/?q=example.com&output=json"

# Or use tools:
# - crt.sh (web interface)
# - Facebook CT Monitor
# - CertSpotter (by SSLMate)
```

**Our implementation:**

```
⚠️ CT logging not implemented (requires public CT log)
✅ Documented how to use CT for monitoring
✅ Recommended for production CAs
✅ Example scripts for CT monitoring in examples/
```

## 4. Compliance Frameworks

### 4.1. PCI DSS (Payment Card Industry Data Security Standard)

**Relevance to PKI:**

```
PCI DSS: Required for payment card processing

PKI-related requirements:

Requirement 3.6: Cryptographic key management
✅ Our implementation:
   - Root CA key in offline storage
   - M-of-N key ceremony (3-of-5)
   - HSM recommended
   - Key rotation policy

Requirement 4.1: Strong cryptography for transmission
✅ Our implementation:
   - TLS 1.2+ only
   - Strong cipher suites
   - Server certificates

Requirement 8.3: Multi-factor authentication for non-console admin access
✅ Our implementation:
   - Two-person rule for CA operations
   - Smartcards for key custodians

Requirement 10: Track and monitor all access
✅ Our implementation:
   - Comprehensive audit logging
   - Log retention: 7 years
   - Tamper-evident logs
```

### 4.2. SOC 2 (Service Organization Control 2)

**Relevance to PKI:**

```
SOC 2 Trust Service Criteria:

CC6.1: Logical and physical access controls
✅ Our implementation:
   - Physical security for Root CA
   - Network segmentation for Intermediate CA
   - RBAC (Role-Based Access Control)

CC6.6: Logical access security measures
✅ Our implementation:
   - Strong authentication (MFA)
   - Privilege management
   - Access review

CC6.8: Restrict physical access
✅ Our implementation:
   - Vault for Root CA
   - Badge access for server room
   - Two-person rule

CC7.2: Detect security events
✅ Our implementation:
   - IDS/IPS
   - SIEM
   - Real-time alerting

CC7.4: Respond to security incidents
✅ Our implementation:
   - Incident response plan
   - Certificate revocation procedures
   - Communication plan
```

### 4.3. GDPR (General Data Protection Regulation)

**Relevance to PKI:**

```
GDPR: EU data protection law

PKI implications:

Article 5: Data minimization
✅ Our implementation:
   - Collect only necessary information
   - No PII in certificates (unless required)
   - Email address optional

Article 17: Right to be forgotten
⚠️ Challenge for PKI:
   - Certificates cannot be "forgotten"
   - Revocation ≠ deletion
   - Logs must be retained (security)

Solution:
   - Certificate Policy disclaimer
   - Subscriber consent at application
   - Anonymize logs (where possible)

Article 32: Security of processing
✅ Our implementation:
   - Encryption (AES-256)
   - Access control
   - Audit logs
   - Incident response

Article 33: Breach notification (72 hours)
✅ Our implementation:
   - Incident response plan
   - Communication procedures
   - Contact information in CP
```

## 5. Audit and Certification

### 5.1. Why Audit Matters

```
┌─────────────────────────────────────────────────────────────────┐
│ Trust but Verify                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ CA claims:                                                      │
│ "We follow security best practices"                            │
│ "We protect private keys"                                       │
│ "We validate certificate requests"                             │
│                                                                 │
│ Questions:                                                      │
│ - How do we know this is true?                                 │
│ - What if they're lying?                                        │
│ - What if they think they're secure but aren't?                │
│                                                                 │
│ Answer: Independent audit                                       │
│                                                                 │
│ Third-party auditor:                                            │
│ ✅ Reviews policies                                              │
│ ✅ Examines procedures                                           │
│ ✅ Tests controls                                                │
│ ✅ Interviews staff                                              │
│ ✅ Reviews logs                                                  │
│ ✅ Issues audit report                                           │
│                                                                 │
│ Result:                                                         │
│ ✅ Objective assessment                                          │
│ ✅ Identify gaps                                                 │
│ ✅ Improve security                                              │
│ ✅ Build trust                                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2. Audit Types

| Audit Type | Purpose | Frequency | Cost |
|------------|---------|-----------|------|
| **WebTrust** | Public CA qualification | Annual | $20K-50K |
| **SOC 2 Type II** | Service provider controls | Annual | $15K-40K |
| **PCI DSS** | Payment card compliance | Annual | $10K-30K |
| **ISO 27001** | Information security | Annual | $15K-30K |
| **Internal Audit** | Self-assessment | Quarterly | $0-5K |
| **Penetration Test** | Vulnerability assessment | Bi-annual | $10K-25K |

### 5.3. Audit Preparation Checklist

```
Pre-Audit Preparation:

Documentation:
□ Certificate Policy (CP) published
□ Certificate Practice Statement (CPS) documented
□ Standard Operating Procedures (SOPs) written
□ Incident response plan documented
□ Business continuity plan documented
□ Disaster recovery plan documented

Technical:
□ Audit logs enabled and retained
□ Access controls implemented
□ Monitoring and alerting configured
□ Backups tested
□ Patch management documented
□ Network diagrams up to date

Personnel:
□ Background checks completed
□ Training records maintained
□ Non-disclosure agreements signed
□ Access rights documented
□ Separation of duties enforced

Physical:
□ Physical security measures documented
□ Access logs maintained
□ Video surveillance records
□ Key ceremony documentation

Compliance:
□ Self-assessment completed
□ Gap analysis performed
□ Remediation plans for findings
□ Management review conducted
```

### 5.4. Our Project Compliance Status

```
Compliance Scorecard:

✅ IMPLEMENTED:
   - RFC 5280 compliant certificates
   - RFC 6960 OCSP implementation
   - CA/Browser Forum certificate validity (398 days)
   - SHA-256 signatures
   - RSA 2048-bit minimum
   - Subject Alt Name required
   - Comprehensive audit logging
   - Documented policies (CP/CPS)
   - Design rationale documented
   - Threat model documented

⚠️ PARTIALLY IMPLEMENTED:
   - Certificate Transparency (recommended, not implemented)
   - CAA checking (documented, not automated)
   - OCSP Stapling (documented, requires web server config)
   - HSM (recommended, not required for educational use)

❌ NOT APPLICABLE (Educational CA):
   - WebTrust audit
   - Public CT log submission
   - Browser root program inclusion
   - Commercial liability insurance

VERDICT: Compliant for internal/educational CA ✅
         Ready for learning and development use ✅
         Not for public/commercial use without additional work ⚠️
```

---

**Key Takeaways:**

✅ **Standards** provide proven, interoperable solutions
✅ **Compliance** is mandatory for public CAs
✅ **Following standards** ≠ checkbox exercise, it's **security best practice**
✅ **Audits** verify claims and build trust
✅ **Our implementation** follows standards for educational value

**Summary of All Docs:**

1. [Protocol Design](01-protocol-design.md) - Architecture overview
2. [CA Setup](02-ca-setup.md) - Installation guide
3. [Certificate Management](03-certificate-management.md) - Operations
4. [Best Practices](04-best-practices.md) - Security guidance
5. [Troubleshooting](05-troubleshooting.md) - Problem solving
6. [OCSP Guide](06-ocsp-guide.md) - OCSP implementation
7. **[Certificate Policy](07-certificate-policy.md) - Policy framework** ← NEW
8. **[Design Rationale](08-design-rationale.md) - Why decisions** ← NEW
9. **[Threat Model](09-threat-model.md) - Security analysis** ← NEW
10. **[Compliance](10-compliance-standards.md) - Standards rationale** ← NEW
