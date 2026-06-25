import {
  Injectable,
  Logger,
  BadRequestException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { randomInt } from 'crypto';
import Redis from 'ioredis';
import { ConfigService } from '@nestjs/config';
import { WhatsappOtpProvider } from './whatsapp-otp.provider';
import {
  isLocalPhoneNumber,
  LOCAL_PHONE_NUMBER_MESSAGE,
  normalizeLocalPhoneNumber,
} from '../../../common/utils/phone-number.util';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly redis: Redis;
  private readonly OTP_TTL: number;
  private readonly MAX_ATTEMPTS: number;
  private readonly MAX_SENDS_PER_HOUR: number;
  private readonly BLOCK_DURATION: number;

  constructor(
    private readonly configService: ConfigService,
    private readonly whatsappOtpProvider: WhatsappOtpProvider,
  ) {
    this.redis = new Redis({
      host: this.configService.get<string>('redis.host'),
      port: this.configService.get<number>('redis.port'),
      password: this.configService.get<string>('redis.password'),
    });
    this.OTP_TTL = parseInt(process.env.OTP_TTL_SECONDS || '300', 10);
    this.MAX_ATTEMPTS = parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10);
    this.MAX_SENDS_PER_HOUR = parseInt(
      process.env.OTP_MAX_SENDS_PER_HOUR || '3',
      10,
    );
    this.BLOCK_DURATION = parseInt(
      process.env.OTP_BLOCK_DURATION_SECONDS || '900',
      10,
    );
  }

  async sendOtp(
    phoneNumber: string,
  ): Promise<{ sent: boolean; message: string }> {
    const normalizedPhoneNumber = this.normalizePhoneNumber(phoneNumber);

    // Vérifier le blocage anti-brute-force
    const blockKey = this.blockKey(normalizedPhoneNumber);
    const isBlocked = await this.redis.exists(blockKey);
    if (isBlocked) {
      throw new HttpException(
        'Trop de tentatives. Veuillez réessayer dans 15 minutes.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // Vérifier le nombre d'envois par heure
    const sendCount = await this.incrementWithTtl(
      this.sendCountKey(normalizedPhoneNumber),
      3600,
    );
    if (sendCount > this.MAX_SENDS_PER_HOUR) {
      throw new HttpException(
        "Nombre maximum d'envois atteint. Veuillez réessayer dans 1 heure.",
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // Générer le code OTP à 6 chiffres
    const code = randomInt(100000, 1000000).toString();

    // Stocker dans Redis avec TTL
    const otpKey = this.otpKey(normalizedPhoneNumber);
    await this.redis.set(otpKey, code, 'EX', this.OTP_TTL);
    await this.redis.del(this.attemptKey(normalizedPhoneNumber));

    // Cascade de providers : WhatsApp → SMS (fallback) → Notification
    let sent = await this.whatsappOtpProvider.sendOtp(
      normalizedPhoneNumber,
      code,
    );

    if (!sent) {
      // Fallback SMS (si configuré)
      const smsEnabled =
        this.configService.get<string>('SMS_PROVIDER_ENABLED') === 'true';
      if (smsEnabled) {
        this.logger.log('WhatsApp failed, trying SMS fallback...');
        // TODO: Implémenter SMS Twilio provider
        sent = false;
      }
    }

    if (!sent) {
      // Aucun provider disponible — message gracieux (non bloquant)
      this.logger.warn(
        `No OTP provider available for ${normalizedPhoneNumber}`,
      );

      // En mode développement, log le code pour faciliter les tests
      if (this.configService.get('app.nodeEnv') === 'development') {
        this.logger.debug(
          `[DEV] OTP code for ${normalizedPhoneNumber}: ${code}`,
        );
        return {
          sent: true,
          message:
            "Code envoyé. Consultez l'inspecteur OTP dev pour obtenir le code.",
        };
      }

      return {
        sent: false,
        message:
          "Service d'envoi de code actuellement indisponible. Veuillez réessayer dans quelques instants.",
      };
    }

    return {
      sent: true,
      message: 'Code envoyé via WhatsApp.',
    };
  }

  async verifyOtp(phoneNumber: string, code: string): Promise<boolean> {
    const normalizedPhoneNumber = this.normalizePhoneNumber(phoneNumber);
    const normalizedCode = code.trim();
    const otpKey = this.otpKey(normalizedPhoneNumber);
    const attemptKey = this.attemptKey(normalizedPhoneNumber);
    const blockKey = this.blockKey(normalizedPhoneNumber);

    const isBlocked = await this.redis.exists(blockKey);
    if (isBlocked) {
      throw new HttpException(
        'Trop de tentatives échouées. Compte bloqué pour 15 minutes.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const data = await this.redis.get(otpKey);
    if (!data) {
      throw new BadRequestException('Code expiré ou non envoyé.');
    }

    if (this.extractOtpCode(data) !== normalizedCode) {
      const ttl = await this.redis.ttl(otpKey);
      if (ttl <= 0) {
        await this.redis.del(otpKey);
        await this.redis.del(attemptKey);
        throw new BadRequestException('Code expiré ou non envoyé.');
      }

      const attempts = await this.incrementWithTtl(attemptKey, ttl);
      if (attempts >= this.MAX_ATTEMPTS) {
        await this.redis.set(blockKey, '1', 'EX', this.BLOCK_DURATION);
        await this.redis.del(otpKey);
        await this.redis.del(attemptKey);
        throw new HttpException(
          'Trop de tentatives échouées. Compte bloqué pour 15 minutes.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      throw new BadRequestException('Code incorrect.');
    }

    // Code valide — supprimer de Redis
    await this.redis.del(otpKey);
    await this.redis.del(attemptKey);
    return true;
  }

  private otpKey(phoneNumber: string): string {
    return `otp:${phoneNumber}`;
  }

  private attemptKey(phoneNumber: string): string {
    return `otp:attempts:${phoneNumber}`;
  }

  private blockKey(phoneNumber: string): string {
    return `otp:block:${phoneNumber}`;
  }

  private sendCountKey(phoneNumber: string): string {
    return `otp:sends:${phoneNumber}`;
  }

  private normalizePhoneNumber(phoneNumber: string): string {
    const normalized = normalizeLocalPhoneNumber(phoneNumber);
    if (!isLocalPhoneNumber(normalized)) {
      throw new BadRequestException(LOCAL_PHONE_NUMBER_MESSAGE);
    }
    return normalized;
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

  private async incrementWithTtl(
    key: string,
    ttlSeconds: number,
  ): Promise<number> {
    const result = await this.redis.eval(
      `
local count = redis.call("INCR", KEYS[1])
local ttl = redis.call("TTL", KEYS[1])
if ttl < 0 then
  redis.call("EXPIRE", KEYS[1], tonumber(ARGV[1]))
end
return count
      `,
      1,
      key,
      ttlSeconds,
    );

    return Number(result);
  }
}
