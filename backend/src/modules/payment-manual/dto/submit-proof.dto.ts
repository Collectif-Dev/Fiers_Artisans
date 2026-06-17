import { IsOptional, IsString, Matches, IsISO8601 } from 'class-validator';

const IVOIRIAN_MOBILE_PHONE = /^(07|05|01)\d{8}$/;

export class SubmitProofDto {
  @IsString()
  @Matches(IVOIRIAN_MOBILE_PHONE, {
    message:
      'Le numero expediteur doit etre un mobile ivoirien valide (07, 05 ou 01 + 8 chiffres).',
  })
  sender_number: string;

  @IsOptional()
  @IsISO8601()
  declared_payment_time?: string;
}
