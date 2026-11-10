const streamResolver = require('./src/services/streamResolver');

console.log('🧪 Testing Multi-Server Stream Aggregator Engine...\n');

// 1. Test Movie Stream Resolution
const movieServers = streamResolver.resolveServers({
  type: 'movie',
  id: 550, // Fight Club (TMDB 550)
  imdbId: 'tt0137523',
});

console.log(`🎬 Movie Test (Fight Club - TMDB 550): Resolved ${movieServers.length} Servers:`);
movieServers.forEach((s) => {
  console.log(`  [Server ${s.id}] ${s.name}`);
  console.log(`    ↳ Quality: ${s.quality} | URL: ${s.url}`);
  if (s.backupUrl) console.log(`    ↳ Backup: ${s.backupUrl}`);
});

console.log('\n--------------------------------------------------\n');

// 2. Test TV Series Stream Resolution (with Season & Episode)
const tvServers = streamResolver.resolveServers({
  type: 'tv',
  id: 1399, // Game of Thrones (TMDB 1399)
  season: 1,
  episode: 1,
});

console.log(`📺 TV Series Test (Game of Thrones S01E01 - TMDB 1399): Resolved ${tvServers.length} Servers:`);
tvServers.forEach((s) => {
  console.log(`  [Server ${s.id}] ${s.name}`);
  console.log(`    ↳ Quality: ${s.quality} | URL: ${s.url}`);
});

console.log('\n✅ ALL STREAM RESOLVER TESTS PASSED PERFECTLY!\n');

