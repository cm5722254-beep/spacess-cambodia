import { Controller, Get, Post, Patch, Delete, Body, Param, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { FeedService } from './feed.service';

@ApiTags('Spaces & Social Feed')
@Controller()
export class FeedController {
  constructor(private readonly feedService: FeedService) {}

  @Get('stories')
  @ApiOperation({ summary: 'Get active 24h stories' })
  getStories() {
    return this.feedService.getStories();
  }

  @Post('stories')
  @ApiOperation({ summary: 'Create a new story' })
  createStory(
    @Body()
    body: {
      authorId: string;
      imageUrl: string;
      caption?: string;
    },
  ) {
    return this.feedService.createStory(body.authorId, body.imageUrl, body.caption);
  }

  @Get('reels')
  @ApiOperation({ summary: 'Get video reels' })
  getReels(@Query('currentUserId') currentUserId?: string) {
    return this.feedService.getReels(currentUserId);
  }

  @Post('reels')
  @ApiOperation({ summary: 'Post a new video reel' })
  createReel(
    @Body()
    body: {
      authorId?: string;
      videoUrl: string;
      content?: string;
      audioTitle?: string;
    },
  ) {
    return this.feedService.createReel(body);
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
    },
  ) {
    return this.feedService.createStream(body);
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
  @ApiOperation({ summary: 'Create a new post in a Space with audience circle and city' })
  createPost(
    @Body()
    body: {
      authorId?: string;
      content: string;
      spaceId: string;
      city?: string;
      circleName?: string;
      imageUrl?: string;
      tags?: string[];
    },
  ) {
    return this.feedService.createPost(body);
  }

  @Patch('posts/:id')
  @ApiOperation({ summary: 'Update an existing post' })
  updatePost(
    @Param('id') postId: string,
    @Body() body: { userId: string; content?: string; city?: string; imageUrl?: string },
  ) {
    return this.feedService.updatePost(postId, body.userId, body);
  }

  @Delete('posts/:id')
  @ApiOperation({ summary: 'Delete a post' })
  deletePost(
    @Param('id') postId: string,
    @Query('userId') userId: string = 'admin-1',
  ) {
    const success = this.feedService.deletePost(postId, userId);
    return { success };
  }

  @Post('posts/:id/react')
  @ApiOperation({ summary: 'Toggle reaction on a post (LIKE, LOVE, HAHA, WOW, SAD)' })
  toggleReaction(
    @Param('id') postId: string,
    @Body('reaction') reactionType: string = 'LIKE',
    @Body('userId') userId: string = 'admin-1',
  ) {
    return this.feedService.toggleReaction(postId, userId, reactionType);
  }

  @Post('posts/:id/comment')
  @ApiOperation({ summary: 'Add a comment to a post' })
  addComment(
    @Param('id') postId: string,
    @Body('text') text: string,
    @Body('authorId') authorId: string = 'admin-1',
  ) {
    return this.feedService.addComment(postId, authorId, text);
  }

  @Delete('stories/:id')
  @ApiOperation({ summary: 'Delete a story (Author or Admin)' })
  deleteStory(
    @Param('id') storyId: string,
    @Query('userId') userId: string = 'admin-1',
  ) {
    const success = this.feedService.deleteStory(storyId, userId);
    return { success };
  }

  @Delete('streams/:id')
  @ApiOperation({ summary: 'Delete a video stream (Author or Admin)' })
  deleteStream(
    @Param('id') streamId: string,
    @Query('userId') userId: string = 'admin-1',
  ) {
    const success = this.feedService.deleteStream(streamId, userId);
    return { success };
  }

  @Post('posts/batch-delete')
  @ApiOperation({ summary: 'Admin: Delete multiple selected posts or reels' })
  deletePostsBatch(@Body() body: { postIds: string[]; userId?: string }) {
    const deletedCount = this.feedService.deletePostsBatch(body.postIds || [], body.userId || 'admin-1');
    return { success: true, deletedCount };
  }

  @Delete('posts/:id/comments/:commentId')
  @ApiOperation({ summary: 'Delete a comment from a post' })
  deleteComment(
    @Param('commentId') commentId: string,
    @Query('userId') userId: string = 'admin-1',
  ) {
    const success = this.feedService.deleteComment(commentId, userId);
    return { success };
  }

  @Post('posts/:id/save')
  @ApiOperation({ summary: 'Toggle save / bookmark a post' })
  toggleSavePost(
    @Param('id') postId: string,
    @Body('userId') userId: string = 'admin-1',
  ) {
    const isSaved = this.feedService.toggleSavePost(postId, userId);
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
  getChats(@Query('userId') userId: string = 'admin-1') {
    return this.feedService.getChats(userId);
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
    @Body()
    body: {
      text?: string;
      senderId?: string;
      mediaUrl?: string;
      mediaType?: 'text' | 'image' | 'video' | 'voice';
      durationSec?: number;
    },
  ) {
    return this.feedService.sendMessage(
      chatId,
      body.senderId || 'admin-1',
      body.text || '',
      body.mediaUrl,
      body.mediaType || 'text',
      body.durationSec,
    );
  }

  @Get('search')
  @ApiOperation({ summary: 'Search posts, spaces, hashtags, and members' })
  @ApiQuery({ name: 'q', required: false })
  search(@Query('q') query: string = '', @Query('currentUserId') currentUserId?: string) {
    return this.feedService.search(query, currentUserId);
  }
}
