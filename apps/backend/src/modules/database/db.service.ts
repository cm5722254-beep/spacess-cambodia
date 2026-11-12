import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { getR2Config, getR2Object, putR2Object } from '../storage/r2-client.util';

export interface UserEntity {
  id: string;
  phone: string;
  name: string;
  username: string;
  passwordHash: string;
  email?: string;
  bio?: string;
  location?: string;
  avatar: string;
  bannerUrl?: string;
  storeName?: string;
  storePhone?: string;
  storeDescription?: string;
  storeBannerUrl?: string;
  storeThemeColor?: string;
  storeTagline?: string;
  bakongAccountId?: string;
  twoFactorEnabled?: boolean;
  subscriptionTier?: 'FREE' | 'PRO_PLUS' | 'ULTRA';
  subscriptionExpiresAt?: string;
  role: 'ADMIN' | 'USER';
  isVerified: boolean;
  isBanned: boolean;
  lastNameChangeAt?: string;
  fcmTokens?: string[];
  createdAt: string;
}

export interface PostEntity {
  id: string;
  authorId: string;
  content: string;
  spaceId: string;
  circleName?: string;
  city?: string;
  imageUrl?: string;
  videoUrl?: string;
  mediaType?: 'image' | 'video' | 'gif' | 'text';
  tags?: string[];
  templateStyle?: string;
  moodTag?: string;
  isBoosted?: boolean;
  isReel?: boolean;
  reelAudioTitle?: string;
  createdAt: string;
  updatedAt?: string;
}

export interface CommentEntity {
  id: string;
  postId: string;
  authorId: string;
  text: string;
  parentId?: string;
  replyToAuthor?: string;
  createdAt: string;
}

export interface ReactionEntity {
  id: string;
  postId: string;
  userId: string;
  reaction: string;
  createdAt: string;
}

export interface SavedPostEntity {
  id: string;
  userId: string;
  postId: string;
  createdAt: string;
}

export interface FollowEntity {
  id: string;
  followerId: string;
  followingId: string;
  createdAt: string;
}

export interface ProductEntity {
  id: string;
  title: string;
  priceUsd: number;
  priceKhr: number;
  category: string;
  condition: string;
  imageUrl: string;
  location: string;
  description: string;
  sellerId: string;
  sellerStoreName?: string;
  sellerPhone?: string;
  sellerBakongId?: string;
  sellerTier?: 'FREE' | 'PRO_PLUS' | 'ULTRA';
  createdAt: string;
}

export interface OrderEntity {
  id: string;
  billNumber: string;
  productId: string;
  productTitle: string;
  quantity?: number;
  unitPrice?: number;
  amount: number;
  currency: string;
  buyerId: string;
  buyerName?: string;
  buyerPhone?: string;
  shippingAddress?: string;
  buyerNote?: string;
  sellerId: string;
  sellerName?: string;
  sellerStoreName?: string;
  sellerBakongId: string;
  md5: string;
  qrString?: string;
  qrImage?: string;
  deeplink?: string;
  status: 'PENDING' | 'PAID' | 'FAILED';
  fulfillmentStatus?: 'PROCESSING' | 'CONFIRMED' | 'SHIPPING' | 'DELIVERED';
  trackingNote?: string;
  transactionData?: any;
  paidAt?: string;
  updatedAt?: string;
  createdAt: string;
}

export interface NotificationEntity {
  id: string;
  userId: string;
  actorId: string;
  actorName: string;
  actorAvatar: string;
  type: 'LIKE' | 'COMMENT' | 'FRIEND' | 'ORDER_PAID' | 'ORDER_UPDATE';
  title: string;
  body: string;
  refId?: string;
  isRead: boolean;
  createdAt: string;
}

export interface ReportEntity {
  id: string;
  reporterId: string;
  targetType: 'POST' | 'USER';
  targetId: string;
  reason: string;
  status: 'OPEN' | 'RESOLVED' | 'DISMISSED';
  createdAt: string;
  resolvedAt?: string;
}

export interface BlockEntity {
  blockerId: string;
  blockedId: string;
  createdAt: string;
}

export interface StoryEntity {
  id: string;
  authorId: string;
  authorName: string;
  authorAvatar: string;
  imageUrl: string;
  caption?: string;
  expiresAt?: string;
  createdAt: string;
}

export interface StreamEntity {
  id: string;
  authorId: string;
  authorName: string;
  authorAvatar: string;
  authorRole: string;
  authorIsVerified: boolean;
  title: string;
  description: string;
  videoUrl: string;
  thumbnailUrl?: string;
  category: string;
  duration: string;
  viewsCount: number;
  likesCount: number;
  commentsCount: number;
  isLive: boolean;
  viewerCount?: number;
  likedUserIds?: string[];
  liveChunkUrl?: string;
  liveChunkSeq?: number;
  liveChunks?: Array<{ seq: number; url: string; createdAt: string }>;
  liveEndedAt?: string;
  liveTheme?: string;
  pinnedNotice?: string;
  videoFilter?: string;
  createdAt: string;
}

export interface ChatEntity {
  id: string;
  participantIds: string[];
  lastMessage?: string;
  updatedAt: string;
}

export interface MessageEntity {
  id: string;
  chatId: string;
  senderId: string;
  text: string;
  mediaUrl?: string;
  mediaType?: 'text' | 'image' | 'video' | 'voice';
  durationSec?: number;
  createdAt: string;
}

export interface FriendRequestEntity {
  id: string;
  requesterId: string;
  receiverId: string;
  status: 'PENDING' | 'ACCEPTED';
  createdAt: string;
  updatedAt?: string;
}

export interface DatabaseState {
  users: UserEntity[];
  posts: PostEntity[];
  comments: CommentEntity[];
  reactions: ReactionEntity[];
  savedPosts: SavedPostEntity[];
  follows: FollowEntity[];
  friendRequests: FriendRequestEntity[];
  products: ProductEntity[];
  orders: OrderEntity[];
  stories: StoryEntity[];
  streams: StreamEntity[];
  chats: ChatEntity[];
  messages: MessageEntity[];
  reports?: ReportEntity[];
  blockedUsers?: BlockEntity[];
  notifications?: NotificationEntity[];
}

@Injectable()
export class DbService implements OnModuleInit, OnModuleDestroy {
  private readonly r2StateKey = 'db/spaces_db.json';
  private dbPath: string;
  private r2SyncTimer: NodeJS.Timeout | null = null;
  private r2SyncPending = false;
  private state: DatabaseState = {
    users: [],
    posts: [],
    comments: [],
    reactions: [],
    savedPosts: [],
    follows: [],
    friendRequests: [],
    products: [],
    orders: [],
    stories: [],
    streams: [],
    chats: [],
    messages: [],
    reports: [],
    blockedUsers: [],
    notifications: [],
  };

  async onModuleInit() {
    const dataDir = process.env.DATA_DIR
      ? path.resolve(process.env.DATA_DIR)
      : path.resolve(process.cwd(), 'data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    this.dbPath = path.join(dataDir, 'spaces_db.json');
    await this.load();
  }

  async onModuleDestroy() {
    if (this.r2SyncTimer) {
      clearTimeout(this.r2SyncTimer);
      this.r2SyncTimer = null;
      await this.pushStateToR2();
    } else if (this.r2SyncPending) {
      await this.pushStateToR2();
    }
  }

  private normalizeState(nextState: Partial<DatabaseState>): DatabaseState {
    return {
      users: Array.isArray(nextState.users) ? nextState.users : [],
      posts: Array.isArray(nextState.posts) ? nextState.posts : [],
      comments: Array.isArray(nextState.comments) ? nextState.comments : [],
      reactions: Array.isArray(nextState.reactions) ? nextState.reactions : [],
      savedPosts: Array.isArray(nextState.savedPosts) ? nextState.savedPosts : [],
      follows: Array.isArray(nextState.follows) ? nextState.follows : [],
      friendRequests: Array.isArray(nextState.friendRequests) ? nextState.friendRequests : [],
      products: Array.isArray(nextState.products) ? nextState.products : [],
      orders: Array.isArray(nextState.orders) ? nextState.orders : [],
      stories: Array.isArray(nextState.stories) ? nextState.stories : [],
      streams: Array.isArray(nextState.streams) ? nextState.streams : [],
      chats: Array.isArray(nextState.chats) ? nextState.chats : [],
      messages: Array.isArray(nextState.messages) ? nextState.messages : [],
      reports: Array.isArray(nextState.reports) ? nextState.reports : [],
      blockedUsers: Array.isArray(nextState.blockedUsers) ? nextState.blockedUsers : [],
      notifications: Array.isArray(nextState.notifications) ? nextState.notifications : [],
    };
  }

  importState(nextState: Partial<DatabaseState>) {
    this.state = this.normalizeState(nextState);
    this.save();
    return this.getStats();
  }

  private hashPassword(password: string): string {
    const salt = 'spaces_cambodia_salt_2026';
    return crypto.scryptSync(password, salt, 32).toString('hex');
  }

  private async load() {
    if (fs.existsSync(this.dbPath)) {
      try {
        const raw = fs.readFileSync(this.dbPath, 'utf8');
        this.state = this.normalizeState(JSON.parse(raw));
        console.log(`[DbService] Database loaded from ${this.dbPath} (Users: ${this.state.users.length}, Posts: ${this.state.posts.length})`);
        return;
      } catch (err) {
        console.error('[DbService] Error parsing database file, checking R2 backup:', err);
      }
    }

    if (getR2Config()) {
      try {
        const r2Res = await getR2Object(this.r2StateKey);
        if (r2Res && r2Res.ok) {
          const text = await r2Res.text();
          this.state = this.normalizeState(JSON.parse(text));
          this.save(false);
          console.log(`[DbService] Restored database from Cloudflare R2 (Users: ${this.state.users.length}, Posts: ${this.state.posts.length})`);
          return;
        }
      } catch (err) {
        console.warn('[DbService] Could not restore state from R2:', err);
      }
    }

    // Initialize clean database state with Default Admin and initial test user
    this.state = this.normalizeState({
      users: [
        {
          id: 'admin-1',
          phone: '012345678',
          name: 'CHAN SOCHEAT',
          username: 'admin',
          passwordHash: this.hashPassword('admin12345'),
          email: 'admin@spaces.cambodia.kh',
          bio: 'Administrator & Founder of Spaces Cambodia Platform',
          location: 'Phnom Penh, Cambodia',
          avatar: '/uploads/admin_avatar.jpg',
          storeName: 'CHAN SOCHEAT Official Store',
          storePhone: '012345678',
          storeDescription: 'Official Store of CHAN SOCHEAT',
          bakongAccountId: 'chansocheat_vin@bkrt',
          role: 'ADMIN',
          isVerified: true,
          isBanned: false,
          createdAt: new Date().toISOString(),
        },
      ],
    });
    this.save(false);
    console.log(`[DbService] Clean persistent database initialized at ${this.dbPath}`);
  }

  private async pushStateToR2() {
    if (!getR2Config()) return;
    this.r2SyncPending = true;
    try {
      const payload = Buffer.from(JSON.stringify(this.state), 'utf8');
      const res = await putR2Object(this.r2StateKey, payload, 'application/json');
      if (!res.ok) {
        console.warn(`[DbService] R2 backup returned ${res.status ?? 'error'}: ${(res.errorText || '').slice(0, 150)}`);
      }
    } catch (err) {
      console.warn('[DbService] Failed syncing DB state to R2:', err);
    } finally {
      this.r2SyncPending = false;
    }
  }

  private save(syncR2: boolean = true) {
    try {
      const tmpPath = `${this.dbPath}.tmp`;
      fs.writeFileSync(tmpPath, JSON.stringify(this.state, null, 2), 'utf8');
      fs.renameSync(tmpPath, this.dbPath);
    } catch (err) {
      console.error('[DbService] Error saving database to disk:', err);
    }

    if (syncR2 && getR2Config()) {
      this.r2SyncPending = true;
      if (this.r2SyncTimer) clearTimeout(this.r2SyncTimer);
      this.r2SyncTimer = setTimeout(() => {
        this.r2SyncTimer = null;
        void this.pushStateToR2();
      }, 600);
    }
  }

  // --- USER OPERATIONS ---
  createUser(dto: {
    phone: string;
    name: string;
    username: string;
    password: string;
    email?: string;
  }): UserEntity {
    const newUser: UserEntity = {
      id: `u-${Date.now()}`,
      phone: dto.phone,
      name: dto.name,
      username: dto.username.toLowerCase(),
      passwordHash: this.hashPassword(dto.password),
      email: dto.email,
      bio: 'សមាជិកថ្មីនៃ Spaces Cambodia',
      location: 'Phnom Penh, Cambodia',
      avatar: '/default_avatar.svg',
      role: 'USER',
      isVerified: false,
      isBanned: false,
      createdAt: new Date().toISOString(),
    };
    this.state.users.unshift(newUser);
    this.save();
    return newUser;
  }

  findUserByPhone(phone: string): UserEntity | undefined {
    return this.state.users.find((u) => u.phone === phone);
  }

  findUserByEmail(email?: string): UserEntity | undefined {
    if (!email) return undefined;
    return this.state.users.find((u) => u.email && u.email.toLowerCase() === email.toLowerCase());
  }

  findUserByUsername(username: string): UserEntity | undefined {
    return this.state.users.find((u) => u.username.toLowerCase() === username.toLowerCase());
  }

  findUserById(id: string): UserEntity | undefined {
    return this.state.users.find((u) => u.id === id);
  }

  updateUser(id: string, updates: Partial<UserEntity>): UserEntity | undefined {
    const user = this.findUserById(id);
    if (!user) return undefined;
    Object.assign(user, updates);
    this.save();
    return user;
  }

  getAllUsers(): Omit<UserEntity, 'passwordHash'>[] {
    return this.state.users.map(({ passwordHash, ...safe }) => safe);
  }

  toggleBanUser(userId: string): boolean {
    const user = this.findUserById(userId);
    if (user && user.role !== 'ADMIN') {
      user.isBanned = !user.isBanned;
      this.save();
      return user.isBanned;
    }
    return false;
  }

  deleteUser(userId: string): boolean {
    const user = this.findUserById(userId);
    if (!user || user.role === 'ADMIN') return false;

    // Remove user and all associated data
    this.state.users = this.state.users.filter((u) => u.id !== userId);
    this.clearUserContent(userId);
    this.state.follows = this.state.follows.filter((f) => f.followerId !== userId && f.followingId !== userId);
    this.state.friendRequests = (this.state.friendRequests || []).filter(
      (fr) => fr.requesterId !== userId && fr.receiverId !== userId,
    );
    this.state.products = this.state.products.filter((p) => p.sellerId !== userId);
    this.state.chats = this.state.chats.filter((c) => !c.participantIds.includes(userId));
    const remainingChatIds = new Set(this.state.chats.map((c) => c.id));
    this.state.messages = this.state.messages.filter((m) => remainingChatIds.has(m.chatId) && m.senderId !== userId);
    this.save();
    return true;
  }

  deleteUsersBatch(userIds: string[]): number {
    let deletedCount = 0;
    for (const id of userIds) {
      if (this.deleteUser(id)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  clearUserContent(userId: string): {
    postsRemoved: number;
    commentsRemoved: number;
    storiesRemoved: number;
    streamsRemoved: number;
  } {
    const userPostIds = new Set(this.state.posts.filter((p) => p.authorId === userId).map((p) => p.id));
    const postsBefore = this.state.posts.length;
    const commentsBefore = this.state.comments.length;
    const storiesBefore = this.state.stories.length;
    const streamsBefore = this.state.streams.length;

    this.state.posts = this.state.posts.filter((p) => p.authorId !== userId);
    this.state.comments = this.state.comments.filter((c) => c.authorId !== userId && !userPostIds.has(c.postId));
    this.state.reactions = this.state.reactions.filter((r) => r.userId !== userId && !userPostIds.has(r.postId));
    this.state.savedPosts = this.state.savedPosts.filter((s) => s.userId !== userId && !userPostIds.has(s.postId));
    this.state.stories = this.state.stories.filter((s) => s.authorId !== userId);
    this.state.streams = this.state.streams.filter((s) => s.authorId !== userId);

    this.save();

    return {
      postsRemoved: postsBefore - this.state.posts.length,
      commentsRemoved: commentsBefore - this.state.comments.length,
      storiesRemoved: storiesBefore - this.state.stories.length,
      streamsRemoved: streamsBefore - this.state.streams.length,
    };
  }

  saveUserFcmToken(userId: string, fcmToken: string): boolean {
    const user = this.findUserById(userId);
    if (!user || !fcmToken.trim()) return false;
    if (!user.fcmTokens) user.fcmTokens = [];
    if (!user.fcmTokens.includes(fcmToken.trim())) {
      user.fcmTokens.push(fcmToken.trim());
      this.save();
    }
    return true;
  }

  searchUsers(query: string, currentUserId?: string): any[] {
    const q = (query || '').trim().toLowerCase();
    const list = this.state.users.filter((u) => {
      if (u.isBanned) return false;
      if (currentUserId && u.id === currentUserId) return false;
      if (!q) return true;
      return (
        u.name.toLowerCase().includes(q) ||
        u.username.toLowerCase().includes(q) ||
        (u.phone && u.phone.includes(q))
      );
    });

    return list.map((u) => {
      const counts = this.getFollowCounts(u.id);
      const isFollowing = currentUserId ? this.isFollowing(currentUserId, u.id) : false;
      const friendRel = currentUserId ? this.getFriendRelation(currentUserId, u.id) : { status: 'NONE', requestId: null };
      return {
        id: u.id,
        name: u.name,
        username: u.username,
        avatar: u.avatar || '/default_avatar.svg',
        bio: u.bio || '',
        location: u.location || 'Cambodia',
        role: u.role,
        isVerified: u.isVerified,
        bakongAccountId: u.bakongAccountId || '',
        storeName: u.storeName || '',
        followerCount: counts.followersCount,
        followingCount: counts.followingCount,
        isFollowing,
        friendStatus: friendRel.status,
        friendRequestId: friendRel.requestId,
      };
    });
  }

  verifyPassword(user: UserEntity, pass: string): boolean {
    return user.passwordHash === this.hashPassword(pass);
  }

  changePassword(userId: string, oldPass: string, newPass: string): boolean {
    const user = this.findUserById(userId);
    if (!user || !this.verifyPassword(user, oldPass)) return false;
    user.passwordHash = this.hashPassword(newPass);
    this.save();
    return true;
  }

  updateBanner(userId: string, bannerUrl: string): UserEntity | undefined {
    const user = this.findUserById(userId);
    if (!user) return undefined;
    user.bannerUrl = bannerUrl.trim();
    this.save();
    return user;
  }

  toggleTwoFactor(userId: string): boolean {
    const user = this.findUserById(userId);
    if (!user) return false;
    user.twoFactorEnabled = !user.twoFactorEnabled;
    this.save();
    return user.twoFactorEnabled;
  }

  subscribeTier(userId: string, tier: 'PRO_PLUS' | 'ULTRA', months: number): UserEntity | undefined {
    const user = this.findUserById(userId);
    if (!user) return undefined;
    user.subscriptionTier = tier;
    user.isVerified = true;
    const expires = new Date();
    expires.setMonth(expires.getMonth() + months);
    user.subscriptionExpiresAt = expires.toISOString();
    this.save();
    return user;
  }

  // --- POST & REEL OPERATIONS ---
  createPost(dto: {
    authorId: string;
    content: string;
    spaceId: string;
    circleName?: string;
    city?: string;
    imageUrl?: string;
    videoUrl?: string;
    mediaType?: 'image' | 'video' | 'gif' | 'text';
    tags?: string[];
    templateStyle?: string;
    moodTag?: string;
    isBoosted?: boolean;
    isReel?: boolean;
    reelAudioTitle?: string;
  }): PostEntity {
    const author = this.findUserById(dto.authorId);
    const isBoosted = dto.isBoosted === true || author?.subscriptionTier === 'PRO_PLUS' || author?.subscriptionTier === 'ULTRA';
    const newPost: PostEntity = {
      id: `p-${Date.now()}`,
      authorId: dto.authorId,
      content: dto.content,
      spaceId: dto.spaceId || 'public',
      circleName: dto.circleName,
      city: dto.city || 'Phnom Penh',
      imageUrl: dto.imageUrl,
      videoUrl: dto.videoUrl,
      mediaType: dto.mediaType || (dto.videoUrl ? 'video' : dto.imageUrl ? 'image' : 'text'),
      tags: dto.tags || [],
      templateStyle: dto.templateStyle?.trim() || undefined,
      moodTag: dto.moodTag?.trim() || undefined,
      isBoosted,
      isReel: dto.isReel ?? (dto.mediaType === 'video' || !!dto.videoUrl),
      reelAudioTitle: dto.reelAudioTitle,
      createdAt: new Date().toISOString(),
    };
    this.state.posts.unshift(newPost);
    this.save();
    return newPost;
  }

  getReels(): PostEntity[] {
    return this.state.posts.filter((p) => p.isReel || p.mediaType === 'video' || !!p.videoUrl);
  }

  getPosts(filters?: {
    spaceId?: string;
    city?: string;
    authorId?: string;
    savedByUserId?: string;
    searchQuery?: string;
  }): PostEntity[] {
    let result = [...this.state.posts];

    if (filters?.spaceId && filters.spaceId !== 'all') {
      result = result.filter((p) => p.spaceId === filters.spaceId);
    }
    if (filters?.city && filters.city.trim()) {
      result = result.filter((p) => p.city?.toLowerCase() === filters.city!.toLowerCase());
    }
    if (filters?.authorId) {
      result = result.filter((p) => p.authorId === filters.authorId);
    }
    if (filters?.savedByUserId) {
      const savedIds = new Set(
        this.state.savedPosts
          .filter((s) => s.userId === filters.savedByUserId)
          .map((s) => s.postId),
      );
      result = result.filter((p) => savedIds.has(p.id));
    }
    if (filters?.searchQuery && filters.searchQuery.trim()) {
      const q = filters.searchQuery.toLowerCase().trim();
      result = result.filter(
        (p) =>
          p.content.toLowerCase().includes(q) ||
          p.city?.toLowerCase().includes(q) ||
          p.tags?.some((t) => t.toLowerCase().includes(q)),
      );
    }

    return result;
  }

  getPostById(id: string): PostEntity | undefined {
    return this.state.posts.find((p) => p.id === id);
  }

  updatePost(id: string, userId: string, updates: { content?: string; city?: string; imageUrl?: string }): PostEntity | undefined {
    const post = this.getPostById(id);
    if (!post) return undefined;
    if (post.authorId !== userId) {
      const user = this.findUserById(userId);
      if (user?.role !== 'ADMIN') return undefined;
    }
    if (updates.content) post.content = updates.content;
    if (updates.city) post.city = updates.city;
    if (updates.imageUrl !== undefined) post.imageUrl = updates.imageUrl;
    post.updatedAt = new Date().toISOString();
    this.save();
    return post;
  }

  deletePost(id: string, userId: string): boolean {
    const index = this.state.posts.findIndex((p) => p.id === id);
    if (index === -1) return false;
    const post = this.state.posts[index];
    const user = this.findUserById(userId);
    if (post.authorId !== userId && user?.role !== 'ADMIN') {
      return false;
    }
    this.state.posts.splice(index, 1);
    // Cleanup related comments, reactions, bookmarks
    this.state.comments = this.state.comments.filter((c) => c.postId !== id);
    this.state.reactions = this.state.reactions.filter((r) => r.postId !== id);
    this.state.savedPosts = this.state.savedPosts.filter((s) => s.postId !== id);
    this.save();
    return true;
  }

  // --- COMMENT OPERATIONS ---
  addComment(postId: string, authorId: string, text: string, parentId?: string): CommentEntity {
    let replyToAuthor: string | undefined;
    const cleanParentId = parentId?.trim() || undefined;
    if (cleanParentId) {
      const parentComment = this.state.comments.find((c) => c.id === cleanParentId && c.postId === postId);
      if (parentComment) {
        const parentAuthor = this.findUserById(parentComment.authorId);
        replyToAuthor = parentAuthor?.name || 'អ្នកប្រើប្រាស់';
      }
    }
    const newComment: CommentEntity = {
      id: `c-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      postId,
      authorId,
      text: text.trim(),
      parentId: cleanParentId,
      replyToAuthor,
      createdAt: new Date().toISOString(),
    };
    this.state.comments.push(newComment);
    this.save();
    return newComment;
  }

  getCommentsByPostId(postId: string): CommentEntity[] {
    return this.state.comments.filter((c) => c.postId === postId);
  }

  deleteComment(commentId: string, userId: string): boolean {
    const index = this.state.comments.findIndex((c) => c.id === commentId);
    if (index === -1) return false;
    const comment = this.state.comments[index];
    const user = this.findUserById(userId);
    if (comment.authorId !== userId && user?.role !== 'ADMIN') {
      return false;
    }
    this.state.comments.splice(index, 1);
    this.save();
    return true;
  }

  // --- REACTION OPERATIONS ---
  toggleReaction(postId: string, userId: string, reaction: string): { reacted: boolean; reactionCounts: Record<string, number>; userReaction?: string } {
    const existingIndex = this.state.reactions.findIndex(
      (r) => r.postId === postId && r.userId === userId,
    );

    if (existingIndex !== -1) {
      if (this.state.reactions[existingIndex].reaction === reaction) {
        // Toggle off
        this.state.reactions.splice(existingIndex, 1);
      } else {
        // Update reaction
        this.state.reactions[existingIndex].reaction = reaction;
      }
    } else {
      this.state.reactions.push({
        id: `r-${Date.now()}`,
        postId,
        userId,
        reaction,
        createdAt: new Date().toISOString(),
      });
    }

    this.save();

    const postReactions = this.state.reactions.filter((r) => r.postId === postId);
    const reactionCounts: Record<string, number> = {};
    for (const r of postReactions) {
      reactionCounts[r.reaction] = (reactionCounts[r.reaction] || 0) + 1;
    }
    const currentReaction = this.state.reactions.find((r) => r.postId === postId && r.userId === userId);

    return {
      reacted: !!currentReaction,
      reactionCounts,
      userReaction: currentReaction?.reaction,
    };
  }

  getReactionCounts(postId: string): Record<string, number> {
    const counts: Record<string, number> = {};
    for (const r of this.state.reactions.filter((r) => r.postId === postId)) {
      counts[r.reaction] = (counts[r.reaction] || 0) + 1;
    }
    return counts;
  }

  getUserReaction(postId: string, userId: string): string | undefined {
    return this.state.reactions.find((r) => r.postId === postId && r.userId === userId)?.reaction;
  }

  // --- BOOKMARK / SAVED POSTS ---
  toggleSavePost(postId: string, userId: string): boolean {
    const idx = this.state.savedPosts.findIndex(
      (s) => s.postId === postId && s.userId === userId,
    );
    if (idx !== -1) {
      this.state.savedPosts.splice(idx, 1);
      this.save();
      return false; // Removed
    } else {
      this.state.savedPosts.push({
        id: `sp-${Date.now()}`,
        userId,
        postId,
        createdAt: new Date().toISOString(),
      });
      this.save();
      return true; // Saved
    }
  }

  isPostSaved(postId: string, userId: string): boolean {
    return this.state.savedPosts.some((s) => s.postId === postId && s.userId === userId);
  }

  // --- FOLLOW OPERATIONS ---
  toggleFollow(followerId: string, followingId: string): boolean {
    if (followerId === followingId) return false;
    const idx = this.state.follows.findIndex(
      (f) => f.followerId === followerId && f.followingId === followingId,
    );
    if (idx !== -1) {
      this.state.follows.splice(idx, 1);
      this.save();
      return false; // Unfollowed
    } else {
      this.state.follows.push({
        id: `f-${Date.now()}`,
        followerId,
        followingId,
        createdAt: new Date().toISOString(),
      });
      this.save();
      return true; // Followed
    }
  }

  isFollowing(followerId: string, followingId: string): boolean {
    return this.state.follows.some(
      (f) => f.followerId === followerId && f.followingId === followingId,
    );
  }

  getFollowCounts(userId: string): { followersCount: number; followingCount: number } {
    const followersCount = this.state.follows.filter((f) => f.followingId === userId).length;
    const followingCount = this.state.follows.filter((f) => f.followerId === userId).length;
    return { followersCount, followingCount };
  }

  // --- STORE OPERATIONS ---
  updateUserStore(
    userId: string,
    data: {
      storeName?: string;
      storePhone?: string;
      storeDescription?: string;
      storeBannerUrl?: string;
      storeThemeColor?: string;
      storeTagline?: string;
      bakongAccountId?: string;
    },
  ): UserEntity | undefined {
    const user = this.findUserById(userId);
    if (!user) return undefined;
    if (data.storeName !== undefined) user.storeName = data.storeName.trim();
    if (data.storePhone !== undefined) user.storePhone = data.storePhone.trim();
    if (data.storeDescription !== undefined) user.storeDescription = data.storeDescription.trim();
    if (data.storeBannerUrl !== undefined) user.storeBannerUrl = data.storeBannerUrl.trim();
    if (data.storeThemeColor !== undefined) user.storeThemeColor = data.storeThemeColor.trim();
    if (data.storeTagline !== undefined) user.storeTagline = data.storeTagline.trim();
    if (data.bakongAccountId !== undefined) user.bakongAccountId = data.bakongAccountId.trim();

    // Sync store info to all existing products belonging to this seller
    for (const prod of this.state.products) {
      if (prod.sellerId === userId) {
        if (user.storeName) prod.sellerStoreName = user.storeName;
        if (user.storePhone) prod.sellerPhone = user.storePhone;
        if (user.bakongAccountId) prod.sellerBakongId = user.bakongAccountId;
      }
    }

    this.save();
    return user;
  }

  // --- MARKETPLACE OPERATIONS ---
  createProduct(dto: {
    title: string;
    priceUsd: number;
    category: string;
    condition?: string;
    imageUrl?: string;
    location?: string;
    description: string;
    sellerId: string;
    sellerBakongId?: string;
    sellerStoreName?: string;
  }): ProductEntity {
    const seller = this.findUserById(dto.sellerId);
    const bakongId = (dto.sellerBakongId && dto.sellerBakongId.trim())
      ? dto.sellerBakongId.trim()
      : (seller?.bakongAccountId && seller.bakongAccountId.trim())
        ? seller.bakongAccountId.trim()
        : '';

    const storeName = (dto.sellerStoreName && dto.sellerStoreName.trim())
      ? dto.sellerStoreName.trim()
      : (seller?.storeName && seller.storeName.trim())
        ? seller.storeName.trim()
        : (seller?.name || 'Spaces Merchant');

    // Automatically save Bakong ID & Store Name onto seller's user profile if provided
    if (seller) {
      let updated = false;
      if (dto.sellerBakongId && dto.sellerBakongId.trim() && seller.bakongAccountId !== dto.sellerBakongId.trim()) {
        seller.bakongAccountId = dto.sellerBakongId.trim();
        updated = true;
      }
      if (dto.sellerStoreName && dto.sellerStoreName.trim() && seller.storeName !== dto.sellerStoreName.trim()) {
        seller.storeName = dto.sellerStoreName.trim();
        updated = true;
      }
      if (updated) {
        this.save();
      }
    }

    const newProduct: ProductEntity = {
      id: `prod-${Date.now()}`,
      title: dto.title.trim(),
      priceUsd: dto.priceUsd,
      priceKhr: Math.round(dto.priceUsd * 4100),
      category: dto.category || 'Electronics',
      condition: dto.condition || 'ថ្មី (Brand New)',
      imageUrl: dto.imageUrl || '',
      location: dto.location || 'ភ្នំពេញ (Phnom Penh)',
      description: dto.description.trim(),
      sellerId: dto.sellerId,
      sellerStoreName: storeName,
      sellerPhone: seller?.storePhone || seller?.phone || '012345678',
      sellerBakongId: bakongId,
      sellerTier: seller?.subscriptionTier || 'FREE',
      createdAt: new Date().toISOString(),
    };
    this.state.products.unshift(newProduct);
    this.save();
    return newProduct;
  }

  getProducts(category?: string, query?: string, city?: string): ProductEntity[] {
    let result = [...this.state.products];
    if (category && category !== 'all') {
      result = result.filter((p) => p.category.toLowerCase() === category.toLowerCase());
    }
    if (city && city.trim()) {
      result = result.filter((p) => p.location.toLowerCase().includes(city.toLowerCase()));
    }
    if (query && query.trim()) {
      const q = query.toLowerCase().trim();
      result = result.filter(
        (p) =>
          p.title.toLowerCase().includes(q) ||
          p.description.toLowerCase().includes(q) ||
          p.location.toLowerCase().includes(q) ||
          (p.sellerStoreName && p.sellerStoreName.toLowerCase().includes(q)),
      );
    }

    // Ultra subscribers' products appear at the very top (Top Priority!)
    result.sort((a, b) => {
      const aScore = a.sellerTier === 'ULTRA' ? 2 : a.sellerTier === 'PRO_PLUS' ? 1 : 0;
      const bScore = b.sellerTier === 'ULTRA' ? 2 : b.sellerTier === 'PRO_PLUS' ? 1 : 0;
      return bScore - aScore;
    });

    return result;
  }

  deleteProduct(productId: string, userId: string): boolean {
    const index = this.state.products.findIndex((p) => p.id === productId);
    if (index === -1) return false;
    const prod = this.state.products[index];
    const user = this.findUserById(userId);
    if (prod.sellerId !== userId && user?.role !== 'ADMIN') {
      return false;
    }
    this.state.products.splice(index, 1);
    this.save();
    return true;
  }

  // --- ORDER & BAKONG TRANSACTIONS ---
  createOrder(orderData: {
    billNumber: string;
    productId: string;
    productTitle: string;
    quantity?: number;
    unitPrice?: number;
    amount: number;
    currency: string;
    buyerId: string;
    buyerName?: string;
    buyerPhone?: string;
    shippingAddress?: string;
    buyerNote?: string;
    sellerId: string;
    sellerName?: string;
    sellerStoreName?: string;
    sellerBakongId: string;
    md5: string;
    qrString?: string;
    qrImage?: string;
    deeplink?: string;
  }): OrderEntity {
    const order: OrderEntity = {
      id: `ord-${Date.now()}`,
      ...orderData,
      status: 'PENDING',
      fulfillmentStatus: 'PROCESSING',
      createdAt: new Date().toISOString(),
    };
    if (!this.state.orders) this.state.orders = [];
    this.state.orders.unshift(order);
    this.save();
    return order;
  }

  updateOrderFulfillment(
    orderId: string,
    actingUserId: string,
    fulfillmentStatus: 'PROCESSING' | 'CONFIRMED' | 'SHIPPING' | 'DELIVERED',
    trackingNote?: string,
  ): OrderEntity | null {
    if (!this.state.orders) return null;
    const order = this.state.orders.find((o) => o.id === orderId);
    if (!order) return null;
    const acting = this.findUserById(actingUserId);
    const isAdmin = acting?.role === 'ADMIN';
    // Seller updates processing/confirmed/shipping/delivered; buyer can confirm delivery too
    const canSeller = order.sellerId === actingUserId;
    const canBuyerDeliver = order.buyerId === actingUserId && fulfillmentStatus === 'DELIVERED';
    if (!canSeller && !canBuyerDeliver && !isAdmin) return null;

    order.fulfillmentStatus = fulfillmentStatus;
    if (trackingNote !== undefined) {
      order.trackingNote = trackingNote.trim();
    }
    order.updatedAt = new Date().toISOString();
    this.save();
    return order;
  }

  getOrderByMd5(md5: string): OrderEntity | undefined {
    if (!this.state.orders) return undefined;
    return this.state.orders.find((o) => o.md5 === md5);
  }

  getOrderById(id: string): OrderEntity | undefined {
    if (!this.state.orders) return undefined;
    return this.state.orders.find((o) => o.id === id);
  }

  updateOrderStatus(
    md5: string,
    status: 'PAID' | 'FAILED',
    transactionData?: any,
  ): OrderEntity | undefined {
    if (!this.state.orders) return undefined;
    const order = this.state.orders.find((o) => o.md5 === md5);
    if (!order) return undefined;
    order.status = status;
    if (transactionData) {
      order.transactionData = transactionData;
    }
    if (status === 'PAID') {
      order.paidAt = new Date().toISOString();
    }
    this.save();
    return order;
  }

  getUserOrders(userId: string): { purchases: OrderEntity[]; sales: OrderEntity[] } {
    if (!this.state.orders) return { purchases: [], sales: [] };
    const purchases = this.state.orders.filter((o) => o.buyerId === userId);
    const sales = this.state.orders.filter((o) => o.sellerId === userId);
    return { purchases, sales };
  }

  // --- STORY OPERATIONS ---
  createStory(authorId: string, imageUrl: string, caption?: string): StoryEntity {
    const user = this.findUserById(authorId);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString();
    const story: StoryEntity = {
      id: `story-${Date.now()}`,
      authorId,
      authorName: user?.name || 'Spaces User',
      authorAvatar: user?.avatar || '/default_avatar.svg',
      imageUrl: imageUrl.trim(),
      caption: caption?.trim(),
      expiresAt,
      createdAt: now.toISOString(),
    };
    if (!this.state.stories) this.state.stories = [];
    this.state.stories.unshift(story);
    this.save();
    return story;
  }

  private getStoryExpiryMs(story: StoryEntity): number {
    if (story.expiresAt) {
      const parsed = new Date(story.expiresAt).getTime();
      if (!Number.isNaN(parsed)) return parsed;
    }
    return new Date(story.createdAt).getTime() + 24 * 60 * 60 * 1000;
  }

  getStories(): StoryEntity[] {
    if (!this.state.stories) return [];
    const nowMs = Date.now();
    return this.state.stories.filter((s) => this.getStoryExpiryMs(s) > nowMs);
  }

  getStoryArchive(userId: string): Array<StoryEntity & { isArchived: boolean }> {
    if (!this.state.stories || !userId) return [];
    const nowMs = Date.now();
    return this.state.stories
      .filter((s) => s.authorId === userId)
      .map((s) => {
        const expMs = this.getStoryExpiryMs(s);
        return {
          ...s,
          expiresAt: s.expiresAt || new Date(expMs).toISOString(),
          isArchived: expMs <= nowMs,
        };
      });
  }

  deleteStory(storyId: string, userId: string): boolean {
    if (!this.state.stories) return false;
    const idx = this.state.stories.findIndex((s) => s.id === storyId);
    if (idx === -1) return false;
    const story = this.state.stories[idx];
    const user = this.findUserById(userId);
    if (story.authorId !== userId && user?.role !== 'ADMIN') return false;
    this.state.stories.splice(idx, 1);
    this.save();
    return true;
  }

  deletePostsBatch(postIds: string[], userId: string): number {
    const user = this.findUserById(userId);
    if (!user || user.role !== 'ADMIN') return 0;
    const idSet = new Set(postIds);
    const before = this.state.posts.length;
    this.state.posts = this.state.posts.filter((p) => !idSet.has(p.id));
    this.state.comments = this.state.comments.filter((c) => !idSet.has(c.postId));
    this.state.reactions = this.state.reactions.filter((r) => !idSet.has(r.postId));
    this.state.savedPosts = this.state.savedPosts.filter((s) => !idSet.has(s.postId));
    this.save();
    return before - this.state.posts.length;
  }

  // --- FRIEND REQUEST OPERATIONS (Add Friend / Confirm / Friends List) ---
  getFriendRelation(userId1: string, userId2: string): { status: string; requestId: string | null } {
    if (!this.state.friendRequests) this.state.friendRequests = [];
    const req = this.state.friendRequests.find(
      (fr) =>
        (fr.requesterId === userId1 && fr.receiverId === userId2) ||
        (fr.requesterId === userId2 && fr.receiverId === userId1),
    );
    if (!req) return { status: 'NONE', requestId: null };
    if (req.status === 'ACCEPTED') return { status: 'ACCEPTED', requestId: req.id };
    if (req.requesterId === userId1) return { status: 'PENDING_SENT', requestId: req.id };
    return { status: 'PENDING_RECEIVED', requestId: req.id };
  }

  sendFriendRequest(requesterId: string, receiverId: string): FriendRequestEntity | null {
    if (!requesterId || !receiverId || requesterId === receiverId) return null;
    if (!this.state.friendRequests) this.state.friendRequests = [];

    const existing = this.state.friendRequests.find(
      (fr) =>
        (fr.requesterId === requesterId && fr.receiverId === receiverId) ||
        (fr.requesterId === receiverId && fr.receiverId === requesterId),
    );
    if (existing) {
      // If the other user already sent us a request, accept it immediately!
      if (existing.requesterId === receiverId && existing.status === 'PENDING') {
        existing.status = 'ACCEPTED';
        existing.updatedAt = new Date().toISOString();
        this.save();
      }
      return existing;
    }

    const req: FriendRequestEntity = {
      id: `fr-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      requesterId,
      receiverId,
      status: 'PENDING',
      createdAt: new Date().toISOString(),
    };
    this.state.friendRequests.unshift(req);
    this.save();
    return req;
  }

  respondFriendRequest(requestId: string, userId: string, accept: boolean): { status: string; request?: FriendRequestEntity } {
    if (!this.state.friendRequests) this.state.friendRequests = [];
    const idx = this.state.friendRequests.findIndex((fr) => fr.id === requestId);
    if (idx === -1) return { status: 'NOT_FOUND' };
    const req = this.state.friendRequests[idx];
    if (req.receiverId !== userId && req.requesterId !== userId) {
      return { status: 'FORBIDDEN' };
    }
    if (accept && req.receiverId === userId) {
      req.status = 'ACCEPTED';
      req.updatedAt = new Date().toISOString();
      this.save();
      return { status: 'ACCEPTED', request: req };
    } else {
      this.state.friendRequests.splice(idx, 1);
      this.save();
      return { status: 'REMOVED' };
    }
  }

  removeFriend(userId1: string, userId2: string): boolean {
    if (!this.state.friendRequests) return false;
    const before = this.state.friendRequests.length;
    this.state.friendRequests = this.state.friendRequests.filter(
      (fr) =>
        !(
          (fr.requesterId === userId1 && fr.receiverId === userId2) ||
          (fr.requesterId === userId2 && fr.receiverId === userId1)
        ),
    );
    this.save();
    return this.state.friendRequests.length < before;
  }

  getFriendsOverview(userId: string) {
    if (!this.state.friendRequests) this.state.friendRequests = [];
    const friends: any[] = [];
    const incomingRequests: any[] = [];
    const outgoingRequests: any[] = [];

    for (const fr of this.state.friendRequests) {
      if (fr.status === 'ACCEPTED') {
        if (fr.requesterId === userId || fr.receiverId === userId) {
          const otherId = fr.requesterId === userId ? fr.receiverId : fr.requesterId;
          const u = this.findUserById(otherId);
          if (u && !u.isBanned) {
            friends.push({
              requestId: fr.id,
              id: u.id,
              name: u.name,
              username: u.username,
              avatar: u.avatar || '/default_avatar.svg',
              isVerified: u.isVerified,
              location: u.location || 'Cambodia',
              bio: u.bio || '',
            });
          }
        }
      } else if (fr.status === 'PENDING') {
        if (fr.receiverId === userId) {
          const u = this.findUserById(fr.requesterId);
          if (u && !u.isBanned) {
            incomingRequests.push({
              requestId: fr.id,
              id: u.id,
              name: u.name,
              username: u.username,
              avatar: u.avatar || '/default_avatar.svg',
              isVerified: u.isVerified,
              createdAt: fr.createdAt,
            });
          }
        } else if (fr.requesterId === userId) {
          const u = this.findUserById(fr.receiverId);
          if (u && !u.isBanned) {
            outgoingRequests.push({
              requestId: fr.id,
              id: u.id,
              name: u.name,
              username: u.username,
              avatar: u.avatar || '/default_avatar.svg',
              isVerified: u.isVerified,
              createdAt: fr.createdAt,
            });
          }
        }
      }
    }

    return { friends, incomingRequests, outgoingRequests };
  }

  // --- CHAT OPERATIONS ---
  getChatsForUser(userId: string): ChatEntity[] {
    return this.state.chats
      .filter((c) => c.participantIds.includes(userId))
      .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
  }

  getOrCreateChat(userId1: string, userId2: string): ChatEntity {
    let chat = this.state.chats.find(
      (c) =>
        c.participantIds.length === 2 &&
        c.participantIds.includes(userId1) &&
        c.participantIds.includes(userId2),
    );
    if (!chat) {
      chat = {
        id: `chat-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
        participantIds: [userId1, userId2],
        lastMessage: '',
        updatedAt: new Date().toISOString(),
      };
      this.state.chats.unshift(chat);
      this.save();
    }
    return chat;
  }

  getMessagesByChatId(chatId: string): MessageEntity[] {
    return this.state.messages.filter((m) => m.chatId === chatId);
  }

  getChatById(chatId: string): ChatEntity | undefined {
    return this.state.chats.find((c) => c.id === chatId);
  }

  sendMessage(
    chatId: string,
    senderId: string,
    text: string,
    mediaUrl?: string,
    mediaType: 'text' | 'image' | 'video' | 'voice' = 'text',
    durationSec?: number,
  ): MessageEntity {
    const cleanText = (text || '').trim();
    const msg: MessageEntity = {
      id: `msg-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      chatId,
      senderId,
      text: cleanText,
      mediaUrl: mediaUrl?.trim(),
      mediaType: mediaType || (mediaUrl ? 'image' : 'text'),
      durationSec,
      createdAt: new Date().toISOString(),
    };
    this.state.messages.push(msg);
    const chat = this.state.chats.find((c) => c.id === chatId);
    if (chat) {
      if (msg.mediaType === 'voice') {
        chat.lastMessage = `សារសំឡេង (Voice ${durationSec || 0}s)`;
      } else if (msg.mediaType === 'video') {
        chat.lastMessage = cleanText || 'បានផ្ញើវីដេអូ (Video)';
      } else if (msg.mediaType === 'image') {
        chat.lastMessage = cleanText || 'បានផ្ញើរូបភាព (Photo)';
      } else {
        chat.lastMessage = cleanText;
      }
      chat.updatedAt = msg.createdAt;
    }
    this.save();
    return msg;
  }

  // --- STREAMS & VIDEO WATCH ---
  getStreams(query?: { category?: string; authorId?: string; currentUserId?: string }): any[] {
    if (!this.state.streams) this.state.streams = [];
    let list = [...this.state.streams];

    if (query?.category && query.category !== 'all') {
      list = list.filter((s) => s.category.toLowerCase() === query.category!.toLowerCase());
    }
    if (query?.authorId) {
      list = list.filter((s) => s.authorId === query.authorId);
    }

    // Map isLiked for current user
    return list.map((s) => ({
      ...s,
      isLiked: query?.currentUserId ? (s.likedUserIds?.includes(query.currentUserId) || false) : false,
    }));
  }

  deleteStream(streamId: string, userId: string): boolean {
    if (!this.state.streams) return false;
    const idx = this.state.streams.findIndex((s) => s.id === streamId);
    if (idx === -1) return false;
    const stream = this.state.streams[idx];
    const user = this.findUserById(userId);
    if (stream.authorId !== userId && user?.role !== 'ADMIN') return false;
    this.state.streams.splice(idx, 1);
    this.save();
    return true;
  }

  createStream(dto: {
    authorId: string;
    title: string;
    description: string;
    videoUrl: string;
    thumbnailUrl?: string;
    category?: string;
    duration?: string;
    isLive?: boolean;
    liveTheme?: string;
    pinnedNotice?: string;
    videoFilter?: string;
  }): StreamEntity {
    const author = this.findUserById(dto.authorId);
    const newStream: StreamEntity = {
      id: `stream-${Date.now()}`,
      authorId: dto.authorId,
      authorName: author?.name || 'Spaces Creator',
      authorAvatar: author?.avatar || '/default_avatar.svg',
      authorRole: author?.role || 'USER',
      authorIsVerified: author?.isVerified || false,
      title: (dto.title || 'Live Video').trim(),
      description: (dto.description || '').trim(),
      videoUrl: (dto.videoUrl || '').trim(),
      thumbnailUrl: dto.thumbnailUrl?.trim() || author?.avatar,
      category: dto.category || 'trending',
      duration: dto.duration || (dto.isLive ? 'LIVE' : '05:00'),
      viewsCount: 1,
      likesCount: 0,
      commentsCount: 0,
      isLive: dto.isLive || false,
      viewerCount: dto.isLive ? 1 : undefined,
      likedUserIds: [],
      liveTheme: dto.liveTheme?.trim() || 'ocean',
      pinnedNotice: dto.pinnedNotice?.trim() || undefined,
      videoFilter: dto.videoFilter?.trim() || 'normal',
      createdAt: new Date().toISOString(),
    };

    if (!this.state.streams) this.state.streams = [];
    this.state.streams.unshift(newStream);
    this.save();
    return newStream;
  }

  updateStreamCustomizations(
    streamId: string,
    userId: string,
    data: { liveTheme?: string; pinnedNotice?: string; videoFilter?: string },
  ): StreamEntity | null {
    const stream = this.getStreamById(streamId);
    if (!stream) return null;
    const user = this.findUserById(userId);
    if (stream.authorId !== userId && user?.role !== 'ADMIN') return null;
    if (data.liveTheme !== undefined) stream.liveTheme = data.liveTheme.trim() || 'ocean';
    if (data.pinnedNotice !== undefined) stream.pinnedNotice = data.pinnedNotice.trim();
    if (data.videoFilter !== undefined) stream.videoFilter = data.videoFilter.trim() || 'normal';
    this.save();
    return stream;
  }

  toggleStreamLike(streamId: string, userId: string): { isLiked: boolean; likesCount: number } {
    if (!this.state.streams) this.state.streams = [];
    const stream = this.state.streams.find((s) => s.id === streamId);
    if (!stream) return { isLiked: false, likesCount: 0 };

    if (!stream.likedUserIds) stream.likedUserIds = [];
    const idx = stream.likedUserIds.indexOf(userId);
    let isLiked = false;

    if (idx === -1) {
      stream.likedUserIds.push(userId);
      stream.likesCount = (stream.likesCount || 0) + 1;
      isLiked = true;
    } else {
      stream.likedUserIds.splice(idx, 1);
      stream.likesCount = Math.max(0, (stream.likesCount || 0) - 1);
      isLiked = false;
    }

    this.save();
    return { isLiked, likesCount: stream.likesCount };
  }

  getStreamById(streamId: string): StreamEntity | undefined {
    if (!this.state.streams) return undefined;
    return this.state.streams.find((s) => s.id === streamId);
  }

  pushLiveChunk(
    streamId: string,
    chunkUrl: string,
    posterUrl?: string,
  ): StreamEntity | null {
    const stream = this.getStreamById(streamId);
    if (!stream) return null;

    const seq = (stream.liveChunkSeq || 0) + 1;
    stream.isLive = true;
    stream.duration = 'LIVE';
    stream.liveChunkSeq = seq;
    stream.liveChunkUrl = chunkUrl;
    if (!stream.liveChunks) stream.liveChunks = [];
    stream.liveChunks.push({
      seq,
      url: chunkUrl,
      createdAt: new Date().toISOString(),
    });
    if (stream.liveChunks.length > 10) {
      stream.liveChunks = stream.liveChunks.slice(-10);
    }
    if (!stream.videoUrl || stream.videoUrl.startsWith('live://')) {
      stream.videoUrl = chunkUrl;
    } else {
      stream.videoUrl = chunkUrl;
    }
    if (posterUrl) {
      stream.thumbnailUrl = posterUrl;
    }
    this.save();
    return stream;
  }

  updateStreamViewerCount(streamId: string, count: number): void {
    const stream = this.getStreamById(streamId);
    if (!stream) return;
    stream.viewerCount = Math.max(0, count);
  }

  incrementStreamComments(streamId: string): void {
    const stream = this.getStreamById(streamId);
    if (!stream) return;
    stream.commentsCount = (stream.commentsCount || 0) + 1;
    this.save();
  }

  endLiveStream(
    streamId: string,
    finalVideoUrl?: string,
    finalDuration?: string,
    posterUrl?: string,
  ): StreamEntity | null {
    const stream = this.getStreamById(streamId);
    if (!stream) return null;

    stream.isLive = false;
    stream.liveEndedAt = new Date().toISOString();
    stream.viewerCount = 0;

    if (finalVideoUrl && finalVideoUrl.trim().length > 0) {
      stream.videoUrl = finalVideoUrl.trim();
    } else if (stream.liveChunks && stream.liveChunks.length > 0) {
      stream.videoUrl = stream.liveChunks[stream.liveChunks.length - 1].url;
    }

    if (posterUrl && posterUrl.trim().length > 0) {
      stream.thumbnailUrl = posterUrl.trim();
    }

    if (finalDuration && finalDuration.trim().length > 0) {
      stream.duration = finalDuration.trim();
    } else {
      const elapsedSec = Math.max(
        1,
        Math.floor((Date.now() - new Date(stream.createdAt).getTime()) / 1000),
      );
      const mins = Math.floor(elapsedSec / 60).toString().padStart(2, '0');
      const secs = (elapsedSec % 60).toString().padStart(2, '0');
      stream.duration = `${mins}:${secs}`;
    }

    this.save();
    return stream;
  }

  // --- BLOCKING & MODERATION REPORTS ---
  getBlockedUserIds(blockerId: string): string[] {
    if (!this.state.blockedUsers) return [];
    return this.state.blockedUsers
      .filter((b) => b.blockerId === blockerId)
      .map((b) => b.blockedId);
  }

  isBlockedBetween(u1: string, u2: string): boolean {
    if (!this.state.blockedUsers) return false;
    return this.state.blockedUsers.some(
      (b) => (b.blockerId === u1 && b.blockedId === u2) || (b.blockerId === u2 && b.blockedId === u1),
    );
  }

  toggleBlockUser(blockerId: string, blockedId: string): { isBlocked: boolean } {
    if (!blockerId || !blockedId || blockerId === blockedId) {
      return { isBlocked: false };
    }
    if (!this.state.blockedUsers) this.state.blockedUsers = [];
    const idx = this.state.blockedUsers.findIndex(
      (b) => b.blockerId === blockerId && b.blockedId === blockedId,
    );
    if (idx >= 0) {
      this.state.blockedUsers.splice(idx, 1);
      this.save();
      return { isBlocked: false };
    }
    this.state.blockedUsers.push({
      blockerId,
      blockedId,
      createdAt: new Date().toISOString(),
    });
    this.save();
    return { isBlocked: true };
  }

  getBlockedUsersProfiles(blockerId: string) {
    const ids = this.getBlockedUserIds(blockerId);
    return ids
      .map((id) => this.findUserById(id))
      .filter((u): u is UserEntity => !!u)
      .map((u) => ({
        id: u.id,
        name: u.name,
        username: u.username,
        avatar: u.avatar || '/default_avatar.svg',
      }));
  }

  createReport(
    reporterId: string,
    targetType: 'POST' | 'USER',
    targetId: string,
    reason: string,
  ): ReportEntity {
    if (!this.state.reports) this.state.reports = [];
    const report: ReportEntity = {
      id: `rep-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      reporterId,
      targetType,
      targetId,
      reason: (reason || 'Inappropriate content').trim(),
      status: 'OPEN',
      createdAt: new Date().toISOString(),
    };
    this.state.reports.unshift(report);
    this.save();
    return report;
  }

  getReports() {
    if (!this.state.reports) return [];
    return this.state.reports.map((r) => {
      const reporter = this.findUserById(r.reporterId);
      let targetPreview = '';
      let targetAuthorId = '';
      if (r.targetType === 'POST') {
        const post = this.state.posts.find((p) => p.id === r.targetId);
        targetPreview = post ? post.content.substring(0, 120) : '[Post deleted]';
        targetAuthorId = post?.authorId || '';
      } else {
        const u = this.findUserById(r.targetId);
        targetPreview = u ? `${u.name} (@${u.username})` : '[User not found]';
        targetAuthorId = r.targetId;
      }
      return {
        ...r,
        reporterName: reporter?.name || 'User',
        targetPreview,
        targetAuthorId,
      };
    });
  }

  resolveReport(
    reportId: string,
    action: 'DISMISS' | 'DELETE_POST' | 'BAN_USER',
  ): { success: boolean; report?: ReportEntity } {
    if (!this.state.reports) return { success: false };
    const report = this.state.reports.find((r) => r.id === reportId);
    if (!report) return { success: false };

    if (action === 'DELETE_POST' && report.targetType === 'POST') {
      this.state.posts = this.state.posts.filter((p) => p.id !== report.targetId);
      report.status = 'RESOLVED';
    } else if (action === 'BAN_USER') {
      const targetUserId =
        report.targetType === 'USER'
          ? report.targetId
          : this.state.posts.find((p) => p.id === report.targetId)?.authorId;
      if (targetUserId) {
        const targetUser = this.findUserById(targetUserId);
        if (targetUser && targetUser.role !== 'ADMIN') {
          targetUser.isBanned = true;
        }
      }
      report.status = 'RESOLVED';
    } else {
      report.status = 'DISMISSED';
    }

    report.resolvedAt = new Date().toISOString();
    this.save();
    return { success: true, report };
  }

  // --- PERSISTENT NOTIFICATIONS ---
  createNotification(input: {
    userId: string;
    actorId: string;
    type: 'LIKE' | 'COMMENT' | 'FRIEND' | 'ORDER_PAID' | 'ORDER_UPDATE';
    title: string;
    body: string;
    refId?: string;
  }): NotificationEntity | null {
    if (!input.userId) return null;
    if (!this.state.notifications) this.state.notifications = [];
    const actor = this.findUserById(input.actorId);
    const notif: NotificationEntity = {
      id: `notif-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      userId: input.userId,
      actorId: input.actorId,
      actorName: actor?.name || 'Spaces User',
      actorAvatar: actor?.avatar || '/default_avatar.svg',
      type: input.type,
      title: input.title,
      body: input.body,
      refId: input.refId,
      isRead: false,
      createdAt: new Date().toISOString(),
    };
    this.state.notifications.unshift(notif);
    if (this.state.notifications.length > 1000) {
      this.state.notifications = this.state.notifications.slice(0, 1000);
    }
    this.save();
    return notif;
  }

  getNotificationsForUser(userId: string): NotificationEntity[] {
    if (!this.state.notifications || !userId) return [];
    return this.state.notifications.filter((n) => n.userId === userId).slice(0, 100);
  }

  markNotificationRead(id: string, userId?: string): boolean {
    if (!this.state.notifications) return false;
    const notif = this.state.notifications.find((n) => n.id === id && (!userId || n.userId === userId));
    if (!notif) return false;
    notif.isRead = true;
    this.save();
    return true;
  }

  // --- STATS ---
  getStats() {
    return {
      totalUsers: this.state.users.length,
      activeUsers: this.state.users.filter((u) => !u.isBanned).length,
      totalSpaces: 3,
      totalPosts: this.state.posts.length,
      totalStreams: this.state.streams ? this.state.streams.length : 0,
      totalStories: this.state.stories ? this.state.stories.length : 0,
      totalChats: this.state.chats ? this.state.chats.length : 0,
      totalMessages: this.state.messages ? this.state.messages.length : 0,
      totalReactions: this.state.reactions.length,
      totalProducts: this.state.products.length,
      serverUptimeSeconds: Math.floor(process.uptime()),
      systemVersion: 'Spaces Cambodia 2.0.0 (Production Persistent Release)',
      databaseEngine: 'Persistent Disk Store (Prisma & Supabase Compatible)',
    };
  }
}
