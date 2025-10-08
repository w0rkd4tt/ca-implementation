# Thiết kế Giao thức PKI

## Mục lục

- [1. Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
- [2. Thiết kế Hierarchy](#2-thiết-kế-hierarchy)
- [3. Certificate Policy](#3-certificate-policy)
- [4. Quy trình cấp chứng chỉ](#4-quy-trình-cấp-chứng-chỉ)
- [5. Quy trình thu hồi](#5-quy-trình-thu-hồi)

## 1. Tổng quan kiến trúc

### 1.1. Mô hình PKI

```
                    ┌─────────────────┐
                    │    Root CA      │
                    │  (Offline)      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Intermediate CA │
                    │   (Online)      │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼────────┐  ┌────────▼────────┐  ┌───────▼────────┐
│  Server Cert   │  │  Client Cert    │  │   Email Cert   │
│  (TLS/SSL)     │  │  (mTLS)         │  │   (S/MIME)     │
└────────────────┘  └─────────────────┘  └────────────────┘
```

### 1.2. Các thành phần chính

#### Root CA (Certificate Authority gốc)
- **Vai trò**: CA cao nhất trong hierarchy, tự ký chứng chỉ của chính nó
- **Vòng đời**: 20-30 năm
- **Bảo mật**: Offline, lưu trữ trong HSM hoặc air-gapped system
- **Chức năng**: Chỉ ký chứng chỉ cho Intermediate CA

#### Intermediate CA
- **Vai trò**: CA trung gian, được Root CA ký
- **Vòng đời**: 10 năm
- **Bảo mật**: Online, nhưng được bảo vệ nghiêm ngặt
- **Chức năng**: Cấp chứng chỉ cho end-entities

#### End-entity Certificates
- **Vai trò**: Chứng chỉ cho users, servers, devices
- **Vòng đời**: 1-3 năm
- **Loại**: Server, Client, Email, Code Signing, etc.

### 1.3. Lợi ích của Hierarchy

1. **Bảo mật cao hơn**: Root CA offline → giảm nguy cơ compromise
2. **Linh hoạt**: Thu hồi Intermediate CA không ảnh hưởng Root
3. **Phân quyền**: Các Intermediate CA cho các mục đích khác nhau
4. **Scalability**: Dễ mở rộng với nhiều Intermediate CAs

## 2. Thiết kế Hierarchy

### 2.1. Root CA Specifications

```yaml
Root CA:
  Common Name: "Example Root CA"
  Organization: "Example Organization"
  Country: "VN"
  Key Algorithm: RSA
  Key Size: 4096 bits
  Hash Algorithm: SHA-256
  Validity: 7300 days (20 years)
  Usage:
    - Certificate Signing
    - CRL Signing
  Basic Constraints:
    CA: TRUE
    Path Length: 1 (chỉ cho phép 1 intermediate CA)
  Key Usage:
    - keyCertSign
    - cRLSign
```

### 2.2. Intermediate CA Specifications

```yaml
Intermediate CA:
  Common Name: "Example Intermediate CA"
  Organization: "Example Organization"
  Country: "VN"
  Key Algorithm: RSA
  Key Size: 4096 bits
  Hash Algorithm: SHA-256
  Validity: 3650 days (10 years)
  Usage:
    - Certificate Signing
    - CRL Signing
  Basic Constraints:
    CA: TRUE
    Path Length: 0 (không cho phép CA con)
  Key Usage:
    - keyCertSign
    - cRLSign
  CDP (CRL Distribution Points):
    - http://crl.example.com/intermediate.crl
  AIA (Authority Information Access):
    - http://aia.example.com/intermediate.crt
```

### 2.3. End-entity Certificate Types

#### 2.3.1. Server Certificate (TLS/SSL)

```yaml
Server Certificate:
  Common Name: "www.example.com"
  Subject Alternative Names:
    - DNS: www.example.com
    - DNS: example.com
    - DNS: mail.example.com
  Key Algorithm: RSA
  Key Size: 2048 bits
  Hash Algorithm: SHA-256
  Validity: 398 days (13 months - theo CA/Browser Forum)
  Extended Key Usage:
    - serverAuth
  Key Usage:
    - digitalSignature
    - keyEncipherment
```

#### 2.3.2. Client Certificate (mTLS)

```yaml
Client Certificate:
  Common Name: "user@example.com"
  Email: "user@example.com"
  Key Algorithm: RSA
  Key Size: 2048 bits
  Validity: 365 days (1 year)
  Extended Key Usage:
    - clientAuth
  Key Usage:
    - digitalSignature
```

#### 2.3.3. Email Certificate (S/MIME)

```yaml
Email Certificate:
  Common Name: "John Doe"
  Email: "john.doe@example.com"
  Key Algorithm: RSA
  Key Size: 2048 bits
  Validity: 365 days
  Extended Key Usage:
    - emailProtection
  Key Usage:
    - digitalSignature
    - keyEncipherment
```

## 3. Certificate Policy (CP)

### 3.1. Định nghĩa Policy

Certificate Policy định nghĩa các quy tắc và thủ tục mà CA tuân theo khi cấp và quản lý chứng chỉ.

#### 3.1.1. Policy Levels

```
Level 1 - Low Assurance:
  - Tự động xác thực email
  - Sử dụng cho môi trường test/dev
  - Validity: 90 days
  - OID: 1.2.3.4.1

Level 2 - Medium Assurance:
  - Xác thực domain ownership
  - Yêu cầu approval từ admin
  - Validity: 1 year
  - OID: 1.2.3.4.2

Level 3 - High Assurance:
  - Extended Validation (EV)
  - Xác thực pháp lý tổ chức
  - Background check
  - Validity: 1 year
  - OID: 1.2.3.4.3
```

### 3.2. Certificate Profiles

#### Server Certificate Profile

```ini
[server_cert]
# Extensions
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
crlDistributionPoints = URI:http://crl.example.com/intermediate.crl
authorityInfoAccess = OCSP;URI:http://ocsp.example.com

[alt_names]
DNS.1 = www.example.com
DNS.2 = example.com
```

## 4. Quy trình cấp chứng chỉ

### 4.1. Certificate Request Process

```
┌──────────┐          ┌──────────┐          ┌──────────┐
│  Client  │          │    RA    │          │    CA    │
└────┬─────┘          └────┬─────┘          └────┬─────┘
     │                     │                     │
     │  1. Generate CSR    │                     │
     ├────────────────────>│                     │
     │                     │                     │
     │                     │  2. Validate CSR    │
     │                     ├────────────────────>│
     │                     │                     │
     │                     │  3. Sign Certificate│
     │                     │<────────────────────┤
     │                     │                     │
     │  4. Return Cert     │                     │
     │<────────────────────┤                     │
     │                     │                     │
```

### 4.2. Các bước chi tiết

#### Bước 1: Client tạo Key Pair và CSR

```bash
# Tạo private key
openssl genrsa -out server.key 2048

# Tạo CSR
openssl req -new \
  -key server.key \
  -out server.csr \
  -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Example Org/CN=www.example.com"
```

#### Bước 2: Registration Authority (RA) xác thực

- Xác minh identity của requester
- Kiểm tra domain ownership (DNS validation, HTTP validation)
- Verify business documents (đối với EV certificates)
- Approval workflow

#### Bước 3: CA ký chứng chỉ

```bash
# CA signs the certificate
openssl ca \
  -config intermediate/openssl.cnf \
  -extensions server_cert \
  -days 375 \
  -notext \
  -md sha256 \
  -in server.csr \
  -out server.crt
```

#### Bước 4: Phát hành chứng chỉ

- Certificate được lưu vào database
- Serial number được ghi nhận
- Certificate được gửi về client

### 4.3. Validation Methods

#### Domain Validation (DV)

**HTTP-01 Challenge**:
```
1. CA tạo random token
2. Client đặt token tại: http://domain/.well-known/acme-challenge/{token}
3. CA fetch và verify token
```

**DNS-01 Challenge**:
```
1. CA tạo random token
2. Client tạo TXT record: _acme-challenge.domain.com = {token-hash}
3. CA query DNS và verify
```

**Email Validation**:
```
1. CA gửi email đến admin@domain.com hoặc postmaster@domain.com
2. Client click link confirmation
```

## 5. Quy trình thu hồi

### 5.1. Revocation Process

```
┌──────────┐          ┌──────────┐          ┌──────────┐
│Requester │          │    CA    │          │   User   │
└────┬─────┘          └────┬─────┘          └────┬─────┘
     │                     │                     │
     │  1. Revoke Request  │                     │
     ├────────────────────>│                     │
     │                     │                     │
     │  2. Verify Auth     │                     │
     │<────────────────────┤                     │
     │                     │                     │
     │  3. Add to CRL      │                     │
     │                     ├──────────┐          │
     │                     │          │          │
     │                     │<─────────┘          │
     │                     │                     │
     │                     │  4. Publish CRL     │
     │                     ├────────────────────>│
     │                     │                     │
```

### 5.2. Revocation Reasons

Theo RFC 5280, các lý do thu hồi:

```
0 - unspecified: Không xác định
1 - keyCompromise: Private key bị compromise
2 - cACompromise: CA bị compromise
3 - affiliationChanged: Thay đổi liên kết (employee rời công ty)
4 - superseded: Certificate bị thay thế
5 - cessationOfOperation: Ngừng hoạt động
6 - certificateHold: Tạm thời hold (có thể remove khỏi CRL)
8 - removeFromCRL: Remove khỏi CRL
9 - privilegeWithdrawn: Thu hồi quyền
10 - aACompromise: Attribute Authority bị compromise
```

### 5.3. CRL (Certificate Revocation List)

#### CRL Structure

```
Certificate Revocation List (CRL):
  Version: 2
  Signature Algorithm: sha256WithRSAEncryption
  Issuer: CN=Example Intermediate CA
  Last Update: Jan 1 00:00:00 2024 GMT
  Next Update: Jan 8 00:00:00 2024 GMT
  CRL Extensions:
    X509v3 Authority Key Identifier
    X509v3 CRL Number: 1234

Revoked Certificates:
  Serial Number: 1001
    Revocation Date: Jan 1 10:00:00 2024 GMT
    CRL Reason Code: Key Compromise

  Serial Number: 1002
    Revocation Date: Jan 2 15:30:00 2024 GMT
    CRL Reason Code: Superseded
```

#### CRL Generation

```bash
# Generate CRL
openssl ca \
  -config intermediate/openssl.cnf \
  -gencrl \
  -out intermediate/crl/intermediate.crl

# Convert to DER format
openssl crl \
  -in intermediate/crl/intermediate.crl \
  -outform DER \
  -out intermediate/crl/intermediate.crl.der
```

### 5.4. OCSP (Online Certificate Status Protocol)

#### OCSP vs CRL

| Feature | CRL | OCSP |
|---------|-----|------|
| Update | Periodic (weekly) | Real-time |
| Size | Large (all revoked certs) | Small (single cert status) |
| Privacy | Better (download entire list) | Worse (query specific cert) |
| Performance | Cached locally | Network request |

#### OCSP Request/Response

```
OCSP Request:
  Certificate ID:
    Hash Algorithm: SHA-256
    Issuer Name Hash: abc123...
    Issuer Key Hash: def456...
    Serial Number: 1001

OCSP Response:
  Response Status: successful
  Certificate Status: revoked
  Revocation Time: Jan 1 10:00:00 2024 GMT
  Revocation Reason: keyCompromise
  This Update: Jan 5 08:00:00 2024 GMT
  Next Update: Jan 5 20:00:00 2024 GMT
```

### 5.5. OCSP Stapling

Để cải thiện performance và privacy:

```
┌──────────┐          ┌──────────┐          ┌──────────┐
│  Client  │          │  Server  │          │OCSP Resp.│
└────┬─────┘          └────┬─────┘          └────┬─────┘
     │                     │                     │
     │                     │  1. Request OCSP    │
     │                     ├────────────────────>│
     │                     │                     │
     │                     │  2. OCSP Response   │
     │                     │<────────────────────┤
     │                     │                     │
     │  3. TLS Handshake   │                     │
     │     + OCSP Response │                     │
     │<────────────────────┤                     │
     │                     │                     │
```

Server cache OCSP response và gửi trong TLS handshake, client không cần query OCSP responder.

## 6. Security Considerations

### 6.1. Key Management

- **Key Generation**: Sử dụng CSPRNG (Cryptographically Secure PRNG)
- **Key Storage**: HSM hoặc encrypted storage
- **Key Backup**: Encrypted backup ở multiple locations
- **Key Rotation**: Root CA: 20 years, Intermediate: 10 years, End-entity: 1-2 years

### 6.2. Algorithm Selection

```yaml
Recommended (2024):
  Asymmetric:
    - RSA: 2048 bits minimum (4096 for CA)
    - ECDSA: P-256, P-384, P-521
  Hash:
    - SHA-256 (minimum)
    - SHA-384, SHA-512 (preferred for CA)

Deprecated:
  - MD5: KHÔNG sử dụng
  - SHA-1: KHÔNG sử dụng
  - RSA < 2048 bits: KHÔNG sử dụng
```

### 6.3. Certificate Validity Periods

Theo CA/Browser Forum Baseline Requirements:

- **Server certificates**: Maximum 398 days (13 months)
- **Intermediate CA**: 10 years
- **Root CA**: 20-25 years

### 6.4. Access Control

```yaml
Root CA Private Key:
  Access: CTO, Security Officer only
  Location: Air-gapped system, HSM
  Ceremony: Dual control, 2-person rule

Intermediate CA:
  Access: Security team
  Location: Secure server, protected by firewall
  Logging: All operations logged

Database:
  Access: PKI administrators
  Backup: Daily encrypted backup
```

## 7. Compliance và Standards

### 7.1. Standards và RFCs

- **RFC 5280**: X.509 PKI Certificate and CRL Profile
- **RFC 6960**: Online Certificate Status Protocol (OCSP)
- **RFC 8555**: Automatic Certificate Management Environment (ACME)
- **CA/Browser Forum**: Baseline Requirements for SSL/TLS certificates

### 7.2. Audit Requirements

- **Certificate issuance**: Log all certificate operations
- **Revocation**: Log with reason and timestamp
- **Access**: Log all access to private keys
- **Configuration changes**: Version control
- **Periodic audit**: Quarterly security review

## Kết luận

Thiết kế giao thức PKI cần cân nhắc nhiều yếu tố:
- **Security**: Bảo vệ private keys, sử dụng strong algorithms
- **Scalability**: Hierarchy cho phép mở rộng
- **Availability**: CRL/OCSP cho revocation checking
- **Compliance**: Tuân thủ standards và regulations

Trong phần tiếp theo, chúng ta sẽ triển khai thiết kế này với OpenSSL.
