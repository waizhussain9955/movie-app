# 🌐 CDN Strategy & Streaming Architecture

## Overview
StreamMax ka CDN aur streaming infrastructure design — fast, reliable, aur cost-effective.

---

## 🏗️ CDN Architecture

```
                    USER
                     │
                     ▼
            ┌─────────────────┐
            │   Cloudflare    │
            │   Edge Node     │  ← Closest to user
            │   (100+ PoPs)   │
            └────────┬────────┘
                     │
          ┌──────────┴───────────┐
          │                      │
   ┌──────▼──────┐       ┌───────▼──────┐
   │  BunnyCDN   │       │  Cloudflare  │
   │  (Video)    │       │  R2 (Files)  │
   │  Pull Zone  │       │  (Posters,   │
   │             │       │   Thumbs)    │
   └──────┬──────┘       └──────────────┘
          │
   ┌──────▼──────┐
   │   Origin    │
   │   Server    │
   │  (MinIO /   │
   │   Storage)  │
   └─────────────┘
```

---

## 📺 HLS Streaming Flow

### How HLS Works
```
1. App requests: GET /v1/stream/{movie_id}?quality=1080p
2. Backend signs CDN URL (4-hour expiry)
3. Backend returns: { url: "https://cdn.streammax.app/movies/xxx/1080p/index.m3u8?token=..." }
4. App opens m3u8 in video player
5. Player fetches: index.m3u8 → gets segment list
6. Player downloads segments (10s each) on demand
7. Player buffers 3 segments ahead
8. If segment fails → retry → switch server
```

### HLS Master Playlist Structure
```
# index.m3u8 (Master playlist)
#EXTM3U
#EXT-X-VERSION:3

# 4K
#EXT-X-STREAM-INF:BANDWIDTH=20000000,RESOLUTION=3840x2160,CODECS="avc1.640028,mp4a.40.2"
4k/playlist.m3u8

# 1080p
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
1080p/playlist.m3u8

# 720p
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720,CODECS="avc1.42E01E,mp4a.40.2"
720p/playlist.m3u8

# 480p
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=854x480,CODECS="avc1.42E01E,mp4a.40.2"
480p/playlist.m3u8

# 360p
#EXT-X-STREAM-INF:BANDWIDTH=600000,RESOLUTION=640x360,CODECS="avc1.42E00C,mp4a.40.2"
360p/playlist.m3u8
```

---

## 🔒 CDN URL Signing

### HMAC-based URL Signing (Cloudflare / BunnyCDN)
```typescript
// streamService.ts

import crypto from 'crypto';

const CDN_SECRET = process.env.CDN_SIGNING_SECRET!;
const CDN_BASE_URL = 'https://cdn.streammax.app';

export function signCdnUrl(
  path: string,
  deviceId: string,
  expiryHours: number = 4
): string {
  const expires = Math.floor(Date.now() / 1000) + (expiryHours * 3600);
  const deviceHash = crypto.createHash('md5').update(deviceId).digest('hex').slice(0, 8);
  
  const message = `${path}:${expires}:${deviceHash}`;
  const token = crypto
    .createHmac('sha256', CDN_SECRET)
    .update(message)
    .digest('base64url');
  
  return `${CDN_BASE_URL}${path}?token=${token}&expires=${expires}&d=${deviceHash}`;
}

// Usage:
// signCdnUrl('/movies/tt1234567/1080p/index.m3u8', 'device-uuid-here')
// → https://cdn.streammax.app/movies/tt1234567/1080p/index.m3u8?token=xxx&expires=1234&d=abc123
```

---

## 💰 CDN Cost Optimization

### Strategy 1: Tiered Quality
```
Free users → Max 720p (lower bandwidth)
Premium    → Up to 4K (higher bandwidth, more revenue)

720p cost per hour: ~1.5 GB → $0.015
1080p cost per hour: ~3 GB  → $0.030
4K cost per hour:   ~15 GB  → $0.15
```

### Strategy 2: Cache Optimization
```
Cloudflare Cache Rules:
- .m3u8 playlist files:  Cache-Control: max-age=0 (don't cache — dynamic)
- .ts segment files:     Cache-Control: max-age=86400 (cache 24h)
- Posters/thumbs:        Cache-Control: max-age=604800 (cache 1 week)
- API responses:         Cache-Control: max-age=300 (5 min for lists)

Result: ~70% of .ts requests served from edge cache
Cost reduction: ~70%
```

### Strategy 3: Cloudflare R2 for Static Assets
```
R2 Pricing:
- Storage: $0.015/GB/month
- Egress: FREE (no bandwidth charges for Cloudflare CDN)
- Operations: $0.36/million requests

vs AWS S3 + CloudFront:
- Storage: $0.023/GB
- Egress: $0.085/GB
- Much more expensive!

Use R2 for: Posters, thumbnails, subtitle files, app assets
Use BunnyCDN for: Video files (better video CDN, cheaper for large video)
```

### Cost Comparison
```
BunnyCDN:
  - Storage: €0.01/GB/month
  - Traffic: €0.01/GB (Europe), €0.03/GB (US)
  - 100TB/month = €1,000

Cloudflare Stream:
  - Storage: $5/1000 min stored
  - Delivery: $1/1000 min delivered
  - Expensive for large library

Recommendation: BunnyCDN for video + Cloudflare R2 for images
```

---

## 📊 Bandwidth Planning

### Per User Estimates
```
Average session: 90 minutes
720p bitrate:   2.5 Mbps → 1.7 GB/session
1080p bitrate:  5 Mbps   → 3.4 GB/session
Average mix:    ~2.5 GB/session
```

### Monthly Bandwidth by User Count
```
1,000 DAU:    2,500 GB  = 2.5 TB    → ~$25/month
10,000 DAU:   25,000 GB = 25 TB     → ~$250/month
100,000 DAU:  250 TB                → ~$2,500/month
1M DAU:       2,500 TB              → ~$25,000/month
```

---

## 🔄 Multi-Server Failover

```
App Logic — Server Selection:
  
1. App gets server list from API
2. Servers sorted by: priority > health_score > user_region
3. Try Server 1
4. If error/timeout (5s) → Try Server 2
5. If Server 2 fails → Try Server 3
6. If all fail → Show "No stream available" error
7. Report failure to backend

Backend Server Health Score:
  - Starts at 100
  - Successful play: +1
  - Failed request: -10
  - Response time > 3s: -2
  - Servers below score 20 → marked inactive
```

---

## 🌍 Multi-CDN Strategy (Advanced)

```
For global performance:
  
  User in Asia    → CDN Asia nodes first
  User in Europe  → CDN Europe nodes first
  User in US      → CDN US nodes first

Implementation:
  - Cloudflare geo-routing
  - Multiple BunnyCDN pull zones (US, EU, APAC)
  - API returns region-specific CDN URLs
  
  GET /stream/{id}?quality=1080p
  X-User-Region: ap (from Cloudflare geo header)
  
  Response: { url: "https://cdn-ap.streammax.app/..." }
```

---

## 📡 Adaptive Bitrate (ABR)

```
HLS supports ABR — player automatically switches quality based on:
  - Available bandwidth (measured by download speed)
  - Buffer level (if buffer low → switch to lower quality)
  - CPU performance
  
Flutter (better_player) ABR config:
  
  BetterPlayerDataSource(
    BetterPlayerDataSourceType.network,
    masterPlaylistUrl,
    videoFormat: BetterPlayerVideoFormat.hls,
    cacheConfiguration: BetterPlayerCacheConfiguration(
      useCache: true,
      maxCacheFileSize: 20 * 1024 * 1024,  // 20MB cache
    ),
    bufferingConfiguration: BetterPlayerBufferingConfiguration(
      minBufferMs: 15000,     // 15 seconds min buffer
      maxBufferMs: 60000,     // 60 seconds max buffer
    ),
  );
```

