import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { InjectRepository } from '@nestjs/typeorm';
import { Model } from 'mongoose';
import { Repository, In } from 'typeorm';
import { Conversation } from './schemas/conversation.schema';
import { Message, MessageType } from './schemas/message.schema';
import { User, UserRole } from '../users/entities/user.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { ClientProfile } from '../users/entities/client-profile.entity';

type ParticipantMeta = {
  name: string;
  role: UserRole | string;
  isAvailable: boolean | null;
};

@Injectable()
export class ChatService {
  constructor(
    @InjectModel(Conversation.name)
    private readonly conversationModel: Model<Conversation>,
    @InjectModel(Message.name)
    private readonly messageModel: Model<Message>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
  ) {}

  async createConversation(
    participantIds: string[],
  ): Promise<Conversation> {
    const uniqueParticipants = Array.from(new Set(participantIds.filter(Boolean)));
    if (uniqueParticipants.length < 2) {
      throw new ForbiddenException('Une conversation nécessite deux participants.');
    }

    // Vérifier si la conversation existe déjà
    const existing = await this.conversationModel.findOne({
      participants: { $all: uniqueParticipants, $size: uniqueParticipants.length },
    });
    if (existing) return existing;

    return this.conversationModel.create({
      participants: uniqueParticipants,
    });
  }

  async getUserConversations(userId: string) {
    const conversations = await this.conversationModel
      .find({ participants: userId })
      .sort({ updatedAt: -1 })
      .lean()
      .exec();

    // Collect all other participant IDs
    const otherIds = new Set<string>();
    for (const c of conversations) {
      for (const p of c.participants) {
        if (p !== userId) otherIds.add(p);
      }
    }

    // Resolve names from profiles
    const participantMetaMap = await this.resolveParticipantMeta(
      Array.from(otherIds),
    );

    // Count unread per conversation
    const convoIds = conversations.map((c) => c._id.toString());
    const unreadCounts = await this.messageModel.aggregate([
      {
        $match: {
          conversationId: { $in: convoIds },
          senderId: { $ne: userId },
          isRead: false,
        },
      },
      { $group: { _id: '$conversationId', count: { $sum: 1 } } },
    ]);
    const unreadMap = new Map<string, number>();
    for (const u of unreadCounts) {
      unreadMap.set(u._id, u.count);
    }

    return conversations.map((c) => {
      const otherId = c.participants.find((p: string) => p !== userId) || '';
      const participantMeta = participantMetaMap.get(otherId);

      return {
        _id: c._id,
        participantId: otherId,
        participantName: participantMeta?.name || 'Utilisateur',
        participantRole: participantMeta?.role || null,
        participantIsAvailable: participantMeta?.isAvailable,
        lastMessage: c.lastMessage,
        unreadCount: unreadMap.get(c._id.toString()) || 0,
        updatedAt: (c as any).updatedAt,
      };
    });
  }

  private async resolveParticipantMeta(
    userIds: string[],
  ): Promise<Map<string, ParticipantMeta>> {
    if (userIds.length === 0) return new Map();

    const participantMetaMap = new Map<string, ParticipantMeta>();

    // Fetch user roles
    const users = await this.userRepository.find({
      where: { id: In(userIds) },
      select: ['id', 'role', 'phone_number'],
    });
    const artisanIds = users
      .filter((u) => u.role === 'ARTISAN')
      .map((u) => u.id);
    const clientIds = users
      .filter((u) => u.role === 'CLIENT')
      .map((u) => u.id);

    if (artisanIds.length > 0) {
      const profiles = await this.artisanProfileRepository.find({
        where: { user_id: In(artisanIds) },
        select: [
          'id',
          'user_id',
          'first_name',
          'last_name',
          'business_name',
          'is_available',
        ],
      });
      for (const p of profiles) {
        participantMetaMap.set(p.user_id, {
          name: p.business_name || `${p.first_name} ${p.last_name}`,
          role: UserRole.ARTISAN,
          isAvailable: p.is_available,
        });
      }
    }

    if (clientIds.length > 0) {
      const profiles = await this.clientProfileRepository.find({
        where: { user_id: In(clientIds) },
        select: ['id', 'user_id', 'first_name', 'last_name'],
      });
      for (const p of profiles) {
        participantMetaMap.set(p.user_id, {
          name: `${p.first_name} ${p.last_name}`,
          role: UserRole.CLIENT,
          isAvailable: null,
        });
      }
    }

    // Fallback to phone for users without a profile
    for (const u of users) {
      if (!participantMetaMap.has(u.id)) {
        participantMetaMap.set(u.id, {
          name: u.phone_number,
          role: u.role,
          isAvailable: null,
        });
      }
    }

    return participantMetaMap;
  }

  async getMessages(
    conversationId: string,
    userId: string,
    page = 1,
    limit = 50,
  ): Promise<Message[]> {
    await this.ensureParticipant(conversationId, userId);

    const messages = await this.messageModel
      .find({ conversationId })
      // Return latest messages first, then re-order in ascending order for UI rendering.
      .sort({ sentAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .exec();

    return messages.reverse();
  }

  async sendMessage(
    conversationId: string,
    senderId: string,
    content: string,
    type: string | MessageType = MessageType.TEXT,
    mediaUrl?: string,
  ): Promise<Message> {
    const conversation = await this.getConversationForParticipant(
      conversationId,
      senderId,
    );

    const message = await this.messageModel.create({
      conversationId,
      senderId,
      content,
      type: this.resolveMessageType(type),
      mediaUrl,
    });

    // Mettre à jour le dernier message de la conversation
    await this.conversationModel.findByIdAndUpdate(conversationId, {
      lastMessage: {
        content,
        sentAt: new Date(),
        senderId,
      },
    });

    return message;
  }

  private resolveMessageType(type?: string): MessageType {
    if (!type) return MessageType.TEXT;

    const normalized = type.toUpperCase();
    if (normalized === MessageType.IMAGE) return MessageType.IMAGE;
    if (normalized === MessageType.SYSTEM) return MessageType.SYSTEM;
    return MessageType.TEXT;
  }

  async markAsRead(conversationId: string, userId: string): Promise<void> {
    await this.ensureParticipant(conversationId, userId);

    await this.messageModel.updateMany(
      { conversationId, senderId: { $ne: userId }, isRead: false },
      { isRead: true },
    );
  }

  async findConversationParticipantIds(userId: string): Promise<string[]> {
    const conversations = await this.conversationModel
      .find({ participants: userId })
      .select({ participants: 1 })
      .lean()
      .exec();

    const participantIds = new Set<string>();
    for (const conversation of conversations) {
      for (const participantId of conversation.participants ?? []) {
        participantIds.add(participantId);
      }
    }

    participantIds.add(userId);
    return Array.from(participantIds);
  }

  async ensureParticipant(conversationId: string, userId: string): Promise<void> {
    await this.getConversationForParticipant(conversationId, userId);
  }

  private async getConversationForParticipant(
    conversationId: string,
    userId: string,
  ): Promise<Conversation> {
    const conversation = await this.conversationModel.findOne({
      _id: conversationId,
      participants: userId,
    });

    if (!conversation) {
      const exists = await this.conversationModel.exists({ _id: conversationId });
      if (!exists) {
        throw new NotFoundException('Conversation non trouvée.');
      }

      throw new ForbiddenException('Accès non autorisé à cette conversation.');
    }

    return conversation;
  }
}
