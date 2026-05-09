"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  getManualPayments,
  getManualPaymentDetails,
  validateManualPayment,
  rejectManualPayment,
  reopenManualPayment,
  markManualPaymentRefunded,
  deleteManualPayment,
  fetchFileBlob,
} from "@/lib/api";
import { useTranslations } from "@/hooks/use-translations";
import { useAdminSSE } from "@/hooks/use-admin-sse";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import {
  ChevronLeft,
  ChevronRight,
  WalletCards,
  AlertTriangle,
} from "lucide-react";
import type { PaymentManualRecord } from "@/types";

const PAGE_SIZE = 20;

function formatProvider(provider: string): string {
  return provider.replace(/_/g, " ");
}

function parseImageRef(
  ref?: string,
): { bucket: string; objectKey: string } | null {
  if (!ref) return null;
  const parts = ref.replace(/^\/+/, "").split("/");
  if (parts.length < 2) return null;
  return { bucket: parts[0], objectKey: parts.slice(1).join("/") };
}

export default function PaymentManualPage() {
  const { t, locale } = useTranslations("payment_manual");
  const { t: tApp } = useTranslations("app");

  const [items, setItems] = useState<PaymentManualRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [status, setStatus] = useState("all");

  const [selected, setSelected] = useState<PaymentManualRecord | null>(null);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [actionLoading, setActionLoading] = useState(false);
  const [proofPreviewUrl, setProofPreviewUrl] = useState<string | null>(null);
  const [proofZoomOpen, setProofZoomOpen] = useState(false);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const load = useCallback(
    async (showLoading = true) => {
      if (showLoading) setLoading(true);
      try {
        const result = await getManualPayments(page, PAGE_SIZE, status);
        setItems(result.data);
        setTotal(result.total);
      } catch {
        toast.error(tApp("error"));
      } finally {
        if (showLoading) setLoading(false);
      }
    },
    [page, status, tApp],
  );

  useEffect(() => {
    void load(true);
  }, [load]);

  useEffect(() => {
    const queryStatus = new URLSearchParams(window.location.search).get(
      "status",
    );
    if (queryStatus) {
      setStatus(queryStatus);
      setPage(1);
    }
  }, []);

  useAdminSSE(
    () => {
      void load(false);
    },
    {
      eventTypes: ["PAYMENT_MANUAL_NEW_PROOF", "PAYMENT_MANUAL_UPDATED"],
    },
  );

  const openDetails = useCallback(
    async (id: string) => {
      setDetailsOpen(true);
      setDetailsLoading(true);
      setProofPreviewUrl(null);
      setRejectReason("");
      try {
        const details = await getManualPaymentDetails(id);
        setSelected(details);

        const latestProof = details.proofs?.[0];
        const parsed = parseImageRef(latestProof?.image_url);
        if (parsed) {
          const blob = await fetchFileBlob(parsed.bucket, parsed.objectKey);
          setProofPreviewUrl(URL.createObjectURL(blob));
        }
      } catch {
        toast.error(tApp("error"));
        setDetailsOpen(false);
      } finally {
        setDetailsLoading(false);
      }
    },
    [tApp],
  );

  useEffect(() => {
    return () => {
      if (proofPreviewUrl) {
        URL.revokeObjectURL(proofPreviewUrl);
      }
    };
  }, [proofPreviewUrl]);

  const closeDetails = () => {
    if (proofPreviewUrl) {
      URL.revokeObjectURL(proofPreviewUrl);
    }
    setProofPreviewUrl(null);
    setSelected(null);
    setRejectReason("");
    setProofZoomOpen(false);
    setDetailsOpen(false);
  };

  const applyAction = async (
    action: "validate" | "reject" | "refund" | "reopen" | "delete",
  ) => {
    if (!selected) return;
    if (action === "reject" && rejectReason.trim().length < 5) {
      toast.error(t("reason"));
      return;
    }

    setActionLoading(true);
    try {
      if (action === "validate") {
        await validateManualPayment(selected.id);
      } else if (action === "reject") {
        await rejectManualPayment(selected.id, rejectReason.trim());
      } else if (action === "reopen") {
        await reopenManualPayment(
          selected.id,
          rejectReason.trim().length >= 5 ? rejectReason.trim() : undefined,
        );
      } else if (action === "delete") {
        await deleteManualPayment(selected.id);
      } else {
        await markManualPaymentRefunded(selected.id);
      }
      toast.success(tApp("save"));
      closeDetails();
      await load(false);
    } catch {
      toast.error(tApp("error"));
    } finally {
      setActionLoading(false);
    }
  };

  const statusBadge = (record: PaymentManualRecord) => {
    if (record.refund_required) {
      return <Badge variant="destructive">{t("status_refund_required")}</Badge>;
    }

    if (record.status === "COMPLETED") {
      return (
        <Badge className="bg-green-100 text-green-900">
          {t("status_completed")}
        </Badge>
      );
    }
    if (record.status === "REJECTED") {
      return <Badge variant="destructive">{t("status_rejected")}</Badge>;
    }
    if (record.status === "PENDING_ADMIN") {
      return (
        <Badge className="bg-yellow-100 text-yellow-900">
          {t("status_pending_admin")}
        </Badge>
      );
    }
    if (record.status === "PENDING") {
      return <Badge variant="secondary">{t("status_pending")}</Badge>;
    }
    return <Badge variant="outline">{t("status_expired")}</Badge>;
  };

  const statusLabelMap = useMemo(
    () => ({
      all: t("status_all"),
      PENDING: t("status_pending"),
      PENDING_ADMIN: t("status_pending_admin"),
      COMPLETED: t("status_completed"),
      REJECTED: t("status_rejected"),
      EXPIRED: t("status_expired"),
      REFUND_REQUIRED: t("status_refund_required"),
    }),
    [t],
  );

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">{t("title")}</h2>
        <p className="text-muted-foreground">{t("subtitle")}</p>
      </div>

      <div className="flex gap-3 flex-wrap">
        <Select
          value={status}
          onValueChange={(value) => {
            setStatus(value || "all");
            setPage(1);
          }}
        >
          <SelectTrigger className="w-[220px]">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {Object.entries(statusLabelMap).map(([value, label]) => (
              <SelectItem key={value} value={value}>
                {label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <WalletCards className="h-5 w-5" />
            {t("title")}
            {!loading && (
              <Badge variant="secondary">
                {items.length}/{total}
              </Badge>
            )}
          </CardTitle>
          <CardDescription>{t("subtitle")}</CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="space-y-3">
              {[...Array(5)].map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : items.length === 0 ? (
            <p className="text-sm text-muted-foreground py-10 text-center">
              {t("no_data")}
            </p>
          ) : (
            <>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t("transaction_id")}</TableHead>
                      <TableHead>{t("client")}</TableHead>
                      <TableHead>{t("amount")}</TableHead>
                      <TableHead>{t("provider")}</TableHead>
                      <TableHead>{t("sender_number")}</TableHead>
                      <TableHead>{t("submitted_at")}</TableHead>
                      <TableHead>{t("status")}</TableHead>
                      <TableHead className="text-right">
                        {t("actions")}
                      </TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {items.map((item) => (
                      <TableRow key={item.id}>
                        <TableCell className="font-medium">
                          {item.transaction_id}
                        </TableCell>
                        <TableCell>
                          {item.subscription?.artisan_profile?.user
                            ?.phone_number || "—"}
                        </TableCell>
                        <TableCell>
                          {item.amount_fcfa.toLocaleString(
                            locale === "fr" ? "fr-FR" : "en-US",
                          )}{" "}
                          FCFA
                        </TableCell>
                        <TableCell>{formatProvider(item.provider)}</TableCell>
                        <TableCell>{item.sender_number || "—"}</TableCell>
                        <TableCell>
                          {new Date(item.created_at).toLocaleString(
                            locale === "fr" ? "fr-FR" : "en-US",
                          )}
                        </TableCell>
                        <TableCell>{statusBadge(item)}</TableCell>
                        <TableCell className="text-right">
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => void openDetails(item.id)}
                          >
                            {t("details")}
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
                    disabled={page <= 1}
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                  >
                    <ChevronLeft className="h-4 w-4 mr-1" />
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    disabled={page >= totalPages}
                    onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
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

      <Dialog
        open={detailsOpen}
        onOpenChange={(open) => (!open ? closeDetails() : setDetailsOpen(true))}
      >
        <DialogContent className="max-w-3xl max-h-[88vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{t("details")}</DialogTitle>
            <DialogDescription>
              {selected?.transaction_id || "—"}
            </DialogDescription>
          </DialogHeader>

          {detailsLoading || !selected ? (
            <Skeleton className="h-64 w-full" />
          ) : (
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
              <div className="space-y-3">
                {proofPreviewUrl ? (
                  <button
                    type="button"
                    className="w-full rounded border bg-black/20"
                    onClick={() => setProofZoomOpen(true)}
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={proofPreviewUrl}
                      alt="proof"
                      className="w-full rounded max-h-[70vh] object-contain"
                    />
                  </button>
                ) : (
                  <div className="h-[240px] rounded border flex items-center justify-center text-muted-foreground text-sm">
                    {t("proofs")}
                  </div>
                )}

                {selected.proofs?.[0]?.is_suspected_fraud && (
                  <div className="p-3 rounded border border-destructive text-destructive text-sm flex items-center gap-2">
                    <AlertTriangle className="h-4 w-4" />
                    {t("fraud_alert")}
                  </div>
                )}
              </div>

              <div className="space-y-3 text-sm">
                <p>
                  <strong>{t("status")}:</strong> {selected.status}
                </p>
                <p>
                  <strong>{t("amount")}:</strong> {selected.amount_fcfa} FCFA
                </p>
                <p>
                  <strong>{t("provider")}:</strong>{" "}
                  {formatProvider(selected.provider)}
                </p>
                <p>
                  <strong>{t("sender_number")}:</strong>{" "}
                  {selected.sender_number || "—"}
                </p>
                <p>
                  <strong>{t("proofs")}:</strong> {selected.proofs?.length || 0}
                </p>
                <p>
                  <strong>{t("timeline")}:</strong>{" "}
                  {selected.timeline?.length || 0}
                </p>

                <Input
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder={t("reason")}
                />
              </div>
            </div>
          )}

          <DialogFooter className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              onClick={closeDetails}
              disabled={actionLoading}
            >
              {tApp("cancel")}
            </Button>
            <Button
              onClick={() => void applyAction("validate")}
              disabled={
                actionLoading ||
                !selected ||
                selected.status !== "PENDING_ADMIN"
              }
            >
              {t("validate")}
            </Button>
            <Button
              variant="destructive"
              onClick={() => void applyAction("reject")}
              disabled={
                actionLoading ||
                !selected ||
                selected.status !== "PENDING_ADMIN"
              }
            >
              {t("reject")}
            </Button>
            <Button
              variant="secondary"
              onClick={() => void applyAction("refund")}
              disabled={actionLoading || !selected?.refund_required}
            >
              {t("mark_refunded")}
            </Button>
            <Button
              variant="secondary"
              onClick={() => void applyAction("reopen")}
              disabled={
                actionLoading ||
                !selected ||
                !(
                  ["REJECTED", "EXPIRED", "COMPLETED"].includes(
                    selected.status,
                  ) || Boolean(selected.refund_done_at)
                )
              }
            >
              {t("reopen")}
            </Button>
            <Button
              variant="secondary"
              onClick={() => void applyAction("delete")}
              disabled={
                actionLoading ||
                !selected ||
                !(
                  ["REJECTED", "EXPIRED", "COMPLETED"].includes(
                    selected.status,
                  ) || Boolean(selected.refund_done_at)
                )
              }
            >
              {t("delete")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={proofZoomOpen} onOpenChange={setProofZoomOpen}>
        <DialogContent className="max-w-5xl max-h-[92vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{t("proofs")}</DialogTitle>
          </DialogHeader>
          {proofPreviewUrl ? (
            <div className="w-full rounded border bg-black/20 p-2">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={proofPreviewUrl}
                alt="proof-large"
                className="w-full max-h-[82vh] object-contain"
              />
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">{t("no_data")}</p>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
