'use client';

import { useEffect, useState, useCallback } from 'react';
import { getAnalytics } from '@/lib/api';
import { useTranslations } from '@/hooks/use-translations';
import { useAdminSSE } from '@/hooks/use-admin-sse';
import { KpiCard } from '@/components/dashboard/kpi-card';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Search, Eye, Phone, LogIn, BarChart3 } from 'lucide-react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';
import type { AnalyticsData } from '@/types';

export default function AnalyticsPage() {
  const [data, setData] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState(true);
  const { t } = useTranslations('analytics');

  const loadAnalytics = useCallback(async () => {
    setLoading(true);
    try {
      const analytics = await getAnalytics();
      setData(analytics);
    } catch {
      // handled by loading state
    } finally {
      setLoading(false);
    }
  }, []);

  const silentRefresh = useCallback(async () => {
    try {
      const analytics = await getAnalytics();
      setData(analytics);
    } catch {
      // Silent refresh: ignore transient realtime errors.
    }
  }, []);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void loadAnalytics();
    }, 0);
    return () => window.clearTimeout(timeoutId);
  }, [loadAnalytics]);

  useAdminSSE(silentRefresh, {
    eventTypes: ['ACTIVITY_LOGGED'],
  });

  const chartData = data
    ? [
        { name: t('searches'), value: data.totalSearches },
        { name: t('profile_views'), value: data.totalProfileViews },
        { name: t('contacts'), value: data.totalContacts },
        { name: t('logins'), value: data.recentLogins },
      ]
    : [];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">{t('title')}</h2>
        <p className="text-muted-foreground">{t('subtitle')}</p>
      </div>

      {/* KPI Grid */}
      <div className="grid gap-4 grid-cols-1 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          title={t('searches')}
          value={data?.totalSearches ?? 0}
          icon={Search}
          loading={loading}
        />
        <KpiCard
          title={t('profile_views')}
          value={data?.totalProfileViews ?? 0}
          icon={Eye}
          loading={loading}
        />
        <KpiCard
          title={t('contacts')}
          value={data?.totalContacts ?? 0}
          icon={Phone}
          loading={loading}
        />
        <KpiCard
          title={t('logins')}
          value={data?.recentLogins ?? 0}
          icon={LogIn}
          loading={loading}
        />
      </div>

      {/* Chart */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <BarChart3 className="h-5 w-5" />
            {t('activity_chart')}
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="h-80 flex items-center justify-center">
              <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={320}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                <XAxis dataKey="name" className="text-xs" />
                <YAxis className="text-xs" />
                <Tooltip
                  contentStyle={{
                    backgroundColor: 'hsl(var(--card))',
                    border: '1px solid hsl(var(--border))',
                    borderRadius: '8px',
                  }}
                />
                <Bar dataKey="value" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
