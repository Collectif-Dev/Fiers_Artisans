'use client';

import { useCallback } from 'react';
import { useLocaleContext } from '@/providers/locale-provider';

export function useTranslations(namespace?: string) {
  const { locale, messages, setLocale } = useLocaleContext();

  const t = useCallback(
    (key: string): string => {
      if (!messages) return key;
      const fullKey = namespace ? `${namespace}.${key}` : key;
      const parts = fullKey.split('.');
      let current: unknown = messages;
      for (const part of parts) {
        if (current && typeof current === 'object' && part in current) {
          current = (current as Record<string, unknown>)[part];
        } else {
          return fullKey;
        }
      }
      return typeof current === 'string' ? current : fullKey;
    },
    [messages, namespace]
  );

  return { t, locale, setLocale };
}

