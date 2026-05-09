'use client';

import { useEffect, useState, useCallback } from 'react';
import { getLogs } from '@/lib/api';
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
import { FileText, ChevronLeft, ChevronRight } from 'lucide-react';
import { toast } from 'sonner';
import type { ActivityLog } from '@/types';

const ACTION_TYPES = [
  'SEARCH',
  'PROFILE_VIEW',
  'CONTACT_CLICK',
  'LOGIN',
  'PAYMENT_ATTEMPT',
  'REGISTRATION',
  'SUBSCRIPTION_UPDATED',
  'PAYMENT_MANUAL_INITIATED',
  'PROOF_SUBMITTED',
  'PROOF_VALIDATED',
  'PAYMENT_MANUAL_REJECTED',
  'PAYMENT_MANUAL_REOPENED',
  'PAYMENT_MANUAL_EXPIRED',
  'PAYMENT_MANUAL_SOFT_DELETED',
  'REFUND_PROCESSED',
] as const;

export default function LogsPage() {
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [actionFilter, setActionFilter] = useState('all');
  const limit = 50;
  const { t, locale } = useTranslations('logs');
  const { t: tApp } = useTranslations('app');

  const totalPages = Math.max(1, Math.ceil(total / limit));

  const loadLogs = useCallback(async () => {
    setLoading(true);
    try {
      const action = actionFilter === 'all' ? undefined : actionFilter;
      const result = await getLogs(page, limit, action);
      setLogs(result.data);
      setTotal(result.total);
    } catch {
      toast.error(tApp('error'));
    } finally {
      setLoading(false);
    }
  }, [page, limit, actionFilter, tApp]);

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  const silentRefresh = useCallback(async () => {
    try {
      const action = actionFilter === 'all' ? undefined : actionFilter;
      const result = await getLogs(page, limit, action);
      setLogs(result.data);
      setTotal(result.total);
    } catch {
      // Silent refresh: ignore transient realtime errors.
    }
  }, [actionFilter, page, limit]);

  useAdminSSE(silentRefresh, {
    eventTypes: ['ACTIVITY_LOGGED'],
    minRefreshIntervalMs: 1200,
  });

  const handleActionChange = (value: string | null) => {
    setActionFilter(value ?? 'all');
    setPage(1);
  };

  const actionBadge = (action: string) => {
    switch (action) {
      case 'LOGIN':
        return <Badge className="bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">{action}</Badge>;
      case 'REGISTRATION':
        return <Badge className="bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">{action}</Badge>;
      case 'PAYMENT_ATTEMPT':
        return <Badge className="bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200">{action}</Badge>;
      case 'SEARCH':
        return <Badge variant="secondary">{action}</Badge>;
      case 'PROFILE_VIEW':
        return <Badge variant="outline">{action}</Badge>;
      case 'CONTACT_CLICK':
        return <Badge className="bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200">{action}</Badge>;
      default:
        return <Badge variant="outline">{action}</Badge>;
    }
  };

  const formatMetadata = (metadata?: Record<string, unknown>) => {
    if (!metadata || Object.keys(metadata).length === 0) return '—';
    return (
      <details className="cursor-pointer">
        <summary className="text-xs text-muted-foreground">JSON</summary>
        <pre className="text-xs mt-1 max-w-xs overflow-auto bg-muted p-2 rounded">
          {JSON.stringify(metadata, null, 2)}
        </pre>
      </details>
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">{t('title')}</h2>
        <p className="text-muted-foreground">{t('subtitle')}</p>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        <Select value={actionFilter} onValueChange={handleActionChange}>
          <SelectTrigger className="w-full sm:w-48">
            <SelectValue placeholder={t('filter_action')} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t('filter_all')}</SelectItem>
            {ACTION_TYPES.map((action) => (
              <SelectItem key={action} value={action}>{action}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <FileText className="h-5 w-5" />
            {t('title')}
            {!loading && (
              <Badge variant="secondary" className="ml-2">{total}</Badge>
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
          ) : logs.length === 0 ? (
            <p className="text-center text-muted-foreground py-8">{t('no_logs')}</p>
          ) : (
            <>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('action')}</TableHead>
                      <TableHead>{t('actor_id')}</TableHead>
                      <TableHead>{t('target_id')}</TableHead>
                      <TableHead>{t('metadata')}</TableHead>
                      <TableHead>{t('timestamp')}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {logs.map((log) => (
                      <TableRow key={log._id}>
                        <TableCell>{actionBadge(log.action)}</TableCell>
                        <TableCell className="font-mono text-xs">
                          {log.actorId || '—'}
                        </TableCell>
                        <TableCell className="font-mono text-xs">
                          {log.targetId || '—'}
                        </TableCell>
                        <TableCell>{formatMetadata(log.metadata)}</TableCell>
                        <TableCell>
                          {new Date(log.timestamp).toLocaleString(locale === 'fr' ? 'fr-FR' : 'en-US')}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>

              {/* Pagination */}
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
                    {t('previous')}
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                    disabled={page >= totalPages}
                  >
                    {t('next')}
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
