# ⬇️ MovieBox — Download System Deep-Dive

## Overview
MovieBox ka download system ek multi-threaded download manager hai jo HLS streams aur direct MP4 files dono ko support karta hai.

---

## 📥 Download Architecture

```
User Taps Download
       ↓
Download Manager Initialized
       ↓
       ├── MP4 Direct? → Single file download (multi-part)
       └── HLS/m3u8?  → Parse playlist → Download all .ts segments
                                               ↓
                                     Merge .ts segments into .mp4
                                               ↓
                                     Store in local storage (encrypted)
                                               ↓
                                     Show in "Downloads" tab
```

---

## 🔧 Download Engine

### Primary Engine: aria2c
```
aria2c is an open-source download utility
- Multi-connection download (up to 16 parallel connections)
- Resume support (broken downloads can continue)
- HTTP/HTTPS/BitTorrent support
- Integrated in app as native library (libaria2.so)
```

### HLS Download Process
```
Step 1: Fetch master playlist
  GET https://cdn.xxx/movie/index.m3u8
  
Step 2: Parse and choose quality
  Content of index.m3u8:
  #EXTM3U
  #EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
  1080p/playlist.m3u8
  #EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
  720p/playlist.m3u8

Step 3: Fetch quality playlist
  GET https://cdn.xxx/movie/1080p/playlist.m3u8
  
  Content:
  #EXTM3U
  #EXT-X-VERSION:3
  #EXT-X-TARGETDURATION:10
  #EXTINF:10.0,
  segment000.ts
  #EXTINF:10.0,
  segment001.ts
  ...
  #EXT-X-ENDLIST

Step 4: Download all segments in parallel
  Download: segment000.ts, segment001.ts, ... segmentNNN.ts
  Parallel connections: 8-16 simultaneous downloads

Step 5: Merge segments
  cat segment*.ts > merged.ts
  ffmpeg -i merged.ts -c copy output.mp4

Step 6: Store with metadata
  {
    "title": "Movie Name",
    "quality": "1080p",
    "file_path": "/storage/MovieBox/downloads/movie_123.mp4",
    "size": "2.3 GB",
    "duration": 7320,
    "thumbnail": "/storage/MovieBox/thumbs/movie_123.jpg",
    "downloaded_at": "2024-01-01T00:00:00Z"
  }
```

---

## 📁 Local Storage Structure

### iOS
```
/Documents/MovieBox/
├── downloads/
│   ├── movie_123.mp4         ← Downloaded movie
│   ├── movie_456.mp4
│   └── ...
├── thumbnails/
│   ├── movie_123.jpg
│   └── ...
├── subtitles/
│   ├── movie_123_en.srt
│   └── ...
└── metadata.db               ← SQLite: download history
```

### Android
```
/sdcard/Android/data/com.xxx.moviebox/files/
├── downloads/
│   ├── movie_123.mp4
│   └── ...
├── cache/
│   ├── thumbnails/
│   └── playlists/
└── metadata.db
```

---

## 🔐 Download Encryption (Some Versions)

```
Some versions encrypt downloaded files:
- AES-128 encryption on stored files
- Key derived from device_id + secret_key
- File extension changed to .mbox or .enc
- Decrypted on-the-fly during playback
- Prevents easy copying from device storage
```

---

## ⚡ Download Manager Features

| Feature | Implementation |
|---------|---------------|
| Background Download | iOS Background Fetch / Android WorkManager |
| Resume on reconnect | aria2 built-in resume support |
| Pause/Resume | Pause HTTP range requests |
| Download queue | Local SQLite queue |
| Progress tracking | Polling download state every 500ms |
| Speed limit | aria2 `--max-download-limit` option |
| WiFi-only mode | Network check before starting |
| Storage check | Check free space before download |
| Concurrent downloads | Max 3 simultaneous (configurable) |

---

## 📊 Download State Machine

```
PENDING → DOWNLOADING → PAUSED → DOWNLOADING (resumed)
                     → COMPLETED
                     → FAILED → RETRYING (auto, 3 times)
                              → ERROR (manual retry needed)
                     → CANCELLED
```

---

## 🚨 Download Error Handling

| Error | Cause | Solution |
|-------|-------|---------|
| URL Expired | CDN signed URL timed out | Re-fetch stream URL, restart download |
| Storage Full | Device storage full | Alert user, pause all downloads |
| Network Lost | WiFi/data disconnected | Pause, auto-resume on reconnect |
| Corrupt Segment | CDN served bad data | Re-download that segment only |
| 403 Forbidden | CDN blocked access | Try alternate server |
| Merge Failed | FFmpeg error | Delete segments, retry full download |

---

## 🔄 Download Flow Code (Pseudo-code)

```kotlin
// Android — Download Manager
class MovieDownloadManager {
    
    fun startDownload(movie: Movie, quality: String) {
        // 1. Get stream URL
        val streamUrl = api.getStreamUrl(movie.id, quality)
        
        // 2. Detect type
        if (streamUrl.endsWith(".m3u8")) {
            downloadHLS(streamUrl, movie)
        } else {
            downloadMP4(streamUrl, movie)
        }
    }
    
    fun downloadHLS(m3u8Url: String, movie: Movie) {
        // Parse playlist
        val playlist = HLSParser.parse(m3u8Url)
        val segments = playlist.segments
        
        // Download segments in parallel
        val downloadPool = Executors.newFixedThreadPool(8)
        segments.forEach { segment ->
            downloadPool.submit {
                downloadSegment(segment)
            }
        }
        
        // Wait for all
        downloadPool.awaitTermination()
        
        // Merge
        FFmpegKit.execute("-i 'concat:${segments.joinToString("|")}' -c copy output.mp4")
        
        // Save metadata
        db.saveDownload(movie, "output.mp4")
    }
    
    fun downloadMP4(url: String, movie: Movie) {
        // Multi-part download using HTTP Range
        val fileSize = getFileSize(url)
        val parts = splitIntoParts(fileSize, parts = 8)
        
        // Download each part in parallel
        parts.parallelMap { part ->
            httpClient.get(url, headers = mapOf("Range" to "bytes=${part.start}-${part.end}"))
        }
        
        // Merge parts
        mergeParts(parts, "output.mp4")
    }
}
```

---

## 📱 Download UI

```
Downloads Screen
├── Active Downloads
│   ├── [Movie Poster] Movie Name
│   │   ├── Progress Bar: 45% ████████░░░░░░░░
│   │   ├── Speed: 2.3 MB/s
│   │   ├── ETA: 12 min remaining
│   │   └── [Pause] [Cancel]
│   └── ...
│
├── Completed Downloads
│   ├── [Movie Poster] Movie Name (1080p) — 2.3 GB
│   │   └── [Play] [Delete] [Share]
│   └── ...
│
└── Storage Used: 15.2 GB / 64 GB
```

