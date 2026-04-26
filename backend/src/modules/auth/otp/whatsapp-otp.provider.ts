import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

@Injectable()
export class WhatsappOtpProvider {
  private readonly logger = new Logger(WhatsappOtpProvider.name);
  private readonly apiUrl: string;
  private readonly apiToken: string;
  private readonly phoneNumberId: string;
  private readonly templateName: string;

  constructor(private readonly configService: ConfigService) {
    this.apiUrl = this.configService.get<string>('whatsapp.apiUrl') || '';
    this.apiToken = this.configService.get<string>('whatsapp.apiToken') || '';
    this.phoneNumberId = this.configService.get<string>('whatsapp.phoneNumberId') || '';
    this.templateName = this.configService.get<string>('whatsapp.otpTemplateName') || '';
  }

  async sendOtp(phoneNumber: string, code: string): Promise<boolean> {
    try {
      if (!this.apiToken || !this.phoneNumberId) {
        this.logger.warn('WhatsApp API not configured — skipping OTP send');
        return false;
      }

      await axios.post(
        `${this.apiUrl}/${this.phoneNumberId}/messages`,
        {
          messaging_product: 'whatsapp',
          to: phoneNumber.replace('+', ''),
          type: 'template',
          template: {
            name: this.templateName,
            language: { code: 'fr' },
            components: [
              {
                type: 'body',
                parameters: [{ type: 'text', text: code }],
              },
            ],
          },
        },
        {
          headers: {
            Authorization: `Bearer ${this.apiToken}`,
            'Content-Type': 'application/json',
          },
        },
      );

      this.logger.log(`OTP sent via WhatsApp to ${phoneNumber}`);
      return true;
    } catch (error) {
      this.logger.error(`WhatsApp OTP failed: ${error.message}`);
      return false;
    }
  }
}
