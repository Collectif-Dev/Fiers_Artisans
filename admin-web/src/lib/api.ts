import axios, { type AxiosError, type InternalAxiosRequestConfig } from 'axios';
import type {
  AuthResponse,
  DashboardStats,
  VerificationDocument,
  ArtisanProfile,
  AnalyticsData,
  ClientProfile,
  SubscriptionRecord,
  ReviewRecord,
  ActivityLog,
  PaginatedResult,
} from '@/types';
import { forceLogout, getUser, saveAuth } from '@/lib/auth';

const API_URL = resolveApiUrl();

function resolveApiUrl(): string {
  const explicitUrl = process.env.NEXT_PUBLIC_API_URL?.trim();
  if (explicitUrl) {
    return explicitUrl.replace(/\/+$/, '');
  }

  const apiPort = process.env.NEXT_PUBLIC_API_PORT?.trim() || '3000';
  const rawBasePath = process.env.NEXT_PUBLIC_API_BASE_PATH?.trim() || '/api/v1';
  const basePath = rawBasePath.startsWith('/') ? rawBasePath : `/${rawBasePath}`;

  if (typeof window !== 'undefined') {
    const protocol = window.location.protocol === 'https:' ? 'https' : 'http';
    const host = window.location.hostname || 'localhost';
    return `${protocol}://${host}:${apiPort}${basePath}`;
  }

  return `http://localhost:${apiPort}${basePath}`;
}

const api = axios.create({
  baseURL: API_URL,
  headers: { 'Content-Type': 'application/json' },
});

export async function refreshAdminSession(
  refreshToken: string,
): Promise<AuthResponse> {
  const { data } = await axios.post<AuthResponse>(
    `${API_URL}/auth/refresh`,
    { refresh_token: refreshToken },
    {
      headers: { Authorization: `Bearer ${refreshToken}` },
    },
  );

  const payload = data && typeof data === 'object' && 'data' in data
    ? (data as { data: AuthResponse }).data
    : data;

  return payload;
}

function toPaginatedResult<T>(
  payload: unknown,
  fallbackPage: number,
  fallbackLimit: number,
): PaginatedResult<T> {
  if (
    payload &&
    typeof payload === 'object' &&
    'data' in payload &&
    Array.isArray((payload as { data: unknown }).data)
  ) {
    const typed = payload as {
      data: T[];
      total?: number;
      page?: number;
      limit?: number;
    };
    return {
      data: typed.data,
      total: typeof typed.total === 'number' ? typed.total : typed.data.length,
      page: typeof typed.page === 'number' ? typed.page : fallbackPage,
      limit: typeof typed.limit === 'number' ? typed.limit : fallbackLimit,
    };
  }

  if (Array.isArray(payload)) {
    return {
      data: payload as T[],
      total: payload.length,
      page: fallbackPage,
      limit: fallbackLimit,
    };
  }

  return {
    data: [],
    total: 0,
    page: fallbackPage,
    limit: fallbackLimit,
  };
}

// Unwrap backend envelope {statusCode, data, timestamp}
api.interceptors.response.use((response) => {
  const body = response.data;
  if (
    body &&
    typeof body === 'object' &&
    'data' in body &&
    'statusCode' in body &&
    'timestamp' in body
  ) {
    response.data = body.data;
  }
  return response;
});

// Inject JWT
api.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('admin_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

// Auto-refresh on 401
let isRefreshing = false;
let pendingRequests: ((token: string) => void)[] = [];

function onRefreshed(token: string) {
  pendingRequests.forEach((cb) => cb(token));
  pendingRequests = [];
}

api.interceptors.response.use(undefined, async (error: AxiosError) => {
  const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };
  if (!originalRequest || error.response?.status !== 401 || originalRequest._retry) {
    return Promise.reject(error);
  }

  // Don't refresh on login or refresh endpoint itself
  if (originalRequest.url?.includes('/auth/login') || originalRequest.url?.includes('/auth/refresh')) {
    return Promise.reject(error);
  }

  if (isRefreshing) {
    return new Promise((resolve) => {
      pendingRequests.push((token: string) => {
        originalRequest.headers.Authorization = `Bearer ${token}`;
        resolve(api(originalRequest));
      });
    });
  }

  originalRequest._retry = true;
  isRefreshing = true;

  try {
    const refreshToken = localStorage.getItem('admin_refresh_token');
    if (!refreshToken) throw new Error('No refresh token');

    const refreshed = await refreshAdminSession(refreshToken);
    const newToken = refreshed?.access_token;
    const newRefreshToken = refreshed?.refresh_token || refreshToken;
    const user = refreshed?.user || getUser();

    if (!newToken || !newRefreshToken || !user) {
      throw new Error('Invalid refresh response');
    }

    saveAuth(newToken, newRefreshToken, user);

    originalRequest.headers.Authorization = `Bearer ${newToken}`;
    onRefreshed(newToken);
    return api(originalRequest);
  } catch {
    forceLogout(true);
    return Promise.reject(error);
  } finally {
    isRefreshing = false;
  }
});

// Auth
export async function loginAdmin(phone: string, pinCode: string): Promise<AuthResponse> {
  const { data } = await api.post<AuthResponse>('/auth/login', {
    phone_number: phone,
    pin_code: pinCode,
  });
  return data;
}

// Dashboard
export async function getDashboardStats(): Promise<DashboardStats> {
  const { data } = await api.get<DashboardStats>('/admin/dashboard');
  return data;
}

// Verifications
export async function getPendingVerifications(
  page = 1,
  limit = 20,
): Promise<PaginatedResult<VerificationDocument>> {
  const { data } = await api.get('/admin/verifications/pending', {
    params: { page, limit },
  });
  return toPaginatedResult<VerificationDocument>(data, page, limit);
}

export async function reviewDocument(
  id: string,
  status: 'APPROVED' | 'REJECTED',
  rejectionReason?: string
): Promise<void> {
  await api.put(`/admin/verifications/${id}`, {
    status,
    rejection_reason: rejectionReason,
  });
}

// Artisans
export async function getArtisans(
  page = 1,
  limit = 50,
): Promise<PaginatedResult<ArtisanProfile>> {
  const { data } = await api.get('/admin/artisans', {
    params: { page, limit },
  });
  return toPaginatedResult<ArtisanProfile>(data, page, limit);
}

// Analytics
export async function getAnalytics(): Promise<AnalyticsData> {
  const { data } = await api.get<AnalyticsData>('/admin/analytics');
  return data;
}

// Clients
export async function getClients(
  page = 1,
  limit = 50,
): Promise<PaginatedResult<ClientProfile>> {
  const { data } = await api.get('/admin/clients', {
    params: { page, limit },
  });
  return toPaginatedResult<ClientProfile>(data, page, limit);
}

// Subscriptions
export async function getSubscriptions(
  page = 1,
  limit = 50,
): Promise<PaginatedResult<SubscriptionRecord>> {
  const { data } = await api.get('/admin/subscriptions', {
    params: { page, limit },
  });
  return toPaginatedResult<SubscriptionRecord>(data, page, limit);
}

// Reviews
export async function getReviews(
  page = 1,
  limit = 50,
): Promise<PaginatedResult<ReviewRecord>> {
  const { data } = await api.get('/admin/reviews', {
    params: { page, limit },
  });
  return toPaginatedResult<ReviewRecord>(data, page, limit);
}

export async function deleteReview(id: string): Promise<void> {
  await api.delete(`/admin/reviews/${id}`);
}

// Logs
export async function getLogs(
  page?: number,
  limit?: number,
  action?: string
): Promise<{ data: ActivityLog[]; total: number; page: number; limit: number }> {
  const params: Record<string, string | number> = {};
  if (page) params.page = page;
  if (limit) params.limit = limit;
  if (action) params.action = action;
  const { data } = await api.get<{ data: ActivityLog[]; total: number; page: number; limit: number }>('/admin/logs', { params });
  return data;
}

// Media — authenticated blob fetch for admin preview/download
export async function fetchFileBlob(bucket: string, objectKey: string): Promise<Blob> {
  const response = await api.get(`/media/file/${bucket}/${objectKey}`, {
    responseType: 'blob',
  });
  return response.data as Blob;
}

export { resolveApiUrl };

export default api;
