'use client';

import { useEffect, useState, useMemo, useCallback } from 'react';
import { getReviews, deleteReview } from '@/lib/api';
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Star, Trash2, Loader2, ChevronLeft, ChevronRight } from 'lucide-react';
import { toast } from 'sonner';
import type { ReviewRecord } from '@/types';

function StarRating({ rating }: { rating: number }) {
  return (
    <span className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map((i) => (
        <Star
          key={i}
          className={`h-3.5 w-3.5 ${
            i <= rating
              ? 'fill-yellow-400 text-yellow-400'
              : 'text-muted-foreground'
          }`}
        />
      ))}
    </span>
  );
}

export default function ReviewsPage() {
  const [reviews, setReviews] = useState<ReviewRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [ratingFilter, setRatingFilter] = useState('all');
  const [deleteDialog, setDeleteDialog] = useState<ReviewRecord | null>(null);
  const limit = 50;
  const { t, locale } = useTranslations('reviews');
  const { t: tApp } = useTranslations('app');
  const totalPages = Math.max(1, Math.ceil(total / limit));

  const loadReviews = useCallback(async () => {
    setLoading(true);
    try {
      const result = await getReviews(page, limit);
      setReviews(result.data);
      setTotal(result.total);
    } catch {
      toast.error(tApp('error'));
    } finally {
      setLoading(false);
    }
  }, [page, limit, tApp]);

  useEffect(() => {
    loadReviews();
  }, [loadReviews]);

  const silentRefresh = useCallback(async () => {
    try {
      const result = await getReviews(page, limit);
      setReviews(result.data);
      setTotal(result.total);
    } catch {
      // Silent refresh: ignore transient realtime errors.
    }
  }, [page, limit]);

  useAdminSSE(silentRefresh, {
    eventTypes: ['REVIEW_CREATED', 'REVIEW_REPLIED', 'REVIEW_DELETED'],
  });

  const filtered = useMemo(() => {
    return reviews.filter((r) => {
      return ratingFilter === 'all' || r.rating === Number(ratingFilter);
    });
  }, [reviews, ratingFilter]);

  const handleDelete = async () => {
    if (!deleteDialog) return;
    setActionLoading(true);
    try {
      await deleteReview(deleteDialog.id);
      toast.success(t('deleted_success'));
      setDeleteDialog(null);
      await loadReviews();
    } catch {
      toast.error(tApp('error'));
    } finally {
      setActionLoading(false);
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
        <Select value={ratingFilter} onValueChange={(v) => setRatingFilter(v ?? 'all')}>
          <SelectTrigger className="w-full sm:w-48">
            <SelectValue placeholder={t('filter_rating')} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t('filter_all')}</SelectItem>
            {[1, 2, 3, 4, 5].map((r) => (
              <SelectItem key={r} value={String(r)}>{'⭐'.repeat(r)} ({r})</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Star className="h-5 w-5" />
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
            <p className="text-center text-muted-foreground py-8">{t('no_reviews')}</p>
          ) : (
            <>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('client')}</TableHead>
                      <TableHead>{t('artisan')}</TableHead>
                      <TableHead>{t('rating')}</TableHead>
                      <TableHead>{t('comment')}</TableHead>
                      <TableHead>{t('date')}</TableHead>
                      <TableHead className="text-right">{t('actions')}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {filtered.map((r) => (
                      <TableRow key={r.id}>
                        <TableCell className="font-medium">
                          {r.client?.first_name} {r.client?.last_name}
                        </TableCell>
                        <TableCell>
                          {r.artisan?.first_name} {r.artisan?.last_name}
                        </TableCell>
                        <TableCell>
                          <StarRating rating={r.rating} />
                        </TableCell>
                        <TableCell className="max-w-xs truncate">
                          <div className="space-y-1">
                            <div className="truncate">{r.comment || '—'}</div>
                            {r.artisan_reply && (
                              <div className="rounded-md border border-primary/30 bg-primary/5 px-2 py-1 text-xs">
                                <span className="font-semibold">{t('artisan_reply')}:</span>{' '}
                                {r.artisan_reply}
                              </div>
                            )}
                          </div>
                        </TableCell>
                        <TableCell>
                          {new Date(r.created_at).toLocaleDateString(locale === 'fr' ? 'fr-FR' : 'en-US')}
                        </TableCell>
                        <TableCell className="text-right">
                          <Button
                            size="sm"
                            variant="outline"
                            className="text-destructive hover:text-destructive"
                            onClick={() => setDeleteDialog(r)}
                            disabled={actionLoading}
                          >
                            <Trash2 className="mr-1 h-4 w-4" />
                            {t('delete')}
                          </Button>
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

      {/* Delete confirmation dialog */}
      <Dialog open={!!deleteDialog} onOpenChange={() => setDeleteDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('delete')}</DialogTitle>
            <DialogDescription>{t('confirm_delete')}</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialog(null)}>
              {tApp('cancel')}
            </Button>
            <Button
              variant="destructive"
              onClick={handleDelete}
              disabled={actionLoading}
            >
              {actionLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {t('delete')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
