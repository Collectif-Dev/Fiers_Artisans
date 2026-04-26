import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({
  namespace: '/ws/map-visibility',
  cors: {
    origin: '*',
    credentials: true,
  },
})
export class MapVisibilityGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(MapVisibilityGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  handleConnection(client: Socket): void {
    const token = this.extractSocketToken(client);
    if (!token) {
      this.logger.warn(`Map socket ${client.id} rejected: missing auth token`);
      client.disconnect(true);
      return;
    }

    const userId = this.verifySocketToken(token);
    if (!userId) {
      this.logger.warn(`Map socket ${client.id} rejected: invalid auth token`);
      client.disconnect(true);
      return;
    }

    client.data.userId = userId;
    this.logger.debug(`Map client connected: ${client.id} (user ${userId})`);
  }

  handleDisconnect(client: Socket): void {
    const userId = client.data?.userId as string | undefined;
    this.logger.debug(
      `Map client disconnected: ${client.id}${userId ? ` (user ${userId})` : ''}`,
    );
  }

  @SubscribeMessage('joinCategoryRoom')
  handleJoinCategoryRoom(
    @MessageBody() payload: { categoryId?: string; subcategoryId?: string },
    @ConnectedSocket() client: Socket,
  ): { joined: string[] } {
    this.requireSocketUserId(client);
    const rooms: string[] = [];

    if (payload?.categoryId) {
      const room = `category:${payload.categoryId}`;
      client.join(room);
      rooms.push(room);
    }

    if (payload?.subcategoryId) {
      const room = `subcategory:${payload.subcategoryId}`;
      client.join(room);
      rooms.push(room);
    }

    if (rooms.length === 0) {
      client.join('global');
      rooms.push('global');
    }

    return { joined: rooms };
  }

  @SubscribeMessage('leaveCategoryRoom')
  handleLeaveCategoryRoom(
    @MessageBody() payload: { categoryId?: string; subcategoryId?: string },
    @ConnectedSocket() client: Socket,
  ): { left: string[] } {
    this.requireSocketUserId(client);
    const rooms: string[] = [];

    if (payload?.categoryId) {
      const room = `category:${payload.categoryId}`;
      client.leave(room);
      rooms.push(room);
    }

    if (payload?.subcategoryId) {
      const room = `subcategory:${payload.subcategoryId}`;
      client.leave(room);
      rooms.push(room);
    }

    return { left: rooms };
  }

  async emitArtisanVisibilityUpdated(params: {
    artisanUserId: string;
    isAvailable: boolean;
    categoryId?: string | null;
    subcategoryId?: string | null;
    latitude?: number | null;
    longitude?: number | null;
    locationUpdatedAt?: Date | null;
  }): Promise<void> {
    const payload = {
      artisan_user_id: params.artisanUserId,
      is_available: params.isAvailable,
      category_id: params.categoryId ?? null,
      subcategory_id: params.subcategoryId ?? null,
      latitude: params.latitude ?? null,
      longitude: params.longitude ?? null,
      location_updated_at: params.locationUpdatedAt
        ? params.locationUpdatedAt.toISOString()
        : null,
      timestamp: new Date().toISOString(),
    };

    this.server.emit('artisanVisibilityUpdated', payload);
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
      const payload = this.jwtService.verify<{ sub?: string }>(token, {
        secret:
          this.configService.get<string>('jwt.secret') || 'fallback-secret',
      });
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
