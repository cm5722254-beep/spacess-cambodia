import { Controller, Post, Body, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AiService } from './ai.service';

@ApiTags('AI Assistant & System Diagnostics')
@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('chat')
  @ApiOperation({ summary: 'Chat with Spaces AI Smart Assistant & System Tool' })
  async chat(
    @Body()
    body: {
      message: string;
      history?: { role: string; content: string }[];
    },
  ) {
    if (!body.message || body.message.trim().length === 0) {
      throw new BadRequestException('Message is required');
    }
    const result = await this.aiService.processChat(body.message, body.history);
    return {
      success: true,
      data: result,
      reply: result.reply,
    };
  }
}
