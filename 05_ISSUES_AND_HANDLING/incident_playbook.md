# 🚒 Incident Response Playbook — StreamMax

## Overview
Jab koi bada issue aye — kya karna hai, kaise handle karna hai.

---

## 🚨 Incident Severity Levels

| Level | Name | Description | Response Time |
|-------|------|-------------|--------------|
| P0 | Critical | App completely down, all users affected | 15 minutes |
| P1 | High | Major feature broken (streaming, auth) | 1 hour |
| P2 | Medium | Feature degraded but working | 4 hours |
| P3 | Low | Minor bug, few users affected | 24 hours |
| P4 | Info | Performance degradation, monitoring | 48 hours |

---

## 🔥 P0: Full Outage Playbook

### Detection
```
How we know:
1. UptimeRobot sends SMS/Telegram: "API DOWN"
2. Users flooding Telegram support group
3. Grafana dashboard goes red
```

### Immediate Actions (First 15 minutes)
```
Step 1: Acknowledge
  - Post in team Telegram: "🚨 P0 Incident declared — [Your name] is lead"
  - Start incident timer

Step 2: Assess
  - Check UptimeRobot: Which endpoints are down?
  - SSH into API server: ssh deploy@server-ip
  - Check process: pm2 status
  - Check resources: free -h && df -h && htop

Step 3: Quick Diagnosis
  Scenario A — Process crashed:
    pm2 restart all
    → If recovers: monitor for 5 min → declare resolved
    
  Scenario B — Server OOM (out of memory):
    kill -9 $(ps aux | sort -k4 -rn | head -1 | awk '{print $2}')
    pm2 restart all
    
  Scenario C — Disk full:
    du -sh /var/log/* | sort -rh | head -20
    journalctl --vacuum-time=1d
    pm2 flush
    
  Scenario D — Database down:
    systemctl status postgresql
    systemctl restart postgresql
    # Check logs: journalctl -u postgresql -n 100
    
  Scenario E — nginx down:
    systemctl status nginx
    nginx -t  (test config)
    systemctl restart nginx

Step 4: Post Status Update
  → Telegram support group: "⚠️ We're aware of the outage. Working on fix."
  → Status page: set to "Investigating"

Step 5: Resolve
  → Confirm APIs responding: curl https://api.streammax.app/health
  → Monitor for 10 minutes
  → Post: "✅ Issue resolved at [time]. Cause: [brief description]"
  → Status page: set to "Operational"

Step 6: Post-mortem (within 24h)
  Write incident report (see template below)
```

---

## 🎬 P1: Streaming Down Playbook

```
Symptoms: API working but videos won't play for most users

Steps:
1. Check CDN status: https://www.cloudflarestatus.com
2. Test stream URL directly: curl -I {sample_m3u8_url}
3. Check if specific server or all servers affected

If CDN issue:
  - Check BunnyCDN dashboard
  - If CDN down → nothing you can do, wait
  - Post: "CDN issue affecting video playback. Working with CDN provider."

If all servers returning 404/403:
  - Domain/IP may have changed
  - Content manager manually check and update URLs
  - Temporarily feature "working" content only

If signing key issue:
  - Rotate CDN signing key: update CDN_SIGNING_SECRET env var
  - Restart API: pm2 restart api
  - Monitor: test 5 different stream URLs
```

---

## 🔐 P1: Auth System Down Playbook

```
Symptoms: Users can't log in / getting 401 everywhere

Steps:
1. Test: POST /auth/login with test account
2. Check Redis: redis-cli ping (must return PONG)
3. Check JWT secret: verify JWT_SECRET env var is set
4. Check token validation middleware

If Redis down:
  systemctl restart redis
  # Sessions will be cleared — users need to re-login

If JWT issue:
  - New deployment may have changed JWT_SECRET
  - Ensure env vars are consistent across all API instances
  
Recovery:
  - All active sessions invalidated if Redis cleared
  - Users will need to log in again
  - Post notice: "Brief login issues resolved. Please log in again."
```

---

## 💾 P1: Database Down Playbook

```
Symptoms: API returning 500, logs showing DB connection errors

PostgreSQL:
  systemctl status postgresql
  systemctl restart postgresql
  
  If not starting, check logs:
  journalctl -u postgresql -n 50
  
  Common issues:
  - Disk full → clear space → restart
  - Corrupt data → restore from backup
  - Config error → revert to working config

MongoDB:
  systemctl status mongod
  systemctl restart mongod
  
  Check replica set:
  mongo --eval "rs.status()"
  
  If election in progress → wait 60 seconds

Restoration priority:
  1. Get read-only mode working (use replica)
  2. Full write access restored
  3. Verify data integrity
```

---

## 📊 Incident Report Template

```markdown
# Incident Report: [Short Title]

**Date:** 2024-01-01
**Duration:** 45 minutes (14:30 - 15:15 UTC)
**Severity:** P0 / P1 / P2
**Impact:** ~5,000 users unable to stream content

## Timeline
- 14:30 — UptimeRobot alert triggered
- 14:35 — On-call engineer acknowledged
- 14:40 — Root cause identified: OOM kill on API server
- 14:50 — API server restarted, monitoring
- 15:15 — All services confirmed stable. Incident resolved.

## Root Cause
API server ran out of memory due to memory leak in video extraction service.
Node.js process grew to 7.2GB RAM on 8GB server.

## Impact
- 45 minutes of downtime
- Estimated ~5,000 users affected
- 0 data loss

## Resolution
1. Killed runaway Python extraction process
2. Restarted Node.js API (pm2 restart all)
3. Added memory limit to extraction service: 1GB max

## Action Items
- [ ] Add memory limit to all services (Docker memory constraints)
- [ ] Add memory usage alert at 80% (currently at 90%)
- [ ] Investigate extraction service memory leak
- [ ] Add automatic restart on OOM kill
- [ ] Upgrade server RAM from 8GB to 16GB (€20/month more)

## Lessons Learned
Memory monitoring alert threshold was too high (90%). 
Should have been alerted at 75% to have time to react.
```

---

## 🔔 Alert Channels

```
Telegram Bot Commands (send to @StreamMaxAlerts):
/status    → Current system status
/metrics   → Key metrics snapshot  
/restart   → Restart API (admin only)
/logs 50   → Last 50 error logs

Monitoring Alerts → Telegram group "StreamMax Alerts"
User Reports → Telegram group "StreamMax Support"
Team Communication → Telegram group "StreamMax Team"
```

---

## 📞 Emergency Contacts

```
On-Call Rotation:
  Week 1: Backend Dev 1 (Telegram: @dev1)
  Week 2: Backend Dev 2 (Telegram: @dev2)
  
Escalation:
  If on-call doesn't respond in 15 min → call Team Lead
  If Team Lead unavailable → all-hands notification
  
Hosting Provider Support:
  Hetzner: support.hetzner.com (24/7 chat)
  Cloudflare: dash.cloudflare.com/support
  BunnyCDN: support.bunny.net
```

---

## ✅ Post-Incident Checklist

```
Within 1 hour of resolution:
  [ ] Update status page to "Operational"
  [ ] Post resolution message in support group
  [ ] Notify team in Telegram

Within 24 hours:
  [ ] Write incident report
  [ ] Root cause documented
  [ ] Action items created in GitHub Issues
  [ ] Share report with team

Within 1 week:
  [ ] Action items prioritized
  [ ] Preventive measures implemented
  [ ] Runbook updated with new learnings
```

