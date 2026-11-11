# Technical Specification: Spaces Social Platform

## 1. System Overview & Vision
Spaces is a self-hostable, privacy-first social media and community platform designed around dedicated workspaces called **Spaces**. Unlike conventional single-feed platforms (such as Facebook or Instagram), Spaces isolates interactions and workflows according to context:
- **Family Space**: Intimate family hub featuring private media albums, shared calendars, shared lists, time capsule messages, and parental oversight controls.
- **Team Space**: Lightweight productivity hub featuring topic channels, announcements, task assignments, polls, file repositories, and quiet hours.
- **Public Space**: Open social hub featuring discovery feeds, hashtags, following mechanics, and searchable public profiles.

The backend is built with **NestJS (Node.js + TypeScript)**, backed by **PostgreSQL** (relational data via Prisma ORM) and **Redis** (caching, queues, rate limiting). Real-time communication is powered by **Socket.IO (WebSocket Gateway)**, and binary media is stored in **S3-compatible storage** (MinIO for local development / self-hosting, Cloudflare R2 / AWS S3 for production). The client is built with **Flutter (Dart)** with an iOS/Cupertino-first design aesthetic, supporting both Khmer and English natively.

---

## 2. Instance Modes (`INSTANCE_MODE`)
A single codebase and deployment container supports multiple operational profiles controlled via environment variable `INSTANCE_MODE`:

| Mode | Allowed Space Types | Default Space Behavior | Target Use Case |
| :--- | :--- | :--- | :--- |
| `family` | `FAMILY` only | Single or multi-family private instance; public registration can be restricted or invite-only. | Private household or extended family server. |
| `team` | `TEAM` only | Organizations, workspaces, team collaboration; channels and productivity tools enabled. | Small business, open source team, company internal network. |
| `public` | `PUBLIC` only | Open public social network; global feed, discovery, hashtags, follow system. | Community social network, niche public community. |
| `mixed` | `FAMILY`, `TEAM`, `PUBLIC` | Users can create and participate in any space mode based on permissions. | Full-featured decentralized community hub. |

---

## 3. Core & Differentiating Architectural Features

### 3.1 Per-Post Audience "Circles"
- Rather than a coarse "Public vs. Friends" binary setting, posts can target custom user-defined **Circles** (e.g., "Close Friends", "Colleagues", "Extended Relatives", or specific Space members).
- Audience resolution evaluates:
  1. Space visibility (Public vs. Private Space).
  2. Post target audience: `PUBLIC`, `SPACE_MEMBERS`, or `CIRCLE_RESTRICTED` (backed by a join table of target circle IDs).

### 3.2 Privacy & Focus Mode
- **Hidden Metrics**: Per-user toggle `hideMetrics: boolean`. When enabled, like counts, view counts, and follower counts are not rendered on the client or returned in sanitized DTOs.
- **Focus Mode & Calm Digest**: Instead of infinite scroll feeds designed for dopamine loops, users in Focus Mode receive a aggregated **Daily Digest** with a capped item quota, suppressing algorithmic feeds and unread badge alerts.
- **Expiring Posts**: Posts can define an expiration timeframe (`NEVER`, `24_HOURS`, `7_DAYS`). A scheduled background job (via BullMQ + Redis) soft-deletes or archives expired posts automatically.
- **Time Capsule Posts**: Posts can be published with an `unlockAt: DateTime` timestamp in the future. Prior to the unlock timestamp, the post title/metadata is locked or blurred; content and media decryption/payload are only served after `unlockAt <= NOW()`.
- **Data Sovereignty & GDPR-compliant Erasure**:
  - Full archive export: Generates a JSON + zipped media archive via background queue.
  - Complete account deletion: Cascading purge of user records, active sessions, and media objects from S3 storage.

### 3.3 Localization (i18n)
- First-class support for **Khmer (km-KH)** and **English (en-US)**.
- Mobile client loads localized key-value JSON bundles (`km.json`, `en.json`) with zero hardcoded UI strings.
- Backend error responses return structured error codes (e.g., `AUTH_INVALID_CREDENTIALS`) paired with default messages, allowing mobile apps to render localized messages seamlessly.
- Typography natively supports `Noto Sans Khmer` paired with standard iOS system fonts (`SF Pro`).

---

## 4. Security & Compliance Principles
- **Authentication**: JWT Access Token (short-lived, 15 minutes) + Refresh Token (long-lived, 30 days) with token family rotation and revocation tracking stored in Redis/DB.
- **Password Hashing**: Argon2id with recommended memory and iteration cost parameters.
- **Authorization**: Role-Based Access Control (RBAC) per Space (`OWNER`, `ADMIN`, `MODERATOR`, `MEMBER`, `GUEST`, `CHILD`).
- **Child-Safe Protection**: In `FAMILY` spaces, accounts marked with role `CHILD` have restricted outbound chat, disabled public discovery, and content approval queues managed by parental accounts (`OWNER`/`ADMIN`).
- **Abuse Prevention**:
  - Redis-based sliding window rate limiter on auth routes, post creation, and media uploads.
  - User-level Block, Report, and Mute tables with automated moderation triggers.
  - S3 Presigned URLs with strictly verified MIME type, magic bytes, and file size quotas.

