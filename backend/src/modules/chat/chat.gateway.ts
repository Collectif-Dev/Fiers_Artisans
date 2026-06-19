import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { ChatService } from './chat.service';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { ChatEventsBridge } from './chat-events.bridge';

const WS_ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS?.split(',') || [
  'https://fiers-artisans.ci',
];

@WebSocketGateway({
  namespace: '/ws/chat',
  cors: {
    origin: WS_ALLOWED_ORIGINS,
    credentials: true,
    methods: ['GET', 'POST'],
  },
})
export class ChatGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(ChatGateway.name);
  private userSockets = new Map<string, Set<string>>(); // userId -> socketIds

  private toClientMessage(message: any) {
    if (!message) return message;
    const plain =
      typeof message.toObject === 'function' ? message.toObject() : message;
    return {
      ...plain,
      id: plain?._id?.toString?.() ?? plain?.id?.toString?.() ?? '',
      _id: plain?._id?.toString?.() ?? plain?.id?.toString?.() ?? '',
    };
  }

  constructor(
    private readonly chatService: ChatService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly chatEventsBridge: ChatEventsBridge,
  ) {}

  afterInit(server: Server): void {
    this.chatEventsBridge.bindServer(server);
  }

  handleConnection(client: Socket) {
    const token = this.extractSocketToken(client);
    if (!token) {
      this.logger.warn(`Socket ${client.id} rejected: missing auth token`);
      client.disconnect(true);
      return;
    }

    const userId = this.verifySocketToken(token);
    if (!userId) {
      this.logger.warn(`Socket ${client.id} rejected: invalid auth token`);
      client.disconnect(true);
      return;
    }

    client.data.userId = userId;
    const socketSet = this.userSockets.get(userId) ?? new Set<string>();
    socketSet.add(client.id);
    this.userSockets.set(userId, socketSet);
    client.join(`user:${userId}`);
    this.logger.log(`User ${userId} connected via socket ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    const userId = client.data?.userId as string | undefined;
    if (userId) {
      const socketSet = this.userSockets.get(userId);
      if (socketSet) {
        socketSet.delete(client.id);
        if (socketSet.size === 0) {
          this.userSockets.delete(userId);
        } else {
          this.userSockets.set(userId, socketSet);
        }
      }
      this.logger.log(`User ${userId} disconnected from socket ${client.id}`);
    }
  }

  @SubscribeMessage('joinConversation')
  async handleJoinConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const userId = this.requireSocketUserId(client);
    await this.chatService.ensureParticipant(data.conversationId, userId);
    client.join(`conversation:${data.conversationId}`);
  }

  @SubscribeMessage('sendMessage')
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      content: string;
      type?: string;
      mediaUrl?: string;
    },
  ) {
    const senderId = this.requireSocketUserId(client);
    const message = await this.chatService.sendMessage(
      data.conversationId,
      senderId,
      data.content,
      data.type,
      data.mediaUrl,
    );

    const payload = this.toClientMessage(message);

    // Émettre aux participants de la conversation
    this.server
      .to(`conversation:${data.conversationId}`)
      .emit('newMessage', payload);
    this.chatEventsBridge
      .publishConversationEvent('newMessage', data.conversationId, payload)
      .catch((error) => {
        this.logger.warn(
          `Failed to fan-out newMessage across instances: ${error}`,
        );
      });

    return payload;
  }

  @SubscribeMessage('markAsRead')
  async handleMarkAsRead(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: { conversationId: string },
  ) {
    const userId = this.requireSocketUserId(client);
    await this.chatService.markAsRead(data.conversationId, userId);
    this.server
      .to(`conversation:${data.conversationId}`)
      .emit('messagesRead', { conversationId: data.conversationId, userId });
    this.chatEventsBridge
      .publishConversationEvent('messagesRead', data.conversationId, {
        conversationId: data.conversationId,
        userId,
      })
      .catch((error) => {
        this.logger.warn(
          `Failed to fan-out messagesRead across instances: ${error}`,
        );
      });
  }

  async emitParticipantAvailabilityUpdated(
    participantId: string,
    isAvailable: boolean,
  ) {
    const targetUserIds =
      await this.chatService.findConversationParticipantIds(participantId);

    const payload = {
      participantId,
      participantRole: 'ARTISAN',
      participantIsAvailable: isAvailable,
    };

    for (const userId of targetUserIds) {
      this.server
        .to(`user:${userId}`)
        .emit('participantAvailabilityUpdated', payload);
      this.chatEventsBridge
        .publishUserEvent('participantAvailabilityUpdated', userId, payload)
        .catch((error) => {
          this.logger.warn(
            `Failed to fan-out participant availability across instances: ${error}`,
          );
        });
    }
  }

  async emitUserSyncEvent(
    userId: string,
    event: string,
    payload: Record<string, unknown>,
  ): Promise<void> {
    this.server.to(`user:${userId}`).emit(event, payload);
    this.chatEventsBridge
      .publishUserEvent(event, userId, payload)
      .catch((error) => {
        this.logger.warn(
          `Failed to fan-out ${event} for user ${userId}: ${error}`,
        );
      });
  }

  async emitGlobalSyncEvent(
    event: string,
    payload: Record<string, unknown>,
  ): Promise<void> {
    this.server.emit(event, payload);
    this.chatEventsBridge.publishGlobalEvent(event, payload).catch((error) => {
      this.logger.warn(`Failed to fan-out global ${event}: ${error}`);
    });
  }

  private extractSocketToken(client: Socket): string | null {
    const authHeader = client.handshake.headers?.authorization;
    if (typeof authHeader === 'string') {
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      if (match?.[1]) {
        return match[1].trim();
      }
    }

    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.trim().length > 0) {
      return authToken.trim();
    }

    return null;
  }

  private verifySocketToken(token: string): string | null {
    try {
      const secret = this.configService.get<string>('jwt.secret');
      if (!secret || secret.length < 32) {
        this.logger.error(
          'FATAL: JWT_SECRET is missing or too short for WebSocket verification. Rejecting connection.',
        );
        return null; 
      }
      const payload = this.jwtService.verify<{ sub?: string }>(token, { secret });
      return payload?.sub || null;
    } catch {
      return null;
    }
  }

  private requireSocketUserId(client: Socket): string {
    const userId = client.data?.userId as string | undefined;
    if (!userId) {
      throw new WsException('Unauthorized socket connection.');
    }
    return userId;
  }
}
