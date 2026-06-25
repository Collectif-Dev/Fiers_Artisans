import {
  Controller,
  Get,
  Query,
  ForbiddenException,
  NotFoundException,
  Logger,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import {
  isLocalPhoneNumber,
  LOCAL_PHONE_NUMBER_MESSAGE,
  normalizeLocalPhoneNumber,
} from '../../common/utils/phone-number.util';

/**
 * DEV-ONLY Controller — Inspection OTP via navigateur
 *
 * Disponible uniquement si :
 *   - NODE_ENV=development
 *   - OTP_DEV_INSPECTOR=true (dans .env)
 *
 * Sécurité minimale via clé dev :
 *   - Query param `key` doit correspondre à OTP_DEV_KEY (.env)
 *
 * Usage navigateur :
 *   GET http://localhost:3000/api/v1/dev/otp/latest?phone_number=0703063570&key=fiers_dev_2025
 */
@Controller('dev')
export class DevOtpController {
  private readonly logger = new Logger(DevOtpController.name);
  private readonly redis: Redis;
  private readonly devKey: string;

  constructor(private readonly configService: ConfigService) {
    this.redis = new Redis({
      host: this.configService.get<string>('redis.host'),
      port: this.configService.get<number>('redis.port'),
      password: this.configService.get<string>('redis.password'),
    });
    const key = this.configService.get<string>('OTP_DEV_KEY');
    if (!key) {
      this.logger.error(
        'OTP_DEV_KEY is not set in .env — dev inspector will reject all requests',
      );
    }
    this.devKey = key || '';
  }

  @Get('otp/latest')
  async getLatestOtp(
    @Query('phone_number') phoneNumber: string,
    @Query('key') key: string,
  ) {
    // ── HARDENING: Dev endpoint locked to development only ───────────
    if (process.env.NODE_ENV !== 'development') {
      throw new ForbiddenException(
        'Dev OTP inspector is only available in development environment.',
      );
    }
    // ── FIN HARDENING ──────────────────────────────────────────────

    // Vérifier la clé d'accès dev
    if (!key || key !== this.devKey) {
      throw new ForbiddenException('Clé dev invalide.');
    }

    if (!phoneNumber) {
      throw new NotFoundException('Paramètre phone_number requis.');
    }

    const normalizedPhoneNumber = normalizeLocalPhoneNumber(phoneNumber);
    if (!isLocalPhoneNumber(normalizedPhoneNumber)) {
      throw new BadRequestException(LOCAL_PHONE_NUMBER_MESSAGE);
    }

    const otpKey = `otp:${normalizedPhoneNumber}`;
    const data = await this.redis.get(otpKey);

    if (data) {
      const attempts =
        parseInt(
          (await this.redis.get(`otp:attempts:${normalizedPhoneNumber}`)) ||
            '0',
          10,
        ) || 0;
      const ttl = await this.redis.ttl(otpKey);

      this.logger.debug(`[DEV] OTP inspected for ${normalizedPhoneNumber}`);

      return {
        phone_number: normalizedPhoneNumber,
        code: this.extractOtpCode(data),
        attempts_used: attempts,
        expires_in_seconds: ttl,
        generated_at: new Date(Date.now() - (300 - ttl) * 1000).toISOString(),
      };
    }

    throw new NotFoundException(
      `Aucun OTP trouvé pour ${normalizedPhoneNumber}. Le code a expiré ou n'a pas encore été envoyé.`,
    );
  }

  private extractOtpCode(data: string): string {
    if (!data.startsWith('{')) {
      return data;
    }

    try {
      const parsed = JSON.parse(data) as { code?: unknown };
      return typeof parsed.code === 'string' ? parsed.code : '';
    } catch {
      return '';
    }
  }
}
