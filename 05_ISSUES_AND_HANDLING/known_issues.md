# 🚨 Known Issues & Fixes — StreamMax

## Overview
Common issues jo aate hain streaming apps mein aur unke solutions.

---

## 🎬 Streaming Issues

### Issue 1: Video Not Loading
```
Problem: User taps play, spinner shows, never loads.
Causes:
  - CDN URL expired
  - Server is down
  - Network too slow to buffer
  - SSL certificate expired on server
  - App API call failing

Fix (App Side):
  1. Auto-retry with fresh stream URL (re-call /stream endpoint)
  2. Auto-switch to Server 2, then Server 3
  3. Show "Switching to backup..." message

Fix (Backend Side):
  1. Health checker marks dead server
  2. Auto-replace URL if possible
  3. Alert content manager if all servers dead

User Message: "Loading stream... Please wait"
If 10s pass: "Trying alternate server..."
If all fail: "Video temporarily unavailable. Try again later."
```

### Issue 2: Buffering / Choppy Playback
```
Problem: Video plays but keeps pausing to buffer.
Causes:
  - User's internet too slow
  - CDN edge not cached (cold request)
  - Server bandwidth throttled

Fix:
  - Detect buffer stalls → auto-switch to lower quality
  - Show quality indicator to user
  - Pre-buffer 30 seconds ahead

Code:
  if (bufferProgress < 10 seconds) {
    switchToLowerQuality();
  }
```

### Issue 3: Audio/Video Out of Sync
```
Problem: Audio is late or ahead of video.
Causes:
  - Bad encoding of source file
  - HLS segment timing issues

Fix (App):
  - Add manual A/V sync adjustment in player settings
  - Range: -5s to +5s

Fix (Content):
  - Re-encode offending files with FFmpeg
  - ffmpeg -i input.mp4 -itsoffset 0.5 -c copy output.mp4
```

### Issue 4: Subtitle Not Synced
```
Problem: Subtitles appear too early/late.
Causes:
  - SRT timestamps don't match video version

Fix (App):
  - Subtitle delay control (+/- buttons, range: -10s to +10s)
  
Fix (Backend):
  - Find correct subtitle version matching video runtime
```

### Issue 5: 403 Forbidden on CDN
```
Problem: CDN returns 403, video won't play.
Causes:
  - Signed URL expired
  - Device fingerprint mismatch
  - IP blocked by CDN

Fix:
  - Re-fetch stream URL from API
  - If still 403 → CDN IP ban → try different server
  - Backend: rotate CDN tokens more frequently
```

---

## ⬇️ Download Issues

### Issue 6: Download Stuck / Not Completing
```
Problem: Download shows 95% but never finishes.
Causes:
  - Last few segments failing to download
  - Merge process failing

Fix:
  - Retry failed segments (up to 3 times each)
  - If merge fails → delete and retry full download
  - Add timeout: if no progress for 60s → pause+resume
```

### Issue 7: Downloaded File Won't Play
```
Problem: Download shows complete but won't open.
Causes:
  - Corrupt merge (segments out of order)
  - Partial download (truncated file)
  - Codec not supported

Fix:
  - Verify file integrity: check file size > expected
  - Re-run FFmpeg merge
  - For codec issues: re-encode with ExoPlayer-compatible settings
```

### Issue 8: Storage Full During Download
```
Problem: Download starts but device runs out of space.

Fix:
  - Check available storage before starting download
  - Minimum free space required: file_size + 10%
  - During download: check every minute
  - If space runs out: pause download, alert user
  
User Message: "Only 2GB free. This download needs 3.5GB. Free up space first."
```

---

## 🔐 Authentication Issues

### Issue 9: "Session Expired" Keeps Showing
```
Problem: User keeps getting logged out.
Causes:
  - Refresh token rotation too frequent
  - Clock skew between client and server
  - Multiple device conflicts

Fix:
  - Implement silent token refresh (before expiry)
  - Use sliding window expiry
  - Add 5-minute grace period for expired tokens
```

### Issue 10: Can't Log In (Correct Credentials)
```
Problem: User enters correct email/password but gets error.
Causes:
  - Account suspended
  - Email not verified
  - Database query error
  - Rate limit hit

Debug Steps:
  1. Check error code in response
  2. AUTH_ACCOUNT_SUSPENDED → user banned, check reason
  3. AUTH_EMAIL_NOT_VERIFIED → resend verification email
  4. RATE_LIMIT_EXCEEDED → wait 1 minute, try again
  5. DATABASE_ERROR → server issue, check logs
```

---

## 📱 App Performance Issues

### Issue 11: App Slow / Laggy on Home Screen
```
Problem: Home screen takes too long to load, scrolling is janky.
Causes:
  - Too many API calls on startup
  - Images not cached
  - Main thread blocked

Fix:
  - Cache home feed for 5 minutes
  - Use CachedNetworkImage everywhere
  - Paginate lists (don't load 1000 items at once)
  - Profile with Flutter DevTools
```

### Issue 12: High Memory Usage / App Crash
```
Problem: App crashes after long use, especially in player.
Causes:
  - Video player not properly disposed
  - Image cache too large
  - Memory leak in controller

Fix:
  - Dispose video controller on page exit
  - Limit image cache: maxCacheSize: 200MB
  - Use Flutter memory profiler to find leaks
  
Code:
  @override
  void dispose() {
    _videoController?.dispose();  // MUST dispose!
    super.dispose();
  }
```

---

## 🌐 Backend Issues

### Issue 13: API Server Down
```
Problem: All users can't load content.
Causes:
  - Server OOM (out of memory)
  - Deployment went wrong
  - Database connection pool exhausted
  - nginx crashed

Fix Steps:
  1. Check UptimeRobot alert
  2. SSH into server
  3. Check: pm2 status (Node.js processes)
  4. Check: systemctl status nginx
  5. Check: free -h (memory)
  6. Check: df -h (disk)
  7. Restart: pm2 restart all
  8. If OOM: kill heavy process, increase swap
  9. If disk full: clear logs, old files
  10. Post status update to users
```

### Issue 14: Database Connection Errors
```
Problem: API returns 500 errors, logs show DB connection failed.
Causes:
  - PostgreSQL max_connections hit
  - MongoDB replica set election
  - Redis memory limit

Fix:
  PostgreSQL:
    - Increase max_connections in postgresql.conf
    - Add PgBouncer connection pooler
    
  MongoDB:
    - Check replica set status: rs.status()
    - If election in progress → wait 30-60 seconds
    
  Redis:
    - Increase maxmemory in redis.conf
    - Set eviction policy: allkeys-lru
```

### Issue 15: CDN High Costs
```
Problem: Monthly CDN bill is too high.

Analyze:
  - Which content is most bandwidth-heavy?
  - Are there hotlinking attacks?
  - Is cache hit rate low?

Fix:
  - Block hotlinking: check Referer header
  - Increase cache TTL for .ts segments
  - Compress static assets (gzip/brotli)
  - Limit max quality for free users
  - Add Cloudflare rate limiting per IP
```

---

## 🛡️ Security Issues

### Issue 16: Stream URL Being Scraped/Shared
```
Problem: Users are extracting CDN URLs and sharing them publicly.

Detection:
  - Single URL being accessed from 100+ different IPs
  - CDN logs show unusual patterns

Fix:
  - Shorter URL expiry: 1 hour instead of 4
  - IP binding for signed URLs (optional — breaks VPN users)
  - Concurrent stream limit: 2 per account
  - Rotate CDN signing keys if compromised
```

### Issue 17: API Being Abused (Scraping)
```
Problem: Bot is hammering your API, increasing costs.

Fix:
  - Implement CAPTCHA for suspicious traffic (hCaptcha)
  - Block datacenter IP ranges
  - Aggressive rate limiting: 60 req/min per IP
  - Require valid API key (rotate monthly)
  - Add Cloudflare Bot Management (paid)
```

