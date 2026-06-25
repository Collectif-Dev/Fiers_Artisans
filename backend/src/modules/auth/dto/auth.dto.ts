import {
  IsString,
  Matches,
  IsOptional,
  IsEmail,
  IsInt,
  Min,
  Max,
  IsUUID,
  IsNumber,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import {
  LOCAL_PHONE_NUMBER_MESSAGE,
  LOCAL_PHONE_NUMBER_REGEX,
  normalizeLocalPhoneNumber,
} from '../../../common/utils/phone-number.util';

const PIN_REGEX = /^\d{5}$/;
const OTP_REGEX = /^\d{6}$/;

const LocalPhoneNumber = () =>
  Transform(({ value }) => normalizeLocalPhoneNumber(value));

export class RegisterArtisanDto {
  @LocalPhoneNumber()
  @IsString()
  @Matches(LOCAL_PHONE_NUMBER_REGEX, {
    message: LOCAL_PHONE_NUMBER_MESSAGE,
  })
  phone_number: string;

  @IsString()
  @Matches(PIN_REGEX, {
    message: 'Le code PIN doit contenir exactement 5 chiffres.',
  })
  pin_code: string;

  @IsString()
  first_name: string;

  @IsString()
  last_name: string;

  @IsOptional()
  @IsString()
  business_name?: string;

  @IsOptional()
  @IsString()
  bio?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  years_experience?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @IsUUID()
  category_id: string;

  @IsUUID()
  subcategory_id: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  commune?: string;

  @IsOptional()
  @LocalPhoneNumber()
  @IsString()
  @Matches(LOCAL_PHONE_NUMBER_REGEX, {
    message: LOCAL_PHONE_NUMBER_MESSAGE,
  })
  whatsapp_number?: string;

  @IsOptional()
  @IsEmail()
  email?: string;
}

export class RegisterClientDto {
  @LocalPhoneNumber()
  @IsString()
  @Matches(LOCAL_PHONE_NUMBER_REGEX, {
    message: LOCAL_PHONE_NUMBER_MESSAGE,
  })
  phone_number: string;

  @IsString()
  @Matches(PIN_REGEX, {
    message: 'Le code PIN doit contenir exactement 5 chiffres.',
  })
  pin_code: string;

  @IsString()
  first_name: string;

  @IsString()
  last_name: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  commune?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;
}

export class SendOtpDto {
  @LocalPhoneNumber()
  @IsString()
  @Matches(LOCAL_PHONE_NUMBER_REGEX, {
    message: LOCAL_PHONE_NUMBER_MESSAGE,
  })
  phone_number: string;
}

export class VerifyOtpDto {
  @LocalPhoneNumber()
  @IsString()
  @Matches(LOCAL_PHONE_NUMBER_REGEX, {
    message: LOCAL_PHONE_NUMBER_MESSAGE,
  })
  phone_number: string;

  @IsString()
  @Matches(OTP_REGEX, {
    message: 'Le code OTP doit contenir exactement 6 chiffres.',
  })
  code: string;
}

export class LoginDto {
  @LocalPhoneNumber()
  @IsString()
  @Matches(LOCAL_PHONE_NUMBER_REGEX, {
    message: LOCAL_PHONE_NUMBER_MESSAGE,
  })
  phone_number: string;

  @IsString()
  @Matches(PIN_REGEX, {
    message: 'Le code PIN doit contenir exactement 5 chiffres.',
  })
  pin_code: string;
}

export class SetupPinDto {
  @LocalPhoneNumber()
  @IsString()
  @Matches(LOCAL_PHONE_NUMBER_REGEX, {
    message: LOCAL_PHONE_NUMBER_MESSAGE,
  })
  phone_number: string;

  @IsString()
  @Matches(OTP_REGEX, {
    message: 'Le code OTP doit contenir exactement 6 chiffres.',
  })
  code: string;

  @IsString()
  @Matches(PIN_REGEX, {
    message: 'Le code PIN doit contenir exactement 5 chiffres.',
  })
  pin_code: string;
}

export class RefreshTokenDto {
  @IsString()
  refresh_token: string;
}
