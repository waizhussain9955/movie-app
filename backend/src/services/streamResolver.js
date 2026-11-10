/**
 * StreamMax Multi-Server Stream Aggregator & Resolver Engine
 * Aggregates live servers for Movies and TV Shows.
 * If Server 1 fails or is slow, the client player auto-switches to Server 2, 3, etc.
 */

class StreamResolver {
  /**
   * Resolve all available video servers for a given TMDB / IMDB ID
   * @param {Object} params
   * @param {string} params.type - 'movie' or 'tv'
   * @param {string|number} params.id - TMDB ID
   * @param {string} [params.imdbId] - IMDB ID (e.g. tt1234567)
   * @param {number} [params.season] - Season number (for TV)
   * @param {number} [params.episode] - Episode number (for TV)
   */
  resolveServers({ type = 'movie', id, imdbId = '', season = 1, episode = 1 }) {
    const servers = [];
    const safeImdb = imdbId || '';

    // 1. Server 1: VidSrc Premium (High Speed, HLS + Multi-audio)
    if (type === 'movie') {
      servers.push({
        id: 1,
        name: 'Server 1 (VidSrc Pro - Fast HD)',
        type: 'embed',
        quality: '1080p',
        url: `https://vidsrc.to/embed/movie/${id}`,
        backupUrl: safeImdb ? `https://vidsrc.me/embed/movie?imdb=${safeImdb}` : `https://vidsrc.me/embed/movie?tmdb=${id}`,
        status: 'active',
        priority: 1,
      });
    } else {
      servers.push({
        id: 1,
        name: 'Server 1 (VidSrc Pro - Fast HD)',
        type: 'embed',
        quality: '1080p',
        url: `https://vidsrc.to/embed/tv/${id}/${season}/${episode}`,
        backupUrl: `https://vidsrc.me/embed/tv?tmdb=${id}&season=${season}&episode=${episode}`,
        status: 'active',
        priority: 1,
      });
    }

    // 2. Server 2: VidLink (Ultra Fast, Clean, No-Ads stream provider)
    if (type === 'movie') {
      servers.push({
        id: 2,
        name: 'Server 2 (VidLink Ultra - Multi-Subtitles)',
        type: 'embed',
        quality: '1080p',
        url: `https://vidlink.pro/movie/${id}`,
        status: 'active',
        priority: 2,
      });
    } else {
      servers.push({
        id: 2,
        name: 'Server 2 (VidLink Ultra - Multi-Subtitles)',
        type: 'embed',
        quality: '1080p',
        url: `https://vidlink.pro/tv/${id}/${season}/${episode}`,
        status: 'active',
        priority: 2,
      });
    }

    // 3. Server 3: EmbedSu (Direct HLS Streams & MP4)
    if (type === 'movie') {
      servers.push({
        id: 3,
        name: 'Server 3 (EmbedSu - Direct HLS 4K/1080p)',
        type: 'embed',
        quality: '1080p',
        url: `https://embed.su/embed/movie/${id}`,
        status: 'active',
        priority: 3,
      });
    } else {
      servers.push({
        id: 3,
        name: 'Server 3 (EmbedSu - Direct HLS 4K/1080p)',
        type: 'embed',
        quality: '1080p',
        url: `https://embed.su/embed/tv/${id}/${season}/${episode}`,
        status: 'active',
        priority: 3,
      });
    }

    // 4. Server 4: 2Embed (Worldwide Mirror)
    if (type === 'movie') {
      servers.push({
        id: 4,
        name: 'Server 4 (2Embed CDN Mirror)',
        type: 'embed',
        quality: '720p',
        url: `https://www.2embed.cc/embed/${id}`,
        backupUrl: safeImdb ? `https://2embed.org/embed/${safeImdb}` : '',
        status: 'active',
        priority: 4,
      });
    } else {
      servers.push({
        id: 4,
        name: 'Server 4 (2Embed CDN Mirror)',
        type: 'embed',
        quality: '720p',
        url: `https://www.2embed.cc/embedtv/${id}&s=${season}&e=${episode}`,
        status: 'active',
        priority: 4,
      });
    }

    // 5. Server 5: MultiEmbed / AutoEmbed (Global Failover)
    if (type === 'movie') {
      servers.push({
        id: 5,
        name: 'Server 5 (AutoEmbed Global VIP)',
        type: 'embed',
        quality: '1080p',
        url: `https://player.autoembed.cc/embed/movie/${id}`,
        status: 'active',
        priority: 5,
      });
    } else {
      servers.push({
        id: 5,
        name: 'Server 5 (AutoEmbed Global VIP)',
        type: 'embed',
        quality: '1080p',
        url: `https://player.autoembed.cc/embed/tv/${id}/${season}/${episode}`,
        status: 'active',
        priority: 5,
      });
    }

    // 6. Server 6: SuperEmbed (Backup Mirror)
    if (type === 'movie') {
      servers.push({
        id: 6,
        name: 'Server 6 (SuperEmbed Emergency Backup)',
        type: 'embed',
        quality: '720p',
        url: safeImdb ? `https://multiembed.mov/directstream.php?video_id=${safeImdb}` : `https://multiembed.mov/directstream.php?video_id=${id}&tmdb=1`,
        status: 'active',
        priority: 6,
      });
    } else {
      servers.push({
        id: 6,
        name: 'Server 6 (SuperEmbed Emergency Backup)',
        type: 'embed',
        quality: '720p',
        url: safeImdb ? `https://multiembed.mov/directstream.php?video_id=${safeImdb}&s=${season}&e=${episode}` : `https://multiembed.mov/directstream.php?video_id=${id}&tmdb=1&s=${season}&e=${episode}`,
        status: 'active',
        priority: 6,
      });
    }

    return servers;
  }
}

module.exports = new StreamResolver();

