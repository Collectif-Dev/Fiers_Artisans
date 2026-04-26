'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';
import { useTranslations } from '@/hooks/use-translations';
import {
  LayoutDashboard,
  ShieldCheck,
  Hammer,
  BarChart3,
  Users,
  CreditCard,
  Star,
  FileText,
} from 'lucide-react';

const navItems = [
  { key: 'overview', href: '/', icon: LayoutDashboard },
  { key: 'verifications', href: '/verifications', icon: ShieldCheck },
  { key: 'artisans', href: '/artisans', icon: Hammer },
  { key: 'analytics', href: '/analytics', icon: BarChart3 },
  { key: 'clients', href: '/clients', icon: Users },
  { key: 'subscriptions', href: '/subscriptions', icon: CreditCard },
  { key: 'reviews', href: '/reviews', icon: Star },
  { key: 'logs', href: '/logs', icon: FileText },
];

export function Sidebar() {
  const pathname = usePathname();
  const { t } = useTranslations('nav');
  const { t: tApp } = useTranslations('app');

  return (
    <aside className="hidden md:flex flex-col w-64 border-r bg-card h-screen sticky top-0">
      <div className="p-6 border-b">
        <h1 className="text-lg font-bold tracking-tight">
          ⚒️ Fiers Artisans
        </h1>
        <p className="text-xs text-muted-foreground mt-0.5">{tApp('subtitle')}</p>
      </div>
      <nav className="flex-1 p-4 space-y-1">
        {navItems.map((item) => {
          const isActive =
            item.href === '/'
              ? pathname === '/'
              : pathname.startsWith(item.href);
          return (
            <Link
              key={item.key}
              href={item.href}
              className={cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                isActive
                  ? 'bg-primary text-primary-foreground'
                  : 'text-muted-foreground hover:text-foreground hover:bg-muted'
              )}
            >
              <item.icon className="h-4 w-4" />
              {t(item.key)}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
