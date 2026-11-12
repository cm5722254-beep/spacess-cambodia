import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  Headers,
  ForbiddenException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { FeedService } from './feed.service';

@ApiTags('Spaces & Social Feed')
@Controller()
export class FeedController {
  constructor(private readonly feedService: FeedService) {}

  private resolveActingUserId(authHeader?: string, fallbackId?: string): string {
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const decoded = JSON.parse(
          Buffer.from(authHeader.replace('Bearer ', ''), 'base64').toString('utf8'),
        );
        if (decoded && decoded.userId) return decoded.userId;
      } catch (e) {}
    }
    return (fallbackId || '').trim();
  }

  @Get('stories')
  @ApiOperation({ summary: 'Get active 24h stories' })
  getStories() {
    return this.feedService.getStories();
  }

  @Get('stories/archive')
  @ApiOperation({ summary: 'Get user story history including 24h expired archive' })
  getStoryArchive(
    @Headers('authorization') authHeader?: string,
    @Query('userId') userId?: string,
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) {
      return [];
    }
    return this.feedService.getStoryArchive(actingUserId);
  }

  @Post('stories')
  @ApiOperation({ summary: 'Create a new story (24h active lifespan)' })
  createStory(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      authorId?: string;
      imageUrl: string;
      caption?: string;
    },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.authorId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.createStory(actingUserId, body.imageUrl, body.caption);
  }

  @Get('reels')
  @ApiOperation({ summary: 'Get video reels' })
  getReels(@Query('currentUserId') currentUserId?: string) {
    return this.feedService.getReels(currentUserId);
  }

  @Post('reels')
  @ApiOperation({ summary: 'Post a new video reel' })
  createReel(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
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
    },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.authorId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.createReel({ ...body, authorId: actingUserId });
  }

  @Get('streams')
  @ApiOperation({ summary: 'Get live video streams and long videos (Watch / Stream)' })
  getStreams(
    @Query('category') category?: string,
    @Query('authorId') authorId?: string,
    @Query('currentUserId') currentUserId?: string,
  ) {
    return this.feedService.getStreams({ category, authorId, currentUserId });
  }

  @Post('streams')
  @ApiOperation({ summary: 'Publish a new long video or start a stream' })
  createStream(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
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
    },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.authorId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.createStream({ ...body, authorId: actingUserId });
  }

  @Patch('streams/:id/customize')
  @ApiOperation({ summary: 'Customize live theme, pinned banner, or video filter' })
  customizeStream(
    @Param('id') streamId: string,
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      userId?: string;
      liveTheme?: string;
      pinnedNotice?: string;
      videoFilter?: string;
    },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.userId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    const updated = this.feedService.updateStreamCustomizations(streamId, actingUserId, body);
    if (!updated) {
      throw new ForbiddenException('Not authorized to customize this stream');
    }
    return { success: true, stream: updated };
  }

  @Post('streams/:id/like')
  @ApiOperation({ summary: 'Toggle like on a video stream' })
  toggleStreamLike(
    @Param('id') streamId: string,
    @Body() body: { userId: string },
  ) {
    return this.feedService.toggleStreamLike(streamId, body.userId);
  }

  @Get('feed')
  @ApiOperation({ summary: 'Get live social feed filtered by space, city, author, or saved posts' })
  @ApiQuery({ name: 'spaceId', required: false })
  @ApiQuery({ name: 'city', required: false })
  @ApiQuery({ name: 'authorId', required: false })
  @ApiQuery({ name: 'savedByUserId', required: false })
  @ApiQuery({ name: 'currentUserId', required: false })
  getFeed(
    @Query('spaceId') spaceId?: string,
    @Query('city') city?: string,
    @Query('authorId') authorId?: string,
    @Query('savedByUserId') savedByUserId?: string,
    @Query('currentUserId') currentUserId?: string,
  ) {
    return this.feedService.getFeed({ spaceId, city, authorId, savedByUserId, currentUserId });
  }

  @Get('spaces')
  @ApiOperation({ summary: 'List all active Spaces (Family, Team, Public)' })
  getSpaces() {
    return this.feedService.getSpaces();
  }

  @Post('posts')
  @ApiOperation({ summary: 'Create a new post in a Space with audience circle, template, and city' })
  createPost(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      authorId?: string;
      content: string;
      spaceId: string;
      city?: string;
      circleName?: string;
      imageUrl?: string;
      tags?: string[];
      templateStyle?: string;
      moodTag?: string;
    },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.authorId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.createPost({ ...body, authorId: actingUserId });
  }

  @Patch('posts/:id')
  @ApiOperation({ summary: 'Update an existing post (Author or Admin only)' })
  updatePost(
    @Param('id') postId: string,
    @Headers('authorization') authHeader: string,
    @Body() body: { userId?: string; content?: string; city?: string; imageUrl?: string },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.userId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    const updated = this.feedService.updatePost(postId, actingUserId, body);
    if (!updated) {
      throw new ForbiddenException('Not allowed to edit this post');
    }
    return updated;
  }

  @Delete('posts/:id')
  @ApiOperation({ summary: 'Delete a post (Author or Admin only)' })
  deletePost(
    @Param('id') postId: string,
    @Headers('authorization') authHeader?: string,
    @Query('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    const success = this.feedService.deletePost(postId, actingUserId);
    if (!success) {
      throw new ForbiddenException('Not allowed to delete this post');
    }
    return { success };
  }

  @Post('posts/:id/react')
  @ApiOperation({ summary: 'Toggle reaction on a post (LIKE, LOVE, HAHA, WOW, SAD)' })
  toggleReaction(
    @Param('id') postId: string,
    @Headers('authorization') authHeader: string,
    @Body('reaction') reactionType: string = 'LIKE',
    @Body('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.toggleReaction(postId, actingUserId, reactionType);
  }

  @Post('posts/:id/comment')
  @ApiOperation({ summary: 'Add a comment or nested reply to a post' })
  addComment(
    @Param('id') postId: string,
    @Headers('authorization') authHeader: string,
    @Body('text') text: string,
    @Body('authorId') authorId: string = '',
    @Body('parentId') parentId?: string,
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, authorId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.addComment(postId, actingUserId, text, parentId);
  }

  @Delete('stories/:id')
  @ApiOperation({ summary: 'Delete a story (Author or Admin only)' })
  deleteStory(
    @Param('id') storyId: string,
    @Headers('authorization') authHeader?: string,
    @Query('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    const success = this.feedService.deleteStory(storyId, actingUserId);
    if (!success) {
      throw new ForbiddenException('Not allowed to delete this story');
    }
    return { success };
  }

  @Delete('streams/:id')
  @ApiOperation({ summary: 'Delete a video stream (Author or Admin only)' })
  deleteStream(
    @Param('id') streamId: string,
    @Headers('authorization') authHeader?: string,
    @Query('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    const success = this.feedService.deleteStream(streamId, actingUserId);
    if (!success) {
      throw new ForbiddenException('Not allowed to delete this stream');
    }
    return { success };
  }

  @Post('posts/batch-delete')
  @ApiOperation({ summary: 'Admin: Delete multiple selected posts or reels' })
  deletePostsBatch(
    @Headers('authorization') authHeader: string,
    @Body() body: { postIds: string[]; userId?: string },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.userId);
    if (!actingUserId) {
      throw new ForbiddenException('Admin authentication required');
    }
    const deletedCount = this.feedService.deletePostsBatch(body.postIds || [], actingUserId);
    return { success: true, deletedCount };
  }

  @Delete('posts/:id/comments/:commentId')
  @ApiOperation({ summary: 'Delete a comment from a post (Author or Admin only)' })
  deleteComment(
    @Param('commentId') commentId: string,
    @Headers('authorization') authHeader?: string,
    @Query('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    const success = this.feedService.deleteComment(commentId, actingUserId);
    if (!success) {
      throw new ForbiddenException('Not allowed to delete this comment');
    }
    return { success };
  }

  @Post('posts/:id/save')
  @ApiOperation({ summary: 'Toggle save / bookmark a post' })
  toggleSavePost(
    @Param('id') postId: string,
    @Headers('authorization') authHeader: string,
    @Body('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    const isSaved = this.feedService.toggleSavePost(postId, actingUserId);
    return { success: true, isSaved };
  }

  // --- FRIENDS (ADD FRIEND / CONFIRM) ---
  @Get('friends')
  @ApiOperation({ summary: 'Get friends list and pending friend requests' })
  getFriends(@Query('userId') userId: string) {
    return this.feedService.getFriendsOverview(userId);
  }

  @Post('friends/request')
  @ApiOperation({ summary: 'Send a friend request' })
  sendFriendRequest(@Body() body: { requesterId: string; receiverId: string }) {
    return this.feedService.sendFriendRequest(body.requesterId, body.receiverId);
  }

  @Post('friends/respond')
  @ApiOperation({ summary: 'Accept (Confirm) or decline a friend request' })
  respondFriendRequest(@Body() body: { requestId: string; userId: string; accept: boolean }) {
    return this.feedService.respondFriendRequest(body.requestId, body.userId, body.accept);
  }

  @Post('friends/remove')
  @ApiOperation({ summary: 'Unfriend / cancel friend request' })
  removeFriend(@Body() body: { userId1: string; userId2: string }) {
    return this.feedService.removeFriend(body.userId1, body.userId2);
  }

  // --- MESSENGER & CHATS ---
  @Get('chats')
  @ApiOperation({ summary: 'List all chat conversations' })
  getChats(
    @Headers('authorization') authHeader: string,
    @Query('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) return [];
    return this.feedService.getChats(actingUserId);
  }

  @Post('chats/direct')
  @ApiOperation({ summary: 'Get or create a direct 1-on-1 chat conversation' })
  getOrCreateDirectChat(@Body() body: { userId1: string; userId2: string }) {
    return this.feedService.getOrCreateDirectChat(body.userId1, body.userId2);
  }

  @Get('chats/:id/messages')
  @ApiOperation({ summary: 'Get messages for a chat conversation' })
  getMessages(
    @Param('id') chatId: string,
    @Query('currentUserId') currentUserId?: string,
  ) {
    return this.feedService.getMessages(chatId, currentUserId);
  }

  @Post('chats/:id/messages')
  @ApiOperation({ summary: 'Send text, photo, video, or voice message in a chat' })
  sendMessage(
    @Param('id') chatId: string,
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      text?: string;
      senderId?: string;
      mediaUrl?: string;
      mediaType?: 'text' | 'image' | 'video' | 'voice';
      durationSec?: number;
    },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.senderId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.sendMessage(
      chatId,
      actingUserId,
      body.text || '',
      body.mediaUrl,
      body.mediaType || 'text',
      body.durationSec,
    );
  }

  // --- SAFETY: REPORT & BLOCK ---
  @Post('reports')
  @ApiOperation({ summary: 'Submit a report against a post or user' })
  createReport(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      reporterId?: string;
      targetType: 'POST' | 'USER';
      targetId: string;
      reason: string;
    },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body.reporterId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.createReport(
      actingUserId,
      body.targetType || 'POST',
      body.targetId,
      body.reason || 'Inappropriate content',
    );
  }

  @Post('users/:id/block')
  @ApiOperation({ summary: 'Block or unblock a user' })
  toggleBlockUser(
    @Param('id') targetUserId: string,
    @Headers('authorization') authHeader: string,
    @Body() body: { blockerId?: string },
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, body?.blockerId);
    if (!actingUserId) {
      throw new ForbiddenException('Authentication required');
    }
    return this.feedService.toggleBlockUser(actingUserId, targetUserId);
  }

  @Get('users/blocked')
  @ApiOperation({ summary: 'Get list of users blocked by the current user' })
  getBlockedUsers(
    @Headers('authorization') authHeader: string,
    @Query('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) return [];
    return this.feedService.getBlockedUsers(actingUserId);
  }

  @Get('notifications')
  @ApiOperation({ summary: 'Get persistent notification history for user' })
  getNotifications(
    @Headers('authorization') authHeader: string,
    @Query('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    if (!actingUserId) return [];
    return this.feedService.getNotifications(actingUserId);
  }

  @Patch('notifications/:id/read')
  @ApiOperation({ summary: 'Mark a notification as read' })
  markNotificationRead(
    @Param('id') id: string,
    @Headers('authorization') authHeader: string,
    @Query('userId') userId: string = '',
  ) {
    const actingUserId = this.resolveActingUserId(authHeader, userId);
    return this.feedService.markNotificationRead(id, actingUserId || undefined);
  }

  @Get('search')
  @ApiOperation({ summary: 'Search posts, spaces, hashtags, and members' })
  @ApiQuery({ name: 'q', required: false })
  search(@Query('q') query: string = '', @Query('currentUserId') currentUserId?: string) {
    return this.feedService.search(query, currentUserId);
  }
}
