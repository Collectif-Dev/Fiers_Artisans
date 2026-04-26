import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SearchService } from './search.service';
import { SearchController } from './search.controller';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { AnalyticsModule } from '../analytics/analytics.module';

@Module({
  imports: [TypeOrmModule.forFeature([ArtisanProfile]), AnalyticsModule],
  controllers: [SearchController],
  providers: [SearchService],
})
export class SearchModule {}
