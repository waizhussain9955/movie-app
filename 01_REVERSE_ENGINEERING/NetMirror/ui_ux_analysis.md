# 🎨 NetMirror — UI/UX Analysis

## Overview
NetMirror UI casting-focused hai. Main feature is to discover and connect to cast devices. Dark theme with blue accent.

---

## 📱 Screen Structure

```
NetMirror Screens:
├── Onboarding
│   ├── Splash
│   ├── Network Permission
│   └── Cast Device Scan
├── Main Tabs
│   ├── Home (Movies/Content)
│   ├── Cast (Mirror + Connect to TV)
│   ├── Browser (Built-in browser)
│   ├── IPTV (Live TV)
│   └── Downloads
└── Settings
    ├── Cast Settings
    ├── Video Quality
    ├── IPTV Settings
    └── About
```

---

## 📺 Cast/Mirror Screen

```
┌─────────────────────────────────────┐
│  Cast & Mirror                  ⚙️  │
├─────────────────────────────────────┤
│                                     │
│  📡 Scanning for devices...         │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  📺  Samsung Smart TV        │    │  ← Detected TV
│  │       Living Room            │    │
│  │  [Connect]                   │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │  🎯  Chromecast Ultra        │    │
│  │       Bedroom                │    │
│  │  [Connect]                   │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │  🍎  Apple TV 4K             │    │
│  │       Office                 │    │
│  │  [Connect]                   │    │
│  └─────────────────────────────┘    │
│                                     │
│  ─── Screen Mirror ───              │
│  [Start Mirroring Your Screen]      │
│                                     │
└─────────────────────────────────────┘
```

---

## 🌐 Built-in Browser Screen

```
┌─────────────────────────────────────┐
│  ← →  🔒 netflix.com          ☰   │  ← URL bar
├─────────────────────────────────────┤
│                                     │
│         [WEBPAGE CONTENT]           │
│                                     │
│                                     │
│  ┌────────────────────────────────┐ │
│  │ 🎬 Video Detected!              │ │  ← Popup when video found
│  │ "Movie Title"                   │ │
│  │ [⬇ Download] [📺 Cast to TV]   │ │
│  └────────────────────────────────┘ │
│                                     │
│  ─── Recent ───                     │
│  netflix.com  youtube.com  ...      │
└─────────────────────────────────────┘
```

---

## 🎨 Design System

### Colors
```
Background:    #090E1A (Deep dark blue)
Surface:       #131B2E
Primary:       #0066FF (Blue)
Accent:        #00D4FF (Cyan)
Text:          #FFFFFF / #8899AA
Success:       #00CC66
Warning:       #FFB300
```

### Key UX Differences from MovieBox
| Feature | MovieBox | NetMirror |
|---------|---------|----------|
| Main Feature | Browse movies | Cast to TV |
| Onboarding | Simple | Network scan |
| Navigation | 5 tabs | 5 tabs (different) |
| Color Theme | Red/Dark | Blue/Dark |
| Primary Action | Watch Now | Cast Now |

