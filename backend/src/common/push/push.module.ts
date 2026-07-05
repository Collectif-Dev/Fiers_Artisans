import { Module } from '@nestjs/common';
import { FcmProvider } from '../../modules/notifications/providers/fcm.provider';

@Module({
  providers: [FcmProvider],
  exports: [FcmProvider],
})
export class PushModule {}
