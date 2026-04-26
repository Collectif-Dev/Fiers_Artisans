import { registerAs } from '@nestjs/config';

export default registerAs('wave', () => ({
  apiUrl: process.env.WAVE_API_URL || 'https://api.wave.com/v1',
  apiKey: process.env.WAVE_API_KEY || '',
  webhookSecret: process.env.WAVE_WEBHOOK_SECRET || '',
  merchantId: process.env.WAVE_MERCHANT_ID || '',
}));
