import { registerAs } from '@nestjs/config';

export default registerAs('whatsapp', () => ({
  apiUrl: process.env.WHATSAPP_API_URL || 'https://graph.facebook.com/v18.0',
  apiToken: process.env.WHATSAPP_API_TOKEN || '',
  phoneNumberId: process.env.WHATSAPP_PHONE_NUMBER_ID || '',
  otpTemplateName: process.env.WHATSAPP_OTP_TEMPLATE_NAME || 'fiers_artisans_otp',
}));
