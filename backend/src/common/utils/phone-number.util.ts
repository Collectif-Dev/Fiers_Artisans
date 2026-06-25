export const LOCAL_PHONE_NUMBER_LENGTH = 10;
export const LOCAL_PHONE_NUMBER_REGEX = /^\d{10}$/;
export const LOCAL_PHONE_NUMBER_MESSAGE =
  'Le numéro de téléphone doit contenir exactement 10 chiffres.';

export function normalizeLocalPhoneNumber(value: unknown): string {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim().replace(/\D/g, '');
}

export function isLocalPhoneNumber(value: string): boolean {
  return LOCAL_PHONE_NUMBER_REGEX.test(value);
}
