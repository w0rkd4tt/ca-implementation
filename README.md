# CA Implementation - Certificate Authority Zero to Hero

## Giới thiệu

Dự án này cung cấp hướng dẫn chi tiết về cách thiết kế, triển khai và quản lý một hệ thống Certificate Authority (CA) hoàn chỉnh. Từ việc thiết kế giao thức đến việc triển khai thực tế với OpenSSL.

## Mục tiêu

- 📚 Hiểu rõ kiến trúc và hoạt động của CA
- 🔧 Thiết kế giao thức PKI tùy chỉnh
- 🚀 Triển khai CA sử dụng OpenSSL
- 🔐 Quản lý vòng đời chứng chỉ số
- ✅ Áp dụng best practices trong bảo mật

## Cấu trúc Project

```
ca-implementation/
├── docs/                          # Tài liệu chi tiết
│   ├── 01-protocol-design.md     # Thiết kế giao thức
│   ├── 02-ca-setup.md            # Hướng dẫn cài đặt CA
│   ├── 03-certificate-management.md  # Quản lý chứng chỉ
│   ├── 04-best-practices.md      # Best practices
│   ├── 05-troubleshooting.md     # Xử lý sự cố
│   └── 06-ocsp-guide.md          # Hướng dẫn OCSP
├── scripts/                       # Scripts tự động hóa
│   ├── setup-ca.sh               # Thiết lập CA
│   ├── create-intermediate-ca.sh # Tạo Intermediate CA
│   ├── issue-certificate.sh      # Cấp chứng chỉ
│   ├── revoke-certificate.sh     # Thu hồi chứng chỉ
│   ├── check-cert-expiry.sh      # Kiểm tra hạn chứng chỉ
│   ├── setup-ocsp.sh             # Thiết lập OCSP responder
│   └── check-ocsp.sh             # Kiểm tra OCSP status
├── config/                        # File cấu hình
│   ├── ocsp.cnf                  # Config OCSP responder
├── examples/                      # Ví dụ thực hành
│   ├── web-server/               # HTTPS web server
│   ├── email-signing/            # S/MIME email
│   └── code-signing/             # Code signing
└── tests/                         # Test scripts
    └── verify-setup.sh           # Kiểm tra cài đặt
```

## Yêu cầu hệ thống

- **OS**: Linux/macOS (Ubuntu 20.04+ hoặc macOS 10.15+)
- **OpenSSL**: Version 1.1.1 trở lên
- **Bash**: Version 4.0+
- **Quyền**: Root/sudo để tạo directories

## Quick Start

### 1. Clone repository

```bash
git clone https://github.com/yourusername/ca-implementation.git
cd ca-implementation
```

### 2. Thiết lập Root CA

```bash
cd scripts
chmod +x *.sh
sudo ./setup-ca.sh
```

### 3. Tạo Intermediate CA

```bash
sudo ./create-intermediate-ca.sh
```

### 4. Cấp chứng chỉ cho server

```bash
sudo ./issue-certificate.sh server www.example.com
```

### 5. Kiểm tra hạn chứng chỉ

```bash
# Kiểm tra certificate từ file
sudo ./check-cert-expiry.sh -f /root/ca/intermediate/certs/example.pki.cert.pem

# Kiểm tra certificate của web server
./check-cert-expiry.sh -h example.pki -p 443

# Kiểm tra tất cả certificates trong CA
sudo ./check-cert-expiry.sh -a
```

### 6. Thiết lập OCSP Responder

```bash
# Setup OCSP responder
sudo ./setup-ocsp.sh

# Start OCSP responder
sudo /root/ca/intermediate/ocsp-responder.sh

# Kiểm tra OCSP status
./check-ocsp.sh -f /root/ca/intermediate/certs/example.pki.cert.pem
```

### 7. Thu hồi chứng chỉ

```bash
# Thu hồi certificate
sudo ./revoke-certificate.sh /root/ca/intermediate/certs/example.pki.cert.pem

# Cập nhật CRL
sudo openssl ca -config /root/ca/intermediate/openssl.cnf -gencrl \
    -out /root/ca/intermediate/crl/intermediate.crl.pem

# Kiểm tra OCSP status sau khi revoke
./check-ocsp.sh -f /root/ca/intermediate/certs/example.pki.cert.pem
```

## Nội dung chi tiết

### 1. [Thiết kế Giao thức PKI](docs/01-protocol-design.md)

- Kiến trúc hệ thống CA
- Thiết kế hierarchy: Root CA → Intermediate CA → End-entity
- Định nghĩa chính sách chứng chỉ (Certificate Policy)
- Thiết kế quy trình cấp và thu hồi chứng chỉ

### 2. [Cài đặt và Cấu hình CA](docs/02-ca-setup.md)

- Cài đặt OpenSSL
- Tạo Root CA
- Tạo Intermediate CA
- Cấu hình OpenSSL configuration files
- Bảo mật private keys

### 3. [Quản lý Chứng chỉ](docs/03-certificate-management.md)

- Tạo Certificate Signing Request (CSR)
- Cấp phát chứng chỉ
- Gia hạn chứng chỉ
- Thu hồi chứng chỉ
- Quản lý Certificate Revocation List (CRL)

### 3.5. [OCSP Implementation](docs/06-ocsp-guide.md)

- OCSP protocol và hoạt động
- OCSP vs CRL comparison
- Setup OCSP Responder
- OCSP Stapling configuration
- Production deployment và monitoring

### 4. [Best Practices](docs/04-best-practices.md)

- Bảo mật private key
- Key rotation policy
- Audit logging
- Disaster recovery
- HSM integration

### 5. [Troubleshooting](docs/05-troubleshooting.md)

- Các lỗi thường gặp
- Debug certificate issues
- Verification problems

## Policy và Rationale Documents

### 6. [Certificate Policy & CPS](docs/07-certificate-policy.md)

- Tại sao cần Certificate Policy (CP) và Certificate Practice Statement (CPS)
- Cấu trúc CP theo RFC 3647
- Example Certificate Policy đầy đủ
- Policy OID và implementation guidelines
- Legal và compliance context

### 7. [PKI Design Rationale](docs/08-design-rationale.md)

- **Tại sao** thiết kế như vậy (không chỉ "làm thế nào")
- Architecture decisions: Two-tier hierarchy, Offline Root CA
- Cryptographic choices: RSA 4096 vs ECC, SHA-256 rationale
- Certificate validity periods: 398 days explained
- Revocation strategy: CRL + OCSP + OCSP Stapling
- Operational security: Key rotation, M-of-N key ceremony

### 8. [Threat Model và Risk Analysis](docs/09-threat-model.md)

- STRIDE threat modeling methodology
- Attack tree analysis
- Real-world PKI incidents (DigiNotar, Comodo, Let's Encrypt)
- Attack scenarios và impact assessment
- Risk matrix và mitigation strategies
- Defense in depth layers

### 9. [Compliance và Standards](docs/10-compliance-standards.md)

- Tại sao standards matter
- Key RFCs: RFC 5280 (X.509), RFC 6960 (OCSP), RFC 6066 (OCSP Stapling)
- CA/Browser Forum Baseline Requirements
- WebTrust Principles
- Certificate Transparency (CT)
- Compliance frameworks: PCI DSS, SOC 2, GDPR
- Audit and certification process

## Ví dụ Use Cases

### Use Case 1: HTTPS Web Server

```bash
cd examples/web-server
./setup-https-server.sh
```

### Use Case 2: Email Signing (S/MIME)

```bash
cd examples/email-signing
./create-email-certificate.sh user@example.com
```

### Use Case 3: Code Signing

```bash
cd examples/code-signing
./create-code-signing-cert.sh
```

## Kiểm tra và Xác thực

Verify toàn bộ setup:

```bash
cd tests
./verify-setup.sh
```

## Tính năng chính

- ✅ Root CA và Intermediate CA hierarchy
- ✅ Hỗ trợ nhiều loại chứng chỉ (server, client, email, code signing)
- ✅ CRL và OCSP support
- ✅ Scripts tự động hóa hoàn chỉnh
- ✅ Kiểm tra hạn certificate tự động
- ✅ Thu hồi certificate và quản lý CRL
- ✅ Logging và audit trail
- ✅ Security best practices
- ✅ Tài liệu chi tiết bằng tiếng Việt

## Scripts Utilities

### setup-ocsp.sh

Thiết lập OCSP (Online Certificate Status Protocol) Responder:

```bash
# Setup OCSP responder
sudo ./setup-ocsp.sh

# Start OCSP responder (Method 1: Manual)
sudo /root/ca/intermediate/ocsp-responder.sh

# Start OCSP responder (Method 2: Systemd)
sudo systemctl daemon-reload
sudo systemctl start ocsp-responder
sudo systemctl enable ocsp-responder

# Stop OCSP responder
sudo /root/ca/intermediate/ocsp-stop.sh
# OR: sudo systemctl stop ocsp-responder

# View logs
tail -f /var/log/ocsp-responder.log
# OR: sudo journalctl -u ocsp-responder -f
```

Script tự động:
- ✅ Tạo OCSP signing key và certificate
- ✅ Tạo startup/stop scripts
- ✅ Tạo systemd service file
- ✅ Configure OCSP responder

### check-ocsp.sh

Kiểm tra trạng thái certificate qua OCSP:

```bash
# Check local certificate file
./check-ocsp.sh -f /path/to/cert.pem

# Check remote HTTPS server
./check-ocsp.sh -h example.com -p 443

# Use custom OCSP URL
./check-ocsp.sh -f cert.pem -u http://ocsp.example.com:8888

# Verbose output
./check-ocsp.sh -f cert.pem -v
```

**Exit codes:**
- 0 = Certificate is GOOD
- 1 = Certificate is REVOKED or ERROR
- 2 = OCSP responder not available

### check-cert-expiry.sh

Kiểm tra thời hạn certificate với các tùy chọn:

```bash
# Kiểm tra file certificate
./check-cert-expiry.sh -f /path/to/cert.pem

# Kiểm tra remote web server
./check-cert-expiry.sh -h example.com -p 443

# Kiểm tra tất cả certificates trong CA
./check-cert-expiry.sh -a

# Tùy chỉnh ngưỡng cảnh báo
./check-cert-expiry.sh -h example.com -w 60 -c 14
# -w: warning threshold (days)
# -c: critical threshold (days)
```

**Exit codes:**
- 0 = OK (certificate còn hạn)
- 1 = Error/Expired
- 2 = Critical (sắp hết hạn)
- 3 = Warning

### revoke-certificate.sh

Thu hồi certificate và cập nhật CRL:

```bash
# Thu hồi certificate
sudo ./revoke-certificate.sh /root/ca/intermediate/certs/example.pki.cert.pem

# Kiểm tra CRL
openssl crl -in /root/ca/intermediate/crl/intermediate.crl.pem -noout -text

# Verify certificate có bị revoke không
openssl verify -crl_check \
    -CAfile /root/ca/intermediate/certs/ca-chain.cert.pem \
    -CRLfile /root/ca/intermediate/crl/intermediate.crl.pem \
    /root/ca/intermediate/certs/example.pki.cert.pem
```

## Bảo mật

⚠️ **QUAN TRỌNG**:

- Private key của Root CA phải được bảo vệ tuyệt đối
- Sử dụng strong passphrase
- Backup private keys an toàn
- Root CA nên offline sau khi setup
- Implement proper access control

## Tài liệu tham khảo

### RFCs (Request for Comments)

**Core PKI Standards:**
- [RFC 5280 - X.509 PKI Certificate and CRL Profile](https://tools.ietf.org/html/rfc5280) - Bible của PKI, định nghĩa certificate format
- [RFC 6960 - OCSP (Online Certificate Status Protocol)](https://tools.ietf.org/html/rfc6960) - Real-time revocation checking
- [RFC 6066 - TLS Extensions](https://tools.ietf.org/html/rfc6066) - Bao gồm OCSP Stapling
- [RFC 3647 - Certificate Policy and CPS Framework](https://tools.ietf.org/html/rfc3647) - Template cho CP/CPS
- [RFC 5280 - PKIX Certificate and CRL Profile](https://datatracker.ietf.org/doc/html/rfc5280) - X.509 v3 certificates

**Cryptography Standards:**
- [RFC 3279 - Algorithms and Identifiers for PKIX](https://tools.ietf.org/html/rfc3279) - RSA, DSA, ECDSA
- [RFC 4055 - Additional Algorithms for PKIX](https://tools.ietf.org/html/rfc4055) - SHA-256, SHA-384, SHA-512
- [RFC 5758 - Additional Algorithms and Identifiers](https://tools.ietf.org/html/rfc5758) - SHA-2 family

**Certificate Extensions:**
- [RFC 5280 Section 4.2 - Certificate Extensions](https://datatracker.ietf.org/doc/html/rfc5280#section-4.2) - basicConstraints, keyUsage, etc.
- [RFC 6962 - Certificate Transparency](https://tools.ietf.org/html/rfc6962) - Public logging of certificates

### NIST Standards

**Key Management:**
- [NIST SP 800-57 Part 1 - Recommendation for Key Management](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final) - Key lifecycle management
- [NIST SP 800-57 Part 2 - Best Practices for Key Management](https://csrc.nist.gov/publications/detail/sp/800-57-part-2/rev-1/final)

**Cryptographic Standards:**
- [FIPS 140-2 - Security Requirements for Cryptographic Modules](https://csrc.nist.gov/publications/detail/fips/140/2/final)
- [FIPS 140-3 - Security Requirements for Cryptographic Modules (Updated)](https://csrc.nist.gov/publications/detail/fips/140/3/final)
- [NIST SP 800-131A - Transitioning to Cryptographic Algorithms](https://csrc.nist.gov/publications/detail/sp/800-131a/rev-2/final) - Algorithm recommendations

**PKI Guidelines:**
- [NIST SP 800-32 - Introduction to Public Key Technology and PKI](https://csrc.nist.gov/publications/detail/sp/800-32/final)

### Industry Standards and Requirements

**CA/Browser Forum:**
- [Baseline Requirements for SSL/TLS Certificates](https://cabforum.org/baseline-requirements-documents/) - Mandatory for public CAs
- [Network Security Requirements](https://cabforum.org/network-security-requirements/) - Infrastructure security
- [EV SSL Certificate Guidelines](https://cabforum.org/extended-validation/) - Extended Validation requirements

**WebTrust:**
- [WebTrust Principles and Criteria for CAs](https://www.cpacanada.ca/en/business-and-accounting-resources/audit-and-assurance/overview-of-webtrust-services) - Audit framework
- [WebTrust for Certification Authorities - SSL Baseline with Network Security](https://www.cpacanada.ca/-/media/site/operational/ms-member-services/docs/webtrust/07280-ms-webtrust-for-certification-authorities-ssl-baseline-with-network-security-v2-7.pdf)

**ETSI (European Standards):**
- [ETSI EN 319 411-1 - Policy Requirements for CAs (Part 1: General)](https://www.etsi.org/deliver/etsi_en/319400_319499/31941101/01.02.02_60/en_31941101v010202p.pdf)
- [ETSI EN 319 411-2 - Policy Requirements for CAs (Part 2: NCP+)](https://www.etsi.org/deliver/etsi_en/319400_319499/31941102/02.02.02_60/en_31941102v020202p.pdf)

### Compliance Frameworks

**Payment Card Industry:**
- [PCI DSS v4.0 - Payment Card Industry Data Security Standard](https://www.pcisecuritystandards.org/document_library/) - Requirements 3, 4, 8, 10

**Service Organization Controls:**
- [SOC 2 - Trust Service Criteria](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/aicpasoc2report.html) - Security, availability, confidentiality

**International Standards:**
- [ISO/IEC 27001 - Information Security Management](https://www.iso.org/isoiec-27001-information-security.html)
- [ISO/IEC 27002 - Code of Practice for Information Security Controls](https://www.iso.org/standard/75652.html)

**Regional Regulations:**
- [eIDAS Regulation (EU)](https://digital-strategy.ec.europa.eu/en/policies/eidas-regulation) - Electronic identification and trust services
- [GDPR - General Data Protection Regulation](https://gdpr.eu/) - Privacy considerations for PKI

### Books and Publications

**Comprehensive PKI Resources:**
- **"PKI: Implementing and Managing E-Security"** by Andrew Nash, William Duane, Celia Joseph, Derek Brink
- **"Understanding PKI: Concepts, Standards, and Deployment Considerations"** by Carlisle Adams, Steve Lloyd
- **"Network Security with OpenSSL"** by John Viega, Matt Messier, Pravir Chandra
- **"Bulletproof SSL and TLS"** by Ivan Ristić - Comprehensive TLS/SSL guide

**Security and Cryptography:**
- **"Applied Cryptography"** by Bruce Schneier - Cryptographic fundamentals
- **"Cryptography Engineering"** by Niels Ferguson, Bruce Schneier, Tadayoshi Kohno
- **"Security Engineering"** by Ross Anderson - Chapter 21 on PKI

### Online Resources

**OpenSSL Documentation:**
- [OpenSSL Official Documentation](https://www.openssl.org/docs/) - Command reference
- [OpenSSL Cookbook](https://www.feistyduck.com/library/openssl-cookbook/) by Ivan Ristić - Free PDF
- [OpenSSL Command-Line HOWTO](https://www.madboa.com/geek/openssl/) - Practical examples

**Certificate Transparency:**
- [crt.sh - Certificate Search](https://crt.sh/) - Search CT logs
- [Certificate Transparency Log List](https://www.certificate-transparency.org/known-logs) - All CT logs
- [Google Certificate Transparency](https://github.com/google/certificate-transparency) - Google's CT project

**Security Research:**
- [CVE Details - SSL/TLS Vulnerabilities](https://www.cvedetails.com/) - Known vulnerabilities
- [SSL Labs - SSL/TLS Best Practices](https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/) - Modern TLS configs

**PKI Tools and Libraries:**
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/) - Automated CA
- [Cloudflare CFSSL](https://github.com/cloudflare/cfssl) - PKI toolkit
- [Boulder (Let's Encrypt CA Software)](https://github.com/letsencrypt/boulder) - Production CA implementation
- [PyCA/cryptography](https://cryptography.io/) - Python crypto library
- [Bouncy Castle](https://www.bouncycastle.org/) - Java/C# crypto library

### Real-World Incidents and Case Studies

**Famous PKI Breaches:**
- [DigiNotar CA Compromise (2011)](https://en.wikipedia.org/wiki/DigiNotar) - Lessons in CA security
- [Comodo CA Incident (2011)](https://blog.comodo.com/other/the-recent-ra-compromise/) - RA compromise
- [Symantec Mis-issuance](https://security.googleblog.com/2017/09/chromes-plan-to-distrust-symantec.html) - Google distrusts Symantec
- [Let's Encrypt CAA Bug](https://community.letsencrypt.org/t/revoking-certain-certificates-on-march-4/114864) - 3M certs revoked

**Analysis Articles:**
- [How Certificate Transparency Works](https://certificate.transparency.dev/howctworks/) - Visual explanation
- [The Sorry State of SSL](https://www.eff.org/deeplinks/2011/10/how-secure-https-today) - EFF analysis
- [HTTPS adoption statistics](https://transparencyreport.google.com/https/overview) - Google transparency report

### Blogs and Forums

**Security Blogs:**
- [Troy Hunt's Blog](https://www.troyhunt.com/) - HTTPS and certificate security
- [Scott Helme's Blog](https://scotthelme.co.uk/) - Security headers, HTTPS
- [The Cloudflare Blog](https://blog.cloudflare.com/) - PKI and crypto topics
- [Mozilla Security Blog](https://blog.mozilla.org/security/) - Certificate policy updates

**Communities:**
- [Let's Encrypt Community](https://community.letsencrypt.org/) - ACME and automation
- [Stack Exchange - Security](https://security.stackexchange.com/questions/tagged/pki) - PKI Q&A
- [/r/PKI Subreddit](https://www.reddit.com/r/PKI/) - PKI discussions

### Video Resources

**Conference Talks:**
- [DEF CON PKI Talks](https://www.youtube.com/results?search_query=defcon+pki) - Security conference talks
- [Black Hat PKI Presentations](https://www.youtube.com/results?search_query=black+hat+pki)
- [RSA Conference - PKI Sessions](https://www.youtube.com/c/RSAConference)

**Educational Videos:**
- [Computerphile - Public Key Cryptography](https://www.youtube.com/watch?v=GSIDS_lvRv4)
- [How SSL/TLS Works](https://www.youtube.com/results?search_query=how+ssl+tls+works)

### Tools for Testing and Validation

**SSL/TLS Testing:**
- [SSL Labs SSL Test](https://www.ssllabs.com/ssltest/) - Grade your HTTPS configuration
- [testssl.sh](https://github.com/drwetter/testssl.sh) - Command-line SSL/TLS tester
- [sslscan](https://github.com/rbsec/sslscan) - Fast SSL/TLS scanner

**Certificate Analysis:**
- [Certificate Decoder](https://www.sslshopper.com/certificate-decoder.html) - View certificate details
- [CSR Decoder](https://www.sslshopper.com/csr-decoder.html) - Decode CSR files
- [SSL Checker](https://www.sslshopper.com/ssl-checker.html) - Check SSL installation

### Vietnamese Resources

**Tiếng Việt:**
- [Tìm hiểu về PKI và Certificate Authority](https://viblo.asia/tags/pki) - Viblo articles
- [Hướng dẫn triển khai HTTPS](https://kipalog.com/tags/https) - Kipalog guides
- [Bảo mật ứng dụng web với SSL/TLS](https://techtalk.vn/tag/ssl-tls) - TechTalk articles

---

> **Note:** Tài liệu tham khảo được cập nhật thường xuyên. Kiểm tra phiên bản mới nhất của standards và RFCs.

## Tác giả

🧑‍💻 **W0rkkd4tt** – Offensive Security Engineer

📧 Email: datnguyenlequoc@2001.com

🔗 GitHub: [github.com/w0rkd4tt](https://github.com/w0rkd4tt)
🛡️ Pentester | Recon Automation | Burp Suite Certified Practitioner | OSWE

> [!WARNING]
> Đây là project học tập. Không sử dụng cho production environment mà không có security audit đầy đủ.
