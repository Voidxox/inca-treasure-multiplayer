import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize } from 'node:path';

const root = 'D:/Flutter/inca-treasure-flutter/build/web';
const types = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.css', 'text/css; charset=utf-8'],
  ['.png', 'image/png'],
  ['.jpg', 'image/jpeg'],
  ['.wasm', 'application/wasm'],
  ['.svg', 'image/svg+xml'],
]);

createServer((req, res) => {
  const url = new URL(req.url ?? '/', 'http://127.0.0.1:8088');
  const clean = normalize(decodeURIComponent(url.pathname)).replace(/^([/\\])+/, '');
  let file = join(root, clean || 'index.html');
  if (!file.startsWith(root.replaceAll('/', '\\')) && !file.startsWith(root)) {
    res.writeHead(403).end('Forbidden');
    return;
  }
  if (!existsSync(file) || statSync(file).isDirectory()) file = join(root, 'index.html');
  res.writeHead(200, { 'content-type': types.get(extname(file)) ?? 'application/octet-stream' });
  createReadStream(file).pipe(res);
}).listen(8088, '0.0.0.0', () => console.log('Flutter web listening on http://127.0.0.1:8088'));
