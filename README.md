# 🎬 Movie Streaming App — Reverse Engineering & Spec-Driven Development

> **Project Goal:** Reverse engineer MovieBox & NetMirror → Document every detail → Build our own streaming app using Spec-Driven Development

---

## 📁 Complete Project Structure

```
Reverse Engineer movie app/
├── README.md                                  ← Master index
├── backend/                                   ← Live Node.js Multi-Server API
│   ├── src/
│   │   ├── config/db.js                       ← MongoDB / In-memory Hybrid
│   │   ├── models/Movie.js                    ← Movie Mongoose Schema
│   │   ├── routes/movieRoutes.js              ← /home, /movie/:id, /stream, /search
│   │   ├── services/streamResolver.js         ← 6 Live Stream Providers Resolver
│   │   ├── services/tmdbService.js            ← TMDB Metadata Engine
│   │   └── server.js                          ← Live Express server
│   └── test_in_process.js                     ← Backend tests (All PASSED ✅)
│
├── streammax_app/                             ← Flutter Cross-Platform Mobile App
│   ├── lib/
│   │   ├── models/movie.dart                  ← Movie & StreamServer models
│   │   ├── screens/home_screen.dart           ← Hero Carousel & Category Feeds
│   │   ├── screens/movie_detail_screen.dart   ← Backdrop Hero, Watch Now, CTA
│   │   ├── screens/player_screen.dart         ← Full Video Player with 6-Server Switcher
│   │   ├── screens/search_screen.dart         ← Real-time instant search
│   │   ├── services/api_service.dart          ← API client + fallback engine
│   │   └── main.dart                          ← Dark theme & Bottom Navigation
│   └── test/                                  ← Automated Unit & Widget Tests (All PASSED ✅)
│
├── 01_REVERSE_ENGINEERING/
│   ├── LIVE_APK_ANALYSIS.md                   ← Real decompiled APK teardown
│   ├── APP_OWNERSHIP_AND_ENTITIES.md          ← Who owns MovieBox & NetMirror
│   ├── MovieBox/
│   │   ├── architecture.md                    ← Full app architecture
│   │   ├── backend_analysis.md                ← Backend & API reverse engineered
│   │   ├── content_pipeline.md                ← How movies are added
│   │   ├── download_system.md                 ← Download mechanism deep-dive
│   │   └── ui_ux_analysis.md                  ← UI patterns & screens
│   └── NetMirror/
│       ├── architecture.md
│       ├── backend_analysis.md
│       ├── content_pipeline.md
│       ├── download_system.md
│       └── ui_ux_analysis.md
│
├── 02_SPECIFICATIONS/
│   ├── app_spec.md                            ← Full feature specification
│   ├── api_spec.md                            ← API endpoints & contracts
│   ├── database_schema.md                     ← DB design
│   ├── content_management.md                  ← CMS & content workflow
│   ├── security_spec.md                       ← Auth, DRM, security
│   └── PERMISSIONS_GUIDE.md                   ← Complete Android/iOS permissions guide
│
├── 03_DEVELOPMENT_PLAN/
│   ├── roadmap.md                             ← 12-week roadmap
│   ├── tech_stack.md                          ← Technology decisions
│   ├── team_structure.md                      ← Team roles & headcount
│   └── sprint_planning.md                     ← Sprint-by-sprint breakdown
│
├── 04_BACKEND/
│   ├── server_architecture.md                 ← Server & microservices design
│   ├── cdn_strategy.md                        ← CDN, HLS streaming
│   ├── content_ingestion.md                   ← How content enters system
│   └── error_handling.md                      ← Error handling & monitoring
│
├── 05_ISSUES_AND_HANDLING/
│   ├── known_issues.md                        ← Common issues & fixes
│   ├── dmca_legal.md                          ← Legal & DMCA compliance
│   └── incident_playbook.md                   ← Incident response
│
└── 06_RESEARCH/
    ├── market_analysis.md                     ← Market overview
    ├── competitors.md                         ← Full competitor analysis
    └── monetization.md                        ← Revenue models
```

---

## 🚀 Reading Order

1. `06_RESEARCH/competitors.md` — Understand the market
2. `01_REVERSE_ENGINEERING/MovieBox/` — Deep dive MovieBox
3. `01_REVERSE_ENGINEERING/NetMirror/` — Deep dive NetMirror
4. `02_SPECIFICATIONS/app_spec.md` — What WE are building
5. `03_DEVELOPMENT_PLAN/roadmap.md` — How we build it
6. `04_BACKEND/` — Backend implementation details

---

## ⚠️ Legal Notice

> This project is for **educational and research purposes only.**
> Reverse engineering conducted under fair use / security research exemption.
> Do NOT host, stream, or distribute copyrighted content without proper licensing.

