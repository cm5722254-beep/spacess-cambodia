# Spaces Monorepo & Project Structure

The project is structured as a monorepo containing the NestJS backend, Flutter mobile client, infrastructure provisioning, and shared contracts.

```text
spaces-platform/
├── .github/
│   └── workflows/
│       ├── backend-ci.yml             # Lint, unit test, build backend
│       └── mobile-ci.yml              # Analyze, test, build Android APK
├── apps/
│   ├── backend/                       # NestJS Application
│   │   ├── prisma/
│   │   │   ├── schema.prisma          # Database schema definition
│   │   │   ├── migrations/            # Version-controlled SQL migrations
│   │   │   └── seed.ts                # Database seeding script
│   │   ├── src/
│   │   │   ├── common/                # Shared decorators, filters, interceptors, guards
│   │   │   │   ├── decorators/        # CurrentUser, Roles, Public, SpaceRoles
│   │   │   │   ├── filters/           # GlobalExceptionFilter with i18n error mapping
│   │   │   │   ├── guards/            # JwtAuthGuard, RolesGuard, SpaceRoleGuard
│   │   │   │   ├── interceptors/      # TransformResponseInterceptor, LoggingInterceptor
│   │   │   │   ├── middleware/        # RequestIdMiddleware, RateLimiterMiddleware
│   │   │   │   └── utils/             # Crypto, hashing, pagination helpers
│   │   │   ├── config/                # Environment configuration schemas (Joi / Zod)
│   │   │   │   ├── app.config.ts
│   │   │   │   ├── database.config.ts
│   │   │   │   ├── redis.config.ts
│   │   │   │   └── storage.config.ts
│   │   │   ├── modules/               # Feature-based clean architecture modules
│   │   │   │   ├── auth/              # JWT, refresh rotation, login, register, password
│   │   │   │   ├── users/             # Profile management, settings, GDPR export
│   │   │   │   ├── circles/           # Audience circles management
│   │   │   │   ├── spaces/            # Space CRUD, members, invites, channels
│   │   │   │   ├── posts/             # Posts, feed algorithms, expiring, time capsules
│   │   │   │   ├── comments/          # Nested comments, replies
│   │   │   │   ├── reactions/         # Post & comment reactions
│   │   │   │   ├── follows/           # Social graph (follow/unfollow)
│   │   │   │   ├── media/             # S3 presigned URLs, thumbnail generator, sharp
│   │   │   │   ├── realtime/          # Socket.IO Gateway, chat messages, rooms
│   │   │   │   ├── productivity/      # Family & Team tools (calendar, tasks, lists, albums)
│   │   │   │   ├── notifications/     # FCM push dispatcher, in-app notification center
│   │   │   │   ├── moderation/        # Reports, block, mute, child approval queue
│   │   │   │   └── prisma/            # Global PrismaService & database lifecycle
│   │   │   ├── app.module.ts          # Root NestJS module
│   │   │   └── main.ts                # Application entrypoint & Swagger setup
│   │   ├── test/                      # E2E and integration tests
│   │   ├── .env.example
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── Dockerfile
│   │
│   └── mobile/                        # Flutter Application
│       ├── android/                   # Android native wrapper
│       ├── ios/                       # iOS native wrapper
│       ├── assets/
│       │   ├── fonts/                 # Noto Sans Khmer & SF Pro display fonts
│       │   ├── icons/                 # Cupertino vector icon sets
│       │   ├── i18n/                  # Localization bundles
│       │   │   ├── km.json            # Khmer translations
│       │   │   └── en.json            # English translations
│       │   └── images/                # App brand logos, illustrations
│       ├── lib/
│       │   ├── app.dart               # CupertinoApp entry widget with theme & router
│       │   ├── main.dart              # Main initialization (FCM, Riverpod, LocalStorage)
│       │   ├── core/
│       │   │   ├── constants/         # App constants, layout tokens, endpoints
│       │   │   ├── errors/            # Failure types & exception handling
│       │   │   ├── localization/      # i18n loader, AppLocalizations provider
│       │   │   ├── network/           # Dio client with interceptors (Auth token refresh)
│       │   │   ├── router/            # GoRouter configuration & route guards
│       │   │   ├── storage/           # SecureStorage & SharedPrefs wrappers
│       │   │   ├── theme/             # iOS Cupertino theme, translucent colors, haptics
│       │   │   └── websocket/         # Socket.IO client service & reconnection logic
│       │   ├── features/              # Feature-first application modules
│       │   │   ├── auth/              # Login, register, forgot password, auth providers
│       │   │   ├── spaces/            # Space switcher, space settings, invite sheet
│       │   │   ├── feed/              # Public feed, space feed, focus digest, post card
│       │   │   ├── post_composer/     # Post creation, circle picker, time capsule, media
│       │   │   ├── chat/              # Realtime messaging UI, channel list, bubbles
│       │   │   ├── productivity/      # Calendar views, task board, checklist, albums
│       │   │   ├── profile/           # User profile, edit profile, user posts
│       │   │   ├── settings/          # Hide metrics, focus mode toggle, language selector
│       │   │   └── notifications/     # In-app notification center & badge listener
│       │   └── shared/                # Shared iOS-style widgets
│       │       ├── buttons/           # CupertinoButton wrappers with haptics
│       │       ├── cards/             # Rounded blur frosted glass cards
│       │       ├── dialogs/           # iOS action sheets and modal popups
│       │       ├── inputs/            # CupertinoTextField wrappers
│       │       └── loaders/           # Shimmer skeleton loaders & pull-to-refresh
│       ├── pubspec.yaml
│       └── analysis_options.yaml
│
├── deploy/                            # Deployment & Infrastructure
│   ├── docker-compose.yml             # Local & VPS development setup
│   ├── docker-compose.prod.yml        # Production stack with Traefik/Caddy & SSL
│   ├── Caddyfile                      # Automatic TLS reverse proxy configuration
│   └── minio-init/                    # S3 bucket auto-creation initialization script
│
├── docs/                              # Project Documentation
│   └── architecture/
│       ├── spec.md                    # Core specifications and instance modes
│       ├── database-schema.prisma     # Complete PostgreSQL schema
│       ├── api-spec.md                # Complete REST & WebSocket contracts
│       └── folder-structure.md        # Monorepo directory map
│
├── .gitignore
├── README.md
└── package.json                       # Root workspace package.json (Turborepo/NPM Workspaces)
```

