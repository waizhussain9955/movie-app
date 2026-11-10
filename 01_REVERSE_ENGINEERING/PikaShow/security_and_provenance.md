# 🔒 Security, Permissions & Provenance Audit — PikaShow APK

## 📌 Executive Security Findings
Static security audit ke mutabiq PikaShow version `10.8.2` mein multiple architectural aur security hygiene concerns detect huwi hain:

```
┌─────────────────────────────────────────────────────────────┐
│                 PikaShow Risk Severity Radar                │
├─────────────────────────────────────────────────────────────┤
│  [HIGH]       Android Debug Certificate (No Dev Provenance) │
│  [MEDIUM]     usesCleartextTraffic="true" (Plain HTTP)      │
│  [MEDIUM]     allowBackup="true" (ADB Data Extraction)      │
│  [MEDIUM]     Exported RequestService (Cross-App Invocation)│
│  [LOW-MED]    RECORD_AUDIO Permission (Microphone Access)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Signing Certificate & Trust Audit

```
Keystore Type:      Generic Android Debug Key
Owner / Issuer:     C=US, O=Android, CN=Android Debug
Serial Number:      35d0ca3017725cd4
Validity:           23 May 2025 to 8 October 2052
SHA-256:            F6:14:BF:F7:BC:30:2B:71:25:C5:85:FD:FA:48:D5:DA:9E:24:B5:2F:40:83:99:3F:91:72:F6:7D:3D:C8:BE:6C
SHA-1:              A2:F3:9A:9D:C1:12:87:9E:38:65:ED:1B:07:0F:CC:4C:26:4B:EA:D6
Algorithm:          2048-bit RSA, SHA256withRSA
```

### Risk Assessment:
* **No Developer Identity:** Yeh APK kisi verifiable developer ya production organization key se sign nahi kiya gaya. Koi bhi shakhs Android Studio ke standard debug keystore se matching signature wala modified build tayar kar sakta hai.
* **Non-Play Store Release:** Play Store signing standards (Play App Signing / custom release keys) exist nahi karte.

---

## 2. Manifest Flags & Attack Surface

### A. `usesCleartextTraffic="true"`
* **Issue:** Application ko unencrypted HTTP connections establish karne ki ijazat deta hai.
* **Risk:** Local Wi-Fi networks par Man-in-the-Middle (MITM) attacks ke zariye network traffic inspect ya modify ki ja sakti hai.

### B. `allowBackup="true"`
* **Issue:** Android Debug Bridge (ADB) ke zariye application ka internal data (SQLite cache, SharedPreferences, tokens) extract kiya ja sakta hai.
* **Remediation:** Standard security best practice isko `allowBackup="false"` rakhna hoti hai.

### C. Exported Service (`RequestService`)
* **Declaration:**
  ```xml
  <service 
      android:name="com.offshore.raichu.service.RequestService" 
      android:exported="true">
      <intent-filter>
          <action android:name="com.offshore.REQUEST_SERVICE" />
      </intent-filter>
  </service>
  ```
* **Risk:** Yeh service doosri installed apps ke liye accessible hai. Agar incoming intent parameters sanitize na hon toh unauthorized service triggers ka khatra rehta hai.

---

## 3. Permissions Footprint

Application ne **15 permissions** declare ki hain:

| Permission Name | Category | Functional Role |
| :--- | :--- | :--- |
| `INTERNET` | Network | API queries aur video streaming |
| `ACCESS_NETWORK_STATE` | Network | Connection status detection (Wi-Fi vs Cellular) |
| `ACCESS_WIFI_STATE` | Network | Wi-Fi status queries |
| `WAKE_LOCK` | System | Video playback ke dauran screen sleep prevent karna |
| `FOREGROUND_SERVICE` | System | Background task execution |
| `RECEIVE_BOOT_COMPLETED` | System | Device reboot par WorkManager scheduler restore karna |
| `RECORD_AUDIO` | Hardware | ⚠️ Unexpected in video player; voice ad SDK dependency |
| `AD_ID` & AdServices | Telemetry | Advertising user profiling & attribution |

* **Positive Finding:** Storage (`READ_EXTERNAL_STORAGE`), Camera, Contacts, aur Fine Location permissions exist **nahi** karti hain, jo ke is app category ke liye relatively restrained footprint hai.

---

## 4. Code Obfuscation Assessment
* **R8 / ProGuard Minification:** Non-SDK classes single-letter packages mein split hain (`c2`, `r0`, `y`, `n`, `p0`).
* **Namespace Layering:**
  * Package Identifier: `com.offshore.pikachu`
  * Internal Code Path: `com.offshore.raichu`
  * Public App Brand: `Pikashow`
* **Native Encapsulation:** Request headers aur cryptographic token checks Java layer ke bajaye native binary (`libpika.so`) mein compile kiye gaye hain.

