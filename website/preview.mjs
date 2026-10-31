import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), 'dist');
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml' };
const port = Number(process.env.PORT || 4173);
const basePath = process.env.BASE_PATH || '/';
http.createServer(async (req, res) => {
  try {
    const requested = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (!requested.startsWith(basePath)) throw new Error('Not found');
    const pathname = '/' + requested.slice(basePath.length);
    const file = path.resolve(root, '.' + pathname + (pathname.endsWith('/') ? 'index.html' : ''));
    if (!file.startsWith(root + path.sep) || !(await stat(file)).isFile()) throw new Error('Not found');
    res.setHeader('Content-Type', `${types[path.extname(file)] || 'application/octet-stream'}; charset=utf-8`);
    res.end(await readFile(file));
  } catch { res.writeHead(404); res.end('Not found'); }
}).listen(port, '127.0.0.1', () => console.log(`Local: http://127.0.0.1:${port}${basePath}`));
