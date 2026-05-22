'use client';

import { useEffect, useState, useMemo, useCallback } from 'react';
import { getArtisans } from '@/lib/api';
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { ChevronLeft, ChevronRight, Hammer, Search, Star } from 'lucide-react';
import { toast } from 'sonner';
import type { ArtisanProfile } from '@/types';

export default function ArtisansPage() {
  const [artisans, setArtisans] = useState<ArtisanProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [cityFilter, setCityFilter] = useState('all');
  const limit = 50;
  const { t } = useTranslations('artisans');
  const { t: tApp } = useTranslations('app');
  const totalPages = Math.max(1, Math.ceil(total / limit));

  const loadArtisans = useCallback(async () => {
    setLoading(true);
    try {
      const result = await getArtisans(page, limit);
      setArtisans(result.data);
      setTotal(result.total);
    } catch {
      toast.error(tApp('error'));
    } finally {
      setLoading(false);
    }
  }, [page, limit, tApp]);

  const silentRefresh = useCallback(async () => {
    try {
      const result = await getArtisans(page, limit);
      setArtisans(result.data);
      setTotal(result.total);
    } catch {
      // Silent refresh: ignore transient realtime errors.
    }
  }, [page, limit]);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void loadArtisans();
    }, 0);
    return () => window.clearTimeout(timeoutId);
  }, [loadArtisans]);

  useAdminSSE(silentRefresh, {
    eventTypes: [
      'ARTISAN_REGISTERED',
      'ARTISAN_UPDATED',
      'VERIFICATION_REVIEWED',
      'REVIEW_CREATED',
      'REVIEW_DELETED',
      'SUBSCRIPTION_UPDATED',
      'PAYMENT_UPDATED',
    ],
  });

  const cities = useMemo(() => {
    const set = new Set(artisans.map((a) => a.city).filter(Boolean));
    return Array.from(set).sort();
  }, [artisans]);

  const filtered = useMemo(() => {
    return artisans.filter((a) => {
      const matchesSearch =
        !search ||
        `${a.first_name} ${a.last_name} ${a.business_name}`
          .toLowerCase()
          .includes(search.toLowerCase());
      const matchesCity = cityFilter === 'all' || a.city === cityFilter;
      return matchesSearch && matchesCity;
    });
  }, [artisans, search, cityFilter]);

  const subBadge = (status?: string) => {
    switch (status) {
      case 'ACTIVE':
        return <Badge className="bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">{t('sub_active')}</Badge>;
      case 'EXPIRED':
        return <Badge variant="destructive">{t('sub_expired')}</Badge>;
      case 'PENDING':
        return <Badge variant="outline">{t('sub_pending')}</Badge>;
      default:
        return <Badge variant="secondary">—</Badge>;
    }
  };

  const verifBadge = (status?: string) => {
    switch (status) {
      case 'VERIFIED':
        return <Badge className="bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">{t('verif_verified')}</Badge>;
      case 'CERTIFIED':
        return <Badge className="bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200">{t('verif_certified')}</Badge>;
      default:
        return <Badge variant="outline">{t('verif_pending')}</Badge>;
    }
  };

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
        <Select value={cityFilter} onValueChange={(v) => setCityFilter(v ?? 'all')}>
          <SelectTrigger className="w-full sm:w-48">
            <SelectValue placeholder={t('filter_city')} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t('filter_all')}</SelectItem>
            {cities.map((city) => (
              <SelectItem key={city} value={city}>{city}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Hammer className="h-5 w-5" />
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
            <p className="text-center text-muted-foreground py-8">{t('no_artisans')}</p>
          ) : (
            <>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('name')}</TableHead>
                      <TableHead>{t('phone')}</TableHead>
                      <TableHead>{t('business')}</TableHead>
                      <TableHead>{t('city')}</TableHead>
                      <TableHead>{t('category')}</TableHead>
                      <TableHead>{t('subcategory')}</TableHead>
                      <TableHead>{t('rating')}</TableHead>
                      <TableHead>{t('subscription')}</TableHead>
                      <TableHead>{t('verification')}</TableHead>
                      <TableHead>{t('status')}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {filtered.map((a) => (
                      <TableRow key={a.id}>
                        <TableCell className="font-medium">
                          {a.first_name} {a.last_name}
                        </TableCell>
                        <TableCell>{a.user?.phone_number || '—'}</TableCell>
                        <TableCell>{a.business_name}</TableCell>
                        <TableCell>{a.city}, {a.commune}</TableCell>
                        <TableCell>{a.category?.name || '—'}</TableCell>
                        <TableCell>{a.subcategory?.name || '—'}</TableCell>
                        <TableCell>
                          <span className="flex items-center gap-1">
                            <Star className="h-3.5 w-3.5 fill-yellow-400 text-yellow-400" />
                            {a.rating_avg?.toFixed(1) || '—'}
                            <span className="text-xs text-muted-foreground">({a.total_reviews})</span>
                          </span>
                        </TableCell>
                        <TableCell>{subBadge(a.subscription?.status)}</TableCell>
                        <TableCell>{verifBadge(a.user?.verification_status)}</TableCell>
                        <TableCell>
                          {a.user?.is_active ? (
                            <Badge className="bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">{t('active')}</Badge>
                          ) : (
                            <Badge variant="destructive">{t('inactive')}</Badge>
                          )}
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
