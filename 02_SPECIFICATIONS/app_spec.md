# 📐 App Specification — StreamMax (Our App)

## Product Vision
**StreamMax** ek cross-platform movie streaming app hai jo MovieBox + NetMirror ke best features combine karti hai:
- 🎬 Movie & TV Show streaming
- 📺 Cast to any TV (Chromecast, AirPlay, DLNA)
- 📺 IPTV / Live TV
- 🌐 Built-in browser with video extractor
- ⬇️ Offline downloads
- 🎭 Clean, modern UI

---

## 🎯 Target Platforms
- Android (API 21+, Android 5.0+)
- iOS (iOS 14+)

---

## 👥 User Types

| User Type | Description |
|-----------|------------|
| Anonymous User | Browse content without account |
| Registered User | Save watchlist, sync progress |
| Premium User | HD quality, no ads |
| Admin | Content management |

---

## 📱 Feature Specification

### Feature 1: Home Screen
**Priority:** P0 (Must Have)

**Requirements:**
- Featured carousel (auto-scroll, 5 items)
- Trending Now section (horizontal scroll)
- New Releases section
- Continue Watching (last 10 items)
- Categories quick-access row
- Pull-to-refresh
- Infinite scroll / pagination

**Acceptance Criteria:**
- [ ] Home loads in < 2 seconds
- [ ] Featured carousel auto-scrolls every 4 seconds
- [ ] Shows at minimum 20 movies per category
- [ ] Continue Watching shows exact timestamp

---

### Feature 2: Search
**Priority:** P0

**Requirements:**
- Real-time search (debounced, 300ms)
- Search movies, TV shows, actors, directors
- Search history (last 10 searches)
- Trending searches
- Filter by: Genre, Year, Rating, Quality
- Voice search support

**Acceptance Criteria:**
- [ ] Results appear in < 500ms
- [ ] Minimum 95% recall for exact title match
- [ ] Voice search works offline (on-device)

---

### Feature 3: Movie Detail
**Priority:** P0

**Requirements:**
- Movie poster + backdrop
- Title, year, duration, rating, genres
- Plot description (expandable)
- Director + cast list
- Multiple server selection
- Quality selector (360p - 4K)
- Subtitle language selector
- Watchlist add/remove
- Share button
- Related movies section
- User ratings/reviews

**Acceptance Criteria:**
- [ ] Page loads in < 1.5 seconds
- [ ] Shows at least 3 servers where available
- [ ] All metadata fields populated

---

### Feature 4: Video Player
**Priority:** P0

**Requirements:**
- HLS + MP4 playback
- Quality switching (mid-stream, no restart)
- Subtitle overlay (SRT, VTT, ASS formats)
- Playback speed control (0.5x - 2.0x)
- Skip intro button (for TV shows)
- Double-tap to seek (10 seconds)
- Brightness/Volume gesture control
- Picture-in-Picture (PiP)
- Chromecast / AirPlay cast button
- Auto-next episode
- Remember watch position

**Acceptance Criteria:**
- [ ] Video starts in < 3 seconds on 4G
- [ ] Quality switch takes < 2 seconds
- [ ] Resume from exact position (± 5 seconds)
- [ ] Subtitles sync within ± 500ms
- [ ] PiP works on Android 8+ and iOS 14+

---

### Feature 5: Cast to TV
**Priority:** P1

**Requirements:**
- Auto-discover Chromecast, Apple TV, Smart TVs (DLNA)
- One-tap cast from movie player
- Cast controls (play/pause/seek/volume) on phone
- Continue watching on phone while casting
- Display movie poster on TV while loading

**Acceptance Criteria:**
- [ ] Device discovery within 5 seconds on same WiFi
- [ ] Cast starts within 3 seconds of tap
- [ ] Phone controls TV with < 500ms latency

---

### Feature 6: Downloads
**Priority:** P1

**Requirements:**
- Download HLS streams (merge to MP4)
- Download MP4 directly (multi-part)
- Choose quality before download
- Background downloading
- Pause/Resume downloads
- Download queue (max 3 simultaneous)
- WiFi-only mode option
- Storage space indicator
- Offline playback of downloaded content
- Auto-delete after X days (optional)

**Acceptance Criteria:**
- [ ] Download speed uses full available bandwidth
- [ ] Resume works after app kill
- [ ] Offline playback works with no internet
- [ ] Downloaded content plays within 1 second of tap

---

### Feature 7: IPTV / Live TV
**Priority:** P2

**Requirements:**
- Load M3U playlist from URL
- Channel list with logos and EPG
- Filter by country/category
- TV Guide (7-day EPG)
- Record live TV to local storage
- Favorite channels

**Acceptance Criteria:**
- [ ] M3U with 1000+ channels loads in < 5 seconds
- [ ] Channel changes within 3 seconds

---

### Feature 8: Built-in Browser
**Priority:** P2

**Requirements:**
- Chromium-based WebView browser
- Video detection on any page
- Extract video for download or cast
- Ad blocking
- Private/Incognito mode
- Bookmarks

**Acceptance Criteria:**
- [ ] Video detected automatically on 90%+ of streaming sites
- [ ] Extracted video plays without re-encoding

---

### Feature 9: User Accounts
**Priority:** P1

**Requirements:**
- Register with email or Google/Apple SSO
- Cloud sync: Watchlist, Watch history, Downloads metadata
- Multiple device support (up to 5 devices)
- Profile picture + username
- Parental controls (PIN-lock mature content)

---

### Feature 10: Settings
**Priority:** P0

**Requirements:**
- Video quality preference (Auto/360p/720p/1080p/4K)
- Download quality preference
- Subtitle size, color, position
- Playback speed default
- Theme (Dark/Light/AMOLED)
- Language (app UI language)
- Notifications (new content, downloads)
- Clear cache
- Storage management

---

## 📊 Non-Functional Requirements

| Requirement | Target |
|------------|--------|
| App size | < 50 MB (Android), < 60 MB (iOS) |
| Cold start time | < 2 seconds |
| Crash rate | < 0.1% sessions |
| ANR rate | < 0.05% |
| Memory usage | < 300 MB during playback |
| Battery drain | < 15% per hour during streaming |
| API response | < 500ms (p95) |
| Video start time | < 3s on 4G, < 1s on WiFi |

---

## 🚀 Launch Phases

### Phase 1 — MVP (Month 1-3)
- Home, Search, Movie Detail, Video Player
- Basic download (MP4 only)
- Anonymous browsing

### Phase 2 — Core Features (Month 4-6)
- HLS downloads + quality selection
- User accounts + watchlist sync
- Cast to TV (Chromecast)
- IPTV basic

### Phase 3 — Advanced (Month 7-9)
- Built-in browser + extractor
- AirPlay + DLNA
- Live TV recording
- Advanced recommendations

### Phase 4 — Monetization (Month 10-12)
- Ad integration
- Premium subscription tier
- Push notifications
- Analytics dashboard

