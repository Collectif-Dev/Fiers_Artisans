import { IsEnum } from 'class-validator';
import { PaymentProviderManual } from '../entities/payment-manual.entity';

export class CreatePaymentManualDto {
  @IsEnum(PaymentProviderManual)
  provider: PaymentProviderManual;
}
