import { Injectable } from '@nestjs/common';
import { DbService, PostEntity, UserEntity } from '../database/db.service';
import { EventsService } from '../events/events.service';

export interface Author {
  id: string;
  name: string;
  username: string;
  avatar: string;
  isVerified: boolean;
  role: string;
  location: string;
  bio: string;
  followerCount: number;
  followingCount: number;
  isFollowing: boolean;
}

export interface PostItem {
  id: string;
  author: Author;
  space: {
    id: string;
    name: string;
    mode: 'FAMILY' | 'TEAM' | 'PUBLIC';
    color: string;
    icon: string;
  };
  circle?: string;
  city: string;
  content: string;
  imageUrl?: string;
  aspectRatio?: number;
  timeAgo: string;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  isLiked: boolean;
  selectedReaction?: string;
  isBookmarked: boolean;
  tags: string[];
  templateStyle?: string;
  moodTag?: string;
  videoUrl?: string;
  isReel?: boolean;
  reelAudioTitle?: string;
  comments: Array<{
    id: string;
    author: string;
    avatar: string;
    text: string;
    timeAgo: string;
    authorId: string;
    parentId?: string;
    replyToAuthor?: string;
  }>;
}

export interface SpaceItem {
  id: string;
  name: string;
  mode: 'FAMILY' | 'TEAM' | 'PUBLIC';
  color: string;
  icon: string;
  description: string;
  memberCount: number;
  postCount: number;
}

@Injectable()
export class FeedService {
  constructor(
    private readonly db: DbService,
    private readonly events: EventsService,
  ) {}

  private spaces: SpaceItem[] = [
    {
      id: 'public',
      name: 'Spaces កម្ពុជា (Public)',
      mode: 'PUBLIC',
      color: '#007AFF',
      icon: 'globe',
      description: 'តំបន់សាធារណៈសម្រាប់ប្រជាជនកម្ពុជាចែករំលែកព័ត៌មាន និងចំណេះដឹងទូទៅ',
      memberCount: 1,
      postCount: 0,
    },
    {
      id: 'family',
      name: 'គ្រួសារកក់ក្ដៅ (Family)',
      mode: 'FAMILY',
      color: '#34C759',
      icon: 'house',
      description: 'តំបន់ឯកជនសម្រាប់តែសមាជិកគ្រួសារ សុវត្ថិភាពខ្ពស់ គ្មានការផ្សាយពាណិជ្ជកម្ម',
      memberCount: 1,
      postCount: 0,
    },
    {
      id: 'team',
      name: 'ក្រុមការងារ & Developer (Team)',
      mode: 'TEAM',
      color: '#5856D6',
      icon: 'briefcase',
      description: 'តំបន់សម្រាប់ពិភាក្សាគម្រោងការងារ ឯកសារ និងបច្ចេកវិទ្យា',
      memberCount: 1,
      postCount: 0,
    },
  ];

  getSpaces(): SpaceItem[] {
    return this.spaces.map((s) => ({
      ...s,
      postCount: this.db.getPosts({ spaceId: s.id }).length,
      memberCount: Math.max(1, this.db.getAllUsers().length),
    }));
  }

  private formatTimeAgo(isoDate?: string): string {
    if (!isoDate) return 'ថ្មីៗនេះ';
    const diffMs = Date.now() - new Date(isoDate).getTime();
    const mins = Math.floor(diffMs / 60000);
    if (mins < 1) return 'ឥឡូវនេះ';
    if (mins < 60) return `${mins} នាទីមុន`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours} ម៉ោងមុន`;
    const days = Math.floor(hours / 24);
    return `${days} ថ្ងៃមុន`;
  }

  getStories() {
    const dbStories = this.db.getStories();
    return dbStories.map((s) => ({
      id: s.id,
      city: 'កម្ពុជា (Cambodia)',
      title: s.caption || 'Story',
      caption: s.caption || '',
      imageUrl: s.imageUrl,
      coverUrl: s.imageUrl,
      timeAgo: this.formatTimeAgo(s.createdAt),
      author: {
        id: s.authorId,
        name: s.authorName,
        avatar: s.authorAvatar || '/default_avatar.svg',
      },
      hasUnseen: true,
      expiresAt: s.expiresAt,
      createdAt: s.createdAt,
    }));
  }

  getStoryArchive(userId: string) {
    const dbStories = this.db.getStoryArchive(userId);
    return dbStories.map((s) => ({
      id: s.id,
      city: 'កម្ពុជា (Cambodia)',
      title: s.caption || 'Story',
      caption: s.caption || '',
      imageUrl: s.imageUrl,
      coverUrl: s.imageUrl,
      timeAgo: this.formatTimeAgo(s.createdAt),
      author: {
        id: s.authorId,
        name: s.authorName,
        avatar: s.authorAvatar || '/default_avatar.svg',
      },
      hasUnseen: false,
      expiresAt: s.expiresAt,
      isArchived: s.isArchived,
      createdAt: s.createdAt,
    }));
  }

  createStory(authorId: string, imageUrl: string, caption?: string) {
    return this.db.createStory(authorId, imageUrl, caption);
  }

  deleteStory(storyId: string, userId: string): boolean {
    return this.db.deleteStory(storyId, userId);
  }

  deletePostsBatch(postIds: string[], userId: string): number {
    return this.db.deletePostsBatch(postIds, userId);
  }

  deleteStream(streamId: string, userId: string): boolean {
    return this.db.deleteStream(streamId, userId);
  }

  getFeed(params?: {
    spaceId?: string;
    city?: string;
    authorId?: string;
    savedByUserId?: string;
    currentUserId?: string;
  }) {
    const blockedSet = params?.currentUserId
      ? new Set(this.db.getBlockedUserIds(params.currentUserId))
      : new Set<string>();

    const rawPosts = this.db
      .getPosts({
        spaceId: params?.spaceId,
        city: params?.city,
        authorId: params?.authorId,
        savedByUserId: params?.savedByUserId,
      })
      .filter((p) => !blockedSet.has(p.authorId));

    const posts = rawPosts.map((p) => this.toPostItem(p, params?.currentUserId));

    return {
      posts,
      settings: {
        instanceMode: 'mixed',
        focusMode: false,
        hideMetrics: false,
      },
    };
  }

  createPost(dto: {
    authorId?: string;
    content: string;
    spaceId: string;
    city?: string;
    circleName?: string;
    imageUrl?: string;
    tags?: string[];
    templateStyle?: string;
    moodTag?: string;
  }) {
    const authorId = dto.authorId || 'admin-1';
    const post = this.db.createPost({
      authorId,
      content: dto.content,
      spaceId: dto.spaceId || 'public',
      city: dto.city,
      circleName: dto.circleName,
      imageUrl: dto.imageUrl,
      tags: dto.tags,
      templateStyle: dto.templateStyle,
      moodTag: dto.moodTag,
    });
    return this.toPostItem(post, authorId);
  }

  updatePost(id: string, userId: string, updates: { content?: string; city?: string; imageUrl?: string }) {
    const post = this.db.updatePost(id, userId, updates);
    if (!post) return null;
    return this.toPostItem(post, userId);
  }

  deletePost(id: string, userId: string): boolean {
    return this.db.deletePost(id, userId);
  }

  toggleReaction(postId: string, userId: string, reaction: string) {
    const res = this.db.toggleReaction(postId, userId, reaction);
    const post = this.db.getPosts().find((p) => p.id === postId);
    if (post && post.authorId !== userId && res?.reacted) {
      const actor = this.db.findUserById(userId);
      this.events.emitToUser(post.authorId, {
        type: 'NOTIFICATION',
        title: `${actor?.name || 'នរណាម្នាក់'} បានបញ្ចេញប្រតិកម្ម (${reaction})`,
        body: post.content.substring(0, 80),
        data: { postId, reaction },
      });
    }
    return res;
  }

  addComment(postId: string, authorId: string, text: string, parentId?: string) {
    const comment = this.db.addComment(postId, authorId, text, parentId);
    const author = this.db.findUserById(authorId);
    const post = this.db.getPosts().find((p) => p.id === postId);
    if (post && post.authorId !== authorId) {
      this.events.emitToUser(post.authorId, {
        type: 'NOTIFICATION',
        title: `${author?.name || 'នរណាម្នាក់'} បានបញ្ចេញមតិលើការបង្ហោះរបស់អ្នក`,
        body: text.substring(0, 100),
        data: { postId, commentId: comment.id },
      });
    }
    return {
      id: comment.id,
      author: author?.name || 'អ្នកប្រើប្រាស់',
      avatar: author?.avatar || '/default_avatar.svg',
      text: comment.text,
      timeAgo: 'មុននេះបន្តិច',
      authorId: comment.authorId,
      parentId: comment.parentId,
      replyToAuthor: comment.replyToAuthor,
    };
  }

  deleteComment(commentId: string, userId: string): boolean {
    return this.db.deleteComment(commentId, userId);
  }

  toggleSavePost(postId: string, userId: string): boolean {
    return this.db.toggleSavePost(postId, userId);
  }

  // --- FRIENDS (ADD FRIEND / CONFIRM) ---
  getFriendsOverview(userId: string) {
    return this.db.getFriendsOverview(userId);
  }

  sendFriendRequest(requesterId: string, receiverId: string) {
    const req = this.db.sendFriendRequest(requesterId, receiverId);
    if (!req) return { success: false, message: 'សំណើមិនត្រឹមត្រូវ' };
    const sender = this.db.findUserById(requesterId);
    this.events.emitToUser(receiverId, {
      type: 'NOTIFICATION',
      title: 'សំណើសុំធ្វើមិត្តថ្មី',
      body: `${sender?.name || 'អ្នកប្រើប្រាស់'} ចង់ភ្ជាប់ទំនាក់ទំនងជាមួយអ្នក`,
      data: { requesterId },
    });
    return { success: true, request: req };
  }

  respondFriendRequest(requestId: string, userId: string, accept: boolean) {
    const res = this.db.respondFriendRequest(requestId, userId, accept);
    if (accept && res?.request?.requesterId) {
      const accepter = this.db.findUserById(userId);
      this.events.emitToUser(res.request.requesterId, {
        type: 'NOTIFICATION',
        title: 'សំណើធ្វើមិត្តត្រូវបានយល់ព្រម',
        body: `${accepter?.name || 'មិត្តភក្តិ'} បានយល់ព្រមជាមិត្តរបស់អ្នកហើយ`,
        data: { userId },
      });
    }
    return res;
  }

  removeFriend(userId1: string, userId2: string) {
    const ok = this.db.removeFriend(userId1, userId2);
    return { success: ok };
  }

  // --- MESSENGER & CHATS ---
  getChats(userId: string) {
    if (!userId) return [];
    const chats = this.db.getChatsForUser(userId);
    return chats.map((c) => {
      const otherId = c.participantIds.find((id) => id !== userId) || userId;
      const otherUser = this.db.findUserById(otherId);
      const avatar = otherUser?.avatar || '/default_avatar.svg';
      const name = otherUser?.name || 'ការជជែក';
      return {
        id: c.id,
        participantId: otherId,
        participantUsername: otherUser?.username || '',
        isVerified: otherUser?.isVerified || false,
        title: name,
        avatar,
        participantName: name,
        participantAvatar: avatar,
        isGroup: false,
        lastMessage: c.lastMessage || 'ចាប់ផ្ដើមការសន្ទនា',
        lastMessageTime: this.formatTimeAgo(c.updatedAt),
        timeAgo: this.formatTimeAgo(c.updatedAt),
        unreadCount: 0,
      };
    });
  }

  getOrCreateDirectChat(userId1: string, userId2: string) {
    const chat = this.db.getOrCreateChat(userId1, userId2);
    const otherUser = this.db.findUserById(userId2);
    const avatar = otherUser?.avatar || '/default_avatar.svg';
    const name = otherUser?.name || 'ការជជែក';
    return {
      id: chat.id,
      participantId: userId2,
      participantUsername: otherUser?.username || '',
      isVerified: otherUser?.isVerified || false,
      title: name,
      avatar,
      participantName: name,
      participantAvatar: avatar,
      isGroup: false,
      lastMessage: chat.lastMessage || '',
      lastMessageTime: this.formatTimeAgo(chat.updatedAt),
      timeAgo: this.formatTimeAgo(chat.updatedAt),
      unreadCount: 0,
    };
  }

  getMessages(chatId: string, currentUserId?: string) {
    const msgs = this.db.getMessagesByChatId(chatId);
    return msgs.map((m) => {
      const sender = this.db.findUserById(m.senderId);
      const sName = sender?.name || 'User';
      const sAvatar = sender?.avatar || '/default_avatar.svg';
      return {
        id: m.id,
        chatId: m.chatId,
        senderId: m.senderId,
        senderName: sName,
        senderAvatar: sAvatar,
        sender: { id: m.senderId, name: sName, avatar: sAvatar },
        text: m.text,
        mediaUrl: m.mediaUrl || null,
        mediaType: m.mediaType || 'text',
        durationSec: m.durationSec || 0,
        timeAgo: this.formatTimeAgo(m.createdAt),
        isMe: currentUserId ? m.senderId === currentUserId : false,
        createdAt: m.createdAt,
      };
    });
  }

  sendMessage(
    chatId: string,
    senderId: string,
    text: string,
    mediaUrl?: string,
    mediaType: 'text' | 'image' | 'video' | 'voice' = 'text',
    durationSec?: number,
  ) {
    const msg = this.db.sendMessage(chatId, senderId, text, mediaUrl, mediaType, durationSec);
    const sender = this.db.findUserById(senderId);
    const sName = sender?.name || 'User';
    const sAvatar = sender?.avatar || '/default_avatar.svg';

    const payloadMsg = {
      id: msg.id,
      chatId: msg.chatId,
      senderId: msg.senderId,
      senderName: sName,
      senderAvatar: sAvatar,
      sender: { id: msg.senderId, name: sName, avatar: sAvatar },
      text: msg.text,
      mediaUrl: msg.mediaUrl || null,
      mediaType: msg.mediaType || 'text',
      durationSec: msg.durationSec || 0,
      timeAgo: 'ឥឡូវនេះ',
      isMe: false,
      createdAt: msg.createdAt,
    };

    const chat = this.db.getChatById(chatId);
    if (chat) {
      const recipients = chat.participantIds.filter((id) => id !== senderId);
      const preview =
        msg.text ||
        (msg.mediaType === 'voice'
          ? '🎤 សារសំឡេងថ្មី'
          : msg.mediaType === 'video'
            ? '🎬 វីដេអូថ្មី'
            : '📷 រូបភាពថ្មី');
      this.events.emitToUsers(recipients, {
        type: 'CHAT_MESSAGE',
        title: `សារថ្មីពី ${sName}`,
        body: preview,
        data: { chatId, message: payloadMsg },
      });
    }

    return {
      ...payloadMsg,
      isMe: true,
    };
  }

  getReels(currentUserId?: string) {
    const blockedSet = currentUserId
      ? new Set(this.db.getBlockedUserIds(currentUserId))
      : new Set<string>();
    const raw = this.db.getReels().filter((p) => !blockedSet.has(p.authorId));
    return raw.map((p) => this.toPostItem(p, currentUserId));
  }

  createReport(reporterId: string, targetType: 'POST' | 'USER', targetId: string, reason: string) {
    return this.db.createReport(reporterId, targetType, targetId, reason);
  }

  toggleBlockUser(blockerId: string, blockedId: string) {
    return this.db.toggleBlockUser(blockerId, blockedId);
  }

  getBlockedUsers(blockerId: string) {
    return this.db.getBlockedUsersProfiles(blockerId);
  }

  createReel(dto: {
    authorId?: string;
    videoUrl: string;
    content?: string;
    audioTitle?: string;
    location?: string;
    spaceId?: string;
    tags?: string[];
    isBoosted?: boolean;
    isAiGenerated?: boolean;
    shareToStory?: boolean;
  }) {
    const authorId = dto.authorId || 'admin-1';
    const city = dto.location || 'Cambodia';
    let content = dto.content || '';
    if (dto.isAiGenerated && !content.includes('#AI')) {
      content = `[AI Created] ${content}`.trim();
    }
    const reel = this.db.createPost({
      authorId,
      content,
      spaceId: dto.spaceId && dto.spaceId.trim().length > 0 ? dto.spaceId.trim() : 'public',
      circleName: 'Reels',
      city,
      videoUrl: dto.videoUrl,
      mediaType: 'video',
      tags: Array.isArray(dto.tags) ? dto.tags : undefined,
      isBoosted: dto.isBoosted === true,
      isReel: true,
      reelAudioTitle: dto.audioTitle || 'Original Audio',
    });

    if (dto.shareToStory) {
      try {
        this.db.createStory(authorId, dto.videoUrl, content.substring(0, 80));
      } catch (err) {
        console.warn('Failed to mirror reel to story:', err);
      }
    }

    return this.toPostItem(reel, authorId);
  }

  getStreams(query?: { category?: string; authorId?: string; currentUserId?: string }) {
    return this.db.getStreams(query);
  }

  createStream(dto: {
    authorId?: string;
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
  }) {
    const authorId = dto.authorId || 'admin-1';
    return this.db.createStream({
      ...dto,
      authorId,
    });
  }

  updateStreamCustomizations(
    streamId: string,
    userId: string,
    data: { liveTheme?: string; pinnedNotice?: string; videoFilter?: string },
  ) {
    return this.db.updateStreamCustomizations(streamId, userId, data);
  }

  toggleStreamLike(streamId: string, userId: string) {
    return this.db.toggleStreamLike(streamId, userId);
  }

  search(query: string, currentUserId?: string) {
    const q = (query || '').trim();
    const posts = this.db.getPosts({ searchQuery: q }).map((p) => this.toPostItem(p, currentUserId));
    const spaces = this.getSpaces().filter((s) => s.name.toLowerCase().includes(q.toLowerCase()));
    const users = this.db.searchUsers(q, currentUserId);
    return { posts, spaces, users };
  }

  private toPostItem(p: PostEntity, currentUserId?: string): PostItem {
    const authorUser = this.db.findUserById(p.authorId);
    const authorCounts = this.db.getFollowCounts(p.authorId);
    const isFollowing = currentUserId ? this.db.isFollowing(currentUserId, p.authorId) : false;

    const author: Author = {
      id: authorUser?.id || p.authorId,
      name: authorUser?.name || 'អ្នកប្រើប្រាស់',
      username: authorUser?.username || 'user',
      avatar: authorUser?.avatar || '/default_avatar.svg',
      isVerified: authorUser?.isVerified || false,
      role: authorUser?.role || 'USER',
      location: authorUser?.location || p.city || 'Phnom Penh, Cambodia',
      bio: authorUser?.bio || '',
      followerCount: authorCounts.followersCount,
      followingCount: authorCounts.followingCount,
      isFollowing,
    };

    const spaceRef = this.spaces.find((s) => s.id === p.spaceId) || this.spaces[0];
    const reactions = this.db.getReactionCounts(p.id);
    const likeCount = (Object.values(reactions) as number[]).reduce((a: number, b: number) => a + b, 0);
    const userReaction = currentUserId ? this.db.getUserReaction(p.id, currentUserId) : undefined;
    const isBookmarked = currentUserId ? this.db.isPostSaved(p.id, currentUserId) : false;

    const rawComments = this.db.getCommentsByPostId(p.id);
    const comments = rawComments.map((c) => {
      const cAuthor = this.db.findUserById(c.authorId);
      return {
        id: c.id,
        author: cAuthor?.name || 'អ្នកប្រើប្រាស់',
        avatar: cAuthor?.avatar || '/default_avatar.svg',
        text: c.text,
        timeAgo: this.formatTimeAgo(c.createdAt),
        authorId: c.authorId,
        parentId: c.parentId,
        replyToAuthor: c.replyToAuthor,
      };
    });

    return {
      id: p.id,
      author,
      space: {
        id: spaceRef.id,
        name: spaceRef.name,
        mode: spaceRef.mode,
        color: spaceRef.color,
        icon: spaceRef.icon,
      },
      circle: p.circleName,
      city: p.city || 'Phnom Penh',
      content: p.content,
      imageUrl: p.imageUrl,
      videoUrl: p.videoUrl,
      isReel: p.isReel || false,
      reelAudioTitle: p.reelAudioTitle,
      templateStyle: p.templateStyle,
      moodTag: p.moodTag,
      aspectRatio: 1.33,
      timeAgo: this.formatTimeAgo(p.createdAt),
      likeCount,
      commentCount: comments.length,
      shareCount: 0,
      isLiked: !!userReaction,
      selectedReaction: userReaction,
      isBookmarked,
      tags: p.tags || [],
      comments,
    };
  }
}
