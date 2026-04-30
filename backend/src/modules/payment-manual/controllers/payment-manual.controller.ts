import {
  Controller,
  Post,
  Get,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  ParseUUIDPipe,
  ParseFilePipe,
  MaxFileSizeValidator,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, Roles } from '../../../common/decorators';
import { RolesGuard, PhoneVerifiedGuard } from '../../../common/guards';
import { PaymentManualService } from '../services/payment-manual.service';
import { CreatePaymentManualDto } from '../dto/create-payment-manual.dto';
import { SubmitProofDto } from '../dto/submit-proof.dto';

@Controller('payments/manual')
@UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard, RolesGuard)
@Roles('ARTISAN')
export class PaymentManualController {
  constructor(private readonly paymentManualService: PaymentManualService) {}

  @Post('initiate')
  @Throttle({ default: { limit: 5, ttl: 60 * 60 * 1000 } })
  async initiatePayment(
    @CurrentUser('id') userId: string,
    @Body() dto: CreatePaymentManualDto,
  ) {
    const payment = await this.paymentManualService.initiatePayment(userId, dto.provider);
    return {
      transaction_id: payment.transaction_id,
      provider: payment.provider,
      amount_fcfa: payment.amount_fcfa,
      status: payment.status,
      expires_at_admin: payment.expires_at_admin,
      recipient_number: process.env.PAYMENT_MANUAL_RECIPIENT_NUMBER || process.env.WAVE_MERCHANT_ID || 'N/A',
    };
  }

  @Get(':transactionId')
  async getStatus(
    @Param('transactionId') transactionId: string,
    @CurrentUser('id') userId: string,
  ) {
    const payment = await this.paymentManualService.getStatus(transactionId, userId);
    return payment;
  }

  @Post(':transactionId/submit-proof')
  @Throttle({ default: { limit: 3, ttl: 24 * 60 * 60 * 1000 } })
  @UseInterceptors(FileInterceptor('file'))
  async submitProof(
    @Param('transactionId') transactionId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: SubmitProofDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    const proof = await this.paymentManualService.submitProof({
      transactionId,
      userId,
      file,
      senderNumber: dto.sender_number,
      declaredTime: dto.declared_payment_time ? new Date(dto.declared_payment_time) : undefined,
    });

    return proof;
  }

  @Get(':transactionId/proof/:proofId')
  async getProofUrl(
    @Param('transactionId') transactionId: string,
    @Param('proofId', ParseUUIDPipe) proofId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.paymentManualService.getProofSignedUrl(transactionId, proofId, userId);
  }
}
