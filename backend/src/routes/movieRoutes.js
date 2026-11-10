const express = require('express');
const router = express.Router();
const tmdbService = require('../services/tmdbService');
const streamResolver = require('../services/streamResolver');
const Movie = require('../models/Movie');

/**
 * GET /api/home
 * Home Screen Feed (Featured Carousel, Trending, TV Series, Top Rated)
 */
router.get('/home', async (req, res) => {
  try {
    const feed = await tmdbService.getHomeFeed();
    res.json({ success: true, data: feed });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/search?q=batman
 * Instant Search
 */
router.get('/search', async (req, res) => {
  const query = req.query.q;
  const page = parseInt(req.query.page) || 1;
  if (!query) {
    return res.status(400).json({ success: false, message: 'Query parameter q is required' });
  }

  try {
    const results = await tmdbService.search(query, page);
    res.json({ success: true, data: results });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/movie/:id
 * Full Movie Details + Embedded Servers
 */
router.get('/movie/:id', async (req, res) => {
  const tmdbId = req.params.id;
  try {
    const details = await tmdbService.getMovieDetails(tmdbId);
    const servers = streamResolver.resolveServers({
      type: 'movie',
      id: tmdbId,
      imdbId: details.imdbId,
    });

    details.servers = servers;

    // Async cache to MongoDB in background without blocking response
    Movie.findOneAndUpdate(
      { tmdbId: Number(tmdbId) },
      {
        $set: {
          tmdbId: details.id,
          imdbId: details.imdbId,
          title: details.title,
          overview: details.overview,
          posterUrl: details.posterUrl,
          backdropUrl: details.backdropUrl,
          rating: details.rating,
          year: details.year,
          genres: details.genres,
          runtime: details.runtime,
          servers: servers,
          lastFetchedAt: new Date(),
        },
        $inc: { views: 1 },
      },
      { upsert: true, new: true }
    ).catch(() => {});

    res.json({ success: true, data: details });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/tv/:id
 * Full TV Series Details
 */
router.get('/tv/:id', async (req, res) => {
  const tmdbId = req.params.id;
  try {
    const details = await tmdbService.getTVDetails(tmdbId);
    res.json({ success: true, data: details });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * GET /api/stream/:type/:id
 * Dedicated stream server list (supports season & episode for TV shows)
 * Example: /api/stream/movie/550
 * Example: /api/stream/tv/1399?s=1&e=1
 */
router.get('/stream/:type/:id', async (req, res) => {
  const { type, id } = req.params;
  const season = parseInt(req.query.s) || 1;
  const episode = parseInt(req.query.e) || 1;
  const imdbId = req.query.imdb || '';

  try {
    const servers = streamResolver.resolveServers({
      type,
      id,
      imdbId,
      season,
      episode,
    });

    res.json({
      success: true,
      mediaType: type,
      id,
      season,
      episode,
      totalServers: servers.length,
      servers,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;

