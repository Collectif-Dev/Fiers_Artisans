import { Injectable } from '@nestjs/common';
import sharp from 'sharp';

export interface ExifData {
  captureDate: Date | null;
  modifiedDate: Date | null;
  device: string | null;
  software: string | null;
  hasExif: boolean;
}

@Injectable()
export class ExifExtractorService {
  async extract(buffer: Buffer): Promise<ExifData> {
    const metadata = await sharp(buffer, { failOn: 'none' }).metadata();
    const metadataAny = metadata as sharp.Metadata & {
      make?: string;
      model?: string;
      software?: string;
    };

    const captureDate = this.parseExifDate(
      this.searchExifAscii(metadata.exif, ['DateTimeOriginal', 'CreateDate']),
    );
    const modifiedDate = this.parseExifDate(
      this.searchExifAscii(metadata.exif, ['ModifyDate', 'DateTime']),
    );

    const deviceParts = [metadataAny.make, metadataAny.model]
      .filter((v) => typeof v === 'string' && v.trim().length > 0)
      .map((v) => (v as string).trim());

    const software =
      this.searchExifAscii(metadata.exif, ['Software']) ||
      metadataAny.software ||
      null;

    return {
      captureDate,
      modifiedDate,
      device: deviceParts.length > 0 ? deviceParts.join(' ') : null,
      software: software?.trim() || null,
      hasExif: Boolean(metadata.exif && metadata.exif.length > 0),
    };
  }

  detectSuspiciousSoftware(exif: ExifData): boolean {
    const software = exif.software?.toLowerCase() || '';
    if (!software) {
      return false;
    }

    const suspiciousKeywords = [
      'photoshop',
      'canva',
      'gimp',
      'snapseed',
      'lightroom',
      'pixlr',
      'facetune',
    ];

    return suspiciousKeywords.some((keyword) => software.includes(keyword));
  }

  private parseExifDate(raw: string | null): Date | null {
    if (!raw) return null;

    const normalized = raw.replace(/^\s+|\s+$/g, '').replace(/^"|"$/g, '');

    const normalizedIsoCandidate = normalized
      .replace(/^(\d{4}):(\d{2}):(\d{2})\s/, '$1-$2-$3T')
      .replace(/\s/g, '');

    const parsed = new Date(normalizedIsoCandidate);
    if (Number.isNaN(parsed.getTime())) {
      return null;
    }
    return parsed;
  }

  private searchExifAscii(
    exifBuffer: Buffer | undefined,
    candidates: string[],
  ): string | null {
    if (!exifBuffer || exifBuffer.length === 0) {
      return null;
    }

    const ascii = exifBuffer.toString('utf8');

    for (const candidate of candidates) {
      const regex = new RegExp(`${candidate}[^\\x00]{0,6}([^\\x00]{4,40})`, 'i');
      const match = ascii.match(regex);
      if (match?.[1]) {
        return match[1];
      }
    }

    return null;
  }
}
