# Quản lý Chứng chỉ

## Mục lục

- [1. Cấp phát Certificate](#1-cấp-phát-certificate)
- [2. Xác thực Certificate](#2-xác-thực-certificate)
- [3. Gia hạn Certificate](#3-gia-hạn-certificate)
- [4. Thu hồi Certificate](#4-thu-hồi-certificate)
- [5. CRL Management](#5-crl-management)
- [6. OCSP Setup](#6-ocsp-setup)

## 1. Cấp phát Certificate

### Tổng quan quy trình cấp certificate

Quy trình cấp phát certificate gồm 5 bước chính:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Generate Private Key                                        │
│    └─> Tạo cặp key (public/private) cho entity                │
├─────────────────────────────────────────────────────────────────┤
│ 2. Create Certificate Signing Request (CSR)                   │
│    └─> Entity tạo CSR chứa public key + thông tin định danh   │
├─────────────────────────────────────────────────────────────────┤
│ 3. Submit CSR to CA                                            │
│    └─> Gửi CSR đến CA để xin cấp certificate                  │
├─────────────────────────────────────────────────────────────────┤
│ 4. CA Signs Certificate                                        │
│    └─> CA verify CSR và ký bằng private key của CA            │
├─────────────────────────────────────────────────────────────────┤
│ 5. Deploy Certificate                                          │
│    └─> Cài đặt certificate + private key lên server           │
└─────────────────────────────────────────────────────────────────┘
```

### 1.1. Server Certificate (HTTPS/TLS)

#### Sử dụng script tự động

```bash
cd /root/ca/scripts
./issue-certificate.sh server www.example.com example.com mail.example.com
```

#### Manual process - Giải thích từng bước

```bash
cd /root/ca

# ═══════════════════════════════════════════════════════════════
# BƯỚC 1: Generate Private Key
# ═══════════════════════════════════════════════════════════════
# Mục đích: Tạo cặp key RSA 2048-bit (private + public key)
# - Private key: Được giữ bí mật trên server, dùng để decrypt data
# - Public key: Được nhúng trong certificate, dùng để encrypt data
# Tại sao RSA 2048-bit?
# - Đủ mạnh cho TLS (CA/Browser Forum yêu cầu tối thiểu 2048-bit)
# - Nhanh hơn RSA 4096-bit mà vẫn đảm bảo security
# ═══════════════════════════════════════════════════════════════

openssl genrsa -out intermediate/private/www.example.com.key.pem 2048
chmod 400 intermediate/private/www.example.com.key.pem

# chmod 400: Chỉ owner đọc được, không ai khác (bảo mật private key)

# ═══════════════════════════════════════════════════════════════
# BƯỚC 2: Create Certificate Signing Request (CSR)
# ═══════════════════════════════════════════════════════════════
# Mục đích: Tạo yêu cầu cấp certificate chứa:
# - Public key (được extract từ private key)
# - Thông tin định danh (Subject: CN, O, C, ST, L)
# - Subject Alternative Names (SAN) - QUAN TRỌNG cho HTTPS!
#
# Tại sao cần SAN?
# - Browsers hiện đại KHÔNG chấp nhận cert chỉ có CN
# - SAN cho phép 1 cert bảo vệ nhiều domains
# - RFC 6125 yêu cầu phải có SAN cho server certificates
#
# Tại sao dùng SHA-256?
# - SHA-1 đã deprecated (bị collision attacks)
# - SHA-256 là standard hiện tại, an toàn
# ═══════════════════════════════════════════════════════════════

cat > /tmp/san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
countryName = Country Name
stateOrProvinceName = State or Province Name
localityName = Locality Name
organizationName = Organization Name
commonName = Common Name

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = www.example.com
DNS.2 = example.com
DNS.3 = mail.example.com
EOF

openssl req -config /tmp/san.cnf \
    -key intermediate/private/www.example.com.key.pem \
    -new -sha256 -out intermediate/csr/www.example.com.csr.pem \
    -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Example Org/CN=www.example.com"

# CSR chứa:
# - Public key (từ private key)
# - Subject: /C=VN/ST=Hanoi/L=Hanoi/O=Example Org/CN=www.example.com
# - SAN: www.example.com, example.com, mail.example.com
# - Signature: CSR được ký bởi private key để prove ownership

# ═══════════════════════════════════════════════════════════════
# BƯỚC 3: CA Signs Certificate
# ═══════════════════════════════════════════════════════════════
# Mục đích: CA verify CSR và tạo certificate
# - CA kiểm tra CSR signature (verify ownership của private key)
# - CA thêm extensions (basicConstraints, keyUsage, extendedKeyUsage)
# - CA ký certificate bằng Intermediate CA private key
#
# Tại sao 398 days?
# - CA/Browser Forum Baseline Requirements quy định:
#   + Trước 1/3/2018: max 39 tháng (1185 days)
#   + Từ 1/3/2018: max 825 days
#   + Từ 1/9/2020: max 398 days (13 tháng)
# - Mục đích: Force renewal thường xuyên, giảm thiệt hại nếu key bị lộ
# ═══════════════════════════════════════════════════════════════

cat intermediate/openssl.cnf > /tmp/sign.cnf
cat >> /tmp/sign.cnf << EOF

[server_cert_san]
basicConstraints = CA:FALSE                    # Đây KHÔNG phải CA cert
nsCertType = server                            # Netscape cert type (legacy)
subjectKeyIdentifier = hash                    # ID của certificate
authorityKeyIdentifier = keyid,issuer:always   # Link đến issuer (CA)
keyUsage = critical, digitalSignature, keyEncipherment
# ^ keyUsage:
#   - digitalSignature: Ký digital signatures (TLS handshake)
#   - keyEncipherment: Encrypt keys (RSA key exchange)
#   - critical: Extension này BẮT BUỘC phải hiểu
extendedKeyUsage = serverAuth                  # Dùng cho TLS server auth
subjectAltName = @alt_names                    # SAN extensions

[alt_names]
DNS.1 = www.example.com
DNS.2 = example.com
DNS.3 = mail.example.com
EOF

openssl ca -config /tmp/sign.cnf \
    -extensions server_cert_san \
    -days 398 -notext -md sha256 \
    -in intermediate/csr/www.example.com.csr.pem \
    -out intermediate/certs/www.example.com.cert.pem

# openssl ca làm gì?
# 1. Đọc CSR và verify signature
# 2. Thêm serial number (từ intermediate/serial)
# 3. Thêm extensions từ [server_cert_san]
# 4. Ký certificate bằng Intermediate CA private key
# 5. Lưu vào intermediate/newcerts/<serial>.pem
# 6. Update intermediate/index.txt (certificate database)
# 7. Increment intermediate/serial

chmod 444 intermediate/certs/www.example.com.cert.pem
# chmod 444: Read-only cho mọi user (cert là public data)

# ═══════════════════════════════════════════════════════════════
# BƯỚC 4: Verify Certificate Chain
# ═══════════════════════════════════════════════════════════════
# Mục đích: Kiểm tra certificate có hợp lệ không
# - Verify signature: Certificate được ký bởi Intermediate CA đúng không?
# - Verify chain: Intermediate CA có được ký bởi Root CA không?
# - Check expiry: Certificate còn hạn không?
# ═══════════════════════════════════════════════════════════════

openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
    intermediate/certs/www.example.com.cert.pem

# Output: www.example.com.cert.pem: OK
# ca-chain.cert.pem chứa: Intermediate CA cert + Root CA cert

# ═══════════════════════════════════════════════════════════════
# BƯỚC 5: Create Bundle for Deployment
# ═══════════════════════════════════════════════════════════════
# Mục đích: Tạo bundle file cho web server
# Bundle = Server cert + Intermediate CA cert
#
# Tại sao cần bundle?
# - Client (browser) cần verify certificate chain
# - Client có Root CA cert (sau khi user import)
# - Server phải gửi: Server cert + Intermediate CA cert
# - Client sẽ verify: Server cert <- Intermediate CA <- Root CA
#
# Tại sao KHÔNG bao gồm Root CA?
# - Root CA đã có sẵn trong browser trust store
# - Gửi Root CA là lãng phí bandwidth
# ═══════════════════════════════════════════════════════════════

cat intermediate/certs/www.example.com.cert.pem \
    intermediate/certs/intermediate.cert.pem > \
    intermediate/certs/www.example.com.bundle.pem

# Bundle structure:
# ┌─────────────────────────────────────────┐
# │ www.example.com.cert.pem (End-entity)  │
# ├─────────────────────────────────────────┤
# │ intermediate.cert.pem (Intermediate CA)│
# └─────────────────────────────────────────┘
#
# Client verification:
# www.example.com.cert ← Intermediate CA ← Root CA (in browser)
#        (from bundle)      (from bundle)    (pre-installed)
```

**Certificate đã sẵn sàng deploy!**
- Private key: `intermediate/private/www.example.com.key.pem` (BẢO MẬT!)
- Certificate: `intermediate/certs/www.example.com.cert.pem`
- Bundle: `intermediate/certs/www.example.com.bundle.pem` (cho web server)

### 1.2. Client Certificate (mTLS)

```bash
# Using script
./issue-certificate.sh client user@example.com

# Manual
openssl genrsa -out intermediate/private/user.key.pem 2048

openssl req -config intermediate/openssl.cnf \
    -key intermediate/private/user.key.pem \
    -new -sha256 -out intermediate/csr/user.csr.pem \
    -subj "/C=VN/ST=Hanoi/O=Example Org/CN=user@example.com/emailAddress=user@example.com"

openssl ca -config intermediate/openssl.cnf \
    -extensions client_cert \
    -days 365 -notext -md sha256 \
    -in intermediate/csr/user.csr.pem \
    -out intermediate/certs/user.cert.pem

# Create PKCS#12 bundle for distribution
openssl pkcs12 -export \
    -out intermediate/certs/user.p12 \
    -inkey intermediate/private/user.key.pem \
    -in intermediate/certs/user.cert.pem \
    -certfile intermediate/certs/ca-chain.cert.pem \
    -name "User Certificate"

# User imports user.p12 into browser/application
```

### 1.3. Email Certificate (S/MIME)

```bash
# Generate for email signing and encryption
openssl genrsa -out intermediate/private/john.doe.key.pem 2048

openssl req -config intermediate/openssl.cnf \
    -key intermediate/private/john.doe.key.pem \
    -new -sha256 -out intermediate/csr/john.doe.csr.pem \
    -subj "/C=VN/ST=Hanoi/O=Example Org/CN=John Doe/emailAddress=john.doe@example.com"

openssl ca -config intermediate/openssl.cnf \
    -extensions client_cert \
    -days 365 -notext -md sha256 \
    -in intermediate/csr/john.doe.csr.pem \
    -out intermediate/certs/john.doe.cert.pem

# Create PKCS#12 for email client
openssl pkcs12 -export \
    -out intermediate/certs/john.doe.p12 \
    -inkey intermediate/private/john.doe.key.pem \
    -in intermediate/certs/john.doe.cert.pem \
    -certfile intermediate/certs/ca-chain.cert.pem \
    -name "John Doe (john.doe@example.com)"
```

### 1.4. Code Signing Certificate

```bash
# Create extension profile in openssl.cnf
cat >> intermediate/openssl.cnf << 'EOF'

[ code_signing_cert ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
EOF

# Generate certificate
openssl genrsa -out intermediate/private/codesign.key.pem 2048

openssl req -config intermediate/openssl.cnf \
    -key intermediate/private/codesign.key.pem \
    -new -sha256 -out intermediate/csr/codesign.csr.pem \
    -subj "/C=VN/ST=Hanoi/O=Example Org/CN=Code Signing Certificate"

openssl ca -config intermediate/openssl.cnf \
    -extensions code_signing_cert \
    -days 1095 -notext -md sha256 \
    -in intermediate/csr/codesign.csr.pem \
    -out intermediate/certs/codesign.cert.pem
```

## 2. Xác thực Certificate

### 2.1. Verify Certificate Chain

```bash
# Verify single certificate
openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
    intermediate/certs/www.example.com.cert.pem

# Output: www.example.com.cert.pem: OK

# Verify with CRL checking
openssl verify \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -CRLfile intermediate/crl/intermediate.crl.pem \
    -crl_check \
    intermediate/certs/www.example.com.cert.pem
```

### 2.2. Inspect Certificate Details

```bash
# View all certificate information
openssl x509 -in intermediate/certs/www.example.com.cert.pem -noout -text

# Specific fields
openssl x509 -in cert.pem -noout -subject
openssl x509 -in cert.pem -noout -issuer
openssl x509 -in cert.pem -noout -dates
openssl x509 -in cert.pem -noout -serial
openssl x509 -in cert.pem -noout -fingerprint -sha256

# Check SAN
openssl x509 -in cert.pem -noout -text | grep -A 1 "Subject Alternative Name"

# Check expiration
openssl x509 -in cert.pem -noout -enddate

# Check if certificate is expired
openssl x509 -in cert.pem -noout -checkend 0
# Returns 0 if not expired, 1 if expired

# Check if will expire in 30 days
openssl x509 -in cert.pem -noout -checkend $((30*86400))
```

### 2.3. Test SSL/TLS Connection

```bash
# Test HTTPS server
openssl s_client -connect www.example.com:443 -showcerts

# With SNI (Server Name Indication)
openssl s_client -connect example.com:443 -servername www.example.com

# Check specific TLS version
openssl s_client -connect example.com:443 -tls1_2
openssl s_client -connect example.com:443 -tls1_3

# Verify certificate chain
openssl s_client -connect example.com:443 -CAfile ca-chain.cert.pem

# Check certificate expiration on remote server
echo | openssl s_client -connect example.com:443 2>/dev/null | \
    openssl x509 -noout -dates
```

### 2.4. Verify CSR

```bash
# View CSR details
openssl req -text -noout -in server.csr.pem

# Verify CSR signature
openssl req -in server.csr.pem -noout -verify

# Check if CSR matches private key
openssl req -in server.csr.pem -noout -modulus | openssl md5
openssl rsa -in server.key.pem -noout -modulus | openssl md5
# MD5 hashes should match
```

## 3. Gia hạn Certificate

### 3.1. Renew với cùng key

```bash
# Reuse existing private key
cd /root/ca

# Create new CSR with same key
openssl req -config intermediate/openssl.cnf \
    -key intermediate/private/www.example.com.key.pem \
    -new -sha256 -out intermediate/csr/www.example.com-renew.csr.pem \
    -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Example Org/CN=www.example.com"

# Sign new certificate
openssl ca -config intermediate/openssl.cnf \
    -extensions server_cert \
    -days 398 -notext -md sha256 \
    -in intermediate/csr/www.example.com-renew.csr.pem \
    -out intermediate/certs/www.example.com-renewed.cert.pem
```

### 3.2. Renew với new key (recommended)

```bash
# Generate new key
openssl genrsa -out intermediate/private/www.example.com-new.key.pem 2048

# Create CSR
openssl req -config intermediate/openssl.cnf \
    -key intermediate/private/www.example.com-new.key.pem \
    -new -sha256 -out intermediate/csr/www.example.com-new.csr.pem \
    -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Example Org/CN=www.example.com"

# Sign
openssl ca -config intermediate/openssl.cnf \
    -extensions server_cert \
    -days 398 -notext -md sha256 \
    -in intermediate/csr/www.example.com-new.csr.pem \
    -out intermediate/certs/www.example.com-new.cert.pem

# After deployment, revoke old certificate
./revoke-certificate.sh intermediate/certs/www.example.com.cert.pem superseded
```

### 3.3. Automated Renewal Script

```bash
#!/bin/bash
# renew-certificates.sh - Tự động renew certificates sắp hết hạn

CA_DIR="/root/ca/intermediate"
DAYS_BEFORE_EXPIRE=30

# Find certificates expiring soon
find "$CA_DIR/certs" -name "*.cert.pem" | while read cert; do
    if openssl x509 -in "$cert" -noout -checkend $((DAYS_BEFORE_EXPIRE*86400)); then
        echo "Certificate OK: $cert"
    else
        echo "Certificate expiring soon: $cert"

        # Get CN
        CN=$(openssl x509 -in "$cert" -noout -subject | grep -o 'CN=[^,]*' | cut -d= -f2)

        echo "Renewing certificate for: $CN"
        # Add renewal logic here
    fi
done
```

## 4. Thu hồi Certificate

### Tổng quan quy trình thu hồi certificate

Thu hồi certificate là quá trình vô hiệu hóa certificate trước khi hết hạn.

```
┌──────────────────────────────────────────────────────────────────┐
│ Tại sao cần thu hồi certificate?                               │
├──────────────────────────────────────────────────────────────────┤
│ 1. Private key bị lộ (keyCompromise)                           │
│    → Attacker có thể impersonate server                        │
│                                                                  │
│ 2. Certificate bị cấp nhầm (incorrect information)             │
│    → Domain ownership thay đổi                                 │
│                                                                  │
│ 3. Employee rời công ty (affiliationChanged)                   │
│    → Không còn quyền sử dụng certificate                       │
│                                                                  │
│ 4. Certificate bị thay thế (superseded)                        │
│    → Đã cấp certificate mới                                    │
│                                                                  │
│ 5. Server ngừng hoạt động (cessationOfOperation)               │
│    → Không cần certificate nữa                                 │
└──────────────────────────────────────────────────────────────────┘
```

**Quy trình thu hồi:**

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Revoke Certificate                                          │
│    └─> Đánh dấu certificate là "Revoked" trong database       │
├─────────────────────────────────────────────────────────────────┤
│ 2. Update CRL (Certificate Revocation List)                   │
│    └─> Tạo danh sách certificates bị thu hồi                  │
├─────────────────────────────────────────────────────────────────┤
│ 3. Publish CRL                                                 │
│    └─> Đưa CRL lên web server để clients download             │
├─────────────────────────────────────────────────────────────────┤
│ 4. Update OCSP (Optional)                                      │
│    └─> Cập nhật OCSP responder cho real-time checking         │
└─────────────────────────────────────────────────────────────────┘
```

### 4.1. Sử dụng script

```bash
cd /root/ca/scripts
./revoke-certificate.sh /root/ca/intermediate/certs/compromised.cert.pem keyCompromise
```

### 4.2. Manual revocation - Giải thích từng bước

```bash
# ═══════════════════════════════════════════════════════════════
# BƯỚC 1: Revoke Certificate
# ═══════════════════════════════════════════════════════════════
# Mục đích: Đánh dấu certificate không còn hợp lệ
# - CA cập nhật database (index.txt)
# - Thay đổi status từ "V" (Valid) → "R" (Revoked)
# - Ghi lại thời gian revoke và lý do
# ═══════════════════════════════════════════════════════════════

openssl ca -config intermediate/openssl.cnf \
    -revoke intermediate/certs/compromised.cert.pem \
    -crl_reason keyCompromise

# openssl ca -revoke làm gì?
# 1. Đọc certificate và lấy serial number
# 2. Tìm entry trong intermediate/index.txt
# 3. Update status: V → R
# 4. Thêm revocation date và reason
#
# Trước revoke (index.txt):
# V    250101120000Z        1000  unknown  /C=VN/ST=Hanoi/CN=compromised.com
#
# Sau revoke (index.txt):
# R    250101120000Z 241215093000Z,keyCompromise  1000  unknown  /C=VN/ST=Hanoi/CN=compromised.com
# ^    ^             ^              ^              ^     ^        ^
# |    |             |              |              |     |        └─ Subject DN
# |    |             |              |              |     └─ Unknown (deprecated)
# |    |             |              |              └─ Serial number
# |    |             |              └─ Revocation reason
# |    |             └─ Revocation date (YYMMDDHHMMSSZ)
# |    └─ Expiry date
# └─ Status: R = Revoked

# ═══════════════════════════════════════════════════════════════
# BƯỚC 2: Generate CRL (Certificate Revocation List)
# ═══════════════════════════════════════════════════════════════
# Mục đích: Tạo danh sách certificates bị thu hồi
# - CRL chứa serial numbers của revoked certificates
# - CRL được CA ký để chống giả mạo
# - Clients download CRL để kiểm tra certificate status
# ═══════════════════════════════════════════════════════════════

openssl ca -config intermediate/openssl.cnf \
    -gencrl -out intermediate/crl/intermediate.crl.pem

# openssl ca -gencrl làm gì?
# 1. Đọc tất cả revoked entries từ index.txt
# 2. Tạo CRL structure chứa:
#    - Issuer: Intermediate CA
#    - thisUpdate: Thời điểm tạo CRL
#    - nextUpdate: Khi nào phải update CRL (default: 30 days)
#    - Revoked Certificates list:
#      * Serial Number
#      * Revocation Date
#      * CRL Reason Code
# 3. Ký CRL bằng Intermediate CA private key
# 4. Output: intermediate.crl.pem (PEM format)

# CRL structure:
# Certificate Revocation List (CRL):
#     Version 2 (0x1)
#     Signature Algorithm: sha256WithRSAEncryption
#     Issuer: /C=VN/ST=Hanoi/O=Example Org/CN=Intermediate CA
#     Last Update: Dec 15 09:30:00 2024 GMT
#     Next Update: Jan 14 09:30:00 2025 GMT
#     CRL extensions:
#         X509v3 Authority Key Identifier:
#             keyid:...
# Revoked Certificates:
#     Serial Number: 1000
#         Revocation Date: Dec 15 09:30:00 2024 GMT
#         CRL entry extensions:
#             X509v3 CRL Reason Code:
#                 Key Compromise
#     Serial Number: 1001
#         Revocation Date: Dec 14 15:20:00 2024 GMT
#         CRL entry extensions:
#             X509v3 CRL Reason Code:
#                 Superseded

# ═══════════════════════════════════════════════════════════════
# BƯỚC 3: Convert CRL to DER Format (Optional)
# ═══════════════════════════════════════════════════════════════
# Mục đích: Convert sang binary format
# - PEM: Base64-encoded, dùng cho command-line tools
# - DER: Binary, nhỏ hơn, dùng cho browsers/applications
# ═══════════════════════════════════════════════════════════════

openssl crl -in intermediate/crl/intermediate.crl.pem \
    -outform DER -out intermediate/crl/intermediate.crl

# Browsers thường dùng DER format khi download CRL
```

**Verification - Kiểm tra certificate đã bị revoke chưa:**

```bash
# Check certificate với CRL
openssl verify -crl_check \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -CRLfile intermediate/crl/intermediate.crl.pem \
    intermediate/certs/compromised.cert.pem

# Output nếu bị revoke:
# compromised.cert.pem: CN = compromised.com
# error 23 at 0 depth lookup: certificate revoked
#
# Output nếu OK:
# compromised.cert.pem: OK
```

### 4.3. Revocation Reasons

```
unspecified (0)          - Lý do không xác định
keyCompromise (1)        - Private key bị lộ
CACompromise (2)         - CA bị compromise
affiliationChanged (3)   - Thay đổi liên kết (employee rời công ty)
superseded (4)           - Certificate bị thay thế
cessationOfOperation (5) - Ngừng hoạt động
certificateHold (6)      - Tạm ngừng (có thể gỡ bỏ)
removeFromCRL (8)        - Gỡ khỏi CRL
privilegeWithdrawn (9)   - Thu hồi quyền
aACompromise (10)        - AA bị compromise
```

### 4.4. Temporary Hold

```bash
# Place on hold
openssl ca -config intermediate/openssl.cnf \
    -revoke intermediate/certs/user.cert.pem \
    -crl_reason certificateHold

# To remove from hold, edit index.txt
# Change 'R' to 'V' for that certificate entry
# Then regenerate CRL
```

## 5. CRL Management

### 5.1. Generate CRL

```bash
# Root CA CRL
openssl ca -config rootca/openssl.cnf \
    -gencrl -out rootca/crl/ca.crl.pem

# Intermediate CA CRL
openssl ca -config intermediate/openssl.cnf \
    -gencrl -out intermediate/crl/intermediate.crl.pem
```

### 5.2. View CRL

```bash
# View CRL in text format
openssl crl -in intermediate/crl/intermediate.crl.pem -noout -text

# View revoked certificates
openssl crl -in intermediate/crl/intermediate.crl.pem -noout -text | \
    grep -A 2 "Serial Number"

# Check CRL validity period
openssl crl -in intermediate/crl/intermediate.crl.pem -noout -nextupdate
```

### 5.3. Publish CRL

```bash
# Copy to web server
cp intermediate/crl/intermediate.crl /var/www/html/crl/

# Verify access
curl http://crl.example.com/intermediate.crl -o - | \
    openssl crl -inform DER -noout -text
```

### 5.4. Automated CRL Update

```bash
#!/bin/bash
# update-crl.sh - Cập nhật CRL định kỳ

CA_DIR="/root/ca/intermediate"
WEB_DIR="/var/www/html/crl"

# Generate CRL
openssl ca -config "$CA_DIR/openssl.cnf" \
    -gencrl -out "$CA_DIR/crl/intermediate.crl.pem"

# Convert to DER
openssl crl -in "$CA_DIR/crl/intermediate.crl.pem" \
    -outform DER -out "$CA_DIR/crl/intermediate.crl"

# Publish
cp "$CA_DIR/crl/intermediate.crl" "$WEB_DIR/"

echo "CRL updated: $(date)"
```

Add to crontab:
```bash
# Update CRL daily at 2am
0 2 * * * /root/ca/scripts/update-crl.sh
```

## 6. OCSP Setup

### 6.1. Generate OCSP Signing Certificate

```bash
cd /root/ca

# Generate OCSP key
openssl genrsa -out intermediate/private/ocsp.key.pem 2048

# Create OCSP CSR
openssl req -config intermediate/openssl.cnf \
    -new -sha256 \
    -key intermediate/private/ocsp.key.pem \
    -out intermediate/csr/ocsp.csr.pem \
    -subj "/C=VN/ST=Hanoi/O=Example Org/CN=OCSP Responder"

# Sign OCSP certificate
openssl ca -config intermediate/openssl.cnf \
    -extensions ocsp \
    -days 375 -notext -md sha256 \
    -in intermediate/csr/ocsp.csr.pem \
    -out intermediate/certs/ocsp.cert.pem
```

### 6.2. Run OCSP Responder

```bash
# Start OCSP responder
openssl ocsp \
    -port 8888 \
    -text \
    -sha256 \
    -index intermediate/index.txt \
    -CA intermediate/certs/ca-chain.cert.pem \
    -rkey intermediate/private/ocsp.key.pem \
    -rsigner intermediate/certs/ocsp.cert.pem \
    -nrequest 1

# Run in background
nohup openssl ocsp \
    -port 8888 \
    -index intermediate/index.txt \
    -CA intermediate/certs/ca-chain.cert.pem \
    -rkey intermediate/private/ocsp.key.pem \
    -rsigner intermediate/certs/ocsp.cert.pem \
    > /var/log/ocsp.log 2>&1 &
```

### 6.3. Test OCSP

```bash
# Query OCSP responder
openssl ocsp \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -url http://ocsp.example.com:8888 \
    -resp_text \
    -issuer intermediate/certs/intermediate.cert.pem \
    -cert intermediate/certs/www.example.com.cert.pem

# Expected output:
# Response verify OK
# intermediate/certs/www.example.com.cert.pem: good
```

### 6.4. Production OCSP with nginx

```nginx
# /etc/nginx/sites-available/ocsp
server {
    listen 80;
    server_name ocsp.example.com;

    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 7. Certificate Database

### 7.1. View Certificate Database

```bash
# View all certificates
cat /root/ca/intermediate/index.txt

# Format:
# V = Valid
# R = Revoked
# E = Expired

# Example:
# V    250101120000Z        1000  unknown  /C=VN/ST=Hanoi/O=Example/CN=www.example.com
# R    250101120000Z 240515120000Z,keyCompromise  1001  unknown  /C=VN/.../CN=compromised.com
```

### 7.2. Query Certificate by Serial

```bash
SERIAL="1000"

# Find in database
grep "$SERIAL" /root/ca/intermediate/index.txt

# Get certificate file
CERT_FILE="/root/ca/intermediate/newcerts/${SERIAL}.pem"
openssl x509 -in "$CERT_FILE" -noout -text
```

### 7.3. List All Valid Certificates

```bash
# List valid certificates
awk '/^V/ {print $3, $5}' /root/ca/intermediate/index.txt

# List revoked certificates
awk '/^R/ {print $3, $4, $5}' /root/ca/intermediate/index.txt
```

### 7.4. Backup Database

```bash
#!/bin/bash
# backup-ca-db.sh

DATE=$(date +%Y%m%d)
BACKUP_DIR="/root/ca-backups/$DATE"

mkdir -p "$BACKUP_DIR"

# Backup index
cp /root/ca/intermediate/index.txt "$BACKUP_DIR/"
cp /root/ca/intermediate/serial "$BACKUP_DIR/"
cp /root/ca/intermediate/crlnumber "$BACKUP_DIR/"

# Backup certificates
tar czf "$BACKUP_DIR/certs.tar.gz" /root/ca/intermediate/certs/
tar czf "$BACKUP_DIR/private.tar.gz" /root/ca/intermediate/private/

# Encrypt backup
openssl enc -aes-256-cbc \
    -salt -in "$BACKUP_DIR/private.tar.gz" \
    -out "$BACKUP_DIR/private.tar.gz.enc"

rm "$BACKUP_DIR/private.tar.gz"

echo "Backup completed: $BACKUP_DIR"
```

## Tổng kết

Bạn đã học:
- ✅ Cấp phát certificates cho server, client, email, code signing
- ✅ Xác thực và kiểm tra certificates
- ✅ Gia hạn certificates
- ✅ Thu hồi certificates với CRL
- ✅ Setup OCSP responder
- ✅ Quản lý certificate database

**Next**: [Best Practices](04-best-practices.md) - Security best practices
