# 🔌 API Specification — StreamMax Backend

## Base URL
```
Production:  https://api.streammax.app/v1
Staging:     https://api-staging.streammax.app/v1
Development: http://localhost:3000/v1
```

## Authentication
```
All protected endpoints require:
Authorization: Bearer {jwt_token}

Token obtained via:
POST /auth/login → returns access_token (24h) + refresh_token (30d)
POST /auth/refresh → new access_token using refresh_token
```

---

## 🔐 Auth Endpoints

### Register
```
POST /auth/register
Content-Type: application/json

Body:
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "username": "moviefan"
}

Response 201:
{
  "user": { "id": "uuid", "email": "...", "username": "..." },
  "access_token": "jwt...",
  "refresh_token": "jwt...",
  "expires_in": 86400
}
```

### Login
```
POST /auth/login
Body: { "email": "...", "password": "..." }
Response: same as register
```

### Social Login
```
POST /auth/google
Body: { "id_token": "google_id_token" }

POST /auth/apple
Body: { "identity_token": "apple_identity_token" }
```

### Device Auth (Anonymous)
```
POST /auth/device
Body: { "device_id": "uuid", "platform": "android|ios" }
Response: { "access_token": "jwt...", "is_anonymous": true }
```

### Refresh Token
```
POST /auth/refresh
Body: { "refresh_token": "jwt..." }
Response: { "access_token": "jwt..." }
```

---

## 🎬 Content Endpoints

### Get Home Feed
```
GET /home
Auth: Optional

Response 200:
{
  "featured": [Movie],
  "trending": [Movie],
  "new_releases": [Movie],
  "continue_watching": [WatchProgress],  // Auth only
  "categories": [Category]
}
```

### Get Movies List
```
GET /movies
Query params:
  page     (int, default: 1)
  limit    (int, default: 20, max: 50)
  sort     (string: latest|trending|rating|title)
  genre    (string: action|drama|horror|...)
  year     (int: 2024)
  quality  (string: hd|4k)
  lang     (string: en|ar|fr|...)

Response 200:
{
  "data": [Movie],
  "pagination": {
    "current_page": 1,
    "total_pages": 50,
    "total_items": 1000,
    "has_next": true
  }
}
```

### Get Single Movie
```
GET /movies/{id}
Auth: Optional

Response 200:
{
  "id": "uuid",
  "title": "Movie Title",
  "original_title": "...",
  "year": 2024,
  "duration": 142,
  "rating": 8.5,
  "imdb_id": "tt1234567",
  "tmdb_id": 12345,
  "genres": ["Action", "Thriller"],
  "language": "en",
  "country": "US",
  "description": "Plot description...",
  "poster_url": "https://cdn.streammax.app/posters/...",
  "backdrop_url": "https://cdn.streammax.app/backdrops/...",
  "trailer_url": "https://youtube.com/watch?v=...",
  "director": "Director Name",
  "cast": [
    { "name": "Actor Name", "character": "Character", "photo": "url" }
  ],
  "servers": [
    { "id": 1, "name": "Server 1", "quality": "1080p", "is_active": true }
  ],
  "subtitles": [
    { "lang": "en", "label": "English", "url": "..." }
  ],
  "is_bookmarked": false,  // Auth only
  "watch_progress": null    // Auth only
}
```

### Get Stream URL
```
GET /stream/{movie_id}?server=1&quality=1080p
Auth: Required (or device token)

Response 200:
{
  "url": "https://cdn.streammax.app/signed/movie.m3u8?token=xxx&expires=1234567890",
  "type": "hls|mp4",
  "quality": "1080p",
  "expires_at": 1234567890,
  "subtitles": [
    { "lang": "en", "url": "..." }
  ]
}

Error 404: { "error": "stream_not_found" }
Error 503: { "error": "server_unavailable" }
```

### Search
```
GET /search?q={query}&type=all&page=1
Query params:
  q       (string, required) — search term
  type    (string: all|movie|series|person)
  page    (int, default: 1)

Response 200:
{
  "query": "avengers",
  "results": {
    "movies": [Movie],
    "series": [Series],
    "persons": [Person]
  },
  "total": 45
}
```

### Get Categories
```
GET /categories
Response 200:
{
  "data": [
    { "id": "action", "name": "Action", "icon": "🎯", "count": 2340 },
    { "id": "drama",  "name": "Drama",  "icon": "🎭", "count": 1890 }
  ]
}
```

### Get Trending
```
GET /trending?period=day|week|month
Response 200: { "data": [Movie] }
```

---

## 📺 TV Series Endpoints

### Get Series
```
GET /series/{id}
Response: same as Movie + seasons array

GET /series/{id}/season/{season_number}
Response: { "episodes": [Episode] }

GET /series/{id}/season/{s}/episode/{e}
Response: { episode detail + servers }

GET /stream/episode/{episode_id}?server=1
Response: same as movie stream
```

---

## ⬇️ Download Endpoints

### Get Download URL (Pre-signed)
```
POST /downloads/prepare
Auth: Required
Body:
{
  "movie_id": "uuid",
  "quality": "720p",
  "server": 1
}

Response 200:
{
  "download_id": "uuid",
  "type": "hls|mp4",
  "manifest_url": "...",   // for HLS: m3u8 with all segment URLs
  "direct_url": "...",      // for MP4: direct file URL
  "file_size": 1073741824,  // bytes
  "expires_at": 1234567890
}
```

---

## 👤 User Endpoints

### Get Profile
```
GET /user/profile
Auth: Required

Response 200:
{
  "id": "uuid",
  "email": "...",
  "username": "...",
  "avatar": "url",
  "created_at": "...",
  "subscription": "free|premium",
  "subscription_expires": null
}
```

### Update Profile
```
PATCH /user/profile
Auth: Required
Body: { "username": "new_name", "avatar": "base64_image" }
```

### Watchlist
```
GET  /user/watchlist?page=1       → Get watchlist
POST /user/watchlist              → Add movie
     Body: { "movie_id": "uuid", "type": "movie|series" }
DELETE /user/watchlist/{movie_id} → Remove from watchlist
```

### Watch History & Progress
```
GET /user/history?page=1          → Watch history

POST /user/progress
Auth: Required
Body:
{
  "content_id": "uuid",
  "content_type": "movie|episode",
  "position": 3600,          // seconds watched
  "duration": 7200,          // total duration
  "completed": false
}

Response 200: { "saved": true }
```

---

## 📺 IPTV Endpoints

```
GET /iptv/channels?country=us&category=sports&page=1
GET /iptv/categories
GET /iptv/epg?channel_id={id}&date=2024-01-01
GET /iptv/m3u?country=us    → Download full M3U playlist
```

---

## 🌐 Video Extractor Endpoint

```
POST /extract
Auth: Required (rate limited: 20/hour)
Body: { "url": "https://any-website.com/video-page" }

Response 200:
{
  "title": "Extracted Video Title",
  "thumbnail": "url",
  "duration": 7200,
  "formats": [
    { "quality": "1080p", "url": "...", "ext": "mp4", "size": 1073741824 }
  ]
}

Error 422: { "error": "no_video_found" }
Error 429: { "error": "rate_limit_exceeded" }
```

---

## 🚨 Report Endpoint

```
POST /report
Body:
{
  "content_id": "uuid",
  "server_id": 1,
  "issue": "broken_link|low_quality|wrong_content|other",
  "description": "Optional description"
}
Response 200: { "ticket_id": "uuid", "message": "Report received" }
```

---

## 📊 Response Models

### Movie Object
```json
{
  "id": "uuid",
  "title": "string",
  "year": "number",
  "duration": "number (seconds)",
  "rating": "number (0-10)",
  "genres": ["string"],
  "poster_url": "string",
  "backdrop_url": "string",
  "type": "movie|series"
}
```

### Error Response
```json
{
  "error": "error_code",
  "message": "Human readable message",
  "details": {}
}
```

---

## ⚡ Rate Limits

| Endpoint | Limit |
|---------|-------|
| /auth/* | 10 req/min |
| /search | 60 req/min |
| /stream | 30 req/min |
| /extract | 20 req/hour |
| /report | 10 req/hour |
| All others | 300 req/min |

---

## 🔒 HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (invalid params) |
| 401 | Unauthorized (no/invalid token) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 422 | Unprocessable Entity |
| 429 | Rate Limit Exceeded |
| 500 | Internal Server Error |
| 503 | Service Unavailable (CDN/stream down) |

