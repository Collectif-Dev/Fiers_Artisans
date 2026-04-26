// OTP Provider configuration avec fallback non-bloquant
export const OTP_PROVIDERS = {
  WHATSAPP: {
    enabled: process.env.WHATSAPP_PROVIDER_ENABLED !== 'false',
    priority: 1,
    label: 'WhatsApp Business Cloud API',
  },
  SMS_TWILIO: {
    enabled: process.env.SMS_PROVIDER_ENABLED === 'true',
    priority: 2,
    label: 'Twilio SMS',
  },
} as const;

// Payment Provider configuration avec feature flags
export const PAYMENT_PROVIDERS = {
  WAVE: {
    enabled: true,
    label: 'Wave',
  },
  ORANGE_MONEY: {
    enabled: false,
    label: 'Orange Money',
  },
  MTN_MOMO: {
    enabled: false,
    label: 'MTN Mobile Money',
  },
} as const;
