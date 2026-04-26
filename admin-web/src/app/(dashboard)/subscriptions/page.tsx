'use client';

import { useEffect, useState, useMemo, useCallback } from 'react';
import { getSubscriptions } from '@/lib/api';
import { useTranslations } from '@/hooks/use-translations';
import { useAdminSSE } from '@/hooks/use-admin-sse';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { ChevronLeft, ChevronRight, CreditCard } from 'lucide-react';
import { toast } from 'sonner';
import type { SubscriptionRecord } from '@/types';

export default function SubscriptionsPage() {
  const [subscriptions, setSubscriptions] = useState<SubscriptionRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [statusFilter, setStatusFilter] = useState('all');
  const limit = 50;
  const { t, locale } = useTranslations('subscriptions');
  const { t: tApp } = useTranslations('app');
  const totalPages = Math.max(1, Math.ceil(total / limit));

  const loadSubscriptions = useCallback(async () => {
    setLoading(true);
    try {
      const result = await getSubscriptions(page, limit);
      setSubscriptions(result.data);
      setTotal(result.total);
    } catch {
      toast.error(tApp('error'));
    } finally {
      setLoading(false);
    }
  }, [page, limit, tApp]);

  const silentRefresh = useCallback(async () => {
    try {
      const result = await getSubscriptions(page, limit);
      setSubscriptions(result.data);
      setTotal(result.total);
    } catch {
      // Silent refresh: ignore transient realtime errors.
    }
  }, [page, limit]);

  useEffect(() => {
    loadSubscriptions();
  }, [loadSubscriptions]);

  useAdminSSE(silentRefresh, {
    eventTypes: ['SUBSCRIPTION_UPDATED', 'PAYMENT_UPDATED'],
  });

  const filtered = useMemo(() => {
    return subscriptions.filter((s) => {
      return statusFilter === 'all' || s.status === statusFilter;
    });
  }, [subscriptions, statusFilter]);

  const statusBadge = (status: string) => {
    switch (status) {
      case 'ACTIVE':
        return <Badge className="bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">{t('status_active')}</Badge>;
      case 'EXPIRED':
        return <Badge variant="destructive">{t('status_expired')}</Badge>;
      case 'PENDING':
        return <Badge className="bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200">{t('status_pending')}</Badge>;
      case 'CANCELLED':
        return <Badge variant="secondary">{t('status_cancelled')}</Badge>;
      default:
        return <Badge variant="outline">{status}</Badge>;
    }
  };

  const getLastPaymentDate = (payments: SubscriptionRecord['payments']) => {
    const successful = payments
      .filter((p) => p.status === 'SUCCESS')
      .sort((a, b) => new Date(b.paid_at).getTime() - new Date(a.paid_at).getTime());
    return successful.length > 0
      ? new Date(successful[0].paid_at).toLocaleDateString(locale === 'fr' ? 'fr-FR' : 'en-US')
      : t('no_payment');
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">{t('title')}</h2>
        <p className="text-muted-foreground">{t('subtitle')}</p>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        <Select value={statusFilter} onValueChange={(v) => setStatusFilter(v ?? 'all')}>
          <SelectTrigger className="w-full sm:w-48">
            <SelectValue placeholder={t('filter_status')} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t('filter_all')}</SelectItem>
            <SelectItem value="ACTIVE">{t('status_active')}</SelectItem>
            <SelectItem value="EXPIRED">{t('status_expired')}</SelectItem>
            <SelectItem value="PENDING">{t('status_pending')}</SelectItem>
            <SelectItem value="CANCELLED">{t('status_cancelled')}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CreditCard className="h-5 w-5" />
            {t('title')}
            {!loading && (
              <Badge variant="secondary" className="ml-2">{filtered.length}/{total}</Badge>
            )}
          </CardTitle>
          <CardDescription>{t('subtitle')}</CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="space-y-3">
              {[...Array(5)].map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <p className="text-center text-muted-foreground py-8">{t('no_subscriptions')}</p>
          ) : (
            <>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('artisan')}</TableHead>
                      <TableHead>{t('plan')}</TableHead>
                      <TableHead>{t('status')}</TableHead>
                      <TableHead>{t('amount')}</TableHead>
                      <TableHead>{t('start_date')}</TableHead>
                      <TableHead>{t('expiry_date')}</TableHead>
                      <TableHead>{t('last_payment')}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {filtered.map((s) => (
                      <TableRow key={s.id}>
                        <TableCell className="font-medium">
                          {s.artisan_profile?.first_name} {s.artisan_profile?.last_name}
                        </TableCell>
                        <TableCell>{s.plan}</TableCell>
                        <TableCell>{statusBadge(s.status)}</TableCell>
                        <TableCell>{s.amount_fcfa?.toLocaleString(locale === 'fr' ? 'fr-FR' : 'en-US')} FCFA</TableCell>
                        <TableCell>
                          {s.starts_at ? new Date(s.starts_at).toLocaleDateString(locale === 'fr' ? 'fr-FR' : 'en-US') : '—'}
                        </TableCell>
                        <TableCell>
                          {s.expires_at ? new Date(s.expires_at).toLocaleDateString(locale === 'fr' ? 'fr-FR' : 'en-US') : '—'}
                        </TableCell>
                        <TableCell>
                          {getLastPaymentDate(s.payments || [])}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>

              <div className="flex items-center justify-between mt-4">
                <p className="text-sm text-muted-foreground">
                  Page {page} / {totalPages}
                </p>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={page <= 1}
                  >
                    <ChevronLeft className="h-4 w-4 mr-1" />
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                    disabled={page >= totalPages}
                  >
                    Next
                    <ChevronRight className="h-4 w-4 ml-1" />
                  </Button>
                </div>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
