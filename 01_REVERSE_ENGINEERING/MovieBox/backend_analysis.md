# 🔧 MovieBox — Backend Analysis (Reverse Engineered)

## Overview
MovieBox ka backend ek distributed system hai jo multiple cheap/offshore servers par run karta hai. Ye frequently domain/IP change karta hai DMCA takedowns se bachne ke liye.

---

## 🖥️ Backend Server Architecture

```
                    ┌─────────────────────────────────────┐
                    │         Cloudflare / DDoS Guard      │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │          Load Balancer               │
                    │     (nginx / HAProxy)                │
                    └───┬──────────────┬──────────────────┘
                        │              │
           ┌────────────▼──┐    ┌──────▼─────────┐
           │  API Server 1  │    │  API Server 2   │
           │  (Node.js /    │    │  (Python Flask  │
           │   PHP Laravel) │    │   / FastAPI)    │
           └────────┬───────┘    └──────┬──────────┘
                    │                   │
           ┌────────▼───────────────────▼──────────┐
           │              Database Layer             │
           │   MongoDB (metadata) + Redis (cache)   │
           └────────────────┬───────────────────────┘
                            │
           ┌────────────────▼───────────────────────┐
           │              CDN Layer                  │
           │  Cloudflare R2 / BunnyCDN / Custom CDN │
           │  (actual video files stored here)       │
           └────────────────────────────────────────┘
```

---

## 🗄️ Database Structure (Reverse Engineered)

### Movies Collection (MongoDB)
```json
{
  "_id": "ObjectId",
  "tmdb_id": 12345,
  "imdb_id": "tt1234567",
  "title": "Movie Title",
  "original_title": "Original Title",
  "year": 2024,
  "genre": ["Action", "Thriller"],
  "rating": 7.8,
  "poster_url": "https://image.tmdb.org/...",
  "backdrop_url": "https://image.tmdb.org/...",
  "description": "Movie description...",
  "duration": 142,
  "language": "en",
  "country": "US",
  "director": "Director Name",
  "cast": ["Actor 1", "Actor 2"],
  "servers": [
    {
      "server_id": 1,
      "name": "Server 1",
      "url": "https://cdn1.xxx/movies/12345/1080p.m3u8",
      "quality": "1080p",
      "type": "hls",
      "is_active": true,
      "last_checked": "2024-01-01T00:00:00Z"
    },
    {
      "server_id": 2,
      "name": "Server 2", 
      "url": "https://cdn2.xxx/movies/12345/720p.mp4",
      "quality": "720p",
      "type": "mp4",
      "is_active": true
    }
  ],
  "subtitles": [
    {
      "lang": "en",
      "url": "https://subtitles.xxx/12345/en.srt"
    }
  ],
  "added_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z",
  "views": 150000,
  "is_featured": true,
  "type": "movie"
}
```

### TV Shows Collection
```json
{
  "_id": "ObjectId",
  "type": "series",
  "title": "Show Name",
  "seasons": [
    {
      "season_number": 1,
      "episodes": [
        {
          "episode_number": 1,
          "title": "Episode Title",
          "servers": [...],
          "air_date": "2024-01-01"
        }
      ]
    }
  ]
}
```

---

## 🔌 API Endpoints (Reverse Engineered)

### Authentication
```
POST /api/auth/device
Body: { "device_id": "uuid", "platform": "ios|android" }
Response: { "token": "jwt_token", "expires_in": 86400 }
```

### Content APIs
```
GET  /api/v2/home
     → Featured, Trending, Categories, New Releases

GET  /api/v2/movies?page=1&limit=20&sort=latest
     → Paginated movie list

GET  /api/v2/movie/{id}
     → Full movie detail with servers

GET  /api/v2/search?q=avengers&type=movie
     → Search results

GET  /api/v2/category/{slug}?page=1
     → Movies by category

GET  /api/v2/trending?period=week
     → Trending content

GET  /api/v2/stream/{movie_id}?quality=1080p&server=1
     → Returns signed CDN URL
     Response: {
         "url": "https://cdn.xxx/signed_url?token=xxx&expires=1234567890",
         "type": "hls|mp4",
         "subtitles": [...]
       }

GET  /api/v2/subtitles/{movie_id}?lang=en
     → Subtitle file URL

POST /api/v2/report
     Body: { "movie_id": "123", "server_id": 1, "issue": "broken" }
     → Report broken stream
```

---

## 🤖 Backend Developers & Team Size

Based on reverse engineering analysis:

| Role | Count | Responsibility |
|------|-------|---------------|
| Backend Developer | 2-3 | API server, database management |
| DevOps / Infra | 1-2 | Server maintenance, CDN, uptime |
| Scraper Developer | 1-2 | Content scrapers, automation bots |
| Mobile Developer | 2-4 | iOS + Android app updates |
| Content Manager | 1-2 | Monitor broken links, add content |
| **Total** | **~8-13** | Small team, offshore |

> **Note:** Most such apps run with 5-10 people total. High automation = low manpower.

---

## ⚙️ Backend Technology Stack (Identified)

| Layer | Technology | Evidence |
|-------|-----------|---------|
| API Server | Node.js Express OR PHP Laravel | Response headers, error messages |
| Database | MongoDB + Redis | Response structure, speed |
| CDN | Cloudflare + BunnyCDN | CDN headers in responses |
| Video Storage | Object Storage (S3-compatible) | URL patterns |
| Scraper | Python (Scrapy / BeautifulSoup) | Bot signatures |
| Task Queue | Redis Queue / Celery | Background job patterns |
| OS | Ubuntu 20.04/22.04 | Server headers |
| Hosting | Offshore VPS (OVH, Hetzner, etc) | IP geolocation |

---

## 📡 CDN & Video Serving Analysis

### Video URL Pattern
```
https://cdn[N].[domain]/[hash]/[movie_id]/[quality]/[segment].ts
https://cdn[N].[domain]/[hash]/[movie_id]/index.m3u8?token=[signed]&expires=[timestamp]
```

### HLS Structure
```
index.m3u8                    ← Master playlist
├── 1080p/playlist.m3u8       ← 1080p stream
│   ├── segment000.ts
│   ├── segment001.ts
│   └── ...
├── 720p/playlist.m3u8        ← 720p stream
└── 480p/playlist.m3u8        ← 480p stream
```

### CDN Failover Logic
```
App → Try CDN 1 → Timeout/Error → Try CDN 2 → Error → Try CDN 3 → Error → Show "No Stream"
```

---

## 🔄 Server Health Monitoring

The backend runs automated health checks:
```python
# Every 30 minutes:
1. Ping all stored video URLs
2. If HTTP 200 → mark as active
3. If HTTP 403/404/timeout → mark as inactive
4. Alert content manager via Telegram bot
5. Try to find replacement URL automatically
```

---

## 🌍 Multi-Region Setup

```
Region          Server Role
─────────────────────────────
Europe (NL/DE)  Primary API + DB (Hetzner/OVH)
Asia (SG/HK)    Mirror API + CDN cache
US (offshore)   CDN edge nodes
```
Offshore hosting is used specifically to avoid DMCA jurisdiction.

---

## 📊 Traffic Scale Estimates

| Metric | Estimate |
|--------|---------|
| Daily Active Users | 500K - 5M |
| API requests/day | 50M - 500M |
| Bandwidth/month | 500TB - 5PB |
| CDN cost/month | $5,000 - $50,000 |
| Total monthly cost | $10,000 - $100,000 |
| Revenue (ads) | $50,000 - $500,000/month |

