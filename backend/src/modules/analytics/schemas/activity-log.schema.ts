import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ collection: 'activity_logs' })
export class ActivityLog extends Document {
  @Prop({ required: true, index: true })
  actorId: string;

  @Prop({
    required: true,
    enum: [
      'PROFILE_VIEW',
      'SEARCH',
      'CONTACT_CLICK',
      'LOGIN',
      'PAYMENT_ATTEMPT',
      'REGISTRATION',
      'SUBSCRIPTION_UPDATED',
      'PAYMENT_MANUAL_INITIATED',
      'PROOF_SUBMITTED',
      'PROOF_VALIDATED',
      'PAYMENT_MANUAL_REJECTED',
      'PAYMENT_MANUAL_REOPENED',
      'PAYMENT_MANUAL_EXPIRED',
      'REFUND_PROCESSED',
    ],
    index: true,
  })
  action: string;

  @Prop()
  targetId: string;

  @Prop({ type: Object })
  metadata: Record<string, any>;

  @Prop()
  ipAddress: string;

  @Prop()
  userAgent: string;

  @Prop({
    default: () => new Date(),
    index: { expireAfterSeconds: 7776000 }, // 90 jours
  })
  timestamp: Date;
}

export const ActivityLogSchema = SchemaFactory.createForClass(ActivityLog);
