import {
  Controller,
  Post,
  Get,
  Put,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { VerificationService } from './verification.service';
import { SubmitDocumentDto } from './dto/submit-document.dto';
import { ReviewDocumentDto } from './dto/review-document.dto';
import { CurrentUser, Roles } from '../../common/decorators';
import { RolesGuard, PhoneVerifiedGuard } from '../../common/guards';

@Controller('verification')
@UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard)
export class VerificationController {
  constructor(private readonly verificationService: VerificationService) {}

  @Post('submit')
  @UseGuards(RolesGuard)
  @Roles('ARTISAN')
  submitDocument(
    @CurrentUser('id') userId: string,
    @Body() dto: SubmitDocumentDto,
  ) {
    return this.verificationService.submitDocument(userId, dto);
  }

  @Get('status')
  getMyVerificationStatus(@CurrentUser('id') userId: string) {
    return this.verificationService.getVerificationStatus(userId);
  }
}
