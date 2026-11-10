# 🎬 Content Management System — StreamMax

## Overview
Ye document batata hai ke content (movies, series, IPTV) kaise manage hoti hai — from ingestion to delivery.

---

## 📺 Admin CMS Dashboard

```
Admin Panel: https://admin.streammax.app

├── Dashboard (Overview)
│   ├── Total content count
│   ├── Broken streams today
│   ├── New user signups
│   └── Server health status
│
├── Content Management
│   ├── Movies
│   │   ├── Add Movie
│   │   ├── Edit Movie
│   │   ├── Bulk Import
│   │   └── Broken Links
│   ├── TV Series
│   │   ├── Add Series + Episodes
│   │   └── Episode management
│   └── IPTV Channels
│       ├── Add Channels
│       ├── Import M3U
│       └── Channel health
│
├── Stream Management
│   ├── Server Status Board
│   ├── CDN Health
│   └── Add/Remove Servers
│
├── User Management
│   ├── User list
│   ├── Subscriptions
│   └── Reports/Tickets
│
└── Settings
    ├── Featured Content
    ├── App Config
    └── DMCA Removal
```

---

## ➕ Adding a Movie — Manual Process

### Via Admin UI
```
1. Click "Add Movie"
2. Enter IMDB ID or TMDB ID → Auto-fetch metadata
   - System calls TMDB API and fills all fields
3. Review/edit metadata if needed
4. Add stream servers:
   - Enter CDN URL for each quality (1080p, 720p, 480p)
   - Select type (HLS/MP4)
   - Test URL (system auto-tests)
5. Add subtitles (optional):
   - Upload .srt/.vtt file OR enter URL
6. Set as Featured/Trending (optional)
7. Click "Publish"
```

### Via Bulk Import (CSV/JSON)
```
JSON format:
[
  {
    "imdb_id": "tt1234567",
    "servers": [
      { "url": "https://cdn.xxx/movie.m3u8", "quality": "1080p" }
    ]
  }
]

Upload → System fetches metadata → Auto-creates entries
```

---

## 🤖 Automated Content Ingestion

### Content Scraper Bot

```python
# content_scraper.py — Runs every 2 hours

class ContentScraper:
    
    def run(self):
        # 1. Fetch new releases from TMDB
        new_movies = self.fetch_tmdb_new_releases()
        
        for movie in new_movies:
            if self.already_exists(movie['imdb_id']):
                continue
                
            # 2. Find stream sources
            streams = self.find_streams(movie)
            
            if streams:
                # 3. Store in DB
                self.save_movie(movie, streams)
                
                # 4. Notify admin via Telegram
                self.notify(f"New movie added: {movie['title']}")
    
    def find_streams(self, movie):
        """Try multiple sources to find working stream"""
        sources = [
            self.check_partner_cdn(movie['imdb_id']),
            self.scrape_vidsrc(movie['imdb_id']),
            self.scrape_embed_sources(movie['imdb_id']),
        ]
        return [s for s in sources if s is not None]
    
    def scrape_vidsrc(self, imdb_id):
        """Extract from embed providers"""
        # vidsrc.to, vidsrc.me, embedder.to etc.
        url = f"https://vidsrc.to/embed/movie/{imdb_id}"
        # Extract actual m3u8 URL using headless browser
        return self.extract_video_url(url)
```

---

## 🔍 Stream Health Monitoring

### Health Check Bot (Runs every 30 min)
```python
class StreamHealthBot:
    
    def check_all(self):
        movies = db.movies.find({ "servers.is_active": True })
        
        for movie in movies:
            for server in movie['servers']:
                is_healthy = self.test_stream(server['url'])
                
                if not is_healthy:
                    # Mark as inactive
                    db.movies.update(
                        { "_id": movie['_id'], "servers.server_id": server['server_id'] },
                        { "$set": { "servers.$.is_active": False } }
                    )
                    
                    # Try to find replacement
                    new_url = self.find_replacement(movie['imdb_id'], server['quality'])
                    
                    if new_url:
                        # Auto-replace
                        self.update_server_url(movie['_id'], server['server_id'], new_url)
                        self.notify(f"Auto-fixed: {movie['title']} {server['quality']}")
                    else:
                        # Alert content manager
                        self.alert_manager(movie, server)
    
    def test_stream(self, url):
        try:
            if url.endswith('.m3u8'):
                # Test HLS: fetch playlist
                resp = requests.get(url, timeout=10)
                return resp.status_code == 200 and '#EXTM3U' in resp.text
            else:
                # Test MP4: fetch first byte
                resp = requests.head(url, timeout=10)
                return resp.status_code == 200
        except:
            return False
```

---

## 📊 Content Workflow

```
New Movie in Theaters/Released
         ↓
Scraper Bot detects (via TMDB API)
         ↓
Add to "Pending" queue in admin
         ↓
Content Bot tries to find streams automatically
         ↓
     ┌───┴───────────────────────────┐
     │                               │
 Found auto                    Not found
     │                               │
Auto-published              Alert content manager
     │                               │
Health check every 30 min    Manager manually finds URL
     │                               │
     └───────────────────────────────┘
                   ↓
         Stream goes live in app
                   ↓
Users watch / download
                   ↓
If broken link reported by users
                   ↓
   Auto-fix attempt by bot
         ↓
     Fixed? → Done
     Not fixed? → Manual review (24h SLA)
```

---

## 🗑️ DMCA Content Removal Process

```
DMCA Notice Received (email/legal)
         ↓
Admin removes content within 24 hours:
  1. Admin panel → Find movie
  2. Click "DMCA Remove"
  3. Movie marked as dmca_removed = true
  4. All servers/streams deleted
  5. Movie hidden from app immediately
  6. Log removal with notice ID
         ↓
Confirm removal to sender
         ↓
Document in DMCA log
```

---

## 📡 IPTV Channel Management

```
Sources → Import → Validate → Categorize → Publish

Sources:
- github.com/iptv-org/iptv (free, 8000+ channels)
- Custom M3U URLs submitted by users
- Partner IPTV providers

Import:
- POST /admin/iptv/import { "m3u_url": "..." }
- Parse M3U, extract: name, logo, URL, country, group

Validate:
- Test each stream URL (HTTP HEAD request)
- Keep only working streams

Categorize:
- Auto-detect: News, Sports, Movies, Kids, etc.
- Assign country from M3U tags

Publish:
- Save to iptv_channels collection
- Run health check every 6 hours
```

---

## 📈 Content KPIs

| Metric | Target |
|--------|--------|
| Content availability | 95%+ streams working at any time |
| Broken link detection | < 1 hour to detect |
| Auto-fix rate | 70%+ broken links auto-replaced |
| New content added | 50-200 items/day |
| DMCA response time | < 24 hours |
| Stream uptime | 99%+ for featured content |

