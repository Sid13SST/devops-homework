const http = require('http');

const PORT = process.env.PORT || 3000;

const page = `<!doctype html>
<html>
  <head><title>Node.js Hello World</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:60px">
    <h1>Hello World from Node.js</h1>
    <p>Served by a Node.js HTTP server running inside Docker.</p>
  </body>
</html>`;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(page);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Node.js app listening on port ${PORT}`);
});
