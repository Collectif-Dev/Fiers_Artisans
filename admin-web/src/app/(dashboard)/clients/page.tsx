'use client';

import { useEffect, useState, useMemo, useCallback } from 'react';
import { getClients } from '@/lib/api';
import { useTranslations } from '@/hooks/use-translations';
import { useAdminSSE } from '@/hooks/use-admin-sse';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
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
import { ChevronLeft, ChevronRight, Users, Search } from 'lucide-react';
import { toast } from 'sonner';
import type { ClientProfile } from '@/types';

export default function ClientsPage() {
  const [clients, setClients] = useState<ClientProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const limit = 50;
  const { t, locale } = useTranslations('clients');
  const { t: tApp } = useTranslations('app');
  const totalPages = Math.max(1, Math.ceil(total / limit));

  const loadClients = useCallback(async () => {
    setLoading(true);
    try {
      const result = await getClients(page, limit);
      setClients(result.data);
      setTotal(result.total);
    } catch {
      toast.error(tApp('error'));
    } finally {
      setLoading(false);
    }
  }, [page, limit, tApp]);

  const silentRefresh = useCallback(async () => {
    try {
      const result = await getClients(page, limit);
      setClients(result.data);
      setTotal(result.total);
    } catch {
      // Silent refresh: ignore transient realtime errors.
    }
  }, [page, limit]);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void loadClients();
    }, 0);
    return () => window.clearTimeout(timeoutId);
  }, [loadClients]);

  useAdminSSE(silentRefresh, {
    eventTypes: ['CLIENT_REGISTERED', 'CLIENT_UPDATED'],
  });

  const filtered = useMemo(() => {
    return clients.filter((c) => {
      if (!search) return true;
      return `${c.first_name} ${c.last_name}`
        .toLowerCase()
        .includes(search.toLowerCase());
    });
  }, [clients, search]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">{t('title')}</h2>
        <p className="text-muted-foreground">{t('subtitle')}</p>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder={tApp('search')}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
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
            <p className="text-center text-muted-foreground py-8">{t('no_clients')}</p>
          ) : (
            <>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('name')}</TableHead>
                      <TableHead>{t('phone')}</TableHead>
                      <TableHead>{t('city')}</TableHead>
                      <TableHead>{t('status')}</TableHead>
                      <TableHead>{t('verified')}</TableHead>
                      <TableHead>{t('joined')}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {filtered.map((c) => (
                      <TableRow key={c.id}>
                        <TableCell className="font-medium">
                          {c.first_name} {c.last_name}
                        </TableCell>
                        <TableCell>{c.user?.phone_number || '—'}</TableCell>
                        <TableCell>{c.city}{c.commune ? `, ${c.commune}` : ''}</TableCell>
                        <TableCell>
                          {c.user?.is_active ? (
                            <Badge className="bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">{t('active')}</Badge>
                          ) : (
                            <Badge variant="destructive">{t('inactive')}</Badge>
                          )}
                        </TableCell>
                        <TableCell>
                          {c.user?.is_phone_verified ? (
                            <Badge className="bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">{t('yes')}</Badge>
                          ) : (
                            <Badge variant="outline">{t('no')}</Badge>
                          )}
                        </TableCell>
                        <TableCell>
                          {new Date(c.created_at).toLocaleDateString(locale === 'fr' ? 'fr-FR' : 'en-US')}
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
