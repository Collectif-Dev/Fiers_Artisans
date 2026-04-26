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
import { Type } from 'class-transformer';

const PIN_REGEX = /^\d{5}$/;

export class RegisterArtisanDto {
  @IsString()
  phone_number: string;

  @IsString()
  @Matches(PIN_REGEX, { message: 'Le code PIN doit contenir exactement 5 chiffres.' })
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
  @IsString()
  whatsapp_number?: string;

  @IsOptional()
  @IsEmail()
  email?: string;
}

export class RegisterClientDto {
  @IsString()
  phone_number: string;

  @IsString()
  @Matches(PIN_REGEX, { message: 'Le code PIN doit contenir exactement 5 chiffres.' })
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
  @IsString()
  phone_number: string;
}

export class VerifyOtpDto {
  @IsString()
  phone_number: string;

  @IsString()
  code: string;
}

export class LoginDto {
  @IsString()
  phone_number: string;

  @IsString()
  @Matches(PIN_REGEX, { message: 'Le code PIN doit contenir exactement 5 chiffres.' })
  pin_code: string;
}

export class SetupPinDto {
  @IsString()
  phone_number: string;

  @IsString()
  code: string;

  @IsString()
  @Matches(PIN_REGEX, { message: 'Le code PIN doit contenir exactement 5 chiffres.' })
  pin_code: string;
}

export class RefreshTokenDto {
  @IsString()
  refresh_token: string;
}
