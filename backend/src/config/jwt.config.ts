import { registerAs } from '@nestjs/config';

function requireEnv(name: string, minLength: number = 32): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `FATAL: ${name} is required. ` +
      `Authentication cannot operate with a fallback secret. ` +
      `Set a strong secret of at least ${minLength} characters in your environment.`
    );
  }
  if (value.length < minLength) {
    throw new Error(
      `FATAL: ${name} is too short (${value.length} chars). ` +
      `Minimum required: ${minLength} characters for cryptographic security.`
    );
  }
  return value;
}

export default registerAs('jwt', () => ({
  secret: requireEnv('JWT_SECRET', 32),
  refreshSecret: requireEnv('JWT_REFRESH_SECRET', 32),
  accessExpiration: process.env.JWT_ACCESS_EXPIRATION || '15m',
  refreshExpiration: process.env.JWT_REFRESH_EXPIRATION || '30d',
}));
