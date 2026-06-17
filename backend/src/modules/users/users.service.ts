import { Injectable, NotFoundException, HttpStatus } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User, UserRole } from './entities/user.entity';
import { ArtisanProfile } from './entities/artisan-profile.entity';
import { ClientProfile } from './entities/client-profile.entity';
import { FavoriteArtisan } from './entities/favorite-artisan.entity';
import { Subcategory } from '../categories/entities/subcategory.entity';
import { UpdateArtisanProfileDto } from './dto/update-artisan-profile.dto';
import { UpdateClientProfileDto } from './dto/update-client-profile.dto';
import { AnalyticsService } from '../analytics/analytics.service';
import { ChatGateway } from '../chat/chat.gateway';
import { MapVisibilityGateway } from './map-visibility.gateway';
import { AdminRealtimeService } from '../../common/realtime/admin-realtime.service';
import { BusinessException } from '../../common/exceptions/business.exception';

type UserLocationSnapshot = {
  latitude: number | null;
  longitude: number | null;
  locationUpdatedAt: Date | null;
};

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    @InjectRepository(FavoriteArtisan)
    private readonly favoriteArtisanRepository: Repository<FavoriteArtisan>,
    @InjectRepository(Subcategory)
    private readonly subcategoryRepository: Repository<Subcategory>,
    private readonly analyticsService: AnalyticsService,
    private readonly chatGateway: ChatGateway,
    private readonly mapVisibilityGateway: MapVisibilityGateway,
    private readonly adminRealtimeService: AdminRealtimeService,
  ) {}

  private async getUserLocationSnapshot(
    userId: string,
  ): Promise<UserLocationSnapshot> {
    const rawLocation = await this.userRepository
      .createQueryBuilder('u')
      .select('u.location_updated_at', 'location_updated_at')
      .addSelect('ST_Y(u.location::geometry)', 'latitude')
      .addSelect('ST_X(u.location::geometry)', 'longitude')
      .where('u.id = :id', { id: userId })
      .getRawOne<{
        location_updated_at: string | Date | null;
        latitude: string | null;
        longitude: string | null;
      }>();

    return {
      latitude:
        rawLocation?.latitude != null ? Number(rawLocation.latitude) : null,
      longitude:
        rawLocation?.longitude != null ? Number(rawLocation.longitude) : null,
      locationUpdatedAt: rawLocation?.location_updated_at
        ? new Date(rawLocation.location_updated_at)
        : null,
    };
  }

  private async attachLocationSnapshot<
    T extends { user_id?: string; user?: { id?: string | null } | null },
  >(entity: T): Promise<T> {
    const userId = entity.user_id ?? entity.user?.id ?? null;
    if (!userId) {
      return entity;
    }

    const snapshot = await this.getUserLocationSnapshot(userId);
    Object.assign(entity as Record<string, unknown>, {
      latitude: snapshot.latitude,
      longitude: snapshot.longitude,
      location_updated_at: snapshot.locationUpdatedAt,
      locationUpdatedAt: snapshot.locationUpdatedAt,
    });
    return entity;
  }

  private async userHasStoredLocation(userId: string): Promise<boolean> {
    const snapshot = await this.getUserLocationSnapshot(userId);
    return snapshot.latitude != null && snapshot.longitude != null;
  }

  private async ensureArtisanLocationForVisibility(
    userId: string,
  ): Promise<void> {
    if (await this.userHasStoredLocation(userId)) {
      return;
    }

    throw new BusinessException(
      'PROFILE_LOCATION_REQUIRED_FOR_AVAILABILITY',
      'Impossible de rendre votre profil visible sans position GPS valide. Mettez d abord votre localisation a jour.',
      HttpStatus.BAD_REQUEST,
    );
  }

  private async emitMapVisibilityUpdate(
    artisanUserId: string,
    isAvailable: boolean,
    profileHint?: {
      id?: string;
      category_id: string;
      subcategory_id: string;
      is_subscription_active: boolean;
    },
  ): Promise<void> {
    const profile = profileHint
      ? profileHint
      : await this.artisanProfileRepository.findOne({
          where: { user_id: artisanUserId },
          loadEagerRelations: false,
          select: [
            'id',
            'user_id',
            'category_id',
            'subcategory_id',
            'is_subscription_active',
          ],
        });

    if (!profile) {
      return;
    }

    const rawLocation = await this.getUserLocationSnapshot(artisanUserId);

    await this.mapVisibilityGateway.emitArtisanVisibilityUpdated({
      artisanUserId,
      isAvailable: isAvailable && profile.is_subscription_active,
      categoryId: profile.category_id,
      subcategoryId: profile.subcategory_id,
      latitude: rawLocation.latitude,
      longitude: rawLocation.longitude,
      locationUpdatedAt: rawLocation.locationUpdatedAt,
    });
  }

  async findById(id: string): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id },
      relations: ['artisan_profile', 'client_profile'],
    });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé.');
    }
    return user;
  }

  async findByPhone(phone_number: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { phone_number },
      relations: ['artisan_profile', 'client_profile'],
    });
  }

  async getArtisanProfile(userId: string): Promise<ArtisanProfile> {
    const profile = await this.artisanProfileRepository.findOne({
      where: { user_id: userId },
      relations: ['category', 'subcategory', 'user'],
    });
    if (!profile) {
      throw new NotFoundException('Profil artisan non trouvé.');
    }
    return this.attachLocationSnapshot(profile);
  }

  async getArtisanPublicProfile(artisanId: string): Promise<ArtisanProfile> {
    // Try by profile ID first, then by user ID (mobile sends userId)
    let profile = await this.artisanProfileRepository.findOne({
      where: { id: artisanId, is_subscription_active: true },
      relations: ['category', 'subcategory', 'user'],
    });
    if (!profile) {
      profile = await this.artisanProfileRepository.findOne({
        where: { user: { id: artisanId }, is_subscription_active: true },
        relations: ['category', 'subcategory', 'user'],
      });
    }
    if (!profile) {
      throw new NotFoundException('Artisan non trouvé ou non actif.');
    }

    this.analyticsService
      .logActivity({
        actorId: 'anonymous',
        action: 'PROFILE_VIEW',
        targetId: profile.id,
      })
      .catch(() => {});

    return this.attachLocationSnapshot(profile);
  }

  async updateArtisanProfile(
    userId: string,
    dto: UpdateArtisanProfileDto,
  ): Promise<ArtisanProfile> {
    const profile = await this.artisanProfileRepository.findOne({
      where: { user_id: userId },
      relations: ['subcategory'],
    });
    if (!profile) {
      throw new NotFoundException('Profil artisan non trouvé.');
    }
    const previousAvailability = profile.is_available;

    if (dto.is_available === true) {
      await this.ensureArtisanLocationForVisibility(userId);
    }

    if (dto.subcategory_id) {
      const subcategory = await this.subcategoryRepository.findOne({
        where: { id: dto.subcategory_id },
        select: ['id', 'category_id'],
      });

      if (!subcategory) {
        throw new NotFoundException('Metier non trouve.');
      }

      const nextCategoryId = dto.category_id ?? profile.category_id;
      if (nextCategoryId && subcategory.category_id !== nextCategoryId) {
        throw new NotFoundException(
          'La categorie ne correspond pas au metier selectionne.',
        );
      }

      dto.category_id = dto.category_id ?? subcategory.category_id;
    }

    if (
      dto.category_id &&
      !dto.subcategory_id &&
      profile.subcategory_id &&
      profile.subcategory?.category_id &&
      profile.subcategory.category_id !== dto.category_id
    ) {
      dto.subcategory_id = null;
    }

    Object.assign(profile, dto);
    const savedProfile = await this.artisanProfileRepository.save(profile);

    if (
      dto.is_available !== undefined &&
      previousAvailability !== savedProfile.is_available
    ) {
      this.chatGateway
        .emitParticipantAvailabilityUpdated(
          savedProfile.user_id,
          savedProfile.is_available,
        )
        .catch(() => {});

      this.emitMapVisibilityUpdate(
        savedProfile.user_id,
        savedProfile.is_available,
        {
          category_id: savedProfile.category_id,
          subcategory_id: savedProfile.subcategory_id,
          is_subscription_active: savedProfile.is_subscription_active,
        },
      ).catch(() => {});
    }

    this.adminRealtimeService.emit('ARTISAN_UPDATED', {
      userId: savedProfile.user_id,
      artisanProfileId: savedProfile.id,
      categoryId: savedProfile.category_id,
      subcategoryId: savedProfile.subcategory_id,
      isAvailable: savedProfile.is_available,
      isSubscriptionActive: savedProfile.is_subscription_active,
    });
    this.chatGateway
      .emitUserSyncEvent(savedProfile.user_id, 'userProfileUpdated', {
        role: 'ARTISAN',
        updatedAt: new Date().toISOString(),
      })
      .catch(() => {});
    this.chatGateway
      .emitGlobalSyncEvent('artisanProfileUpdated', {
        artisanUserId: savedProfile.user_id,
        artisanProfileId: savedProfile.id,
        isAvailable: savedProfile.is_available,
        categoryId: savedProfile.category_id,
        subcategoryId: savedProfile.subcategory_id,
        isSubscriptionActive: savedProfile.is_subscription_active,
        updatedAt: new Date().toISOString(),
      })
      .catch(() => {});

    return this.attachLocationSnapshot(savedProfile);
  }

  async getArtisanStats(userId: string): Promise<{
    profile_views_48h: number;
    window_hours: number;
  }> {
    const profile = await this.getArtisanProfile(userId);
    const profileViews48h =
      await this.analyticsService.countProfileViewsInLastHours(profile.id, 48);
    return {
      profile_views_48h: profileViews48h,
      window_hours: 48,
    };
  }

  async getClientProfile(userId: string): Promise<ClientProfile> {
    const profile = await this.clientProfileRepository.findOne({
      where: { user_id: userId },
      relations: ['user'],
    });
    if (!profile) {
      throw new NotFoundException('Profil client non trouvé.');
    }
    return this.attachLocationSnapshot(profile);
  }

  async updateClientProfile(
    userId: string,
    dto: UpdateClientProfileDto,
  ): Promise<ClientProfile> {
    const profile = await this.clientProfileRepository.findOne({
      where: { user_id: userId },
    });
    if (!profile) {
      throw new NotFoundException('Profil client non trouvé.');
    }
    Object.assign(profile, dto);
    const saved = await this.clientProfileRepository.save(profile);
    this.adminRealtimeService.emit('CLIENT_UPDATED', {
      userId: saved.user_id,
      clientProfileId: saved.id,
      city: saved.city,
      commune: saved.commune,
    });
    this.chatGateway
      .emitUserSyncEvent(saved.user_id, 'userProfileUpdated', {
        role: 'CLIENT',
        updatedAt: new Date().toISOString(),
      })
      .catch(() => {});
    return this.attachLocationSnapshot(saved);
  }

  async listFavoriteArtisans(
    clientUserId: string,
  ): Promise<Record<string, any>[]> {
    const clientProfile = await this.getClientProfile(clientUserId);
    const favorites = await this.favoriteArtisanRepository.find({
      where: { client_profile_id: clientProfile.id },
      relations: [
        'artisan_profile',
        'artisan_profile.user',
        'artisan_profile.category',
        'artisan_profile.subcategory',
      ],
      order: { created_at: 'DESC' },
    });
    return favorites.map((favorite) => {
      const profile = favorite.artisan_profile;
      return {
        id: profile.id,
        user_id: profile.user_id,
        first_name: profile.first_name,
        last_name: profile.last_name,
        business_name: profile.business_name,
        bio: profile.bio,
        years_experience: profile.years_experience,
        city: profile.city,
        commune: profile.commune,
        rating_avg: profile.rating_avg,
        total_reviews: profile.total_reviews,
        is_available: profile.is_available,
        is_subscription_active: profile.is_subscription_active,
        category_id: profile.category_id,
        subcategory_id: profile.subcategory_id,
        category: profile.category,
        subcategory: profile.subcategory,
        created_at: profile.created_at,
        updated_at: profile.updated_at,
        user: profile.user
          ? {
              id: profile.user.id,
              phone_number: profile.user.phone_number,
              email: profile.user.email,
              verification_status: profile.user.verification_status,
            }
          : null,
      };
    });
  }

  async getFavoriteStatus(
    clientUserId: string,
    artisanIdentifier: string,
  ): Promise<{ is_favorite: boolean }> {
    const isFavorite = await this.isFavorite(clientUserId, artisanIdentifier);
    return { is_favorite: isFavorite };
  }

  async setFavoriteArtisan(
    clientUserId: string,
    artisanIdentifier: string,
    isFavorite: boolean,
  ): Promise<{ is_favorite: boolean }> {
    const clientProfile = await this.getClientProfile(clientUserId);
    const artisanProfile =
      await this.findArtisanProfileByIdentifier(artisanIdentifier);

    const existing = await this.favoriteArtisanRepository.findOne({
      where: {
        client_profile_id: clientProfile.id,
        artisan_profile_id: artisanProfile.id,
      },
    });

    if (isFavorite) {
      if (!existing) {
        await this.favoriteArtisanRepository.save(
          this.favoriteArtisanRepository.create({
            client_profile_id: clientProfile.id,
            artisan_profile_id: artisanProfile.id,
          }),
        );
      }
      this.chatGateway
        .emitUserSyncEvent(clientUserId, 'favoriteStatusUpdated', {
          artisanUserId: artisanProfile.user_id,
          isFavorite: true,
          updatedAt: new Date().toISOString(),
        })
        .catch(() => {});
      return { is_favorite: true };
    }

    if (existing) {
      await this.favoriteArtisanRepository.delete(existing.id);
    }
    this.chatGateway
      .emitUserSyncEvent(clientUserId, 'favoriteStatusUpdated', {
        artisanUserId: artisanProfile.user_id,
        isFavorite: false,
        updatedAt: new Date().toISOString(),
      })
      .catch(() => {});
    return { is_favorite: false };
  }

  private async isFavorite(
    clientUserId: string,
    artisanIdentifier: string,
  ): Promise<boolean> {
    const clientProfile = await this.getClientProfile(clientUserId);
    const artisanProfile =
      await this.findArtisanProfileByIdentifier(artisanIdentifier);
    const favorite = await this.favoriteArtisanRepository.findOne({
      where: {
        client_profile_id: clientProfile.id,
        artisan_profile_id: artisanProfile.id,
      },
      select: ['id'],
    });
    return !!favorite;
  }

  private async findArtisanProfileByIdentifier(
    artisanIdentifier: string,
  ): Promise<ArtisanProfile> {
    let profile = await this.artisanProfileRepository.findOne({
      where: { user: { id: artisanIdentifier } },
      relations: ['user', 'category', 'subcategory'],
    });

    if (!profile) {
      profile = await this.artisanProfileRepository.findOne({
        where: { id: artisanIdentifier },
        relations: ['user', 'category', 'subcategory'],
      });
    }

    if (!profile) {
      throw new NotFoundException('Artisan non trouvé.');
    }

    return profile;
  }

  async updateUserLocation(
    userId: string,
    lat: number,
    lng: number,
    city?: string,
    commune?: string,
  ): Promise<void> {
    const normalizedCity = city?.trim();
    const normalizedCommune = commune?.trim();

    await this.userRepository.manager.transaction(async (manager) => {
      await manager
        .createQueryBuilder()
        .update(User)
        .set({
          location: () => 'ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)',
          location_updated_at: () => 'CURRENT_TIMESTAMP',
        })
        .where('id = :id', { id: userId })
        .setParameters({ lat, lng })
        .execute();

      const user = await manager.getRepository(User).findOne({
        where: { id: userId },
        select: ['id', 'role'],
      });

      if (
        user?.role === UserRole.ARTISAN &&
        (normalizedCity || normalizedCommune)
      ) {
        await manager.getRepository(ArtisanProfile).update(
          { user_id: userId },
          {
            ...(normalizedCity ? { city: normalizedCity } : {}),
            ...(normalizedCommune ? { commune: normalizedCommune } : {}),
          },
        );
      }

      if (
        user?.role === UserRole.CLIENT &&
        (normalizedCity || normalizedCommune)
      ) {
        await manager.getRepository(ClientProfile).update(
          { user_id: userId },
          {
            ...(normalizedCity ? { city: normalizedCity } : {}),
            ...(normalizedCommune ? { commune: normalizedCommune } : {}),
          },
        );
      }
    });

    const snapshot = await this.getUserLocationSnapshot(userId);
    const updatedAtIso =
      snapshot.locationUpdatedAt?.toISOString() ?? new Date().toISOString();

    const user = await this.userRepository.findOne({
      where: { id: userId },
      select: ['id', 'role'],
    });

    if (user?.role === UserRole.ARTISAN) {
      const artisanProfile = await this.artisanProfileRepository.findOne({
        where: { user_id: userId },
        loadEagerRelations: false,
        select: [
          'id',
          'user_id',
          'category_id',
          'subcategory_id',
          'is_available',
          'is_subscription_active',
        ],
      });

      if (artisanProfile) {
        this.emitMapVisibilityUpdate(userId, artisanProfile.is_available, {
          category_id: artisanProfile.category_id,
          subcategory_id: artisanProfile.subcategory_id,
          is_subscription_active: artisanProfile.is_subscription_active,
        }).catch(() => {});

        this.adminRealtimeService.emit('ARTISAN_UPDATED', {
          userId,
          artisanProfileId: artisanProfile.id,
          categoryId: artisanProfile.category_id,
          subcategoryId: artisanProfile.subcategory_id,
          isAvailable: artisanProfile.is_available,
          isSubscriptionActive: artisanProfile.is_subscription_active,
          latitude: snapshot.latitude,
          longitude: snapshot.longitude,
          locationUpdatedAt: updatedAtIso,
        });
        this.chatGateway
          .emitUserSyncEvent(userId, 'userProfileUpdated', {
            role: 'ARTISAN',
            updatedAt: updatedAtIso,
            locationUpdatedAt: updatedAtIso,
          })
          .catch(() => {});
        this.chatGateway
          .emitGlobalSyncEvent('artisanProfileUpdated', {
            artisanUserId: userId,
            artisanProfileId: artisanProfile.id,
            isAvailable: artisanProfile.is_available,
            categoryId: artisanProfile.category_id,
            subcategoryId: artisanProfile.subcategory_id,
            isSubscriptionActive: artisanProfile.is_subscription_active,
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            locationUpdatedAt: updatedAtIso,
            updatedAt: updatedAtIso,
          })
          .catch(() => {});
      }

      return;
    }

    if (user?.role === UserRole.CLIENT) {
      const clientProfile = await this.clientProfileRepository.findOne({
        where: { user_id: userId },
        loadEagerRelations: false,
        select: ['id', 'user_id', 'city', 'commune'],
      });

      this.adminRealtimeService.emit('CLIENT_UPDATED', {
        userId,
        clientProfileId: clientProfile?.id ?? null,
        city: clientProfile?.city ?? null,
        commune: clientProfile?.commune ?? null,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        locationUpdatedAt: updatedAtIso,
      });
      this.chatGateway
        .emitUserSyncEvent(userId, 'userProfileUpdated', {
          role: 'CLIENT',
          updatedAt: updatedAtIso,
          locationUpdatedAt: updatedAtIso,
        })
        .catch(() => {});
    }
  }

  async updateFcmToken(userId: string, fcmToken: string): Promise<void> {
    await this.userRepository.update(userId, { fcm_token: fcmToken });
  }
}
