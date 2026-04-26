import { registerAs } from '@nestjs/config';

export default registerAs('jwt', () => ({
  secret: process.env.JWT_SECRET || 'change_me_jwt_secret_min_32_chars',
  refreshSecret: process.env.JWT_REFRESH_SECRET || 'change_me_jwt_refresh_secret_min_32_chars',
  accessExpiration: process.env.JWT_ACCESS_EXPIRATION || '15m',
  refreshExpiration: process.env.JWT_REFRESH_EXPIRATION || '30d',
}));
