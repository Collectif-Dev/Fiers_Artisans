import {
  Controller,
  Post,
  Put,
  Get,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ReviewsService } from './reviews.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { ReplyReviewDto } from './dto/reply-review.dto';
import { CurrentUser, Roles } from '../../common/decorators';
import { RolesGuard, PhoneVerifiedGuard } from '../../common/guards';

@Controller('reviews')
@UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard)
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles('CLIENT')
  create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateReviewDto,
  ) {
    return this.reviewsService.create(userId, dto);
  }

  @Put(':reviewId/reply')
  @UseGuards(RolesGuard)
  @Roles('ARTISAN')
  replyToReview(
    @CurrentUser('id') userId: string,
    @Param('reviewId', ParseUUIDPipe) reviewId: string,
    @Body() dto: ReplyReviewDto,
  ) {
    return this.reviewsService.replyToReview(userId, reviewId, dto);
  }
}

@Controller('artisan')
export class ArtisanReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Get(':id/reviews')
  findByArtisan(@Param('id', ParseUUIDPipe) id: string) {
    return this.reviewsService.findByArtisan(id);
  }
}
