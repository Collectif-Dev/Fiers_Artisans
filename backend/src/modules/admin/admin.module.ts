import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { User } from '../users/entities/user.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { ClientProfile } from '../users/entities/client-profile.entity';
import { Subscription } from '../subscription/entities/subscription.entity';
import { Payment } from '../subscription/entities/payment.entity';
import { Review } from '../reviews/entities/review.entity';
import { PaymentManual } from '../payment-manual/entities/payment-manual.entity';
import { VerificationModule } from '../verification/verification.module';
import { AnalyticsModule } from '../analytics/analytics.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      ArtisanProfile,
      ClientProfile,
      Subscription,
      Payment,
      Review,
      PaymentManual,
    ]),
    VerificationModule,
    AnalyticsModule,
    NotificationsModule,
  ],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
