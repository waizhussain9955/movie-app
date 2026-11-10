# 🖥️ 02 — StreamMax Backend REST API Specification

## 📌 Overview
StreamMax ka central Node.js/Express backend metadata aggregation, server routing, caching, aur stream resolution ke liye centralized API Gateway ke taur par act karta hai.

---

## 🌐 Base URL & Environments

```
Local Development:  http://localhost:5000/api
Staging Cluster:    https://staging-api.streammax.internal/api/v1
Production Edge:    https://api.streammax.app/v1
```

### Standard Response Envelope
Tamam successful aur error responses ek predictable JSON envelope follow karte hain:

```json
// Success Response
{
  "success": true,
  "timestamp": "2026-11-10T05:15:00.000Z",
  "data": { ... }
}

// Error Response
{
  "success": false,
  "timestamp": "2026-11-10T05:15:00.000Z",
  "error": {
    "code": "STREAM_NOT_FOUND",
    "message": "No active playback source was resolved for this title.",
    "status": 404
  }
}
```

---

## 🔌 API Endpoints Reference

### 1. Unified Home Feed
Client application ko ek hi single network request mein pura home screen feed provide karta hai.

```http
GET /api/home
Headers:
  Accept: application/json
```

#### Query Parameters:
* `language` (optional, default: `en-US`): Content locale.
* `refresh` (optional, boolean): Bypass Redis cache if `true`.

#### Response (200 OK):
```json
{
  "success": true,
  "data": {
    "hero": [
      {
        "id": 1022789,
        "title": "Inside Out 2",
        "backdrop": "https://image.tmdb.org/t/p/original/stKGOmPAg2kQxL9nFw2FqV28r3j.jpg",
        "rating": 7.6,
        "mediaType": "movie"
      }
    ],
    "trending": [ ... ],
    "series": [ ... ],
    "bollywood": [ ... ],
    "topRated": [ ... ]
  }
}
```

---

### 2. Search & Filter
Movies aur TV shows ko title, keyword, ya audio language ke tehat search karta hai.

```http
GET /api/search?q={query}&type={movie|tv|all}&page={page}&audio={hi|en}
```

#### Request Example:
```http
GET /api/search?q=Money%20Heist&audio=hi
```

#### Processing Pipeline:
1. **Query Normalizer:** Removes words like `"watch"`, `"stream"`, `"in hindi"`.
2. **Catalog Lookup:** Queries TMDB Multi-search with sanitized string.
3. **Audio Filter Tagging:** Agar user ne `audio=hi` specify kiya ho, toh response objects mein `hasHindiAudio: true` flag tag ho jata hai.

---

### 3. Movie / TV Show Details
Kisi specific media item ka complete information payload fetch karta hai.

```http
GET /api/movies/:id?type={movie|tv}
```

#### Response Payload (200 OK):
```json
{
  "success": true,
  "data": {
    "id": 71446,
    "title": "Money Heist",
    "originalTitle": "La Casa de Papel",
    "overview": "To carry out the biggest heist in history...",
    "poster": "https://image.tmdb.org/t/p/w500/reKs8y4mJwXgP7bfX9aoer5xs4n.jpg",
    "backdrop": "https://image.tmdb.org/t/p/original/gFZri2YbFUReXD6y7MkZYzKf0ix.jpg",
    "rating": 8.2,
    "releaseDate": "2017-05-02",
    "mediaType": "tv",
    "totalSeasons": 5,
    "genres": ["Crime", "Drama"],
    "cast": [
      { "name": "Álvaro Morte", "character": "The Professor" }
    ]
  }
}
```

---

### 4. TV Show Season & Episodes
Series ke specific season ke tamam episodes ki list return karta hai.

```http
GET /api/tv/:id/season/:seasonNumber
```

#### Response Payload (200 OK):
```json
{
  "success": true,
  "data": {
    "seriesId": 71446,
    "seasonNumber": 1,
    "episodes": [
      {
        "episodeNumber": 1,
        "title": "Episode 1",
        "overview": "The Professor recruits eight thieves...",
        "runtime": 47,
        "stillPath": "https://image.tmdb.org/t/p/w500/xGex15g8eJpI02iF...jpg"
      }
    ]
  }
}
```

---

### 5. Stream Source Resolver
Client player ke liye verified, clean streaming links aur available audio tracks generate karta hai.

```http
POST /api/stream/resolve
Content-Type: application/json
```

#### Request Body:
```json
{
  "tmdbId": 71446,
  "mediaType": "tv",
  "season": 1,
  "episode": 1,
  "preferredAudio": "hi"
}
```

#### Response (200 OK):
```json
{
  "success": true,
  "data": {
    "title": "Money Heist - S01E01",
    "primaryStream": {
      "name": "Server 1 (Dual Audio VIP)",
      "format": "hls",
      "streamUrl": "https://cdn.streammax.internal/hls/71446_s1e1/master.m3u8",
      "isDirectHls": true,
      "defaultAudio": "hi",
      "availableAudioTracks": ["en", "hi", "es", "ta", "te"]
    },
    "fallbackServers": [
      {
        "name": "Server 2 (Embed VidSrc)",
        "format": "iframe",
        "streamUrl": "https://vidsrc.me/embed/tv?tmdb=71446&season=1&episode=1",
        "isDirectHls": false
      }
    ]
  }
}
```

---

## 🛡️ Security & Ad Sanitization Middleware
Backend server per built-in response sanitization layers implement ki gayi hain:
1. **Adware / Redirect Whitelist:** Stream URLs sirf verified content delivery hostnames (CDN) allow karti hain.
2. **Referer & Origin Spoofing:** Third-party upstream CDNs ke liye backend safe proxy headers inject karta hai taake mobile client per CORS ya 403 Forbidden errors na aayen.
3. **No Adult Content Injection:** Upstream servers se aane wale kisi bhi popup ya redirection header ko sanitize kiya jata hai.

