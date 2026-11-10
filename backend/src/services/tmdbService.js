const axios = require('axios');

const TMDB_BASE_URL = 'https://api.themoviedb.org/3';
const API_KEY = process.env.TMDB_API_KEY || '15d2ea6d0dc1d476efbca3eba2b9bbfb';

const tmdbClient = axios.create({
  baseURL: TMDB_BASE_URL,
  params: {
    api_key: API_KEY,
    language: 'en-US',
  },
  timeout: 8000,
});

class TMDBService {
  /**
   * Format TMDB movie item for StreamMax
   */
  _formatItem(item, mediaType = 'movie') {
    return {
      id: item.id,
      title: item.title || item.name || 'Untitled',
      originalTitle: item.original_title || item.original_name,
      overview: item.overview,
      posterUrl: item.poster_path ? `https://image.tmdb.org/t/p/w500${item.poster_path}` : null,
      backdropUrl: item.backdrop_path ? `https://image.tmdb.org/t/p/original${item.backdrop_path}` : null,
      rating: item.vote_average ? Number(item.vote_average.toFixed(1)) : 0,
      releaseDate: item.release_date || item.first_air_date || 'N/A',
      year: (item.release_date || item.first_air_date || '').substring(0, 4) || 'N/A',
      mediaType: item.media_type || mediaType,
      popularity: item.popularity,
    };
  }

  /**
   * Home Feed: Trending, Popular, Top Rated, Now Playing
   */
  async getHomeFeed() {
    try {
      const [trendingMovies, trendingTV, nowPlaying, topRated, actionMovies] = await Promise.all([
        tmdbClient.get('/trending/movie/week'),
        tmdbClient.get('/trending/tv/week'),
        tmdbClient.get('/movie/now_playing'),
        tmdbClient.get('/movie/top_rated'),
        tmdbClient.get('/discover/movie', { params: { with_genres: 28, sort_by: 'popularity.desc' } }),
      ]);

      return {
        hero: (trendingMovies.data.results || []).slice(0, 6).map((i) => this._formatItem(i, 'movie')),
        trending: (trendingMovies.data.results || []).map((i) => this._formatItem(i, 'movie')),
        series: (trendingTV.data.results || []).map((i) => this._formatItem(i, 'tv')),
        nowPlaying: (nowPlaying.data.results || []).map((i) => this._formatItem(i, 'movie')),
        topRated: (topRated.data.results || []).map((i) => this._formatItem(i, 'movie')),
        action: (actionMovies.data.results || []).map((i) => this._formatItem(i, 'movie')),
      };
    } catch (error) {
      console.error('Error fetching home feed from TMDB:', error.message);
      throw error;
    }
  }

  /**
   * Full Movie Details by ID
   */
  async getMovieDetails(id) {
    const res = await tmdbClient.get(`/movie/${id}`, {
      params: { append_to_response: 'credits,videos,similar' },
    });
    const d = res.data;

    return {
      id: d.id,
      imdbId: d.imdb_id,
      title: d.title,
      overview: d.overview,
      posterUrl: d.poster_path ? `https://image.tmdb.org/t/p/w500${d.poster_path}` : null,
      backdropUrl: d.backdrop_path ? `https://image.tmdb.org/t/p/original${d.backdrop_path}` : null,
      rating: d.vote_average ? Number(d.vote_average.toFixed(1)) : 0,
      runtime: d.runtime,
      genres: (d.genres || []).map((g) => g.name),
      releaseDate: d.release_date,
      year: (d.release_date || '').substring(0, 4),
      tagline: d.tagline,
      mediaType: 'movie',
      cast: (d.credits?.cast || []).slice(0, 10).map((c) => ({
        name: c.name,
        character: c.character,
        photo: c.profile_path ? `https://image.tmdb.org/t/p/w185${c.profile_path}` : null,
      })),
      similar: (d.similar?.results || []).slice(0, 10).map((i) => this._formatItem(i, 'movie')),
    };
  }

  /**
   * Full TV Series Details by ID
   */
  async getTVDetails(id) {
    const res = await tmdbClient.get(`/tv/${id}`, {
      params: { append_to_response: 'credits,videos,similar' },
    });
    const d = res.data;

    return {
      id: d.id,
      title: d.name,
      overview: d.overview,
      posterUrl: d.poster_path ? `https://image.tmdb.org/t/p/w500${d.poster_path}` : null,
      backdropUrl: d.backdrop_path ? `https://image.tmdb.org/t/p/original${d.backdrop_path}` : null,
      rating: d.vote_average ? Number(d.vote_average.toFixed(1)) : 0,
      genres: (d.genres || []).map((g) => g.name),
      totalSeasons: d.number_of_seasons,
      totalEpisodes: d.number_of_episodes,
      seasons: (d.seasons || []).map((s) => ({
        seasonNumber: s.season_number,
        name: s.name,
        episodeCount: s.episode_count,
        posterUrl: s.poster_path ? `https://image.tmdb.org/t/p/w300${s.poster_path}` : null,
      })),
      mediaType: 'tv',
      cast: (d.credits?.cast || []).slice(0, 10).map((c) => ({
        name: c.name,
        character: c.character,
        photo: c.profile_path ? `https://image.tmdb.org/t/p/w185${c.profile_path}` : null,
      })),
      similar: (d.similar?.results || []).slice(0, 10).map((i) => this._formatItem(i, 'tv')),
    };
  }

  /**
   * Search Movies and TV shows
   */
  async search(query, page = 1) {
    const res = await tmdbClient.get('/search/multi', {
      params: { query, page, include_adult: false },
    });

    const results = (res.data.results || [])
      .filter((i) => i.media_type === 'movie' || i.media_type === 'tv')
      .map((i) => this._formatItem(i, i.media_type));

    return {
      page: res.data.page,
      totalPages: res.data.total_pages,
      totalResults: res.data.total_results,
      results,
    };
  }
}

module.exports = new TMDBService();

