# 🏗️ Architecture Analysis — PikaShow APK (`com.offshore.pikachu`)

## 📌 Executive Architecture Summary
Pikashow version `10.8.2` (build code `83`) ek **Thin Native-Backed Client Shell** architecture use karta hai. App ka visual front-end Android Jetpack Compose aur Kotlin mein likha gaya hai, lekin critical business logic, network request authentication, aur dynamic API routing Java layer ke bajaye native C++ binary (`libpika.so`) aur Firebase Remote Config par munhasir hai.

```
┌─────────────────────────────────────────────────────────────┐
│                 PikaShow Client Shell                      │
│                                                             │
│  ┌───────────────────────┐       ┌───────────────────────┐  │
│  │ MainActivity (Compose)│       │  WebViewActivity (UI) │  │
│  └───────────┬───────────┘       └───────────┬───────────┘  │
│              │                               │              │
│  ┌───────────▼───────────────────────────────▼───────────┐  │
│  │                Room Local Database                    │  │
│  │   (Bollywood, Hollywood, Series, LiveTV Cache)        │  │
│  └───────────────────────────┬───────────────────────────┘  │
└──────────────────────────────┼──────────────────────────────┘
                               │ JNI Bridge
┌──────────────────────────────▼──────────────────────────────┐
│                    libpika.so (Native C++)                  │
│                                                             │
│  * pikachu_on_create / on_resume / on_pause                 │
│  * pikachu_get_headers / pikachu_get_headers_v2             │
│  * ensure_sign_key & get_sign_key_sha256                    │
└──────────────────────────────┬──────────────────────────────┘
                               │ Dynamic Base URL Injected
┌──────────────────────────────▼──────────────────────────────┐
│                  Retrofit 2 / OkHttp 3                      │
│               Authenticated Network Client                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🧩 Component & Code Inventory

Decompilation metrics show that **99.7%** of the compiled classes belong to third-party SDKs:

* **Total Classes:** `17,357` (across `classes.dex` and `classes2.dex`)
* **App's Own Classes:** Only `46` Java files under `com.offshore.raichu`
* **Third-Party Ad SDKs:** `29` out of `31` Activities belong to ad mediation frameworks (AppLovin MAX, Unity Ads, Vungle, Mintegral).

### App-Own Code Layout (`com.offshore.raichu`):

| Package / Module | Component Count | Purpose |
| :--- | :---: | :--- |
| `MainActivity.java` | 1 | Launcher activity; delegates all lifecycle events to native bridge. |
| `MyApplication.java` | 1 | Sets Firebase channel identifiers (`pikaofficialnew`, version `2607211`). |
| `natives/` | 2 | `Pikachu.java` & `NativeWrapper.java` (JNI binding to `libpika.so`). |
| `models/vo/` | 18 | Data models (`ContentItem`, `VideoData`, `VideoHeader`, `LiveTvItem`). |
| `models/cache/` & `db/` | 8 | Room SQLite cache tables for offline catalog persistence. |
| `remoteconfig/` | 2 | Remote configuration parser for update prompts and ad channels. |
| `service/` | 1 | `RequestService.java` (Exported system communication service). |
| `ui/` | 3 | `WebViewActivity.java` and playback layout wrappers. |

---

## ⚡ Native Code Orchestration (`libpika.so`)
App ki real anti-tamper security native binary ke andar pack ki gayi hai:
* **Stripped ELF Binary:** Built with Clang 14.0.6 (`1.06 MB` for arm64-v8a).
* **JNI Exported Interfaces:**
  * Lifecycle: `pikachu_on_attached`, `pikachu_on_create_vm`, `pikachu_on_start`, `pikachu_on_resume`, `pikachu_on_nav`
  * Request Headers: `pikachu_get_headers`, `pikachu_get_headers_v2`
  * Signature Verification: `ensure_sign_key`, `get_sign_key_sha256`

---

## 📦 Obfuscated Payload (`assets/z/`)
Application assets mein `8.1 MB` ka uncompressed chunked payload mojood hai:
* ~50 chunks of ~100 KB (`eee*.ext`)
* 4 chunks of ~1 MB (`em*.ext`)
* Small index blobs (`f*.ext`, `ggg*.ext`)

Yeh chunks initial boot par native layer ya runtime script ke zariye reassemble hote hain aur encrypted configurations ya initial seed data provide karte hain.

