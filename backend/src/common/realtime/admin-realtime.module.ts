import { Global, Module } from '@nestjs/common';
import { AdminRealtimeService } from './admin-realtime.service';

@Global()
@Module({
  providers: [AdminRealtimeService],
  exports: [AdminRealtimeService],
})
export class AdminRealtimeModule {}
