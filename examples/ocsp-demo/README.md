# OCSP Demo - Hands-on Example

Demo thực tế về cách sử dụng OCSP để kiểm tra trạng thái certificate.

## Mục tiêu

- Hiểu cách OCSP hoạt động
- Setup OCSP responder
- Test OCSP với certificate hợp lệ và bị thu hồi
- Tích hợp OCSP vào web server

## Prerequisites

```bash
# Đã setup CA
cd /root/ca/scripts
sudo ./setup-ca.sh  # Nếu chưa setup

# Đã tạo certificate
sudo ./issue-certificate.sh server example.pki
```

## Demo 1: Basic OCSP Query

### Bước 1: Setup OCSP Responder

```bash
cd /root/ca/scripts
sudo ./setup-ocsp.sh
```

### Bước 2: Start OCSP Responder

```bash
# Terminal 1: Start OCSP responder
sudo /root/ca/intermediate/ocsp-responder.sh
```

Output:
```
Starting OCSP responder on port 8888...
OCSP responder started (PID: 12345)
Log file: /var/log/ocsp-responder.log
```

### Bước 3: Test OCSP Query

```bash
# Terminal 2: Check certificate status
cd /root/ca/scripts
./check-ocsp.sh -f /root/ca/intermediate/certs/example.pki.cert.pem
```

**Expected output:**

```
═══════════════════════════════════════════════════════════════════
  Certificate Information
═══════════════════════════════════════════════════════════════════
Subject: C=VN, ST=Hanoi, O=Example Organization, CN=example.pki
Issuer: C=VN, ST=Hanoi, O=Example Organization, CN=Intermediate CA
Serial: 1000
Valid From: Dec 15 10:00:00 2024 GMT
Valid Until: Jan 17 10:00:00 2026 GMT
[✓] Certificate is not expired

═══════════════════════════════════════════════════════════════════
  OCSP Status Check
═══════════════════════════════════════════════════════════════════

[INFO] OCSP Responder: http://localhost:8888
[INFO] Checking certificate status...

[✓] OCSP response verified successfully
[✓] Certificate Status: GOOD ✓

[✓] Certificate is valid and not revoked
```

## Demo 2: OCSP với Revoked Certificate

### Bước 1: Tạo test certificate

```bash
cd /root/ca/scripts
sudo ./issue-certificate.sh server test-revoke.example.pki
```

### Bước 2: Verify certificate GOOD

```bash
./check-ocsp.sh -f /root/ca/intermediate/certs/test-revoke.example.pki.cert.pem
```

Output: `Certificate Status: GOOD ✓`

### Bước 3: Revoke certificate

```bash
sudo ./revoke-certificate.sh \
    /root/ca/intermediate/certs/test-revoke.example.pki.cert.pem \
    keyCompromise
```

**Output:**

```
[INFO] Revoking certificate: /root/ca/intermediate/certs/test-revoke.example.pki.cert.pem
[INFO] Revocation reason: keyCompromise
Using configuration from /root/ca/intermediate/openssl.cnf
Revoking Certificate 1001.
Data Base Updated
[SUCCESS] Certificate revoked successfully
[INFO] Generating updated CRL...
[SUCCESS] CRL updated: /root/ca/intermediate/crl/intermediate.crl.pem
```

### Bước 4: Check OCSP sau khi revoke

```bash
./check-ocsp.sh -f /root/ca/intermediate/certs/test-revoke.example.pki.cert.pem
```

**Expected output:**

```
[✓] OCSP response verified successfully
[✗] Certificate Status: REVOKED ✗

[✗] Revocation Reason: Key Compromise
[✗] Revocation Time: Dec 15 11:30:00 2024 GMT
```

Exit code: `1` (indicating certificate is revoked)

## Demo 3: OCSP Stapling với Nginx

### Bước 1: Create Nginx config

```bash
sudo nano /etc/nginx/sites-available/ocsp-demo
```

Content:

```nginx
server {
    listen 443 ssl http2;
    server_name example.pki;

    # SSL Certificates
    ssl_certificate /root/ca/intermediate/certs/example.pki.bundle.pem;
    ssl_certificate_key /root/ca/intermediate/private/example.pki.key.pem;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /root/ca/intermediate/certs/ca-chain.cert.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;

    location / {
        root /var/www/html;
        index index.html;

        # Display certificate info
        add_header X-Certificate-Subject $ssl_client_s_dn always;
        add_header X-Certificate-Serial $ssl_client_serial always;
    }

    # OCSP status endpoint
    location /ocsp-status {
        default_type text/plain;
        return 200 "OCSP Stapling: $ssl_stapled_ocsp_resp\n";
    }
}
```

### Bước 2: Enable site

```bash
sudo ln -s /etc/nginx/sites-available/ocsp-demo /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Bước 3: Test OCSP Stapling

```bash
# Test with OpenSSL
echo | openssl s_client -connect example.pki:443 -status -servername example.pki 2>&1 | grep -A 17 "OCSP Response"
```

**Expected output:**

```
OCSP Response Status: successful (0x0)
Response Type: Basic OCSP Response
Version: 1 (0x0)
Responder Id: C = VN, ST = Hanoi, O = Example Organization, CN = OCSP Responder
Produced At: Dec 15 11:45:00 2024 GMT
Responses:
Certificate ID:
  Hash Algorithm: sha256
  Issuer Name Hash: ...
  Issuer Key Hash: ...
  Serial Number: 1000
Cert Status: good
This Update: Dec 15 11:45:00 2024 GMT
Next Update: Dec 15 11:50:00 2024 GMT
```

### Bước 4: Test với browser

```bash
# Add to /etc/hosts (if not already)
echo "127.0.0.1 example.pki" | sudo tee -a /etc/hosts

# Open browser
xdg-open https://example.pki  # Linux
open https://example.pki      # macOS
```

Import Root CA vào browser (xem QUICKSTART.md) và truy cập `https://example.pki/ocsp-status`

## Demo 4: OCSP Health Monitoring

### Script giám sát OCSP

Tạo file `monitor-ocsp.sh`:

```bash
#!/bin/bash

OCSP_URL="http://localhost:8888"
TEST_CERT="/root/ca/intermediate/certs/example.pki.cert.pem"
CHECK_INTERVAL=60  # seconds

while true; do
    echo "[$(date)] Checking OCSP responder health..."

    if /root/ca/scripts/check-ocsp.sh -f "$TEST_CERT" -u "$OCSP_URL" > /dev/null 2>&1; then
        echo "[$(date)] ✓ OCSP responder is healthy"
    else
        echo "[$(date)] ✗ OCSP responder is DOWN - Sending alert!"
        # Send alert (email, Slack, etc.)
        # Example: curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
        #   -d '{"text":"OCSP Responder is DOWN!"}'
    fi

    sleep $CHECK_INTERVAL
done
```

Chạy monitor:

```bash
chmod +x monitor-ocsp.sh
nohup ./monitor-ocsp.sh > /var/log/ocsp-monitor.log 2>&1 &
```

## Demo 5: Python Client kiểm tra OCSP

Tạo file `ocsp_client.py`:

```python
#!/usr/bin/env python3
"""
Simple OCSP client using OpenSSL
"""

import subprocess
import sys
import json
from datetime import datetime

def check_ocsp(cert_file, issuer_file, ocsp_url, ca_chain):
    """Check certificate status via OCSP"""

    cmd = [
        'openssl', 'ocsp',
        '-CAfile', ca_chain,
        '-issuer', issuer_file,
        '-cert', cert_file,
        '-url', ocsp_url,
        '-resp_text'
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)

        # Parse output
        output = result.stdout + result.stderr

        status = {
            'timestamp': datetime.now().isoformat(),
            'cert_file': cert_file,
            'ocsp_url': ocsp_url,
            'response_verified': 'Response verify OK' in output
        }

        if ': good' in output:
            status['cert_status'] = 'GOOD'
            status['valid'] = True
        elif ': revoked' in output:
            status['cert_status'] = 'REVOKED'
            status['valid'] = False

            # Extract revocation reason
            for line in output.split('\n'):
                if 'Revocation Reason:' in line:
                    status['revocation_reason'] = line.split(':')[1].strip()
                if 'Revocation Time:' in line:
                    status['revocation_time'] = line.split('Time:')[1].strip()
        else:
            status['cert_status'] = 'UNKNOWN'
            status['valid'] = False

        return status

    except subprocess.TimeoutExpired:
        return {
            'timestamp': datetime.now().isoformat(),
            'cert_file': cert_file,
            'ocsp_url': ocsp_url,
            'error': 'OCSP request timeout'
        }
    except Exception as e:
        return {
            'timestamp': datetime.now().isoformat(),
            'cert_file': cert_file,
            'ocsp_url': ocsp_url,
            'error': str(e)
        }

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} <cert_file> <issuer_file> <ocsp_url> <ca_chain>")
        sys.exit(1)

    cert_file = sys.argv[1]
    issuer_file = sys.argv[2]
    ocsp_url = sys.argv[3]
    ca_chain = sys.argv[4]

    result = check_ocsp(cert_file, issuer_file, ocsp_url, ca_chain)
    print(json.dumps(result, indent=2))

    # Exit code based on status
    if result.get('valid'):
        sys.exit(0)
    else:
        sys.exit(1)
```

Sử dụng:

```bash
chmod +x ocsp_client.py

./ocsp_client.py \
    /root/ca/intermediate/certs/example.pki.cert.pem \
    /root/ca/intermediate/certs/intermediate.cert.pem \
    http://localhost:8888 \
    /root/ca/intermediate/certs/ca-chain.cert.pem
```

Output:

```json
{
  "timestamp": "2024-12-15T11:50:00.123456",
  "cert_file": "/root/ca/intermediate/certs/example.pki.cert.pem",
  "ocsp_url": "http://localhost:8888",
  "response_verified": true,
  "cert_status": "GOOD",
  "valid": true
}
```

## Demo 6: Load Testing OCSP Responder

Test performance của OCSP responder:

```bash
#!/bin/bash
# load-test-ocsp.sh

OCSP_URL="http://localhost:8888"
CERT="/root/ca/intermediate/certs/example.pki.cert.pem"
ISSUER="/root/ca/intermediate/certs/intermediate.cert.pem"
CA_CHAIN="/root/ca/intermediate/certs/ca-chain.cert.pem"
NUM_REQUESTS=100

echo "Starting OCSP load test with $NUM_REQUESTS requests..."

start_time=$(date +%s)
success=0
failed=0

for i in $(seq 1 $NUM_REQUESTS); do
    if openssl ocsp \
        -CAfile "$CA_CHAIN" \
        -issuer "$ISSUER" \
        -cert "$CERT" \
        -url "$OCSP_URL" \
        -timeout 5 > /dev/null 2>&1; then
        ((success++))
    else
        ((failed++))
    fi

    if [ $((i % 10)) -eq 0 ]; then
        echo "Progress: $i/$NUM_REQUESTS requests completed"
    fi
done

end_time=$(date +%s)
duration=$((end_time - start_time))
rps=$(echo "scale=2; $NUM_REQUESTS / $duration" | bc)

echo ""
echo "═══════════════════════════════════════"
echo "  OCSP Load Test Results"
echo "═══════════════════════════════════════"
echo "Total Requests: $NUM_REQUESTS"
echo "Successful: $success"
echo "Failed: $failed"
echo "Duration: ${duration}s"
echo "Requests/sec: $rps"
echo "═══════════════════════════════════════"
```

## Cleanup

```bash
# Stop OCSP responder
sudo /root/ca/intermediate/ocsp-stop.sh

# OR stop systemd service
sudo systemctl stop ocsp-responder
```

## Summary

✅ Đã học:
- Setup và chạy OCSP responder
- Test OCSP với certificate hợp lệ và revoked
- Configure OCSP Stapling trên Nginx
- Monitor OCSP responder health
- Tích hợp OCSP vào Python application
- Load testing OCSP performance

## Next Steps

- [OCSP Guide](../../docs/06-ocsp-guide.md) - Chi tiết về OCSP
- [Best Practices](../../docs/04-best-practices.md) - Security best practices
- [Troubleshooting](../../docs/05-troubleshooting.md) - Xử lý sự cố
