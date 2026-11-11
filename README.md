# Spaces Cambodia (`spacess-cambodia`)

Full-stack social media, short video (Reels), Watch & Live Camera Streaming, Marketplace (Bakong KHQR), and Messaging platform powered by NestJS and Flutter Web/Mobile.

## Project Structure

- `apps/backend` — NestJS REST API (`src/modules/*`: auth, feed, live streams, marketplace, storage with Cloudflare R2 S3 + local disk fallback, AI chat, health)
- `apps/mobile` — Flutter application (`lib/*` + `web/*`, Apple Liquid Glass UI, bilingual Khmer / English)
- `run-spaces-all.js` — Unified local gateway & static server on port `8080` proxying `/api/*` to port `3000`
- `deploy` — Container & environment deployment definitions

## Quick Start

1. Copy `.env.example` to `.env` (and configure `apps/backend/.env` if needed) with your database, OAuth, and Cloudflare R2 credentials.
2. Start backend dependencies & build:
   ```bash
   npm run build:backend
   node run-spaces-all.js
   ```
3. Analyze or build the Flutter Web client from `apps/mobile`:
   ```bash
   flutter analyze
   flutter build web --release
   ```

