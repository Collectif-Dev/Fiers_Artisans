import {
  Controller,
  Get,
  Query,
  ForbiddenException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

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
      this.logger.error('OTP_DEV_KEY is not set in .env — dev inspector will reject all requests');
    }
    this.devKey = key || '';
  }

  @Get('otp/latest')
  async getLatestOtp(
    @Query('phone_number') phoneNumber: string,
    @Query('key') key: string,
  ) {
    // Vérifier la clé d'accès dev
    if (!key || key !== this.devKey) {
      throw new ForbiddenException('Clé dev invalide.');
    }

    if (!phoneNumber) {
      throw new NotFoundException('Paramètre phone_number requis.');
    }

    // Chercher dans Redis avec plusieurs variantes du numéro
    const candidates = [
      phoneNumber,
      `+225${phoneNumber}`,
      phoneNumber.replace(/^\+/, ''),
    ];

    for (const candidate of candidates) {
      const otpKey = `otp:${candidate}`;
      const data = await this.redis.get(otpKey);

      if (data) {
        const parsed = JSON.parse(data);
        const ttl = await this.redis.ttl(otpKey);

        this.logger.debug(`[DEV] OTP inspected for ${candidate}`);

        return {
          phone_number: candidate,
          code: parsed.code,
          attempts_used: parsed.attempts,
          expires_in_seconds: ttl,
          generated_at: new Date(Date.now() - (300 - ttl) * 1000).toISOString(),
        };
      }
    }

    throw new NotFoundException(
      `Aucun OTP trouvé pour ${phoneNumber}. Le code a expiré ou n'a pas encore été envoyé.`,
    );
  }
}
