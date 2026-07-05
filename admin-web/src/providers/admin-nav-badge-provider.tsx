'use client';

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { usePathname } from 'next/navigation';
import { getDashboardStats } from '@/lib/api';
import { useAdminSSE, type AdminRealtimeEvent } from '@/hooks/use-admin-sse';

type NavBadgeKey =
  | 'verifications'
  | 'artisans'
  | 'clients'
  | 'subscriptions'
  | 'manual_payments'
  | 'reviews'
  | 'logs';

type NavBadgeCounts = Record<NavBadgeKey, number>;

const EMPTY_COUNTS: NavBadgeCounts = {
  verifications: 0,
  artisans: 0,
  clients: 0,
  subscriptions: 0,
  manual_payments: 0,
  reviews: 0,
  logs: 0,
};

const EPHEMERAL_KEYS = new Set<NavBadgeKey>([
  'artisans',
  'clients',
  'subscriptions',
  'reviews',
  'logs',
]);

const PENDING_COUNT_EVENTS = new Set<string>([
  'VERIFICATION_SUBMITTED',
  'VERIFICATION_REVIEWED',
  'PAYMENT_MANUAL_NEW_PROOF',
  'PAYMENT_MANUAL_UPDATED',
  'PAYMENT_MANUAL_TIMELINE_UPDATED',
]);

const EVENT_TO_KEY: Partial<Record<string, NavBadgeKey>> = {
  VERIFICATION_SUBMITTED: 'verifications',
  VERIFICATION_REVIEWED: 'verifications',
  ARTISAN_REGISTERED: 'artisans',
  ARTISAN_UPDATED: 'artisans',
  CLIENT_REGISTERED: 'clients',
  CLIENT_UPDATED: 'clients',
  SUBSCRIPTION_UPDATED: 'subscriptions',
  PAYMENT_UPDATED: 'subscriptions',
  PAYMENT_MANUAL_NEW_PROOF: 'manual_payments',
  PAYMENT_MANUAL_UPDATED: 'manual_payments',
  PAYMENT_MANUAL_TIMELINE_UPDATED: 'manual_payments',
  REVIEW_CREATED: 'reviews',
  REVIEW_REPLIED: 'reviews',
  REVIEW_DELETED: 'reviews',
  ACTIVITY_LOGGED: 'logs',
};

const AdminNavBadgeContext = createContext<NavBadgeCounts>(EMPTY_COUNTS);

function getActiveNavKey(pathname: string): NavBadgeKey | null {
  if (pathname.startsWith('/verifications')) return 'verifications';
  if (pathname.startsWith('/artisans')) return 'artisans';
  if (pathname.startsWith('/clients')) return 'clients';
  if (pathname.startsWith('/subscriptions')) return 'subscriptions';
  if (pathname.startsWith('/payments/manual')) return 'manual_payments';
  if (pathname.startsWith('/reviews')) return 'reviews';
  if (pathname.startsWith('/logs')) return 'logs';
  return null;
}

export function AdminNavBadgeProvider({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const [counts, setCounts] = useState<NavBadgeCounts>(EMPTY_COUNTS);
  const pathnameRef = useRef(pathname);
  const refreshPromiseRef = useRef<Promise<void> | null>(null);

  useEffect(() => {
    pathnameRef.current = pathname;
  }, [pathname]);

  const refreshPendingCounts = async () => {
    if (refreshPromiseRef.current) {
      return refreshPromiseRef.current;
    }

    const task = getDashboardStats()
      .then((stats) => {
        setCounts((current) => ({
          ...current,
          verifications: stats.pendingVerifications ?? 0,
          manual_payments: stats.pendingManualPayments ?? 0,
        }));
      })
      .catch(() => undefined)
      .finally(() => {
        refreshPromiseRef.current = null;
      });

    refreshPromiseRef.current = task;
    return task;
  };

  useEffect(() => {
    void refreshPendingCounts();
  }, []);

  useEffect(() => {
    const activeKey = getActiveNavKey(pathname);
    if (!activeKey || !EPHEMERAL_KEYS.has(activeKey)) {
      return;
    }

    const timeoutId = window.setTimeout(() => {
      setCounts((current) => ({
        ...current,
        [activeKey]: 0,
      }));
    }, 0);

    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [pathname]);

  const handleRealtimeEvent = (event: AdminRealtimeEvent) => {
    const eventType = event.type;
    if (!eventType) {
      return;
    }

    if (PENDING_COUNT_EVENTS.has(eventType)) {
      void refreshPendingCounts();
    }

    const targetKey = EVENT_TO_KEY[eventType];
    if (!targetKey) {
      return;
    }

    if (getActiveNavKey(pathnameRef.current) === targetKey) {
      return;
    }

    if (!EPHEMERAL_KEYS.has(targetKey)) {
      return;
    }

    setCounts((current) => ({
      ...current,
      [targetKey]: current[targetKey] + 1,
    }));
  };

  useAdminSSE(() => undefined, { onRealtimeEvent: handleRealtimeEvent });

  const value = useMemo(() => {
    const activeKey = getActiveNavKey(pathname);
    if (!activeKey) {
      return counts;
    }

    return {
      ...counts,
      [activeKey]: 0,
    };
  }, [counts, pathname]);

  return (
    <AdminNavBadgeContext.Provider value={value}>
      {children}
    </AdminNavBadgeContext.Provider>
  );
}

export function useAdminNavBadges() {
  return useContext(AdminNavBadgeContext);
}
