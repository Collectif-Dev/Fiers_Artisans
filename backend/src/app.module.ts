import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MongooseModule } from '@nestjs/mongoose';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { AdminRealtimeModule } from './common/realtime/admin-realtime.module';

// Config
import {
  appConfig,
  databasePostgresConfig,
  databaseMongoConfig,
  redisConfig,
  jwtConfig,
  whatsappConfig,
  waveConfig,
  minioConfig,
} from './config';

// Modules
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { VerificationModule } from './modules/verification/verification.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { PortfolioModule } from './modules/portfolio/portfolio.module';
import { SearchModule } from './modules/search/search.module';
import { SubscriptionModule } from './modules/subscription/subscription.module';
import { ChatModule } from './modules/chat/chat.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { ReviewsModule } from './modules/reviews/reviews.module';
import { MediaModule } from './modules/media/media.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { AdminModule } from './modules/admin/admin.module';
import { HealthModule } from './modules/health/health.module';
import { DevModule } from './modules/dev/dev.module';
import { PaymentManualModule } from './modules/payment-manual/payment-manual.module';

@Module({
  imports: [
    AdminRealtimeModule,

    // ── Configuration ─────────────────────────────────────────────
    ConfigModule.forRoot({
      isGlobal: true,
      load: [
        appConfig,
        databasePostgresConfig,
        databaseMongoConfig,
        redisConfig,
        jwtConfig,
        whatsappConfig,
        waveConfig,
        minioConfig,
      ],
      envFilePath: ['../.env'],
    }),

    // ── PostgreSQL + PostGIS ──────────────────────────────────────
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get<string>('database.postgres.host'),
        port: configService.get<number>('database.postgres.port'),
        username: configService.get<string>('database.postgres.username'),
        password: configService.get<string>('database.postgres.password'),
        database: configService.get<string>('database.postgres.database'),
        autoLoadEntities: true,
        synchronize: configService.get<string>('app.nodeEnv') !== 'production',
        logging: configService.get<string>('app.nodeEnv') === 'development',
      }),
    }),

    // ── MongoDB ───────────────────────────────────────────────────
    MongooseModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        uri: configService.get<string>('database.mongo.uri'),
      }),
    }),

    // ── Rate Limiting ─────────────────────────────────────────────
    ThrottlerModule.forRoot([
      {
        ttl: parseInt(process.env.THROTTLE_TTL_MS || '60000', 10),
        limit: parseInt(process.env.THROTTLE_LIMIT || '30', 10),
      },
    ]),

    // ── Scheduled Tasks ───────────────────────────────────────────
    ScheduleModule.forRoot(),

    // ── Feature Modules ───────────────────────────────────────────
    HealthModule,
    AuthModule,
    UsersModule,
    VerificationModule,
    CategoriesModule,
    PortfolioModule,
    SearchModule,
    SubscriptionModule,
    ChatModule,
    NotificationsModule,
    ReviewsModule,
    MediaModule,
    AnalyticsModule,
    AdminModule,
    PaymentManualModule,

    // ── Dev Tools (uniquement en développement) ───────────────────
    // Conditionnel : chargé seulement si NODE_ENV=development + OTP_DEV_INSPECTOR=true
    ...(process.env.NODE_ENV === 'development' && process.env.OTP_DEV_INSPECTOR === 'true'
      ? [DevModule]
      : []),
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
