import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { SearchArtisansDto } from './dto/search-artisans.dto';
import { AnalyticsService } from '../analytics/analytics.service';

@Injectable()
export class SearchService {
  constructor(
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    private readonly analyticsService: AnalyticsService,
  ) {}

  async searchArtisans(dto: SearchArtisansDto) {
    const {
      lat,
      lng,
      radius_km = 10,
      min_rating,
      category,
      subcategory,
      query,
      sort_by = 'distance',
      available_only = false,
      page = 1,
      limit = 20,
    } = dto;
    const safeRadiusKm = Math.min(Math.max(radius_km ?? 10, 1), 100);
    const safePage = Math.max(page ?? 1, 1);
    const safeLimit = Math.min(Math.max(limit ?? 20, 1), 50);
    const offset = (safePage - 1) * safeLimit;
    const normalizedQuery = query?.trim();

    let qb = this.artisanProfileRepository
      .createQueryBuilder('ap')
      .innerJoinAndSelect('ap.user', 'u')
      .leftJoinAndSelect('ap.category', 'c')
      .leftJoinAndSelect('ap.subcategory', 'sc')
      .select([
        'ap.id',
        'ap.user_id',
        'ap.first_name',
        'ap.last_name',
        'ap.business_name',
        'ap.bio',
        'ap.category_id',
        'ap.subcategory_id',
        'ap.city',
        'ap.commune',
        'ap.address',
        'ap.rating_avg',
        'ap.total_reviews',
        'ap.years_experience',
        'ap.is_available',
        'ap.is_subscription_active',
        'ap.whatsapp_number',
        'ap.working_hours',
        'ap.last_active_at',
        'ap.created_at',
        'ap.updated_at',
        'u.id',
        'u.phone_number',
        'u.verification_status',
        'u.is_active',
        'u.location',
        'u.location_updated_at',
        'c.id',
        'c.name',
        'c.icon_url',
        'c.slug',
        'c.is_active',
        'c.display_order',
        'sc.id',
        'sc.category_id',
        'sc.name',
        'sc.slug',
      ])
      .where('ap.is_subscription_active = :active', { active: true })
      .andWhere('u.is_active = :isActive', { isActive: true })
      .andWhere('ap.is_available = :isAvailable', { isAvailable: true })
      // PostGIS : filtrer par rayon en km
      .andWhere(
        `ST_DWithin(
          u.location::geography,
          ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
          :radius
        )`,
        { lat, lng, radius: safeRadiusKm * 1000 },
      )
      // Ajouter la distance calculée
      .addSelect(
        `ST_Distance(
          u.location::geography,
          ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
        )`,
        'distance_meters',
      )
      .addSelect('ST_Y(u.location::geometry)', 'user_latitude')
      .addSelect('ST_X(u.location::geometry)', 'user_longitude')
      .addSelect('u.location_updated_at', 'user_location_updated_at');

    // Conservé pour compatibilité de contrat; tous les résultats sont désormais disponibles.
    if (available_only) {
      qb = qb.andWhere('ap.is_available = :avail', { avail: true });
    }

    if (min_rating != null) {
      qb = qb.andWhere('ap.rating_avg >= :minRating', {
        minRating: min_rating,
      });
    }

    if (category) {
      // Accept both category slug and UUID id from mobile
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          category,
        );
      if (isUuid) {
        qb = qb.andWhere('c.id = :category', { category });
      } else {
        qb = qb.andWhere('c.slug = :category', { category });
      }
    }

    if (subcategory) {
      // Accept both subcategory slug and UUID id from mobile
      const isSubcategoryUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          subcategory,
        );
      if (isSubcategoryUuid) {
        qb = qb.andWhere('sc.id = :subcategory', { subcategory });
      } else {
        qb = qb.andWhere('sc.slug = :subcategory', { subcategory });
      }
    }

    if (normalizedQuery) {
      qb = qb.andWhere(
        `(
          ap.first_name ILIKE :query OR
          ap.last_name ILIKE :query OR
          ap.business_name ILIKE :query OR
          c.name ILIKE :query OR
          c.slug ILIKE :query OR
          sc.name ILIKE :query OR
          sc.slug ILIKE :query
        )`,
        { query: `%${normalizedQuery}%` },
      );
    }

    if (sort_by === 'rating') {
      qb = qb
        .orderBy('ap.rating_avg', 'DESC')
        .addOrderBy('distance_meters', 'ASC');
    } else {
      qb = qb.orderBy('distance_meters', 'ASC');
    }

    const total = await qb.getCount();

    const { entities, raw } = await qb
      .skip(offset)
      .take(safeLimit)
      .getRawAndEntities();

    const results = entities.map((entity, index) => {
      const distanceMeters = Number(raw[index]?.distance_meters);
      const rawLatitude = raw[index]?.user_latitude;
      const rawLongitude = raw[index]?.user_longitude;

      // Expose distance in km for mobile cards and sorting transparency.
      (entity as any).distance = Number.isFinite(distanceMeters)
        ? distanceMeters / 1000
        : null;
      (entity as any).latitude =
        rawLatitude != null ? Number(rawLatitude) : null;
      (entity as any).longitude =
        rawLongitude != null ? Number(rawLongitude) : null;
      (entity as any).location_updated_at =
        raw[index]?.user_location_updated_at ?? null;

      // ── SECURITY: Strip sensitive user fields from search results ──
      if ((entity as any).user) {
        const user = (entity as any).user;
        (entity as any).user = {
          id: user.id,
          first_name: user.first_name,
          last_name: user.last_name,
          phone_number: user.phone_number,
          verification_status: user.verification_status,
        };
      }
      // ── FIN SECURITY ──

      return entity;
    });

    const roundedLat = Number(Number(lat).toFixed(4));
    const roundedLng = Number(Number(lng).toFixed(4));

    // Fire-and-forget analytics
    this.analyticsService
      .logActivity({
        actorId: 'anonymous',
        action: 'SEARCH',
        metadata: {
          category,
          subcategory,
          query: normalizedQuery,
          lat: roundedLat,
          lng: roundedLng,
          min_rating,
          available_only,
          results: total,
        },
      })
      .catch(() => {});

    return {
      data: results,
      meta: {
        total,
        page: safePage,
        limit: safeLimit,
        totalPages: Math.ceil(total / safeLimit),
      },
    };
  }
}
