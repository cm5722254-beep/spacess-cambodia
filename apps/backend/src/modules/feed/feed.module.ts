import { Module } from '@nestjs/common';
import { FeedController } from './feed.controller';
import { LiveStreamController } from './live-stream.controller';
import { FeedService } from './feed.service';
import { DbModule } from '../database/db.module';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [DbModule, StorageModule],
  controllers: [FeedController, LiveStreamController],
  providers: [FeedService],
  exports: [FeedService],
})
export class FeedModule {}

