import { Injectable, BadRequestException } from '@nestjs/common';
import sharp from 'sharp';

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const ALLOWED_FORMATS = ['jpeg', 'jpg', 'png', 'webp'];
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;
const MIN_WIDTH = 480;
const MIN_HEIGHT = 640;

export interface ProofValidationResult {
  mimeType: string;
  sizeBytes: number;
  width: number;
  height: number;
  format: string;
  bytesPerPixel: number;
  suspiciousCompression: boolean;
}

@Injectable()
export class ProofValidationService {
  async validateImage(file: Express.Multer.File): Promise<ProofValidationResult> {
    if (!file?.buffer || file.buffer.length === 0) {
      throw new BadRequestException('Aucun fichier image fourni.');
    }

    if (file.size > MAX_FILE_SIZE_BYTES) {
      throw new BadRequestException('Image trop lourde (max 5 Mo).');
    }

    let metadata: sharp.Metadata;
    try {
      metadata = await sharp(file.buffer, { failOn: 'error' }).metadata();
    } catch {
      throw new BadRequestException('Image corrompue ou illisible.');
    }

    const format = (metadata.format ?? 'unknown').toLowerCase();
    if (!ALLOWED_FORMATS.includes(format)) {
      throw new BadRequestException(
        'Format non pris en charge. Utilisez une image JPG, PNG ou WEBP.',
      );
    }

    // Some clients send inconsistent MIME headers (for example HEIC wrappers)
    // while the actual binary payload is a valid JPEG/PNG/WEBP.
    // We trust the decoded format above to avoid false rejections.

    const width = metadata.width ?? 0;
    const height = metadata.height ?? 0;

    if (width < MIN_WIDTH || height < MIN_HEIGHT) {
      throw new BadRequestException(
        `Resolution insuffisante (minimum ${MIN_WIDTH}x${MIN_HEIGHT}).`,
      );
    }

    const bytesPerPixel = file.size / Math.max(1, width * height);
    const suspiciousCompression = bytesPerPixel < 0.05;

    return {
      mimeType:
        ALLOWED_MIME_TYPES.includes((file.mimetype || '').toLowerCase())
          ? file.mimetype.toLowerCase()
          : `image/${format === 'jpg' ? 'jpeg' : format}`,
      sizeBytes: file.size,
      width,
      height,
      format,
      bytesPerPixel,
      suspiciousCompression,
    };
  }
}
