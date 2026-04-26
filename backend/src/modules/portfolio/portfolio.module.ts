import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PortfolioService } from './portfolio.service';
import {
  PortfolioController,
  ArtisanPortfolioController,
} from './portfolio.controller';
import {
  PortfolioItem,
  PortfolioItemSchema,
} from './schemas/portfolio-item.schema';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { User } from '../users/entities/user.entity';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: PortfolioItem.name, schema: PortfolioItemSchema },
    ]),
    TypeOrmModule.forFeature([ArtisanProfile, User]),
  ],
  controllers: [PortfolioController, ArtisanPortfolioController],
  providers: [PortfolioService],
})
export class PortfolioModule {}
