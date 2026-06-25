import { BadRequestException, HttpException, HttpStatus } from '@nestjs/common';
import { OtpService } from './otp.service';

type RedisMockInstance = {
  store: Map<string, { value: string; expiresAt?: number }>;
  exists(key: string): number;
  get(key: string): string | null;
};

declare global {
  var __otpRedisInstances: RedisMockInstance[];
}

globalThis.__otpRedisInstances = [];

jest.mock('ioredis', () => {
  class RedisMock {
    readonly store = new Map<string, { value: string; expiresAt?: number }>();

    constructor() {
      globalThis.__otpRedisInstances.push(this);
    }

    exists(key: string): number {
      return this.getRecord(key) ? 1 : 0;
    }

    get(key: string): string | null {
      return this.getRecord(key)?.value ?? null;
    }

    set(key: string, value: string, mode?: string, ttlSeconds?: number): 'OK' {
      this.store.set(key, {
        value,
        expiresAt:
          mode === 'EX' && typeof ttlSeconds === 'number'
            ? Date.now() + ttlSeconds * 1000
            : undefined,
      });
      return 'OK';
    }

    del(...keys: string[]): number {
      let deleted = 0;
      for (const key of keys) {
        if (this.store.delete(key)) {
          deleted += 1;
        }
      }
      return deleted;
    }

    incr(key: string): number {
      const record = this.getRecord(key);
      const next = (record ? parseInt(record.value, 10) : 0) + 1;
      this.store.set(key, {
        value: next.toString(),
        expiresAt: record?.expiresAt,
      });
      return next;
    }

    expire(key: string, ttlSeconds: number): number {
      const record = this.getRecord(key);
      if (!record) {
        return 0;
      }
      record.expiresAt = Date.now() + ttlSeconds * 1000;
      return 1;
    }

    ttl(key: string): number {
      const record = this.getRecord(key);
      if (!record) {
        return -2;
      }
      if (!record.expiresAt) {
        return -1;
      }
      return Math.ceil((record.expiresAt - Date.now()) / 1000);
    }

    eval(
      _script: string,
      _keyCount: number,
      key: string,
      ttlSeconds: number,
    ): number {
      const count = this.incr(key);
      if (this.ttl(key) < 0) {
        this.expire(key, Number(ttlSeconds));
      }
      return count;
    }

    private getRecord(
      key: string,
    ): { value: string; expiresAt?: number } | undefined {
      const record = this.store.get(key);
      if (!record) {
        return undefined;
      }
      if (record.expiresAt && record.expiresAt <= Date.now()) {
        this.store.delete(key);
        return undefined;
      }
      return record;
    }
  }

  return {
    __esModule: true,
    default: RedisMock,
  };
});

describe('OtpService', () => {
  const configService = {
    get: jest.fn((key: string) => {
      const values: Record<string, unknown> = {
        'redis.host': 'localhost',
        'redis.port': 6379,
        'redis.password': undefined,
        'app.nodeEnv': 'test',
      };
      return values[key];
    }),
  };

  const whatsappOtpProvider = {
    sendOtp: jest.fn().mockResolvedValue(true),
  };

  beforeEach(() => {
    globalThis.__otpRedisInstances = [];
    jest.clearAllMocks();
  });

  it('stores OTPs under the canonical 10-digit local phone number', async () => {
    const service = new OtpService(
      configService as any,
      whatsappOtpProvider as any,
    );

    await service.sendOtp('07 00 00 00 00');

    const redis = globalThis.__otpRedisInstances[0];
    expect(redis.store.has('otp:0700000000')).toBe(true);
    expect(redis.store.has('otp:+2250700000000')).toBe(false);
    expect(whatsappOtpProvider.sendOtp).toHaveBeenCalledWith(
      '0700000000',
      expect.stringMatching(/^\d{6}$/),
    );
  });

  it('rejects phone numbers that are not exactly 10 local digits', async () => {
    const service = new OtpService(
      configService as any,
      whatsappOtpProvider as any,
    );

    await expect(service.sendOtp('+2250700000000')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(service.sendOtp('070000000')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('blocks immediately on the last allowed wrong OTP attempt', async () => {
    const service = new OtpService(
      configService as any,
      whatsappOtpProvider as any,
    );
    await service.sendOtp('0700000000');

    for (let i = 0; i < 4; i += 1) {
      await expect(
        service.verifyOtp('0700000000', '000000'),
      ).rejects.toBeInstanceOf(BadRequestException);
    }

    let blockedError: unknown;
    try {
      await service.verifyOtp('0700000000', '000000');
    } catch (error) {
      blockedError = error;
    }

    expect(blockedError).toBeInstanceOf(HttpException);
    expect((blockedError as HttpException).getStatus()).toBe(
      HttpStatus.TOO_MANY_REQUESTS,
    );

    const redis = globalThis.__otpRedisInstances[0];
    expect(redis.exists('otp:block:0700000000')).toBe(1);
    expect(redis.exists('otp:0700000000')).toBe(0);
    expect(redis.exists('otp:attempts:0700000000')).toBe(0);
  });

  it('clears attempt counters after a valid OTP', async () => {
    const service = new OtpService(
      configService as any,
      whatsappOtpProvider as any,
    );
    await service.sendOtp('0700000000');

    const redis = globalThis.__otpRedisInstances[0];
    const code = await redis.get('otp:0700000000');

    await expect(service.verifyOtp('0700000000', code || '')).resolves.toBe(
      true,
    );
    expect(redis.exists('otp:0700000000')).toBe(0);
    expect(redis.exists('otp:attempts:0700000000')).toBe(0);
  });
});
