'use client';

import { useAuth } from '@/hooks/use-auth';
import { useTranslations } from '@/hooks/use-translations';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { LogOut, Globe, Menu } from 'lucide-react';
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet';
import { MobileSidebar } from './mobile-sidebar';

export function Topbar() {
  const { user, logout } = useAuth();
  const { t, locale, setLocale } = useTranslations('app');

  return (
    <header className="sticky top-0 z-30 flex h-14 items-center gap-4 border-b bg-card px-4 md:px-6">
      {/* Mobile menu */}
      <Sheet>
        <SheetTrigger className="inline-flex items-center justify-center rounded-lg h-8 w-8 hover:bg-muted md:hidden">
          <Menu className="h-5 w-5" />
        </SheetTrigger>
        <SheetContent side="left" className="p-0 w-64">
          <MobileSidebar />
        </SheetContent>
      </Sheet>

      <div className="flex-1" />

      {/* Language switcher */}
      <Button
        variant="ghost"
        size="sm"
        onClick={() => setLocale(locale === 'fr' ? 'en' : 'fr')}
        className="gap-1.5 text-xs"
      >
        <Globe className="h-4 w-4" />
        {locale.toUpperCase()}
      </Button>

      {/* User menu */}
      <DropdownMenu>
        <DropdownMenuTrigger className="inline-flex items-center justify-center rounded-full h-8 w-8 hover:bg-muted">
          <Avatar className="h-8 w-8">
            <AvatarFallback className="text-xs bg-primary text-primary-foreground">
              AD
            </AvatarFallback>
          </Avatar>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <div className="px-2 py-1.5">
            <p className="text-sm font-medium">{user?.phone_number}</p>
            <p className="text-xs text-muted-foreground">{t('role_admin')}</p>
          </div>
          <DropdownMenuSeparator />
          <DropdownMenuItem onClick={logout} className="text-destructive">
            <LogOut className="mr-2 h-4 w-4" />
            {t('logout')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </header>
  );
}
