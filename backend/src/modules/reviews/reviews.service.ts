import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from './entities/review.entity';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { ClientProfile } from '../users/entities/client-profile.entity';
import { CreateReviewDto } from './dto/create-review.dto';
import { ReplyReviewDto } from './dto/reply-review.dto';
import { AdminRealtimeService } from '../../common/realtime/admin-realtime.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(Review)
    private readonly reviewRepository: Repository<Review>,
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    private readonly adminRealtimeService: AdminRealtimeService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateReviewDto): Promise<Review> {
    // Récupérer le profil client
    const clientProfile = await this.clientProfileRepository.findOne({
      where: { user_id: userId },
    });
    if (!clientProfile) {
      throw new NotFoundException('Profil client non trouvé.');
    }

    // Vérifier l'unicité : un seul avis par client par artisan
    const existing = await this.reviewRepository.findOne({
      where: { client_id: clientProfile.id, artisan_id: dto.artisan_id },
    });
    if (existing) {
      throw new ConflictException(
        'Vous avez déjà laissé un avis pour cet artisan.',
      );
    }

    // Créer l'avis
    const review = this.reviewRepository.create({
      client_id: clientProfile.id,
      artisan_id: dto.artisan_id,
      rating: dto.rating,
      comment: dto.comment,
    });
    const saved = await this.reviewRepository.save(review);

    // Recalculer la note moyenne de l'artisan
    await this.updateArtisanRating(dto.artisan_id);

    this.adminRealtimeService.emit('REVIEW_CREATED', {
      reviewId: saved.id,
      artisanId: saved.artisan_id,
      clientId: saved.client_id,
      rating: saved.rating,
    });

    const artisanProfile = await this.artisanProfileRepository.findOne({
      where: { id: saved.artisan_id },
      loadEagerRelations: false,
      select: {
        id: true,
        user_id: true,
      },
    });
    if (artisanProfile?.user_id) {
      this.notificationsService
        .create({
          userId: artisanProfile.user_id,
          type: 'REVIEW_CREATED',
          title: 'Nouvel avis reçu',
          body: `Vous avez reçu une nouvelle note de ${saved.rating}/5.`,
          data: {
            reviewId: saved.id,
            artisanId: saved.artisan_id,
          },
        })
        .catch(() => {});
    }

    return saved;
  }

  async findByArtisan(artisanId: string): Promise<Review[]> {
    return this.reviewRepository.find({
      where: { artisan_id: artisanId },
      relations: ['client'],
      order: { created_at: 'DESC' },
    });
  }

  async replyToReview(
    artisanUserId: string,
    reviewId: string,
    dto: ReplyReviewDto,
  ): Promise<Review> {
    const artisanProfile = await this.artisanProfileRepository.findOne({
      where: { user_id: artisanUserId },
      loadEagerRelations: false,
      select: {
        id: true,
      },
    });

    if (!artisanProfile) {
      throw new NotFoundException('Profil artisan non trouvé.');
    }

    const review = await this.reviewRepository.findOne({
      where: { id: reviewId, artisan_id: artisanProfile.id },
      relations: ['client'],
    });

    if (!review) {
      throw new NotFoundException('Avis introuvable.');
    }

    if ((review.artisan_reply ?? '').trim().length > 0) {
      throw new ConflictException('Une réponse existe déjà pour cet avis.');
    }

    review.artisan_reply = dto.reply.trim();
    review.artisan_reply_at = new Date();
    const saved = await this.reviewRepository.save(review);

    this.adminRealtimeService.emit('REVIEW_REPLIED', {
      reviewId: saved.id,
      artisanId: saved.artisan_id,
      clientId: saved.client_id,
    });

    const clientProfile = await this.clientProfileRepository.findOne({
      where: { id: saved.client_id },
      select: ['user_id'],
    });
    if (clientProfile?.user_id) {
      this.notificationsService
        .create({
          userId: clientProfile.user_id,
          type: 'REVIEW_UPDATED',
          title: 'Réponse à votre avis',
          body: 'Un artisan a répondu à votre avis.',
          data: {
            reviewId: saved.id,
            artisanId: saved.artisan_id,
          },
        })
        .catch(() => {});
    }

    return saved;
  }

  private async updateArtisanRating(artisanId: string): Promise<void> {
    const result = await this.reviewRepository
      .createQueryBuilder('review')
      .select('AVG(review.rating)', 'avg')
      .addSelect('COUNT(review.id)', 'count')
      .where('review.artisan_id = :artisanId', { artisanId })
      .getRawOne();

    await this.artisanProfileRepository.update(artisanId, {
      rating_avg: parseFloat(result.avg) || 0,
      total_reviews: parseInt(result.count, 10) || 0,
    });
  }
}
