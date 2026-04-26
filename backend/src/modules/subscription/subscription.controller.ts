import {
  Controller,
  Post,
  Get,
  Body,
  Headers,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Request } from 'express';
import { SkipThrottle } from '@nestjs/throttler';
import { SubscriptionService } from './subscription.service';
import { CurrentUser, Roles } from '../../common/decorators';
import { RolesGuard, PhoneVerifiedGuard } from '../../common/guards';

interface RawBodyRequest extends Request {
  rawBody?: Buffer;
}

@Controller('subscription')
export class SubscriptionController {
  constructor(private readonly subscriptionService: SubscriptionService) {}

  @Post('initiate')
  @UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard, RolesGuard)
  @Roles('ARTISAN')
  initiatePayment(@CurrentUser('id') userId: string) {
    return this.subscriptionService.initiatePayment(userId);
  }

  @Post('wave/webhook')
  @SkipThrottle()
  async handleWaveWebhook(
    @Req() req: RawBodyRequest,
    @Body() body: any,
    @Headers('wave-signature') signature: string,
  ) {
    const rawBody = req.rawBody?.toString() || JSON.stringify(body);
    await this.subscriptionService.handleWaveWebhook(body, rawBody, signature);
    return { received: true };
  }

  @Get('status')
  @UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard, RolesGuard)
  @Roles('ARTISAN')
  getStatus(@CurrentUser('id') userId: string) {
    return this.subscriptionService.getStatus(userId);
  }

  @Get('providers')
  getProviders() {
    return this.subscriptionService.getAvailableProviders();
  }
}
