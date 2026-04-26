import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ collection: 'conversations', timestamps: true })
export class Conversation extends Document {
  @Prop({ type: [String], index: true })
  participants: string[];

  @Prop({ type: Object })
  lastMessage: {
    content: string;
    sentAt: Date;
    senderId: string;
  };
}

export const ConversationSchema = SchemaFactory.createForClass(Conversation);
ConversationSchema.index({ participants: 1, updatedAt: -1 });
