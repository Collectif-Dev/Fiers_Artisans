import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ChatService } from './chat.service';
import { CurrentUser } from '../../common/decorators';
import { PhoneVerifiedGuard } from '../../common/guards';

@Controller('chat')
@UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('conversations')
  getConversations(@CurrentUser('id') userId: string) {
    return this.chatService.getUserConversations(userId);
  }

  @Post('conversations')
  createConversation(
    @CurrentUser('id') userId: string,
    @Body('participantId') participantId: string,
  ) {
    return this.chatService.createConversation([userId, participantId]);
  }

  @Get('conversations/:id/messages')
  getMessages(
    @Param('id') conversationId: string,
    @CurrentUser('id') userId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.chatService.getMessages(
      conversationId,
      userId,
      page || 1,
      limit || 50,
    );
  }

  @Post('conversations/:id/messages')
  sendMessage(
    @Param('id') conversationId: string,
    @CurrentUser('id') senderId: string,
    @Body() body: { content: string; type?: string; mediaUrl?: string },
  ) {
    return this.chatService.sendMessage(
      conversationId,
      senderId,
      body.content,
      body.type,
      body.mediaUrl,
    );
  }

  @Put('conversations/:id/read')
  markAsRead(
    @Param('id') conversationId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.chatService.markAsRead(conversationId, userId);
  }
}
