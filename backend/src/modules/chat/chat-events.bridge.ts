import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import Redis from 'ioredis';
import type { Server } from 'socket.io';

type ConversationEventPayload = {
  kind: 'conversation';
  event: string;
  conversationId: string;
  payload: unknown;
  sourceInstanceId: string;
};

type UserEventPayload = {
  kind: 'user';
  event: string;
  userId: string;
  payload: unknown;
  sourceInstanceId: string;
};

type GlobalEventPayload = {
  kind: 'global';
  event: string;
  payload: unknown;
  sourceInstanceId: string;
};

type DistributedChatEvent =
  | ConversationEventPayload
  | UserEventPayload
  | GlobalEventPayload;

@Injectable()
export class ChatEventsBridge implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ChatEventsBridge.name);
  private readonly instanceId = randomUUID();
  private readonly channel = 'chat:events:v1';
  private readonly publisher: Redis;
  private readonly subscriber: Redis;

  private server: Server | null = null;
  private enabled = false;

  constructor(private readonly configService: ConfigService) {
    const host = this.configService.get<string>('redis.host') || 'localhost';
    const port = this.configService.get<number>('redis.port') || 6379;
    const password =
      this.configService.get<string>('redis.password') || undefined;

    const connectionOptions = {
      host,
      port,
      password,
    };

    this.publisher = new Redis(connectionOptions);
    this.subscriber = new Redis(connectionOptions);

    this.publisher.on('error', (error) => {
      this.logger.warn(`Redis publisher error: ${error}`);
    });
    this.subscriber.on('error', (error) => {
      this.logger.warn(`Redis subscriber error: ${error}`);
    });
  }

  bindServer(server: Server): void {
    this.server = server;
  }

  async onModuleInit(): Promise<void> {
    try {
      this.subscriber.on('message', this.handleRedisMessage);
      await this.subscriber.subscribe(this.channel);
      this.enabled = true;
      this.logger.log(
        `Distributed chat bridge enabled on channel "${this.channel}"`,
      );
    } catch (error) {
      this.enabled = false;
      this.logger.warn(`Distributed chat bridge disabled: ${error}`);
    }
  }

  async onModuleDestroy(): Promise<void> {
    this.subscriber.off('message', this.handleRedisMessage);
    await Promise.allSettled([this.subscriber.quit(), this.publisher.quit()]);
  }

  async publishConversationEvent(
    event: string,
    conversationId: string,
    payload: unknown,
  ): Promise<void> {
    await this.publish({
      kind: 'conversation',
      event,
      conversationId,
      payload,
      sourceInstanceId: this.instanceId,
    });
  }

  async publishUserEvent(
    event: string,
    userId: string,
    payload: unknown,
  ): Promise<void> {
    await this.publish({
      kind: 'user',
      event,
      userId,
      payload,
      sourceInstanceId: this.instanceId,
    });
  }

  async publishGlobalEvent(event: string, payload: unknown): Promise<void> {
    await this.publish({
      kind: 'global',
      event,
      payload,
      sourceInstanceId: this.instanceId,
    });
  }

  private async publish(event: DistributedChatEvent): Promise<void> {
    if (!this.enabled) {
      return;
    }

    try {
      await this.publisher.publish(this.channel, JSON.stringify(event));
    } catch (error) {
      this.logger.warn(`Failed to publish chat event: ${error}`);
    }
  }

  private handleRedisMessage = (_channel: string, rawPayload: string): void => {
    if (!this.server) {
      return;
    }

    try {
      const event = JSON.parse(rawPayload) as Partial<DistributedChatEvent>;
      if (event.sourceInstanceId === this.instanceId) {
        return;
      }

      if (
        event.kind === 'conversation' &&
        event.conversationId &&
        event.event
      ) {
        this.server
          .to(`conversation:${event.conversationId}`)
          .emit(event.event, event.payload);
        return;
      }

      if (event.kind === 'user' && event.userId && event.event) {
        this.server.to(`user:${event.userId}`).emit(event.event, event.payload);
        return;
      }

      if (event.kind === 'global' && event.event) {
        this.server.emit(event.event, event.payload);
      }
    } catch (error) {
      this.logger.warn(`Invalid distributed chat event payload: ${error}`);
    }
  };
}
