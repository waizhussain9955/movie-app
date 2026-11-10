# 🗄️ Database Schema — StreamMax

## Database Technology
- **Primary DB:** PostgreSQL 15 (structured data: users, subscriptions)
- **Content DB:** MongoDB 7 (movies, series — flexible schema)
- **Cache:** Redis 7 (sessions, frequently accessed data)
- **Search:** Elasticsearch 8 (full-text search)
- **File Storage:** MinIO / AWS S3 compatible

---

## 📊 PostgreSQL Schema (Users & Auth)

### users table
```sql
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         VARCHAR(255) UNIQUE NOT NULL,
  username      VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255),                    -- NULL if social login
  avatar_url    VARCHAR(500),
  role          VARCHAR(20) DEFAULT 'user',       -- user|admin|moderator
  is_active     BOOLEAN DEFAULT true,
  is_verified   BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  last_login_at TIMESTAMPTZ
);

CREATE INDEX idx_users_email ON users(email);
```

### social_logins table
```sql
CREATE TABLE social_logins (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  provider    VARCHAR(20) NOT NULL,  -- google|apple|facebook
  provider_id VARCHAR(255) NOT NULL,
  UNIQUE(provider, provider_id)
);
```

### device_sessions table
```sql
CREATE TABLE device_sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  device_id   VARCHAR(255) NOT NULL,
  device_name VARCHAR(100),
  platform    VARCHAR(20),           -- android|ios|web
  fcm_token   VARCHAR(500),          -- for push notifications
  is_anonymous BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ DEFAULT NOW()
);
```

### subscriptions table
```sql
CREATE TABLE subscriptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
  plan            VARCHAR(20) NOT NULL,  -- free|premium|premium_plus
  status          VARCHAR(20) DEFAULT 'active',  -- active|cancelled|expired
  starts_at       TIMESTAMPTZ NOT NULL,
  expires_at      TIMESTAMPTZ NOT NULL,
  payment_method  VARCHAR(50),
  transaction_id  VARCHAR(255),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_expires ON subscriptions(expires_at);
```

### watch_history table
```sql
CREATE TABLE watch_history (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  content_id    VARCHAR(50) NOT NULL,   -- MongoDB ObjectId
  content_type  VARCHAR(20) NOT NULL,   -- movie|episode
  position      INTEGER DEFAULT 0,      -- seconds watched
  duration      INTEGER,                -- total duration in seconds
  is_completed  BOOLEAN DEFAULT false,
  watched_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, content_id)
);

CREATE INDEX idx_watch_history_user ON watch_history(user_id, watched_at DESC);
```

### watchlist table
```sql
CREATE TABLE watchlist (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  content_id   VARCHAR(50) NOT NULL,
  content_type VARCHAR(20) NOT NULL,
  added_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, content_id)
);

CREATE INDEX idx_watchlist_user ON watchlist(user_id, added_at DESC);
```

### reports table
```sql
CREATE TABLE reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  content_id  VARCHAR(50) NOT NULL,
  server_id   INTEGER,
  issue       VARCHAR(50) NOT NULL,
  description TEXT,
  status      VARCHAR(20) DEFAULT 'open',  -- open|reviewing|resolved
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 📦 MongoDB Schema (Content)

### movies collection
```javascript
{
  _id: ObjectId,
  
  // Identifiers
  imdb_id: "tt1234567",
  tmdb_id: 12345,
  slug: "movie-title-2024",
  
  // Basic Info
  title: "Movie Title",
  original_title: "Original Title",
  year: 2024,
  release_date: ISODate("2024-01-15"),
  duration: 8520,  // seconds (142 minutes)
  language: "en",
  country: "US",
  
  // Ratings
  imdb_rating: 8.5,
  tmdb_rating: 7.9,
  vote_count: 15000,
  
  // Classification
  genres: ["Action", "Thriller", "Sci-Fi"],
  tags: ["superhero", "based-on-comic"],
  age_rating: "PG-13",
  
  // Media
  poster_url: "https://cdn.streammax.app/posters/tt1234567.jpg",
  backdrop_url: "https://cdn.streammax.app/backdrops/tt1234567.jpg",
  trailer_url: "https://youtube.com/watch?v=xxxxx",
  
  // People
  director: ["Director Name"],
  writers: ["Writer Name"],
  cast: [
    { name: "Actor Name", character: "Character Name", order: 1, photo: "url" }
  ],
  
  // Streams
  servers: [
    {
      server_id: 1,
      name: "Server HD",
      quality: "1080p",
      type: "hls",  // hls|mp4
      url: "https://cdn.streammax.app/movies/tt1234567/1080p/index.m3u8",
      size: 2147483648,  // bytes (2GB)
      is_active: true,
      last_checked: ISODate("2024-01-01"),
      report_count: 0
    },
    {
      server_id: 2,
      name: "Server SD",
      quality: "720p",
      type: "mp4",
      url: "https://cdn2.streammax.app/movies/tt1234567/720p.mp4",
      size: 1073741824,
      is_active: true,
      last_checked: ISODate("2024-01-01"),
      report_count: 0
    }
  ],
  
  // Subtitles
  subtitles: [
    { lang: "en", label: "English", url: "https://subs.streammax.app/tt1234567/en.vtt" },
    { lang: "ar", label: "Arabic",  url: "https://subs.streammax.app/tt1234567/ar.vtt" }
  ],
  
  // Metadata
  description: "Full plot description...",
  keywords: ["keyword1", "keyword2"],
  
  // Stats
  view_count: 1500000,
  download_count: 250000,
  is_featured: false,
  is_trending: true,
  featured_until: null,
  
  // Timestamps
  content_added_at: ISODate("2024-01-01"),
  updated_at: ISODate("2024-01-01"),
  
  // Type
  type: "movie"
}
```

### series collection
```javascript
{
  _id: ObjectId,
  // ... same base fields as movie ...
  type: "series",
  status: "ongoing|ended|cancelled",
  total_seasons: 5,
  total_episodes: 65,
  
  seasons: [
    {
      season_number: 1,
      title: "Season 1",
      year: 2020,
      poster_url: "...",
      
      episodes: [
        {
          episode_number: 1,
          title: "Episode Title",
          description: "Episode description",
          air_date: ISODate("2020-01-15"),
          duration: 2700,  // 45 minutes
          still_url: "https://cdn.streammax.app/stills/...",
          
          servers: [ /* same as movie servers */ ],
          subtitles: [ /* same as movie subtitles */ ]
        }
      ]
    }
  ]
}
```

### iptv_channels collection
```javascript
{
  _id: ObjectId,
  name: "BBC News",
  country: "GB",
  country_name: "United Kingdom",
  category: "News",
  language: "en",
  logo_url: "https://cdn.streammax.app/logos/bbc-news.png",
  
  streams: [
    {
      url: "https://live.bbc.com/stream.m3u8",
      quality: "HD",
      is_active: true,
      last_checked: ISODate("2024-01-01")
    }
  ],
  
  epg_id: "bbc.news.uk",
  website: "https://bbc.co.uk/news",
  
  is_active: true,
  is_featured: false,
  view_count: 500000
}
```

---

## 🔴 Redis Schema (Cache & Sessions)

```
# Session tokens
sessions:{token} → { user_id, device_id, expires_at }  TTL: 86400

# Content cache (frequently accessed)
movie:{id} → JSON Movie object  TTL: 3600
home_feed → JSON home data  TTL: 300

# Stream URL cache (signed, short-lived)
stream:{movie_id}:{quality}:{server} → CDN URL  TTL: 3600

# Rate limiting
ratelimit:{ip}:{endpoint} → request count  TTL: 60

# User watch progress (fast write, sync to PostgreSQL every 30s)
progress:{user_id}:{content_id} → { position, duration }  TTL: 86400 * 30

# Search trending
trending:searches → sorted set (search_term, score)  No TTL
```

---

## 🔍 Elasticsearch Mapping (Search)

```json
{
  "mappings": {
    "properties": {
      "id":    { "type": "keyword" },
      "title": { "type": "text", "analyzer": "standard" },
      "original_title": { "type": "text" },
      "description": { "type": "text" },
      "year":  { "type": "integer" },
      "genres": { "type": "keyword" },
      "cast":  { "type": "text" },
      "director": { "type": "text" },
      "imdb_rating": { "type": "float" },
      "type":  { "type": "keyword" },
      "language": { "type": "keyword" },
      "is_active": { "type": "boolean" }
    }
  }
}
```

---

## 📈 Data Volumes (Expected)

| Collection | Records | Growth/day |
|-----------|---------|-----------|
| Movies | 50,000 | +100 |
| TV Series | 10,000 | +20 |
| Episodes | 500,000 | +200 |
| IPTV Channels | 20,000 | +50 |
| Users | 100,000 | +500 |
| Watch History | 10M | +50K |
| Reports | 10,000 | +100 |

