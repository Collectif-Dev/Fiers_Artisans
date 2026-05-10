import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { PaymentMinioIndicator } from './indicators/payment-minio.indicator';
import { AnalyticsService } from '../analytics/analytics.service';

@Controller('health')
export class HealthController {
  constructor(
    private readonly paymentMinioIndicator: PaymentMinioIndicator,
    private readonly analyticsService: AnalyticsService,
  ) {}

  @Get()
  @SkipThrottle()
  async check() {
    const paymentProofsBucket = await this.paymentMinioIndicator
      .check()
      .catch(() => ({ bucket: 'payment-proofs', exists: false }));
    const activityLogsTtl = await this.analyticsService.getLogRetentionStatus();

    return {
      status: 'ok',
      service: 'Fiers Artisans API',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      storage: {
        paymentProofsBucket,
      },
      analytics: {
        activityLogsTtl,
      },
    };
  }
}
