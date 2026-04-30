import { Injectable } from '@nestjs/common';
import { AdminRealtimeService } from '../../../common/realtime/admin-realtime.service';
import { ChatGateway } from '../../chat/chat.gateway';
import {
  PAYMENT_MANUAL_NEW_PROOF,
  PAYMENT_MANUAL_UPDATED,
} from './payment.events';

@Injectable()
export class PaymentRealtimeService {
  constructor(
    private readonly adminRealtimeService: AdminRealtimeService,
    private readonly chatGateway: ChatGateway,
  ) {}

  async emitNewProof(payload: Record<string, unknown>): Promise<void> {
    this.adminRealtimeService.emit(PAYMENT_MANUAL_NEW_PROOF, payload);
  }

  async emitPaymentUpdated(payload: {
    userId?: string;
    paymentId: string;
    transactionId: string;
    status: string;
    refundRequired?: boolean;
    updatedAt: string;
  }): Promise<void> {
    this.adminRealtimeService.emit(PAYMENT_MANUAL_UPDATED, payload);

    if (payload.userId) {
      await this.chatGateway.emitUserSyncEvent(payload.userId, 'manualPaymentUpdated', {
        paymentId: payload.paymentId,
        transactionId: payload.transactionId,
        status: payload.status,
        refundRequired: payload.refundRequired ?? false,
        updatedAt: payload.updatedAt,
      });
    }
  }
}
