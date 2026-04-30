import { Injectable, BadRequestException } from '@nestjs/common';
import sharp from 'sharp';

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
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

    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      throw new BadRequestException(
        `Type de fichier invalide. Formats acceptes: ${ALLOWED_MIME_TYPES.join(', ')}`,
      );
    }

    if (file.size > MAX_FILE_SIZE_BYTES) {
      throw new BadRequestException('Image trop lourde (max 5 Mo).');
    }

    this.assertMagicBytes(file.buffer, file.mimetype);

    let metadata: sharp.Metadata;
    try {
      metadata = await sharp(file.buffer, { failOn: 'error' }).metadata();
    } catch {
      throw new BadRequestException('Image corrompue ou illisible.');
    }

    const width = metadata.width ?? 0;
    const height = metadata.height ?? 0;
    const format = metadata.format ?? 'unknown';

    if (width < MIN_WIDTH || height < MIN_HEIGHT) {
      throw new BadRequestException(
        `Resolution insuffisante (minimum ${MIN_WIDTH}x${MIN_HEIGHT}).`,
      );
    }

    const bytesPerPixel = file.size / Math.max(1, width * height);
    const suspiciousCompression = bytesPerPixel < 0.05;

    return {
      mimeType: file.mimetype,
      sizeBytes: file.size,
      width,
      height,
      format,
      bytesPerPixel,
      suspiciousCompression,
    };
  }

  private assertMagicBytes(buffer: Buffer, mimeType: string): void {
    const header = buffer.subarray(0, 12);

    const isJpeg = header[0] === 0xff && header[1] === 0xd8 && header[2] === 0xff;
    const isPng =
      header[0] === 0x89 &&
      header[1] === 0x50 &&
      header[2] === 0x4e &&
      header[3] === 0x47;
    const isWebp =
      header[0] === 0x52 &&
      header[1] === 0x49 &&
      header[2] === 0x46 &&
      header[3] === 0x46 &&
      header[8] === 0x57 &&
      header[9] === 0x45 &&
      header[10] === 0x42 &&
      header[11] === 0x50;

    const validByMime =
      (mimeType === 'image/jpeg' && isJpeg) ||
      (mimeType === 'image/png' && isPng) ||
      (mimeType === 'image/webp' && isWebp);

    if (!validByMime) {
      throw new BadRequestException('Le type reel du fichier ne correspond pas au MIME annonce.');
    }
  }
}
