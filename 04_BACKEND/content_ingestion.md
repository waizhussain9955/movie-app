# 📥 Content Ingestion Pipeline — StreamMax

## Overview
Naye content ko system mein kaise add kiya jata hai — automated aur manual dono.

---

## 🤖 Automated Ingestion System

### Architecture
```
                    ┌─────────────────────────────────┐
                    │        TMDB API Watcher          │
                    │   (Runs every 2 hours)           │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │      New Release Detector        │
                    │  "Is this movie in our DB?"     │
                    └──────────────┬──────────────────┘
                                   │
                        ┌──────────▼──────────┐
                        │   Stream Finder      │
                        │  (Try multiple APIs) │
                        └──────────┬───────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │          Quality Checker         │
                    │  Test stream, check quality      │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │         Save to Database         │
                    │    + Notify Admin via Telegram   │
                    └────────────────────────────────-─┘
```

---

## 🔎 Stream Finder Service

### Free/Legal Embed Sources
```python
# stream_finder.py

EMBED_PROVIDERS = [
    # Free embed providers (some legal, some grey area)
    "https://vidsrc.to/embed/movie/{imdb_id}",
    "https://vidsrc.me/embed/movie?imdb={imdb_id}",
    "https://multiembed.mov/directstream.php?video_id={imdb_id}",
    "https://embed.su/embed/movie/{tmdb_id}",
    "https://2embed.cc/embed/{imdb_id}",
]

class StreamFinder:
    async def find_streams(self, imdb_id: str, tmdb_id: int) -> list[StreamResult]:
        results = []
        
        for provider_template in EMBED_PROVIDERS:
            url = provider_template.format(imdb_id=imdb_id, tmdb_id=tmdb_id)
            
            try:
                stream = await self.extract_stream(url)
                if stream:
                    results.append(stream)
            except Exception as e:
                logger.warning(f"Provider failed: {url} — {e}")
        
        return results
    
    async def extract_stream(self, embed_url: str) -> StreamResult | None:
        """Use yt-dlp to extract actual stream URL from embed page"""
        cmd = [
            'yt-dlp', 
            '--dump-json',
            '--no-download',
            '--quiet',
            embed_url
        ]
        
        result = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await result.communicate()
        
        if result.returncode == 0:
            data = json.loads(stdout)
            return StreamResult(
                url=data['url'],
                quality=data.get('height', 720),
                format=data.get('ext', 'mp4'),
            )
        return None
```

---

## 📋 TMDB Integration

### Fetch New Releases
```python
# tmdb_watcher.py

import httpx
from datetime import datetime, timedelta

TMDB_API_KEY = os.getenv('TMDB_API_KEY')  # Free key from themoviedb.org
TMDB_BASE = "https://api.themoviedb.org/3"

async def fetch_new_releases():
    """Get movies released in the last 7 days"""
    today = datetime.now().strftime('%Y-%m-%d')
    week_ago = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
    
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{TMDB_BASE}/discover/movie",
            params={
                "api_key": TMDB_API_KEY,
                "primary_release_date.gte": week_ago,
                "primary_release_date.lte": today,
                "sort_by": "popularity.desc",
                "page": 1
            }
        )
        
        movies = resp.json()['results']
        return movies

async def fetch_movie_details(tmdb_id: int) -> dict:
    """Get full movie details from TMDB"""
    async with httpx.AsyncClient() as client:
        # Basic details
        movie = (await client.get(
            f"{TMDB_BASE}/movie/{tmdb_id}",
            params={"api_key": TMDB_API_KEY, "language": "en-US"}
        )).json()
        
        # Credits (cast, director)
        credits = (await client.get(
            f"{TMDB_BASE}/movie/{tmdb_id}/credits",
            params={"api_key": TMDB_API_KEY}
        )).json()
        
        # Videos (trailers)
        videos = (await client.get(
            f"{TMDB_BASE}/movie/{tmdb_id}/videos",
            params={"api_key": TMDB_API_KEY}
        )).json()
        
        return {
            "title": movie['title'],
            "original_title": movie['original_title'],
            "year": movie['release_date'][:4],
            "duration": movie['runtime'] * 60,  # to seconds
            "genres": [g['name'] for g in movie['genres']],
            "description": movie['overview'],
            "poster_url": f"https://image.tmdb.org/t/p/w500{movie['poster_path']}",
            "backdrop_url": f"https://image.tmdb.org/t/p/original{movie['backdrop_path']}",
            "imdb_id": movie['imdb_id'],
            "tmdb_id": tmdb_id,
            "rating": movie['vote_average'],
            "director": self._get_director(credits),
            "cast": self._get_cast(credits),
            "trailer_url": self._get_trailer(videos),
            "language": movie['original_language'],
            "country": movie['production_countries'][0]['iso_3166_1'] if movie['production_countries'] else None,
        }

def _get_director(credits: dict) -> str:
    for person in credits.get('crew', []):
        if person['job'] == 'Director':
            return person['name']
    return ''

def _get_cast(credits: dict) -> list:
    return [
        {
            "name": actor['name'],
            "character": actor['character'],
            "photo": f"https://image.tmdb.org/t/p/w185{actor['profile_path']}" if actor['profile_path'] else None,
            "order": actor['order']
        }
        for actor in credits.get('cast', [])[:10]  # Top 10 cast members
    ]
```

---

## 🔄 Full Ingestion Flow

```python
# main_ingestion.py — Runs every 2 hours via cron

async def run_ingestion():
    logger.info("🤖 Starting content ingestion job...")
    
    # 1. Get new releases from TMDB
    new_movies = await fetch_new_releases()
    
    added = 0
    for movie_data in new_movies:
        tmdb_id = movie_data['id']
        
        # 2. Check if already in DB
        existing = await db.movies.find_one({"tmdb_id": tmdb_id})
        if existing:
            continue
        
        # 3. Get full details
        details = await fetch_movie_details(tmdb_id)
        
        # 4. Find streams
        streams = await stream_finder.find_streams(
            details['imdb_id'], 
            tmdb_id
        )
        
        if not streams:
            # Add to "pending" (no stream yet)
            await db.pending_movies.insert_one({
                **details,
                "status": "no_stream",
                "added_at": datetime.now()
            })
            continue
        
        # 5. Save to DB
        await db.movies.insert_one({
            **details,
            "servers": [
                {
                    "server_id": i + 1,
                    "url": stream.url,
                    "quality": f"{stream.quality}p",
                    "type": "mp4",
                    "is_active": True,
                    "last_checked": datetime.now()
                }
                for i, stream in enumerate(streams)
            ],
            "is_featured": False,
            "view_count": 0,
            "type": "movie",
            "content_added_at": datetime.now()
        })
        
        added += 1
        
        # 6. Notify admin
        await send_telegram(
            f"✅ Added: {details['title']} ({details['year']}) — {len(streams)} servers"
        )
    
    logger.info(f"✅ Ingestion complete. Added {added} new movies.")

# Schedule: Run every 2 hours
# crontab: 0 */2 * * * python main_ingestion.py
```

---

## 📊 Ingestion Monitoring

```
Daily Report (sent to Telegram at 9 AM):
  🎬 Daily Content Report
  New movies added: 45
  Pending (no stream): 12
  Broken streams fixed: 8
  Broken streams pending: 3
  Total library: 52,340 movies
  Active streams: 97.2%
```

---

## 🗂️ Subtitle Automation

```python
# subtitle_fetcher.py

OPENSUBTITLES_API_KEY = os.getenv('OPENSUBTITLES_API_KEY')

async def fetch_subtitles(imdb_id: str, languages: list = ['en', 'ar', 'fr']) -> list:
    """Fetch subtitles from OpenSubtitles API"""
    async with httpx.AsyncClient() as client:
        for lang in languages:
            resp = await client.get(
                "https://api.opensubtitles.com/api/v1/subtitles",
                headers={"Api-Key": OPENSUBTITLES_API_KEY},
                params={
                    "imdb_id": imdb_id.replace("tt", ""),
                    "languages": lang,
                    "type": "movie"
                }
            )
            
            data = resp.json()
            if data['data']:
                # Get download URL
                best_sub = data['data'][0]
                download_resp = await client.post(
                    "https://api.opensubtitles.com/api/v1/download",
                    headers={"Api-Key": OPENSUBTITLES_API_KEY},
                    json={"file_id": best_sub['attributes']['files'][0]['file_id']}
                )
                
                download_link = download_resp.json()['link']
                yield {
                    "lang": lang,
                    "label": get_language_label(lang),
                    "url": download_link
                }

# OpenSubtitles free tier: 100 downloads/day
# Paid: $5-20/month for more downloads
```

