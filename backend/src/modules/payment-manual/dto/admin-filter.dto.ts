import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';
import { PaymentManualStatus } from '../entities/payment-manual.entity';

export class AdminFilterDto {
  @IsOptional()
  @IsIn([
    PaymentManualStatus.PENDING,
    PaymentManualStatus.PENDING_ADMIN,
    PaymentManualStatus.COMPLETED,
    PaymentManualStatus.REJECTED,
    PaymentManualStatus.EXPIRED,
    'REFUND_REQUIRED',
  ])
  status?:
    | PaymentManualStatus
    | 'REFUND_REQUIRED';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;

  @IsOptional()
  @IsString()
  sort?: 'asc' | 'desc';
}
