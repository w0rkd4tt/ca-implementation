# Threat Model và Risk Analysis

## Mục lục

- [1. Threat Modeling Methodology](#1-threat-modeling-methodology)
- [2. PKI Threat Landscape](#2-pki-threat-landscape)
- [3. Attack Scenarios](#3-attack-scenarios)
- [4. Risk Assessment](#4-risk-assessment)
- [5. Mitigation Strategies](#5-mitigation-strategies)

## 1. Threat Modeling Methodology

### 1.1. STRIDE Model

Chúng ta sử dụng **STRIDE** framework (Microsoft) để phân tích threats:

```
STRIDE:
S - Spoofing Identity          (Giả mạo danh tính)
T - Tampering with Data        (Sửa đổi dữ liệu)
R - Repudiation                (Chối bỏ hành động)
I - Information Disclosure     (Rò rỉ thông tin)
D - Denial of Service          (Từ chối dịch vụ)
E - Elevation of Privilege     (Leo thang đặc quyền)
```

### 1.2. Attack Tree Analysis

```
ROOT GOAL: Compromise PKI Infrastructure

├── 1. Compromise Root CA Private Key
│   ├── 1.1 Physical Access
│   │   ├── 1.1.1 Break into facility
│   │   ├── 1.1.2 Insider threat
│   │   └── 1.1.3 Social engineering
│   ├── 1.2 Cryptographic Attack
│   │   ├── 1.2.1 Brute force RSA key
│   │   └── 1.2.2 Side-channel attack on HSM
│   └── 1.3 Supply Chain Attack
│       ├── 1.3.1 Compromised HSM
│       └── 1.3.2 Backdoored firmware
│
├── 2. Compromise Intermediate CA
│   ├── 2.1 Network Attack
│   │   ├── 2.1.1 Remote code execution
│   │   ├── 2.1.2 SQL injection (if using DB)
│   │   └── 2.1.3 Malware infection
│   ├── 2.2 Credential Theft
│   │   ├── 2.2.1 Password cracking
│   │   ├── 2.2.2 Phishing admin
│   │   └── 2.2.3 Keylogger
│   └── 2.3 Configuration Weakness
│       ├── 2.3.1 Weak file permissions
│       └── 2.3.2 Unpatched vulnerabilities
│
├── 3. Issue Fraudulent Certificates
│   ├── 3.1 Compromise RA (Registration Authority)
│   ├── 3.2 Bypass Identity Validation
│   │   ├── 3.2.1 DNS hijacking
│   │   └── 3.2.2 Email account compromise
│   └── 3.3 Exploit Automation Bugs
│
└── 4. Man-in-the-Middle Attacks
    ├── 4.1 Compromise OCSP Responder
    ├── 4.2 Serve Stale CRL
    └── 4.3 Block Revocation Checking
```

## 2. PKI Threat Landscape

### 2.1. Threat Actors

| Actor | Motivation | Capability | Likelihood |
|-------|-----------|------------|------------|
| **Script Kiddies** | Fun, Learning | Low | High |
| **Cybercriminals** | Financial Gain | Medium-High | Medium |
| **Insider (Malicious)** | Revenge, Greed | High | Low |
| **Insider (Negligent)** | Carelessness | Low | High |
| **Competitors** | Business Advantage | Medium | Low |
| **Nation-States** | Espionage, Sabotage | Very High | Very Low |
| **Hacktivists** | Ideology | Medium | Low |

### 2.2. Real-World PKI Incidents

#### DigiNotar (2011) - CA Compromise

```
═══════════════════════════════════════════════════════════════════
INCIDENT: DigiNotar CA Compromise
DATE: July 2011 (discovered)
═══════════════════════════════════════════════════════════════════

ATTACK:
- Attacker compromised DigiNotar CA servers
- Issued 531 fraudulent certificates
- Including: *.google.com, *.cia.gov, *.mossad.gov.il
- Used in Man-in-the-Middle attacks in Iran

ROOT CAUSE:
❌ Weak server security (outdated software)
❌ No network segmentation
❌ Weak passwords
❌ No monitoring/alerting
❌ Poor incident response

IMPACT:
- 300,000+ users affected
- DigiNotar went bankrupt
- All DigiNotar certificates revoked
- Trust destroyed

LESSONS LEARNED:
✅ Monitoring is critical
✅ Defense in depth
✅ Rapid incident response
✅ Transparency matters
```

#### Comodo (2011) - RA Compromise

```
═══════════════════════════════════════════════════════════════════
INCIDENT: Comodo RA Compromise
DATE: March 2011
═══════════════════════════════════════════════════════════════════

ATTACK:
- Attacker compromised Italian RA (InstantSSL)
- Issued 9 fraudulent certificates
- Targets: gmail.com, yahoo.com, live.com, addons.mozilla.org

ROOT CAUSE:
❌ RA had weak security
❌ RA had ability to issue certificates directly
❌ No rate limiting
❌ Insufficient validation checks

IMPACT:
- Certificates revoked quickly
- Firefox/Chrome pushed emergency updates
- Comodo survived (Root CA not compromised)

LESSONS LEARNED:
✅ Separate Root CA from operational systems
✅ Limit RA capabilities
✅ Implement rate limiting
✅ Multi-factor authentication
✅ Certificate Transparency (now mandatory)
```

#### Let's Encrypt CAA Bug (2020)

```
═══════════════════════════════════════════════════════════════════
INCIDENT: Let's Encrypt CAA Checking Bug
DATE: February 2020
═══════════════════════════════════════════════════════════════════

ISSUE:
- Bug in CAA (Certificate Authority Authorization) checking code
- Certificates issued without proper CAA validation
- 3 million certificates affected

ROOT CAUSE:
❌ Software bug
❌ Insufficient testing

IMPACT:
- Revoked 3 million certificates
- 48-hour grace period for renewal
- Massive operational burden on users

LESSONS LEARNED:
✅ Thorough testing of validation code
✅ Gradual rollout of changes
✅ Transparency in incident handling
✅ Adequate grace period for renewals
```

## 3. Attack Scenarios

### 3.1. Root CA Key Compromise

**Scenario:**

```
Attacker Goal: Obtain Root CA private key

Method: Social Engineering + Physical Access

1. Reconnaissance:
   - Identify key custodians (LinkedIn, social media)
   - Learn organization structure
   - Identify physical security measures

2. Social Engineering:
   - Phish 3 of 5 key custodians
   - Pretend to be "auditor" requesting key ceremony
   - Create urgency ("emergency certificate needed")

3. Physical Attack:
   - Break into facility during "ceremony"
   - Force custodians to insert smartcards
   - Extract private key

Impact: CATASTROPHIC
- All issued certificates become untrustworthy
- Complete loss of trust
- Business destroyed
```

**Likelihood:** Very Low (with proper controls)

**Mitigations:**

```
✅ Two-Person Rule (3-of-5 key ceremony)
   → Cannot force single person

✅ Witness Required (auditor, lawyer present)
   → Attack visible to others

✅ Physical Security (vault, guards, cameras)
   → Difficult to break in

✅ Key Ceremony Schedule (planned, documented)
   → Fake urgency detected

✅ Background Checks (custodians)
   → Reduced insider threat

✅ HSM (key never leaves hardware)
   → Cannot extract even with physical access

✅ Monitoring (access logs, video)
   → Detection and forensics
```

### 3.2. Intermediate CA Network Compromise

**Scenario:**

```
Attacker Goal: Issue fraudulent certificates

Method: Remote Code Execution

1. Reconnaissance:
   - Scan Intermediate CA server
   - Identify services (SSH, HTTP, etc.)
   - Find vulnerabilities (CVEs)

2. Exploitation:
   - Exploit unpatched vulnerability
   - Gain shell access
   - Escalate privileges (to root)

3. Persistence:
   - Install backdoor
   - Create admin account
   - Modify CA software

4. Malicious Action:
   - Issue fraudulent certificates
   - Sign with Intermediate CA key
   - Cover tracks (delete logs)

Impact: HIGH
- Fraudulent certificates issued
- MitM attacks possible
- Damage to reputation

Recovery:
✅ Revoke Intermediate CA certificate
✅ Issue new Intermediate CA
✅ Re-issue all end-entity certificates
✅ Timeline: Days (not months like Root CA compromise)
```

**Likelihood:** Medium (without proper security)

**Mitigations:**

```
✅ Network Segmentation
   - Intermediate CA in separate VLAN
   - Firewall rules (deny all except necessary)
   - No direct internet access

✅ Hardened OS
   - Minimal services
   - Disable unnecessary accounts
   - SELinux/AppArmor

✅ Regular Patching
   - Security updates within 24 hours
   - Automated patch management

✅ Intrusion Detection (IDS/IPS)
   - Detect exploit attempts
   - Alert on anomalies
   - Automatic blocking

✅ Monitoring & Logging
   - SIEM (Security Information and Event Management)
   - Real-time alerts
   - Log forwarding (cannot delete)

✅ File Integrity Monitoring (FIM)
   - Detect unauthorized changes
   - Alert on CA software modifications

✅ HSM for Key Storage
   - Private key never on filesystem
   - Cannot extract even with root access
```

### 3.3. DNS Hijacking (Domain Validation Bypass)

**Scenario:**

```
Attacker Goal: Get certificate for victim.com (without owning it)

Method: DNS Hijacking

1. Reconnaissance:
   - Identify victim's DNS provider
   - Research DNS provider security

2. Attack DNS Provider:
   - Phish DNS provider admin
   - OR exploit DNS provider vulnerability
   - Gain access to DNS control panel

3. Hijack Domain Validation:
   - Request certificate for victim.com
   - CA sends validation challenge:
     * Create TXT record: _pki-validation.victim.com
   - Attacker creates TXT record (controls DNS)
   - CA validates → Success!
   - CA issues certificate

4. Man-in-the-Middle:
   - Set up fake server with fraudulent certificate
   - Intercept traffic to victim.com
   - Steal credentials, data

Impact: HIGH
- Impersonate victim website
- Steal user data
- Damage to victim reputation
```

**Likelihood:** Low-Medium (depends on DNS provider security)

**Mitigations:**

```
✅ Multi-Perspective Validation
   - Check DNS from multiple locations
   - Different geographic regions
   - Different DNS servers
   - Harder to hijack all perspectives

✅ CAA Records (Certificate Authority Authorization)
   - victim.com sets: CAA 0 issue "authorized-ca.com"
   - Only authorized-ca.com can issue certificates
   - Other CAs must reject requests

✅ Certificate Transparency (CT)
   - All certificates logged publicly
   - Victim monitors CT logs for their domain
   - Detect fraudulent certificates quickly

✅ DNSSEC
   - Cryptographic signatures on DNS records
   - Prevents DNS hijacking
   - Validates DNS chain of trust

✅ Email Validation Backup
   - If DNS validation suspicious, require email validation too
   - Harder to compromise both DNS AND email
```

### 3.4. OCSP Responder Compromise

**Scenario:**

```
Attacker Goal: Make revoked certificate appear valid

Method: Compromise OCSP Responder

1. Attack:
   - Compromise OCSP responder server
   - Obtain OCSP signing key

2. Malicious Action:
   - Revoked certificate: 1234ABCD
   - Client queries OCSP for 1234ABCD
   - Attacker's OCSP responds: "good" (lie)
   - Client accepts revoked certificate

3. Use Revoked Certificate:
   - Use compromised private key
   - MitM attacks
   - Impersonation

Impact: MEDIUM
- Revoked certificates appear valid
- Cannot detect compromised certificates
- Time-limited (until OCSP cert expires)
```

**Likelihood:** Low-Medium

**Mitigations:**

```
✅ Short OCSP Certificate Validity (1 year)
   - Limits damage window
   - Forces annual key rotation

✅ OCSP Response Signing Time
   - Timestamp in OCSP response
   - Detect replayed old responses

✅ Nonce in OCSP Request
   - Client includes random nonce
   - Response must include same nonce
   - Prevents replay attacks

✅ Certificate Transparency
   - OCSP signing certificate logged
   - Detect unauthorized OCSP certificates

✅ Monitoring
   - Monitor OCSP responder for anomalies
   - Alert on unusual response patterns
   - Rate limiting

✅ Separate OCSP Key
   - Not CA private key
   - Compromise doesn't affect CA
```

## 4. Risk Assessment

### 4.1. Risk Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│                    PKI Risk Matrix                              │
│                                                                 │
│  Impact                                                         │
│    ↑                                                            │
│    │                                                            │
│  C │  [Medium]        [HIGH]          [CRITICAL]              │
│  r │                                                            │
│  i │   - RA           - Intermediate  - Root CA               │
│  t │   Compromise     CA Compromise   Key Compromise          │
│  i │                  - DNS Hijacking                          │
│  c │                                                            │
│  a │                                                            │
│  l │                                                            │
│    │                                                            │
│  H │  [LOW]           [Medium]        [HIGH]                  │
│  i │                                                            │
│  g │   - DDoS         - OCSP          - Malicious             │
│  h │   - Server       Compromise      Insider                 │
│    │   Outage         - Weak                                   │
│    │                  Validation                               │
│    │                                                            │
│  M │  [Minimal]       [LOW]           [Medium]                │
│  e │                                                            │
│  d │   - Minor        - Script        - Phishing              │
│  i │   Config         Kiddies         Attack                  │
│  u │   Error          - Port Scan                             │
│  m │                                                            │
│    │                                                            │
│  L │  [Minimal]       [Minimal]       [LOW]                   │
│  o │                                                            │
│  w │   - Logging      - Weak          - Social               │
│    │   Failure        Password        Engineering             │
│    │                  (Non-admin)                              │
│    │                                                            │
│    └───────────────────────────────────────────────────→       │
│         Rare          Unlikely        Likely        Frequent   │
│                                                                 │
│                       Likelihood                                │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2. Risk Scoring

| Threat | Likelihood | Impact | Risk Score | Priority |
|--------|-----------|--------|------------|----------|
| Root CA Key Compromise | Rare (1) | Critical (5) | 5 | P0 (Prevent) |
| Intermediate CA Compromise | Unlikely (2) | High (4) | 8 | P1 (Monitor) |
| DNS Hijacking | Unlikely (2) | High (4) | 8 | P1 (Mitigate) |
| OCSP Compromise | Unlikely (2) | Medium (3) | 6 | P2 (Monitor) |
| Malicious Insider | Unlikely (2) | High (4) | 8 | P1 (Prevent) |
| Phishing Attack | Likely (4) | Medium (3) | 12 | P1 (Train) |
| DDoS Attack | Likely (4) | Medium (3) | 12 | P2 (Mitigate) |
| Weak Validation | Unlikely (2) | Medium (3) | 6 | P2 (Test) |
| Configuration Error | Likely (4) | Low (2) | 8 | P2 (Review) |

**Risk Score = Likelihood × Impact**

**Priority:**
- **P0 (Critical):** Prevent at all costs
- **P1 (High):** Active mitigation required
- **P2 (Medium):** Monitoring and periodic review
- **P3 (Low):** Accept risk with documentation

## 5. Mitigation Strategies

### 5.1. Defense in Depth Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                  Defense in Depth - PKI                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Layer 7: Policy & Procedures                                  │
│           └─> Certificate Policy, CPS, Incident Response        │
│                                                                 │
│  Layer 6: People & Training                                    │
│           └─> Background checks, Security awareness, Drills    │
│                                                                 │
│  Layer 5: Physical Security                                    │
│           └─> Vault, Guards, Cameras, Two-person rule          │
│                                                                 │
│  Layer 4: Cryptographic Controls                               │
│           └─> RSA 4096, SHA-256, HSM, M-of-N                  │
│                                                                 │
│  Layer 3: Application Security                                 │
│           └─> CA software hardening, Input validation, Logging │
│                                                                 │
│  Layer 2: Host Security                                        │
│           └─> Hardened OS, Patching, FIM, Antivirus           │
│                                                                 │
│  Layer 1: Network Security                                     │
│           └─> Firewall, IDS/IPS, Segmentation, VPN            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2. Control Mapping

| Threat | Primary Control | Secondary Control | Tertiary Control |
|--------|----------------|-------------------|------------------|
| **Root CA Compromise** | Offline storage | M-of-N (3-of-5) | Physical security |
| **Intermediate Compromise** | Network segmentation | Hardened OS | IDS/IPS |
| **DNS Hijacking** | Multi-perspective validation | CAA records | Certificate Transparency |
| **OCSP Compromise** | Separate OCSP key | Short validity (1 year) | Monitoring |
| **Insider Threat** | Background checks | Two-person rule | Audit logs |
| **Phishing** | Security training | MFA | Email filtering |
| **DDoS** | Load balancing | Rate limiting | CDN |

### 5.3. Continuous Improvement

```
Security Maturity Model:

Level 1: Reactive (Ad-hoc)
❌ Manual processes
❌ No monitoring
❌ React to incidents

Level 2: Defined (Documented)
⚠️ Documented procedures
⚠️ Basic logging
⚠️ Incident response plan

Level 3: Managed (Proactive)
✅ Automated monitoring
✅ Regular testing
✅ Threat intelligence

Level 4: Optimized (Predictive)
✅ Predictive analytics
✅ AI-driven detection
✅ Continuous adaptation

GOAL: Achieve Level 3 within 1 year
```

---

**Key Takeaways:**

✅ **Threat modeling** is essential before implementing PKI
✅ **Real-world incidents** provide valuable lessons
✅ **Defense in depth** prevents single point of failure
✅ **Risk assessment** prioritizes mitigation efforts
✅ **Continuous monitoring** detects attacks early
✅ **Incident response** limits damage

**Next:** [Compliance and Standards](10-compliance-standards.md)
