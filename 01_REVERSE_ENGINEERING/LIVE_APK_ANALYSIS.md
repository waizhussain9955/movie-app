# 🔬 Live APK Binary Analysis & Decompilation Report

> **Target Files:**
> 1. `moviebox-v-4.0.03.1028.03.apk` (76.2 MB) — MD5/Structure Verified
> 2. `NetMirror.apk` (51.5 MB) — MD5/Structure Verified

---

## 1. 🎬 MovieBox Teardown (`com.community.moviebox`)

### 1.1 Technical Stack & Core Engine
* **Application Framework:** Native Android (Kotlin & Java) with heavy C/C++ NDK bindings.
* **Internal Package Root:** `com.community.moviebox`
* **Parent Architecture:** `com.transsion.subroom` & `com.transsnet.*`

### 1.2 Video Player Subsystem (The Engine Secret)
MovieBox does NOT use Google’s default ExoPlayer out-of-the-box. Instead, it embeds a custom multimedia playback stack:
* **`libmpv.so`:** Full **MPV Player** engine compiled for Android. This gives it hardware-accelerated demuxing, seamless subtitle styling, and universal codec playback (MKV, MP4, WebM, HLS/m3u8, DASH).
* **`libalivcffmpeg.so` & FFmpeg libraries (`libavcodec.so`, `libavformat.so`, `libavfilter.so`, `libavutil.so`):** Custom Alibaba / AliVC FFmpeg build used for live stream packet ingestion.
* **`libgav1JNI.so`:** Dedicated AV1 codec decoder (Google’s libgav1) allowing ultra-compressed HD playback at minimal mobile data bandwidth.
* **`libsaasCorePlayer.so` / `libplayer.so`:** Proprietary playback abstraction engine.

### 1.3 Local Storage & State Management
* **`libmmkv.so`:** Uses Tencent’s **MMKV** (Memory-Mapped Key-Value store) rather than standard Android `SharedPreferences` or Room DB. This provides sub-millisecond read/write speeds across background downloader services and foreground UI.

### 1.4 Navigation & App Layout (Extracted from `appTab.json`)
The application is structured into 5 foundational navigation hubs:
1. `BT_HOME` (`Home`): Movies & TV show feeds, hero carousel, trending categories.
2. `BT_NOVEL` (`NovelHub`): Web novels & digital fiction reader.
3. `BT_SHORTTV` (`ShortTV`): Short vertical drama episodes (TikTok / Reel format).
4. `BT_DOWNLOADS` (`Downloads`): Download manager, offline storage, queue status.
5. `BT_ME` (`Me`): User profile, watch history, device management, parental PIN settings.

### 1.5 Unique Modules Discovered in Manifest
* **WiFi P2P Offline Transfer:** `com.transsion.transfer.wifi.ui.WifiConnectActivity` — Allows peer-to-peer high-speed movie sharing between nearby devices without mobile data or internet.
* **Download Guard Service:** `com.transsnet.downloader.guard.DownloadGuardService` and `ForegroundService` — Prevents Android OS from killing active downloads when the app is minimized or phone screen is locked.
* **Parental Controls:** `com.transsion.usercenter.kids.PinManagementActivity` — Profiles with PIN restrictions for sensitive content.
* **TV Link:** `com.transsion.usercenter.tvlink.TvDownloadWebLinkActivity` — Browser push-to-TV download pairing.

### 1.6 Extracted Backend Domains & Active CDN Endpoints
* Primary Content & Media CDN: `pbcdn.aoneroom.com`, `v.aoneroom.com`, `h5.aoneroom.com`
* Regional Streaming Mirrors:
  * `v.moviebox.ng` (Nigeria node)
  * `v.moviebox.ph` (Philippines node)
  * `movie-box.co`, `movie-box.tv`
  * `themoviebox.xyz`, `themoviebox.org`
  * `playmoviebox.com`, `boxmovies.org`
  * `moviebox.studio`, `moviebox.biz`

---

## 2. 🪞 NetMirror Teardown (`app.netmirror.nmv2`)

### 2.1 Technical Stack & Core Engine
* **Application Framework:** **React Native** running Facebook’s **Hermes Bytecode Engine** (`libhermes.so`, `libjsi.so`, `libreactnative.so`).
* **Bundle Target:** `assets/index.android.bundle` (Hermes compiled binary bytecode, 1.2 MB).
* **Package Identifier:** `app.netmirror.nmv2`

### 2.2 UI & Component Libraries
* **Vector Icons:** Full suite of `react-native-vector-icons` (`FontAwesome`, `AntDesign`, `Feather`, `Entypo`, `EvilIcons`).
* **Gesture System:** `react-native-gesture-handler` (`libgesturehandler.so`).
* **Image Pipeline:** Facebook Fresco (`libimagepipeline.so`).

### 2.3 Streaming, Mirroring & Casting Engine
* **Web Sniffer Component:** Uses `RNCWebViewFileProvider` and React Native WebView to load media hosters. It executes DOM injection scripts to intercept HTML5 `<video>` elements, `.m3u8` playlists, and direct MP4 URLs.
* **Cast SDK Bridge:** Bridges native Android Chromecast and DLNA libraries to React Native JavaScript layer to send video streams directly to Smart TVs.
* **Security & Obfuscation:** Critical API routes and mirror resolvers are Base64-obfuscated inside the Hermes bytecode bundle.

---

## 3. 🎯 Architectural Comparison Matrix

| Dimension | MovieBox (`com.community.moviebox`) | NetMirror (`app.netmirror.nmv2`) |
| :--- | :--- | :--- |
| **Framework** | Native Kotlin / Java + C++ | React Native + Hermes Engine |
| **Video Playback** | MPV Player + Custom FFmpeg | Native Video / WebView Stream Bridge |
| **Local Storage** | Tencent MMKV (High performance) | AsyncStorage / MMKV Bridge |
| **Ad Monetization** | ByteDance Pangle (`openadsdk`), Vungle, Hisavana | AdMob / Unity Ads |
| **Strengths** | Rock-solid offline downloads, P2P sharing | Screen mirroring, browser video sniffer |
| **Weaknesses** | Heavy APK footprint (76 MB), complex native code | Slower JS bridge, heavier memory footprint on low-end devices |

