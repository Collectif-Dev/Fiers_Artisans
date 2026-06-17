import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import * as Minio from 'minio';
import sharp from 'sharp';
import { MediaFile } from './schemas/media-file.schema';

const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);
  private readonly minioClient: Minio.Client;
  private readonly minioSigningClient: Minio.Client;

  constructor(
    @InjectModel(MediaFile.name)
    private readonly mediaFileModel: Model<MediaFile>,
    private readonly configService: ConfigService,
  ) {
    this.minioClient = new Minio.Client({
      endPoint: this.configService.get<string>('minio.endpoint') || 'localhost',
      port: this.configService.get<number>('minio.port') || 9000,
      useSSL: this.configService.get<boolean>('minio.useSSL') || false,
      accessKey: this.configService.get<string>('minio.accessKey') || '',
      secretKey: this.configService.get<string>('minio.secretKey') || '',
    });

    this.minioSigningClient = new Minio.Client({
      endPoint:
        this.configService.get<string>('minio.publicEndpoint') ||
        this.configService.get<string>('minio.endpoint') ||
        'localhost',
      port:
        this.configService.get<number>('minio.publicPort') ||
        this.configService.get<number>('minio.port') ||
        9000,
      useSSL:
        this.configService.get<boolean>('minio.publicUseSSL') ||
        this.configService.get<boolean>('minio.useSSL') ||
        false,
      accessKey: this.configService.get<string>('minio.accessKey') || '',
      secretKey: this.configService.get<string>('minio.secretKey') || '',
    });
  }

  async onModuleInit() {
    // Créer les buckets s'ils n'existent pas
    const buckets =
      this.configService.get<Record<string, string>>('minio.buckets') || {};
    for (const bucket of Object.values(buckets)) {
      const exists = await this.minioClient.bucketExists(bucket);
      if (!exists) {
        await this.minioClient.makeBucket(bucket);
        this.logger.log(`Bucket "${bucket}" created`);
      }
    }
  }

  async upload(
    userId: string,
    bucket: string,
    file: Express.Multer.File,
  ): Promise<MediaFile> {
    // Validation
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      throw new BadRequestException(
        `Type de fichier non autorisé. Types acceptés : ${ALLOWED_MIME_TYPES.join(', ')}`,
      );
    }
    if (file.size > MAX_FILE_SIZE) {
      throw new BadRequestException(
        'Le fichier dépasse la taille maximale de 10 MB.',
      );
    }

    const fileId = randomUUID();
    const ext = file.originalname.split('.').pop();
    const objectKey = `${fileId}.${ext}`;
    let thumbnailKey: string | undefined;

    // Compression des images avec Sharp
    if (file.mimetype.startsWith('image/')) {
      const [optimized, thumbnail] = await Promise.all([
        sharp(file.buffer)
          .resize(1200, 1200, { fit: 'inside', withoutEnlargement: true })
          .jpeg({ quality: 80, progressive: true })
          .toBuffer(),
        sharp(file.buffer)
          .resize(300, 300, { fit: 'cover' })
          .jpeg({ quality: 70 })
          .toBuffer(),
      ]);

      thumbnailKey = `${fileId}_thumb.jpg`;

      await Promise.all([
        this.minioClient.putObject(
          bucket,
          objectKey,
          optimized,
          optimized.length,
          {
            'Content-Type': 'image/jpeg',
          },
        ),
        this.minioClient.putObject(
          bucket,
          thumbnailKey,
          thumbnail,
          thumbnail.length,
          {
            'Content-Type': 'image/jpeg',
          },
        ),
      ]);
    } else {
      await this.minioClient.putObject(
        bucket,
        objectKey,
        file.buffer,
        file.size,
        {
          'Content-Type': file.mimetype,
        },
      );
    }

    // Sauvegarder les métadonnées dans MongoDB
    return this.mediaFileModel.create({
      userId,
      bucket,
      objectKey,
      originalName: file.originalname,
      mimeType: file.mimetype,
      size: file.size,
      thumbnailKey,
    });
  }

  async getSignedUrl(bucket: string, objectKey: string): Promise<string> {
    // URL signée valide 1 heure.
    // In Docker, public endpoint can be unreachable from inside the container.
    try {
      return await this.minioSigningClient.presignedGetObject(
        bucket,
        objectKey,
        3600,
      );
    } catch (error) {
      this.logger.warn(
        `Public signing endpoint unavailable for ${bucket}/${objectKey}, fallback to internal MinIO endpoint`,
      );
      return this.minioClient.presignedGetObject(bucket, objectKey, 3600);
    }
  }

  async hasBucket(bucket: string): Promise<boolean> {
    return this.minioClient.bucketExists(bucket);
  }

  async uploadRaw(
    userId: string,
    bucket: string,
    file: Express.Multer.File,
    forcedObjectKey?: string,
  ): Promise<{
    id: string;
    bucket: string;
    objectKey: string;
    mimeType: string;
    size: number;
    originalName: string;
  }> {
    if (!file?.buffer || file.buffer.length === 0) {
      throw new BadRequestException('Fichier vide.');
    }

    if (file.size > MAX_FILE_SIZE) {
      throw new BadRequestException(
        'Le fichier depasse la taille maximale de 10 MB.',
      );
    }

    const ext = file.originalname.split('.').pop() || 'bin';
    const fileId = randomUUID();
    const objectKey = forcedObjectKey || `${fileId}.${ext}`;

    await this.minioClient.putObject(
      bucket,
      objectKey,
      file.buffer,
      file.size,
      {
        'Content-Type': file.mimetype || 'application/octet-stream',
      },
    );

    const media = (await this.mediaFileModel.create({
      userId,
      bucket,
      objectKey,
      originalName: file.originalname,
      mimeType: file.mimetype || 'application/octet-stream',
      size: file.size,
      thumbnailKey: undefined,
    })) as MediaFile & { _id: unknown };

    return {
      id: String(media._id),
      bucket,
      objectKey,
      mimeType: file.mimetype || 'application/octet-stream',
      size: file.size,
      originalName: file.originalname,
    };
  }

  async streamFile(
    bucket: string,
    objectKey: string,
  ): Promise<{
    stream: NodeJS.ReadableStream;
    contentType: string;
    size: number;
  }> {
    const stat = await this.minioClient.statObject(bucket, objectKey);
    const stream = await this.minioClient.getObject(bucket, objectKey);
    const contentType =
      stat.metaData?.['content-type'] || this.guessMimeType(objectKey);
    return { stream, contentType, size: stat.size };
  }

  private guessMimeType(objectKey: string): string {
    const ext = objectKey.split('.').pop()?.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  async delete(bucket: string, objectKey: string): Promise<void> {
    await this.minioClient.removeObject(bucket, objectKey);
  }
}
