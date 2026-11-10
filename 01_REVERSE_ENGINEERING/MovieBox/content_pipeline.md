# 🎥 MovieBox — Content Pipeline Analysis

## Overview
MovieBox mein content kaise aata hai — ye ek multi-step automated process hai. Koi official licensing nahi hai. Content scraping, automation, aur community submissions se aata hai.

---

## 📥 Content Ingestion Pipeline

```
Step 1: Content Discovery
         ↓
Step 2: Metadata Fetching (TMDB/IMDb)
         ↓
Step 3: Video Source Finding
         ↓
Step 4: Video Processing & Encoding
         ↓
Step 5: CDN Upload & Distribution
         ↓
Step 6: Quality Check
         ↓
Step 7: Published to App
```

---

## 🔍 Step 1: Content Discovery

### Where do they find movies?

| Source | Method | Detail |
|--------|--------|--------|
| Public Torrent Sites | Web Scrapers | The Pirate Bay, 1337x, RARBG mirrors |
| Direct Download Sites | Crawlers | Indexleech, Rapidgator, etc. |
| YouTube (some) | yt-dlp bots | For trailers / some free content |
| User Submissions | API endpoint | Community sends video URLs |
| Other piracy sites | Mirror crawlers | Fmovies, Putlocker mirrors |
| Telegram Channels | Telegram bots | Movie release channels |
| Usenet | NZB fetchers | Old school binary newsgroups |

### Automation Bot Flow
```python
# Pseudo-code for their scraper
def discover_new_content():
    sources = [
        "https://1337x.to/trending",
        "https://yts.mx/api/v2/list_movies.json",
        "https://torrent-site-mirror.xyz/movies"
    ]
    
    for source in sources:
        movies = scrape_latest(source)
        for movie in movies:
            if not already_in_db(movie.imdb_id):
                queue_for_processing(movie)
```

---

## 📋 Step 2: Metadata Fetching

### TMDB API Integration
```
New Movie Detected
      ↓
Search TMDB API: GET https://api.themoviedb.org/3/search/movie?query={title}
      ↓
Fetch Full Details: GET https://api.themoviedb.org/3/movie/{tmdb_id}
      ↓
Fetch Images: Posters, Backdrops, Logos
      ↓
Fetch IMDb Rating (via OMDb API or scraping)
      ↓
Fetch Cast & Crew
      ↓
Store in MongoDB
```

### Data Sources for Metadata
| Data | Source |
|------|--------|
| Title, Year, Genre | TMDB API |
| Plot, Director, Cast | TMDB + OMDb |
| IMDb Rating | OMDb API / IMDb scrape |
| Poster Images | TMDB CDN |
| Trailers | YouTube API |
| Subtitles | OpenSubtitles API |

---

## 🎞️ Step 3: Video Source Finding

### Method 1: Direct Encode from Torrent
```
1. Download torrent file
2. Download actual video via libtorrent
3. Store in temp storage
4. Encode to multiple qualities (see Step 4)
```

### Method 2: Stream Ripping from Other Sites
```
1. Find movie on existing streaming site (Fmovies, etc.)
2. Extract video URL using custom extractor
3. Download with yt-dlp or aria2
4. Re-encode and store
```

### Method 3: Direct URL Indexing (Most Common)
```
1. Find existing CDN URLs from other piracy networks
2. Test if URL is live (HTTP 200 check)
3. Store URL directly in DB without re-hosting
4. App serves this URL to users
```
> ⚡ Method 3 is cheapest — no storage cost, just index existing URLs.

---

## 🔄 Step 4: Video Processing & Encoding

### Encoding Pipeline (When Self-Hosting)
```
Input Video (any format)
         ↓
FFmpeg Processing
├── Resolution Check (original quality)
├── Encode 4K  (if source is 4K)   → H.265/HEVC
├── Encode 1080p                    → H.264/H.265
├── Encode 720p                     → H.264
├── Encode 480p                     → H.264
└── Encode 360p                     → H.264
         ↓
HLS Segmentation
├── Split each quality into 10-second .ts segments
├── Create playlist.m3u8 for each quality
└── Create master index.m3u8
         ↓
Upload to CDN/Object Storage
```

### FFmpeg Commands Used
```bash
# Encode 1080p HLS
ffmpeg -i input.mkv \
  -vf scale=1920:1080 \
  -c:v libx264 -crf 23 -preset fast \
  -c:a aac -b:a 128k \
  -hls_time 10 \
  -hls_playlist_type vod \
  -hls_segment_filename '1080p/segment%03d.ts' \
  1080p/index.m3u8

# Encode 720p
ffmpeg -i input.mkv \
  -vf scale=1280:720 \
  -c:v libx264 -crf 24 \
  -hls_time 10 \
  720p/index.m3u8
```

---

## ✅ Step 5: Quality Check

```
Automated QC Bot:
1. Play first 30 seconds of each quality
2. Check video integrity (no corruption)
3. Check audio sync
4. Verify HLS manifest is valid
5. Test from multiple regions (via proxy)
6. If pass → Mark as "published"
7. If fail → Alert content manager
```

---

## 📺 Step 6: Content Management Dashboard

### What Content Managers Do
| Task | Frequency | Tool |
|------|-----------|------|
| Check broken streams | Daily | Internal dashboard |
| Add new movies | Daily | Admin panel |
| Update stream URLs | As needed | Direct DB edit |
| Handle user reports | Daily | Ticket system |
| Monitor CDN health | Real-time | Grafana dashboard |
| Remove DMCA content | Immediate | One-click removal |

### Admin Panel Features
```
Admin Dashboard
├── Content Manager
│   ├── Add Movie/Series
│   ├── Edit Movie Details
│   ├── Manage Servers/URLs
│   ├── Bulk Import (CSV/JSON)
│   └── DMCA Remove
├── Health Monitor
│   ├── Broken Links (auto-detected)
│   ├── CDN Status
│   └── Server Status
├── Analytics
│   ├── Most Watched
│   ├── Broken Reports
│   └── User Activity
└── Settings
    ├── Featured Content
    ├── Trending Algorithm
    └── App Config
```

---

## 📊 Content Scale

| Metric | Estimate |
|--------|---------|
| Total Movies | 10,000 - 100,000 |
| Total TV Shows | 2,000 - 20,000 |
| New content added/day | 50 - 200 items |
| Broken links/day | 5-10% of total |
| Auto-replaced | ~60% |
| Manual intervention | ~40% |

