import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ collection: 'media_files', timestamps: true })
export class MediaFile extends Document {
  @Prop({ required: true })
  userId: string;

  @Prop({ required: true })
  bucket: string;

  @Prop({ required: true })
  objectKey: string;

  @Prop({ required: true })
  originalName: string;

  @Prop({ required: true })
  mimeType: string;

  @Prop({ required: true })
  size: number;

  @Prop()
  thumbnailKey: string;
}

export const MediaFileSchema = SchemaFactory.createForClass(MediaFile);
