# 📺 03 — Video Streaming & Multi-Audio HLS Specification

## 📌 Introduction
StreamMax application high-performance video streaming ke liye **HTTP Live Streaming (HLS - RFC 8216)** protocol use karti hai. Multi-language audio (jaise Hollywood aur Netflix titles ke liye **Hindi Dubbed** aur **English Original** audio tracks) ek single adaptive master manifest ke zariye deliver hoti hain.

Is document mein Master Manifest structure, Audio Track group specifications, aur HTML5/Hls.js Player Bridge ka complete technical breakdown diya gaya hai.

---

## 🎼 HLS Master Manifest Architecture (`master.m3u8`)

Ek standard dual-audio / multi-language HLS master stream ke andar video stream aur audio tracks alag alag renditions mein define kiye jate hain:

```m3u8
#EXTM3U
#EXT-X-VERSION:4

# --- Independent Multi-Language Audio Renditions ---
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-main",NAME="English [Original]",DEFAULT=YES,AUTOSELECT=YES,LANGUAGE="eng",URI="audio_eng.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-main",NAME="Hindi [Dubbed]",DEFAULT=NO,AUTOSELECT=YES,LANGUAGE="hin",URI="audio_hin.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-main",NAME="Spanish",DEFAULT=NO,AUTOSELECT=NO,LANGUAGE="spa",URI="audio_spa.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-main",NAME="Tamil",DEFAULT=NO,AUTOSELECT=NO,LANGUAGE="tam",URI="audio_tam.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-main",NAME="Telugu",DEFAULT=NO,AUTOSELECT=NO,LANGUAGE="tel",URI="audio_tel.m3u8"

# --- Adaptive Video Streams Linked to Audio Group ---
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,AUDIO="audio-main",CODECS="avc1.4d401f,mp4a.40.2"
video_360p.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=1800000,RESOLUTION=1280x720,AUDIO="audio-main",CODECS="avc1.4d401f,mp4a.40.2"
video_720p.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=4200000,RESOLUTION=1920x1080,AUDIO="audio-main",CODECS="avc1.640028,mp4a.40.2"
video_1080p.m3u8
```

---

## 🎧 Audio Track Switching Engine

### 1. In-Player Track Switching Mechanism
Traditional player mein jab server change hota hai toh poori video reload hoti hai aur watch position zero par chali jati hai. StreamMax ka **HLS Multi-Track Engine** video buffer ko re-download kiye baghair audio stream switch karta hai:

```
                  ┌───────────────────────────────┐
                  │    Active Video Buffer        │
                  │   (720p / 1080p Video Segs)   │
                  └──────────────┬────────────────┘
                                 │ Demuxed & Synchronized
        ┌────────────────────────┴────────────────────────┐
        ▼                                                 ▼
[Audio Stream: English]                        [Audio Stream: Hindi]
(Default / Inactive)                           (Selected by User)
```

### 2. Player Bridge (Hls.js JavaScript Integration)
Flutter WebView ke andar embed kiya gaya Hls.js player runtime audio tracks detect karta hai aur track change event execute karta hai:

```javascript
// 1. Detect Available Audio Tracks on Manifest Parsed
hls.on(Hls.Events.MANIFEST_PARSED, function() {
    var audioTracks = hls.audioTracks;
    console.log("Found " + audioTracks.length + " audio tracks.");
    
    // Auto-select Hindi track if user preference is Hindi
    if (window.preferHindiAudio) {
        for (var i = 0; i < audioTracks.length; i++) {
            var lang = (audioTracks[i].lang || "").toLowerCase();
            var name = (audioTracks[i].name || "").toLowerCase();
            if (lang.indexOf("hi") !== -1 || name.indexOf("hindi") !== -1) {
                hls.audioTrack = i;
                console.log("Switched to Hindi track index: " + i);
                break;
            }
        }
    }
});

// 2. Direct JavaScript API for Flutter UI Bridge
window.changeAudioTrack = function(trackIndex) {
    if (hls && hls.audioTracks[trackIndex]) {
        hls.audioTrack = trackIndex;
        return true;
    }
    return false;
};
```

---

## 📱 Mobile Screen Orientation & Display Controls

### 1. Fullscreen Immersive Mode
Video playback ke dauran Android hardware navigation bar aur status bar screen content ko cut na karein, iske liye immersive sticky mode implement kiya gaya hai:

```dart
// Player enter hone par
SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

// Player exit hone par (Portrait Restore)
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
]);
```

### 2. Orientation Lock & Aspect Ratio Preservation
* **Aspect Ratio:** Default 16:9 widescreen ratio maintain hota hai (`object-fit: contain`).
* **Safe Area Handling:** Display cutouts (notch) aur rounded edges ke liye CSS environment safe insets use kiye gaye hain:
  ```css
  body, html {
    margin: 0;
    padding: 0;
    width: 100vw;
    height: 100vh;
    background-color: #000;
    overflow: hidden;
    padding-top: env(safe-area-inset-top);
    padding-bottom: env(safe-area-inset-bottom);
  }
  ```

---

## 🛡️ Stream Resilience & Fallback Matrix

Agar primary HLS direct stream reach na ho sake ya rate-limit ho, player fallback ladder follow karta hai:

| Priority | Source Engine | Audio Feature | Playback Mechanism |
| :---: | :--- | :--- | :--- |
| **S1** | Direct HLS Master (`.m3u8`) | 🇮🇳 Multi-Audio (Hindi + English) | Native Hls.js HTML5 Player |
| **S2** | VidSrc VIP Cloud | English (Subtitles available) | Sandboxed IFrame with Ad-Block |
| **S3** | Secondary Embed Mirror | Multi-Language Dubbed | Secure WebView Container |

