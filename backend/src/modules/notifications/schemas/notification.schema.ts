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
      'NEARBY_SEARCH',
      'REVIEW_RECEIVED',
      'DOCUMENT_APPROVED',
      'DOCUMENT_REJECTED',
      'PAYMENT_SUCCESS',
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

export const NotificationSchema =
  SchemaFactory.createForClass(Notification);
