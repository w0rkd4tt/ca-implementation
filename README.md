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

- [RFC 5280 - Internet X.509 PKI Certificate and CRL Profile](https://tools.ietf.org/html/rfc5280)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [CA/Browser Forum Baseline Requirements](https://cabforum.org/baseline-requirements-documents/)

## Tác giả

🧑‍💻 **W0rkkd4tt** – Offensive Security Engineer

📧 Email: datnguyenlequoc@2001.com

🔗 GitHub: [github.com/w0rkd4tt](https://github.com/w0rkd4tt)
🛡️ Pentester | Recon Automation | Burp Suite Certified Practitioner | OSWE

> [!WARNING]
> Đây là project học tập. Không sử dụng cho production environment mà không có security audit đầy đủ.
