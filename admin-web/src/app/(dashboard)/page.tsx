'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { getDashboardStats } from '@/lib/api';
import { useTranslations } from '@/hooks/use-translations';
import { useAdminSSE } from '@/hooks/use-admin-sse';
import { KpiCard } from '@/components/dashboard/kpi-card';
import { Button, buttonVariants } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import {
  Users,
  Hammer,
  CreditCard,
  BadgeSwissFranc,
  ShieldAlert,
  Star,
  ArrowRight,
  WalletCards,
} from 'lucide-react';
import type { DashboardStats } from '@/types';

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const { t } = useTranslations('dashboard');
  const { t: tApp } = useTranslations('app');

  const loadStats = useCallback(async () => {
    setLoading(true);
    setError(false);
    try {
      const data = await getDashboardStats();
      setStats(data);
    } catch {
      setError(true);
    } finally {
      setLoading(false);
    }
  }, []);

  const silentRefresh = useCallback(async () => {
    try {
      const data = await getDashboardStats();
      setStats(data);
    } catch { /* ignore */ }
  }, []);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void loadStats();
    }, 0);
    return () => window.clearTimeout(timeoutId);
  }, [loadStats]);

  // Real-time: refresh KPIs for business-changing events.
  useAdminSSE(silentRefresh, {
    eventTypes: [
      'ARTISAN_REGISTERED',
      'CLIENT_REGISTERED',
      'VERIFICATION_SUBMITTED',
      'VERIFICATION_REVIEWED',
      'REVIEW_CREATED',
      'REVIEW_DELETED',
      'SUBSCRIPTION_UPDATED',
      'PAYMENT_UPDATED',
      'PAYMENT_MANUAL_NEW_PROOF',
      'PAYMENT_MANUAL_UPDATED',
    ],
  });

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">{t('title')}</h2>
      </div>

      {error && (
        <Card className="border-destructive">
          <CardContent className="py-4 text-center">
            <p className="text-destructive mb-2">{tApp('error')}</p>
            <Button variant="outline" size="sm" onClick={loadStats}>
              {tApp('retry')}
            </Button>
          </CardContent>
        </Card>
      )}

      {/* KPI Grid */}
      <div className="grid gap-4 grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <KpiCard
          title={t('total_clients')}
          value={stats?.totalClients ?? 0}
          icon={Users}
          loading={loading}
        />
        <KpiCard
          title={t('total_artisans')}
          value={stats?.totalArtisans ?? 0}
          icon={Hammer}
          loading={loading}
        />
        <KpiCard
          title={t('active_subscriptions')}
          value={stats?.activeSubscriptions ?? 0}
          icon={CreditCard}
          loading={loading}
        />
        <KpiCard
          title={t('total_revenue')}
          value={stats?.totalRevenueFcfa ?? 0}
          icon={BadgeSwissFranc}
          loading={loading}
        />
        <KpiCard
          title={t('pending_verifications')}
          value={stats?.pendingVerifications ?? 0}
          icon={ShieldAlert}
          loading={loading}
        />
        <KpiCard
          title={t('manual_payments_pending')}
          value={stats?.pendingManualPayments ?? 0}
          icon={WalletCards}
          loading={loading}
        />
        <KpiCard
          title={t('total_reviews')}
          value={stats?.totalReviews ?? 0}
          icon={Star}
          loading={loading}
        />
      </div>

      {/* Quick actions */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">{t('quick_actions')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-wrap gap-3">
          <Link
            href="/verifications"
            className={cn(buttonVariants({ variant: 'outline' }), 'no-underline')}
          >
            <ShieldAlert className="mr-2 h-4 w-4" />
            {t('view_pending')}
            {stats && stats.pendingVerifications > 0 && (
              <span className="ml-2 bg-destructive text-destructive-foreground rounded-full px-2 py-0.5 text-xs">
                {stats.pendingVerifications}
              </span>
            )}
            <ArrowRight className="ml-2 h-4 w-4" />
          </Link>
          <Link
            href="/artisans"
            className={cn(buttonVariants({ variant: 'outline' }), 'no-underline')}
          >
            <Hammer className="mr-2 h-4 w-4" />
            {t('view_artisans')}
            <ArrowRight className="ml-2 h-4 w-4" />
          </Link>
          <Link
            href="/reviews"
            className={cn(buttonVariants({ variant: 'outline' }), 'no-underline')}
          >
            <Star className="mr-2 h-4 w-4" />
            {t('view_reviews')}
            <ArrowRight className="ml-2 h-4 w-4" />
          </Link>
          <Link
            href="/payments/manual?status=PENDING_ADMIN"
            className={cn(buttonVariants({ variant: 'outline' }), 'no-underline')}
          >
            <WalletCards className="mr-2 h-4 w-4" />
            {t('view_manual_payments')}
            <ArrowRight className="ml-2 h-4 w-4" />
          </Link>
        </CardContent>
      </Card>
    </div>
  );
}
