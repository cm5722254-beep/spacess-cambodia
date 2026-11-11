# REST & WebSocket API Specification

## 1. Global Conventions & Standards

- **Base URL**: `/api/v1`
- **Content Type**: `application/json` (except multipart media uploads or presigned direct-to-S3 uploads).
- **Authentication**: Bearer JWT in the HTTP `Authorization` header:
  ```http
  Authorization: Bearer <access_token>
  ```
- **Language / Localization Negotiation**: Client supplies `Accept-Language: km` or `Accept-Language: en`.

### 1.1 Standard Response Envelopes

#### Success Envelope
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 120,
    "totalPages": 6,
    "hasNextPage": true
  }
}
```

#### Error Envelope
```json
{
  "success": false,
  "error": {
    "code": "AUTH_INVALID_CREDENTIALS",
    "message": "The email or password entered is incorrect.",
    "localizedMessage": "អ៊ីមែល ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវទេ។",
    "details": [
      {
        "field": "password",
        "issue": "Must be at least 8 characters long."
      }
    ],
    "timestamp": "2026-11-09T06:15:00.000Z"
  }
}
```

---

## 2. Authentication & Account Management (`/api/v1/auth`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `POST` | `/auth/register` | Register new user account | Public |
| `POST` | `/auth/login` | Login with username/email & password | Public |
| `POST` | `/auth/refresh` | Rotate access & refresh tokens | Public (Refresh Token) |
| `POST` | `/auth/logout` | Revoke current refresh token session | Authenticated |
| `POST` | `/auth/logout-all` | Revoke all sessions across all devices | Authenticated |
| `GET` | `/auth/sessions` | List all active device sessions | Authenticated |

---

## 3. Users, Profiles & Settings (`/api/v1/users`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `GET` | `/users/me` | Retrieve authenticated user profile & settings | Authenticated |
| `PATCH` | `/users/me` | Update profile (name, bio, avatarUrl, bannerUrl, language) | Authenticated |
| `PATCH` | `/users/me/settings` | Update preferences (`hideMetrics`, `focusModeEnabled`, `digestTime`, `quietHoursStart`, `quietHoursEnd`) | Authenticated |
| `GET` | `/users/:username` | View public profile of a user | Authenticated |
| `POST` | `/users/me/export` | Request complete GDPR data archive export | Authenticated |
| `DELETE` | `/users/me` | Request permanent account deletion & data purge | Authenticated |

---

## 4. Audience Circles (`/api/v1/circles`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `GET` | `/circles` | List all custom circles owned by user | Authenticated |
| `POST` | `/circles` | Create a new circle (e.g. "Close Friends") | Authenticated |
| `PATCH` | `/circles/:id` | Update circle metadata | Authenticated |
| `DELETE` | `/circles/:id` | Delete circle | Authenticated |
| `POST` | `/circles/:id/members` | Add members (`userIds: string[]`) | Authenticated |
| `DELETE` | `/circles/:id/members/:userId` | Remove member from circle | Authenticated |

---

## 5. Spaces & Workspaces (`/api/v1/spaces`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `GET` | `/spaces` | List all spaces user belongs to | Authenticated |
| `POST` | `/spaces` | Create a Space (mode checked against `INSTANCE_MODE`) | Authenticated |
| `GET` | `/spaces/:slug` | Retrieve space overview, members, and channels | Space Member / Public |
| `PATCH` | `/spaces/:id` | Update space settings | Space Admin/Owner |
| `DELETE` | `/spaces/:id` | Archive or delete space | Space Owner |
| `POST` | `/spaces/:id/invites` | Generate an invite code with role and max uses | Space Admin/Owner |
| `POST` | `/spaces/join/:inviteCode` | Join a space using an invite code | Authenticated |
| `GET` | `/spaces/:id/members` | List members and their assigned roles | Space Member |
| `PATCH` | `/spaces/:id/members/:userId`| Update member role (`ADMIN`, `MEMBER`, `CHILD`, etc.) | Space Admin/Owner |
| `DELETE` | `/spaces/:id/members/:userId`| Remove/kick member | Space Admin/Owner |

---

## 6. Channels & Realtime Messaging (`/api/v1/channels`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `GET` | `/spaces/:spaceId/channels` | List channels in a space | Space Member |
| `POST` | `/spaces/:spaceId/channels` | Create channel (text, announcement) | Space Admin |
| `GET` | `/channels/:id/messages` | Paginated message history (cursor-based) | Space Member |
| `POST` | `/channels/:id/messages` | Send message (REST fallback) | Space Member |
| `DELETE` | `/messages/:id` | Delete message | Sender / Moderator |

---

## 7. Posts & Feeds (`/api/v1/posts`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `POST` | `/posts` | Create post (`content`, `audience`, `spaceId`, `circleIds`, `expirationType`, `isTimeCapsule`, `unlockAt`, `media`) | Authenticated |
| `GET` | `/posts/:id` | Get post details (enforcing time-capsule & audience rules) | Authenticated |
| `DELETE` | `/posts/:id` | Soft-delete post | Author / Moderator |
| `GET` | `/feed/global` | Public discovery feed | Authenticated |
| `GET` | `/feed/following` | Feed of followed users | Authenticated |
| `GET` | `/feed/space/:spaceId`| Feed scoped to a specific space | Space Member |
| `GET` | `/feed/digest` | Calm Daily Digest for Focus Mode | Authenticated |
| `POST` | `/posts/:id/approve` | Parent approval for Child accounts in Family mode | Parent / Space Admin |

---

## 8. Reactions & Comments (`/api/v1/posts/:postId/...`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `POST` | `/posts/:id/reactions` | Toggle reaction (`LIKE`, `LOVE`, `CELEBRATE`, etc.) | Authenticated |
| `GET` | `/posts/:id/reactions` | Get reaction breakdown and users (if metrics allowed) | Authenticated |
| `GET` | `/posts/:id/comments` | Get nested comments (paginated) | Authenticated |
| `POST` | `/posts/:id/comments` | Add comment (or reply via `parentId`) | Authenticated |
| `DELETE` | `/comments/:id` | Delete comment | Author / Moderator |
| `POST` | `/comments/:id/reactions` | Toggle reaction on a comment | Authenticated |

---

## 9. Social Graph (`/api/v1/social`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `POST` | `/social/follow/:userId` | Follow a user (or request if private) | Authenticated |
| `DELETE` | `/social/follow/:userId` | Unfollow user | Authenticated |
| `GET` | `/social/:userId/followers` | List user's followers | Authenticated |
| `GET` | `/social/:userId/following` | List user's followings | Authenticated |

---

## 10. Media Uploads (`/api/v1/media`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `POST` | `/media/presigned-url` | Obtain presigned S3 upload URL with content-type lock | Authenticated |
| `POST` | `/media/confirm` | Confirm upload, trigger thumbnail generation & blurhash | Authenticated |

---

## 11. Productivity & Family/Team Tools (`/api/v1/spaces/:spaceId/...`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `GET` | `/spaces/:id/events` | List calendar events (with month/week filters) | Space Member |
| `POST` | `/spaces/:id/events` | Create calendar event | Space Member |
| `GET` | `/spaces/:id/tasks` | List tasks (filtered by assignee, status) | Space Member |
| `POST` | `/spaces/:id/tasks` | Create task assignment | Space Member |
| `PATCH` | `/tasks/:id` | Update task status (`TODO`, `IN_PROGRESS`, `DONE`) | Assignee / Creator |
| `GET` | `/spaces/:id/lists` | List shared lists (e.g. Grocery, Packing) | Space Member |
| `POST` | `/spaces/:id/lists` | Create shared list | Space Member |
| `POST` | `/lists/:id/items` | Add item to shared list | Space Member |
| `PATCH` | `/lists/items/:itemId` | Toggle item completion status | Space Member |
| `GET` | `/spaces/:id/albums` | List family/team media albums | Space Member |
| `POST` | `/spaces/:id/albums` | Create media album | Space Member |

---

## 12. Safety, Moderation & Reporting (`/api/v1/moderation`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `POST` | `/moderation/block/:userId` | Block a user | Authenticated |
| `DELETE` | `/moderation/block/:userId` | Unblock a user | Authenticated |
| `POST` | `/moderation/mute/:userId` | Mute a user's activities from feeds | Authenticated |
| `DELETE` | `/moderation/mute/:userId` | Unmute a user | Authenticated |
| `POST` | `/moderation/reports` | Submit abuse report against Post, Comment, or User | Authenticated |

---

## 13. Push Notifications & Devices (`/api/v1/notifications`)

| Method | Endpoint | Description | Access |
| :--- | :--- | :--- | :--- |
| `POST` | `/notifications/devices` | Register/Update FCM device token | Authenticated |
| `DELETE` | `/notifications/devices` | Unregister FCM token on logout | Authenticated |
| `GET` | `/notifications` | Paginated in-app notifications | Authenticated |
| `PATCH` | `/notifications/:id/read` | Mark single notification as read | Authenticated |
| `POST` | `/notifications/read-all` | Mark all notifications as read | Authenticated |

---

## 14. Realtime WebSocket Protocol (Socket.IO)

- **Gateway Namespace**: `/realtime`
- **Handshake Authentication**:
  ```javascript
  const socket = io('/realtime', {
    auth: { token: 'Bearer <access_token>' }
  });
  ```

### Client to Server Events

| Event Name | Payload | Description |
| :--- | :--- | :--- |
| `channel:join` | `{ "channelId": "uuid" }` | Subscribe to a specific space channel room |
| `channel:leave` | `{ "channelId": "uuid" }` | Unsubscribe from room |
| `message:send` | `{ "channelId": "uuid", "content": "text", "mediaId": "optional-uuid" }` | Transmit live message |
| `typing:start` | `{ "channelId": "uuid" }` | Broadcast user is typing |
| `typing:stop` | `{ "channelId": "uuid" }` | Broadcast user stopped typing |

### Server to Client Events

| Event Name | Payload | Description |
| :--- | :--- | :--- |
| `message:new` | Full `Message` DTO with sender profile | Broadcasted to channel subscribers |
| `typing:status` | `{ "channelId": "uuid", "userId": "uuid", "isTyping": true }` | Live typing indicator |
| `notification:new`| Full `Notification` DTO | Targeted emit to user's private socket room |
| `capsule:unlocked`| `{ "postId": "uuid", "title": "..." }` | Fired when time capsule arrives at unlock date |

