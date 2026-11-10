# ⬇️ NetMirror — Download System

## Overview
NetMirror ka download system MovieBox se similar hai lekin casting feature ke saath integrate hai.

---

## Download Architecture

Same HLS/MP4 download system as MovieBox (see MovieBox/download_system.md).

### Additional Features in NetMirror

#### 1. Cast-then-Download
```
User watching on TV via Cast
         ↓
Taps "Download for Offline"
         ↓
Phone downloads in background while still casting to TV
         ↓
Both happen simultaneously
```

#### 2. IPTV Recording (DVR Feature)
```
Live Channel Playing
         ↓
User taps "Record"
         ↓
App starts capturing stream to local file:
  ffmpeg -i {channel_url} -c copy recording.mp4
         ↓
Saved to Downloads with timestamp
         ↓
Watch recorded content anytime
```

#### 3. Browser Video Download
```
Video detected in browser
         ↓
User taps Download icon
         ↓
Backend extracts direct URL (yt-dlp)
         ↓
Download starts with multi-part downloader
         ↓
Saved to local storage
```

---

## Download Formats

| Source | Download Format | Storage |
|--------|----------------|---------|
| Movie (HLS) | Merge .ts → .mp4 | Local |
| Movie (MP4 direct) | .mp4 directly | Local |
| IPTV Recording | .mp4 (ffmpeg capture) | Local |
| Browser extracted | .mp4 / .webm | Local |

---

## Storage Management

```
Downloads Tab
├── Filter: Movies | TV Shows | IPTV | Browser
├── Sort: Date | Size | Name
├── Bulk Actions: Select All → Delete Selected
├── Storage indicator: 23.5 GB used
└── Auto-delete: 30 days (optional setting)
```

