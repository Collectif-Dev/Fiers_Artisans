'use client';

import { useEffect, useRef } from 'react';
import { resolveApiUrl } from '@/lib/api';
import { forceLogout } from '@/lib/auth';

const POLL_INTERVAL = 30_000;
const SSE_RECONNECT_DELAY = 3_000;
const MIN_REFRESH_INTERVAL_MS = 800;

type AdminRealtimeEvent = {
  type?: string;
  payload?: Record<string, unknown>;
  timestamp?: string;
};

type UseAdminSSEOptions = {
  eventTypes?: string[];
  minRefreshIntervalMs?: number;
};

/**
 * Shared hook: subscribes to the global admin SSE stream.
 * Falls back to polling if SSE disconnects.
 * Refreshes on visibility change.
 *
 * @param onEvent — called on each SSE message (or poll tick) so the
 *                  consuming page can reload its own data.
 */
export function useAdminSSE(onEvent: () => void, options?: UseAdminSSEOptions) {
  const onEventRef = useRef(onEvent);
  const optionsRef = useRef<UseAdminSSEOptions | undefined>(options);

  useEffect(() => {
    onEventRef.current = onEvent;
  }, [onEvent]);

  useEffect(() => {
    optionsRef.current = options;
  }, [options]);

  const normalizeEvent = (raw: unknown): AdminRealtimeEvent | null => {
    let current: unknown = raw;
    for (let i = 0; i < 3; i += 1) {
      if (!current || typeof current !== 'object') {
        return null;
      }

      const record = current as Record<string, unknown>;
      const maybeType = record.type;
      if (typeof maybeType === 'string') {
        return {
          type: maybeType,
          payload:
            record.payload && typeof record.payload === 'object'
              ? (record.payload as Record<string, unknown>)
              : undefined,
          timestamp:
            typeof record.timestamp === 'string' ? record.timestamp : undefined,
        };
      }

      current = record.data;
    }

    return null;
  };

  useEffect(() => {
    let abortController: AbortController | null = null;
    let fallbackId: ReturnType<typeof setInterval> | null = null;
    let reconnectId: ReturnType<typeof setTimeout> | null = null;
    let throttledFireId: ReturnType<typeof setTimeout> | null = null;
    let disposed = false;
    let lastFireAt = 0;

    const clearThrottledFire = () => {
      if (throttledFireId) {
        clearTimeout(throttledFireId);
        throttledFireId = null;
      }
    };

    const normalizeEventType = (eventType?: string): string | undefined => {
      if (eventType === 'DOCUMENT_SUBMITTED') {
        return 'VERIFICATION_SUBMITTED';
      }
      if (eventType === 'DOCUMENT_REVIEWED') {
        return 'VERIFICATION_REVIEWED';
      }
      return eventType;
    };

    const shouldHandleEventType = (eventType?: string) => {
      const filter = optionsRef.current?.eventTypes;
      if (!filter || filter.length === 0 || !eventType) {
        return true;
      }
      return filter.includes(eventType);
    };

    const fire = (eventType?: string) => {
      const normalizedEventType = normalizeEventType(eventType);
      if (!shouldHandleEventType(normalizedEventType)) {
        return;
      }

      const minInterval =
        optionsRef.current?.minRefreshIntervalMs ?? MIN_REFRESH_INTERVAL_MS;
      const now = Date.now();
      const elapsed = now - lastFireAt;
      if (elapsed >= minInterval) {
        lastFireAt = now;
        onEventRef.current();
        return;
      }

      if (!throttledFireId) {
        throttledFireId = setTimeout(() => {
          throttledFireId = null;
          lastFireAt = Date.now();
          onEventRef.current();
        }, minInterval - elapsed);
      }
    };

    const startPolling = () => {
      if (!fallbackId && !disposed) {
        fallbackId = setInterval(() => fire(), POLL_INTERVAL);
      }
    };
    const stopPolling = () => {
      if (fallbackId) {
        clearInterval(fallbackId);
        fallbackId = null;
      }
    };

    const clearReconnect = () => {
      if (reconnectId) {
        clearTimeout(reconnectId);
        reconnectId = null;
      }
    };

    const scheduleReconnect = () => {
      if (
        disposed ||
        reconnectId ||
        document.visibilityState !== 'visible'
      ) {
        return;
      }

      reconnectId = setTimeout(() => {
        reconnectId = null;
        void startSSE();
      }, SSE_RECONNECT_DELAY);
    };

    const stopSSE = () => {
      abortController?.abort();
      abortController = null;
      clearReconnect();
    };

    const extractEventType = (eventBlock: string): string | undefined => {
      const dataLines = eventBlock
        .split('\n')
        .filter((line) => line.startsWith('data:'))
        .map((line) => line.slice(5).trimStart());

      if (dataLines.length === 0) {
        return undefined;
      }

      try {
        const parsed = JSON.parse(dataLines.join('\n'));
        const normalized = normalizeEvent(parsed);
        return normalized?.type;
      } catch {
        return undefined;
      }
    };

    const handleChunk = (chunk: string, currentBuffer: string) => {
      let buffer = `${currentBuffer}${chunk.replace(/\r\n/g, '\n')}`;

      while (true) {
        const eventSeparator = buffer.indexOf('\n\n');
        if (eventSeparator === -1) break;

        const eventBlock = buffer.slice(0, eventSeparator);
        buffer = buffer.slice(eventSeparator + 2);

        const hasData = eventBlock
          .split('\n')
          .some((line) => line.startsWith('data:'));

        if (hasData) {
          fire(extractEventType(eventBlock));
        }
      }

      return buffer;
    };

    const startSSE = async () => {
      if (disposed || document.visibilityState !== 'visible') return;

      stopSSE();
      stopPolling();

      const controller = new AbortController();
      abortController = controller;

      try {
        const openStream = async (path: string) =>
          fetch(`${resolveApiUrl()}${path}`, {
            method: 'GET',
            headers: {
              Accept: 'text/event-stream',
              'X-Admin-Web-Auth': 'cookie',
              'Cache-Control': 'no-cache',
            },
            credentials: 'include',
            signal: controller.signal,
            cache: 'no-store',
          });

        let response = await openStream('/admin/events');
        if (response.status === 404) {
          response = await openStream('/admin/verifications/events');
        }

        if (response.status === 401 || response.status === 403) {
          forceLogout(true);
          return;
        }

        if (!response.ok || !response.body) {
          throw new Error(`SSE connection failed (${response.status})`);
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        while (!disposed) {
          const { value, done } = await reader.read();
          if (done) {
            break;
          }

          buffer = handleChunk(decoder.decode(value, { stream: true }), buffer);
        }

        if (!disposed) {
          startPolling();
          scheduleReconnect();
        }
      } catch {
        if (!disposed) {
          startPolling();
          scheduleReconnect();
        }
      }
    };

    const onVisibility = () => {
      if (document.visibilityState === 'visible') {
        fire();
        void startSSE();
      } else {
        stopSSE();
        stopPolling();
      }
    };

    if (document.visibilityState === 'visible') {
      void startSSE();
    }
    document.addEventListener('visibilitychange', onVisibility);

    return () => {
      disposed = true;
      stopSSE();
      stopPolling();
      clearThrottledFire();
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, []);
}
