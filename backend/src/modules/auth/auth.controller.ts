import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
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
  constructor(private readonly authService: AuthService) {}

  @Post('register/artisan')
  registerArtisan(@Body() dto: RegisterArtisanDto) {
    return this.authService.registerArtisan(dto);
  }

  @Post('register/client')
  registerClient(@Body() dto: RegisterClientDto) {
    return this.authService.registerClient(dto);
  }

  @Post('send-otp')
  sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto.phone_number);
  }

  @Post('verify-otp')
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto.phone_number, dto.code);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('setup-pin')
  setupPin(@Body() dto: SetupPinDto) {
    return this.authService.setupPin(dto);
  }

  @Post('refresh')
  @UseGuards(AuthGuard('jwt-refresh'))
  refreshToken(@CurrentUser('id') userId: string) {
    return this.authService.refreshToken(userId);
  }

  @Post('logout')
  @UseGuards(AuthGuard('jwt'))
  logout() {
    // Le token JWT est invalidé côté client (suppression du token)
    // En production, ajouter le token à une blacklist Redis
    return { message: 'Déconnexion réussie.' };
  }
}
