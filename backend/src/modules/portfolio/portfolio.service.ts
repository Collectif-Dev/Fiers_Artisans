import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PortfolioItem } from './schemas/portfolio-item.schema';
import { ArtisanProfile } from '../users/entities/artisan-profile.entity';

type PortfolioImageObject = { bucket: string; objectKey: string };

@Injectable()
export class PortfolioService {
  constructor(
    @InjectModel(PortfolioItem.name)
    private readonly portfolioModel: Model<PortfolioItem>,
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    private readonly configService: ConfigService,
  ) {}

  async create(
    userId: string,
    dto: any,
    requestBaseUrl?: string,
  ): Promise<Record<string, any>> {
    const profile = await this.artisanProfileRepository.findOne({
      where: { user_id: userId },
    });
    if (!profile) throw new NotFoundException('Profil artisan non trouvé.');

    const imageObjects = this.resolveImageObjects(dto);
    const rest = { ...(dto ?? {}) };
    delete (rest as Record<string, any>).imageUrls;
    delete (rest as Record<string, any>).imageObjects;
    delete (rest as Record<string, any>).images;

    const created = await this.portfolioModel.create({
      artisanProfileId: profile.id,
      ...rest,
      imageObjects,
      imageUrls: imageObjects.map((img) => this.toStorageMediaValue(img)),
    });

    return this.toResponseItem(created, requestBaseUrl);
  }

  async findMyItems(
    userId: string,
    requestBaseUrl?: string,
  ): Promise<Record<string, any>[]> {
    const profile = await this.artisanProfileRepository.findOne({
      where: { user_id: userId },
    });
    if (!profile) throw new NotFoundException('Profil artisan non trouvé.');

    const items = await this.portfolioModel
      .find({ artisanProfileId: profile.id })
      .sort({ createdAt: -1 })
      .exec();

    return Promise.all(
      items.map((item) => this.toResponseItem(item, requestBaseUrl)),
    );
  }

  async findByArtisan(
    artisanId: string,
    requestBaseUrl?: string,
  ): Promise<Record<string, any>[]> {
    const items = await this.portfolioModel
      .find({ artisanProfileId: artisanId })
      .sort({ createdAt: -1 })
      .exec();

    return Promise.all(
      items.map((item) => this.toResponseItem(item, requestBaseUrl)),
    );
  }

  async update(
    userId: string,
    itemId: string,
    dto: any,
    requestBaseUrl?: string,
  ): Promise<Record<string, any>> {
    const profile = await this.artisanProfileRepository.findOne({
      where: { user_id: userId },
    });
    if (!profile) throw new NotFoundException('Profil artisan non trouvé.');

    const item = await this.portfolioModel.findById(itemId).exec();
    if (!item) throw new NotFoundException('Réalisation non trouvée.');
    if (item.artisanProfileId !== profile.id) {
      throw new ForbiddenException('Accès non autorisé.');
    }

    const imageObjects = this.resolveImageObjects(dto);
    const rest = { ...(dto ?? {}) };
    delete (rest as Record<string, any>).imageUrls;
    delete (rest as Record<string, any>).imageObjects;
    delete (rest as Record<string, any>).images;

    Object.assign(item, rest);
    if (imageObjects.length > 0) {
      item.imageObjects = imageObjects;
      item.imageUrls = imageObjects.map((img) => this.toStorageMediaValue(img));
    }

    const saved = await item.save();
    return this.toResponseItem(saved, requestBaseUrl);
  }

  async remove(userId: string, itemId: string): Promise<void> {
    const profile = await this.artisanProfileRepository.findOne({
      where: { user_id: userId },
    });
    if (!profile) throw new NotFoundException('Profil artisan non trouvé.');

    const item = await this.portfolioModel.findById(itemId).exec();
    if (!item) throw new NotFoundException('Réalisation non trouvée.');
    if (item.artisanProfileId !== profile.id) {
      throw new ForbiddenException('Accès non autorisé.');
    }

    await this.portfolioModel.findByIdAndDelete(itemId).exec();
  }

  private async toResponseItem(
    item: PortfolioItem,
    requestBaseUrl?: string,
  ): Promise<Record<string, any>> {
    const raw = item.toObject() as Record<string, any>;
    const imageObjects = this.resolveImageObjects(raw);

    const shouldPersistImageObjects =
      imageObjects.length > 0 &&
      (!Array.isArray(raw.imageObjects) || raw.imageObjects.length === 0);

    if (shouldPersistImageObjects) {
      await this.portfolioModel
        .updateOne(
          { _id: raw._id },
          {
            $set: {
              imageObjects,
              imageUrls: imageObjects.map((img) => this.toStorageMediaValue(img)),
            },
          },
        )
        .exec();
    }

    const baseUrl = this.resolvePublicBaseUrl(requestBaseUrl);
    raw.imageObjects = imageObjects;
    raw.imageUrls = imageObjects.map((img) =>
      this.buildPublicMediaUrl(baseUrl, img),
    );
    return raw;
  }

  private resolveImageObjects(source: any): PortfolioImageObject[] {
    const fromObjects = this.parseImageObjects(source?.imageObjects ?? source?.images);
    if (fromObjects.length > 0) {
      return fromObjects;
    }
    return this.parseImageUrls(source?.imageUrls);
  }

  private parseImageObjects(values: unknown): PortfolioImageObject[] {
    if (!Array.isArray(values)) {
      return [];
    }

    const normalized: PortfolioImageObject[] = [];
    for (const value of values) {
      if (!value || typeof value !== 'object') continue;
      const bucket = String((value as any).bucket ?? '').trim();
      const objectKey = String((value as any).objectKey ?? '').trim();
      if (!bucket || !objectKey) continue;
      normalized.push({ bucket, objectKey });
    }
    return this.dedupeImageObjects(normalized);
  }

  private parseImageUrls(values: unknown): PortfolioImageObject[] {
    if (!Array.isArray(values)) {
      return [];
    }

    const parsed: PortfolioImageObject[] = [];
    for (const value of values) {
      if (typeof value !== 'string') continue;
      const ref = this.extractBucketAndObjectKey(value);
      if (ref) parsed.push(ref);
    }
    return this.dedupeImageObjects(parsed);
  }

  private dedupeImageObjects(values: PortfolioImageObject[]): PortfolioImageObject[] {
    const seen = new Set<string>();
    return values.filter((value) => {
      const key = `${value.bucket}/${value.objectKey}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  private extractBucketAndObjectKey(value: string): PortfolioImageObject | null {
    if (!value) {
      return null;
    }

    const trimmed = value.trim();
    if (!trimmed) {
      return null;
    }

    if (!trimmed.includes('://') && !trimmed.startsWith('/')) {
      const firstSlash = trimmed.indexOf('/');
      if (firstSlash > 0 && firstSlash < trimmed.length - 1) {
        const bucket = trimmed.slice(0, firstSlash);
        const objectKey = decodeURIComponent(trimmed.slice(firstSlash + 1));
        if (bucket && objectKey) {
          return { bucket, objectKey };
        }
      }
    }

    try {
      const url = new URL(trimmed);
      return this.extractFromPathParts(url.pathname.split('/').filter(Boolean));
    } catch {
      return this.extractFromPathParts(trimmed.split('/').filter(Boolean));
    }
  }

  private extractFromPathParts(pathParts: string[]): PortfolioImageObject | null {
    if (pathParts.length < 2) {
      return null;
    }

    const mediaIndex = pathParts.findIndex((part) => part === 'media');
    if (mediaIndex >= 0 && pathParts.length >= mediaIndex + 4) {
      const routeType = pathParts[mediaIndex + 1];
      if (routeType === 'file' || routeType === 'public') {
        const bucket = pathParts[mediaIndex + 2];
        const objectKey = decodeURIComponent(pathParts.slice(mediaIndex + 3).join('/'));
        if (bucket && objectKey) {
          return { bucket, objectKey };
        }
      }
    }

    const [bucket, ...objectParts] = pathParts;
    const objectKey = decodeURIComponent(objectParts.join('/'));
    if (!bucket || !objectKey) {
      return null;
    }
    return { bucket, objectKey };
  }

  private resolvePublicBaseUrl(requestBaseUrl?: string): string {
    if (requestBaseUrl && requestBaseUrl.trim().length > 0) {
      return requestBaseUrl.replace(/\/+$/, '');
    }

    const appUrl = this.configService.get<string>('app.appUrl') || 'http://localhost:3000';
    return appUrl.replace(/\/+$/, '');
  }

  private buildPublicMediaUrl(baseUrl: string, image: PortfolioImageObject): string {
    const bucket = encodeURIComponent(image.bucket);
    const objectKey = encodeURIComponent(image.objectKey);
    return `${baseUrl}/api/v1/media/public/${bucket}/${objectKey}`;
  }

  private toStorageMediaValue(image: PortfolioImageObject): string {
    return `${image.bucket}/${encodeURIComponent(image.objectKey)}`;
  }
}
