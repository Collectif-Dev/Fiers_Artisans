import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SubscriptionService } from './subscription.service';
import { SubscriptionController } from './subscription.controller';
import { Subscription } from './entities/subscription.entity';
import { Payment } from './entities/payment.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { User } from '../users/entities/user.entity';
import { WaveProvider } from './providers/wave.provider';
import { AnalyticsModule } from '../analytics/analytics.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Subscription, Payment, ArtisanProfile, User]),
    AnalyticsModule,
    NotificationsModule,
  ],
  controllers: [SubscriptionController],
  providers: [SubscriptionService, WaveProvider],
  exports: [SubscriptionService],
})
export class SubscriptionModule {}
