# OCSP (Online Certificate Status Protocol) - Hướng dẫn chi tiết

## Mục lục

- [1. Giới thiệu OCSP](#1-giới-thiệu-ocsp)
- [2. OCSP vs CRL](#2-ocsp-vs-crl)
- [3. Thiết lập OCSP Responder](#3-thiết-lập-ocsp-responder)
- [4. Kiểm tra OCSP](#4-kiểm-tra-ocsp)
- [5. OCSP Stapling](#5-ocsp-stapling)
- [6. Production Deployment](#6-production-deployment)
- [7. Troubleshooting](#7-troubleshooting)

## 1. Giới thiệu OCSP

### 1.1. OCSP là gì?

**OCSP (Online Certificate Status Protocol)** là giao thức để kiểm tra trạng thái thu hồi của certificate theo thời gian thực.

```
┌─────────────────────────────────────────────────────────────────┐
│ Timeline: Phát triển của Certificate Revocation                │
├─────────────────────────────────────────────────────────────────┤
│ 1988: X.509 v1 - Không có cơ chế revocation                    │
│   └─> Problem: Không thể thu hồi certificate bị lộ            │
│                                                                 │
│ 1993: X.509 v2 - Giới thiệu CRL (Certificate Revocation List) │
│   └─> Problem: CRL file lớn, phải download toàn bộ            │
│                                                                 │
│ 1999: RFC 2560 - OCSP ra đời                                   │
│   └─> Solution: Query từng certificate, response nhỏ gọn      │
│                                                                 │
│ 2013: RFC 6960 - OCSP phiên bản cải tiến                       │
│   └─> Thêm OCSP Stapling, cải thiện privacy & performance     │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2. OCSP hoạt động như thế nào?

```
┌────────────┐                                      ┌────────────┐
│            │  1. OCSP Request (certificate SN)    │            │
│   Client   │ ──────────────────────────────────> │    OCSP    │
│  (Browser) │                                      │  Responder │
│            │  2. OCSP Response (good/revoked)     │            │
│            │ <────────────────────────────────── │            │
└────────────┘                                      └────────────┘
                                                           │
                                                           │ Check status
                                                           ↓
                                                    ┌─────────────┐
                                                    │ CA Database │
                                                    │  (index.txt)│
                                                    └─────────────┘
```

**Quy trình chi tiết:**

1. **Client tạo OCSP Request:**
   - Lấy serial number của certificate cần kiểm tra
   - Lấy issuer name hash và issuer key hash
   - Tạo OCSP request message

2. **OCSP Responder xử lý:**
   - Parse OCSP request
   - Tra cứu serial number trong CA database
   - Tạo OCSP response với status: `good`, `revoked`, hoặc `unknown`
   - Ký response bằng OCSP signing key

3. **Client verify response:**
   - Verify OCSP response signature
   - Kiểm tra OCSP signing certificate
   - Đọc certificate status

### 1.3. OCSP Request/Response Format

**OCSP Request structure:**

```asn1
OCSPRequest ::= SEQUENCE {
    tbsRequest      TBSRequest,
    optionalSignature   [0] EXPLICIT Signature OPTIONAL
}

TBSRequest ::= SEQUENCE {
    version             [0] EXPLICIT Version DEFAULT v1,
    requestorName       [1] EXPLICIT GeneralName OPTIONAL,
    requestList         SEQUENCE OF Request
}

Request ::= SEQUENCE {
    reqCert     CertID,         -- Certificate identifier
    singleRequestExtensions [0] EXPLICIT Extensions OPTIONAL
}

CertID ::= SEQUENCE {
    hashAlgorithm   AlgorithmIdentifier,
    issuerNameHash  OCTET STRING,   -- Hash of issuer DN
    issuerKeyHash   OCTET STRING,   -- Hash of issuer public key
    serialNumber    CertificateSerialNumber
}
```

**OCSP Response structure:**

```asn1
OCSPResponse ::= SEQUENCE {
   responseStatus  OCSPResponseStatus,
   responseBytes   [0] EXPLICIT ResponseBytes OPTIONAL
}

OCSPResponseStatus ::= ENUMERATED {
    successful          (0),  -- Response has valid confirmations
    malformedRequest    (1),  -- Illegal confirmation request
    internalError       (2),  -- Internal error in issuer
    tryLater            (3),  -- Try again later
    sigRequired         (5),  -- Must sign the request
    unauthorized        (6)   -- Request unauthorized
}

ResponseBytes ::= SEQUENCE {
    responseType    OBJECT IDENTIFIER,
    response        OCTET STRING
}

BasicOCSPResponse ::= SEQUENCE {
   tbsResponseData      ResponseData,
   signatureAlgorithm   AlgorithmIdentifier,
   signature            BIT STRING,
   certs            [0] EXPLICIT SEQUENCE OF Certificate OPTIONAL
}

ResponseData ::= SEQUENCE {
   version              [0] EXPLICIT Version DEFAULT v1,
   responderID              ResponderID,
   producedAt               GeneralizedTime,
   responses                SEQUENCE OF SingleResponse
}

SingleResponse ::= SEQUENCE {
   certID                   CertID,
   certStatus               CertStatus,
   thisUpdate               GeneralizedTime,
   nextUpdate           [0] EXPLICIT GeneralizedTime OPTIONAL,
   singleExtensions     [1] EXPLICIT Extensions OPTIONAL
}

CertStatus ::= CHOICE {
    good        [0]     IMPLICIT NULL,
    revoked     [1]     IMPLICIT RevokedInfo,
    unknown     [2]     IMPLICIT UnknownInfo
}

RevokedInfo ::= SEQUENCE {
    revocationTime              GeneralizedTime,
    revocationReason    [0]     EXPLICIT CRLReason OPTIONAL
}
```

## 2. OCSP vs CRL

### 2.1. So sánh chi tiết

| Tiêu chí | CRL | OCSP |
|----------|-----|------|
| **Phương pháp** | Download danh sách thu hồi | Query từng certificate |
| **Kích thước** | Lớn (chứa tất cả revoked certs) | Nhỏ (chỉ 1 certificate) |
| **Bandwidth** | Cao (download toàn bộ CRL) | Thấp (query nhỏ gọn) |
| **Freshness** | Thấp (update định kỳ, vd: 24h) | Cao (real-time) |
| **Privacy** | Tốt (không tiết lộ cert nào check) | Kém (OCSP provider biết cert nào check) |
| **Caching** | Dễ cache (CRL ít thay đổi) | Khó cache (cần fresh data) |
| **Offline** | Có thể dùng offline | Cần kết nối internet |
| **Performance** | Chậm với CRL lớn | Nhanh với từng query |
| **Infrastructure** | Đơn giản (chỉ cần web server) | Phức tạp (cần OCSP responder) |

### 2.2. Khi nào dùng CRL?

✅ **Nên dùng CRL khi:**
- Số lượng certificate ít (< 1000 certs)
- Certificate ít bị thu hồi
- Có thể chấp nhận độ trễ cập nhật (vd: 24h)
- Cần offline verification
- Hạ tầng đơn giản, không có budget cho OCSP server

❌ **Không nên dùng CRL khi:**
- Số lượng certificate lớn (> 10000 certs)
- Cần real-time revocation checking
- CRL quá lớn (> 1MB) ảnh hưởng performance

### 2.3. Khi nào dùng OCSP?

✅ **Nên dùng OCSP khi:**
- Cần kiểm tra revocation real-time
- Số lượng certificate lớn
- Cần tiết kiệm bandwidth
- Có budget để vận hành OCSP responder
- Compliance yêu cầu (vd: PCI DSS)

❌ **Không nên dùng OCSP khi:**
- Không có hạ tầng để chạy OCSP responder 24/7
- Cần offline verification
- Privacy là ưu tiên hàng đầu (vì OCSP provider biết cert nào được check)

### 2.4. Best Practice: Kết hợp CRL + OCSP

**Chiến lược khuyến nghị:**

```
┌─────────────────────────────────────────────────────────────────┐
│ Defense in Depth: CRL + OCSP + OCSP Stapling                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ 1. Primary: OCSP với OCSP Stapling                             │
│    └─> Fast, real-time, giảm privacy leak                     │
│                                                                 │
│ 2. Fallback: OCSP query trực tiếp                              │
│    └─> Nếu stapling không available                           │
│                                                                 │
│ 3. Last resort: CRL                                            │
│    └─> Nếu OCSP responder down                                │
│                                                                 │
│ 4. Grace period: Allow if all fail                             │
│    └─> Tránh break service khi CA infrastructure down         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Cấu hình trong certificate:

```
X509v3 extensions:
    X509v3 CRL Distribution Points:
        Full Name:
          URI:http://crl.example.com/intermediate.crl

    Authority Information Access:
        OCSP - URI:http://ocsp.example.com:8888
        CA Issuers - URI:http://ca.example.com/intermediate.cert.pem
```

## 3. Thiết lập OCSP Responder

### 3.1. Quick Setup với script

```bash
# Chạy script tự động setup OCSP
cd /root/ca/scripts
sudo ./setup-ocsp.sh
```

Script sẽ:
1. ✅ Tạo OCSP signing key
2. ✅ Tạo OCSP signing certificate
3. ✅ Tạo startup/stop scripts
4. ✅ Tạo systemd service file

### 3.2. Manual Setup - Chi tiết từng bước

#### Bước 1: Tạo OCSP Signing Key

```bash
cd /root/ca

# Generate 2048-bit RSA key
openssl genrsa -out intermediate/private/ocsp.key.pem 2048
chmod 400 intermediate/private/ocsp.key.pem
```

**Tại sao cần key riêng cho OCSP?**
- **Security best practice**: Không dùng CA private key cho OCSP
- **Key compromise isolation**: Nếu OCSP key bị lộ, CA key vẫn an toàn
- **Performance**: OCSP key không cần bảo vệ chặt như CA key
- **Operational**: OCSP responder cần access key thường xuyên

#### Bước 2: Tạo OCSP Signing Certificate

```bash
# Create CSR
openssl req -new -sha256 \
    -config intermediate/openssl.cnf \
    -key intermediate/private/ocsp.key.pem \
    -out intermediate/csr/ocsp.csr.pem \
    -subj "/C=VN/ST=Hanoi/O=Example Organization/OU=OCSP Services/CN=OCSP Responder"

# Add OCSP extension to config (nếu chưa có)
cat >> intermediate/openssl.cnf << 'EOF'

[ ocsp_cert ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF

# Sign OCSP certificate
openssl ca -batch \
    -config intermediate/openssl.cnf \
    -extensions ocsp_cert \
    -days 375 \
    -notext \
    -md sha256 \
    -in intermediate/csr/ocsp.csr.pem \
    -out intermediate/certs/ocsp.cert.pem

chmod 444 intermediate/certs/ocsp.cert.pem
```

**Extensions giải thích:**

- `basicConstraints = CA:FALSE`: Đây KHÔNG phải CA certificate
- `keyUsage = critical, digitalSignature`: Chỉ được dùng để ký
- `extendedKeyUsage = critical, OCSPSigning`: **BẮT BUỘC** - chỉ định dùng cho OCSP
  - `critical`: Extension này PHẢI được hiểu, không thì reject
  - `OCSPSigning` (id-kp-OCSPSigning 1.3.6.1.5.5.7.3.9): OCSP signing purpose

**Verify OCSP certificate:**

```bash
# Check extensions
openssl x509 -in intermediate/certs/ocsp.cert.pem -noout -text | grep -A 3 "Extended Key Usage"

# Output:
# X509v3 Extended Key Usage: critical
#     OCSP Signing
```

#### Bước 3: Chạy OCSP Responder

**Method 1: Manual (for testing)**

```bash
openssl ocsp \
    -port 8888 \
    -text \
    -sha256 \
    -index intermediate/index.txt \
    -CA intermediate/certs/ca-chain.cert.pem \
    -rkey intermediate/private/ocsp.key.pem \
    -rsigner intermediate/certs/ocsp.cert.pem \
    -nrequest 1
```

**Parameters giải thích:**

- `-port 8888`: Listen trên port 8888
- `-text`: Show text output (for debugging)
- `-sha256`: Dùng SHA-256 hash algorithm
- `-index intermediate/index.txt`: CA database chứa certificate status
- `-CA ca-chain.cert.pem`: CA chain để verify requests
- `-rkey ocsp.key.pem`: OCSP signing private key
- `-rsigner ocsp.cert.pem`: OCSP signing certificate
- `-nrequest 1`: Exit sau 1 request (for testing)

**Method 2: Background service**

```bash
# Start in background
nohup openssl ocsp \
    -port 8888 \
    -text \
    -sha256 \
    -index intermediate/index.txt \
    -CA intermediate/certs/ca-chain.cert.pem \
    -rkey intermediate/private/ocsp.key.pem \
    -rsigner intermediate/certs/ocsp.cert.pem \
    > /var/log/ocsp-responder.log 2>&1 &

echo $! > /var/run/ocsp-responder.pid
```

**Method 3: Systemd service (production)**

```bash
# Use setup script
sudo ./setup-ocsp.sh

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable ocsp-responder
sudo systemctl start ocsp-responder

# Check status
sudo systemctl status ocsp-responder

# View logs
sudo journalctl -u ocsp-responder -f
```

## 4. Kiểm tra OCSP

### 4.1. Sử dụng script check-ocsp.sh

```bash
cd /root/ca/scripts

# Check local certificate file
./check-ocsp.sh -f /root/ca/intermediate/certs/www.example.com.cert.pem

# Check remote HTTPS server
./check-ocsp.sh -h www.example.com -p 443

# Use custom OCSP URL
./check-ocsp.sh -f server.cert.pem -u http://ocsp.example.com:8888

# Verbose output
./check-ocsp.sh -f server.cert.pem -v
```

### 4.2. Manual OCSP Query

```bash
# Basic OCSP query
openssl ocsp \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -url http://localhost:8888 \
    -issuer intermediate/certs/intermediate.cert.pem \
    -cert intermediate/certs/www.example.com.cert.pem

# Output khi certificate GOOD:
# Response verify OK
# intermediate/certs/www.example.com.cert.pem: good
#     This Update: Dec 15 10:30:00 2024 GMT
#     Next Update: Dec 15 10:35:00 2024 GMT

# Output khi certificate REVOKED:
# Response verify OK
# intermediate/certs/compromised.cert.pem: revoked
#     This Update: Dec 15 10:30:00 2024 GMT
#     Next Update: Dec 15 10:35:00 2024 GMT
#     Revocation Time: Dec 14 15:20:00 2024 GMT
#     Revocation Reason: keyCompromise
```

**Với verbose output:**

```bash
openssl ocsp \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -url http://localhost:8888 \
    -resp_text \
    -issuer intermediate/certs/intermediate.cert.pem \
    -cert intermediate/certs/www.example.com.cert.pem
```

Output:

```
OCSP Response Data:
    OCSP Response Status: successful (0x0)
    Response Type: Basic OCSP Response
    Version: 1 (0x0)
    Responder Id: C = VN, ST = Hanoi, O = Example Organization, CN = OCSP Responder
    Produced At: Dec 15 10:30:00 2024 GMT
    Responses:
    Certificate ID:
      Hash Algorithm: sha256
      Issuer Name Hash: 1234567890ABCDEF...
      Issuer Key Hash: ABCDEF1234567890...
      Serial Number: 1000
    Cert Status: good
    This Update: Dec 15 10:30:00 2024 GMT
    Next Update: Dec 15 10:35:00 2024 GMT

Response verify OK
intermediate/certs/www.example.com.cert.pem: good
```

### 4.3. Test OCSP với revoked certificate

```bash
# Revoke a test certificate
cd /root/ca
./scripts/revoke-certificate.sh intermediate/certs/test.cert.pem keyCompromise

# Query OCSP
openssl ocsp \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -url http://localhost:8888 \
    -resp_text \
    -issuer intermediate/certs/intermediate.cert.pem \
    -cert intermediate/certs/test.cert.pem

# Expected output:
# Cert Status: revoked
# Revocation Time: Dec 15 10:45:00 2024 GMT
# Revocation Reason: keyCompromise
```

### 4.4. OCSP với curl

Bạn có thể dùng curl để gửi OCSP request (advanced):

```bash
# Generate OCSP request DER
openssl ocsp \
    -issuer intermediate/certs/intermediate.cert.pem \
    -cert intermediate/certs/www.example.com.cert.pem \
    -reqout /tmp/ocsp-request.der

# Send via curl
curl -X POST \
    -H "Content-Type: application/ocsp-request" \
    --data-binary @/tmp/ocsp-request.der \
    http://localhost:8888 \
    -o /tmp/ocsp-response.der

# Parse response
openssl ocsp \
    -respin /tmp/ocsp-response.der \
    -resp_text \
    -noverify
```

## 5. OCSP Stapling

### 5.1. OCSP Stapling là gì?

**OCSP Stapling** (RFC 6066) là kỹ thuật server tự query OCSP và gửi kèm response cho client.

**Lợi ích:**

```
┌─────────────────────────────────────────────────────────────────┐
│ Traditional OCSP vs OCSP Stapling                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ TRADITIONAL OCSP:                                              │
│ ┌────────┐  1. TLS Handshake  ┌────────┐                      │
│ │ Client │ ──────────────────> │ Server │                      │
│ └────────┘                      └────────┘                      │
│     │                                                           │
│     │ 2. OCSP Query                                            │
│     └─────────────────────> ┌──────────┐                       │
│                              │   OCSP   │                       │
│     3. OCSP Response         │ Responder│                       │
│     <─────────────────────── └──────────┘                       │
│                                                                 │
│ ❌ Privacy leak: OCSP provider biết client connect đến đâu      │
│ ❌ Performance: Thêm 1 RTT để query OCSP                        │
│ ❌ Reliability: Nếu OCSP down, TLS có thể fail                  │
│                                                                 │
│ ─────────────────────────────────────────────────────────────  │
│                                                                 │
│ OCSP STAPLING:                                                 │
│                         ┌────────┐                              │
│                         │ Server │                              │
│                         └────────┘                              │
│                             │                                   │
│                             │ Background: Query OCSP            │
│                             └──────────> ┌──────────┐           │
│                                          │   OCSP   │           │
│                             <────────────│ Responder│           │
│                                          └──────────┘           │
│                                                                 │
│ ┌────────┐  1. TLS Handshake + Stapled OCSP  ┌────────┐        │
│ │ Client │ ──────────────────────────────────>│ Server │        │
│ └────────┘                                    └────────┘        │
│                                                                 │
│ ✅ Privacy: Client không cần query OCSP trực tiếp               │
│ ✅ Performance: Không thêm latency                              │
│ ✅ Reliability: Server cache OCSP response                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2. Cấu hình OCSP Stapling với Nginx

```nginx
# /etc/nginx/sites-available/example.com

server {
    listen 443 ssl http2;
    server_name www.example.com;

    # SSL Certificates
    ssl_certificate /root/ca/intermediate/certs/www.example.com.bundle.pem;
    ssl_certificate_key /root/ca/intermediate/private/www.example.com.key.pem;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /root/ca/intermediate/certs/ca-chain.cert.pem;

    # OCSP Responder (optional, nếu không có trong cert)
    # resolver 8.8.8.8 8.8.4.4 valid=300s;
    # resolver_timeout 5s;

    # OCSP Stapling cache
    ssl_stapling_file /var/cache/nginx/ocsp/www.example.com.ocsp;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        root /var/www/html;
        index index.html;
    }
}
```

**Test OCSP Stapling:**

```bash
# Check if OCSP stapling is working
echo | openssl s_client -connect www.example.com:443 -status -servername www.example.com 2>&1 | grep -A 17 "OCSP Response"

# Expected output:
# OCSP Response Status: successful (0x0)
# Response Type: Basic OCSP Response
# ...
# Cert Status: good
```

### 5.3. Cấu hình OCSP Stapling với Apache

```apache
# /etc/apache2/sites-available/example.com-ssl.conf

<VirtualHost *:443>
    ServerName www.example.com

    SSLEngine on
    SSLCertificateFile /root/ca/intermediate/certs/www.example.com.cert.pem
    SSLCertificateKeyFile /root/ca/intermediate/private/www.example.com.key.pem
    SSLCertificateChainFile /root/ca/intermediate/certs/ca-chain.cert.pem

    # OCSP Stapling
    SSLUseStapling on

    DocumentRoot /var/www/html
</VirtualHost>

# Global OCSP Stapling config
SSLStaplingCache shmcb:/var/run/ocsp(128000)
SSLStaplingResponderTimeout 5
SSLStaplingReturnResponderErrors off
```

**Enable và restart:**

```bash
# Enable modules
sudo a2enmod ssl
sudo a2enmod socache_shmcb

# Enable site
sudo a2ensite example.com-ssl

# Restart Apache
sudo systemctl restart apache2
```

## 6. Production Deployment

### 6.1. OCSP Responder với High Availability

**Setup Load Balancer:**

```nginx
# /etc/nginx/conf.d/ocsp-loadbalancer.conf

upstream ocsp_backend {
    least_conn;
    server ocsp1.example.com:8888 max_fails=3 fail_timeout=30s;
    server ocsp2.example.com:8888 max_fails=3 fail_timeout=30s;
    server ocsp3.example.com:8888 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name ocsp.example.com;

    location / {
        proxy_pass http://ocsp_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # OCSP timeouts
        proxy_connect_timeout 5s;
        proxy_read_timeout 5s;
        proxy_send_timeout 5s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
```

### 6.2. Monitoring OCSP Responder

**Script kiểm tra health:**

```bash
#!/bin/bash
# /usr/local/bin/check-ocsp-health.sh

OCSP_URL="http://localhost:8888"
TEST_CERT="/root/ca/intermediate/certs/www.example.com.cert.pem"
ISSUER_CERT="/root/ca/intermediate/certs/intermediate.cert.pem"
CA_CHAIN="/root/ca/intermediate/certs/ca-chain.cert.pem"

# Query OCSP
if openssl ocsp \
    -CAfile "$CA_CHAIN" \
    -url "$OCSP_URL" \
    -issuer "$ISSUER_CERT" \
    -cert "$TEST_CERT" \
    -timeout 5 2>&1 | grep -q "Response verify OK"; then
    echo "OCSP responder is healthy"
    exit 0
else
    echo "OCSP responder is down or not responding"
    exit 1
fi
```

**Prometheus monitoring:**

```bash
# Install ocsp_exporter
go install github.com/ribbybibby/ssl_exporter@latest

# Run exporter
./ssl_exporter --config.file=ocsp-config.yml
```

**ocsp-config.yml:**

```yaml
modules:
  ocsp:
    prober: ocsp
    timeout: 5s
    ocsp:
      issuer_cert_file: /root/ca/intermediate/certs/intermediate.cert.pem
      ca_file: /root/ca/intermediate/certs/ca-chain.cert.pem
```

### 6.3. Automated Certificate Renewal

Khi renew certificate, cần update OCSP:

```bash
#!/bin/bash
# /usr/local/bin/renew-and-update-ocsp.sh

CERT_PATH="$1"
DOMAIN="$2"

# Renew certificate
./issue-certificate.sh server "$DOMAIN"

# OCSP responder tự động đọc index.txt, không cần restart
# Nhưng nên verify:
sleep 2

# Test OCSP với certificate mới
./check-ocsp.sh -f "$CERT_PATH"

if [ $? -eq 0 ]; then
    echo "Certificate renewed and OCSP updated successfully"
else
    echo "Warning: OCSP check failed after renewal"
    exit 1
fi
```

### 6.4. Security Best Practices

✅ **DO:**
- Chạy OCSP responder trên server riêng (không cùng CA server)
- Dùng OCSP signing certificate riêng (không dùng CA key)
- Set proper permissions cho OCSP key (chmod 400)
- Enable rate limiting trên reverse proxy
- Monitor OCSP responder health 24/7
- Cache OCSP responses (server-side)
- Implement graceful degradation nếu OCSP down

❌ **DON'T:**
- Không dùng CA private key để sign OCSP responses
- Không expose OCSP responder trực tiếp ra internet (dùng reverse proxy)
- Không hardcode OCSP URL trong code (dùng AIA extension)
- Không skip OCSP response verification
- Không set quá dài nextUpdate time (max 7 days)

## 7. Troubleshooting

### 7.1. OCSP Responder không start

**Lỗi: "Error loading OCSP signing key"**

```bash
# Check key permissions
ls -la /root/ca/intermediate/private/ocsp.key.pem

# Fix permissions
chmod 400 /root/ca/intermediate/private/ocsp.key.pem
chown root:root /root/ca/intermediate/private/ocsp.key.pem
```

**Lỗi: "Error opening CA certificate"**

```bash
# Check CA chain exists
ls -la /root/ca/intermediate/certs/ca-chain.cert.pem

# Recreate CA chain if needed
cat intermediate/certs/intermediate.cert.pem \
    rootca/certs/ca.cert.pem > \
    intermediate/certs/ca-chain.cert.pem
```

### 7.2. OCSP Response verify failed

**Lỗi: "Response Verify Failure"**

Nguyên nhân:
1. OCSP signing certificate không có `extendedKeyUsage = OCSPSigning`
2. OCSP certificate hết hạn
3. CA chain không đầy đủ

**Fix:**

```bash
# Check OCSP certificate extensions
openssl x509 -in intermediate/certs/ocsp.cert.pem -noout -text | grep -A 3 "Extended Key Usage"

# Should show:
# X509v3 Extended Key Usage: critical
#     OCSP Signing

# Check OCSP certificate expiry
openssl x509 -in intermediate/certs/ocsp.cert.pem -noout -dates

# Recreate OCSP certificate nếu sai
./setup-ocsp.sh
```

### 7.3. Certificate status = unknown

**Lỗi: "cert status: unknown"**

Nguyên nhân:
- Certificate không có trong index.txt
- Serial number không match

**Debug:**

```bash
# Get certificate serial
SERIAL=$(openssl x509 -in cert.pem -noout -serial | cut -d= -f2)
echo "Serial: $SERIAL"

# Search in database
grep "$SERIAL" /root/ca/intermediate/index.txt

# If not found, certificate không được issue bởi CA này
```

### 7.4. OCSP Stapling không hoạt động

**Check Nginx logs:**

```bash
# Enable debug logging
error_log /var/log/nginx/error.log debug;

# Restart Nginx
sudo systemctl restart nginx

# Check logs
tail -f /var/log/nginx/error.log | grep -i ocsp
```

**Common issues:**

1. **OCSP URL không accessible từ server:**
   ```bash
   # Test từ server
   curl -I http://ocsp.example.com:8888
   ```

2. **Resolver không được config:**
   ```nginx
   # Add DNS resolver
   resolver 8.8.8.8 8.8.4.4 valid=300s;
   resolver_timeout 5s;
   ```

3. **Certificate không có AIA extension:**
   ```bash
   # Check AIA
   openssl x509 -in cert.pem -noout -text | grep -A 2 "Authority Information Access"
   ```

### 7.5. Performance Issues

**OCSP responder chậm:**

```bash
# Check system load
top
htop

# Check OCSP process
ps aux | grep ocsp

# Monitor OCSP queries
tail -f /var/log/ocsp-responder.log
```

**Solutions:**
- Enable caching trên reverse proxy (Nginx/Varnish)
- Scale horizontal: Thêm OCSP responder instances
- Optimize database: Index index.txt nếu dùng custom database

## Tổng kết

✅ Bạn đã học:
- OCSP protocol và cách hoạt động
- Sự khác biệt giữa CRL và OCSP
- Cách setup OCSP responder từ đầu
- OCSP Stapling để tăng performance và privacy
- Production deployment với HA và monitoring
- Troubleshooting các lỗi thường gặp

**Next Steps:**
- [Best Practices](04-best-practices.md) - Security best practices
- [Troubleshooting](05-troubleshooting.md) - Xử lý sự cố
