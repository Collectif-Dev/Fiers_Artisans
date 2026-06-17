import { Injectable } from '@nestjs/common';
import { Observable, Subject } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  AdminRealtimeEvent,
  AdminRealtimeEventType,
} from './admin-realtime.events';

@Injectable()
export class AdminRealtimeService {
  private readonly eventsSubject = new Subject<AdminRealtimeEvent>();

  emit(
    type: AdminRealtimeEventType | string,
    payload?: Record<string, unknown>,
  ): void {
    this.eventsSubject.next({
      type,
      timestamp: new Date().toISOString(),
      payload,
    });
  }

  asSseStream(): Observable<MessageEvent> {
    return this.eventsSubject
      .asObservable()
      .pipe(map((event) => ({ data: event }) as MessageEvent));
  }
}
