import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(
  Strategy,
  'jwt-refresh',
) {
  constructor(private readonly configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        ExtractJwt.fromAuthHeaderAsBearerToken(),
        ExtractJwt.fromBodyField('refresh_token'),
      ]),
      ignoreExpiration: false,
      secretOrKey: (() => {
        const secret = configService.get<string>('jwt.refreshSecret');
        if (!secret || secret.length < 32) {
          throw new Error(
            'FATAL: JWT_REFRESH_SECRET is not configured or is too short. ' +
              'The JWT refresh strategy cannot initialize without a secure secret. ' +
              'Application startup aborted.',
          );
        }
        return secret;
      })(),
    });
  }

  async validate(payload: any) {
    return {
      id: payload.sub,
      phone_number: payload.phone_number,
      role: payload.role,
    };
  }
}
