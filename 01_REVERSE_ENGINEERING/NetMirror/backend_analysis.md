# 🔧 NetMirror — Backend Analysis

## Overview
NetMirror ka backend MovieBox se zyada complex hai kyunki isko streaming + casting + IPTV sab manage karna padta hai.

---

## 🖥️ Backend Services Breakdown

```
NetMirror Backend
├── API Gateway (nginx + rate limiting)
├── Content Service (movies, metadata)
├── Stream Service (CDN URL generation)
├── IPTV Service (channel list, EPG)
├── Cast Session Service (WebSocket)
├── Video Extractor Service (yt-dlp wrapper)
└── Analytics Service
```

---

## 🗄️ Database Design

### Movies Collection
```json
{
  "_id": "ObjectId",
  "title": "Movie Title",
  "type": "movie|series|live",
  "streams": [
    {
      "quality": "1080p",
      "url": "https://cdn.xxx/movie.m3u8",
      "server": 1,
      "healthy": true
    }
  ],
  "metadata": {
    "tmdb_id": 12345,
    "rating": 8.5,
    "genre": ["Action"],
    "year": 2024
  }
}
```

### IPTV Channels Collection
```json
{
  "_id": "ObjectId",
  "name": "Channel Name",
  "country": "US",
  "category": "Sports|News|Entertainment",
  "logo": "https://logo.url",
  "stream_url": "https://iptv.xxx/channel.m3u8",
  "epg_id": "channel_epg_id",
  "is_active": true
}
```

### Cast Sessions (Redis — ephemeral)
```json
{
  "session_id": "uuid",
  "device_id": "phone_uuid",
  "cast_device": "chromecast|airplay|dlna",
  "content_url": "https://cdn.xxx/movie.m3u8",
  "position": 3600,
  "created_at": 1234567890,
  "expires_at": 1234571490
}
```

---

## 🔌 API Endpoints

### Content API
```
GET /v1/home                        → Curated home content
GET /v1/movies?page=1&limit=20      → Movie list
GET /v1/movie/{id}                  → Movie detail + streams
GET /v1/stream/{id}?quality=1080p   → Signed stream URL
GET /v1/search?q={query}            → Search all content
```

### IPTV API
```
GET /v1/iptv/channels?country={cc}  → Channel list by country
GET /v1/iptv/categories             → Channel categories
GET /v1/iptv/epg?channel={id}&date={date} → Program guide
GET /v1/iptv/m3u                    → Full M3U playlist export
```

### Cast API
```
POST /v1/cast/start
     Body: { "content_url": "...", "cast_type": "chromecast" }
     → Creates WebSocket session

WS   /v1/cast/ws/{session_id}       → Real-time cast control
     Messages: { "action": "play|pause|seek|stop", "position": 0 }

GET  /v1/cast/devices               → Detected cast devices on network
```

### Browser Video Extractor
```
POST /v1/extract
     Body: { "url": "https://any-video-website.com/video" }
     → Uses yt-dlp to extract direct video URL
     Response: {
       "title": "Video Title",
       "formats": [
         { "quality": "1080p", "url": "...", "ext": "mp4" }
       ]
     }
```

---

## 👥 Backend Team Structure

| Role | Count | Responsibility |
|------|-------|---------------|
| Backend Dev (API) | 2-3 | REST API, business logic |
| Backend Dev (Streaming) | 1-2 | HLS, CDN, encoding pipeline |
| DevOps | 1-2 | Servers, CI/CD, monitoring |
| Mobile Dev (Android) | 1-2 | Android app + casting SDK |
| Mobile Dev (iOS) | 1-2 | iOS app + AirPlay |
| Content Ops | 1 | Monitor content quality |
| **Total** | **~7-12** | Lean team |

---

## ⚙️ Tech Stack

| Layer | Technology |
|-------|-----------|
| API | Go (Gin) or Node.js (Fastify) |
| Database | MongoDB (content) + PostgreSQL (users) + Redis (sessions/cache) |
| Message Queue | Redis Pub/Sub or RabbitMQ |
| CDN | Cloudflare Stream + BunnyCDN |
| Video Extraction | yt-dlp (Python service) |
| Cast Protocol | Google Cast SDK, AirPlay 2 |
| WebSocket | Socket.io or native WS |
| Hosting | Hetzner / OVH (offshore) |
| Monitoring | Grafana + Prometheus |

---

## 🔄 Cast Session Flow

```
Phone                    Server                    TV
  │                         │                       │
  │── POST /cast/start ────→│                       │
  │                         │                       │
  │←── session_id ──────────│                       │
  │                         │                       │
  │── WS connect ──────────→│                       │
  │                         │                       │
  │── { action: "load",    →│── Cast content URL ──→│
  │    url: "movie.m3u8" }  │                       │
  │                         │                       │
  │── { action: "pause" } →│── Pause command ─────→│
  │                         │                       │
  │←── { position: 3600 } ──│←── Position update ───│
```

---

## 📊 Infrastructure Scale

| Resource | Spec |
|---------|------|
| API Servers | 2-4 VPS (8 core, 32GB RAM each) |
| DB Servers | 1 MongoDB cluster (3 nodes) |
| Redis | 1 Redis cluster (HA) |
| CDN Bandwidth | 500TB - 2PB/month |
| Monthly Cost | \$15,000 - \$80,000 |
| Uptime Target | 99.5% (not enterprise grade) |

