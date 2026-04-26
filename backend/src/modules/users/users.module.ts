import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { UsersService } from './users.service';
import { UsersController, PublicArtisanController } from './users.controller';
import { User } from './entities/user.entity';
import { ArtisanProfile } from './entities/artisan-profile.entity';
import { ClientProfile } from './entities/client-profile.entity';
import { FavoriteArtisan } from './entities/favorite-artisan.entity';
import { Subcategory } from '../categories/entities/subcategory.entity';
import { AnalyticsModule } from '../analytics/analytics.module';
import { ChatModule } from '../chat/chat.module';
import { MapVisibilityGateway } from './map-visibility.gateway';

@Module({
  imports: [
    JwtModule.register({}),
    TypeOrmModule.forFeature([
      User,
      ArtisanProfile,
      ClientProfile,
      FavoriteArtisan,
      Subcategory,
    ]),
    AnalyticsModule,
    ChatModule,
  ],
  controllers: [UsersController, PublicArtisanController],
  providers: [UsersService, MapVisibilityGateway],
  exports: [UsersService, MapVisibilityGateway],
})
export class UsersModule {}
