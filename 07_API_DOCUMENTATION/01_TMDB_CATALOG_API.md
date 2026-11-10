# 🎬 01 — TMDB Metadata Provider API Specification

## 📌 Introduction
StreamMax application movie aur TV series ka high-quality metadata fetch karne ke liye **The Movie Database (TMDB) API v3** use karti hai. Is document mein un tamam endpoints, query parameters, data models, aur image CDN URLs ki detail mojood hai jo client-side application consume karti hai.

---

## 🔑 Authentication & Configuration

```http
Base URL: https://api.themoviedb.org/3
Auth Type: API Key (URL Query Parameter)
Param: ?api_key={TMDB_API_KEY}
Format: JSON (Content-Type: application/json)
Rate Limit: 40 requests per 10 seconds per IP
```

### Image CDN Architecture
TMDB posters aur backdrops high-speed CDN ke zariye deliver karta hai:
* **Poster CDN Base:** `https://image.tmdb.org/t/p/w500{poster_path}` (Mobile UI List view ke liye optimal resolution)
* **Backdrop CDN Base:** `https://image.tmdb.org/t/p/original{backdrop_path}` (Detail Screen banner ke liye high resolution)
* **Profile CDN Base:** `https://image.tmdb.org/t/p/w185{profile_path}` (Cast & Crew avatars ke liye)

---

## 📡 Core Catalog Endpoints

### 1. Trending Movies
Haftawaar trending movies ki list fetch karta hai jo Home screen ke main carousel aur trending slider mein show hoti hain.

```http
GET /trending/movie/week?api_key={KEY}
```

#### Response Structure (200 OK):
```json
{
  "page": 1,
  "results": [
    {
      "id": 1022789,
      "title": "Inside Out 2",
      "original_title": "Inside Out 2",
      "overview": "Teenager Riley's mind headquarters is undergoing a sudden demolition...",
      "poster_path": "/vpnVM9B6NMmQpWeZvzLvDESb2QY.jpg",
      "backdrop_path": "/stKGOmPAg2kQxL9nFw2FqV28r3j.jpg",
      "media_type": "movie",
      "vote_average": 7.6,
      "release_date": "2024-06-11",
      "genre_ids": [16, 10751, 12, 35]
    }
  ],
  "total_pages": 1000,
  "total_results": 20000
}
```

---

### 2. Trending TV Series
Popular TV series ki list fetch karta hai (jaise *Money Heist*, *Berlin*, *Stranger Things*).

```http
GET /trending/tv/week?api_key={KEY}
```

#### Response Fields Mapping:
* TV shows mein `title` ki jagah `name` field hoti hai.
* `release_date` ki jagah `first_air_date` aati hai.
* Client Model mapping: `title = item['title'] ?? item['name'] ?? 'Unknown'`.

---

### 3. Bollywood & Hindi Hits / Dubbed Filter
Hindi dubbed aur Bollywood titles ko prioritize karne ke liye discover endpoint query filter kiya jata hai.

```http
GET /discover/movie?api_key={KEY}&with_original_language=hi&sort_by=popularity.desc
```

#### Query Parameters:
* `with_original_language=hi`: Sirf Hindi audio/language content filter karta hai.
* `sort_by=popularity.desc`: Sabse zyada dekhi jane wali movies pehle aati hain.
* `include_adult=false`: Safe content filtering.

---

### 4. Multi-Search & Hindi Dubbed Keyword Handling
Jab user search bar mein movie ya series search karta hai (e.g., `"Money Heist"`, `"Berlin in Hindi"`, `"Inception"`):

```http
GET /search/multi?api_key={KEY}&query={SEARCH_QUERY}&page=1&include_adult=false
```

#### Hindi Dubbed Search Sanitization Logic:
Client-side search engine agar user `"Money Heist in Hindi"` search kare, toh query ko clean karta hai taake TMDB 0 results na de:
```dart
String cleanQuery = query
    .replaceAll(RegExp(r'\b(in hindi|hindi dubbed|hindi audio|dual audio)\b', caseSensitive: false), '')
    .trim();
```
1. Clean query se TMDB metadata fetch hota hai.
2. Filter state activate hoti hai taake video player screen default audio track **Hindi (🇮🇳)** select kare.

---

### 5. Movie Detailed Information & Cast
Movie ki full detail, runtime, genres, aur top cast fetch karne ke liye:

```http
GET /movie/{id}?api_key={KEY}&append_to_response=credits,recommendations
```

#### Key Response Data:
```json
{
  "id": 1022789,
  "title": "Inside Out 2",
  "runtime": 96,
  "genres": [{"id": 16, "name": "Animation"}, {"id": 10751, "name": "Family"}],
  "credits": {
    "cast": [
      {
        "id": 12898,
        "name": "Amy Poehler",
        "character": "Joy (voice)",
        "profile_path": "/rP2Ue7XjE8g6g0...jpg"
      }
    ]
  }
}
```

---

### 6. TV Series Seasons & Episodes Breakdown
Kisi bhi TV Series (e.g. *Money Heist* ID `71446`) ke episodes fetch karne ke liye season-specific endpoint:

```http
GET /tv/{series_id}/season/{season_number}?api_key={KEY}
```

#### Response Structure:
```json
{
  "_id": "5919e917c3a3684a0a01061c",
  "air_date": "2017-05-02",
  "season_number": 1,
  "name": "Season 1",
  "episodes": [
    {
      "id": 1335962,
      "episode_number": 1,
      "name": "Episode 1",
      "overview": "The Professor recruits a young female robber and seven other criminals...",
      "runtime": 47,
      "still_path": "/xGex15g8eJpI02iF...jpg",
      "vote_average": 8.3
    }
  ]
}
```

---

## ⚡ Client-Side Parallel Concurrency Model
Feed load time ko minimize karne ke liye Flutter client `Future.wait` ka use karta hai:

```dart
final responses = await Future.wait([
  http.get(Uri.parse('$tmdbUrl/trending/movie/week?api_key=$key')).timeout(const Duration(seconds: 7)),
  http.get(Uri.parse('$tmdbUrl/trending/tv/week?api_key=$key')).timeout(const Duration(seconds: 7)),
  http.get(Uri.parse('$tmdbUrl/discover/movie?api_key=$key&with_original_language=hi&sort_by=popularity.desc')).timeout(const Duration(seconds: 7)),
  http.get(Uri.parse('$tmdbUrl/movie/top_rated?api_key=$key')).timeout(const Duration(seconds: 7)),
]);
```
* **Performance Gain:** 4 sequential calls (~6.5 seconds) se reduce hokar parallel call (~1.1 seconds) mein complete hoti hain.

