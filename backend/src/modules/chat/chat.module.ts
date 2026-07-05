import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ChatService } from './chat.service';
import { ChatController } from './chat.controller';
import { ChatGateway } from './chat.gateway';
import { ChatEventsBridge } from './chat-events.bridge';
import {
  Conversation,
  ConversationSchema,
} from './schemas/conversation.schema';
import { Message, MessageSchema } from './schemas/message.schema';
import { User } from '../users/entities/user.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { ClientProfile } from '../users/entities/client-profile.entity';
import {
  Notification,
  NotificationSchema,
} from '../notifications/schemas/notification.schema';
import { PushModule } from '../../common/push/push.module';

@Module({
  imports: [
    PushModule,
    JwtModule.register({}),
    MongooseModule.forFeature([
      { name: Conversation.name, schema: ConversationSchema },
      { name: Message.name, schema: MessageSchema },
      { name: Notification.name, schema: NotificationSchema },
    ]),
    TypeOrmModule.forFeature([User, ArtisanProfile, ClientProfile]),
  ],
  controllers: [ChatController],
  providers: [ChatService, ChatGateway, ChatEventsBridge],
  exports: [ChatService, ChatGateway, ChatEventsBridge],
})
export class ChatModule {}
