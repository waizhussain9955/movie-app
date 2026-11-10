# 🌐 Backend & Network Analysis — PikaShow APK

## 📌 Network Architecture Overview
Static decompilation se establish hota hai ke PikaShow application ke DEX files ya strings table mein koi bhi plaintext Content API base URL hardcoded **nahi** hai. Network communication architecture dynamic runtime injection model follow karta hai.

---

## 📡 Dynamic URL Injection Model

```
                    ┌───────────────────────────────┐
                    │    Firebase Remote Config /   │
                    │      assets/z/ Decryption     │
                    └───────────────┬───────────────┘
                                    │ Runtime Injected String
                    ┌───────────────▼───────────────┐
                    │ NativeWrapper.setUrl(String)  │
                    │   (Must end with trailing '/')│
                    └───────────────┬───────────────┘
                                    │ Configures Base URL
                    ┌───────────────▼───────────────┐
                    │    Retrofit 2 HTTP Client     │
                    └───────────────┬───────────────┘
                                    │ Injects Native Headers
                    ┌───────────────▼───────────────┐
                    │     libpika.so Sign Engine    │
                    │   (pikachu_get_headers_v2)    │
                    └───────────────┬───────────────┘
                                    │ Signed Outgoing Request
                    ┌───────────────▼───────────────┐
                    │     Target Content Server     │
                    └───────────────────────────────┘
```

1. `NativeWrapper.setUrl(String)` function runtime par external source (Firebase Remote Config ya native decrypted memory) se base URL receive karta hai.
2. Retrofit instance build hone ke baad `libpika.so` se `pikachu_get_headers_v2` call hota hai jo timestamped signature aur authorization headers generate karta hai.
3. Is native signing mechanism ki wajah se koi bhi unauthorized third-party direct HTTP requests bina native validation ke execute nahi kar sakti.

---

## 🔍 Network Strings & Domain Indicators

Static string extraction across all DEX layers aur `libpika.so` ne **102 unique URLs** identify kiye hain:

### 1. Primary Non-SDK Hostname:
* `https://manoda.co/` — Native library `libpika.so` mein direct reference mojood hai (Primary candidate for dynamic resolution / discovery endpoint).

### 2. Advertising & Mediation Domains:
* **AppLovin:** `a.applovin.com`, `ms.applovin.com`, `rt.applovin.com`, `md.applovin.com`, `d.applovin.com`
* **Vungle:** `adx.ads.vungle.com`, `config.ads.vungle.com`, `logs.ads.vungle.com`
* **Unity Ads:** `gateway.unityads.unity3d.com`, `scar.unityads.unity3d.com`
* **Mintegral:** `gatewayprotocol.v1`, `com.mbridge.msdk` endpoints

### 3. Google & Infrastructure Telemetry:
* `firebaseremoteconfig.googleapis.com` (Dynamic config fetching)
* `firebase-settings.crashlytics.com`
* `app-measurement.com` (Analytics tracking)
* `www.googleapis.com`, `play.google.com`

### 4. External Social / Video Links:
* `https://t.me/` (Telegram official channel redirects)
* `https://www.youtube.com/` (Trailer / external embeds)

---

## 🛡️ Upstream Risk Comparison (StreamMax vs PikaShow)
PikaShow ka network model 4 mukhtalif ad networks aur background telemetry ke sath heavily bundled hai, jiski wajah se mobile data consumption zyada hoti hai aur aggressive popunder ads trigger hote hain. 

StreamMax ke architecture mein in تمام ad SDKs ko bypass kar ke direct, clean HLS manifests aur direct TMDB caching use ki gayi hai taake fast aur ad-free streaming deliver ho sake.

