# Cài đặt và Cấu hình CA

## Mục lục

- [1. Chuẩn bị môi trường](#1-chuẩn-bị-môi-trường)
- [2. Thiết lập Root CA](#2-thiết-lập-root-ca)
- [3. Thiết lập Intermediate CA](#3-thiết-lập-intermediate-ca)
- [4. Xác minh cài đặt](#4-xác-minh-cài-đặt)

## 1. Chuẩn bị môi trường

### 1.1. Kiểm tra OpenSSL

```bash
# Kiểm tra version
openssl version
# Output: OpenSSL 1.1.1 hoặc cao hơn

# Kiểm tra cấu hình
openssl version -a
```

### 1.2. Cài đặt OpenSSL (nếu cần)

#### Ubuntu/Debian

```bash
sudo apt update
sudo apt install openssl
```

#### macOS

```bash
# Sử dụng Homebrew
brew install openssl@3

# Add to PATH
echo 'export PATH="/usr/local/opt/openssl@3/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### CentOS/RHEL

```bash
sudo yum install openssl
```

### 1.3. Tạo cấu trúc thư mục

```bash
# Tạo root directory
sudo mkdir -p /root/ca
cd /root/ca

# Tạo cấu trúc cho Root CA
mkdir -p rootca/{certs,crl,newcerts,private}
chmod 700 rootca/private
touch rootca/index.txt
echo 1000 > rootca/serial
echo 1000 > rootca/crlnumber

# Tạo cấu trúc cho Intermediate CA
mkdir -p intermediate/{certs,crl,csr,newcerts,private}
chmod 700 intermediate/private
touch intermediate/index.txt
echo 1000 > intermediate/serial
echo 1000 > intermediate/crlnumber
```

Cấu trúc thư mục sau khi tạo:

```
/root/ca/
├── rootca/
│   ├── certs/          # Chứa certificates
│   ├── crl/            # Chứa CRLs
│   ├── newcerts/       # Certificates mới cấp
│   ├── private/        # Private keys (700 permission)
│   ├── index.txt       # Certificate database
│   ├── serial          # Certificate serial number counter
│   └── crlnumber       # CRL number counter
└── intermediate/
    ├── certs/
    ├── crl/
    ├── csr/            # Certificate Signing Requests
    ├── newcerts/
    ├── private/
    ├── index.txt
    ├── serial
    └── crlnumber
```

## 2. Thiết lập Root CA

### 2.1. Tạo Root CA configuration file

Tạo file `/root/ca/rootca/openssl.cnf`:

```ini
# OpenSSL Root CA configuration file

[ ca ]
default_ca = CA_default

[ CA_default ]
# Directory and file locations
dir               = /root/ca/rootca
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

# Root CA certificate and key
private_key       = $dir/private/ca.key.pem
certificate       = $dir/certs/ca.cert.pem

# CRL settings
crlnumber         = $dir/crlnumber
crl               = $dir/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-256 for signing
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_strict

[ policy_strict ]
# Root CA chỉ ký Intermediate CA
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
# Cho phép linh hoạt hơn với end-entity certificates
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Default values
countryName_default             = VN
stateOrProvinceName_default     = Hanoi
localityName_default            = Hanoi
0.organizationName_default      = Example Organization
organizationalUnitName_default  = Example Organization Root CA
emailAddress_default            = ca@example.com

[ v3_ca ]
# Extensions for Root CA certificate
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions for Intermediate CA certificate
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ crl_ext ]
# CRL extensions
authorityKeyIdentifier=keyid:always

[ ocsp ]
# OCSP extensions
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
```

### 2.2. Tạo Root CA private key

```bash
cd /root/ca

# Tạo 4096-bit RSA key với AES-256 encryption
openssl genrsa -aes256 -out rootca/private/ca.key.pem 4096

# Set permissions
chmod 400 rootca/private/ca.key.pem
```

**Quan trọng**:
- Sử dụng passphrase mạnh (ít nhất 20 ký tự)
- Lưu passphrase an toàn (password manager, vault)
- Backup private key ở nơi an toàn offline

### 2.3. Tạo Root CA certificate

```bash
# Tạo self-signed certificate (validity: 20 years)
openssl req -config rootca/openssl.cnf \
      -key rootca/private/ca.key.pem \
      -new -x509 -days 7300 -sha256 \
      -extensions v3_ca \
      -out rootca/certs/ca.cert.pem

# Nhập thông tin:
# Country Name: VN
# State: Hanoi
# Locality: Hanoi
# Organization: Example Organization
# Organizational Unit: Example Organization Root CA
# Common Name: Example Root CA
# Email: ca@example.com

# Set permissions
chmod 444 rootca/certs/ca.cert.pem
```

### 2.4. Xác minh Root CA certificate

```bash
# Xem chi tiết certificate
openssl x509 -noout -text -in rootca/certs/ca.cert.pem

# Kiểm tra các thông tin quan trọng:
# - Validity: Not Before và Not After
# - Subject: CN=Example Root CA
# - Issuer: CN=Example Root CA (self-signed)
# - Public-Key: (4096 bit)
# - Signature Algorithm: sha256WithRSAEncryption
# - X509v3 Basic Constraints: CA:TRUE
# - X509v3 Key Usage: Digital Signature, Certificate Sign, CRL Sign
```

Output mẫu:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            3a:15:8c:45:b4:21:8f:...
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = VN, ST = Hanoi, L = Hanoi, O = Example Organization,
                OU = Example Organization Root CA, CN = Example Root CA
        Validity
            Not Before: Jan  1 00:00:00 2024 GMT
            Not After : Dec 31 23:59:59 2043 GMT
        Subject: C = VN, ST = Hanoi, L = Hanoi, O = Example Organization,
                 OU = Example Organization Root CA, CN = Example Root CA
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (4096 bit)
                Modulus:
                    00:c4:a1:...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Key Identifier:
                A7:3B:...
            X509v3 Authority Key Identifier:
                keyid:A7:3B:...

            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Key Usage: critical
                Digital Signature, Certificate Sign, CRL Sign
```

## 3. Thiết lập Intermediate CA

### 3.1. Tạo Intermediate CA configuration file

Tạo file `/root/ca/intermediate/openssl.cnf`:

```ini
# OpenSSL Intermediate CA configuration file

[ ca ]
default_ca = CA_default

[ CA_default ]
# Directory and file locations
dir               = /root/ca/intermediate
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

# Intermediate CA certificate and key
private_key       = $dir/private/intermediate.key.pem
certificate       = $dir/certs/intermediate.cert.pem

# CRL settings
crlnumber         = $dir/crlnumber
crl               = $dir/crl/intermediate.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-256 for signing
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_loose

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

countryName_default             = VN
stateOrProvinceName_default     = Hanoi
localityName_default            = Hanoi
0.organizationName_default      = Example Organization
organizationalUnitName_default  = Example Organization Intermediate CA
emailAddress_default            = ca@example.com

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
crlDistributionPoints = URI:http://crl.example.com/root.crl
authorityInfoAccess = caIssuers;URI:http://aia.example.com/root.crt

[ server_cert ]
# Extensions for server certificates
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
crlDistributionPoints = URI:http://crl.example.com/intermediate.crl
authorityInfoAccess = caIssuers;URI:http://aia.example.com/intermediate.crt,OCSP;URI:http://ocsp.example.com

[ client_cert ]
# Extensions for client certificates
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
crlDistributionPoints = URI:http://crl.example.com/intermediate.crl
authorityInfoAccess = caIssuers;URI:http://aia.example.com/intermediate.crt,OCSP;URI:http://ocsp.example.com

[ crl_ext ]
authorityKeyIdentifier=keyid:always

[ ocsp ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
```

### 3.2. Tạo Intermediate CA private key

```bash
cd /root/ca

# Tạo 4096-bit RSA key
openssl genrsa -aes256 \
      -out intermediate/private/intermediate.key.pem 4096

# Set permissions
chmod 400 intermediate/private/intermediate.key.pem
```

### 3.3. Tạo Intermediate CA CSR

```bash
# Tạo Certificate Signing Request
openssl req -config intermediate/openssl.cnf \
      -new -sha256 \
      -key intermediate/private/intermediate.key.pem \
      -out intermediate/csr/intermediate.csr.pem

# Nhập thông tin:
# Common Name: Example Intermediate CA
# (các trường khác giống Root CA)
```

### 3.4. Root CA ký Intermediate CA certificate

```bash
# Root CA signs Intermediate CA certificate (validity: 10 years)
openssl ca -config rootca/openssl.cnf \
      -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in intermediate/csr/intermediate.csr.pem \
      -out intermediate/certs/intermediate.cert.pem

# Nhập passphrase của Root CA
# Confirm: y

# Set permissions
chmod 444 intermediate/certs/intermediate.cert.pem
```

### 3.5. Xác minh Intermediate CA certificate

```bash
# Xem chi tiết certificate
openssl x509 -noout -text \
      -in intermediate/certs/intermediate.cert.pem

# Kiểm tra:
# - Subject: CN=Example Intermediate CA
# - Issuer: CN=Example Root CA (signed by Root CA)
# - X509v3 Basic Constraints: CA:TRUE, pathlen:0
```

### 3.6. Verify certificate chain

```bash
# Verify chain: Root CA -> Intermediate CA
openssl verify -CAfile rootca/certs/ca.cert.pem \
      intermediate/certs/intermediate.cert.pem

# Output: intermediate.cert.pem: OK
```

### 3.7. Tạo certificate chain file

```bash
# Tạo chain file cho deployment
cat intermediate/certs/intermediate.cert.pem \
      rootca/certs/ca.cert.pem > \
      intermediate/certs/ca-chain.cert.pem

chmod 444 intermediate/certs/ca-chain.cert.pem
```

Certificate chain được dùng khi deploy server certificate để client có thể verify toàn bộ chain.

## 4. Xác minh cài đặt

### 4.1. Kiểm tra cấu trúc thư mục

```bash
# Kiểm tra permissions
ls -la /root/ca/rootca/private/
# Output: drwx------ (700) và -r-------- (400) cho key files

ls -la /root/ca/intermediate/private/
# Output: drwx------ (700) và -r-------- (400) cho key files
```

### 4.2. Kiểm tra certificates

```bash
# Root CA certificate
openssl x509 -noout -subject -issuer \
      -in rootca/certs/ca.cert.pem
# subject=C = VN, ... CN = Example Root CA
# issuer=C = VN, ... CN = Example Root CA (self-signed)

# Intermediate CA certificate
openssl x509 -noout -subject -issuer \
      -in intermediate/certs/intermediate.cert.pem
# subject=C = VN, ... CN = Example Intermediate CA
# issuer=C = VN, ... CN = Example Root CA
```

### 4.3. Kiểm tra database files

```bash
# Root CA database
cat /root/ca/rootca/index.txt
# Output: Danh sách certificates đã cấp (bao gồm Intermediate CA)

# Check serial numbers
cat /root/ca/rootca/serial
# Output: 1001 (hoặc số tiếp theo)

cat /root/ca/intermediate/serial
# Output: 1000 (chưa cấp certificate nào)
```

### 4.4. Test cấp certificate đầu tiên

Để test, tạo một server certificate:

```bash
cd /root/ca

# Tạo private key cho test
openssl genrsa -out intermediate/private/test.example.com.key.pem 2048

# Tạo CSR
openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/test.example.com.key.pem \
      -new -sha256 -out intermediate/csr/test.example.com.csr.pem \
      -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Example Organization/CN=test.example.com"

# Cấp certificate
openssl ca -config intermediate/openssl.cnf \
      -extensions server_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/test.example.com.csr.pem \
      -out intermediate/certs/test.example.com.cert.pem

# Verify chain
openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
      intermediate/certs/test.example.com.cert.pem
# Output: test.example.com.cert.pem: OK
```

Nếu output là "OK", cài đặt CA thành công!

### 4.5. Tạo CRL đầu tiên

```bash
# Root CA CRL
openssl ca -config rootca/openssl.cnf \
      -gencrl -out rootca/crl/ca.crl.pem

# Intermediate CA CRL
openssl ca -config intermediate/openssl.cnf \
      -gencrl -out intermediate/crl/intermediate.crl.pem

# Verify CRL
openssl crl -in intermediate/crl/intermediate.crl.pem -noout -text
```

## 5. Bảo mật và Backup

### 5.1. Backup Root CA

```bash
# Tạo encrypted backup
cd /root/ca
tar czf - rootca/ | \
  openssl enc -aes-256-cbc -salt -out rootca-backup-$(date +%Y%m%d).tar.gz.enc

# Lưu backup ở:
# - External encrypted drive
# - Offline storage
# - Safe deposit box
```

### 5.2. Root CA Offline

Sau khi setup xong:

1. **Shutdown Root CA system**
   ```bash
   # Copy Intermediate CA certificate để deploy
   # Sau đó shutdown Root CA
   sudo shutdown -h now
   ```

2. **Store Root CA securely**
   - Air-gapped machine
   - Physical security
   - Chỉ power on khi cần:
     - Ký Intermediate CA mới
     - Renew Intermediate CA
     - Thu hồi Intermediate CA
     - Generate CRL

### 5.3. Intermediate CA Security

```bash
# Setup firewall
sudo ufw enable
sudo ufw allow 22/tcp  # SSH only
sudo ufw allow 80/tcp  # HTTP for ACME challenge (optional)
sudo ufw allow 443/tcp # HTTPS for OCSP (optional)

# Setup fail2ban
sudo apt install fail2ban

# Regular backup
# Thêm vào crontab:
0 2 * * * /root/ca/scripts/backup-intermediate-ca.sh
```

### 5.4. Access Control

```bash
# Chỉ root user access
chown -R root:root /root/ca
chmod -R 750 /root/ca
chmod 700 /root/ca/*/private

# Audit logging
# Log all access to /root/ca
auditctl -w /root/ca -p wa -k ca_access
```

## 6. Troubleshooting

### 6.1. Lỗi "unable to load CA private key"

```bash
# Kiểm tra file tồn tại
ls -la rootca/private/ca.key.pem

# Kiểm tra permissions
chmod 400 rootca/private/ca.key.pem

# Test key
openssl rsa -in rootca/private/ca.key.pem -check
```

### 6.2. Lỗi "TXT_DB error number 2"

Duplicate certificate trong database:

```bash
# Xem database
cat rootca/index.txt

# Nếu cần, xóa dòng duplicate hoặc:
# Thêm vào [CA_default] section:
unique_subject = no
```

### 6.3. Serial number mismatch

```bash
# Reset serial nếu cần
echo 1000 > rootca/serial
echo 1000 > intermediate/serial
```

## Kết luận

Bạn đã hoàn thành:
- ✅ Cài đặt Root CA với 4096-bit key
- ✅ Tạo self-signed Root CA certificate (20 years)
- ✅ Cài đặt Intermediate CA
- ✅ Root CA ký Intermediate CA certificate (10 years)
- ✅ Verify certificate chain
- ✅ Setup bảo mật và backup

**Next steps**:
- [Certificate Management](03-certificate-management.md) - Cấp và quản lý certificates
- [Best Practices](04-best-practices.md) - Security best practices
