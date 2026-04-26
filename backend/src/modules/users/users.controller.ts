import {
  Controller,
  Get,
  Put,
  Delete,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { UsersService } from './users.service';
import { UpdateArtisanProfileDto } from './dto/update-artisan-profile.dto';
import { UpdateClientProfileDto } from './dto/update-client-profile.dto';
import { CurrentUser } from '../../common/decorators';
import { RolesGuard, PhoneVerifiedGuard } from '../../common/guards';
import { Roles } from '../../common/decorators';
import { UpdateLocationDto } from './dto';

@Controller()
@UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  // ── FCM Token ──────────────────────────────────────────────────
  @Put('users/fcm-token')
  updateFcmToken(
    @CurrentUser('id') userId: string,
    @Body('fcmToken') fcmToken: string,
  ) {
    return this.usersService.updateFcmToken(userId, fcmToken);
  }

  @Put('users/location')
  updateMyLocation(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateLocationDto,
  ) {
    return this.usersService.updateUserLocation(userId, dto.lat, dto.lng);
  }

  // ── Artisan Profile ─────────────────────────────────────────────
  @Get('artisan/profile')
  @UseGuards(RolesGuard)
  @Roles('ARTISAN')
  getMyArtisanProfile(@CurrentUser('id') userId: string) {
    return this.usersService.getArtisanProfile(userId);
  }

  @Put('artisan/profile')
  @UseGuards(RolesGuard)
  @Roles('ARTISAN')
  updateMyArtisanProfile(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateArtisanProfileDto,
  ) {
    return this.usersService.updateArtisanProfile(userId, dto);
  }

  @Get('artisan/stats')
  @UseGuards(RolesGuard)
  @Roles('ARTISAN')
  getMyArtisanStats(@CurrentUser('id') userId: string) {
    return this.usersService.getArtisanStats(userId);
  }

  // ── Client Profile ──────────────────────────────────────────────
  @Get('client/profile')
  @UseGuards(RolesGuard)
  @Roles('CLIENT')
  getMyClientProfile(@CurrentUser('id') userId: string) {
    return this.usersService.getClientProfile(userId);
  }

  @Put('client/profile')
  @UseGuards(RolesGuard)
  @Roles('CLIENT')
  updateMyClientProfile(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateClientProfileDto,
  ) {
    return this.usersService.updateClientProfile(userId, dto);
  }

  @Get('client/favorites')
  @UseGuards(RolesGuard)
  @Roles('CLIENT')
  getFavoriteArtisans(@CurrentUser('id') userId: string) {
    return this.usersService.listFavoriteArtisans(userId);
  }

  @Get('client/favorites/:artisanUserId/status')
  @UseGuards(RolesGuard)
  @Roles('CLIENT')
  getFavoriteStatus(
    @CurrentUser('id') userId: string,
    @Param('artisanUserId', ParseUUIDPipe) artisanUserId: string,
  ) {
    return this.usersService.getFavoriteStatus(userId, artisanUserId);
  }

  @Put('client/favorites/:artisanUserId')
  @UseGuards(RolesGuard)
  @Roles('CLIENT')
  addFavoriteArtisan(
    @CurrentUser('id') userId: string,
    @Param('artisanUserId', ParseUUIDPipe) artisanUserId: string,
  ) {
    return this.usersService.setFavoriteArtisan(userId, artisanUserId, true);
  }

  @Delete('client/favorites/:artisanUserId')
  @UseGuards(RolesGuard)
  @Roles('CLIENT')
  removeFavoriteArtisan(
    @CurrentUser('id') userId: string,
    @Param('artisanUserId', ParseUUIDPipe) artisanUserId: string,
  ) {
    return this.usersService.setFavoriteArtisan(userId, artisanUserId, false);
  }
}

@Controller('artisan')
export class PublicArtisanController {
  constructor(private readonly usersService: UsersService) {}

  @Get(':id')
  getArtisanPublicProfile(@Param('id', ParseUUIDPipe) id: string) {
    return this.usersService.getArtisanPublicProfile(id);
  }
}
