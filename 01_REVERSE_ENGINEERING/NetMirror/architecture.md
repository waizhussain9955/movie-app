# 🪞 NetMirror — Complete Architecture Analysis

## Overview
NetMirror ek screen mirroring aur media casting app hai jo movie streaming ke saath combine hoti hai. Ye Miracast, AirPlay, Chromecast protocols ko support karti hai, aur saath mein ek built-in browser/streaming engine bhi hai.

---

## 🏗️ Dual Architecture — Mirroring + Streaming

```
NetMirror App
├── Screen Mirroring Engine
│   ├── Miracast (WiFi Direct protocol)
│   ├── AirPlay Receiver/Sender
│   ├── Chromecast (Google Cast SDK)
│   ├── DLNA/UPnP
│   └── Smart TV Direct Connect
│
├── Built-in Browser (Streaming)
│   ├── Custom WebView (Chromium-based)
│   ├── Ad-blocker integration
│   ├── Video detector/extractor
│   └── Cast-to-TV from browser
│
├── Media Player
│   ├── Local file playback
│   ├── Network stream playback (m3u8/mp4)
│   └── Cast from player to TV
│
└── Content Layer (Add-on feature)
    ├── Movie/Series index (similar to MovieBox)
    ├── IPTV support (m3u playlists)
    └── Live TV channels
```

---

## 📱 App Module Breakdown

### Module 1: Screen Mirroring
```
Phone Screen → Capture (MediaProjection API) → Encode (H.264) → Stream → TV
```

### Module 2: Browser + Video Extractor
```
User opens URL in built-in browser
         ↓
NetMirror scans page for video elements
         ↓
Detects video URLs (m3u8/mp4/dash)
         ↓
Offers "Cast to TV" or "Download" option
         ↓
Streams extracted URL to TV via Chromecast/DLNA
```

### Module 3: Content/IPTV
```
M3U Playlist URL → Parse channels → Display EPG → Play stream
OR
Built-in movie index → Select movie → Stream/Cast
```

---

## 🔄 Network Protocols Used

| Protocol | Use Case | Port |
|----------|---------|------|
| Miracast | Screen mirror via WiFi Direct | 7236 |
| AirPlay | Apple device to Apple TV / smart TV | 7000, 49152 |
| Chromecast | Cast to Google/Android TV | 8008, 8009 |
| DLNA/UPnP | Universal media sharing | 1900 (SSDP) |
| RTSP | Real-time streaming | 554 |
| HLS | HTTP Live Streaming | 80/443 |

---

## 🏗️ Backend Architecture

```
                    ┌──────────────────────────────┐
                    │   CloudFlare Protection       │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │    Main API Server            │
                    │    (Node.js / Go)             │
                    └───┬──────────────┬────────────┘
                        │              │
           ┌────────────▼──┐    ┌──────▼─────────┐
           │  Content DB   │    │  User Service   │
           │  (MongoDB)    │    │  (PostgreSQL)   │
           └────────┬───────┘    └────────────────┘
                    │
           ┌────────▼───────────────────────────────┐
           │         CDN / Stream Servers            │
           │    (Cloudflare Stream / BunnyCDN)       │
           └────────────────────────────────────────┘
```

---

## 🔌 Key APIs (Reverse Engineered)

```
Base URL: https://api.netmirror[N].com/v1/

GET  /movies?page=1&sort=trending       → Movie list
GET  /movie/{id}                        → Movie detail
GET  /stream/{id}?quality=auto          → Stream URL
GET  /iptv/channels?country=us          → IPTV channels list
GET  /iptv/epg?channel_id={id}          → TV guide
POST /cast/session                      → Start cast session
GET  /browser/extract?url={webpage_url} → Extract video from webpage
GET  /search?q={query}&type=all         → Unified search
```

---

## 🔐 Security Analysis

| Feature | Implementation |
|---------|---------------|
| API Auth | App-specific API key (rotated monthly) |
| Cast Security | WPA2 WiFi required for local casting |
| SSL | Standard HTTPS, no pinning in most versions |
| Obfuscation | DexGuard / R8 optimization |
| Anti-tamper | Basic root/emulator detection |

---

## 🛠️ Technology Stack

| Component | Technology |
|-----------|-----------|
| Android App | Kotlin + Jetpack |
| iOS App | Swift + SwiftUI |
| Cast SDK | Google Cast SDK |
| Screen Capture | MediaProjection API (Android) |
| Browser Engine | WebView (Chromium) |
| Video Extraction | yt-dlp embedded / custom extractors |
| Player | ExoPlayer (Android) / AVPlayer (iOS) |
| Backend API | Node.js / Go |
| Database | MongoDB + Redis |
| Analytics | Firebase Analytics |

---

## 🌟 Unique Features vs MovieBox

| Feature | MovieBox | NetMirror |
|---------|---------|----------|
| Screen Mirroring | ❌ | ✅ |
| Cast to TV | Limited | ✅ Full |
| Built-in Browser | ❌ | ✅ |
| Video Extractor | ❌ | ✅ |
| IPTV/Live TV | ❌ | ✅ |
| Movie Streaming | ✅ Full | ✅ |
| Download | ✅ | ✅ |
| Offline Playback | ✅ | ✅ |
| Subtitle Support | ✅ | ✅ |
| Multi-server | ✅ | ✅ |

---

## 📊 Data Flow

```
[App Opens]
     ↓
[Scan local network for cast devices — mDNS discovery]
     ↓
[Found: Smart TVs, Chromecasts, AirPlay devices]
     ↓
[User selects content]
├── Movie from built-in library → Stream → Option to cast
├── URL in browser → Video extracted → Cast to TV
├── IPTV channel → Live stream → Cast to TV
└── Local file → Play → Cast to TV
```

