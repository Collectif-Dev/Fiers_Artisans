'use client';

import { useReducer, useCallback, useEffect } from 'react';
import { loginAdmin, refreshAdminSession } from '@/lib/api';
import {
  AUTH_LOGOUT_EVENT,
  forceLogout,
  getRefreshToken,
  getToken,
  getUser,
  isTokenExpired,
  saveAuth,
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
      const token = getToken();
      const refreshToken = getRefreshToken();
      const savedUser = getUser();

      if (!savedUser || savedUser.role !== 'ADMIN') {
        dispatch({ type: 'hydrate', user: null });
        return;
      }

      if (token && !isTokenExpired(token)) {
        dispatch({ type: 'hydrate', user: savedUser });
        return;
      }

      if (!refreshToken) {
        forceLogout(false);
        dispatch({ type: 'hydrate', user: null });
        return;
      }

      try {
        const refreshed = await refreshAdminSession(refreshToken);
        if (!refreshed?.user || refreshed.user.role !== 'ADMIN') {
          throw new Error('NOT_ADMIN');
        }

        saveAuth(
          refreshed.access_token,
          refreshed.refresh_token || refreshToken,
          refreshed.user,
        );
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
    const data = await loginAdmin(phone, pinCode);
    if (data.user.role !== 'ADMIN') {
      throw new Error('NOT_ADMIN');
    }
    saveAuth(data.access_token, data.refresh_token, data.user);
    dispatch({ type: 'login', user: data.user });
  }, []);

  const logout = useCallback(() => {
    forceLogout(true);
    dispatch({ type: 'logout' });
  }, []);

  return { user, loading, login, logout, isAuthenticated: !!user };
}
