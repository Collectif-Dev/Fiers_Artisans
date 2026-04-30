import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification } from './schemas/notification.schema';
import { FcmProvider } from './providers/fcm.provider';
import { User } from '../users/entities/user.entity';
import { ChatGateway } from '../chat/chat.gateway';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectModel(Notification.name)
    private readonly notificationModel: Model<Notification>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly fcmProvider: FcmProvider,
    private readonly chatGateway: ChatGateway,
  ) {}

  async create(data: {
    userId: string;
    type: string;
    title: string;
    body: string;
    data?: Record<string, any>;
  }): Promise<Notification> {
    const notification = await this.notificationModel.create(data);
    const unreadCount = await this.getUnreadCount(data.userId);

    this.chatGateway
      .emitUserSyncEvent(data.userId, 'notificationCreated', {
        notification: this.toClientNotification(notification),
        unreadCount,
      })
      .catch(() => {});

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
    const unreadCount = await this.getUnreadCount(userId);
    this.chatGateway
      .emitUserSyncEvent(userId, 'notificationRead', {
        notificationId,
        unreadCount,
      })
      .catch(() => {});
  }

  async markAllAsRead(userId: string): Promise<void> {
    await this.notificationModel.updateMany(
      { userId, isRead: false },
      { isRead: true },
    );
    this.chatGateway
      .emitUserSyncEvent(userId, 'notificationsReadAll', {
        unreadCount: 0,
      })
      .catch(() => {});
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.notificationModel.countDocuments({
      userId,
      isRead: false,
    });
  }

  private toClientNotification(notification: Notification): Record<string, unknown> {
    const asAny = notification as any;
    const plain =
      typeof asAny.toObject === 'function' ? asAny.toObject() : asAny;
    return {
      ...plain,
      id: plain?._id?.toString?.() ?? plain?.id?.toString?.() ?? '',
      _id: plain?._id?.toString?.() ?? plain?.id?.toString?.() ?? '',
    };
  }
}
