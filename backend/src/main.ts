// Charger .env AVANT tout import de modules NestJS
// pour que process.env soit peuplé quand les décorateurs @Module s'évaluent
import './load-env.js';

import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters';
import { LoggingInterceptor, TransformInterceptor } from './common/interceptors';

const PRIVATE_LAN_HOST_PATTERN =
  /^(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})$/;

function isLoopbackOriginAllowed(origin: string): boolean {
  try {
    const parsed = new URL(origin);
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return false;
    }

    return ['localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname);
  } catch {
    return false;
  }
}

function isLanOriginAllowed(origin: string, allowedPorts: number[]): boolean {
  try {
    const parsed = new URL(origin);
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return false;
    }

    if (!PRIVATE_LAN_HOST_PATTERN.test(parsed.hostname)) {
      return false;
    }

    const port = parsed.port
      ? parseInt(parsed.port, 10)
      : parsed.protocol === 'https:'
        ? 443
        : 80;

    return Number.isInteger(port) && allowedPorts.includes(port);
  } catch {
    return false;
  }
}

async function bootstrap() {
  // ── HARDENING: Environment validation ──────────────────────────────
  const processNodeEnv = process.env.NODE_ENV;
  if (!processNodeEnv) {
    Logger.error(
      'FATAL: NODE_ENV is not set. ' +
      'The application cannot start without an explicit environment. ' +
      'Set NODE_ENV=production or NODE_ENV=development.',
      'Bootstrap',
    );
    process.exit(1);
  }

  if (processNodeEnv === 'production') {
    if (process.env.OTP_DEV_INSPECTOR === 'true') {
      Logger.error(
        'FATAL: OTP_DEV_INSPECTOR=true is strictly forbidden in production. ' +
        'This would expose OTP codes to potential attackers. ' +
        'Set OTP_DEV_INSPECTOR=false or unset it.',
        'Bootstrap',
      );
      process.exit(1);
    }
  }
  // ── FIN HARDENING ─────────────────────────────────────────────────

  // ── Fail-fast: vérifier les secrets obligatoires ────────────────
  const requiredSecrets = [
    'POSTGRES_PASSWORD',
    'REDIS_PASSWORD',
    'JWT_SECRET',
    'JWT_REFRESH_SECRET',
  ];
  const missing = requiredSecrets.filter((k) => !process.env[k] || process.env[k]?.startsWith('change_me'));
  if (missing.length > 0 && process.env.NODE_ENV === 'production') {
    Logger.error(
      `Missing or insecure required secrets: ${missing.join(', ')}. Refusing to start in production.`,
      'Bootstrap',
    );
    process.exit(1);
  }
  if (missing.length > 0) {
    Logger.warn(
      `⚠️  Secrets with default values detected: ${missing.join(', ')}. Update .env before deploying.`,
      'Bootstrap',
    );
  }

  const app = await NestFactory.create(AppModule, {
    rawBody: true, // Pour la vérification HMAC du webhook Wave
  });
  // Required behind reverse proxies (Nginx) so rate limiting sees real client IP.
  const httpAdapter = app.getHttpAdapter();
  const httpServer = httpAdapter.getInstance() as { set?: (key: string, value: unknown) => void };
  httpServer.set?.('trust proxy', 1);

  const configService = app.get(ConfigService);
  const port = configService.get<number>('app.port') || 3000;
  const host = configService.get<string>('app.host') || '0.0.0.0';
  const nodeEnv = configService.get<string>('app.nodeEnv') || 'development';
  const corsOrigins = configService.get<string[]>('app.corsOrigins') || ['*'];
  const corsAllowLan = configService.get<boolean>('app.corsAllowLan') ?? false;
  const corsLanPorts = configService.get<number[]>('app.corsLanPorts') || [];
  const corsOriginSet = new Set(corsOrigins);
  const allowAnyCorsOrigin = corsOrigins.includes('*');

  // ── Préfixe global ──────────────────────────────────────────
  app.setGlobalPrefix('api/v1', {
    exclude: ['api/docs', 'api/docs-json'],
  });

  // ── Sécurité ──────────────────────────────────────────────────
  app.use(helmet());
  app.enableCors({
    origin: (origin, callback) => {
      if (!origin || allowAnyCorsOrigin || corsOriginSet.has(origin)) {
        callback(null, true);
        return;
      }

      if (
        nodeEnv !== 'production' &&
        isLoopbackOriginAllowed(origin)
      ) {
        callback(null, true);
        return;
      }

      if (
        nodeEnv !== 'production' &&
        corsAllowLan &&
        isLanOriginAllowed(origin, corsLanPorts)
      ) {
        callback(null, true);
        return;
      }

      callback(null, false);
    },
    credentials: true,
  });

  // ── Pipes globaux ─────────────────────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // ── Filtres et Intercepteurs globaux ──────────────────────────
  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(
    new LoggingInterceptor(),
    new TransformInterceptor(),
  );

  // ── Swagger (API Documentation) ───────────────────────────────
  if (configService.get<string>('app.nodeEnv') !== 'production') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('Fiers Artisans API')
      .setDescription('API pour la plateforme Fiers Artisans — Marketplace artisans ivoiriens')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  await app.listen(port, host);
  Logger.log(
    `🚀 Fiers Artisans API running on http://${host}:${port}`,
    'Bootstrap',
  );
  if (host !== 'localhost') {
    Logger.log(
      `🔁 Loopback access: http://localhost:${port}`,
      'Bootstrap',
    );
  }
  Logger.log(
    `📖 Swagger docs: http://localhost:${port}/api/docs`,
    'Bootstrap',
  );
}
bootstrap();
