"use client";

import { useState } from "react";
import { useAuth } from "@/hooks/use-auth";
import { useTranslations } from "@/hooks/use-translations";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Hammer, Loader2 } from "lucide-react";

const PHONE_REGEX = /^\d{10}$/;
const normalizePhone = (value: string) => {
  const digits = value.replace(/\D/g, "");
  const localDigits =
    digits.length === 13 && digits.startsWith("225") ? digits.slice(3) : digits;
  return localDigits.slice(0, 10);
};

export default function LoginPage() {
  const [phone, setPhone] = useState("");
  const [pinCode, setPinCode] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const { t } = useTranslations("login");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    const normalizedPhone = normalizePhone(phone);
    if (!PHONE_REGEX.test(normalizedPhone)) {
      setError(t("error_phone"));
      return;
    }

    setLoading(true);
    try {
      await login(normalizedPhone, pinCode);
      // Prefer a full navigation after login to avoid occasional RSC payload fetch failures in dev.
      window.location.assign("/");
    } catch (err: unknown) {
      if (err instanceof Error && err.message === "NOT_ADMIN") {
        setError(t("error_role"));
      } else {
        setError(t("error_credentials"));
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-muted/30 p-4">
      <Card className="w-full max-w-sm">
        <CardHeader className="text-center">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-xl bg-primary">
            <Hammer className="h-7 w-7 text-primary-foreground" />
          </div>
          <CardTitle className="text-xl">{t("title")}</CardTitle>
          <CardDescription>{t("subtitle")}</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="phone">{t("phone")}</Label>
              <Input
                id="phone"
                type="tel"
                inputMode="numeric"
                pattern="[0-9]{10}"
                maxLength={10}
                placeholder={t("phone_placeholder")}
                value={phone}
                onChange={(e) => setPhone(normalizePhone(e.target.value))}
                onPaste={(e) => {
                  const pasted = e.clipboardData.getData("text");
                  const normalized = normalizePhone(pasted);
                  if (normalized !== pasted) {
                    e.preventDefault();
                    setPhone(normalized);
                  }
                }}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="pinCode">{t("password")}</Label>
              <Input
                id="pinCode"
                type="password"
                inputMode="numeric"
                pattern="[0-9]{5}"
                maxLength={5}
                autoComplete="off"
                value={pinCode}
                onChange={(e) =>
                  setPinCode(e.target.value.replace(/\D/g, "").slice(0, 5))
                }
                required
              />
            </div>
            {error && (
              <p className="text-sm text-destructive text-center">{error}</p>
            )}
            <Button type="submit" className="w-full" disabled={loading}>
              {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {t("submit")}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
