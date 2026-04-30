import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaService } from '../../media/media.service';

@Injectable()
export class PaymentMinioIndicator {
  constructor(
    private readonly mediaService: MediaService,
    private readonly configService: ConfigService,
  ) {}

  async check(): Promise<{ bucket: string; exists: boolean }> {
    const bucket =
      this.configService.get<string>('minio.buckets.paymentProofs') ||
      this.configService.get<string>('MINIO_PAYMENT_PROOF_BUCKET') ||
      'payment-proofs';

    const exists = await this.mediaService.hasBucket(bucket);
    return { bucket, exists };
  }
}
