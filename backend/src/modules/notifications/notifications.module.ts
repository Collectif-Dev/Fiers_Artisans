import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import {
  Notification,
  NotificationSchema,
} from './schemas/notification.schema';
import { FcmProvider } from './providers/fcm.provider';
import { User } from '../users/entities/user.entity';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Notification.name, schema: NotificationSchema },
    ]),
    TypeOrmModule.forFeature([User]),
  ],
  controllers: [NotificationsController],
  providers: [NotificationsService, FcmProvider],
  exports: [NotificationsService],
})
export class NotificationsModule {}
