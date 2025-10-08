# Quick Start Guide - CA Implementation

Hướng dẫn nhanh setup CA và tạo HTTPS server với domain `example.pki` trên localhost.

## Bước 1: Cấu hình Hosts File

Thêm domain `example.pki` trỏ về 127.0.0.1:

### macOS/Linux

```bash
sudo nano /etc/hosts
```

Thêm dòng sau:

```
127.0.0.1    example.pki
```

Lưu file (Ctrl+O, Enter, Ctrl+X)

### Windows

```powershell
# Mở Notepad với quyền Administrator
notepad C:\Windows\System32\drivers\etc\hosts
```

Thêm dòng:

```
127.0.0.1    example.pki
```

Verify:

```bash
ping example.pki
# Should respond from 127.0.0.1
```

## Bước 2: Setup Certificate Authority

```bash
cd ca-implementation/scripts
chmod +x *.sh
sudo ./setup-ca.sh
```

Script sẽ hỏi thông tin:

- **Country**: VN
- **State**: Hanoi
- **Organization**: WorkDat PKI
- **Root CA Passphrase**: Nhập passphrase mạnh cho Root CA (nhớ lưu lại!)
- **Intermediate CA Passphrase**: Nhập passphrase mạnh cho Intermediate CA (nhớ lưu lại!)

**⚠️ Lưu ý quan trọng:**

- Script sẽ yêu cầu bạn nhập passphrase **2 lần** để xác nhận
- **KHÔNG** được để trống passphrase (nhấn Enter)
- Passphrase phải có **ít nhất 4 ký tự**
- **NÊN LƯU** passphrase ở nơi an toàn - bạn sẽ cần nó để ký certificates sau này! **Abc@123**

Output:

```
✓ Root CA created
✓ Intermediate CA created
✓ Certificate chain verified
```

## Bước 3: Cấp Certificate cho example.pki

```bash
sudo ./issue-certificate.sh server example.pki
```

Certificate được tạo tại:

- Private key: `/root/ca/intermediate/private/example.pki.key.pem`
- Certificate: `/root/ca/intermediate/certs/example.pki.cert.pem`
- Bundle: `/root/ca/intermediate/certs/example.pki.bundle.pem`

## Bước 4: Setup Python HTTPS Server

### Tạo Python HTTPS Server Script

```bash
cd ../examples/web-server
```

Tạo file `https-server.py`:

```python
#!/usr/bin/env python3
import http.server
import ssl
import os

# Configuration
HOST = '0.0.0.0'
PORT = 443
CERT_FILE = '/root/ca/intermediate/certs/example.pki.bundle.pem'  # Bundle includes chain
KEY_FILE = '/root/ca/intermediate/private/example.pki.key.pem'

# Create HTTP handler
handler = http.server.SimpleHTTPRequestHandler

# Create HTTPS server
httpd = http.server.HTTPServer((HOST, PORT), handler)

# Setup SSL context
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(CERT_FILE, KEY_FILE)

# Wrap socket with SSL
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

print(f"🚀 HTTPS Server running on https://example.pki:{PORT}")
print(f"📁 Serving files from: {os.getcwd()}")
print(f"🔒 Certificate: {CERT_FILE}")
print("\nPress Ctrl+C to stop server")

try:
    httpd.serve_forever()
except KeyboardInterrupt:
    print("\n\n✓ Server stopped")
    httpd.shutdown()
```

Tạo file `index.html` demo:

```html
<!DOCTYPE html>
<html lang="vi">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>WorkDat PKI - HTTPS Demo</title>
    <style>
      body {
        font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
        max-width: 800px;
        margin: 50px auto;
        padding: 20px;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
      }
      .container {
        background: rgba(255, 255, 255, 0.1);
        padding: 40px;
        border-radius: 10px;
        backdrop-filter: blur(10px);
      }
      h1 {
        margin-top: 0;
      }
      .status {
        background: rgba(76, 175, 80, 0.3);
        padding: 15px;
        border-radius: 5px;
        margin: 20px 0;
      }
      code {
        background: rgba(0, 0, 0, 0.3);
        padding: 2px 6px;
        border-radius: 3px;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>🔒 WorkDat PKI - HTTPS Server</h1>
      <div class="status">
        <strong>✓ HTTPS Connection Established!</strong>
      </div>
      <p>Chào mừng đến với CA Implementation demo.</p>
      <h2>Thông tin kết nối:</h2>
      <ul>
        <li><strong>Domain:</strong> <code>example.pki</code></li>
        <li><strong>Protocol:</strong> HTTPS (TLS)</li>
        <li><strong>Port:</strong> 443</li>
        <li><strong>Certificate Authority:</strong> WorkDat Root CA</li>
      </ul>
      <h2>Certificate Details:</h2>
      <p>
        Click vào biểu tượng khóa 🔒 trên thanh địa chỉ để xem thông tin
        certificate.
      </p>
    </div>
  </body>
</html>
```

### Chạy HTTPS Server

```bash
sudo chmod +x https-server.py
sudo python3 https-server.py
```

## Bước 5: Trust Root CA Certificate

### Copy Root CA Certificate ra nơi truy cập được

```bash
# Copy ra thư mục home để browser có thể import
sudo cp /root/ca/rootca/certs/ca.cert.pem ~/workdat-root-ca.crt
sudo chown $USER:$USER ~/workdat-root-ca.crt
chmod 644 ~/workdat-root-ca.crt
```

### macOS

```bash
sudo security add-trusted-cert \
    -d -r trustRoot \
    -k /Library/Keychains/System.keychain \
    ~/workdat-root-ca.crt
```

### Ubuntu/Linux

```bash
sudo cp ~/workdat-root-ca.crt \
    /usr/local/share/ca-certificates/workdat-ca.crt
sudo update-ca-certificates
```

### Browser (Chrome/Edge)

1. Settings → Privacy and security → Security
2. Manage certificates → Authorities
3. Import → Browse to `~/workdat-root-ca.crt` (trong thư mục home của bạn)
4. ✓ Check "Trust this certificate for identifying websites"

### Browser (Firefox)

1. Settings → Privacy & Security → Certificates
2. View Certificates → Authorities → Import
3. Browse to `~/workdat-root-ca.crt` (trong thư mục home của bạn)
4. ✓ Trust for websites

## Bước 6: Truy cập Website

Mở browser và truy cập:

```
https://example.pki
```

✓ Bạn sẽ thấy:

- 🔒 Biểu tượng khóa màu xanh (Secure connection)
- Website hiển thị nội dung HTML
- Certificate valid từ WorkDat Root CA

## Testing với cURL

```bash
# Test với CA certificate
curl --cacert ~/workdat-root-ca.crt https://example.pki

# Hoặc test mà không verify (development only)
curl -k https://example.pki
```

## Xem Thông tin Certificate

```bash
# View certificate details
openssl s_client -connect example.pki:443 -showcerts

# Check certificate dates
openssl x509 -in /root/ca/intermediate/certs/example.pki.cert.pem \
    -noout -dates -subject -issuer
```

## Cấu trúc Thư mục

```
/root/ca/
├── rootca/
│   ├── certs/ca.cert.pem          # Root CA certificate (import vào browser)
│   ├── private/ca.key.pem         # Root CA private key ⚠️ BẢO MẬT!
│   └── openssl.cnf
└── intermediate/
    ├── certs/
    │   ├── intermediate.cert.pem  # Intermediate CA
    │   ├── ca-chain.cert.pem      # Certificate chain
    │   └── example.pki.cert.pem   # Server certificate
    ├── private/
    │   └── example.pki.key.pem    # Server private key ⚠️ BẢO MẬT!
    └── openssl.cnf
```

## Troubleshooting

### Port 443 đã được sử dụng

```bash
# Check port
sudo lsof -i :443

# Kill process nếu cần
sudo kill -9 <PID>
```

### Permission denied khi chạy port 443

```bash
# Phải dùng sudo vì port < 1024
sudo python3 https-server.py
```

### Browser vẫn báo "Not Secure"

1. Clear browser cache và SSL state
2. Verify đã import Root CA certificate đúng cách
3. Restart browser
4. Check certificate:
   ```bash
   openssl verify -CAfile /root/ca/intermediate/certs/ca-chain.cert.pem \
       /root/ca/intermediate/certs/example.pki.cert.pem
   ```

### "unable to get local issuer certificate"

```bash
# Verify CA chain
cat /root/ca/intermediate/certs/example.pki.cert.pem \
    /root/ca/intermediate/certs/intermediate.cert.pem \
    > /root/ca/intermediate/certs/example.pki.bundle.pem

# Use bundle in server
```

## Advanced: Tạo Certificate cho nhiều domains

```bash
# Certificate với Subject Alternative Names (SAN)
sudo ./issue-certificate.sh server example.pki \
    "DNS:example.pki,DNS:www.example.pki,DNS:api.example.pki,IP:127.0.0.1"
```

Cập nhật `/etc/hosts`:

```
127.0.0.1    example.pki www.example.pki api.example.pki
```

## Security Reminders ⚠️

- **NEVER** share private keys (`*.key.pem`)
- **BACKUP** Root CA key ở nơi an toàn, offline
- **STRONG** passphrase cho private keys
- **ROTATE** certificates trước khi hết hạn
- Đây là môi trường **LEARNING** - không dùng cho production!

## Next Steps

- [Quản lý Certificate Lifecycle](docs/03-certificate-management.md)
- [Revoke Certificates](docs/03-certificate-management.md#revocation)
- [Setup OCSP](docs/03-certificate-management.md#ocsp)
- [Best Practices](docs/04-best-practices.md)

---

**Congratulations! 🎉** Bạn đã setup thành công CA và HTTPS server với domain tùy chỉnh!
