# 📱 Pikashow APK — Static Reverse Engineering Report

> **Document:** Static Analysis & Security Evaluation Report  
> **Source Target:** `pikashow_0_v8n4.apk` / `pikashow.apk`  
> **Package Name:** `com.offshore.pikachu`  
> **Version:** `10.8.2` (VersionCode: `83`)  
> **Date:** 10 November 2026 (PKT)  
> **Prepared for:** Waiz Hussain  
> **File Size:** 21,434,649 bytes (21.4 MB)  
> **SHA256:** `372dc5af73e2299ed4a65c0567a3a2ecb3ce6c7ce850d06f4d3c29faf3a4e0a6`  
> **MD5:** `2601b5a421c5362cd35f7117aa866665`  
> **Methodology:** Static Analysis Only (JADX 1.5.3, APKTool 2.11.0, Androguard 4.1.4, Keytool). No network traffic captured; APK SHA256 verified identical before and after analysis.

---

## 📊 High-Level Metrics

| Metric | Value | Significance |
| :--- | :--- | :--- |
| **App Version** | `10.8.2` (Code `83`) | Production distributed version |
| **Total Classes** | `17,357` classes | Heavy binary payload |
| **App's Own Java Files** | `46` files (`com.offshore.raichu`) | App logic is extremely thin; mostly a wrapper |
| **Unique URLs Found** | `102` URLs | Almost all belong to ad networks / telemetry |
| **Signing Certificate** | **Android Debug Key** | ⚠️ Major provenance & trust red flag |

---

## 🎯 Executive Summary
Pikashow version 10.8.2 (`com.offshore.pikachu`) is a thin Kotlin and Jetpack Compose shell whose real runtime behaviour lives in native code (`libpika.so`) and in server-driven configuration. Of its 17,357 classes, only **46 Java files** belong to the app's own code; the remaining 99.7% consists of third-party advertising SDKs (AppLovin MAX, Unity Ads, Vungle, Mintegral) and Firebase telemetry (Analytics, Crashlytics, Remote Config).

### Key Architectural Findings:
1. **Debug-Signed Certificate:** The APK is signed with a generic `Android Debug` certificate rather than a verified developer release key.
2. **Native Layer Header & Request Signing:** Network request signing and headers are generated inside native C++ library `libpika.so`, bypassing standard Java/Kotlin hooks.
3. **Dynamic API Injection:** No plaintext content-API base URL exists anywhere in the DEX files or native binary strings; the endpoint is delivered dynamically at runtime via Firebase Remote Config or native memory injection.

---

## 1. Methodology & Analysis Tooling

> **Note on `awesome-reverse-engineer-anything`:**  
> The repository `AIshihzong/awesome-reverse-engineer-anything` is a curated awesome-list showcasing AI agent reverse engineering use cases centered on REA (`morluto/rea`). It is not a decompiler itself. This analysis was performed directly using the underlying decompilation engines that REA orchestrates (`JADX`, `apktool`, `Androguard`, `keytool`).

| Tool | Version | Role in Analysis | Output Volume |
| :--- | :--- | :--- | :--- |
| **JADX** | `1.5.3` | DEX to Java decompilation: 9,474 classes processed | 12,659 Java files (108 MB) |
| **APKTool** | `2.11.0` | Full APK decode: Manifest, resources & 17,357 smali files | 211 MB decompiled tree |
| **Androguard** | `4.1.4` | Independent Manifest, DEX, strings & certificate cross-check | Structured JSON outputs |
| **Keytool / Strings**| OpenJDK `21.0.13` | Certificate inspection, ELF & DEX string extraction | Raw telemetry logs |

---

## 2. App Identity & Environment

| Field | Value | Notes |
| :--- | :--- | :--- |
| **App Name** | Pikashow | Branded display name |
| **Package Name** | `com.offshore.pikachu` | Android system package ID |
| **Code Namespace** | `com.offshore.raichu` | Decompiled code directory |
| **SDK Levels** | `minSdk 21` (Android 5.0) / `targetSdk 34` (Android 14) / `compileSdk 34` | Modern API 34 compliance |
| **Build System** | Gradle plugin `8.0.2`, Kotlin `1.9.10` | Standard modern Android build |
| **Application Class** | `com.offshore.raichu.MyApplication` | App initialization entry point |
| **Launcher Activity** | `com.offshore.raichu.MainActivity` | Single exported activity |
| **DEX Architecture** | Multidex (`classes.dex`: 8.8 MB + `classes2.dex`: 7.5 MB) | Total 83,018 unique DEX strings |
| **Firebase Channels** | `our_version = "2607211"`, `channel = "pikaofficialnew"` | Configured in `MyApplication.onCreate` |

---

## 3. Signing Certificate & Provenance

```
Owner / Issuer:     C=US, O=Android, CN=Android Debug
Serial Number:      35d0ca3017725cd4
Validity:           23 May 2025 to 8 October 2052
SHA256 Fingerprint: F6:14:BF:F7:BC:30:2B:71:25:C5:85:FD:FA:48:D5:DA:9E:24:B5:2F:40:83:99:3F:91:72:F6:7D:3D:C8:BE:6C
SHA1 Fingerprint:   A2:F3:9A:9D:C1:12:87:9E:38:65:ED:1B:07:0F:CC:4C:26:4B:EA:D6
Algorithm:          2048-bit RSA, SHA256withRSA
```

> ⚠️ **Provenance Verdict:** The APK is signed with the generic Android Debug keystore. Anyone with Android Studio can compile an update matching this certificate. This confirms the distribution bypassed standard Google Play release pipelines.

---

## 4. Permissions & Manifest Security Flags

### Declared Permissions (15 Total):
* **Core Network:** `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`
* **Playback / Background:** `WAKE_LOCK`, `FOREGROUND_SERVICE`, `RECEIVE_BOOT_COMPLETED`
* **Advertising & Attribution:** `AD_ID`, `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_TOPICS`
* **SDK Bindings:** `BIND_GET_INSTALL_REFERRER_SERVICE`, `BIND_APPHUB_SERVICE`, `com.on.talk.PERMISSION_BIND_INTERACTION`
* **Audio Anomaly:** `RECORD_AUDIO` *(Unexpected in a video playback app; likely injected by an ad network or voice search SDK)*.

### Security Flags:
| Flag | Value | Security Impact |
| :--- | :--- | :--- |
| `usesCleartextTraffic` | `"true"` | ⚠️ Unencrypted HTTP traffic allowed (vulnerable to MITM). |
| `allowBackup` | `"true"` | ⚠️ App internal data can be extracted via ADB backup. |
| `largeHeap` | `"true"` | Performance allocation for video buffer management. |

---

## 5. Component Breakdown

| Component Type | Total Count | App's Own Components | Third-Party / Ad SDKs |
| :--- | :---: | :--- | :--- |
| **Activities** | **31** | `2` (`MainActivity`, `ui.WebViewActivity`) | `29` (AppLovin MAX, Unity Ads, Vungle, Mintegral) |
| **Services** | **12** | `1` (`com.offshore.raichu.service.RequestService`) | `11` (Firebase Measurement, WorkManager, AppLovin) |
| **Receivers** | **12** | `0` | `12` (AndroidX, Firebase, Mintegral) |
| **Content Providers** | **4** | `0` | `4` (AppLovin Init, Firebase Init, AndroidX Startup, Vungle) |

* **Exported Surface:** The externally reachable surface is restricted to `MainActivity` (launcher) and `RequestService` (action `com.offshore.REQUEST_SERVICE`).

---

## 6. App's Internal Architecture (`com.offshore.raichu`)

The app's own code comprises only 46 cleanly decompiled Java classes:

```
com/offshore/raichu/
├── MainActivity.java            ← Shell activity delegating lifecycles to native bridge
├── MyApplication.java           ← Initializes Firebase config & native wrapper
├── natives/
│   ├── Pikachu.java             ← JNI native function declarations
│   └── NativeWrapper.java       ← Retrofit builder (requires base URL ending in '/')
├── models/
│   ├── vo/                      ← Value objects (ContentItem, VideoData, LiveTvItem, etc.)
│   ├── cache/                   ← Room database entities
│   └── db/                      ← Local cache for Bollywood, Hollywood, Series, Live TV
├── remoteconfig/
│   └── RemoteConfig.java        ← Firebase Remote Config parser (ads, update dialogs, speed)
├── service/
│   └── RequestService.java      ← Exported background communication service
└── ui/
    └── WebViewActivity.java     ← Fallback web rendering container
```

---

## 7. Native Libraries & Cryptographic Signing (`libpika.so`)

The APK includes native libraries for 4 CPU architectures:
* `arm64-v8a` (`libpika.so` — 1,061,760 bytes)
* `armeabi-v7a` (`libpika.so` — 712,416 bytes)
* `x86` / `x86_64`

### Exported JNI Symbols in `libpika.so`:
* Lifecycle Handlers: `pikachu_on_attached`, `pikachu_on_create`, `pikachu_on_create_vm`, `pikachu_on_start`, `pikachu_on_resume`, `pikachu_on_pause`, `pikachu_on_nav`
* Network Request Signing: `pikachu_get_headers`, `pikachu_get_headers_v2`
* Internal Validation: `ensure_sign_key`, `get_sign_key_sha256`

> **Key Architectural Takeaway:** The app delegates HTTP authentication headers and tamper verification to C++ native code. This prevents simple static extraction of API credentials from Java bytecode.

---

## 8. Network Indicators & Endpoints

A complete string scan across all DEX files and `libpika.so` identified **102 unique URLs**:
* **Advertising & Telemetry (99%):** `a.applovin.com`, `adx.ads.vungle.com`, `gateway.unityads.unity3d.com`, `firebaseremoteconfig.googleapis.com`, `app-measurement.com`.
* **Only Non-SDK Domain Found:** `https://manoda.co/` (referenced directly within `libpika.so`).
* **Content APIs:** No plaintext media streaming or catalog endpoints are present in the static binary. The live base URL is injected at runtime into `NativeWrapper.setUrl(String)`.

---

## 9. Asset Analysis

* **`assets/z/` (8.1 MB):** Contains ~50 × 100 KB chunks (`eee*.ext`), four 1 MB chunks (`em*.ext`), and smaller `f*.ext`/`ggg*.ext` blobs. These represent an uncompressed, split/obfuscated payload (encrypted catalog/configuration reassembled at runtime).
* **`assets/ad-viewer/`:** Standard Open Measurement Interface Definition (`omsdk-v1.js`, `omid-session-client-v1.js`).
* **`assets/builddatas.json`:** Component mapping for ad view mediation.

---

## 10. Comprehensive Risk Assessment

| # | Finding | Severity | Technical Impact |
| :-: | :--- | :---: | :--- |
| **1** | Generic Android Debug Signing Key | **High** | Absence of release provenance; vulnerable to local signing impersonation. |
| **2** | `usesCleartextTraffic="true"` | **Medium** | Plaintext HTTP communication permitted; risk of eavesdropping. |
| **3** | `allowBackup="true"` | **Medium** | Local database and shared preferences extractable via ADB. |
| **4** | Exported `RequestService` | **Medium** | Unprotected exported service callable by other installed applications. |
| **5** | Undeclared `RECORD_AUDIO` Permission | **Low-Medium**| Microphone permission declared without explicit user-facing audio feature. |
| **6** | Server-Driven Native Signing | **Design** | Protects API endpoints against static decompilation. |
| **7** | 4 Integrated Ad Networks + Trackers | **Info** | High telemetry footprint; potential ad network redirection risks. |

