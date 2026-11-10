# 📥 NetMirror — Content Pipeline Analysis

## Overview
NetMirror content pipeline MovieBox se alag hai — ye IPTV, extracted URLs, aur self-hosted streams sab manage karta hai.

---

## 📺 Content Sources

```
NetMirror Content Sources
├── 1. Self-hosted Movie Library (same as MovieBox)
├── 2. IPTV M3U Playlists (live TV channels)
├── 3. Browser Video Extraction (yt-dlp)
├── 4. User-submitted M3U links
└── 5. Partner CDN feeds
```

---

## 🔄 Movie Content Pipeline

### Same as MovieBox (see MovieBox/content_pipeline.md)
- TMDB metadata fetching
- Video scraping from piracy sources
- FFmpeg encoding to HLS
- CDN upload

---

## 📡 IPTV Content Pipeline

```
Step 1: M3U Source Collection
  - Collect free IPTV M3U playlists from public repos
  - Sources: github.com/iptv-org/iptv, etc.
  - 50,000+ channels across 200+ countries

Step 2: Channel Validation
  Bot tests each channel URL:
  - HTTP request to stream URL
  - If response = 200 + content-type: video → ACTIVE
  - If timeout/error → INACTIVE (try next mirror)
  - Run every 6 hours

Step 3: Metadata Enrichment
  - Channel name cleanup
  - Logo fetching (from tvdb.com / channellogos)
  - Category tagging (News, Sports, Movies, etc.)
  - Country assignment
  - EPG data fetch (from epg.pw or similar)

Step 4: Database Storage
  Store in IPTV collection:
  {
    name, country, category, logo, stream_url, 
    backup_urls: [], epg_id, is_active, last_checked
  }

Step 5: Serve via API
  GET /v1/iptv/channels → App shows channel list
  → App plays stream_url directly
```

---

## 🌐 Browser Video Extractor Pipeline

```
User enters URL in NetMirror browser
         ↓
App sends URL to backend: POST /v1/extract { url: "..." }
         ↓
Backend runs yt-dlp:
  yt-dlp --dump-json --no-download {url}
         ↓
yt-dlp extracts video metadata + direct URLs
         ↓
Backend returns format list to app:
  [
    { quality: "1080p", url: "...", ext: "mp4" },
    { quality: "720p",  url: "...", ext: "mp4" }
  ]
         ↓
App shows "Cast to TV" or "Download" option
         ↓
User casts URL directly to Chromecast/Smart TV
```

### Sites yt-dlp can extract from (1000+ sites)
- YouTube, Vimeo, Dailymotion
- Twitch, TikTok
- Most video streaming sites
- Direct video links in any webpage

---

## 📊 Content Scale

| Content Type | Count | Update Frequency |
|-------------|-------|-----------------|
| Movies | 20,000-80,000 | 50-100 new/day |
| TV Series | 5,000-20,000 | 10-20 new/day |
| IPTV Channels | 10,000-50,000 | Health check every 6h |
| Live TV Events | Dynamic | Real-time |

