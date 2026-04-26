import {
  Injectable,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { BusinessException } from '../../common/exceptions/business.exception';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User, UserRole } from '../users/entities/user.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { ClientProfile } from '../users/entities/client-profile.entity';
import { Subcategory } from '../categories/entities/subcategory.entity';
import { OtpService } from './otp/otp.service';
import {
  RegisterArtisanDto,
  RegisterClientDto,
  LoginDto,
  SetupPinDto,
} from './dto/auth.dto';
import { AnalyticsService } from '../analytics/analytics.service';
import { PinLoginGuardService } from './pin-login-guard.service';
import { AdminRealtimeService } from '../../common/realtime/admin-realtime.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    @InjectRepository(Subcategory)
    private readonly subcategoryRepository: Repository<Subcategory>,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly otpService: OtpService,
    private readonly analyticsService: AnalyticsService,
    private readonly pinLoginGuardService: PinLoginGuardService,
    private readonly adminRealtimeService: AdminRealtimeService,
  ) {}

  private hasValidCoordinates(latitude?: number, longitude?: number): boolean {
    return (
      Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      (latitude as number) >= -90 &&
      (latitude as number) <= 90 &&
      (longitude as number) >= -180 &&
      (longitude as number) <= 180
    );
  }

  private async setUserLocationIfProvided(
    userId: string,
    latitude?: number,
    longitude?: number,
  ): Promise<void> {
    if (!this.hasValidCoordinates(latitude, longitude)) {
      return;
    }

    await this.userRepository
      .createQueryBuilder()
      .update(User)
      .set({
        location: () => 'ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)',
        location_updated_at: () => 'CURRENT_TIMESTAMP',
      })
      .where('id = :id', { id: userId })
      .setParameters({ lat: latitude, lng: longitude })
      .execute();
  }

  async registerArtisan(dto: RegisterArtisanDto) {
    // Vérifier l'unicité du numéro
    const existing = await this.userRepository.findOne({
      where: { phone_number: dto.phone_number },
    });
    if (existing) {
      throw new BusinessException('AUTH_PHONE_ALREADY_USED', 'Ce numéro de téléphone est déjà utilisé.', HttpStatus.CONFLICT);
    }

    // Créer l'utilisateur
    const pin_hash = await bcrypt.hash(dto.pin_code, 12);
    const user = this.userRepository.create({
      phone_number: dto.phone_number,
      pin_hash,
      password_hash: null,
      role: UserRole.ARTISAN,
      email: dto.email,
      whatsapp_number: dto.whatsapp_number || dto.phone_number,
    });
    const savedUser = await this.userRepository.save(user);
    await this.setUserLocationIfProvided(
      savedUser.id,
      dto.latitude,
      dto.longitude,
    );

    const resolvedCategoryId = dto.category_id;
    const resolvedSubcategoryId = dto.subcategory_id;

    const subcategory = await this.subcategoryRepository.findOne({
      where: { id: resolvedSubcategoryId },
      select: ['id', 'category_id'],
    });

    if (!subcategory) {
      throw new BusinessException(
        'AUTH_INVALID_SUBCATEGORY',
        'Metier invalide.',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (subcategory.category_id !== resolvedCategoryId) {
      throw new BusinessException(
        'AUTH_CATEGORY_SUBCATEGORY_MISMATCH',
        'La categorie ne correspond pas au metier selectionne.',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Créer le profil artisan
    const profile = this.artisanProfileRepository.create({
      user_id: savedUser.id,
      first_name: dto.first_name,
      last_name: dto.last_name,
      business_name: dto.business_name,
      bio: dto.bio,
      years_experience: dto.years_experience ?? 0,
      category_id: resolvedCategoryId,
      subcategory_id: resolvedSubcategoryId,
      city: dto.city,
      commune: dto.commune,
      whatsapp_number: dto.whatsapp_number || dto.phone_number,
    });
    await this.artisanProfileRepository.save(profile);

    this.logger.log(`Artisan registered: ${savedUser.id}`);
    this.analyticsService.logActivity({ actorId: savedUser.id, action: 'REGISTRATION', metadata: { role: 'ARTISAN' } });
    this.adminRealtimeService.emit('ARTISAN_REGISTERED', {
      userId: savedUser.id,
      artisanProfileId: profile.id,
      categoryId: profile.category_id,
      subcategoryId: profile.subcategory_id,
    });
    return this.generateTokens(savedUser);
  }

  async registerClient(dto: RegisterClientDto) {
    const existing = await this.userRepository.findOne({
      where: { phone_number: dto.phone_number },
    });
    if (existing) {
      throw new BusinessException('AUTH_PHONE_ALREADY_USED', 'Ce numéro de téléphone est déjà utilisé.', HttpStatus.CONFLICT);
    }

    const pin_hash = await bcrypt.hash(dto.pin_code, 12);
    const user = this.userRepository.create({
      phone_number: dto.phone_number,
      pin_hash,
      password_hash: null,
      role: UserRole.CLIENT,
      email: dto.email,
      whatsapp_number: dto.phone_number,
    });
    const savedUser = await this.userRepository.save(user);
    await this.setUserLocationIfProvided(
      savedUser.id,
      dto.latitude,
      dto.longitude,
    );

    const profile = this.clientProfileRepository.create({
      user_id: savedUser.id,
      first_name: dto.first_name,
      last_name: dto.last_name,
      city: dto.city,
      commune: dto.commune,
    });
    await this.clientProfileRepository.save(profile);

    this.logger.log(`Client registered: ${savedUser.id}`);
    this.analyticsService.logActivity({ actorId: savedUser.id, action: 'REGISTRATION', metadata: { role: 'CLIENT' } });
    this.adminRealtimeService.emit('CLIENT_REGISTERED', {
      userId: savedUser.id,
      clientProfileId: profile.id,
    });
    return this.generateTokens(savedUser);
  }

  async sendOtp(phoneNumber: string) {
    return this.otpService.sendOtp(phoneNumber);
  }

  async verifyOtp(phoneNumber: string, code: string) {
    await this.otpService.verifyOtp(phoneNumber, code);

    // Marquer le téléphone comme vérifié
    await this.userRepository.update(
      { phone_number: phoneNumber },
      { is_phone_verified: true },
    );

    return { verified: true };
  }

  async login(dto: LoginDto) {
    if (await this.pinLoginGuardService.isBlocked(dto.phone_number)) {
      const ttl = await this.pinLoginGuardService.blockTtlSeconds(dto.phone_number);
      throw new BusinessException(
        'AUTH_PIN_BLOCKED',
        `Trop de tentatives. Réessayez dans ${ttl || 1} secondes.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const user = await this.userRepository.findOne({
      where: { phone_number: dto.phone_number },
    });
    if (!user) {
      await this.pinLoginGuardService.registerFailure(dto.phone_number);
      throw new BusinessException(
        'AUTH_INVALID_CREDENTIALS',
        'Numero de telephone ou code PIN incorrect.',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!user.pin_hash) {
      throw new BusinessException(
        'AUTH_PIN_SETUP_REQUIRED',
        'Votre compte doit definir un code PIN avant la connexion.',
        HttpStatus.FORBIDDEN,
      );
    }

    const isPinValid = await bcrypt.compare(dto.pin_code, user.pin_hash);
    if (!isPinValid) {
      await this.pinLoginGuardService.registerFailure(dto.phone_number);
      throw new BusinessException(
        'AUTH_INVALID_CREDENTIALS',
        'Numero de telephone ou code PIN incorrect.',
        HttpStatus.UNAUTHORIZED,
      );
    }

    await this.pinLoginGuardService.clearFailures(dto.phone_number);

    if (!user.is_active) {
      throw new BusinessException('AUTH_ACCOUNT_DISABLED', 'Compte désactivé.', HttpStatus.UNAUTHORIZED);
    }

    // Si téléphone non vérifié → envoyer OTP et bloquer
    if (!user.is_phone_verified) {
      try {
        await this.otpService.sendOtp(user.phone_number);
      } catch (e) {
        this.logger.warn(`OTP send failed during login for ${user.phone_number}: ${e.message}`);
      }
      throw new BusinessException('AUTH_OTP_REQUIRED', 'Vérification du téléphone requise.', HttpStatus.FORBIDDEN);
    }

    this.analyticsService.logActivity({ actorId: user.id, action: 'LOGIN', metadata: { role: user.role } });
    return this.generateTokens(user);
  }

  async setupPin(dto: SetupPinDto) {
    const user = await this.userRepository.findOne({
      where: { phone_number: dto.phone_number },
    });

    if (!user) {
      throw new BusinessException(
        'AUTH_INVALID_CREDENTIALS',
        'Numero de telephone ou code PIN incorrect.',
        HttpStatus.UNAUTHORIZED,
      );
    }

    await this.otpService.verifyOtp(dto.phone_number, dto.code);

    user.pin_hash = await bcrypt.hash(dto.pin_code, 12);
    user.password_hash = null;
    user.is_phone_verified = true;
    const saved = await this.userRepository.save(user);

    await this.pinLoginGuardService.clearFailures(dto.phone_number);
    this.analyticsService.logActivity({ actorId: saved.id, action: 'PIN_SETUP' });

    return {
      pin_set: true,
      ...(await this.generateTokens(saved)),
    };
  }

  async refreshToken(userId: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user || !user.is_active) {
      throw new BusinessException('AUTH_INVALID_TOKEN', 'Token invalide.', HttpStatus.UNAUTHORIZED);
    }
    return this.generateTokens(user);
  }

  private async generateTokens(user: User) {
    const payload = {
      sub: user.id,
      phone_number: user.phone_number,
      role: user.role,
    };

    const access_token = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('jwt.secret') || 'fallback',
      expiresIn: (this.configService.get<string>('jwt.accessExpiration') || '15m') as any,
    });

    const refresh_token = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('jwt.refreshSecret') || 'fallback',
      expiresIn: (this.configService.get<string>('jwt.refreshExpiration') || '30d') as any,
    });

    // Resolve first_name / last_name from profile
    let first_name = '';
    let last_name = '';

    if (user.role === UserRole.ARTISAN) {
      const profile = await this.artisanProfileRepository.findOne({
        where: { user_id: user.id },
        select: ['id', 'first_name', 'last_name', 'business_name'],
      });
      if (profile) {
        first_name = profile.first_name;
        last_name = profile.last_name;
      }
    } else if (user.role === UserRole.CLIENT) {
      const profile = await this.clientProfileRepository.findOne({
        where: { user_id: user.id },
        select: ['id', 'first_name', 'last_name'],
      });
      if (profile) {
        first_name = profile.first_name;
        last_name = profile.last_name;
      }
    }

    return {
      access_token,
      refresh_token,
      user: {
        id: user.id,
        phone_number: user.phone_number,
        role: user.role,
        first_name,
        last_name,
        email: user.email,
        is_phone_verified: user.is_phone_verified,
        verification_status: user.verification_status,
      },
    };
  }
}
