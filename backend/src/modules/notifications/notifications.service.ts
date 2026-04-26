import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification } from './schemas/notification.schema';
import { FcmProvider } from './providers/fcm.provider';
import { User } from '../users/entities/user.entity';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectModel(Notification.name)
    private readonly notificationModel: Model<Notification>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly fcmProvider: FcmProvider,
  ) {}

  async create(data: {
    userId: string;
    type: string;
    title: string;
    body: string;
    data?: Record<string, any>;
  }): Promise<Notification> {
    const notification = await this.notificationModel.create(data);
    // Offload push dispatch outside the critical HTTP path.
    setImmediate(() => {
      this.dispatchPushNotification(data).catch((error) => {
        this.logger.warn(`FCM push failed for ${data.userId}: ${error}`);
      });
    });

    return notification;
  }

  private async dispatchPushNotification(data: {
    userId: string;
    type: string;
    title: string;
    body: string;
    data?: Record<string, any>;
  }): Promise<void> {
    const user = await this.userRepository.findOne({
      where: { id: data.userId },
      select: ['fcm_token'],
    });
    if (!user?.fcm_token) {
      return;
    }

    const stringData: Record<string, string> = {};
    if (data.data) {
      for (const [k, v] of Object.entries(data.data)) {
        stringData[k] = String(v);
      }
    }
    stringData.type = data.type;

    await this.fcmProvider.sendToDevice(
      user.fcm_token,
      data.title,
      data.body,
      stringData,
    );
  }

  async getUserNotifications(
    userId: string,
    page = 1,
    limit = 20,
  ): Promise<{ data: Notification[]; total: number }> {
    const [data, total] = await Promise.all([
      this.notificationModel
        .find({ userId })
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .exec(),
      this.notificationModel.countDocuments({ userId }),
    ]);
    return { data, total };
  }

  async markAsRead(userId: string, notificationId: string): Promise<void> {
    await this.notificationModel.updateOne(
      { _id: notificationId, userId },
      { isRead: true },
    );
  }

  async markAllAsRead(userId: string): Promise<void> {
    await this.notificationModel.updateMany(
      { userId, isRead: false },
      { isRead: true },
    );
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.notificationModel.countDocuments({
      userId,
      isRead: false,
    });
  }
}
