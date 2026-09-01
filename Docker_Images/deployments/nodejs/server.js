const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 4001;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'up', runtime: 'nodejs', host: os.hostname() }));
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`<h1>Node.js deployment</h1><p>Container: ${os.hostname()}</p><p><a href="/health">/health</a></p>`);
});

server.listen(PORT, '0.0.0.0', () => console.log(`nodejs deployment on ${PORT}`));
