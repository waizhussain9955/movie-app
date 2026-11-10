# 🗓️ Development Roadmap — StreamMax (12 Weeks)

## Overview
12-hafton mein StreamMax build karne ka complete plan.

---

## 📅 Phase 1: Foundation (Week 1-3)

### Week 1: Setup & Infrastructure
```
Days 1-2: Project Setup
  ✅ GitHub repository create (monorepo)
  ✅ Flutter project initialize
  ✅ Node.js backend project initialize
  ✅ Docker Compose setup (local dev)
  ✅ CI/CD pipeline basic setup
  ✅ Domain purchase + Cloudflare setup
  
Days 3-4: Database Setup
  ✅ PostgreSQL schema (users, auth tables)
  ✅ MongoDB setup + movies schema
  ✅ Redis setup + connection
  ✅ Database migrations system
  
Days 5-7: Auth System (Backend)
  ✅ POST /auth/register
  ✅ POST /auth/login
  ✅ POST /auth/device (anonymous)
  ✅ JWT middleware
  ✅ POST /auth/refresh
```

### Week 2: Content API + Admin
```
Days 1-3: Content API
  ✅ GET /home
  ✅ GET /movies (paginated)
  ✅ GET /movies/{id}
  ✅ GET /stream/{id} (basic, no signing)
  ✅ GET /search
  ✅ GET /categories

Days 4-5: Admin Panel (Basic)
  ✅ React admin dashboard
  ✅ Login page (admin only)
  ✅ Movie list + add movie form
  ✅ TMDB auto-fetch when adding movie
  
Days 6-7: Testing
  ✅ Postman collection for all APIs
  ✅ Basic unit tests
  ✅ Deploy to staging server
```

### Week 3: Flutter App — Foundation
```
Days 1-2: Project Structure
  ✅ Folder structure (Clean Architecture)
  ✅ Navigation (GoRouter)
  ✅ Theme (dark theme)
  ✅ Network layer (Dio + interceptors)
  ✅ Local storage (Hive)
  
Days 3-5: Auth Screens
  ✅ Splash screen
  ✅ Login screen
  ✅ Register screen
  ✅ Device login (anonymous) on first launch
  
Days 6-7: Home Screen (Basic)
  ✅ Featured carousel
  ✅ Movie list sections
  ✅ Category row
  ✅ Pull to refresh
```

---

## 📅 Phase 2: Core Features (Week 4-6)

### Week 4: Movie Detail + Player
```
Days 1-2: Movie Detail Screen
  ✅ Full movie detail page
  ✅ Server selector
  ✅ Quality selector
  ✅ Subtitle selector
  
Days 3-5: Video Player
  ✅ better_player integration
  ✅ HLS playback (m3u8)
  ✅ MP4 playback
  ✅ Quality switching
  ✅ Subtitle overlay
  
Days 6-7: Player Controls
  ✅ Custom player controls UI
  ✅ Double-tap seek
  ✅ Brightness/volume gesture
  ✅ Fullscreen + rotation
  ✅ Remember watch position
```

### Week 5: Search + Downloads
```
Days 1-2: Search Screen
  ✅ Real-time search with debounce
  ✅ Search history
  ✅ Filter by genre/year/rating
  
Days 3-5: Download System
  ✅ HLS download (fetch segments → merge)
  ✅ MP4 direct download
  ✅ Background download service
  ✅ Pause/Resume
  ✅ Download progress UI
  
Days 6-7: Downloads Screen
  ✅ Downloaded movies list
  ✅ Offline playback
  ✅ Delete downloads
  ✅ Storage indicator
```

### Week 6: User Features
```
Days 1-3: User Account
  ✅ Profile screen
  ✅ Watchlist (add/remove)
  ✅ Watch history
  ✅ Settings screen
  
Days 4-5: Watch Progress Sync
  ✅ POST /user/progress (backend)
  ✅ Sync every 30 seconds during playback
  ✅ Resume from last position
  ✅ Continue Watching on home screen
  
Days 6-7: TV Series
  ✅ Series detail page
  ✅ Season + Episode list
  ✅ Episode player
  ✅ Auto-next episode
```

---

## 📅 Phase 3: Advanced Features (Week 7-9)

### Week 7: Cast to TV
```
Days 1-3: Chromecast
  ✅ flutter_cast_framework integration
  ✅ Cast button in player
  ✅ Cast controls screen
  ✅ Phone controls while casting
  
Days 4-5: AirPlay (iOS)
  ✅ AVKit AirPlay integration
  ✅ AirPlay button in player
  
Days 6-7: DLNA
  ✅ DLNA device discovery
  ✅ DLNA streaming
```

### Week 8: IPTV + Live TV
```
Days 1-2: IPTV Backend
  ✅ IPTV channels collection
  ✅ GET /iptv/channels
  ✅ GET /iptv/epg
  ✅ M3U import tool
  
Days 3-5: IPTV Screen (App)
  ✅ Channel list by country/category
  ✅ EPG (TV guide)
  ✅ Live channel player
  
Days 6-7: IPTV Recording
  ✅ Record live stream to file
  ✅ Save to downloads
```

### Week 9: Built-in Browser + Extractor
```
Days 1-3: Browser Module
  ✅ WebView browser screen
  ✅ URL bar + navigation
  ✅ Bookmarks
  ✅ History
  
Days 4-5: Video Extractor
  ✅ yt-dlp service (Python backend)
  ✅ POST /extract endpoint
  ✅ App integration: detect video in browser
  
Days 6-7: Cast from Browser
  ✅ "Cast to TV" from extracted video
  ✅ "Download" from extracted video
```

---

## 📅 Phase 4: Polish + Monetization (Week 10-12)

### Week 10: Content Management + Automation
```
Days 1-3: Content Scraper
  ✅ TMDB new releases watcher
  ✅ Stream finder bot
  ✅ Auto-add to DB
  
Days 4-5: Health Monitor
  ✅ Broken link checker bot
  ✅ Auto-fix system
  ✅ Telegram alerts
  
Days 6-7: Admin Panel Enhancement
  ✅ Dashboard with analytics
  ✅ Broken streams board
  ✅ Bulk operations
```

### Week 11: Ads + Subscriptions
```
Days 1-3: Ad Integration
  ✅ Google AdMob setup
  ✅ Banner ads (home screen)
  ✅ Interstitial ads (before video)
  ✅ Rewarded ads (unlock HD)
  
Days 4-5: Subscription System
  ✅ Subscription plans in DB
  ✅ Payment integration (Stripe or in-app purchases)
  ✅ Premium content gates
  
Days 6-7: Push Notifications
  ✅ Firebase Cloud Messaging
  ✅ New content notifications
  ✅ Download complete notification
```

### Week 12: QA + Launch
```
Days 1-3: Testing
  ✅ Full E2E testing
  ✅ Performance testing (1000 concurrent users)
  ✅ Security audit
  ✅ Bug fixes
  
Days 4-5: Store Submission
  ✅ Google Play Store submission
  ✅ Apple App Store submission (or alternative)
  ✅ Store assets (screenshots, description)
  
Days 6-7: Launch
  ✅ Production deployment
  ✅ Monitoring dashboards live
  ✅ Support channel (Telegram/Discord)
  ✅ 🚀 LAUNCH!
```

---

## 📊 Milestone Summary

| Week | Milestone |
|------|-----------|
| 3 | Backend APIs live + Basic Flutter app running |
| 6 | Full MVP: Stream, Search, Download, User Accounts |
| 9 | Full feature set: Cast, IPTV, Browser |
| 12 | Production launch + Store submission |

---

## ⚠️ Risk Register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| CDN costs spike | Medium | High | Set Cloudflare spending alerts |
| App Store rejection | High | High | Use alternative distribution (APK direct) |
| DMCA takedowns | High | Medium | Quick removal process, offshore hosting |
| Stream sources breaking | High | Medium | Multi-server + auto-fix bot |
| Team bottleneck | Medium | Medium | Clear task separation, parallel work |

