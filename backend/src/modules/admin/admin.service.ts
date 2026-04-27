import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { ClientProfile } from '../users/entities/client-profile.entity';
import {
  Subscription,
  SubscriptionStatus,
} from '../subscription/entities/subscription.entity';
import {
  Payment,
  PaymentStatus,
} from '../subscription/entities/payment.entity';
import { Review } from '../reviews/entities/review.entity';
import { VerificationService } from '../verification/verification.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { ReviewDocumentDto } from '../verification/dto/review-document.dto';
import { AdminRealtimeService } from '../../common/realtime/admin-realtime.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    @InjectRepository(Subscription)
    private readonly subscriptionRepository: Repository<Subscription>,
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(Review)
    private readonly reviewRepository: Repository<Review>,
    private readonly verificationService: VerificationService,
    private readonly analyticsService: AnalyticsService,
    private readonly adminRealtimeService: AdminRealtimeService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async getDashboardStats() {
    const [
      totalClients,
      totalArtisans,
      activeSubscriptions,
      totalRevenue,
      pendingVerifications,
      totalReviews,
    ] = await Promise.all([
      this.userRepository
        .createQueryBuilder('u')
        .where('u.role = :role', { role: 'CLIENT' })
        .getCount(),
      this.artisanProfileRepository.count(),
      this.subscriptionRepository.count({
        where: { status: SubscriptionStatus.ACTIVE },
      }),
      this.paymentRepository
        .createQueryBuilder('p')
        .select('COALESCE(SUM(p.amount_fcfa), 0)', 'total')
        .where('p.status = :status', { status: PaymentStatus.SUCCESS })
        .getRawOne()
        .then((r) => parseInt(r.total, 10)),
      this.verificationService.countPendingDocuments(),
      this.reviewRepository.count(),
    ]);

    return {
      totalClients,
      totalArtisans,
      activeSubscriptions,
      totalRevenueFcfa: totalRevenue,
      pendingVerifications,
      totalReviews,
    };
  }

  private normalizePagination(
    page?: number,
    limit?: number,
  ): {
    page: number;
    limit: number;
  } {
    const safePage = Number.isFinite(page) ? Math.max(1, Math.floor(page!)) : 1;
    const safeLimit = Number.isFinite(limit)
      ? Math.min(100, Math.max(1, Math.floor(limit!)))
      : 50;
    return { page: safePage, limit: safeLimit };
  }

  async getPendingVerifications(page?: number, limit?: number) {
    const pagination = this.normalizePagination(page, limit);
    return this.verificationService.getPendingDocumentsPaginated(
      pagination.page,
      pagination.limit,
    );
  }

  async reviewDocument(docId: string, adminId: string, dto: ReviewDocumentDto) {
    return this.verificationService.reviewDocument(docId, adminId, dto);
  }

  async listArtisans(
    page?: number,
    limit?: number,
    search?: string,
    city?: string,
  ) {
    const pagination = this.normalizePagination(page, limit);
    const query = this.artisanProfileRepository
      .createQueryBuilder('ap')
      .leftJoinAndSelect('ap.user', 'user')
      .leftJoinAndSelect('ap.category', 'category')
      .leftJoinAndSelect('ap.subcategory', 'subcategory')
      .leftJoinAndSelect('ap.subscription', 'subscription')
      .orderBy('ap.created_at', 'DESC');

    if (search?.trim()) {
      query.andWhere(
        `(ap.first_name ILIKE :search OR ap.last_name ILIKE :search OR ap.business_name ILIKE :search)`,
        { search: `%${search.trim()}%` },
      );
    }

    if (city?.trim()) {
      query.andWhere('ap.city ILIKE :city', { city: city.trim() });
    }

    const [data, total] = await query
      .skip((pagination.page - 1) * pagination.limit)
      .take(pagination.limit)
      .getManyAndCount();

    return {
      data,
      total,
      page: pagination.page,
      limit: pagination.limit,
    };
  }

  async getAnalytics() {
    return this.analyticsService.getDashboardStats();
  }

  // ── Clients ─────────────────────────────────────────────────
  async listClients(page?: number, limit?: number, search?: string) {
    const pagination = this.normalizePagination(page, limit);
    const query = this.clientProfileRepository
      .createQueryBuilder('cp')
      .leftJoinAndSelect('cp.user', 'user')
      .orderBy('cp.created_at', 'DESC');

    if (search?.trim()) {
      query.andWhere(
        `(cp.first_name ILIKE :search OR cp.last_name ILIKE :search OR user.phone_number ILIKE :search)`,
        { search: `%${search.trim()}%` },
      );
    }

    const [data, total] = await query
      .skip((pagination.page - 1) * pagination.limit)
      .take(pagination.limit)
      .getManyAndCount();

    return {
      data,
      total,
      page: pagination.page,
      limit: pagination.limit,
    };
  }

  // ── Subscriptions ───────────────────────────────────────────
  async listSubscriptions(page?: number, limit?: number, status?: string) {
    const pagination = this.normalizePagination(page, limit);
    const query = this.subscriptionRepository
      .createQueryBuilder('s')
      .leftJoinAndSelect('s.artisan_profile', 'artisan_profile')
      .leftJoinAndSelect('artisan_profile.user', 'user')
      .leftJoinAndSelect('s.payments', 'payments')
      .orderBy('s.created_at', 'DESC');

    if (status?.trim()) {
      query.andWhere('s.status = :status', { status: status.trim() });
    }

    const [data, total] = await query
      .skip((pagination.page - 1) * pagination.limit)
      .take(pagination.limit)
      .getManyAndCount();

    return {
      data,
      total,
      page: pagination.page,
      limit: pagination.limit,
    };
  }

  // ── Reviews ─────────────────────────────────────────────────
  async listReviews(page?: number, limit?: number, rating?: number) {
    const pagination = this.normalizePagination(page, limit);
    const query = this.reviewRepository
      .createQueryBuilder('r')
      .leftJoinAndSelect('r.client', 'client')
      .leftJoinAndSelect('r.artisan', 'artisan')
      .orderBy('r.created_at', 'DESC');

    if (Number.isFinite(rating)) {
      query.andWhere('r.rating = :rating', { rating });
    }

    const [data, total] = await query
      .skip((pagination.page - 1) * pagination.limit)
      .take(pagination.limit)
      .getManyAndCount();

    return {
      data,
      total,
      page: pagination.page,
      limit: pagination.limit,
    };
  }

  async deleteReview(reviewId: string) {
    const review = await this.reviewRepository.findOne({
      where: { id: reviewId },
      select: ['id', 'artisan_id', 'client_id'],
    });

    if (!review) {
      throw new NotFoundException('Avis non trouvé.');
    }

    await this.reviewRepository.delete(reviewId);

    const result = await this.reviewRepository
      .createQueryBuilder('review')
      .select('AVG(review.rating)', 'avg')
      .addSelect('COUNT(review.id)', 'count')
      .where('review.artisan_id = :artisanId', { artisanId: review.artisan_id })
      .getRawOne<{ avg: string | null; count: string }>();

    await this.artisanProfileRepository.update(review.artisan_id, {
      rating_avg: parseFloat(result?.avg ?? '0') || 0,
      total_reviews: parseInt(result?.count ?? '0', 10) || 0,
    });

    this.adminRealtimeService.emit('REVIEW_DELETED', {
      reviewId,
      artisanId: review.artisan_id,
    });

    const [artisanProfile, clientProfile] = await Promise.all([
      this.artisanProfileRepository.findOne({
        where: { id: review.artisan_id },
        loadEagerRelations: false,
        select: {
          id: true,
          user_id: true,
        },
      }),
      this.clientProfileRepository.findOne({
        where: { id: review.client_id },
        select: ['user_id'],
      }),
    ]);

    if (artisanProfile?.user_id) {
      this.notificationsService
        .create({
          userId: artisanProfile.user_id,
          type: 'REVIEW_UPDATED',
          title: 'Avis supprimé',
          body: 'Un avis sur votre profil a été supprimé par la modération.',
          data: { reviewId, artisanId: review.artisan_id },
        })
        .catch(() => {});
    }

    if (clientProfile?.user_id) {
      this.notificationsService
        .create({
          userId: clientProfile.user_id,
          type: 'REVIEW_UPDATED',
          title: 'Avis supprimé',
          body: 'Votre avis a été supprimé par la modération.',
          data: { reviewId, artisanId: review.artisan_id },
        })
        .catch(() => {});
    }

    return { deleted: true };
  }

  // ── Activity Logs ───────────────────────────────────────────
  async getLogs(page = 1, limit = 50, action?: string) {
    return this.analyticsService.getLogs(page, limit, action);
  }
}
