import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { MetricsController } from './metrics.controller';
import { MetricsService } from './metrics.service';
import { MediaModule } from '../media/media.module';
import { PaymentMinioIndicator } from './indicators/payment-minio.indicator';

@Module({
  imports: [MediaModule],
  controllers: [HealthController, MetricsController],
  providers: [MetricsService, PaymentMinioIndicator],
})
export class HealthModule {}
