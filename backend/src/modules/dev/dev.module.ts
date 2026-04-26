import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { DevOtpController } from './dev-otp.controller';

/**
 * Module développement — chargé UNIQUEMENT si :
 *   - NODE_ENV=development
 *   - OTP_DEV_INSPECTOR=true
 *
 * Fournit un endpoint GET pour consulter les OTP en cours via navigateur.
 * Désactivé automatiquement en production (le module n'est pas importé).
 */
@Module({
  imports: [ConfigModule],
  controllers: [DevOtpController],
})
export class DevModule {
  /**
   * Vérifie si le module dev doit être activé.
   * Appelé par AppModule pour conditionner l'import.
   */
  static isEnabled(configService: ConfigService): boolean {
    const nodeEnv = configService.get<string>('app.nodeEnv') || process.env.NODE_ENV;
    const inspectorFlag = configService.get<string>('OTP_DEV_INSPECTOR') || process.env.OTP_DEV_INSPECTOR;
    return nodeEnv === 'development' && inspectorFlag === 'true';
  }
}
