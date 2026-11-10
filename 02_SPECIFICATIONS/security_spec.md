# 🛡️ Security Specification — StreamMax

## Overview
Security requirements for the StreamMax platform covering authentication, API security, content protection, and data privacy.

---

## 🔐 Authentication Security

### JWT Token Strategy
```
Access Token:
- Algorithm: RS256 (RSA + SHA256)
- Expiry: 24 hours
- Payload: { user_id, role, subscription, device_id, iat, exp }

Refresh Token:
- Stored in DB (can be revoked)
- Expiry: 30 days
- One refresh token per device

Device Token (Anonymous):
- Algorithm: HS256
- Expiry: 90 days
- Limited permissions
```

### Password Requirements
```
- Minimum 8 characters
- Must contain: uppercase + lowercase + number
- Hashing: bcrypt (cost factor: 12)
- No password reuse (last 5)
```

### Rate Limiting (Auth)
```
Login attempts:    5 per minute per IP
Register:         3 per hour per IP
Forgot password:  3 per hour per email
OTP verification: 3 attempts per OTP
```

---

## 🌐 API Security

### Request Validation
```
1. All inputs validated and sanitized
2. SQL injection prevention (parameterized queries)
3. NoSQL injection prevention (Mongoose sanitize)
4. XSS prevention (input encoding)
5. File upload validation (type + size + virus scan)
```

### HTTPS & Headers
```nginx
# Required HTTP Security Headers
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
```

### API Key Management
```
Mobile apps use API key in headers:
X-API-Key: {rotated_every_30_days}
X-App-Version: 1.0.0
X-Platform: android|ios
X-Device-ID: {uuid}

API keys rotated:
- Automatic: every 30 days
- Immediate: if key is compromised
- Old keys accepted for 7 days after rotation (grace period)
```

---

## 🎬 Content Protection

### CDN URL Signing
```
All stream URLs are time-limited signed URLs:

Pattern:
https://cdn.streammax.app/movies/{id}/1080p/index.m3u8
  ?token={HMAC_SHA256_signature}
  &expires={unix_timestamp}
  &device={device_id_hash}

Signing:
secret = SERVER_CDN_SECRET
message = f"{content_path}:{expires}:{device_hash}"
signature = HMAC_SHA256(secret, message)
token = base64url(signature)

Validity: 4 hours
HLS segments: each .ts segment is also signed
```

### Stream Protection
```
1. Each stream URL is unique per session
2. URLs cannot be shared across devices
3. Device fingerprint validated on each request
4. Concurrent stream limit: 2 screens per account
5. Geographic restrictions (optional per content)
```

---

## 🔒 Data Privacy

### User Data
```
Stored:
- Email (encrypted at rest — AES-256)
- Password hash (bcrypt)
- Watch history
- Preferences

NOT stored:
- Payment card details (use Stripe — no raw card data)
- Exact location (only country-level)

Retention:
- Active users: indefinitely
- Deleted accounts: 30-day grace, then hard delete
- Watch history: 2 years max
- Logs: 90 days
```

### GDPR / Privacy Compliance
```
User rights:
- Right to access data: GET /user/data/export
- Right to delete:      DELETE /user/account
- Right to portability: JSON export of all data
- Opt-out of analytics: PATCH /user/settings { analytics: false }
```

---

## 🚫 Abuse Prevention

### Device Limits
```
- Max 5 devices per account
- Remove device: DELETE /user/devices/{device_id}
- Suspicious multi-device login: email alert
```

### Download Limits
```
- Free: 5 downloads/month, 480p max
- Premium: Unlimited, up to 1080p
- Downloads verified on playback (token check)
```

### Anti-Sharing
```
- Watch position sync reveals concurrent sessions
- 2+ concurrent streams → alert user
- 5+ concurrent streams → auto suspend account
```

---

## 🔍 Security Monitoring

### Logging
```
All logged (Elasticsearch):
- API requests (IP, endpoint, status, response_time)
- Auth events (login, logout, token refresh, failures)
- Content access (which user watched what)
- Admin actions (who changed what)
- Error events

Log retention: 90 days
Sensitive data masked in logs
```

### Intrusion Detection
```
Alerts triggered for:
- 100+ failed logins from same IP in 10 min
- Same account from 10+ different IPs in 1 hour
- Unusual API patterns (scraping behavior)
- Known malicious IP ranges
```

### Vulnerability Management
```
- Dependency updates: weekly automated check (Dependabot)
- Security patches: within 48 hours for critical
- Penetration testing: quarterly
- Bug bounty: private program via HackerOne
```

---

## 📱 Mobile App Security

### Android
```
- ProGuard/R8 code obfuscation
- Root detection (advisory, not blocking)
- Certificate pinning (for API calls)
- Sensitive data in EncryptedSharedPreferences
- Downloaded files encrypted (AES-256)
- Network security config (block cleartext)
```

### iOS
```
- App Transport Security (ATS) enforced
- Keychain for token storage
- Jailbreak detection (advisory)
- SSL certificate pinning
- Downloaded files encrypted
```

---

## 🛡️ Security Checklist

### Before Launch
- [ ] All endpoints require authentication (except public ones)
- [ ] Rate limiting on all endpoints
- [ ] Input validation on all endpoints
- [ ] SQL/NoSQL injection tests passed
- [ ] HTTPS enforced, HTTP redirects to HTTPS
- [ ] Security headers configured
- [ ] API keys rotation system live
- [ ] CDN URL signing working
- [ ] Logs collecting properly
- [ ] Monitoring alerts configured
- [ ] Penetration test completed
- [ ] Privacy policy + ToS published
- [ ] GDPR data export/delete working

