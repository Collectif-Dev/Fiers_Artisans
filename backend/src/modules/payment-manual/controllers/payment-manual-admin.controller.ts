import {
  Controller,
  Get,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  Sse,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { RolesGuard } from '../../../common/guards';
import { CurrentUser, Roles } from '../../../common/decorators';
import { PaymentManualService } from '../services/payment-manual.service';
import { RejectProofDto } from '../dto/reject-proof.dto';
import { ValidateProofDto } from '../dto/validate-proof.dto';
import { AdminFilterDto } from '../dto/admin-filter.dto';
import { ReopenProofDto } from '../dto/reopen-proof.dto';
import { AdminRealtimeService } from '../../../common/realtime/admin-realtime.service';
import type { Observable } from 'rxjs';

@Controller('admin')
@UseGuards(AuthGuard('jwt'), RolesGuard)
@Roles('ADMIN')
export class PaymentManualAdminController {
  constructor(
    private readonly paymentManualService: PaymentManualService,
    private readonly adminRealtimeService: AdminRealtimeService,
  ) {}

  @Get('payment-proofs')
  getList(@Query() filters: AdminFilterDto) {
    return this.paymentManualService.getAdminList(filters);
  }

  @Get('payment-proofs/:id/details')
  getDetails(@Param('id', ParseUUIDPipe) id: string) {
    return this.paymentManualService.getDetailed(id);
  }

  @Patch('payment-proofs/:id/validate')
  async validate(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: ValidateProofDto,
  ) {
    await this.paymentManualService.validateProof(id, adminId, dto.notes);
    return { success: true };
  }

  @Patch('payment-proofs/:id/reject')
  async reject(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: RejectProofDto,
  ) {
    await this.paymentManualService.rejectProof(id, adminId, dto.reason);
    return { success: true };
  }

  @Patch('payment-proofs/:id/reopen')
  async reopen(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: ReopenProofDto,
  ) {
    await this.paymentManualService.reopenProof(id, adminId, dto.reason);
    return { success: true };
  }

  @Patch('payment-proofs/:id/mark-refunded')
  async markRefunded(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
  ) {
    await this.paymentManualService.markRefundDone(id, adminId);
    return { success: true };
  }

  @Delete('payment-proofs/:id')
  async softDelete(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') adminId: string,
  ) {
    await this.paymentManualService.softDeletePayment(id, adminId);
    return { success: true };
  }

  @Sse('payment-events')
  paymentEvents(): Observable<MessageEvent> {
    return this.adminRealtimeService.asSseStream();
  }
}
