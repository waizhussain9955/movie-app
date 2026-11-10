# 🛡️ App Permissions Specification & Guide

> **Project Target:** StreamMax (Movie & Cast Streaming App)
> **Platform Coverage:** Android (API 21 - 34+) & iOS (14 - 18+)

---

## 1. 📋 Summary of Required Permissions

Here is the master list of all permissions discovered in the reverse engineering of MovieBox & NetMirror, categorized by function and necessity:

| Permission Name | Category | Android Level | Necessity | Why It's Needed |
| :--- | :--- | :--- | :--- | :--- |
| `INTERNET` | Network | Normal | **Mandatory** | Streaming video, fetching TMDB metadata, API calls. |
| `ACCESS_NETWORK_STATE` | Network | Normal | **Mandatory** | Detect whether user is on WiFi or Mobile data before downloading. |
| `ACCESS_WIFI_STATE` | Network / Cast | Normal | **Mandatory** | Discover Smart TVs, Chromecasts, and local DLNA devices on WiFi. |
| `CHANGE_WIFI_STATE` | P2P Share | Dangerous | Optional (Feature) | Setting up WiFi Direct for offline phone-to-phone movie sharing. |
| `NEARBY_WIFI_DEVICES` | Cast / P2P | Dangerous (API 33+) | **Required on Android 13+** | Discovers nearby casting devices without requesting fine GPS location. |
| `FOREGROUND_SERVICE` | Background | Normal | **Mandatory** | Keeps video playing in background and prevents download termination. |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Background | Normal (API 34+) | **Mandatory on Android 14+** | Required by Google for background audio/video playback. |
| `WAKE_LOCK` | Power | Normal | **Mandatory** | Prevents CPU from sleeping while an offline movie is downloading. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Power | Special | Optional (User Prompt) | Stops aggressive battery savers (Xiaomi/Samsung/Oppo) from killing downloads. |
| `POST_NOTIFICATIONS` | Notification | Dangerous (API 33+) | **Mandatory on Android 13+** | Displays download progress bar and player playback controls in notification shade. |
| `READ_MEDIA_VIDEO` | Storage | Dangerous (API 33+) | **Mandatory on Android 13+** | Accessing downloaded movies in external storage. |
| `READ_MEDIA_AUDIO` | Storage | Dangerous (API 33+) | Optional | Playing custom audio tracks or downloaded podcasts/novels. |
| `READ_EXTERNAL_STORAGE` | Storage | Dangerous (≤ API 32) | **Legacy Mandatory** | Accessing storage on Android 12 and below. |
| `WRITE_EXTERNAL_STORAGE` | Storage | Dangerous (≤ API 28) | **Legacy Mandatory** | Saving movies directly to public `Download/` folder on older Android versions. |
| `SYSTEM_ALERT_WINDOW` | UI / Overlay | Special | Optional | Floating mini-player (Picture-in-Picture fallback for older devices). |

---

## 2. 📱 Android Permissions Breakdown by Feature

### 2.1 Core Video Streaming & Metadata
These permissions require no runtime popups; they are granted automatically upon app install:
```xml
<!-- In AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```
* **Use Case:** Every time the app talks to our Fastify API or streams an HLS segment from BunnyCDN.

---

### 2.2 Offline Downloads & Download Guard Service
Android aggressively shuts down background processes to conserve battery. To ensure a 2GB movie finishes downloading even when the user locks their phone, these permissions are required:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

#### Runtime Strategy (Android 13+):
On Android 13 (API 33) and above, the app must request `POST_NOTIFICATIONS` before starting a download so the user sees:
> *"Downloading: Spider-Man (1080p) — 45% (3.2 MB/s)"*

---

### 2.3 Storage & File Saving Strategy (Modern Scoped Storage)

Google has changed how storage permissions work across Android versions:

```xml
<!-- For Android 12 and below (Legacy) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />

<!-- For Android 13+ (Modern Granular) -->
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

> 💡 **Best Practice Recommendation:**
> Store downloads inside the app’s isolated internal directory:
> `context.getExternalFilesDir(Environment.DIRECTORY_MOVIES)`
> **Benefit:** If saved here, our app needs **ZERO storage permissions** on modern Android! The files are secure, protected from other apps, and automatically removed if the app is uninstalled.

---

### 2.4 Cast to TV & Local Network Discovery

To stream content to a Chromecast, Android TV, or Samsung Smart TV (DLNA), the app must scan the local WiFi network:

```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />

<!-- Android 13+ Nearby Devices permission -->
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" 
                   android:usesPermissionFlags="neverForLocation" />
```

* **Important Note:** On older Android versions (Android 11 and below), scanning for local WiFi devices technically required `ACCESS_FINE_LOCATION` because WiFi SSIDs could be used to deduce location. On Android 13+, `NEARBY_WIFI_DEVICES` with `neverForLocation` flag solves this without asking for creepy location access!

---

### 2.5 Offline P2P Transfer (MovieBox Feature)
If implementing the MovieBox offline file-sharing feature (sharing videos phone-to-phone via WiFi Direct):
```xml
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```
* **Note:** This should only be requested when the user taps "Share via WiFi P2P", not at startup.

---

## 3. 🍎 iOS Required Permissions (`Info.plist`)

On iOS, permissions are defined in `ios/Runner/Info.plist` with clear rationale strings:

```xml
<dict>
    <!-- Background Audio / Video Playback -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>fetch</string>
        <string>processing</string>
    </array>

    <!-- Local Network Discovery for Chromecast / AirPlay / DLNA -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>StreamMax requires local network access to discover and stream movies to your Smart TV or Chromecast.</string>
    
    <key>NSBonjourServices</key>
    <array>
        <string>_googlecast._tcp</string>
        <string>_airplay._tcp</string>
    </array>

    <!-- Photo Library / Saving Videos (Optional) -->
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>StreamMax needs permission to save downloaded videos to your Photos album.</string>
</dict>
```

---

## 4. 🛡️ User Experience & Permission Best Practices

1. **Zero Permission Startup:** Never ask for permissions during the Splash Screen or on first launch. Allow the user to browse movies, view trailers, and search freely without any popups.
2. **Contextual Asking:**
   * Only ask for `POST_NOTIFICATIONS` when the user clicks **Download**.
   * Only ask for Local Network when the user taps the **Cast to TV** icon.
3. **Graceful Fallbacks:** If the user denies notification access, continue the download silently without crashing the app.

