import type { User } from '@/types';

const LEGACY_TOKEN_KEY = 'admin_token';
const LEGACY_REFRESH_KEY = 'admin_refresh_token';
const USER_KEY = 'admin_user';
export const AUTH_LOGOUT_EVENT = 'admin-auth-logout';

export function saveAuthUser(user: User) {
  if (typeof window === 'undefined') return;
  localStorage.removeItem(LEGACY_TOKEN_KEY);
  localStorage.removeItem(LEGACY_REFRESH_KEY);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function getUser(): User | null {
  if (typeof window === 'undefined') return null;
  const raw = localStorage.getItem(USER_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function isAuthenticated(): boolean {
  return !!getUser();
}

export function clearAuthSnapshot() {
  if (typeof window === 'undefined') return;
  localStorage.removeItem(LEGACY_TOKEN_KEY);
  localStorage.removeItem(LEGACY_REFRESH_KEY);
  localStorage.removeItem(USER_KEY);
}

export function forceLogout(redirectToLogin = true) {
  clearAuthSnapshot();

  if (typeof window !== 'undefined') {
    window.dispatchEvent(new Event(AUTH_LOGOUT_EVENT));

    if (redirectToLogin && window.location.pathname !== '/login') {
      window.location.replace('/login');
    }
  }
}
