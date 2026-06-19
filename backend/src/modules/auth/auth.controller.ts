import { Controller, Post, Body, UseGuards, Res } from '@nestjs/common';
import type { Response } from 'express';
import { AuthGuard } from '@nestjs/passport';
import { Throttle } from '@nestjs/throttler';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import {
  RegisterArtisanDto,
  RegisterClientDto,
  SendOtpDto,
  VerifyOtpDto,
  LoginDto,
  RefreshTokenDto,
  SetupPinDto,
} from './dto/auth.dto';
import { CurrentUser } from '../../common/decorators';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly configService: ConfigService,
  ) {}

  @Post('register/artisan')
  registerArtisan(@Body() dto: RegisterArtisanDto) {
    return this.authService.registerArtisan(dto);
  }

  @Post('register/client')
  registerClient(@Body() dto: RegisterClientDto) {
    return this.authService.registerClient(dto);
  }

  @Post('send-otp')
  @Throttle({ default: { limit: 3, ttl: 3600000 } })
  sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto.phone_number);
  }

  @Post('verify-otp')
  @Throttle({ default: { limit: 5, ttl: 300000 } })
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto.phone_number, dto.code);
  }

  @Post('login')
  @Throttle({ default: { limit: 10, ttl: 900000 } })
  login(@Body() dto: LoginDto, @Res({ passthrough: true }) response: Response) {
    const result = this.authService.login(dto);
    return result.then((data) => {
      this.setAuthCookies(response, data.access_token, data.refresh_token);
      return data;
    });
  }

  @Post('setup-pin')
  setupPin(@Body() dto: SetupPinDto) {
    return this.authService.setupPin(dto);
  }

  @Post('refresh')
  @UseGuards(AuthGuard('jwt-refresh'))
  refreshToken(
    @CurrentUser('id') userId: string,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = this.authService.refreshToken(userId);
    return result.then((data) => {
      this.setAuthCookies(response, data.access_token, data.refresh_token);
      return data;
    });
  }

  @Post('logout')
  @UseGuards(AuthGuard('jwt'))
  logout(@Res({ passthrough: true }) response: Response) {
    // Clear les cookies HttpOnly (admin-web)
    this.clearAuthCookies(response);

    // Note : Le JWT reste valide côté serveur jusqu'à son expiration
    // Pour une invalidation serveur stricte, ajouter le token à une blacklist Redis (Phase 2)
    return { message: 'Déconnexion réussie.' };
  }

  private clearAuthCookies(response: Response) {
    const cookieConfig = this.configService.get('app.cookie');

    response.clearCookie('admin_token', {
      httpOnly: true,
      secure: cookieConfig.secure,
      sameSite: cookieConfig.sameSite,
      domain: cookieConfig.domain,
      path: cookieConfig.path,
    });

    response.clearCookie('admin_refresh_token', {
      httpOnly: true,
      secure: cookieConfig.secure,
      sameSite: cookieConfig.sameSite,
      domain: cookieConfig.domain,
      path: cookieConfig.path,
    });
  }

  private setAuthCookies(
    response: Response,
    accessToken: string,
    refreshToken: string,
  ) {
    const cookieConfig = this.configService.get('app.cookie');
    const isProd = this.configService.get('app.nodeEnv') === 'production';

    response.cookie('admin_token', accessToken, {
      httpOnly: true,
      secure: cookieConfig.secure,
      sameSite: cookieConfig.sameSite,
      domain: cookieConfig.domain,
      path: cookieConfig.path,
      maxAge: cookieConfig.maxAgeAccess,
    });

    response.cookie('admin_refresh_token', refreshToken, {
      httpOnly: true,
      secure: cookieConfig.secure,
      sameSite: cookieConfig.sameSite,
      domain: cookieConfig.domain,
      path: cookieConfig.path,
      maxAge: cookieConfig.maxAgeRefresh,
    });
  }
}
