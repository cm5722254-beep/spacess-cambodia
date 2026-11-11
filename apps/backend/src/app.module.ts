import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DbModule } from './modules/database/db.module';
import { PrismaModule } from './modules/prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { FeedModule } from './modules/feed/feed.module';
import { AuthModule } from './modules/auth/auth.module';
import { MarketplaceModule } from './modules/marketplace/marketplace.module';
import { StorageModule } from './modules/storage/storage.module';
import { AiModule } from './modules/ai/ai.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', '../../.env'],
    }),
    DbModule,
    PrismaModule,
    HealthModule,
    FeedModule,
    AuthModule,
    MarketplaceModule,
    StorageModule,
    AiModule,
  ],
})
export class AppModule {}

