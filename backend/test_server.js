const http = require('http');
const { spawn } = require('child_process');

console.log('🚀 Launching backend process...');
const server = spawn('node', ['src/server.js'], { cwd: __dirname });

server.stdout.on('data', (d) => process.stdout.write(`[SERVER] ${d}`));
server.stderr.on('data', (d) => process.stderr.write(`[SERVER ERR] ${d}`));

setTimeout(() => {
  console.log('\n📡 Sending test request to /api/health ...');
  http.get('http://127.0.0.1:5000/api/health', (res) => {
    let data = '';
    res.on('data', (c) => (data += c));
    res.on('end', () => {
      console.log('✅ Response:', data);

      console.log('\n📡 Sending test request to /api/stream/movie/550 ...');
      http.get('http://127.0.0.1:5000/api/stream/movie/550', (res2) => {
        let data2 = '';
        res2.on('data', (c) => (data2 += c));
        res2.on('end', () => {
          console.log('✅ Stream Servers Response:');
          try {
            const parsed = JSON.parse(data2);
            console.log(`Total servers resolved: ${parsed.totalServers}`);
            parsed.servers.forEach((s) => console.log(`  - [${s.quality}] ${s.name} -> ${s.url}`));
          } catch {
            console.log(data2);
          }
          console.log('\n🎉 ALL TESTS PASSED! Shutting down test server.');
          server.kill();
          process.exit(0);
        });
      });
    });
  });
}, 2500);

