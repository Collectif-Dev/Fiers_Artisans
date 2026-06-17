import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ collection: 'notifications' })
export class Notification extends Document {
  @Prop({ required: true, index: true })
  userId: string;

  @Prop({
    required: true,
    enum: [
      'NEW_MESSAGE',
      'SUBSCRIPTION_EXPIRY',
      'SUBSCRIPTION_UPDATED',
      'NEARBY_SEARCH',
      'REVIEW_RECEIVED',
      'DOCUMENT_APPROVED',
      'DOCUMENT_REJECTED',
      'PAYMENT_SUCCESS',
      'PAYMENT_MANUAL_VALIDATED',
      'PAYMENT_MANUAL_REJECTED',
      'PAYMENT_MANUAL_COOLDOWN',
      'PAYMENT_MANUAL_REOPENED',
      'PAYMENT_MANUAL_EXPIRED',
      'PAYMENT_MANUAL_AUTO_REPLACED',
      'PAYMENT_MANUAL_INTEGRITY_ALERT',
      'REFUND_PROCESSED',
    ],
  })
  type: string;

  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  body: string;

  @Prop({ type: Object })
  data: Record<string, any>;

  @Prop({ default: false })
  isRead: boolean;

  @Prop({ default: () => new Date() })
  createdAt: Date;

  @Prop({
    default: () => new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    index: { expireAfterSeconds: 0 },
  })
  expireAt: Date;
}

export const NotificationSchema = SchemaFactory.createForClass(Notification);
