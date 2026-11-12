import { Body, Controller, ForbiddenException, Get, Headers, Post } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { PrismaService } from '../prisma/prisma.service';
import { DbService } from '../database/db.service';
import { StorageService } from '../storage/storage.service';
import Redis from 'ioredis';

@ApiTags('System Health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly db: DbService,
    private readonly storage: StorageService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Check health status of backend and infrastructure services' })
  @ApiResponse({ status: 200, description: 'Service is healthy' })
  async checkHealth() {
    const instanceMode = process.env.INSTANCE_MODE || 'mixed';
    let dbStatus = 'json_store_ready';
    let redisStatus = 'skipped';

    // 1. Check PostgreSQL via Prisma only if DATABASE_URL looks configured
    if (process.env.DATABASE_URL && !process.env.DATABASE_URL.includes('localhost')) {
      try {
        await this.prisma.$queryRaw`SELECT 1`;
        dbStatus = 'connected';
      } catch {
        dbStatus = 'unreachable';
      }
    }

    // 2. Check Redis only if REDIS_HOST is configured remotely
    if (process.env.REDIS_HOST && process.env.REDIS_HOST !== 'localhost') {
      try {
        const redis = new Redis({
          host: process.env.REDIS_HOST,
          port: Number(process.env.REDIS_PORT) || 6379,
          password: process.env.REDIS_PASSWORD || undefined,
          connectTimeout: 1000,
          lazyConnect: true,
          maxRetriesPerRequest: 0,
          retryStrategy: () => null,
        });
        redis.on('error', () => {
          // Suppress unhandled error log when Redis is disconnected
        });
        await redis.connect();
        const pong = await redis.ping();
        if (pong === 'PONG') {
          redisStatus = 'connected';
        }
        await redis.quit();
      } catch {
        redisStatus = 'unreachable';
      }
    }

    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptimeSeconds: Math.floor(process.uptime()),
      instanceMode,
      services: {
        database: dbStatus,
        redis: redisStatus,
      },
      stats: this.db.getStats(),
      version: '1.0.0',
    };
  }

  @Post('bootstrap-sync')
  async bootstrapSync(
    @Headers('x-admin-sync-secret') secret: string,
    @Body() body: { state?: any; files?: Array<{ filename: string; base64: string }> },
  ) {
    const expected = (process.env.ADMIN_SYNC_SECRET || '').trim();
    if (!expected || secret !== expected) {
      throw new ForbiddenException('Invalid or missing sync secret');
    }

    let syncedFiles = 0;
    if (Array.isArray(body.files)) {
      for (const file of body.files) {
        if (file?.filename && file?.base64) {
          await this.storage.saveNamedLocalFile(
            file.filename,
            Buffer.from(file.base64, 'base64'),
          );
          syncedFiles++;
        }
      }
    }

    const stats = body.state ? this.db.importState(body.state) : this.db.getStats();
    return {
      success: true,
      syncedFiles,
      stats,
    };
  }
}

