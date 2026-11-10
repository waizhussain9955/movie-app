# 🎨 MovieBox — UI/UX Analysis

## Overview
MovieBox ki UI Netflix/Disney+ se inspired hai. Dark theme, card-based layout, aur smooth animations.

---

## 📱 Screen Inventory

```
MovieBox App Screens:
├── Onboarding
│   ├── Splash Screen
│   └── Permission Request (Storage, Notifications)
├── Main App
│   ├── Home Screen (Tab 1)
│   ├── Search Screen (Tab 2)
│   ├── My List / Bookmarks (Tab 3)
│   ├── Downloads Screen (Tab 4)
│   └── Settings Screen (Tab 5)
├── Content Screens
│   ├── Movie Detail Screen
│   ├── TV Show Detail Screen
│   ├── Season/Episode List
│   └── Category/Genre Screen
├── Player Screens
│   ├── Video Player (Fullscreen)
│   ├── Cast/Mirror Screen
│   └── Subtitle Settings
└── Settings Screens
    ├── App Settings
    ├── Download Settings
    ├── Player Settings
    └── About
```

---

## 🏠 Home Screen Design

```
┌─────────────────────────────────────┐
│  MovieBox          🔔  👤           │  ← Header
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │                             │    │  ← Featured Carousel
│  │   FEATURED MOVIE BACKDROP   │    │     (Auto-scrolls every 4s)
│  │                             │    │
│  │  Movie Title                │    │
│  │  ⭐ 8.5  │  2024  │  Action │    │
│  │  [▶ Watch Now] [+ My List]  │    │
│  └─────────────────────────────┘    │
│  ○ ● ○ ○ ○                          │  ← Dot indicators
│                                     │
│  🔥 Trending Now                    │  ← Section Header
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐       │
│  │    │ │    │ │    │ │    │       │  ← Horizontal scroll cards
│  │    │ │    │ │    │ │    │       │
│  └────┘ └────┘ └────┘ └────┘       │
│                                     │
│  🎬 New Movies                      │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐       │
│  │    │ │    │ │    │ │    │       │
│  └────┘ └────┘ └────┘ └────┘       │
│                                     │
│  📺 Continue Watching               │
│  ─────────────────────────          │
│  [Movie]  Movie Name  ████░░  65%   │
├─────────────────────────────────────┤
│  🏠      🔍      ♥       ⬇️      ⚙️  │  ← Bottom Navigation
└─────────────────────────────────────┘
```

---

## 🎬 Movie Detail Screen

```
┌─────────────────────────────────────┐
│  ←                     ♥  ⋮        │  ← Back + Favorite + More
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │      MOVIE BACKDROP         │    │  ← Hero image
│  │                      ▶      │    │  ← Play trailer button
│  └─────────────────────────────┘    │
│                                     │
│  Movie Title (2024)                 │
│  ⭐ 8.5 IMDb  │  2h 22m  │  HD     │
│  Action • Thriller • Sci-Fi         │
│                                     │
│  [▶ Watch Now]  [⬇ Download]        │  ← CTA Buttons
│                                     │
│  Description                        │
│  Lorem ipsum movie description...  │
│  Read more                          │
│                                     │
│  Director: John Doe                 │
│  Cast: Actor 1, Actor 2, Actor 3   │
│                                     │
│  ─── Servers ───                    │
│  ○ Server 1 (1080p) ✓              │
│  ○ Server 2 (720p)                  │
│  ○ Server 3 (480p)                  │
│                                     │
│  ─── Subtitles ───                  │
│  🌐 English  🌐 Arabic  🌐 Spanish  │
│                                     │
│  ─── You May Also Like ───          │
│  ┌────┐ ┌────┐ ┌────┐             │
│  │    │ │    │ │    │             │
│  └────┘ └────┘ └────┘             │
└─────────────────────────────────────┘
```

---

## 📺 Video Player Screen

```
┌─────────────────────────────────────┐
│  ←  Movie Title              ⚙️  ⋮  │  ← Topbar (hides after 3s)
│                                     │
│                                     │
│           [VIDEO CONTENT]           │
│                                     │
│                                     │
│  ─────────────────────────────────  │
│  00:45:23          ████████░░░░      │  ← Progress bar
│                       1:52:30       │
│                                     │
│  ⏭  ⏮   ⏸   ⏭           🔊 📺 CC  │  ← Controls
│  -10s  -10s  Play  +10s            │
│                                     │
│  Quality: [1080p ▾]                 │
│  Speed:   [1.0x ▾]                  │
└─────────────────────────────────────┘
```

---

## 🎨 Design System

### Colors
```
Background:     #0A0A0A (Near black)
Surface:        #1A1A1A (Dark card)
Primary:        #E50914 (Netflix red) or #0066FF (blue variant)
Text Primary:   #FFFFFF
Text Secondary: #9E9E9E
Accent:         #FFD700 (Gold — for ratings)
```

### Typography
```
App Font:       System default (SF Pro on iOS, Roboto on Android)
Title Large:    24sp Bold
Title Medium:   18sp SemiBold
Body:           14sp Regular
Caption:        12sp Regular
```

### Component Patterns
| Component | Pattern |
|-----------|---------|
| Movie Card | 2:3 aspect ratio poster, rounded corners (8dp) |
| Section Header | Left-aligned title + "See All" right link |
| Carousel | Auto-scroll hero with dot indicators |
| Rating | Star icon + IMDb score in gold |
| Button | Filled primary + Outlined secondary |
| Player | Custom controls overlay, 3-second auto-hide |

---

## 🔄 Navigation Pattern

```
Bottom Tab Navigation (5 tabs):
  Home → Search → Watchlist → Downloads → Settings

Modal Presentations:
  Movie Detail → opens as bottom sheet or push navigation
  
Player: 
  Full screen takeover, landscape forced
```

---

## 📊 UX Patterns Identified

| Pattern | Purpose |
|---------|---------|
| Infinite Scroll | Load more content on scroll end |
| Pull to Refresh | Refresh content feed |
| Offline Badge | Show "Downloaded" badge on poster |
| Continue Watching | Resume from last position |
| Smart Auto-Play | Next episode auto-plays after 5s |
| Picture-in-Picture | iOS/Android PiP support |
| Long Press | Quick actions (Save, Download, Share) |

