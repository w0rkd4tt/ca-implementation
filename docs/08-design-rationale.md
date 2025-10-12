# PKI Design Rationale - Tại sao thiết kế như vậy?

## Mục lục

- [1. Giới thiệu](#1-giới-thiệu)
- [2. Architecture Decisions](#2-architecture-decisions)
- [3. Cryptographic Choices](#3-cryptographic-choices)
- [4. Certificate Validity Periods](#4-certificate-validity-periods)
- [5. Revocation Strategy](#5-revocation-strategy)
- [6. Operational Security](#6-operational-security)

## 1. Giới thiệu

### 1.1. Mục đích document

Document này giải thích **TẠI SAO** chúng ta thiết kế PKI infrastructure như vậy, không chỉ là **LÀM THẾ NÀO**.

```
┌─────────────────────────────────────────────────────────────────┐
│ How vs Why                                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ HOW (Cách làm):                                                │
│ "Chúng ta sử dụng RSA 4096-bit cho Root CA"                   │
│                                                                 │
│ WHY (Tại sao):                                                 │
│ "RSA 4096-bit vì:                                              │
│  - Root CA có lifetime 20 năm                                  │
│  - Cần chống lại quantum computing (trong vài năm tới)        │
│  - 2048-bit có thể bị crack trong 10-15 năm                   │
│  - 4096-bit đủ mạnh cho 20+ năm                               │
│  - Trade-off: Chậm hơn nhưng security > performance cho CA    │
│                                                                 │
│ ALTERNATIVES CONSIDERED (Lựa chọn khác đã xem xét):           │
│  - RSA 2048-bit: Không đủ mạnh cho 20 năm                     │
│  - RSA 8192-bit: Overkill, chậm, không cần thiết             │
│  - ECC P-384: Tốt nhưng ít được support hơn                   │
│  - Post-quantum: Chưa standardized                            │
│                                                                 │
│ DECISION: RSA 4096-bit                                         │
│ RATIONALE: Balance giữa security, compatibility, và lifetime   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2. Decision Framework

Mỗi design decision trong PKI được đánh giá theo 5 tiêu chí:

```
Decision Criteria:

1. SECURITY
   - Cryptographic strength
   - Attack resistance
   - Future-proofing
   Weight: 40%

2. COMPLIANCE
   - Standards compliance (RFC, CA/BF)
   - Regulatory requirements
   - Industry best practices
   Weight: 25%

3. USABILITY
   - Ease of use
   - User experience
   - Error prevention
   Weight: 15%

4. PERFORMANCE
   - Speed
   - Scalability
   - Resource usage
   Weight: 10%

5. MAINTAINABILITY
   - Operational complexity
   - Cost
   - Skillset requirements
   Weight: 10%
```

## 2. Architecture Decisions

### 2.1. Two-Tier Hierarchy (Root CA → Intermediate CA)

#### Decision

```
Architecture: Root CA → Intermediate CA → End-Entity Certificates

NOT:
- Single-tier (Root CA → End-Entity directly)
- Three-tier (Root → Policy CA → Intermediate → End-Entity)
```

#### Rationale

**✅ Why two-tier?**

1. **Security Benefits:**
   ```
   Root CA:
   - Offline (cold storage)
   - Rarely used (only to sign Intermediate)
   - If compromised: Catastrophic but unlikely

   Intermediate CA:
   - Online (operational)
   - Used daily (sign end-entity certs)
   - If compromised: Revoke and reissue from Root

   Impact isolation:
   Root compromise → Trust collapse (rare)
   Intermediate compromise → Revoke intermediate, issue new one (recoverable)
   ```

2. **Operational Flexibility:**
   - Multiple Intermediate CAs for different purposes:
     * Intermediate CA 1: Server certificates
     * Intermediate CA 2: Client certificates
     * Intermediate CA 3: Code signing
   - Easy to revoke one Intermediate without affecting others

3. **Compliance:**
   - CA/Browser Forum recommends two-tier minimum
   - WebTrust audits expect offline Root CA
   - Industry standard for commercial CAs

**❌ Why NOT single-tier?**

```
Single-tier (Root CA → End-Entity directly):

Pros:
✅ Simpler architecture
✅ Shorter certificate chain
✅ Faster validation

Cons:
❌ Root CA must be online (security risk)
❌ No damage isolation if Root compromised
❌ Cannot revoke subset of certificates easily
❌ Not compliant with CA/Browser Forum
❌ No operational flexibility

VERDICT: Cons outweigh Pros for production CA
```

**❌ Why NOT three-tier?**

```
Three-tier (Root → Policy CA → Intermediate → End-Entity):

Used by: Large enterprises, government PKI

Pros:
✅ Policy separation (different assurance levels)
✅ Better organizational structure
✅ Finer-grained control

Cons:
❌ More complex
❌ Longer certificate chains (slower validation)
❌ Higher operational cost
❌ Overkill for most use cases

VERDICT: Two-tier sufficient for educational/internal CA
         Three-tier only if you need policy separation
```

#### Trade-offs

| Aspect | Single-Tier | Two-Tier | Three-Tier |
|--------|-------------|----------|------------|
| Security | ⚠️ Low | ✅ High | ✅ Very High |
| Complexity | ✅ Simple | ⚠️ Moderate | ❌ Complex |
| Flexibility | ❌ Low | ✅ High | ✅ Very High |
| Performance | ✅ Fast | ⚠️ Moderate | ❌ Slower |
| Compliance | ❌ No | ✅ Yes | ✅ Yes |
| Cost | ✅ Low | ⚠️ Moderate | ❌ High |

**Chosen: Two-Tier** (best balance for educational/internal CA)

### 2.2. Offline Root CA

#### Decision

```
Root CA: OFFLINE (cold storage)
- Stored on encrypted USB drive
- Air-gapped from network
- Only powered on for:
  * Signing Intermediate CA certificates
  * Issuing CRL for Root CA
  * Emergency procedures
```

#### Rationale

**✅ Why offline?**

1. **Attack Surface Reduction:**
   ```
   Online CA:
   - Network attacks
   - Remote exploitation
   - Malware
   - Insider threats (remote access)
   - 24/7 vulnerability window

   Offline CA:
   - Physical access required
   - No network attacks
   - No remote exploitation
   - Controlled access (safe/vault)
   - Vulnerability window: Hours per year (not 24/7)
   ```

2. **Real-world Examples:**
   ```
   DigiNotar (2011):
   - Online CA compromised
   - Issued 531 fraudulent certificates
   - Including *.google.com
   - Company went bankrupt
   - If Root was offline: Damage limited to Intermediate CA

   Comodo (2011):
   - Registration Authority compromised
   - Issued fraudulent certificates
   - Root CA not compromised (offline)
   - Revoked compromised Intermediate
   - Business continued

   LESSON: Offline Root CA = Insurance policy
   ```

3. **Compliance:**
   - WebTrust Principles require Root CA protection
   - CA/Browser Forum best practices: Offline Root
   - PCI DSS: Highest security for root keys

**❌ Why NOT online?**

```
Online Root CA:

Pros:
✅ Convenient (no manual intervention)
✅ Faster operations
✅ Automated renewal

Cons:
❌ Single point of failure
❌ Network attack surface
❌ Compromise = catastrophic loss
❌ Cannot revoke Root CA (trust anchor)
❌ All issued certificates become invalid
❌ Reputational damage
❌ Legal liability

VERDICT: Convenience < Security for Root CA
```

#### Implementation

**Physical Security:**

```
Root CA Storage:
1. Hardware:
   - Dedicated laptop (never connected to network)
   - Full disk encryption (LUKS/BitLocker/FileVault)
   - Strong BIOS password
   - Disabled network interfaces (firmware)

2. Key Storage:
   - FIPS 140-2 Level 3 HSM (ideal)
   - OR: Encrypted USB drive (acceptable for educational)
   - Passphrase: 20+ characters, stored separately
   - Backup key: Separate physical location

3. Physical Access:
   - Locked safe or bank vault
   - Two-person rule for access
   - Access logged (manual logbook)
   - Video surveillance

4. Usage Protocol:
   - Clean room (air-gapped)
   - Malware scan before use
   - Witness present (two-person rule)
   - Document all operations
   - Immediate return to storage
```

### 2.3. Intermediate CA Online

#### Decision

```
Intermediate CA: ONLINE (operational)
- Running 24/7
- Connected to network (controlled)
- Automatically signs end-entity certificates
- Generates CRL daily
- OCSP responder queries live
```

#### Rationale

**✅ Why online?**

1. **Operational Requirements:**
   ```
   Modern PKI needs:
   - Real-time certificate issuance (minutes, not days)
   - Automated revocation checking (OCSP)
   - Frequent CRL updates (24 hours)
   - Scale: Hundreds/thousands of certificates

   Cannot achieve with offline CA:
   - Manual signing = bottleneck
   - Delayed revocation = security risk
   - Poor user experience
   ```

2. **Risk Mitigation:**
   ```
   Intermediate CA compromise is recoverable:

   Step 1: Detect compromise (monitoring/alerts)
   Step 2: Shut down Intermediate CA
   Step 3: Revoke Intermediate CA certificate (using Root)
   Step 4: Issue new Intermediate CA certificate
   Step 5: Re-issue all end-entity certificates

   Time to recovery: Days (not months)
   Root CA still trusted
   ```

3. **Defense in Depth:**
   ```
   Intermediate CA security layers:

   Layer 1: Network security
   - Firewall (allow only necessary ports)
   - Network segmentation (VLAN)
   - IDS/IPS monitoring

   Layer 2: Host security
   - Hardened OS (minimal services)
   - Regular patching
   - Antivirus/EDR
   - Host-based firewall

   Layer 3: Application security
   - CA software hardening
   - Access control (RBAC)
   - Audit logging

   Layer 4: Key protection
   - HSM (if available)
   - Encrypted keystore
   - Strong passphrase

   Layer 5: Monitoring
   - 24/7 monitoring
   - Alerting on anomalies
   - Regular security audits
   ```

#### Trade-offs

| Aspect | Offline Intermediate | Online Intermediate |
|--------|---------------------|---------------------|
| Security | ✅ Higher | ⚠️ Lower (but acceptable) |
| Usability | ❌ Manual, slow | ✅ Automated, fast |
| Scalability | ❌ Limited | ✅ High |
| Compliance | ⚠️ Depends | ✅ Industry standard |
| Recoverability | ❌ Same as Root | ✅ Revoke and reissue |

**Chosen: Online Intermediate** (necessary for operational CA)

## 3. Cryptographic Choices

### 3.1. RSA vs ECC

#### Decision Matrix

```
Root CA: RSA 4096-bit
Intermediate CA: RSA 4096-bit
End-Entity Certificates: RSA 2048-bit (default)
                          ECC P-256 (optional)
```

#### Root CA: RSA 4096-bit

**✅ Why RSA 4096-bit?**

1. **Longevity (20-year lifetime):**
   ```
   Key strength over time:

   RSA 2048-bit:
   - Current: Secure (2024)
   - 2030: Secure (probably)
   - 2035: At risk
   - 2040: Likely broken
   - Lifetime: ~15 years safe

   RSA 4096-bit:
   - Current: Secure (overkill)
   - 2030: Secure
   - 2035: Secure
   - 2040: Secure (probably)
   - 2045: At risk
   - Lifetime: 20-25 years safe

   Root CA lifetime: 20 years
   → Need RSA 4096-bit
   ```

2. **Quantum Computing Threat:**
   ```
   Shor's Algorithm (quantum computer):
   - Can break RSA in polynomial time
   - Large quantum computer needed

   Timeline estimates:
   - 2025: Lab-scale quantum computers
   - 2030: Small-scale commercial
   - 2035: RSA 2048 at risk
   - 2040: RSA 4096 at risk

   RSA 4096 buys us time:
   - Harvest now, decrypt later attack
   - 4096-bit harder to break than 2048-bit
   - Migration path to post-quantum crypto
   ```

3. **Compatibility:**
   ```
   RSA 4096 support:
   ✅ All major browsers (100%)
   ✅ All operating systems
   ✅ All programming languages
   ✅ All hardware (though slower)

   Better than ECC P-521:
   ⚠️ Some legacy systems don't support
   ```

**❌ Why NOT RSA 2048-bit?**

```
RSA 2048-bit for Root CA:

Pros:
✅ Faster operations
✅ Smaller certificates
✅ Industry standard for end-entity certs

Cons:
❌ May not survive 20 years
❌ Quantum computing risk
❌ NIST: 2048-bit only until 2030
❌ No safety margin for Root CA

VERDICT: Not enough for 20-year Root CA
```

**❌ Why NOT ECC P-384/P-521?**

```
ECC P-384/P-521 for Root CA:

Pros:
✅ Smaller keys (384-bit ECC ≈ 7680-bit RSA)
✅ Faster operations
✅ Quantum-resistant (more than RSA)

Cons:
⚠️ Less compatibility (some legacy systems)
⚠️ Less familiar to operators
⚠️ Fewer tools support ECC CA operations
⚠️ Some embedded devices don't support

VERDICT: Good choice, but RSA 4096 more pragmatic
         Consider for next-gen CA
```

#### End-Entity Certificates: RSA 2048-bit

**✅ Why RSA 2048-bit?**

1. **Adequate Security for Short Lifetime:**
   ```
   End-entity certificate lifetime:
   - Server certs: 398 days (13 months)
   - Client certs: 365 days
   - Code signing: 3 years

   RSA 2048-bit secure for:
   - Current: ✅ Absolutely secure
   - Next 5 years: ✅ Secure
   - Next 10 years: ✅ Probably secure

   Since certs renewed annually:
   - Exposure window: 1 year (not 20 years)
   - 2048-bit is overkill for 1 year
   ```

2. **Performance:**
   ```
   TLS Handshake Performance:

   RSA 2048-bit:
   - Key generation: 100ms
   - Signing: 5ms
   - Verification: 0.5ms
   - Handshake: 2-3 RTT

   RSA 4096-bit:
   - Key generation: 1000ms (10x slower)
   - Signing: 40ms (8x slower)
   - Verification: 2ms (4x slower)
   - Handshake: 2-3 RTT (same, but slower)

   Impact on web server:
   - RSA 2048: 1000+ TLS handshakes/sec
   - RSA 4096: 200-300 TLS handshakes/sec

   For high-traffic websites:
   - RSA 4096 = 5x more CPU
   - Cost increase
   - Latency increase
   ```

3. **Compliance:**
   ```
   CA/Browser Forum Baseline Requirements:
   ✅ RSA 2048-bit minimum
   ✅ RSA 4096-bit allowed

   Industry standard:
   - 95% of websites: RSA 2048
   - 5% of websites: ECC P-256
   - <1% of websites: RSA 4096

   Recommendation: Follow industry standard
   ```

**Trade-off Table:**

| Aspect | RSA 2048 | RSA 4096 | ECC P-256 |
|--------|----------|----------|-----------|
| Security (1 year) | ✅ Sufficient | ✅ Overkill | ✅ Sufficient |
| Security (20 years) | ❌ Insufficient | ✅ Sufficient | ✅ Sufficient |
| Performance | ✅ Fast | ⚠️ Slow (5x CPU) | ✅ Fastest |
| Compatibility | ✅ 100% | ✅ 100% | ⚠️ 99% (some legacy) |
| Certificate Size | ⚠️ Moderate | ❌ Large | ✅ Small |
| Tooling Support | ✅ Excellent | ✅ Excellent | ⚠️ Good |

**Chosen:**
- **Root CA:** RSA 4096 (longevity)
- **Intermediate CA:** RSA 4096 (10-year lifetime)
- **End-Entity:** RSA 2048 (default), ECC P-256 (optional)

### 3.2. Hash Algorithm: SHA-256

#### Decision

```
Hash Algorithm: SHA-256
- For certificate signatures
- For OCSP responses
- For CRL signatures
- For CSR signatures
```

#### Rationale

**✅ Why SHA-256?**

1. **Security:**
   ```
   Hash function security levels:

   MD5:
   - Broken (1996): Collision attacks
   - DO NOT USE

   SHA-1:
   - Broken (2017): Google/CWI collision
   - Deprecated by all major browsers
   - DO NOT USE

   SHA-256:
   - No known practical attacks
   - Collision resistance: 2^128 operations
   - Preimage resistance: 2^256 operations
   - Expected to be secure until 2030+

   SHA-384/SHA-512:
   - More secure than SHA-256
   - Overkill for most use cases
   - Slower (slight)
   ```

2. **Compliance:**
   ```
   CA/Browser Forum:
   ✅ SHA-256 minimum
   ❌ SHA-1 prohibited since 2017

   NIST SP 800-57:
   ✅ SHA-256 approved until 2030+

   Browser requirements:
   ✅ SHA-256 required
   ```

3. **Performance:**
   ```
   Hash performance (per 1MB):
   - SHA-1: 450 MB/s
   - SHA-256: 350 MB/s (slightly slower)
   - SHA-512: 400 MB/s (faster on 64-bit)

   Impact: Negligible for PKI operations
   ```

**❌ Why NOT SHA-1?**

```
SHA-1:
- Collision found (2017)
- All browsers reject SHA-1 certificates
- Non-compliant
- Security risk

VERDICT: Never use SHA-1 in 2024+
```

**❌ Why NOT SHA-512?**

```
SHA-512:

Pros:
✅ More secure than SHA-256
✅ Faster on 64-bit systems
✅ Future-proof

Cons:
⚠️ Overkill (SHA-256 sufficient)
⚠️ Larger signatures (slight)
⚠️ Some old systems don't support

VERDICT: SHA-256 sufficient, SHA-512 if you want extra safety
```

### 3.3. Symmetric Encryption: AES-256

#### Decision

```
Symmetric encryption: AES-256
- For private key encryption (PKCS#8)
- For backup encryption
- For data at rest
```

#### Rationale

**✅ Why AES-256?**

1. **Security:**
   ```
   AES security levels:

   AES-128:
   - 2^128 brute force (secure)
   - Quantum computing: 2^64 (Grover's algorithm)
   - Still secure but reduced margin

   AES-256:
   - 2^256 brute force (overkill)
   - Quantum computing: 2^128 (Grover's algorithm)
   - Still secure even with quantum computers

   CA lifetime: 20 years
   → Need quantum-resistant encryption
   → AES-256 preferred
   ```

2. **Compliance:**
   ```
   NIST FIPS 197:
   ✅ AES-128 approved
   ✅ AES-256 approved (recommended for TOP SECRET)

   NSA Suite B:
   ✅ AES-256 for TOP SECRET

   FIPS 140-2:
   ✅ AES-256 required for Level 3+
   ```

3. **Performance:**
   ```
   AES performance (hardware-accelerated):
   - AES-128: 5 GB/s
   - AES-256: 4 GB/s (slightly slower)

   Impact: Negligible
   ```

## 4. Certificate Validity Periods

### 4.1. Validity Period Design

```
Certificate Validity Periods:

Root CA:          20 years
Intermediate CA:  10 years
Server (TLS):     398 days (13 months)
Client:           365 days (1 year)
Code Signing:     3 years
Email (S/MIME):   2 years
```

#### Root CA: 20 Years

**✅ Why 20 years?**

1. **Stability vs Security Balance:**
   ```
   Too short (e.g., 5 years):
   Cons:
   ❌ Frequent Root CA rotation
   ❌ All certificates must be reissued
   ❌ Trust store updates (browsers, OS)
   ❌ Operational complexity
   ❌ Downtime risk

   Too long (e.g., 30+ years):
   Cons:
   ❌ Crypto may be broken (quantum computing)
   ❌ Cannot upgrade to stronger algorithms
   ❌ Stuck with old crypto for decades

   20 years:
   ✅ Stable (don't need to rotate often)
   ✅ Crypto should survive (with RSA 4096)
   ✅ Can migrate to post-quantum in next rotation
   ✅ Industry practice
   ```

2. **Industry Standard:**
   ```
   Commercial CAs:
   - Let's Encrypt Root: 20 years
   - DigiCert Root: 25 years
   - GlobalSign Root: 25 years
   - Sectigo Root: 20 years

   Average: 20-25 years
   ```

3. **Compliance:**
   ```
   CA/Browser Forum:
   ⚠️ No specific limit for Root CA
   ✅ 20 years acceptable

   WebTrust:
   ✅ 20 years common practice
   ```

#### Server Certificate: 398 Days

**✅ Why 398 days (not 1 year / 2 years)?**

1. **CA/Browser Forum Requirement:**
   ```
   Certificate Validity Evolution:

   2015: 39 months (1185 days) - Too long!
   2018: 825 days (27 months) - Still long
   2020: 398 days (13 months) - Current requirement
   2024: 90 days? (Proposed, not yet)

   Rationale for shorter validity:
   ✅ Limits exposure of compromised keys
   ✅ Forces periodic re-validation
   ✅ Reduces impact of mis-issuance
   ✅ Encourages automation
   ```

2. **Why exactly 398 (not 365)?**
   ```
   398 days = 13 months:

   Benefit: Grace period for renewal

   Example:
   - Certificate issued: Jan 1, 2024
   - Expires: Feb 2, 2025 (398 days)
   - Renew 30 days early: Jan 1, 2025
   - New certificate expires: Feb 2, 2026

   If only 365 days:
   - Expires: Jan 1, 2025
   - Renew early: Dec 2, 2024
   - New expires: Dec 2, 2025
   - Lost time!

   398 days allows:
   - Renew anytime in the last month
   - No loss of validity period
   - Grace period for operational issues
   ```

3. **Security Benefits:**
   ```
   Short validity (398 days) vs Long (2+ years):

   Key Compromise Scenario:

   Long validity (2 years):
   - Attacker has 2 years to exploit
   - Takes longer to detect
   - More damage possible

   Short validity (398 days):
   - Attacker has <1 year to exploit
   - Certificate expires soon anyway
   - Forced to renew (chance to detect)
   - Less damage possible

   Mis-issuance Scenario:

   Long validity:
   - Bad certificate valid for 2 years
   - Must revoke explicitly
   - Revocation checking not always reliable

   Short validity:
   - Bad certificate expires in <1 year
   - Self-limiting damage
   - Defense in depth
   ```

**❌ Why NOT 90 days (like Let's Encrypt)?**

```
90-day validity:

Pros:
✅ Even more secure
✅ Shorter exposure window
✅ Forces automation

Cons:
❌ Requires automation (not all systems support)
❌ 4x more renewals per year
❌ Higher operational burden
❌ More room for error (missed renewal = outage)
❌ Not yet required by CA/BF

VERDICT: 398 days balances security and operational burden
         90 days better if you have automation
```

## 5. Revocation Strategy

### 5.1. CRL + OCSP (Defense in Depth)

#### Decision

```
Revocation Strategy: CRL + OCSP + OCSP Stapling

NOT:
- CRL only
- OCSP only
- No revocation checking
```

#### Rationale

**✅ Why both CRL and OCSP?**

1. **Different Use Cases:**
   ```
   CRL Best For:
   ✅ Offline verification
   ✅ Batch verification (many certificates)
   ✅ Legacy systems (no OCSP support)
   ✅ Air-gapped environments

   OCSP Best For:
   ✅ Real-time checking
   ✅ Online systems
   ✅ Single certificate queries
   ✅ Up-to-date status

   Together:
   ✅ Covers all scenarios
   ✅ Fallback if one fails
   ✅ Defense in depth
   ```

2. **Failure Scenarios:**
   ```
   Scenario 1: OCSP Responder Down
   - Client tries OCSP
   - OCSP times out
   - Fallback to CRL
   - Still works!

   Scenario 2: CRL Server Down
   - Client tries CRL
   - HTTP 503/timeout
   - Fallback to OCSP
   - Still works!

   Scenario 3: Both Down
   - Client tries OCSP → fail
   - Client tries CRL → fail
   - Soft-fail: Allow connection (with warning)
   - Rationale: Availability > Security

   Without both:
   - Single point of failure
   - If revocation service down → all TLS fails
   - Business impact
   ```

3. **Compliance:**
   ```
   CA/Browser Forum:
   ✅ MUST provide OCSP
   ✅ MUST provide CRL
   ⚠️ Both required (not either/or)

   RFC 5280:
   ✅ Recommends both

   Industry practice:
   - All major CAs: CRL + OCSP
   - Browsers: Check OCSP first, fallback to CRL
   ```

#### OCSP Stapling

**✅ Why OCSP Stapling?**

```
Traditional OCSP:

1. Client connects to server
2. Client extracts certificate
3. Client queries OCSP responder
4. OCSP responder responds
5. Client proceeds with TLS

Problems:
❌ Extra latency (1 RTT)
❌ Privacy leak (OCSP provider knows what sites you visit)
❌ OCSP responder can track users
❌ Single point of failure

OCSP Stapling:

1. Server queries OCSP responder (periodically)
2. Server caches OCSP response
3. Client connects to server
4. Server sends certificate + OCSP response (stapled)
5. Client verifies OCSP response
6. Client proceeds with TLS

Benefits:
✅ No extra latency (0 RTT)
✅ Privacy (OCSP provider doesn't know client)
✅ No tracking
✅ Server caches response (reduces OCSP load)
✅ Works even if OCSP responder temporarily down

Trade-off:
⚠️ Server must implement stapling
⚠️ Requires server configuration
✅ Worth it for benefits
```

## 6. Operational Security

### 6.1. Key Rotation Policy

#### Decision

```
Key Rotation Policy:

Root CA Key:       20 years (no rotation)
Intermediate CA:   10 years (rotate every 10 years)
OCSP Signing Key:  1 year (rotate annually)
TLS Server Key:    1 year (rotate with certificate)
```

#### Rationale

**Root CA: No Rotation (20 years)**

```
Why no rotation?

Root CA key rotation is catastrophic:
- All trust anchors must be updated
- Browser updates
- Operating system updates
- All certificates become invalid
- Months of migration

When to rotate Root CA:
✅ At planned end-of-life (20 years)
✅ If key compromised (emergency)
❌ NOT routinely

Instead:
- Protect Root CA key extremely well
- Keep offline
- Use HSM
- M-of-N control
- Physical security
```

**Intermediate CA: 10 Years**

```
Why 10 years?

Balance:
- Long enough: Operational stability
- Short enough: Periodic refresh

Rotation process:
1. Generate new Intermediate CA key
2. Root CA signs new Intermediate certificate
3. Dual-issuance period (3 months):
   - Old Intermediate still issues certificates
   - New Intermediate starts issuing
   - Both valid
4. After 3 months:
   - Stop using old Intermediate
   - All new certificates from new Intermediate
5. Wait until all old certificates expire
6. Revoke old Intermediate certificate

Time to full migration: ~3 years (Intermediate + max cert lifetime)
```

**OCSP Signing Key: 1 Year**

```
Why annual rotation?

OCSP key compromise scenarios:
- Attacker can create fake "good" responses
- Make revoked certificates appear valid
- Serious but not catastrophic

Mitigation:
- Rotate OCSP key annually
- Limits exposure window
- Low operational cost (automatic)
- Good security hygiene

Process:
1. Generate new OCSP key (January 1)
2. Intermediate CA signs new OCSP certificate
3. Update OCSP responder with new key
4. Restart OCSP responder
5. Old OCSP certificate expires automatically
```

### 6.2. M-of-N Key Ceremony

#### Decision

```
CA Key Access Control: 3-of-5 Multi-Person Control

- 5 key custodians
- 3 required to access CA private key
- Each custodian has smartcard + PIN
- Key ceremony for CA operations
```

#### Rationale

**✅ Why M-of-N (not single person)?**

```
Single Person Control:

Risks:
❌ Insider threat (malicious administrator)
❌ Coercion (forced to sign bad certificate)
❌ Single point of failure (person unavailable)
❌ No accountability

Multi-Person Control (3-of-5):

Benefits:
✅ No single person can access CA key alone
✅ Prevents insider threats
✅ Prevents coercion (need 3 people)
✅ Redundancy (need 3 of 5, not all 5)
✅ Accountability (witnessed operations)
```

**✅ Why 3-of-5 (not 2-of-3 or 4-of-7)?**

```
Options:

2-of-3:
Pros: ✅ Simple, fewer people
Cons: ❌ Only 1 person redundancy

3-of-5:
Pros: ✅ Good balance
      ✅ 2 people redundancy
      ✅ Still need majority (3/5 = 60%)
Cons: ⚠️ Moderate complexity

4-of-7:
Pros: ✅ High redundancy
Cons: ❌ Complex, many people needed
      ❌ Harder to coordinate

5-of-9:
Pros: ✅ Very high redundancy
Cons: ❌ Too complex
      ❌ Difficult to gather 5 people

CHOSEN: 3-of-5
- Enough security (need 3 people)
- Enough redundancy (can lose 2 people)
- Practical to coordinate
```

**Key Ceremony Process:**

```
CA Key Generation Ceremony:

Pre-ceremony:
1. Schedule ceremony (minimum 2 weeks notice)
2. Verify all 5 custodians available
3. Prepare clean room (air-gapped)
4. Test equipment
5. Prepare documentation

During ceremony:
1. All 5 custodians present
2. Witnesses present (auditor, lawyer)
3. Video recording (for audit)
4. Custodians verify equipment
5. Insert 3 smartcards (minimum)
6. Enter PINs
7. Generate CA key in HSM
8. Verify key generation
9. Backup key to separate HSM
10. Remove smartcards
11. Sign ceremony document
12. Store HSM in safe

Post-ceremony:
1. Ceremony report
2. Video archive
3. Document audit trail
4. Distribute custodian smartcards (separate locations)
```

---

**Key Takeaways:**

✅ Every design decision has **rationale**
✅ We consider **alternatives** before choosing
✅ **Trade-offs** are explicitly documented
✅ **Compliance** requirements drive decisions
✅ **Security** prioritized over convenience
✅ **Defense in depth** strategy throughout

**Next:** [Threat Model and Risk Analysis](09-threat-model.md)
