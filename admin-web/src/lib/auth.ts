import type { User } from '@/types';

const TOKEN_KEY = 'admin_token';
const REFRESH_KEY = 'admin_refresh_token';
const USER_KEY = 'admin_user';
export const AUTH_LOGOUT_EVENT = 'admin-auth-logout';

export function saveAuth(accessToken: string, refreshToken: string, user: User) {
  localStorage.setItem(TOKEN_KEY, accessToken);
  localStorage.setItem(REFRESH_KEY, refreshToken);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function getRefreshToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(REFRESH_KEY);
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
  return !!getToken();
}

export function logout() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  localStorage.removeItem(USER_KEY);
}

export function isTokenExpired(token: string, skewSeconds = 10): boolean {
  try {
    const [, payloadB64] = token.split('.');
    if (!payloadB64) return true;

    const normalized = payloadB64.replace(/-/g, '+').replace(/_/g, '/');
    const json = atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '='));
    const payload = JSON.parse(json) as { exp?: number };

    if (!payload.exp) return true;

    const nowSeconds = Math.floor(Date.now() / 1000);
    return nowSeconds >= payload.exp - skewSeconds;
  } catch {
    return true;
  }
}

export function forceLogout(redirectToLogin = true) {
  logout();

  if (typeof window !== 'undefined') {
    window.dispatchEvent(new Event(AUTH_LOGOUT_EVENT));

    if (redirectToLogin && window.location.pathname !== '/login') {
      window.location.replace('/login');
    }
  }
}
