import { getRequestConfig } from 'next-intl/server';

export default getRequestConfig(async () => {
  const locale = process.env.NEXT_PUBLIC_DEFAULT_LOCALE || 'fr';
  return {
    locale,
    messages: (await import(`./messages/${locale}.json`)).default,
  };
});
