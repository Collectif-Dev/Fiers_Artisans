import { registerAs } from '@nestjs/config';

export default registerAs('app', () => {
  const parseCsv = (value?: string): string[] =>
    value
      ?.split(',')
      .map((entry) => entry.trim())
      .filter(Boolean) || [];

  const parsePortCsv = (value?: string): number[] =>
    parseCsv(value)
      .map((entry) => parseInt(entry, 10))
      .filter((entry) => Number.isInteger(entry) && entry > 0 && entry <= 65535);

  const defaultCorsOrigins = [
    'http://localhost:3000',
    'http://localhost:3001',
    'http://localhost:3002',
    'http://localhost:5050',
    'http://127.0.0.1:5050',
  ];

  const envCorsOrigins = parseCsv(process.env.CORS_ORIGINS);
  const defaultLanPorts = [3000, 3001, 3002, 5050, 8080];
  const envLanPorts = parsePortCsv(process.env.CORS_LAN_PORTS);
  const nodeEnv = process.env.NODE_ENV || 'development';
  const corsAllowLan =
    process.env.CORS_ALLOW_LAN != null
      ? process.env.CORS_ALLOW_LAN === 'true'
      : nodeEnv !== 'production';

  return {
    nodeEnv,
    port: parseInt(process.env.APP_PORT || '3000', 10),
    host: process.env.APP_HOST || '0.0.0.0',
    appUrl: process.env.APP_URL || 'http://localhost:3000',
    corsOrigins: Array.from(new Set([...envCorsOrigins, ...defaultCorsOrigins])),
    corsAllowLan,
    corsLanPorts: envLanPorts.length > 0 ? envLanPorts : defaultLanPorts,
  };
});
