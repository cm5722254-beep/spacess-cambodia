import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  NotFoundException,
  Param,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { DbService } from '../database/db.service';
import { StorageService } from '../storage/storage.service';

interface UploadedChunkFile {
  buffer: Buffer;
  mimetype?: string;
  originalname?: string;
}

@ApiTags('Live Streams')
@Controller('streams')
export class LiveStreamController {
  private readonly activeViewers = new Map<string, Map<string, number>>();

  constructor(
    private readonly db: DbService,
    private readonly storage: StorageService,
  ) {}

  private pruneAndCountViewers(streamId: string, viewerId?: string): number {
    let room = this.activeViewers.get(streamId);
    if (!room) {
      room = new Map<string, number>();
      this.activeViewers.set(streamId, room);
    }
    const now = Date.now();
    if (viewerId && viewerId.trim().length > 0) {
      room.set(viewerId.trim(), now);
    }
    for (const [id, lastSeen] of room.entries()) {
      if (now - lastSeen > 15000) {
        room.delete(id);
      }
    }
    const count = Math.max(1, room.size);
    this.db.updateStreamViewerCount(streamId, count);
    return count;
  }

  @Post(':id/live-chunk')
  @UseInterceptors(
    FileInterceptor('chunk', {
      limits: { fileSize: 40 * 1024 * 1024 },
    }),
  )
  @ApiOperation({ summary: 'Push a real-time camera video/audio chunk and optional poster frame' })
  async pushLiveChunk(
    @Param('id') streamId: string,
    @UploadedFile() file: UploadedChunkFile | undefined,
    @Body()
    body: {
      chunkBase64?: string;
      posterBase64?: string;
      mimeType?: string;
    },
  ) {
    const stream = this.db.getStreamById(streamId);
    if (!stream) {
      throw new NotFoundException('Live stream not found');
    }

    let chunkUrl = '';
    if (file && file.buffer && file.buffer.length > 0) {
      const mime = (file.mimetype || body.mimeType || 'video/webm').toLowerCase();
      const ext = mime.includes('mp4') ? 'mp4' : 'webm';
      const saved = await this.storage.saveBuffer(
        file.buffer,
        ext,
        mime,
        `live_${streamId}`,
      );
      chunkUrl = saved.url;
    } else if (body.chunkBase64) {
      const saved = await this.storage.saveBase64(body.chunkBase64, `live_${streamId}`);
      chunkUrl = saved.url;
    } else {
      throw new BadRequestException('No live media chunk provided');
    }

    let posterUrl: string | undefined;
    if (body.posterBase64 && body.posterBase64.length > 20) {
      const savedPoster = await this.storage.saveBase64(
        body.posterBase64,
        `liveposter_${streamId}`,
      );
      posterUrl = savedPoster.url;
    }

    const updated = this.db.pushLiveChunk(streamId, chunkUrl, posterUrl);
    const viewerCount = this.pruneAndCountViewers(streamId);

    return {
      success: true,
      streamId,
      seq: updated?.liveChunkSeq || 1,
      chunkUrl,
      posterUrl: updated?.thumbnailUrl,
      viewerCount,
      isLive: updated?.isLive ?? true,
    };
  }

  @Get(':id/live-state')
  @ApiOperation({ summary: 'Poll real-time live stream state, chunks, viewers, and recent comments' })
  getLiveState(
    @Param('id') streamId: string,
    @Query('viewerId') viewerId?: string,
  ) {
    const stream = this.db.getStreamById(streamId);
    if (!stream) {
      throw new NotFoundException('Stream not found');
    }

    const viewerCount = stream.isLive
      ? this.pruneAndCountViewers(streamId, viewerId)
      : 0;

    const rawComments = this.db.getCommentsByPostId(streamId);
    const comments = rawComments.slice(-50).map((c) => {
      const user = this.db.findUserById(c.authorId);
      return {
        id: c.id,
        authorId: c.authorId,
        author: user?.name || 'Spaces User',
        avatar: user?.avatar || '/default_avatar.svg',
        text: c.text,
        parentId: c.parentId,
        replyToAuthor: c.replyToAuthor,
        createdAt: c.createdAt,
      };
    });

    return {
      id: stream.id,
      isLive: stream.isLive,
      seq: stream.liveChunkSeq || 0,
      chunkUrl: stream.liveChunkUrl || stream.videoUrl,
      chunks: stream.liveChunks || [],
      videoUrl: stream.videoUrl,
      posterUrl: stream.thumbnailUrl,
      viewerCount,
      likesCount: stream.likesCount || 0,
      commentsCount: comments.length,
      duration: stream.duration,
      liveTheme: stream.liveTheme || 'ocean',
      pinnedNotice: stream.pinnedNotice || '',
      videoFilter: stream.videoFilter || 'normal',
      comments,
    };
  }

  @Post(':id/end')
  @UseInterceptors(
    FileInterceptor('replay', {
      limits: { fileSize: 250 * 1024 * 1024 },
    }),
  )
  @ApiOperation({ summary: 'End a live stream and optionally store full VOD replay' })
  async endLiveStream(
    @Param('id') streamId: string,
    @UploadedFile() replayFile: UploadedChunkFile | undefined,
    @Body()
    body: {
      videoUrl?: string;
      duration?: string;
      posterBase64?: string;
    },
  ) {
    const existing = this.db.getStreamById(streamId);
    if (!existing) {
      throw new NotFoundException('Stream not found');
    }

    let finalVideoUrl = body.videoUrl;
    if (replayFile && replayFile.buffer && replayFile.buffer.length > 0) {
      const mime = (replayFile.mimetype || 'video/webm').toLowerCase();
      const ext = mime.includes('mp4') ? 'mp4' : 'webm';
      const saved = await this.storage.saveBuffer(
        replayFile.buffer,
        ext,
        mime,
        `vod_${streamId}`,
      );
      finalVideoUrl = saved.url;
    }

    let posterUrl: string | undefined;
    if (body.posterBase64 && body.posterBase64.length > 20) {
      const savedPoster = await this.storage.saveBase64(
        body.posterBase64,
        `vodposter_${streamId}`,
      );
      posterUrl = savedPoster.url;
    }

    this.activeViewers.delete(streamId);
    const updated = this.db.endLiveStream(
      streamId,
      finalVideoUrl,
      body.duration,
      posterUrl,
    );

    return {
      success: true,
      stream: updated,
    };
  }

  @Get(':id/comments')
  @ApiOperation({ summary: 'Get comments for a video or live stream' })
  getStreamComments(@Param('id') streamId: string) {
    const rawComments = this.db.getCommentsByPostId(streamId);
    return rawComments.map((c) => {
      const user = this.db.findUserById(c.authorId);
      return {
        id: c.id,
        authorId: c.authorId,
        author: user?.name || 'Spaces User',
        avatar: user?.avatar || '/default_avatar.svg',
        text: c.text,
        parentId: c.parentId,
        replyToAuthor: c.replyToAuthor,
        createdAt: c.createdAt,
      };
    });
  }

  @Post(':id/comments')
  @ApiOperation({ summary: 'Post a live or replay comment (or reply) on a video stream' })
  addStreamComment(
    @Param('id') streamId: string,
    @Headers('authorization') authHeader: string,
    @Body() body: { authorId?: string; text: string; parentId?: string },
  ) {
    if (!body.text || !body.text.trim()) {
      throw new BadRequestException('Comment text is required');
    }
    let authorId = '';
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const decoded = JSON.parse(
          Buffer.from(authHeader.replace('Bearer ', ''), 'base64').toString('utf8'),
        );
        if (decoded?.userId) authorId = String(decoded.userId);
      } catch {}
    }
    if (!authorId) authorId = (body.authorId || '').trim();
    if (!authorId) {
      throw new ForbiddenException('Authentication required');
    }
    const created = this.db.addComment(streamId, authorId, body.text.trim(), body.parentId);
    this.db.incrementStreamComments(streamId);
    const user = this.db.findUserById(authorId);
    return {
      id: created.id,
      authorId: created.authorId,
      author: user?.name || 'Spaces User',
      avatar: user?.avatar || '/default_avatar.svg',
      text: created.text,
      parentId: created.parentId,
      replyToAuthor: created.replyToAuthor,
      createdAt: created.createdAt,
    };
  }
}

