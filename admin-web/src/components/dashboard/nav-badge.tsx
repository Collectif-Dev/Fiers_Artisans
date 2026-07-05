type NavBadgeProps = {
  count: number;
};

export function NavBadge({ count }: NavBadgeProps) {
  if (count <= 0) {
    return null;
  }

  return (
    <span className="ml-auto inline-flex min-w-5 items-center justify-center rounded-full border border-background/70 bg-destructive px-1.5 py-0.5 text-[10px] font-semibold leading-none text-white shadow-sm">
      {count > 99 ? '99+' : count}
    </span>
  );
}
