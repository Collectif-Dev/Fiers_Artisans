import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { OtpService } from './otp/otp.service';
import { WhatsappOtpProvider } from './otp/whatsapp-otp.provider';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtRefreshStrategy } from './strategies/jwt-refresh.strategy';
import { User } from '../users/entities/user.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { ClientProfile } from '../users/entities/client-profile.entity';
import { Subcategory } from '../categories/entities/subcategory.entity';
import { AnalyticsModule } from '../analytics/analytics.module';
import { PinLoginGuardService } from './pin-login-guard.service';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const secret = configService.get<string>('jwt.secret');
        if (!secret || secret.length < 32) {
          throw new Error(
            'FATAL: JWT_SECRET is not configured or is too short (< 32 chars). ' +
            'The JWT module cannot initialize without a secure secret. ' +
            'Application startup aborted.',
          );
        }
        return {
          secret,
          signOptions: {
            expiresIn: (configService.get<string>('jwt.accessExpiration') ||
              '15m') as any,
          },
        };
      },
    }),
    TypeOrmModule.forFeature([
      User,
      ArtisanProfile,
      ClientProfile,
      Subcategory,
    ]),
    AnalyticsModule,
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    PinLoginGuardService,
    WhatsappOtpProvider,
    JwtStrategy,
    JwtRefreshStrategy,
  ],
  exports: [AuthService, JwtStrategy],
})
export class AuthModule {}
