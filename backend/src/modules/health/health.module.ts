import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { MetricsController } from './metrics.controller';
import { MetricsService } from './metrics.service';
import { MediaModule } from '../media/media.module';
import { PaymentMinioIndicator } from './indicators/payment-minio.indicator';
import { AnalyticsModule } from '../analytics/analytics.module';

@Module({
  imports: [MediaModule, AnalyticsModule],
  controllers: [HealthController, MetricsController],
  providers: [MetricsService, PaymentMinioIndicator],
})
export class HealthModule {}
