export type AdminRealtimeEventType =
  | 'VERIFICATION_SUBMITTED'
  | 'VERIFICATION_REVIEWED'
  | 'ARTISAN_REGISTERED'
  | 'CLIENT_REGISTERED'
  | 'ARTISAN_UPDATED'
  | 'CLIENT_UPDATED'
  | 'REVIEW_CREATED'
  | 'REVIEW_REPLIED'
  | 'REVIEW_DELETED'
  | 'SUBSCRIPTION_UPDATED'
  | 'PAYMENT_UPDATED'
  | 'ACTIVITY_LOGGED'
  | 'PAYMENT_MANUAL_NEW_PROOF'
  | 'PAYMENT_MANUAL_UPDATED'
  | 'PAYMENT_MANUAL_TIMELINE_UPDATED';

export interface AdminRealtimeEvent<
  TPayload extends Record<string, unknown> = Record<string, unknown>,
> {
  type: AdminRealtimeEventType | string;
  timestamp: string;
  payload?: TPayload;
}
