import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import type { Request } from 'express';
import { PortfolioService } from './portfolio.service';
import { CurrentUser, Roles } from '../../common/decorators';
import { RolesGuard, PhoneVerifiedGuard } from '../../common/guards';

@Controller('portfolio')
@UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard, RolesGuard)
@Roles('ARTISAN')
export class PortfolioController {
  constructor(private readonly portfolioService: PortfolioService) {}

  private getRequestBaseUrl(req: Request): string {
    const forwardedProto = req.headers['x-forwarded-proto'];
    const forwardedHost = req.headers['x-forwarded-host'];
    const protocol =
      (Array.isArray(forwardedProto) ? forwardedProto[0] : forwardedProto) ||
      req.protocol ||
      'http';
    const host =
      (Array.isArray(forwardedHost) ? forwardedHost[0] : forwardedHost) ||
      req.get('host') ||
      'localhost:3000';
    return `${protocol}://${host}`;
  }

  @Get()
  findMyItems(@CurrentUser('id') userId: string, @Req() req: Request) {
    return this.portfolioService.findMyItems(
      userId,
      this.getRequestBaseUrl(req),
    );
  }

  @Post()
  create(
    @CurrentUser('id') userId: string,
    @Body() dto: any,
    @Req() req: Request,
  ) {
    return this.portfolioService.create(userId, dto, this.getRequestBaseUrl(req));
  }

  @Put(':id')
  update(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: Request,
  ) {
    return this.portfolioService.update(
      userId,
      id,
      dto,
      this.getRequestBaseUrl(req),
    );
  }

  @Delete(':id')
  remove(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.portfolioService.remove(userId, id);
  }
}

@Controller('artisan')
export class ArtisanPortfolioController {
  constructor(private readonly portfolioService: PortfolioService) {}

  private getRequestBaseUrl(req: Request): string {
    const forwardedProto = req.headers['x-forwarded-proto'];
    const forwardedHost = req.headers['x-forwarded-host'];
    const protocol =
      (Array.isArray(forwardedProto) ? forwardedProto[0] : forwardedProto) ||
      req.protocol ||
      'http';
    const host =
      (Array.isArray(forwardedHost) ? forwardedHost[0] : forwardedHost) ||
      req.get('host') ||
      'localhost:3000';
    return `${protocol}://${host}`;
  }

  @Get(':id/portfolio')
  findByArtisan(@Param('id') id: string, @Req() req: Request) {
    return this.portfolioService.findByArtisan(id, this.getRequestBaseUrl(req));
  }
}
