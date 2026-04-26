import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

@Injectable()
export class FcmProvider implements OnModuleInit {
  private readonly logger = new Logger(FcmProvider.name);
  private initialized = false;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const projectId = this.configService.get<string>('FCM_PROJECT_ID');
    const clientEmail = this.configService.get<string>('FCM_CLIENT_EMAIL');
    const privateKey = this.configService.get<string>('FCM_PRIVATE_KEY');

    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn(
        'FCM credentials not configured — push notifications disabled.',
      );
      return;
    }

    try {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey: privateKey.replace(/\\n/g, '\n'),
        }),
      });
      this.initialized = true;
      this.logger.log('Firebase Admin SDK initialized.');
    } catch (e) {
      this.logger.error(`FCM init failed: ${e}`);
    }
  }

  async sendToDevice(
    fcmToken: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    if (!this.initialized || !fcmToken) return false;

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: data || {},
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      });
      this.logger.debug(`Push sent to ${fcmToken.slice(0, 10)}…`);
      return true;
    } catch (e: any) {
      if (
        e?.code === 'messaging/registration-token-not-registered' ||
        e?.code === 'messaging/invalid-registration-token'
      ) {
        this.logger.warn(`Invalid FCM token: ${fcmToken.slice(0, 10)}…`);
      } else {
        this.logger.error(`FCM send error: ${e.message}`);
      }
      return false;
    }
  }
}
