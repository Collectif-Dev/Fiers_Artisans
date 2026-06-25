'use client';

import { useReducer, useCallback, useEffect } from 'react';
import { loginAdmin, logoutAdmin, refreshAdminSession } from '@/lib/api';
import {
  AUTH_LOGOUT_EVENT,
  forceLogout,
  saveAuthUser,
} from '@/lib/auth';
import type { User } from '@/types';

interface AuthState {
  user: User | null;
  loading: boolean;
}

type AuthAction =
  | { type: 'hydrate'; user: User | null }
  | { type: 'login'; user: User }
  | { type: 'logout' };

function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case 'hydrate':
      return { user: action.user, loading: false };
    case 'login':
      return { user: action.user, loading: false };
    case 'logout':
      return { user: null, loading: false };
    default:
      return state;
  }
}

function isForbiddenResponse(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'response' in error &&
    (error as { response?: { status?: number } }).response?.status === 403
  );
}

export function useAuth() {
  const [{ user, loading }, dispatch] = useReducer(authReducer, {
    user: null,
    loading: true,
  });

  useEffect(() => {
    let active = true;

    const onForcedLogout = () => {
      if (!active) return;
      dispatch({ type: 'logout' });
    };

    window.addEventListener(AUTH_LOGOUT_EVENT, onForcedLogout);

    const bootstrapSession = async () => {
      try {
        const refreshed = await refreshAdminSession();
        if (!refreshed?.user || refreshed.user.role !== 'ADMIN') {
          throw new Error('NOT_ADMIN');
        }

        saveAuthUser(refreshed.user);
        if (active) {
          dispatch({ type: 'hydrate', user: refreshed.user });
        }
      } catch {
        forceLogout(false);
        if (active) {
          dispatch({ type: 'hydrate', user: null });
        }
      }
    };

    void bootstrapSession();

    return () => {
      active = false;
      window.removeEventListener(AUTH_LOGOUT_EVENT, onForcedLogout);
    };
  }, []);

  const login = useCallback(async (phone: string, pinCode: string) => {
    let data;
    try {
      data = await loginAdmin(phone, pinCode);
    } catch (error) {
      if (isForbiddenResponse(error)) {
        throw new Error('NOT_ADMIN');
      }
      throw error;
    }

    if (data.user.role !== 'ADMIN') {
      throw new Error('NOT_ADMIN');
    }
    saveAuthUser(data.user);
    dispatch({ type: 'login', user: data.user });
  }, []);

  const logout = useCallback(async () => {
    try {
      await logoutAdmin();
    } finally {
      forceLogout(true);
    }
    dispatch({ type: 'logout' });
  }, []);

  return { user, loading, login, logout, isAuthenticated: !!user };
}
