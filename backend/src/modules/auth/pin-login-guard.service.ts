import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class PinLoginGuardService {
  private readonly redis: Redis;
  private readonly maxAttempts: number;
  private readonly blockDurationSeconds: number;
  private readonly attemptWindowSeconds: number;

  constructor(private readonly configService: ConfigService) {
    this.redis = new Redis({
      host: this.configService.get<string>('redis.host'),
      port: this.configService.get<number>('redis.port'),
      password: this.configService.get<string>('redis.password'),
    });

    this.maxAttempts = parseInt(process.env.PIN_MAX_ATTEMPTS || '5', 10);
    this.blockDurationSeconds = parseInt(
      process.env.PIN_BLOCK_DURATION_SECONDS || '900',
      10,
    );
    this.attemptWindowSeconds = parseInt(
      process.env.PIN_ATTEMPT_WINDOW_SECONDS || '900',
      10,
    );
  }

  private attemptKey(phoneNumber: string): string {
    return `auth:pin:attempts:${phoneNumber}`;
  }

  private blockKey(phoneNumber: string): string {
    return `auth:pin:block:${phoneNumber}`;
  }

  async isBlocked(phoneNumber: string): Promise<boolean> {
    const blocked = await this.redis.exists(this.blockKey(phoneNumber));
    return blocked > 0;
  }

  async blockTtlSeconds(phoneNumber: string): Promise<number> {
    const ttl = await this.redis.ttl(this.blockKey(phoneNumber));
    return ttl > 0 ? ttl : 0;
  }

  async registerFailure(phoneNumber: string): Promise<void> {
    const key = this.attemptKey(phoneNumber);
    const attempts = await this.redis.incr(key);

    if (attempts === 1) {
      await this.redis.expire(key, this.attemptWindowSeconds);
    }

    if (attempts >= this.maxAttempts) {
      await this.redis.set(this.blockKey(phoneNumber), '1', 'EX', this.blockDurationSeconds);
      await this.redis.del(key);
    }
  }

  async clearFailures(phoneNumber: string): Promise<void> {
    await this.redis.del(this.attemptKey(phoneNumber));
  }
}
