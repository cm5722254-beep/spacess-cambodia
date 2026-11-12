const { spawn } = require('child_process');
const path = require('path');
const http = require('http');
const fs = require('fs');
const zlib = require('zlib');

console.log('=== STARTING SPACES SOCIAL MEDIA CAMBODIA SERVICES ===');

// 0. Ensure Local Ollama AI Service is running with models on D:\ollama-models
http.get('http://127.0.0.1:11434/api/tags', (res) => {
  console.log('[Ollama] Local AI service is active on port 11434.');
}).on('error', () => {
  console.log('[Ollama] Starting local Ollama service (D:\\ollama-models)...');
  try {
    const ollama = spawn('ollama', ['serve'], {
      env: { ...process.env, OLLAMA_MODELS: 'D:\\ollama-models' },
      detached: true,
      stdio: 'ignore',
    });
    ollama.unref();
  } catch (e) {
    console.warn('[Ollama] Could not auto-start ollama:', e.message);
  }
});

// 1. Start Backend NestJS Server
const backend = spawn('node', ['dist/main.js'], {
  cwd: path.join(__dirname, 'apps', 'backend'),
  stdio: 'inherit',
});

backend.on('error', (err) => {
  console.error('Backend process error:', err);
});

backend.on('exit', (code) => {
  console.log(`Backend process exited with code ${code}`);
});

// 2. Start Unified Mobile Web Server & API Proxy on Port 8080
const WEB_DIR = path.join(__dirname, 'apps', 'mobile', 'build', 'web');
const UPLOADS_DIR = path.join(__dirname, 'apps', 'backend', 'uploads');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.webm': 'video/webm',
  '.m4a': 'audio/mp4',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.wav': 'audio/wav',
  '.aac': 'audio/aac',
  '.woff': 'application/font-woff',
  '.woff2': 'font/woff2',
  '.ttf': 'application/font-ttf',
  '.wasm': 'application/wasm',
};

const server = http.createServer((req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept, Accept-Language, Range');
  res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Reverse Proxy for API endpoints: Forward /api/* to Backend on Port 3000
  if (req.url.startsWith('/api/') || req.url.startsWith('/api')) {
    const isSse = req.url.includes('/events/stream');
    if (isSse) {
      req.setTimeout(0);
      res.setTimeout(0);
      res.setHeader('X-Accel-Buffering', 'no');
    }
    const proxyReq = http.request(
      {
        host: 'localhost',
        port: 3000,
        path: req.url,
        method: req.method,
        headers: {
          ...req.headers,
          host: 'localhost:3000',
        },
      },
      (proxyRes) => {
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(res, { end: true });
      }
    );
    if (isSse) {
      proxyReq.setTimeout(0);
    }

    proxyReq.on('error', (err) => {
      console.error('API Proxy error:', err.message);
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, message: 'Backend unreachable' }));
    });

    req.pipe(proxyReq, { end: true });
    return;
  }

  // Serve User Uploaded Static Files (/uploads/*)
  if (req.url.startsWith('/uploads/') || req.url === '/uploads') {
    const cleanUrl = req.url.split('?')[0];
    const relFile = cleanUrl.replace(/^\/uploads\/?/, '');
    const uploadPath = path.join(UPLOADS_DIR, relFile);

    fs.stat(uploadPath, (err, stats) => {
      if (err || !stats.isFile()) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, message: 'Upload not found' }));
        return;
      }

      const ext = path.extname(uploadPath).toLowerCase();
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';
      res.setHeader('Content-Type', contentType);
      res.setHeader('Cache-Control', 'public, max-age=86400');
      fs.createReadStream(uploadPath).pipe(res);
    });
    return;
  }

  // Serve Static Flutter Web Files with Gzip compression and aggressive caching
  let reqPath = req.url.split('?')[0];
  if (reqPath === '/') reqPath = '/index.html';
  if (reqPath === '/admin' || reqPath === '/admin/') reqPath = '/admin.html';

  let filePath = path.join(WEB_DIR, reqPath);

  fs.stat(filePath, (err, stats) => {
    let isFallback = false;
    if (err || !stats.isFile()) {
      filePath = path.join(WEB_DIR, 'index.html');
      isFallback = true;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    const acceptEncoding = req.headers['accept-encoding'] || '';

    // Cache-Control: aggressive cache for hashed assets; no-cache for HTML, SW, and bootstrap
    const baseName = path.basename(filePath);
    if (ext === '.html' || isFallback || baseName === 'firebase-messaging-sw.js' || baseName === 'flutter_service_worker.js' || baseName === 'flutter_bootstrap.js' || baseName === 'version.json') {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else {
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    }

    res.setHeader('Content-Type', contentType);

    const rawStream = fs.createReadStream(filePath);

    // Compress text/js/json/wasm if client supports gzip
    const shouldCompress = ['.js', '.html', '.css', '.json', '.wasm', '.svg'].includes(ext);
    if (shouldCompress && acceptEncoding.includes('gzip')) {
      res.setHeader('Content-Encoding', 'gzip');
      rawStream.pipe(zlib.createGzip()).pipe(res);
    } else if (shouldCompress && acceptEncoding.includes('deflate')) {
      res.setHeader('Content-Encoding', 'deflate');
      rawStream.pipe(zlib.createDeflate()).pipe(res);
    } else {
      rawStream.pipe(res);
    }
  });
});

server.listen(8080, () => {
  console.log('Spaces Unified Gateway running at: http://localhost:8080');
});
