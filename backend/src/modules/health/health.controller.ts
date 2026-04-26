import { Controller, Get } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';

@Controller('health')
export class HealthController {
  @Get()
  @SkipThrottle()
  check() {
    return {
      status: 'ok',
      service: 'Fiers Artisans API',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    };
  }
}
