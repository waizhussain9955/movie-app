# 🏃 Sprint Planning — StreamMax

## Sprint Structure
- **Sprint Duration:** 2 weeks
- **Team:** 2-3 developers
- **Story Points:** 1 point = ~4 hours of work

---

## Sprint 1 (Week 1-2): Foundation

### Backend Tasks
| Task | Points | Assignee |
|------|--------|---------|
| GitHub repo + monorepo setup | 1 | Backend |
| Docker Compose (pg, mongo, redis) | 2 | Backend |
| Node.js + Fastify project setup | 2 | Backend |
| PostgreSQL schema + migrations | 3 | Backend |
| MongoDB connection + indexes | 2 | Backend |
| POST /auth/register | 2 | Backend |
| POST /auth/login | 1 | Backend |
| POST /auth/device (anonymous) | 2 | Backend |
| JWT middleware | 2 | Backend |
| GET /movies (list + pagination) | 3 | Backend |
| GET /movies/{id} | 2 | Backend |
| GET /home | 3 | Backend |
| **Total** | **25** | |

### Mobile Tasks
| Task | Points | Assignee |
|------|--------|---------|
| Flutter project setup + structure | 2 | Mobile |
| GoRouter navigation setup | 2 | Mobile |
| Dio HTTP client setup | 2 | Mobile |
| Theme (dark + colors) | 2 | Mobile |
| Splash screen | 1 | Mobile |
| Login screen UI | 3 | Mobile |
| Register screen UI | 3 | Mobile |
| Auth flow (token storage) | 3 | Mobile |
| Home screen skeleton | 4 | Mobile |
| **Total** | **22** | |

**Sprint Goal:** Working auth + basic home screen

---

## Sprint 2 (Week 3-4): Core Streaming

### Backend Tasks
| Task | Points | Assignee |
|------|--------|---------|
| GET /stream/{id} (URL retrieval) | 3 | Backend |
| CDN signed URL generation | 4 | Backend |
| GET /search | 3 | Backend |
| GET /categories | 2 | Backend |
| GET /trending | 2 | Backend |
| POST /user/progress | 3 | Backend |
| GET /user/watchlist | 2 | Backend |
| POST /user/watchlist | 2 | Backend |
| **Total** | **21** | |

### Mobile Tasks
| Task | Points | Assignee |
|------|--------|---------|
| Home screen (carousel + sections) | 5 | Mobile |
| Movie detail screen | 4 | Mobile |
| Video player integration | 5 | Mobile |
| Quality selector | 2 | Mobile |
| Subtitle support | 3 | Mobile |
| Server selector | 3 | Mobile |
| **Total** | **22** | |

**Sprint Goal:** End-to-end: Browse → Detail → Watch

---

## Sprint 3 (Week 5-6): Downloads + Search

### Backend Tasks
| Task | Points | Assignee |
|------|--------|---------|
| POST /downloads/prepare | 4 | Backend |
| Series/Episodes API | 5 | Backend |
| Elasticsearch setup + movie index | 5 | Backend |
| Improved search (Elasticsearch) | 3 | Backend |
| **Total** | **17** | |

### Mobile Tasks
| Task | Points | Assignee |
|------|--------|---------|
| Search screen | 4 | Mobile |
| Download manager service | 6 | Mobile |
| HLS segment downloader | 5 | Mobile |
| Downloads screen | 4 | Mobile |
| Offline playback | 3 | Mobile |
| TV Series screen | 4 | Mobile |
| Episode list screen | 3 | Mobile |
| **Total** | **29** | |

**Sprint Goal:** Full download system + TV series

---

## Sprint 4 (Week 7-8): Cast + IPTV

### Backend Tasks
| Task | Points | Assignee |
|------|--------|---------|
| IPTV channels API | 4 | Backend |
| EPG API | 4 | Backend |
| M3U import tool | 3 | Backend |
| **Total** | **11** | |

### Mobile Tasks
| Task | Points | Assignee |
|------|--------|---------|
| Chromecast integration | 6 | Mobile |
| AirPlay integration (iOS) | 4 | Mobile |
| Cast screen | 3 | Mobile |
| IPTV screen | 5 | Mobile |
| Channel list + EPG | 5 | Mobile |
| **Total** | **23** | |

**Sprint Goal:** Cast to TV + IPTV live

---

## Sprint 5 (Week 9-10): Admin + Automation

### Backend Tasks
| Task | Points | Assignee |
|------|--------|---------|
| Content scraper bot | 6 | Backend |
| Stream health checker | 5 | Backend |
| Telegram alert bot | 2 | Backend |
| POST /extract (yt-dlp) | 5 | Backend |
| **Total** | **18** | |

### Admin Panel Tasks
| Task | Points | Assignee |
|------|--------|---------|
| React admin setup | 2 | Full-stack |
| Admin login | 2 | Full-stack |
| Movie CRUD | 5 | Full-stack |
| Broken streams dashboard | 4 | Full-stack |
| IPTV management | 4 | Full-stack |
| **Total** | **17** | |

**Sprint Goal:** Self-maintaining content system

---

## Sprint 6 (Week 11-12): Monetization + Launch

### Tasks
| Task | Points | Assignee |
|------|--------|---------|
| AdMob integration | 4 | Mobile |
| Subscription system backend | 5 | Backend |
| Premium features gates | 3 | Mobile |
| Push notifications (FCM) | 4 | Mobile |
| Full QA testing | 6 | All |
| Performance optimization | 4 | All |
| Play Store submission | 3 | Mobile |
| App Store submission | 3 | Mobile |
| Production deployment | 4 | Backend |
| Monitoring setup | 3 | Backend |
| **Total** | **39** | |

**Sprint Goal:** 🚀 LAUNCH

---

## 📊 Velocity Tracking

| Sprint | Planned | Completed | Velocity |
|--------|---------|-----------|---------|
| Sprint 1 | 47 pts | - | - |
| Sprint 2 | 43 pts | - | - |
| Sprint 3 | 46 pts | - | - |
| Sprint 4 | 34 pts | - | - |
| Sprint 5 | 35 pts | - | - |
| Sprint 6 | 39 pts | - | - |

---

## 🏷️ Issue Labels

```
priority/critical  → Must fix immediately
priority/high      → This sprint
priority/medium    → Next sprint
priority/low       → Backlog

type/bug           → Bug fix
type/feature       → New feature
type/improvement   → Enhancement
type/documentation → Docs

platform/android   → Android only
platform/ios       → iOS only
platform/backend   → Backend only
platform/admin     → Admin panel

status/in-progress → Being worked on
status/blocked     → Waiting on something
status/review      → PR open, needs review
```

