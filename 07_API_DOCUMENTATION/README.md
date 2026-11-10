# 🌐 07 — API Documentation & Integration Architecture (StreamMax)

## 📌 Overview
Yeh directory **StreamMax Media Streaming Platform** ki complete API Architecture, Endpoints, Data Contracts, aur Streaming Specifications ko define karti hai. Is documentation ka maqsad client-side (Flutter Application) aur backend services (Node.js/Express + Metadata Providers) ke darmiyan seamless integration aur robust data flow ensure karna hai.

---

## 📑 Table of Contents

| File Name | Description | Key Focus Areas |
| :--- | :--- | :--- |
| **[`01_TMDB_CATALOG_API.md`](file:///d:/Reverse%20Engineer%20movie%20app/07_API_DOCUMENTATION/01_TMDB_CATALOG_API.md)** | TMDB Metadata Provider API | Trending, Discover, Search, Seasons, Hindi/Bollywood filtering |
| **[`02_STREAMMAX_BACKEND_API.md`](file:///d:/Reverse%20Engineer%20movie%20app/07_API_DOCUMENTATION/02_STREAMMAX_BACKEND_API.md)** | Core REST API Specifications | Auth, Home Feed, Movie Details, Stream Resolution, Watchlist |
| **[`03_STREAMING_HLS_SPEC.md`](file:///d:/Reverse%20Engineer%20movie%20app/07_API_DOCUMENTATION/03_STREAMING_HLS_SPEC.md)** | Video Streaming & Multi-Audio Spec | HLS (`.m3u8`), Multi-Track Audio (Hindi/Dual-Audio), Hls.js Bridge |
| **[`04_CLIENT_INTEGRATION_GUIDE.md`](file:///d:/Reverse%20Engineer%20movie%20app/07_API_DOCUMENTATION/04_CLIENT_INTEGRATION_GUIDE.md)** | Flutter Client Service Architecture | `ApiService`, `NetMirrorService`, Concurrency, In-memory Cache |

---

## 🏛️ System Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                 StreamMax Mobile (Flutter)                  │
│                                                             │
│  ┌────────────────────┐            ┌─────────────────────┐  │
│  │   Catalog Screen   │            │  Video Player Engine│  │
│  └─────────┬──────────┘            └──────────┬──────────┘  │
└────────────┼──────────────────────────────────┼─────────────┘
             │                                  │
      (HTTP REST / JSON)                 (HLS / Hls.js Bridge)
             │                                  │
    ┌────────▼────────┐                ┌────────▼────────┐
    │  API Gateway /  │                │  CDN Streaming  │
    │  Backend Engine │                │    Edge Nodes   │
    └────────┬────────┘                └────────┬────────┘
             │                                  │
    ┌────────▼────────┐                ┌────────▼────────┐
    │  TMDB Metadata  │                │  Multi-Audio    │
    │  Catalog v3     │                │  Master .m3u8   │
    └─────────────────┘                └─────────────────┘
```

---

## 🔐 API Guarantees & Non-Functional Requirements
1. **Low Latency:** Client-side parallel `Future.wait` requests se initial feed latency < 1.2s.
2. **High Availability:** Primary backend failure ki soorat mein direct TMDB Fallback aur Local In-Memory Cache.
3. **Multi-Audio Compatibility:** Standard HLS Master manifest structure jo standard Hls.js aur native ExoPlayer/AVPlayer dono par smoothly execute hota hai.
4. **Ad-Free Clean Data:** Endpoints ke response sanitization rules taake third-party popups, adult redirects, ya adware client tak na pohanche.

