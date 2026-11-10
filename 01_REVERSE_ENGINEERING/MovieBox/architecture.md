# 🎬 MovieBox — Complete Architecture Analysis

## Overview
MovieBox ek pirated streaming app hai jo iOS aur Android dono par available hai (IPA sideloading / APK). Ye app free mein movies aur TV shows stream karti hai bina kisi official license ke.

---

## 🏗️ App Architecture

```
MovieBox App
├── Client Layer (iOS / Android)
│   ├── Native UI (Swift/ObjC on iOS, Kotlin/Java on Android)
│   ├── WebView Layer (kuch screens web-based hain)
│   ├── Video Player (VLC-based / AVPlayer / ExoPlayer)
│   └── Download Manager (custom + aria2)
│
├── API Layer
│   ├── Content API (movie metadata, search, categories)
│   ├── Stream API (actual video URLs — m3u8/mp4)
│   ├── CDN Resolver (multiple mirror CDNs)
│   └── Auth API (optional — kuch versions me free hai)
│
└── Backend (Remote Servers)
    ├── Main API Server
    ├── Content Database (MongoDB / MySQL)
    ├── CDN Network (Cloudflare + custom mirrors)
    └── Scraper Bots (automated content fetchers)
```

---

## 📱 Client-Side Architecture

### iOS Version
```
MovieBox.ipa
├── Info.plist              ← Bundle ID: com.xxx.moviebox (fake/rotated)
├── Frameworks/
│   ├── Alamofire           ← HTTP networking
│   ├── SDWebImage          ← Image loading/caching
│   ├── VLCKit              ← Video playback
│   └── Reachability        ← Network monitoring
├── Resources/
│   ├── Main.storyboard
│   └── Assets.xcassets
└── Binary (ARM64)
```

### Android Version
```
MovieBox.apk
├── AndroidManifest.xml
├── classes.dex             ← Dalvik bytecode (decompile with jadx)
├── lib/
│   ├── arm64-v8a/
│   │   ├── libvlc.so       ← VLC player
│   │   └── libaria2.so     ← Download engine
│   └── x86_64/
├── res/
│   └── layout/             ← XML layouts
└── assets/
    └── config.json         ← Hidden API endpoints (sometimes encrypted)
```

---

## 🔄 App Flow Architecture

```
User Opens App
      ↓
Splash Screen → Config Fetch (remote config check)
      ↓
Home Screen
├── Featured (carousel — latest movies)
├── Categories (Action, Drama, Horror...)
├── Search
└── My Downloads
      ↓
Movie Detail Page
├── Poster + Metadata (from TMDB-like API)
├── Ratings (IMDb scraped)
├── Available Servers (Server 1, 2, 3...)
└── Subtitles (OpenSubtitles API)
      ↓
Stream Resolution
├── App calls Stream API with movie_id
├── Backend returns: { "url": "https://cdn.xxx/movie.m3u8" }
├── Tries Server 1 → if fail → Server 2 → Server 3
└── Opens in Video Player
      ↓
Video Player
├── HLS (m3u8) or MP4 direct
├── Quality selector (720p, 1080p, 4K)
├── Subtitle overlay
├── Download button (triggers download manager)
└── Cast button (Chromecast / AirPlay)
```

---

## 🌐 Network Architecture

### Request Flow
```
App → Cloudflare (DDoS protection) → Load Balancer → API Server
                                                           ↓
                                                    MongoDB (metadata)
                                                           ↓
                                              CDN URL returned to App
                                                           ↓
                                               App streams from CDN directly
```

### API Base URLs (Pattern — rotated frequently)
```
https://api.[random].xyz/v2/
https://[ip-address]:8080/api/
https://[domain].top/movie/api/
```

### Key Endpoints (Reverse Engineered Pattern)
```
GET  /api/movies?page=1&limit=20          → Movie list
GET  /api/movie/{id}                      → Movie detail
GET  /api/stream/{id}?quality=1080p       → Stream URL
GET  /api/search?q={query}               → Search
GET  /api/categories                      → Categories list
GET  /api/trending                        → Trending content
POST /api/report?id={id}                  → Report broken link
```

---

## 🔐 Security Mechanisms (What They Use)

| Mechanism | Details |
|-----------|---------|
| API Key | Hardcoded in app binary (obfuscated with XOR/base64) |
| SSL Pinning | Present in some versions, bypassable with Frida |
| Token Rotation | API tokens change every 24-48 hours |
| URL Signing | CDN URLs are time-limited (expire in 2-6 hours) |
| Root Detection | Basic checks (bypassable) |
| Traffic Obfuscation | Custom headers to look like browser traffic |

---

## 📊 Data Flow Diagram

```
[App Launch]
     |
     v
[Remote Config API] ──→ Fetches: API endpoints, feature flags, ads config
     |
     v
[Home Feed API] ──→ Returns: movie IDs, posters, metadata
     |
     v
[User selects movie]
     |
     v
[Movie Detail API] ──→ Returns: full metadata, server list, subtitle list
     |
     v
[Stream API] ──→ Returns: CDN URL (signed, time-limited)
     |
     v
[CDN / Mirror Server] ──→ Actual video file (HLS segments or MP4)
     |
     v
[Video Player renders stream]
```

---

## 🔧 Key Technologies Identified

| Component | Technology |
|-----------|-----------|
| Networking | Alamofire (iOS) / OkHttp (Android) |
| Image Loading | SDWebImage / Glide |
| Video Player | VLC / AVPlayer / ExoPlayer |
| Download | aria2 / custom downloader |
| DB (Local) | SQLite / Room |
| Cache | NSCache / DiskLRUCache |
| Analytics | Firebase (sometimes) |
| Crash Reports | Bugly / Crashlytics |

---

## 📌 Key Findings

1. **No DRM** — Videos are raw MP4/HLS, no Widevine/FairPlay
2. **Mirror-based** — Multiple CDN mirrors, app auto-switches on failure
3. **Scraped metadata** — TMDB + IMDb data scraped/cached on their server
4. **Community-driven content** — Some versions allow users to submit video links
5. **Obfuscated binary** — ProGuard (Android) / symbol stripping (iOS)
6. **No real user accounts** — Most versions use device fingerprint as "user ID"

