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
      sort_by = 'distance', available_only = false,
      page = 1, limit = 20,
    } = dto;
    const offset = (page - 1) * limit;

    let qb = this.artisanProfileRepository
      .createQueryBuilder('ap')
      .innerJoinAndSelect('ap.user', 'u')
      .leftJoinAndSelect('ap.category', 'c')
      .leftJoinAndSelect('ap.subcategory', 'sc')
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
        { lat, lng, radius: radius_km * 1000 },
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
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(category);
      if (isUuid) {
        qb = qb.andWhere('c.id = :category', { category });
      } else {
        qb = qb.andWhere('c.slug = :category', { category });
      }
    }

    if (subcategory) {
      // Accept both subcategory slug and UUID id from mobile
      const isSubcategoryUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(subcategory);
      if (isSubcategoryUuid) {
        qb = qb.andWhere('sc.id = :subcategory', { subcategory });
      } else {
        qb = qb.andWhere('sc.slug = :subcategory', { subcategory });
      }
    }

    if (query) {
      qb = qb.andWhere(
        `(ap.first_name ILIKE :query OR ap.last_name ILIKE :query OR ap.business_name ILIKE :query)`,
        { query: `%${query}%` },
      );
    }

    if (sort_by === 'rating') {
      qb = qb.orderBy('ap.rating_avg', 'DESC').addOrderBy('distance_meters', 'ASC');
    } else {
      qb = qb.orderBy('distance_meters', 'ASC');
    }

    const total = await qb.getCount();

    const { entities, raw } = await qb
      .skip(offset)
      .take(limit)
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
      return entity;
    });

    // Fire-and-forget analytics
    this.analyticsService.logActivity({
      actorId: 'anonymous',
      action: 'SEARCH',
      metadata: {
        category,
        subcategory,
        query,
        lat,
        lng,
        min_rating,
        available_only,
        results: total,
      },
    }).catch(() => {});

    return {
      data: results,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
