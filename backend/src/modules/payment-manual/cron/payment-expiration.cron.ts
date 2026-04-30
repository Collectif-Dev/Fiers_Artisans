import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PaymentManualService } from '../services/payment-manual.service';

@Injectable()
export class PaymentExpirationCron {
  private readonly logger = new Logger(PaymentExpirationCron.name);

  constructor(private readonly paymentManualService: PaymentManualService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async expireManualPayments(): Promise<void> {
    const expired = await this.paymentManualService.expirePayments();
    if (expired > 0) {
      this.logger.log(`Manual payments expired: ${expired}`);
    }
  }

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async verifyProofHashes(): Promise<void> {
    const result = await this.paymentManualService.verifyProofHashesIntegrity();
    if (result.mismatches > 0) {
      this.logger.warn(
        `Manual proof hash verification mismatches: ${result.mismatches}/${result.checked}`,
      );
    }
  }
}
