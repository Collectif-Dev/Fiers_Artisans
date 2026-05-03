import {
  Controller,
  Post,
  Get,
  Param,
  Query,
  Req,
  Res,
  BadRequestException,
  ForbiddenException,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request, Response } from 'express';
import { MediaService } from './media.service';
import { CurrentUser } from '../../common/decorators';
import { PhoneVerifiedGuard } from '../../common/guards';

@Controller('media')
export class MediaController {
  constructor(
    private readonly mediaService: MediaService,
    private readonly configService: ConfigService,
  ) {}

  private resolveRequestBaseUrl(req: Request): string {
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

  private buildStreamUrl(
    req: Request,
    routeType: 'file' | 'public',
    bucket: string,
    objectKey: string,
  ): string {
    const baseUrl = this.resolveRequestBaseUrl(req);
    return `${baseUrl}/api/v1/media/${routeType}/${encodeURIComponent(bucket)}/${encodeURIComponent(objectKey)}`;
  }

  private isPublicBucket(bucket: string): boolean {
    const portfolioBucket =
      this.configService.get<string>('minio.buckets.portfolio') || 'portfolio';
    const profilesBucket =
      this.configService.get<string>('minio.buckets.profiles') || 'profiles';
    return bucket === portfolioBucket || bucket === profilesBucket;
  }

  private getBucket(
    bucketKey: 'portfolio' | 'documents' | 'media' | 'profiles',
  ): string {
    return this.configService.get<string>(`minio.buckets.${bucketKey}`) || bucketKey;
  }

  private getAllowedUploadBuckets(): string[] {
    return [this.getBucket('portfolio'), this.getBucket('documents')];
  }

  private async handleUpload(
    userId: string,
    bucket: string,
    file: Express.Multer.File,
    req: Request,
  ) {
    const media = await this.mediaService.upload(userId, bucket, file);
    const [url, thumbnailUrl] = await Promise.all([
      this.mediaService.getSignedUrl(media.bucket, media.objectKey),
      media.thumbnailKey
        ? this.mediaService.getSignedUrl(media.bucket, media.thumbnailKey)
        : Promise.resolve(null),
    ]);
    const streamUrl = this.isPublicBucket(media.bucket)
      ? this.buildStreamUrl(req, 'public', media.bucket, media.objectKey)
      : this.buildStreamUrl(req, 'file', media.bucket, media.objectKey);
    const thumbnailStreamUrl = media.thumbnailKey
      ? this.isPublicBucket(media.bucket)
        ? this.buildStreamUrl(req, 'public', media.bucket, media.thumbnailKey)
        : this.buildStreamUrl(req, 'file', media.bucket, media.thumbnailKey)
      : null;

    return {
      id: media._id,
      url,
      streamUrl,
      objectKey: media.objectKey,
      bucket: media.bucket,
      thumbnailUrl,
      thumbnailStreamUrl,
      originalName: media.originalName,
      mimeType: media.mimeType,
      size: media.size,
    };
  }

  @Post('upload')
  @UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard)
  @UseInterceptors(FileInterceptor('file'))
  async upload(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
    @Query('bucket') bucket: string,
    @Req() req: Request,
  ) {
    const allowedBuckets = this.getAllowedUploadBuckets();
    if (!bucket || !allowedBuckets.includes(bucket)) {
      throw new BadRequestException(
        `Bucket non autorise. Buckets autorises: ${allowedBuckets.join(', ')}`,
      );
    }

    return this.handleUpload(userId, bucket, file, req);
  }

  @Post('upload/profile')
  @UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard)
  @UseInterceptors(FileInterceptor('file'))
  async uploadProfile(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request,
  ) {
    const bucket = this.getBucket('profiles');
    return this.handleUpload(userId, bucket, file, req);
  }

  @Post('upload/chat')
  @UseGuards(AuthGuard('jwt'), PhoneVerifiedGuard)
  @UseInterceptors(FileInterceptor('file'))
  async uploadChatAttachment(
    @CurrentUser('id') userId: string,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request,
  ) {
    const bucket = this.getBucket('media');
    return this.handleUpload(userId, bucket, file, req);
  }

  @Get('file/:bucket/:objectKey')
  @UseGuards(AuthGuard('jwt'))
  async streamFile(
    @Param('bucket') bucket: string,
    @Param('objectKey') objectKey: string,
    @Res() res: Response,
  ) {
    try {
      const { stream, contentType, size } = await this.mediaService.streamFile(
        bucket,
        objectKey,
      );
      res.set({
        'Content-Type': contentType,
        'Content-Length': size.toString(),
        'Cache-Control': 'private, max-age=3600',
        'Content-Disposition': 'inline',
      });
      (stream as NodeJS.ReadableStream).pipe(res);
    } catch {
      throw new NotFoundException('Fichier introuvable.');
    }
  }

  @Get('public/:bucket/:objectKey')
  async streamPublicFile(
    @Param('bucket') bucket: string,
    @Param('objectKey') objectKey: string,
    @Res() res: Response,
  ) {
    if (!this.isPublicBucket(bucket)) {
      throw new ForbiddenException('AccĂ¨s public non autorisĂ© pour ce bucket.');
    }

    try {
      const { stream, contentType, size } = await this.mediaService.streamFile(
        bucket,
        objectKey,
      );
      res.set({
        'Content-Type': contentType,
        'Content-Length': size.toString(),
        'Cache-Control': 'public, max-age=3600',
        'Content-Disposition': 'inline',
      });
      (stream as NodeJS.ReadableStream).pipe(res);
    } catch {
      throw new NotFoundException('Fichier introuvable.');
    }
  }
}
