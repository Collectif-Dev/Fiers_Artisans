import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { PaymentMinioIndicator } from './indicators/payment-minio.indicator';

@Controller('health')
export class HealthController {
  constructor(private readonly paymentMinioIndicator: PaymentMinioIndicator) {}

  @Get()
  @SkipThrottle()
  async check() {
    const paymentProofsBucket = await this.paymentMinioIndicator
      .check()
      .catch(() => ({ bucket: 'payment-proofs', exists: false }));

    return {
      status: 'ok',
      service: 'Fiers Artisans API',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      storage: {
        paymentProofsBucket,
      },
    };
  }
}
