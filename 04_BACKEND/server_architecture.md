# 🏗️ Server Architecture — StreamMax Backend

## Overview
StreamMax ka backend microservices-inspired architecture hai lekin monolith se start karenge (simpler to manage).

---

## 🗺️ Architecture Diagram

```
                        INTERNET
                            │
                   ┌────────▼────────┐
                   │   Cloudflare    │
                   │  (DNS + WAF +   │
                   │   DDoS + CDN)   │
                   └────────┬────────┘
                            │
                   ┌────────▼────────┐
                   │   nginx Reverse │
                   │     Proxy       │
                   │  (Rate Limit +  │
                   │   SSL + LB)     │
                   └──┬──────────┬───┘
                      │          │
           ┌──────────▼──┐  ┌────▼──────────┐
           │  API Server  │  │  Stream       │
           │  Node.js     │  │  Server (Go)  │
           │  Port 3000   │  │  Port 4000    │
           └──────┬───────┘  └────┬──────────┘
                  │               │
     ┌────────────┼───────────────┼──────────────┐
     │            │               │              │
┌────▼───┐  ┌─────▼──┐  ┌────────▼──┐  ┌────────▼──┐
│Postgres│  │MongoDB │  │  Redis    │  │Elastics   │
│(Users) │  │(Movies)│  │  (Cache)  │  │(Search)   │
└────────┘  └────────┘  └───────────┘  └───────────┘
                │
       ┌────────▼────────┐
       │  Python Service │
       │  (yt-dlp /      │
       │   Scrapers)     │
       └─────────────────┘
```

---

## 📁 Backend Project Structure

```
streammax-backend/
├── src/
│   ├── config/
│   │   ├── database.ts          ← DB connections
│   │   ├── redis.ts
│   │   └── env.ts               ← Environment variables
│   │
│   ├── plugins/
│   │   ├── auth.ts              ← JWT plugin
│   │   ├── rateLimit.ts
│   │   └── cors.ts
│   │
│   ├── routes/
│   │   ├── auth.ts              ← /auth endpoints
│   │   ├── movies.ts            ← /movies endpoints
│   │   ├── stream.ts            ← /stream endpoints
│   │   ├── search.ts            ← /search endpoint
│   │   ├── user.ts              ← /user endpoints
│   │   ├── iptv.ts              ← /iptv endpoints
│   │   ├── extract.ts           ← /extract endpoint
│   │   └── admin.ts             ← /admin endpoints
│   │
│   ├── services/
│   │   ├── authService.ts       ← Auth business logic
│   │   ├── movieService.ts      ← Movie business logic
│   │   ├── streamService.ts     ← CDN URL signing
│   │   ├── searchService.ts     ← Elasticsearch queries
│   │   ├── userService.ts       ← User management
│   │   ├── extractService.ts    ← yt-dlp integration
│   │   └── notificationService.ts ← Push notifications
│   │
│   ├── models/
│   │   ├── postgresql/
│   │   │   ├── User.ts
│   │   │   ├── Subscription.ts
│   │   │   └── WatchHistory.ts
│   │   └── mongodb/
│   │       ├── Movie.ts
│   │       ├── Series.ts
│   │       └── IptvChannel.ts
│   │
│   ├── middleware/
│   │   ├── auth.ts              ← JWT verification
│   │   ├── rateLimit.ts
│   │   └── validate.ts
│   │
│   ├── jobs/                    ← Background jobs
│   │   ├── healthCheck.ts       ← Stream health checker
│   │   ├── contentScraper.ts    ← New content scraper
│   │   └── cleanupJob.ts        ← Old data cleanup
│   │
│   └── utils/
│       ├── cdn.ts               ← CDN URL signing
│       ├── tmdb.ts              ← TMDB API client
│       ├── telegram.ts          ← Alert bot
│       └── logger.ts
│
├── prisma/
│   └── schema.prisma            ← PostgreSQL schema
│
├── docker-compose.yml
├── Dockerfile
├── package.json
└── .env.example
```

---

## ⚙️ nginx Configuration

```nginx
# /etc/nginx/sites-available/streammax-api

upstream api_servers {
    server 127.0.0.1:3000;
    server 127.0.0.1:3001;  # Second instance for load balancing
    keepalive 32;
}

server {
    listen 80;
    server_name api.streammax.app;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.streammax.app;
    
    ssl_certificate /etc/letsencrypt/live/api.streammax.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.streammax.app/privkey.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;
    limit_req zone=api burst=20 nodelay;
    
    location / {
        proxy_pass http://api_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 30s;
    }
    
    # Larger timeout for stream endpoint
    location /v1/stream {
        proxy_pass http://api_servers;
        proxy_read_timeout 60s;
    }
}
```

---

## 🔄 Background Jobs

### Job 1: Stream Health Checker
```
Schedule: Every 30 minutes
Function: Test all active stream URLs
  - Fetch m3u8 playlist or MP4 HEAD request
  - Mark inactive if fails
  - Try auto-replace
  - Alert on Telegram if can't fix
```

### Job 2: Content Scraper
```
Schedule: Every 2 hours
Function: Check TMDB for new releases
  - Find movies released in last 7 days
  - If not in DB, try to find streams
  - Add to pending queue for review
```

### Job 3: Database Cleanup
```
Schedule: Daily at 2 AM
Function: 
  - Delete expired sessions from Redis
  - Clean up orphaned records
  - Compress old logs
  - Generate daily analytics snapshot
```

### Job 4: Watch Progress Sync
```
Schedule: Every 30 seconds (per active session)
Function:
  - Flush Redis progress data to PostgreSQL
  - Prevents data loss if server restarts
```

---

## 🌡️ Server Scaling Strategy

### Phase 1 (0 - 10K users)
```
Single VPS:
  - 4 CPU cores, 8GB RAM
  - All services on one server
  - Cost: ~€20-30/month
```

### Phase 2 (10K - 100K users)
```
Separate servers:
  - API Server: 2x (4 core, 8GB) ← horizontal scale
  - DB Server: 1x (8 core, 32GB)
  - Redis: 1x managed
  - Cost: ~€100-200/month
```

### Phase 3 (100K+ users)
```
Kubernetes cluster:
  - API pods: auto-scaling (3-10 pods)
  - DB: PostgreSQL HA cluster
  - MongoDB: Replica set
  - Redis: Cluster mode
  - Cost: €500-2000/month
```

---

## 📊 API Performance Targets

| Endpoint | P50 | P95 | P99 |
|---------|-----|-----|-----|
| GET /home | 100ms | 300ms | 500ms |
| GET /movies | 50ms | 200ms | 400ms |
| GET /movies/{id} | 30ms | 100ms | 200ms |
| GET /stream/{id} | 100ms | 300ms | 600ms |
| GET /search | 100ms | 400ms | 800ms |
| POST /auth/login | 200ms | 500ms | 1000ms |

---

## 🚨 Server Monitoring

```
Metrics collected (Prometheus):
- requests_per_second
- response_time_p95
- error_rate (4xx, 5xx)
- database_query_time
- cache_hit_rate
- active_connections
- memory_usage
- cpu_usage
- disk_usage

Alerts:
- Error rate > 5% → Telegram alert
- Response time P95 > 2s → Telegram alert
- CPU > 90% → Telegram alert
- Disk > 80% → Telegram alert
- DB connections > 80% max → Telegram alert
```

