# 📱 04 — Flutter Client API Integration Architecture

## 📌 Introduction
StreamMax Flutter client application (`streammax_app`) ka service layer robust, modular aur asynchronous design pattern par mabni hai. Client layer metadata fetching, local caching, stream resolution, aur video player state handling ko clean separation of concerns ke sath manage karti hai.

---

## 🏛️ Service Layer Architecture

```
                  ┌──────────────────────────────────┐
                  │       Flutter Presentation       │
                  │ (HomeScreen / Detail / Player)   │
                  └─────────────────┬────────────────┘
                                    │
           ┌────────────────────────┼────────────────────────┐
           ▼                        ▼                        ▼
┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│    ApiService      │   │  NetMirrorService  │   │   StorageService   │
│ (Metadata/Catalog) │   │ (Multi-Audio HLS)  │   │  (Cache / History) │
└──────────┬─────────┘   └──────────┬─────────┘   └──────────┬─────────┘
           │                        │                        │
           ▼                        ▼                        ▼
     TMDB v3 API             Master HLS Stream         SQLite Database
   (Trending/Search)         (Multi-Track M3U8)        (Favorites/Progress)
```

---

## 🛠️ Key Client Services

### 1. `ApiService` (`lib/services/api_service.dart`)
Application ka central metadata orchestrator hai.

* **Parallel Home Feed Fetching:**
  `getHomeFeed()` 4 mukhtalif categories (Trending Movies, Trending Series, Bollywood/Hindi Hits, Top Rated) ko parallel execute karta hai:
  ```dart
  static Future<Map<String, List<Movie>>> getHomeFeed() async {
    final futures = await Future.wait([
      http.get(Uri.parse('$tmdbUrl/trending/movie/week?api_key=$key')).timeout(const Duration(seconds: 7)),
      http.get(Uri.parse('$tmdbUrl/trending/tv/week?api_key=$key')).timeout(const Duration(seconds: 7)),
      http.get(Uri.parse('$tmdbUrl/discover/movie?api_key=$key&with_original_language=hi&sort_by=popularity.desc')).timeout(const Duration(seconds: 7)),
      http.get(Uri.parse('$tmdbUrl/movie/top_rated?api_key=$key')).timeout(const Duration(seconds: 7)),
    ]);
    ...
  }
  ```

* **In-Memory Search Caching:**
  User ki queries ko instant render karne ke liye `Map<String, List<Movie>> _searchCache` implement kiya gaya hai taake bar bar network requests na bhejne paren.

* **Server Priority Matrix Generator:**
  `generateServers(...)` function movie ya TV episode ke liye streaming sources ki list banata hai. Agar NetMirror direct HLS resolve ho chuka ho, toh woh priority #1 par inject hota hai:
  ```dart
  static List<Map<String, dynamic>> generateServers({
    required String tmdbId,
    required String mediaType,
    int season = 1,
    int episode = 1,
    String? netMirrorStreamUrl,
  }) {
    List<Map<String, dynamic>> servers = [];
    if (netMirrorStreamUrl != null && netMirrorStreamUrl.isNotEmpty) {
      servers.add({
        'name': 'Server 1 (Dual Audio / Hindi VIP)',
        'url': netMirrorStreamUrl,
        'isDirectHls': true,
      });
    }
    // Standard redundant fallback servers
    servers.add({
      'name': 'Server 2 (VidSrc Cloud)',
      'url': 'https://vidsrc.me/embed/...',
      'isDirectHls': false,
    });
    return servers;
  }
  ```

---

### 2. `NetMirrorService` (`lib/services/netmirror_service.dart`)
Multi-language / Dual-audio HLS streams ko dynamically resolve karta hai.

* **Asynchronous Resolution Flow:**
  1. Discovery handshake se active playback domain resolve hota hai.
  2. Movie title ya TMDB ID se stream master playlist identify hoti hai.
  3. TV episodes ke liye season/episode mapping verify hoti hai.
  4. Client ko direct `.m3u8` master URL return hota hai jismein 18 audio tracks (including Hindi) mojood hote hain.

---

### 3. `PlayerScreen` (`lib/screens/player_screen.dart`)
Video playback engine jo direct HLS aur web embed servers ko automatically handle karta hai:

* **Automatic Stream Type Detection:**
  Agar active URL `.m3u8` contain karta hai, toh player native HTML5 `Hls.js` player container render karta hai.
* **Hindi Audio Selection Pill:**
  App bar aur in-player floating pill `[ 🎧 Audio: 🇮🇳 Hindi ]` user ko single click par Hindi dubbing activate karne ki suvidha deta hai.
* **Ad & Popup Sandboxing:**
  WebView mein unapproved navigations aur malicious redirects block kiye jate hain:
  ```dart
  NavigationDecision.prevent; // Kisi bhi unauthorized external ad-domain redirection ko block karta hai
  ```

---

## 📈 Performance & Error Handling Best Practices
1. **Timeout Safeguard:** Tamam API requests 7-second strict timeout ke sath wrap ki gayi hain taake slow network par UI freeze na ho.
2. **Offline Fallback Data:** Agar internet disconnection ho jaye, toh service built-in cached sample models serve karti hai taake app crash na kare.
3. **Memory Cleanup:** Player close hote hi WebView memory clear karta hai taake background battery drain na ho.

