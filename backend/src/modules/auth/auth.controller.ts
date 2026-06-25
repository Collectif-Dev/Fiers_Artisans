import {
  Controller,
  Post,
  Body,
  UseGuards,
  Res,
  Req,
  ForbiddenException,
} from '@nestjs/common';
import type { Request, Response } from 'express';
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
  async login(
    @Body() dto: LoginDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ) {
    const data = await this.authService.login(dto);

    if (this.isAdminCookieMode(request)) {
      if (data.user.role !== 'ADMIN') {
        this.clearAuthCookies(response);
        throw new ForbiddenException('Admin access only.');
      }
      this.setAuthCookies(response, data.access_token, data.refresh_token);
      return { user: data.user };
    }

    return data;
  }

  @Post('setup-pin')
  setupPin(@Body() dto: SetupPinDto) {
    return this.authService.setupPin(dto);
  }

  @Post('refresh')
  @UseGuards(AuthGuard('jwt-refresh'))
  refreshToken(
    @CurrentUser('id') userId: string,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = this.authService.refreshToken(userId);
    return result.then((data) => {
      if (this.isAdminCookieMode(request)) {
        if (data.user.role !== 'ADMIN') {
          this.clearAuthCookies(response);
          throw new ForbiddenException('Admin access only.');
        }
        this.setAuthCookies(response, data.access_token, data.refresh_token);
        return { user: data.user };
      }

      return data;
    });
  }

  @Post('logout')
  logout(@Res({ passthrough: true }) response: Response) {
    // Clear les cookies HttpOnly (admin-web)
    this.clearAuthCookies(response);

    // Note : Le JWT reste valide côté serveur jusqu'à son expiration
    // Pour une invalidation serveur stricte, ajouter le token à une blacklist Redis (Phase 2)
    return { message: 'Déconnexion réussie.' };
  }

  private isAdminCookieMode(request: Request): boolean {
    return request.header('x-admin-web-auth') === 'cookie';
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
