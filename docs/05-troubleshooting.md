# Troubleshooting - Xử lý Sự cố

## Mục lục

- [1. Lỗi khi Setup CA](#1-lỗi-khi-setup-ca)
- [2. Lỗi Certificate Signing](#2-lỗi-certificate-signing)
- [3. Lỗi Verification](#3-lỗi-verification)
- [4. Lỗi Revocation](#4-lỗi-revocation)
- [5. Lỗi OCSP/CRL](#5-lỗi-ocspcrl)
- [6. Các vấn đề khác](#6-các-vấn-đề-khác)

## 1. Lỗi khi Setup CA

### 1.1. "unable to load CA private key"

**Triệu chứng:**
```
unable to load CA private key
140234567890:error:0906A068:PEM routines:PEM_do_header:bad password read
```

**Nguyên nhân:**
- Sai passphrase
- File key không tồn tại
- File key bị corrupt
- Sai permissions

**Giải pháp:**

```bash
# 1. Kiểm tra file tồn tại
ls -la /root/ca/rootca/private/ca.key.pem

# 2. Kiểm tra permissions
chmod 400 /root/ca/rootca/private/ca.key.pem

# 3. Test key
openssl rsa -in /root/ca/rootca/private/ca.key.pem -check
# Nhập đúng passphrase

# 4. Nếu quên passphrase, cần restore từ backup
# hoặc tạo lại Root CA (cực kỳ không khuyến khích!)

# 5. Kiểm tra key có encrypted không
openssl rsa -in ca.key.pem -text -noout
# Nếu yêu cầu passphrase → encrypted
# Nếu không → unencrypted (không an toàn!)
```

### 1.2. "TXT_DB error number 2"

**Triệu chứng:**
```
failed to update database
TXT_DB error number 2
```

**Nguyên nhân:**
- Duplicate certificate (cùng Subject DN)
- OpenSSL không cho phép cùng Subject trong database

**Giải pháp:**

```bash
# Option 1: Allow duplicate subjects
# Edit openssl.cnf, thêm vào [CA_default]:
unique_subject = no

# Option 2: Revoke certificate cũ trước
openssl ca -config intermediate/openssl.cnf \
    -revoke intermediate/certs/old-cert.pem

# Option 3: Xóa entry trong database (NGUY HIỂM!)
# Backup first!
cp intermediate/index.txt intermediate/index.txt.backup

# Manually edit index.txt và xóa dòng duplicate
nano intermediate/index.txt

# Option 4: Sử dụng SAN thay vì tạo multiple certs
```

### 1.3. "serial number XXXX is already in use"

**Triệu chứng:**
```
The certificate with serial number XXXX has already been issued
```

**Nguyên nhân:**
- Serial number bị trùng

**Giải pháp:**

```bash
# Kiểm tra serial number hiện tại
cat /root/ca/intermediate/serial

# Kiểm tra database
cat /root/ca/intermediate/index.txt | grep "XXXX"

# Increment serial number
# Nếu current = 1005, set = 1006
echo "1006" > /root/ca/intermediate/serial

# Hoặc để OpenSSL tự động increment
# Đảm bảo file serial tồn tại và readable
chmod 644 /root/ca/intermediate/serial
```

### 1.4. "No such file or directory"

**Triệu chứng:**
```bash
Can't open /root/ca/intermediate/index.txt for reading, No such file or directory
```

**Nguyên nhân:**
- Chưa tạo đủ cấu trúc thư mục

**Giải pháp:**

```bash
# Tạo lại cấu trúc
cd /root/ca

# Root CA
mkdir -p rootca/{certs,crl,newcerts,private}
chmod 700 rootca/private
touch rootca/index.txt
echo 1000 > rootca/serial
echo 1000 > rootca/crlnumber

# Intermediate CA
mkdir -p intermediate/{certs,crl,csr,newcerts,private}
chmod 700 intermediate/private
touch intermediate/index.txt
echo 1000 > intermediate/serial
echo 1000 > intermediate/crlnumber

# Verify
ls -la rootca/
ls -la intermediate/
```

## 2. Lỗi Certificate Signing

### 2.1. "The organizationName field is different"

**Triệu chứng:**
```
The organizationName field is different between
CA certificate and the request
```

**Nguyên nhân:**
- Policy trong openssl.cnf yêu cầu match Organization
- CSR có Organization khác với CA

**Giải pháp:**

```bash
# Option 1: Sử dụng policy_loose
# Edit openssl.cnf, trong [CA_default]:
policy = policy_loose

# Option 2: Match Organization trong CSR
openssl req -new \
    -key server.key.pem \
    -out server.csr.pem \
    -subj "/C=VN/ST=Hanoi/O=Example Organization/CN=www.example.com"
#                        ^^ Same as CA ^^

# Option 3: Customize policy
# Edit [policy_strict] in openssl.cnf:
[ policy_custom ]
countryName             = optional
stateOrProvinceName     = optional
organizationName        = optional  # Changed from 'match'
commonName              = supplied
```

### 2.2. "Extension section server_cert not found"

**Triệu chứng:**
```
Error Loading extension section server_cert
```

**Nguyên nhân:**
- openssl.cnf không có section [server_cert]
- Sai tên extension

**Giải pháp:**

```bash
# 1. Kiểm tra openssl.cnf có section
grep "\[server_cert\]" intermediate/openssl.cnf

# 2. Nếu không có, thêm vào:
cat >> intermediate/openssl.cnf << 'EOF'

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EOF

# 3. Hoặc sử dụng extension có sẵn
openssl ca -config intermediate/openssl.cnf \
    -extensions usr_cert \  # Instead of server_cert
    -days 375 ...
```

### 2.3. "Certificate Request does not match Private Key"

**Triệu chứng:**
```
Certificate Request does not match Private Key
error:0B080074:x509 certificate routines:X509_check_private_key:key values mismatch
```

**Nguyên nhân:**
- CSR và private key không match

**Giải pháp:**

```bash
# Verify CSR and key match
# 1. Get modulus from CSR
openssl req -noout -modulus -in server.csr.pem | openssl md5

# 2. Get modulus from key
openssl rsa -noout -modulus -in server.key.pem | openssl md5

# 3. Compare - should be identical
# If different, regenerate CSR with correct key:
openssl req -new \
    -key server.key.pem \
    -out server.csr.pem \
    -subj "/CN=www.example.com"
```

## 3. Lỗi Verification

### 3.1. "unable to get local issuer certificate"

**Triệu chứng:**
```bash
error 20 at 0 depth lookup: unable to get local issuer certificate
```

**Nguyên nhân:**
- Thiếu CA certificate trong chain
- Sai CA file path

**Giải pháp:**

```bash
# 1. Verify với đúng CA chain
openssl verify \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    server.cert.pem

# 2. Kiểm tra chain file
openssl crl2pkcs7 -nocrl \
    -certfile intermediate/certs/ca-chain.cert.pem | \
    openssl pkcs7 -print_certs -noout

# Should show:
# subject=CN=Example Intermediate CA
# issuer=CN=Example Root CA
# subject=CN=Example Root CA
# issuer=CN=Example Root CA (self-signed)

# 3. Recreate chain if needed
cat intermediate/certs/intermediate.cert.pem \
    rootca/certs/ca.cert.pem > \
    intermediate/certs/ca-chain.cert.pem
```

### 3.2. "certificate has expired"

**Triệu chứng:**
```
error 10 at 0 depth lookup: certificate has expired
```

**Nguyên nhân:**
- Certificate đã hết hạn

**Giải pháp:**

```bash
# 1. Kiểm tra expiration
openssl x509 -in cert.pem -noout -enddate
# notAfter=Dec 31 23:59:59 2023 GMT

# 2. Check if expired
openssl x509 -in cert.pem -noout -checkend 0
# Certificate will expire (return 1) or not (return 0)

# 3. Renew certificate
# Generate new CSR and sign again

# 4. For testing, ignore expiration (NOT for production!)
openssl verify -no_check_time \
    -CAfile ca-chain.cert.pem cert.pem
```

### 3.3. "self signed certificate in certificate chain"

**Triệu chứng:**
```
error 19 at 1 depth lookup: self signed certificate in certificate chain
```

**Nguyên nhân:**
- Root CA (self-signed) không được trust

**Giải pháp:**

```bash
# Option 1: Add Root CA to trusted store
# Ubuntu/Debian:
sudo cp rootca/certs/ca.cert.pem /usr/local/share/ca-certificates/my-root-ca.crt
sudo update-ca-certificates

# CentOS/RHEL:
sudo cp rootca/certs/ca.cert.pem /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# macOS:
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain \
    rootca/certs/ca.cert.pem

# Option 2: Verify with -CAfile
openssl verify -CAfile rootca/certs/ca.cert.pem \
    -untrusted intermediate/certs/intermediate.cert.pem \
    server.cert.pem

# Option 3: For testing, allow untrusted
openssl s_client -connect localhost:443 -CAfile ca-chain.cert.pem
```

## 4. Lỗi Revocation

### 4.1. "unable to load certificate"

**Triệu chứng khi revoke:**
```
unable to load certificate
error:0909006C:PEM routines:get_name:no start line
```

**Nguyên nhân:**
- Sai format certificate (DER vs PEM)
- File không phải certificate

**Giải pháp:**

```bash
# 1. Kiểm tra format
file server.cert.pem
# Should say: PEM certificate

# 2. View certificate
openssl x509 -in server.cert.pem -noout -text

# 3. Convert DER to PEM nếu cần
openssl x509 -inform DER -in cert.der \
    -outform PEM -out cert.pem

# 4. Revoke với đúng file
openssl ca -config intermediate/openssl.cnf \
    -revoke intermediate/certs/server.cert.pem
```

### 4.2. "ERROR:Already revoked"

**Triệu chứng:**
```
ERROR:Already revoked, serial number XXXX
```

**Nguyên nhân:**
- Certificate đã bị revoke trước đó

**Giải pháp:**

```bash
# 1. Kiểm tra trong database
cat intermediate/index.txt | grep "XXXX"
# R = Revoked
# V = Valid

# 2. View revocation details
openssl ca -config intermediate/openssl.cnf \
    -status XXXX

# 3. Nếu cần revoke lại với lý do khác,
# edit index.txt (NGUY HIỂM - backup first!)
```

## 5. Lỗi OCSP/CRL

### 5.1. CRL "signature failure"

**Triệu chứng:**
```
error:04091068:rsa routines:int_rsa_verify:bad signature
```

**Nguyên nhân:**
- CRL bị corrupt
- CRL signed bởi wrong CA

**Giải pháp:**

```bash
# 1. Verify CRL
openssl crl -in intermediate/crl/intermediate.crl.pem \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -noout

# 2. Regenerate CRL
openssl ca -config intermediate/openssl.cnf \
    -gencrl -out intermediate/crl/intermediate.crl.pem

# 3. Verify again
openssl verify -crl_check \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -CRLfile intermediate/crl/intermediate.crl.pem \
    server.cert.pem
```

### 5.2. OCSP "unauthorized"

**Triệu chứng:**
```
Response Verify Failure
140234567890:error:27069065:OCSP routines:OCSP_basic_verify:certificate verify error
```

**Nguyên nhân:**
- OCSP signing certificate không valid
- OCSP responder sai config

**Giải pháp:**

```bash
# 1. Verify OCSP certificate
openssl verify -CAfile intermediate/certs/ca-chain.cert.pem \
    intermediate/certs/ocsp.cert.pem

# 2. Check OCSP certificate extensions
openssl x509 -in intermediate/certs/ocsp.cert.pem -noout -text | \
    grep -A 1 "Extended Key Usage"
# Should have: OCSP Signing

# 3. Regenerate OCSP cert if needed
# See docs/03-certificate-management.md section 6.1

# 4. Test OCSP
openssl ocsp \
    -CAfile intermediate/certs/ca-chain.cert.pem \
    -issuer intermediate/certs/intermediate.cert.pem \
    -cert server.cert.pem \
    -url http://localhost:8888 \
    -resp_text
```

### 5.3. "CRL has expired"

**Triệu chứng:**
```
error 12 at 0 depth lookup: CRL has expired
```

**Nguyên nhân:**
- CRL quá hạn (nextUpdate đã qua)

**Giải pháp:**

```bash
# 1. Check CRL expiration
openssl crl -in intermediate/crl/intermediate.crl.pem \
    -noout -nextupdate
# Next Update: Jan 15 00:00:00 2024 GMT

# 2. Regenerate CRL
openssl ca -config intermediate/openssl.cnf \
    -gencrl -out intermediate/crl/intermediate.crl.pem

# 3. Automate CRL updates
# Add to crontab:
# 0 2 * * * openssl ca -config /root/ca/intermediate/openssl.cnf -gencrl -out /root/ca/intermediate/crl/intermediate.crl.pem

# 4. Adjust CRL validity in openssl.cnf
# [CA_default]
# default_crl_days = 30  # Increase if needed
```

## 6. Các vấn đề khác

### 6.1. Browser "Your connection is not private"

**Triệu chứng:**
- Chrome: NET::ERR_CERT_AUTHORITY_INVALID
- Firefox: SEC_ERROR_UNKNOWN_ISSUER

**Nguyên nhân:**
- Browser không trust Root CA

**Giải pháp:**

```bash
# Chrome (Windows):
# 1. Settings → Privacy and security → Security → Manage certificates
# 2. Trusted Root Certification Authorities → Import
# 3. Import rootca/certs/ca.cert.pem

# Firefox:
# 1. Settings → Privacy & Security → Certificates → View Certificates
# 2. Authorities → Import
# 3. Import rootca/certs/ca.cert.pem
# 4. Trust for websites

# macOS:
# 1. Double-click ca.cert.pem
# 2. Keychain Access → System → Certificates
# 3. Double-click certificate → Trust → Always Trust

# Linux:
sudo cp rootca/certs/ca.cert.pem /usr/local/share/ca-certificates/my-ca.crt
sudo update-ca-certificates

# Verify
openssl s_client -connect localhost:443 -CAfile rootca/certs/ca.cert.pem
```

### 6.2. "routines::no start line"

**Triệu chứng:**
```
error:0900006e:PEM routines:PEM_read_bio:no start line
```

**Nguyên nhân:**
- File không phải PEM format
- File empty hoặc corrupt

**Giải pháp:**

```bash
# 1. Check file content
cat cert.pem
# Should start with: -----BEGIN CERTIFICATE-----

# 2. Check file size
ls -lh cert.pem

# 3. Verify format
file cert.pem

# 4. If DER format, convert
openssl x509 -inform DER -in cert.der \
    -outform PEM -out cert.pem

# 5. If corrupt, regenerate from backup
```

### 6.3. Permission Denied

**Triệu chứng:**
```bash
Permission denied: /root/ca/intermediate/private/ca.key.pem
```

**Giải pháp:**

```bash
# 1. Fix ownership
sudo chown -R root:root /root/ca

# 2. Fix permissions
sudo chmod 700 /root/ca/*/private
sudo chmod 400 /root/ca/*/private/*.pem
sudo chmod 755 /root/ca/*/certs
sudo chmod 644 /root/ca/*/certs/*.pem

# 3. Run as root
sudo su
cd /root/ca
./scripts/issue-certificate.sh ...

# 4. Or use sudo
sudo ./scripts/issue-certificate.sh ...
```

### 6.4. "Could not load PEM client certificate"

**Triệu chứng (với curl):**
```
curl: (58) could not load PEM client certificate
```

**Nguyên nhân:**
- Cert và key không trong đúng format
- Missing intermediate certificates

**Giải pháp:**

```bash
# 1. Create proper bundle
cat client.cert.pem client.key.pem > client.pem

# 2. Test with curl
curl --cert client.pem \
     --cacert ca-chain.cert.pem \
     https://example.com

# 3. Or use separate files
curl --cert client.cert.pem \
     --key client.key.pem \
     --cacert ca-chain.cert.pem \
     https://example.com

# 4. For PKCS#12
openssl pkcs12 -export \
    -in client.cert.pem \
    -inkey client.key.pem \
    -out client.p12

curl --cert-type P12 --cert client.p12 \
     https://example.com
```

## Debug Tools

### General Debug Commands

```bash
# Verbose OpenSSL output
openssl ... -text -noout

# Test SSL/TLS connection
openssl s_client -connect host:port -showcerts -debug

# Check certificate chain
openssl s_client -connect host:port -showcerts | \
    openssl x509 -text -noout

# Verify certificate
openssl verify -verbose -CAfile ca.pem cert.pem

# Debug configuration
openssl ca -config openssl.cnf -verbose ...
```

### Logging

```bash
# Enable OpenSSL debug
export OPENSSL_CONF=/root/ca/intermediate/openssl.cnf
openssl ... 2>&1 | tee debug.log

# Check system logs
journalctl -u nginx  # for nginx
tail -f /var/log/syslog
tail -f /var/log/messages
```

## Getting Help

Nếu vẫn gặp vấn đề:

1. **Check logs**: `/var/log/`, application logs
2. **OpenSSL docs**: `man openssl-ca`, `man openssl-req`
3. **Search error message**: Google, StackOverflow
4. **GitHub Issues**: [Create issue](https://github.com/yourusername/ca-implementation/issues)
5. **Community**: OpenSSL mailing list, r/netsec

**Khi báo lỗi, cung cấp:**
- Full error message
- OpenSSL version: `openssl version -a`
- OS: `uname -a`
- Config file (remove sensitive data)
- Steps to reproduce

## Preventive Measures

```bash
# 1. Regular backups
./scripts/backup-ca.sh

# 2. Monitor certificate expiration
./scripts/check-expiring-certs.sh

# 3. Test recovery procedures
./scripts/test-recovery.sh

# 4. Keep system updated
sudo apt update && sudo apt upgrade

# 5. Audit logs regularly
grep ERROR /var/log/ca/*.log

# 6. Test before production
# Always test in dev environment first!
```

---

**Remember**: Khi gặp lỗi, đừng panic! Đọc error message kỹ, search documentation, và test từng bước.
