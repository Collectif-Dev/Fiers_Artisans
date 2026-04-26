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
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('jwt.secret') || 'fallback-secret',
        signOptions: {
          expiresIn: (configService.get<string>('jwt.accessExpiration') || '15m') as any,
        },
      }),
    }),
    TypeOrmModule.forFeature([User, ArtisanProfile, ClientProfile, Subcategory]),
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
