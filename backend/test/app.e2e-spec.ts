import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { HealthController } from '../src/modules/health/health.controller';
import { PaymentMinioIndicator } from '../src/modules/health/indicators/payment-minio.indicator';
import { AnalyticsService } from '../src/modules/analytics/analytics.service';

describe('HealthController (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        {
          provide: PaymentMinioIndicator,
          useValue: {
            check: jest
              .fn()
              .mockResolvedValue({ bucket: 'payment-proofs', exists: true }),
          },
        },
        {
          provide: AnalyticsService,
          useValue: {
            getLogRetentionStatus: jest
              .fn()
              .mockResolvedValue({ ttlSeconds: 2_592_000 }),
          },
        },
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('/health (GET)', async () => {
    const controller = app.get(HealthController);
    const body = await controller.check();

    expect(body).toMatchObject({
      status: 'ok',
      service: 'Fiers Artisans API',
    });
    expect(typeof body.timestamp).toBe('string');
    expect(typeof body.uptime).toBe('number');
    expect(body.storage?.paymentProofsBucket).toEqual({
      bucket: 'payment-proofs',
      exists: true,
    });
    expect(body.analytics?.activityLogsTtl).toEqual({
      ttlSeconds: 2_592_000,
    });
  });
});
