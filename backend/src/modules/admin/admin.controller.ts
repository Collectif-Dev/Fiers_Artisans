import {
  Controller,
  Get,
  Put,
  Delete,
  Param,
  Body,
  Query,
  Sse,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AdminService } from './admin.service';
import { VerificationService } from '../verification/verification.service';
import { AdminRealtimeService } from '../../common/realtime/admin-realtime.service';
import { CurrentUser, Roles } from '../../common/decorators';
import { RolesGuard } from '../../common/guards';
import { ReviewDocumentDto } from '../verification/dto/review-document.dto';
import type { Observable } from 'rxjs';

@Controller('admin')
@UseGuards(AuthGuard('jwt'), RolesGuard)
@Roles('ADMIN')
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly verificationService: VerificationService,
    private readonly adminRealtimeService: AdminRealtimeService,
  ) {}

  @Get('dashboard')
  getDashboard() {
    return this.adminService.getDashboardStats();
  }

  @Get('verifications/pending')
  getPendingVerifications(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.adminService.getPendingVerifications(page, limit);
  }

  @Put('verifications/:id')
  reviewDocument(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: ReviewDocumentDto,
  ) {
    return this.adminService.reviewDocument(id, adminId, dto);
  }

  /** Global admin realtime stream used by all dashboard pages. */
  @Sse('events')
  events(): Observable<MessageEvent> {
    return this.adminRealtimeService.asSseStream();
  }

  /** SSE stream: emits on new submissions and reviews for real-time admin refresh. */
  @Sse('verifications/events')
  verificationEvents(): Observable<MessageEvent> {
    return this.verificationService.docEvents$;
  }

  @Get('artisans')
  listArtisans(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('search') search?: string,
    @Query('city') city?: string,
  ) {
    return this.adminService.listArtisans(page, limit, search, city);
  }

  @Get('analytics')
  getAnalytics() {
    return this.adminService.getAnalytics();
  }

  // ── Clients ─────────────────────────────────────────────────
  @Get('clients')
  listClients(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('search') search?: string,
  ) {
    return this.adminService.listClients(page, limit, search);
  }

  // ── Subscriptions ───────────────────────────────────────────
  @Get('subscriptions')
  listSubscriptions(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('status') status?: string,
  ) {
    return this.adminService.listSubscriptions(page, limit, status);
  }

  // ── Reviews ─────────────────────────────────────────────────
  @Get('reviews')
  listReviews(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('rating') rating?: number,
  ) {
    return this.adminService.listReviews(page, limit, rating);
  }

  @Delete('reviews/:id')
  deleteReview(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.deleteReview(id);
  }

  // ── Activity Logs ───────────────────────────────────────────
  @Get('logs')
  getLogs(
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('action') action?: string,
  ) {
    return this.adminService.getLogs(page || 1, limit || 50, action);
  }
}
