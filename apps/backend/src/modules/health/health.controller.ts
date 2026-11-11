import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { PrismaService } from '../prisma/prisma.service';
import Redis from 'ioredis';

@ApiTags('System Health')
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @ApiOperation({ summary: 'Check health status of backend and infrastructure services' })
  @ApiResponse({ status: 200, description: 'Service is healthy' })
  async checkHealth() {
    const instanceMode = process.env.INSTANCE_MODE || 'mixed';
    let dbStatus = 'disconnected';
    let redisStatus = 'disconnected';

    // 1. Check PostgreSQL via Prisma
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      dbStatus = 'connected';
    } catch {
      dbStatus = 'unreachable';
    }

    // 2. Check Redis
    try {
      const redis = new Redis({
        host: process.env.REDIS_HOST || 'localhost',
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

    const isHealthy = dbStatus === 'connected' && redisStatus === 'connected';

    return {
      status: isHealthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      uptimeSeconds: Math.floor(process.uptime()),
      instanceMode,
      services: {
        database: dbStatus,
        redis: redisStatus,
      },
      version: '1.0.0',
    };
  }
}

