import { Controller, Get, Query, Req, Res } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { EventsService } from './events.service';

@ApiTags('Real-Time Events')
@Controller('events')
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Get('stream')
  @ApiOperation({ summary: 'Subscribe to real-time SSE notifications, chat messages, and order updates' })
  stream(
    @Query('userId') userId: string = '',
    @Req() req: Request,
    @Res() res: Response,
  ) {
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders?.();

    const cleanId = userId.trim();
    const hello = JSON.stringify({
      type: 'SYSTEM',
      data: { connected: true, userId: cleanId },
      timestamp: new Date().toISOString(),
    });
    res.write(`data: ${hello}\n\n`);

    const cleanup = this.eventsService.registerClient(cleanId, res);
    req.on('close', () => {
      cleanup();
    });
  }
}

