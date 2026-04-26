import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

export interface WaveCheckoutSession {
  checkout_id: string;
  checkout_url: string;
  amount: number;
  currency: string;
  merchant_reference: string;
}

@Injectable()
export class WaveProvider {
  private readonly logger = new Logger(WaveProvider.name);
  private readonly apiUrl: string;
  private readonly apiKey: string;

  constructor(private readonly configService: ConfigService) {
    this.apiUrl = this.configService.get<string>('wave.apiUrl') || '';
    this.apiKey = this.configService.get<string>('wave.apiKey') || '';
  }

  async createCheckoutSession(
    subscriptionId: string,
    amount: number,
  ): Promise<WaveCheckoutSession> {
    try {
      const response = await axios.post(
        `${this.apiUrl}/checkout/sessions`,
        {
          amount,
          currency: 'XOF',
          merchant_reference: subscriptionId,
          success_url: `${this.configService.get('app.appUrl')}/subscription/success`,
          error_url: `${this.configService.get('app.appUrl')}/subscription/error`,
        },
        {
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
        },
      );

      return {
        checkout_id: response.data.id,
        checkout_url: response.data.wave_launch_url,
        amount,
        currency: 'XOF',
        merchant_reference: subscriptionId,
      };
    } catch (error) {
      this.logger.error('Wave checkout creation failed', error.message);
      throw error;
    }
  }

  verifyWebhookSignature(payload: string, signature: string): boolean {
    const crypto = require('crypto');
    const secret = this.configService.get<string>('wave.webhookSecret');
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(payload)
      .digest('hex');
    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature),
    );
  }
}
