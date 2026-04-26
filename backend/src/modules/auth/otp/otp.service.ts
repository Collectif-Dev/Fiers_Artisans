import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import Redis from 'ioredis';
import { ConfigService } from '@nestjs/config';
import { WhatsappOtpProvider } from './whatsapp-otp.provider';

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
    this.MAX_SENDS_PER_HOUR = parseInt(process.env.OTP_MAX_SENDS_PER_HOUR || '3', 10);
    this.BLOCK_DURATION = parseInt(process.env.OTP_BLOCK_DURATION_SECONDS || '900', 10);
  }

  async sendOtp(phoneNumber: string): Promise<{ sent: boolean; message: string }> {
    // Vérifier le blocage anti-brute-force
    const blockKey = `otp:block:${phoneNumber}`;
    const isBlocked = await this.redis.exists(blockKey);
    if (isBlocked) {
      throw new BadRequestException(
        'Trop de tentatives. Veuillez réessayer dans 15 minutes.',
      );
    }

    // Vérifier le nombre d'envois par heure
    const sendCountKey = `otp:sends:${phoneNumber}`;
    const sendCount = parseInt(await this.redis.get(sendCountKey) || '0') || 0;
    if (sendCount >= this.MAX_SENDS_PER_HOUR) {
      throw new BadRequestException(
        'Nombre maximum d\'envois atteint. Veuillez réessayer dans 1 heure.',
      );
    }

    // Générer le code OTP à 6 chiffres
    const code = Math.floor(100000 + Math.random() * 900000).toString();

    // Stocker dans Redis avec TTL
    const otpKey = `otp:${phoneNumber}`;
    await this.redis.set(
      otpKey,
      JSON.stringify({ code, attempts: 0 }),
      'EX',
      this.OTP_TTL,
    );

    // Incrémenter le compteur d'envois
    await this.redis.incr(sendCountKey);
    await this.redis.expire(sendCountKey, 3600); // 1 heure

    // Cascade de providers : WhatsApp → SMS (fallback) → Notification
    let sent = await this.whatsappOtpProvider.sendOtp(phoneNumber, code);

    if (!sent) {
      // Fallback SMS (si configuré)
      const smsEnabled = this.configService.get<string>('SMS_PROVIDER_ENABLED') === 'true';
      if (smsEnabled) {
        this.logger.log('WhatsApp failed, trying SMS fallback...');
        // TODO: Implémenter SMS Twilio provider
        sent = false;
      }
    }

    if (!sent) {
      // Aucun provider disponible — message gracieux (non bloquant)
      this.logger.warn(`No OTP provider available for ${phoneNumber}`);

      // En mode développement, log le code pour faciliter les tests
      if (this.configService.get('app.nodeEnv') === 'development') {
        this.logger.debug(`[DEV] OTP code for ${phoneNumber}: ${code}`);
        return {
          sent: true,
          message: 'Code envoyé. Consultez l\'inspecteur OTP dev pour obtenir le code.',
        };
      }

      return {
        sent: false,
        message:
          'Service d\'envoi de code actuellement indisponible. Veuillez réessayer dans quelques instants.',
      };
    }

    return {
      sent: true,
      message: 'Code envoyé via WhatsApp.',
    };
  }

  async verifyOtp(
    phoneNumber: string,
    code: string,
  ): Promise<boolean> {
    const otpKey = `otp:${phoneNumber}`;
    const blockKey = `otp:block:${phoneNumber}`;

    const data = await this.redis.get(otpKey);
    if (!data) {
      throw new BadRequestException('Code expiré ou non envoyé.');
    }

    const otpData = JSON.parse(data);

    // Vérifier le nombre de tentatives
    if (otpData.attempts >= this.MAX_ATTEMPTS) {
      await this.redis.set(blockKey, '1', 'EX', this.BLOCK_DURATION);
      await this.redis.del(otpKey);
      throw new BadRequestException(
        'Trop de tentatives échouées. Compte bloqué pour 15 minutes.',
      );
    }

    if (otpData.code !== code) {
      // Incrémenter les tentatives
      otpData.attempts += 1;
      const ttl = await this.redis.ttl(otpKey);
      await this.redis.set(otpKey, JSON.stringify(otpData), 'EX', ttl);
      throw new BadRequestException('Code incorrect.');
    }

    // Code valide — supprimer de Redis
    await this.redis.del(otpKey);
    return true;
  }
}
