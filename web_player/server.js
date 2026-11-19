const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const urlModule = require('url');

const PORT = 8080;
const PUBLIC_DIR = __dirname;

const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml'
};

function proxyRequest(targetUrl, clientReq, clientRes) {
  try {
    const parsed = new URL(targetUrl);
    const client = parsed.protocol === 'https:' ? https : http;

    const ott = targetUrl.includes('/hs/') ? 'hs' : (targetUrl.includes('/pv/') ? 'pv' : 'nf');
    const options = {
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: clientReq.method || 'GET',
      headers: {
        'Referer': targetUrl.includes('hakunaymatata.com') ? 'https://videodownloader.site/' : 'https://net52.cc/',
        'Origin': 'https://net52.cc',
        'User-Agent': clientReq.headers['user-agent'] || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'X-Requested-With': 'NetmirrorNewTV v1.0',
        'Ott': ott,
        'Accept': '*/*'
      }
    };

    if (clientReq.headers['range']) {
      options.headers['Range'] = clientReq.headers['range'];
    }

    const proxyReq = client.request(options, (proxyRes) => {
      // Follow 301 / 302 redirects if any
      if (proxyRes.statusCode >= 300 && proxyRes.statusCode < 400 && proxyRes.headers.location) {
        let redirectUrl = proxyRes.headers.location;
        if (!redirectUrl.startsWith('http')) {
          redirectUrl = new URL(redirectUrl, targetUrl).toString();
        }
        return proxyRequest(redirectUrl, clientReq, clientRes);
      }

      const contentType = proxyRes.headers['content-type'] || 'application/vnd.apple.mpegurl';
      const isM3u8 = targetUrl.includes('.m3u8') || contentType.includes('mpegurl') || contentType.includes('application/x-mpegURL');

      if (isM3u8) {
        // Rewrite m3u8 playlist lines so all URIs go through /proxy
        let rawBody = '';
        proxyRes.setEncoding('utf8');
        proxyRes.on('data', chunk => { rawBody += chunk; });
        proxyRes.on('end', () => {
          const lines = rawBody.split('\n');
          const baseUrl = targetUrl.substring(0, targetUrl.lastIndexOf('/') + 1);

          const rewritten = lines.map(line => {
            const trimmed = line.trim();
            if (!trimmed) return line;

            // Force Hindi audio as default track when present
            if (line.startsWith('#EXT-X-MEDIA') && line.includes('TYPE=AUDIO')) {
              let audioLine = line;
              if (audioLine.includes('LANGUAGE="hin"') || audioLine.toLowerCase().includes('hindi')) {
                audioLine = audioLine.replace(/DEFAULT=(NO|YES)/i, 'DEFAULT=YES')
                                     .replace(/AUTOSELECT=(NO|YES)/i, 'AUTOSELECT=YES');
                if (!audioLine.includes('AUTOSELECT=')) audioLine += ',AUTOSELECT=YES';
              } else {
                audioLine = audioLine.replace(/DEFAULT=YES/i, 'DEFAULT=NO')
                                     .replace(/AUTOSELECT=YES/i, 'AUTOSELECT=NO');
              }
              if (audioLine.includes('URI="')) {
                audioLine = audioLine.replace(/URI="([^"]+)"/, (match, subUri) => {
                  let resolved = subUri.startsWith('http') ? subUri : new URL(subUri, baseUrl).toString();
                  return 'URI="/proxy?url=' + encodeURIComponent(resolved) + '"';
                });
              }
              return audioLine;
            }

            // Handle other URI="..." inside attributes like #EXT-X-MEDIA (subtitles)
            if (line.startsWith('#EXT-X-MEDIA') && line.includes('URI="')) {
              return line.replace(/URI="([^"]+)"/, (match, subUri) => {
                let resolved = subUri.startsWith('http') ? subUri : new URL(subUri, baseUrl).toString();
                return 'URI="/proxy?url=' + encodeURIComponent(resolved) + '"';
              });
            }

            // Normal segment or sub-playlist URL (not a comment)
            if (!line.startsWith('#')) {
              let resolved = trimmed.startsWith('http') ? trimmed : new URL(trimmed, baseUrl).toString();
              return '/proxy?url=' + encodeURIComponent(resolved);
            }

            return line;
          }).join('\n');

          clientRes.writeHead(200, {
            'Content-Type': 'application/vnd.apple.mpegurl',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Cache-Control': 'no-cache'
          });
          clientRes.end(rewritten);
        });
      } else {
        // Direct stream media segment or MP4
        const resHeaders = {
          'Content-Type': contentType,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Cache-Control': 'public, max-age=3600'
        };
        if (proxyRes.headers['content-range']) resHeaders['Content-Range'] = proxyRes.headers['content-range'];
        if (proxyRes.headers['content-length']) resHeaders['Content-Length'] = proxyRes.headers['content-length'];
        if (proxyRes.headers['accept-ranges']) resHeaders['Accept-Ranges'] = proxyRes.headers['accept-ranges'];

        clientRes.writeHead(proxyRes.statusCode || 200, resHeaders);
        proxyRes.pipe(clientRes);
      }
    });

    proxyReq.on('error', (err) => {
      console.error('Proxy request error:', err.message);
      if (!clientRes.headersSent) {
        clientRes.writeHead(502, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
        clientRes.end('Proxy Error: ' + err.message);
      }
    });

    proxyReq.end();
  } catch (err) {
    if (!clientRes.headersSent) {
      clientRes.writeHead(400, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
      clientRes.end('Invalid URL: ' + err.message);
    }
  }
}

const server = http.createServer((req, res) => {
  // CORS Preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': '*'
    });
    return res.end();
  }

  // Proxy endpoint
  if (req.url.startsWith('/proxy')) {
    const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
    const targetUrl = parsedUrl.searchParams.get('url');
    if (!targetUrl) {
      res.writeHead(400, { 'Content-Type': 'text/plain' });
      return res.end('Missing ?url= parameter');
    }
    return proxyRequest(targetUrl, req, res);
  }

  // Clean stream resolver endpoint (Direct 1080p MP4 without warning clip)
  if (req.url.startsWith('/api/clean-stream')) {
    const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
    const tmdbId = parsedUrl.searchParams.get('tmdb') || '71446';
    const type = parsedUrl.searchParams.get('type') || 'tv';
    const season = parsedUrl.searchParams.get('s') || '1';
    const episode = parsedUrl.searchParams.get('e') || '1';

    const netUrl = type === 'tv'
      ? `https://net27.cc/api/embed-tmdb/${tmdbId}?type=tv&se=${season}&ep=${episode}`
      : `https://net27.cc/api/embed-tmdb/${tmdbId}`;

    https.get(netUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://net27.cc/'
      }
    }, (upstreamRes) => {
      let body = '';
      upstreamRes.on('data', chunk => body += chunk);
      upstreamRes.on('end', () => {
        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(body);
      });
    }).on('error', (err) => {
      res.writeHead(500, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

  // MovieBox Live Hindi Stream Resolver (always fresh, never expires)
  if (req.url.startsWith('/api/moviebox-stream')) {
    const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
    const subjectId = parsedUrl.searchParams.get('subjectId') || '7147213651240699592';
    const detailPath = parsedUrl.searchParams.get('detailPath') || 'money-heist-hindi-0A6xcmujYv8';
    const season = parsedUrl.searchParams.get('se') || '1';
    const episode = parsedUrl.searchParams.get('ep') || '1';

    const apiUrl = `https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play?subjectId=${subjectId}&se=${season}&ep=${episode}&detailPath=${detailPath}&streamSignType=1`;
    const referer = `https://movie-box.co/movies/${detailPath}?id=${subjectId}&type=/movie/detail&detailSe=${season}&detailEp=${episode}&lang=hi`;

    https.get(apiUrl, {
      headers: {
        'Origin': 'https://movie-box.co',
        'Referer': referer,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*'
      }
    }, (upstreamRes) => {
      let body = '';
      upstreamRes.on('data', chunk => body += chunk);
      upstreamRes.on('end', () => {
        try {
          const json = JSON.parse(body);
          const streams = json.data && json.data.streams ? json.data.streams : [];
          let selected = streams.find(s => s.resolutions === '720' || s.resolutions === '1080') || streams[0];
          if (selected && selected.url) {
            console.log(`[MovieBox] Live resolved ${season}x${episode} (${selected.resolutions}p): ${selected.url.substring(0, 80)}...`);
            res.writeHead(302, {
              'Location': '/proxy?url=' + encodeURIComponent(selected.url),
              'Access-Control-Allow-Origin': '*'
            });
            return res.end();
          }
          res.writeHead(404, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
          res.end(JSON.stringify({ error: 'Stream not found in MovieBox response' }));
        } catch (e) {
          res.writeHead(500, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
          res.end(JSON.stringify({ error: e.message }));
        }
      });
    }).on('error', err => {
      res.writeHead(500, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

  // Static file serving
  let filePath = path.join(PUBLIC_DIR, req.url === '/' ? 'index.html' : req.url.split('?')[0]);
  let ext = path.extname(filePath).toLowerCase();
  let contentType = MIME_TYPES[ext] || 'text/plain';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('404 Not Found');
      } else {
        res.writeHead(500);
        res.end('Server error: ' + err.code);
      }
    } else {
      res.writeHead(200, {
        'Content-Type': contentType,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Referrer-Policy': 'no-referrer-when-downgrade',
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0'
      });
      res.end(content);
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 StreamMax Web Player & HLS Proxy running at http://localhost:${PORT}/`);
});
