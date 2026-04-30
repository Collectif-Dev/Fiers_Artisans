import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PaymentManual } from './entities/payment-manual.entity';
import { PaymentProof } from './entities/payment-proof.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { User } from '../users/entities/user.entity';
import { Subscription } from '../subscription/entities/subscription.entity';
import { PaymentManualController } from './controllers/payment-manual.controller';
import { PaymentManualAdminController } from './controllers/payment-manual-admin.controller';
import { PaymentManualService } from './services/payment-manual.service';
import { ProofValidationService } from './services/proof-validation.service';
import { ExifExtractorService } from './services/exif-extractor.service';
import { FraudDetectionService } from './services/fraud-detection.service';
import { PaymentExpirationCron } from './cron/payment-expiration.cron';
import { PaymentRealtimeService } from './events/payment-realtime.service';
import { MediaModule } from '../media/media.module';
import { SubscriptionModule } from '../subscription/subscription.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AnalyticsModule } from '../analytics/analytics.module';
import { ChatModule } from '../chat/chat.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PaymentManual,
      PaymentProof,
      ArtisanProfile,
      User,
      Subscription,
    ]),
    MediaModule,
    SubscriptionModule,
    NotificationsModule,
    AnalyticsModule,
    ChatModule,
  ],
  controllers: [PaymentManualController, PaymentManualAdminController],
  providers: [
    PaymentManualService,
    ProofValidationService,
    ExifExtractorService,
    FraudDetectionService,
    PaymentExpirationCron,
    PaymentRealtimeService,
  ],
  exports: [PaymentManualService],
})
export class PaymentManualModule {}
