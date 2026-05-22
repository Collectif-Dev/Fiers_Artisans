'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import { getPendingVerifications, reviewDocument, fetchFileBlob } from '@/lib/api';
import { useTranslations } from '@/hooks/use-translations';
import { useAdminSSE } from '@/hooks/use-admin-sse';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Textarea } from '@/components/ui/textarea';
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
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { CheckCircle, XCircle, FileText, Loader2, Eye, Download, ChevronLeft, ChevronRight, AlertTriangle, ImageOff } from 'lucide-react';
import { toast } from 'sonner';
import type { VerificationDocument, VerificationDocumentPage } from '@/types';

// ─── Helpers ──────────────────────────────────────────────────────────

/** Extract durable bucket+objectKey from a page, with legacy URL fallback. */
function resolveFileRef(page: VerificationDocumentPage): { bucket: string; objectKey: string | undefined } {
  if (page.object_key) {
    return { bucket: 'documents', objectKey: page.object_key };
  }
  try {
    const url = new URL(page.file_url);
    const parts = url.pathname.split('/').filter(Boolean);
    if (parts.length >= 2) {
      return { bucket: parts[0], objectKey: parts.slice(1).join('/') };
    }
  } catch { /* fall through */ }
  return { bucket: 'documents', objectKey: undefined };
}

function isImageKey(objectKeyOrUrl: string): boolean {
  return /\.(jpe?g|png|webp|gif)(\?|$)/i.test(objectKeyOrUrl);
}

function getPageLabel(page: VerificationDocumentPage): string {
  switch (page.page_role) {
    case 'FRONT': return 'Recto';
    case 'BACK': return 'Verso';
    case 'MAIN': return 'Page principale';
    case 'EXTRA': return `Page ${page.page_order + 1}`;
    default: return `Page ${page.page_order + 1}`;
  }
}

function getDocumentPages(doc: VerificationDocument): VerificationDocumentPage[] {
  if (doc.pages && doc.pages.length > 0) {
    return [...doc.pages].sort((a, b) => a.page_order - b.page_order);
  }
  if (doc.file_url) {
    return [{
      id: 'legacy',
      document_id: doc.id,
      file_url: doc.file_url,
      object_key: doc.object_key,
      page_role: 'MAIN',
      page_order: 0,
      created_at: doc.submitted_at,
    }];
  }
  return [];
}

function isCNIIncomplete(doc: VerificationDocument): boolean {
  if (doc.document_type !== 'CNI') return false;
  const pages = getDocumentPages(doc);
  const roles = pages.map(p => p.page_role);
  return !roles.includes('FRONT') || !roles.includes('BACK');
}

// ─── AuthenticatedPreview: fetches blob via axios, renders image or PDF ─

function AuthenticatedPreview({ page, alt }: { page: VerificationDocumentPage; alt: string }) {
  const { bucket, objectKey } = resolveFileRef(page);
  const [blobUrl, setBlobUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(!!objectKey);
  const [hasError, setHasError] = useState(!objectKey);
  const blobUrlRef = useRef<string | null>(null);

  useEffect(() => {
    if (!objectKey) return;
    let cancelled = false;

    fetchFileBlob(bucket, objectKey)
      .then((blob) => {
        if (cancelled) return;
        const url = URL.createObjectURL(blob);
        blobUrlRef.current = url;
        setBlobUrl(url);
      })
      .catch(() => {
        if (!cancelled) setHasError(true);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
      if (blobUrlRef.current) {
        URL.revokeObjectURL(blobUrlRef.current);
        blobUrlRef.current = null;
      }
    };
  }, [bucket, objectKey]);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center gap-2 p-8">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        <p className="text-sm text-muted-foreground">Chargement…</p>
      </div>
    );
  }

  if (hasError || !blobUrl) {
    return (
      <div className="flex flex-col items-center justify-center gap-2 p-8">
        <ImageOff className="h-10 w-10 text-muted-foreground" />
        <p className="text-muted-foreground text-sm text-center">
          Impossible de charger le fichier.
          <br />
          Le fichier est peut-être manquant ou inaccessible.
        </p>
      </div>
    );
  }

  const fileRef = page.object_key || page.file_url;
  if (isImageKey(fileRef)) {
    return (
      /* eslint-disable-next-line @next/next/no-img-element */
      <img
        src={blobUrl}
        alt={alt}
        className="max-w-full max-h-[60vh] object-contain"
        onError={() => setHasError(true)}
      />
    );
  }

  // PDF or other — render in iframe from blob URL
  return (
    <iframe
      src={blobUrl}
      className="w-full h-[60vh] border-0"
      title={alt}
    />
  );
}

// ─── Main Page ────────────────────────────────────────────────────────

export default function VerificationsPage() {
  const [docs, setDocs] = useState<VerificationDocument[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [rejectDialog, setRejectDialog] = useState<VerificationDocument | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [previewDoc, setPreviewDoc] = useState<VerificationDocument | null>(null);
  const [previewPageIndex, setPreviewPageIndex] = useState(0);
  const limit = 20;
  const { t } = useTranslations('verifications');
  const { t: tApp, locale } = useTranslations('app');
  const totalPages = Math.max(1, Math.ceil(total / limit));

  const loadDocs = useCallback(async () => {
    setLoading(true);
    try {
      const result = await getPendingVerifications(page, limit);
      setDocs(result.data);
      setTotal(result.total);
    } catch {
      toast.error(tApp('error'));
    } finally {
      setLoading(false);
    }
  }, [limit, page, tApp]);

  // Silent refresh (no loading spinner) for SSE and polling
  const silentRefresh = useCallback(async () => {
    try {
      const result = await getPendingVerifications(page, limit);
      setDocs(result.data);
      setTotal(result.total);
    } catch {
      // Silently ignore refresh errors
    }
  }, [limit, page]);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void loadDocs();
    }, 0);
    return () => window.clearTimeout(timeoutId);
  }, [loadDocs]);

  // Real-time: refresh docs on verification events only.
  useAdminSSE(silentRefresh, {
    eventTypes: ['VERIFICATION_SUBMITTED', 'VERIFICATION_REVIEWED'],
  });

  const closePreview = useCallback(() => {
    setPreviewDoc(null);
    setPreviewPageIndex(0);
  }, []);

  const handleApprove = async (doc: VerificationDocument) => {
    if (isCNIIncomplete(doc)) {
      toast.error('Impossible d\'approuver une CNI incomplète (recto et verso requis).');
      return;
    }
    setActionLoading(true);
    try {
      await reviewDocument(doc.id, 'APPROVED');
      toast.success(t('approved_success'));
      setDocs((prev) => prev.filter((d) => d.id !== doc.id));
    } catch {
      toast.error(tApp('error'));
    } finally {
      setActionLoading(false);
    }
  };

  const handleApproveFromPreview = async () => {
    if (!previewDoc) return;
    const doc = previewDoc;
    closePreview();
    await handleApprove(doc);
  };

  const handleRejectFromPreview = () => {
    if (!previewDoc) return;
    const doc = previewDoc;
    closePreview();
    setRejectDialog(doc);
  };

  const handleReject = async () => {
    if (!rejectDialog || !rejectReason.trim()) return;
    setActionLoading(true);
    try {
      await reviewDocument(rejectDialog.id, 'REJECTED', rejectReason.trim());
      toast.success(t('rejected_success'));
      setDocs((prev) => prev.filter((d) => d.id !== rejectDialog.id));
      setRejectDialog(null);
      setRejectReason('');
    } catch {
      toast.error(tApp('error'));
    } finally {
      setActionLoading(false);
    }
  };

  /** Download current page via authenticated fetch → programmatic save */
  const handleDownload = async (page: VerificationDocumentPage) => {
    const { bucket, objectKey } = resolveFileRef(page);
    if (!objectKey) {
      toast.error('Référence fichier manquante.');
      return;
    }
    try {
      const blob = await fetchFileBlob(bucket, objectKey);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = objectKey;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch {
      toast.error('Erreur lors du téléchargement.');
    }
  };

  const openPreview = (doc: VerificationDocument) => {
    setPreviewPageIndex(0);
    setPreviewDoc(doc);
  };

  // Derive preview data outside JSX to avoid IIFE
  const previewPages = previewDoc ? getDocumentPages(previewDoc) : [];
  const safePageIndex = Math.min(previewPageIndex, Math.max(0, previewPages.length - 1));
  const currentPreviewPage = previewPages[safePageIndex] ?? null;
  const hasMultiplePreviewPages = previewPages.length > 1;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">{t('title')}</h2>
        <p className="text-muted-foreground">{t('subtitle')}</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <FileText className="h-5 w-5" />
            {t('title')}
            {!loading && (
              <Badge variant="secondary" className="ml-2">{docs.length}/{total}</Badge>
            )}
          </CardTitle>
          <CardDescription>{t('subtitle')}</CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="space-y-3">
              {[...Array(3)].map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : docs.length === 0 ? (
            <p className="text-center text-muted-foreground py-8">{t('no_pending')}</p>
          ) : (
            <>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t('document_type')}</TableHead>
                    <TableHead>{t('submitted_by')}</TableHead>
                    <TableHead>{t('submitted_at')}</TableHead>
                    <TableHead>Pages</TableHead>
                    <TableHead>{t('document')}</TableHead>
                    <TableHead>{t('status')}</TableHead>
                    <TableHead className="text-right">{t('actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {docs.map((doc) => {
                    const pages = getDocumentPages(doc);
                    const incomplete = isCNIIncomplete(doc);
                    return (
                      <TableRow key={doc.id}>
                        <TableCell className="font-medium">
                          {doc.document_type}
                          {incomplete && (
                            <Badge variant="destructive" className="ml-2 text-xs">
                              <AlertTriangle className="h-3 w-3 mr-1" />
                              Incomplet
                            </Badge>
                          )}
                        </TableCell>
                        <TableCell>{doc.user?.phone_number || doc.user_id.slice(0, 8)}</TableCell>
                        <TableCell>
                          {new Date(doc.submitted_at).toLocaleDateString(locale === 'fr' ? 'fr-FR' : 'en-US')}
                        </TableCell>
                        <TableCell>
                          <Badge variant="outline">{pages.length} page{pages.length > 1 ? 's' : ''}</Badge>
                        </TableCell>
                        <TableCell>
                          <Button
                            size="sm"
                            variant="ghost"
                            className="h-8 px-2"
                            onClick={() => openPreview(doc)}
                            title={t('preview')}
                          >
                            <Eye className="h-4 w-4 mr-1" />
                            Voir
                          </Button>
                        </TableCell>
                        <TableCell>
                          <Badge variant="outline">{t('status_pending') || 'PENDING'}</Badge>
                        </TableCell>
                        <TableCell className="text-right space-x-2">
                          <Button
                            size="sm"
                            variant="outline"
                            className="text-green-600 hover:text-green-700"
                            onClick={() => handleApprove(doc)}
                            disabled={actionLoading || incomplete}
                            title={incomplete ? 'CNI incomplète' : ''}
                          >
                            <CheckCircle className="mr-1 h-4 w-4" />
                            {t('approve')}
                          </Button>
                          <Button
                            size="sm"
                            variant="outline"
                            className="text-destructive hover:text-destructive"
                            onClick={() => setRejectDialog(doc)}
                            disabled={actionLoading}
                          >
                            <XCircle className="mr-1 h-4 w-4" />
                            {t('reject')}
                          </Button>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>

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

      {/* Document preview dialog — fully React-controlled, authenticated blob loading */}
      <Dialog open={!!previewDoc} onOpenChange={(open) => { if (!open) closePreview(); }}>
        <DialogContent className="max-w-3xl max-h-[85vh]">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <FileText className="h-5 w-5" />
              {previewDoc?.document_type}
              {previewDoc && isCNIIncomplete(previewDoc) && (
                <Badge variant="destructive" className="text-xs">
                  <AlertTriangle className="h-3 w-3 mr-1" />
                  CNI incomplète
                </Badge>
              )}
            </DialogTitle>
            <DialogDescription>
              {previewDoc?.user?.phone_number || previewDoc?.user_id?.slice(0, 8) || ''}
              {previewDoc ? ' — ' : ''}
              {previewDoc ? new Date(previewDoc.submitted_at).toLocaleDateString(locale === 'fr' ? 'fr-FR' : 'en-US') : ''}
            </DialogDescription>
          </DialogHeader>

          {/* Page tabs */}
          {hasMultiplePreviewPages && (
            <div className="flex gap-2 overflow-x-auto pb-2">
              {previewPages.map((page, idx) => (
                <button
                  key={page.id}
                  onClick={() => setPreviewPageIndex(idx)}
                  className={`flex-shrink-0 rounded-md border-2 px-3 py-1.5 text-xs font-medium transition-colors ${
                    idx === safePageIndex
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-muted hover:border-muted-foreground/50'
                  }`}
                >
                  {getPageLabel(page)}
                </button>
              ))}
            </div>
          )}

          {/* Current page — authenticated blob fetch via axios */}
          <div className="flex-1 overflow-auto rounded-md border bg-muted/50 min-h-[300px] flex items-center justify-center relative">
            {currentPreviewPage ? (
              <AuthenticatedPreview
                key={currentPreviewPage.id}
                page={currentPreviewPage}
                alt={`${previewDoc?.document_type} - ${getPageLabel(currentPreviewPage)}`}
              />
            ) : (
              <p className="text-muted-foreground">{t('no_file')}</p>
            )}

            {/* Navigation arrows */}
            {hasMultiplePreviewPages && safePageIndex > 0 && (
              <button
                onClick={() => setPreviewPageIndex(i => i - 1)}
                className="absolute left-2 top-1/2 -translate-y-1/2 bg-background/80 rounded-full p-1.5 shadow hover:bg-background"
              >
                <ChevronLeft className="h-5 w-5" />
              </button>
            )}
            {hasMultiplePreviewPages && safePageIndex < previewPages.length - 1 && (
              <button
                onClick={() => setPreviewPageIndex(i => i + 1)}
                className="absolute right-2 top-1/2 -translate-y-1/2 bg-background/80 rounded-full p-1.5 shadow hover:bg-background"
              >
                <ChevronRight className="h-5 w-5" />
              </button>
            )}
          </div>

          {/* Page label */}
          {currentPreviewPage && (
            <p className="text-center text-sm text-muted-foreground">
              {getPageLabel(currentPreviewPage)}
              {hasMultiplePreviewPages && ` (${safePageIndex + 1}/${previewPages.length})`}
            </p>
          )}

          <DialogFooter className="flex-row justify-between sm:justify-between gap-2">
            <div className="flex gap-2">
              {currentPreviewPage && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleDownload(currentPreviewPage)}
                >
                  <Download className="mr-1 h-4 w-4" />
                  {t('download')}
                </Button>
              )}
            </div>
            <div className="flex gap-2">
              <Button
                size="sm"
                className="bg-green-600 hover:bg-green-700 text-white"
                onClick={handleApproveFromPreview}
                disabled={actionLoading || (previewDoc ? isCNIIncomplete(previewDoc) : false)}
              >
                <CheckCircle className="mr-1 h-4 w-4" />
                {t('approve')}
              </Button>
              <Button
                size="sm"
                variant="destructive"
                onClick={handleRejectFromPreview}
                disabled={actionLoading}
              >
                <XCircle className="mr-1 h-4 w-4" />
                {t('reject')}
              </Button>
            </div>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Reject dialog */}
      <Dialog open={!!rejectDialog} onOpenChange={(open) => { if (!open) { setRejectDialog(null); setRejectReason(''); } }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('reject')}</DialogTitle>
            <DialogDescription>{t('confirm_reject')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <Textarea
              placeholder={t('reject_reason_placeholder')}
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
            {rejectReason.trim() === '' && (
              <p className="text-xs text-destructive">{t('reject_reason_required')}</p>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => { setRejectDialog(null); setRejectReason(''); }}>
              {tApp('cancel')}
            </Button>
            <Button
              variant="destructive"
              onClick={handleReject}
              disabled={!rejectReason.trim() || actionLoading}
            >
              {actionLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {t('reject')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
