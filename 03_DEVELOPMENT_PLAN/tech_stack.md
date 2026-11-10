# 🛠️ Tech Stack — StreamMax

## Overview
StreamMax ke liye best technology choices — scalable, maintainable, aur team-friendly.

---

## 📱 Mobile Apps

### Primary Choice: Flutter (Dart)
```
Why Flutter?
✅ Single codebase for iOS + Android (60-70% code sharing)
✅ Native performance
✅ Excellent video player packages
✅ Rich widget library
✅ Hot reload (fast development)
✅ Strong community

Packages:
- video_player / better_player     ← Video playback
- chewie                           ← Video player UI
- flutter_cast_framework           ← Chromecast
- dio                              ← HTTP client
- hive / isar                      ← Local database
- flutter_secure_storage           ← Secure token storage
- cached_network_image             ← Image caching
- just_audio                       ← Audio
- google_mobile_ads                ← AdMob integration
```

### Alternative: React Native (if team knows JS)
```
Packages:
- react-native-video               ← Video player
- react-native-track-player        ← Background audio
- react-native-google-cast         ← Chromecast
- axios / react-query              ← HTTP + state
- react-native-mmkv                ← Fast local storage
```

---

## ⚙️ Backend

### API Server: Node.js + Fastify
```
Why Fastify?
✅ 2x faster than Express
✅ Schema-based validation (Zod/Ajv)
✅ TypeScript first-class support
✅ Plugin ecosystem
✅ Large team familiarity (JavaScript)

Stack:
- Runtime: Node.js 20 LTS
- Framework: Fastify 4
- Language: TypeScript
- ORM (PostgreSQL): Prisma
- ODM (MongoDB): Mongoose
- Validation: Zod
- Auth: JWT (jose library)
- File upload: @fastify/multipart
```

### Alternative: Go (Gin/Fiber) for high performance
```
Best for: Stream server, CDN proxy
Why Go?
✅ 10x faster than Node.js for I/O
✅ Low memory usage
✅ Excellent for concurrent requests
✅ Static binary (easy deployment)
```

### Recommendation: Hybrid
```
Node.js (Fastify) → Main API (content, auth, user management)
Go (Fiber)        → Stream server (high concurrency, URL signing)
Python (FastAPI)  → Scraper service, video extractor (yt-dlp)
```

---

## 🗄️ Databases

| Database | Use | Why |
|---------|-----|-----|
| PostgreSQL 15 | Users, auth, subscriptions | ACID, relations |
| MongoDB 7 | Movies, series, IPTV | Flexible schema |
| Redis 7 | Sessions, cache, rate limiting | Speed |
| Elasticsearch 8 | Full-text search | Search quality |
| MinIO / Cloudflare R2 | File storage | S3-compatible |

---

## 🌐 Infrastructure

### Hosting
```
Cloud Provider: Hetzner Cloud (cost-effective) + Cloudflare
  
Servers:
- API Servers:     2x CX31 (4 core, 8GB RAM) = €20/month each
- DB Server:       1x CX41 (8 core, 16GB RAM) = €40/month
- Redis:           1x CX21 (2 core, 4GB RAM) = €10/month
- Elasticsearch:   1x CX31 = €20/month

Estimated server cost: €90-150/month initially
```

### CDN
```
Primary: Cloudflare (Free tier → Pro $20/month)
  - DDoS protection
  - Global edge caching
  - Workers (edge computing)

Video CDN: BunnyCDN
  - €0.01/GB bandwidth
  - Pull zone (cache from origin)
  - 500GB free trial
  
Alternative for video: Cloudflare Stream
  - $5/1000 min stored
  - $1/1000 min delivered
```

### Container & Deployment
```
Containerization: Docker + Docker Compose (dev) / Kubernetes (prod)
Registry: GitHub Container Registry (GHCR) — free
CI/CD: GitHub Actions (free for public, 2000 min/month private)

Deployment:
  Dev:     docker-compose up
  Staging: GitHub Actions → Docker → Hetzner VPS
  Prod:    GitHub Actions → Docker → K8s cluster
```

---

## 📊 Monitoring & Observability

```
Metrics:    Prometheus + Grafana (self-hosted, free)
Logs:       Loki + Grafana (self-hosted)
Tracing:    Jaeger (self-hosted)
Uptime:     UptimeRobot (free, 50 monitors)
Error tracking: Sentry (free tier)
Alerts:     Grafana → Telegram Bot / Email
```

---

## 🔄 Development Tools

```
Version Control:    Git + GitHub
Project Management: GitHub Projects (Kanban) — free
Code Review:        GitHub PRs
API Testing:        Postman / Bruno (free)
DB GUI:             TablePlus or pgAdmin (free)
Design:             Figma (free tier)
Documentation:      Markdown in repo + GitBook (free)
Communication:      Telegram group / Discord
```

---

## 📦 Complete Stack Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT LAYER                              │
│    Flutter (iOS + Android)  │  React (Admin Web Panel)      │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   API GATEWAY                               │
│              nginx + Cloudflare WAF                         │
└─────────────────────────────────────────────────────────────┘
                              │
┌───────────────┬─────────────┴──────────────┬────────────────┐
│  Node.js API  │   Go Stream Server         │ Python Scraper │
│  (Fastify)    │   (Fiber / Gin)            │ (FastAPI)      │
└───────┬───────┴──────────────┬─────────────┴────────────────┘
        │                      │
┌───────┴──────────────────────┴──────────────────────────────┐
│                    DATA LAYER                               │
│  PostgreSQL │ MongoDB │ Redis │ Elasticsearch │ MinIO        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   CDN LAYER                                 │
│           Cloudflare + BunnyCDN                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 💰 Monthly Cost Estimate

| Service | Cost/month |
|---------|-----------|
| Hetzner servers | €90-150 |
| Cloudflare Pro | \$20 |
| BunnyCDN (1TB) | \$10 |
| Domain | \$1 |
| Email (Resend) | \$0 (free tier) |
| GitHub | \$0 (free) |
| **Total (small scale)** | **~\$150-200/month** |

> Scales to \$1,000-5,000/month at 100K+ users with CDN costs dominating.

