import { IsOptional, IsString, Matches, IsISO8601 } from 'class-validator';

const IVOIRIAN_PHONE_10_DIGITS = /^\d{10}$/;

export class SubmitProofDto {
  @IsString()
  @Matches(IVOIRIAN_PHONE_10_DIGITS, {
    message: 'Le numero expediteur doit contenir exactement 10 chiffres.',
  })
  sender_number: string;

  @IsOptional()
  @IsISO8601()
  declared_payment_time?: string;
}
