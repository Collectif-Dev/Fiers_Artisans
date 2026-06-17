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

    const exifTags = this.parseExifTags(metadata.exif);

    const captureDate = this.parseExifDate(
      exifTags.DateTimeOriginal ||
        exifTags.CreateDate ||
        exifTags.DateTimeDigitized ||
        null,
    );
    const modifiedDate = this.parseExifDate(
      exifTags.ModifyDate || exifTags.DateTime || null,
    );

    const deviceParts = [
      exifTags.Make || metadataAny.make,
      exifTags.Model || metadataAny.model,
    ]
      .filter((v) => typeof v === 'string' && v.trim().length > 0)
      .map((v) => (v as string).trim());

    const software = exifTags.Software || metadataAny.software || null;

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

  private parseExifTags(exifBuffer?: Buffer): Record<string, string> {
    if (!exifBuffer || exifBuffer.length < 14) {
      return {};
    }

    const exifStart =
      exifBuffer.length >= 6 &&
      exifBuffer.subarray(0, 6).toString('ascii') === 'Exif\u0000\u0000'
        ? 6
        : 0;

    if (exifStart + 8 >= exifBuffer.length) {
      return {};
    }

    const endian = exifBuffer
      .subarray(exifStart, exifStart + 2)
      .toString('ascii');
    const littleEndian = endian === 'II';
    if (!littleEndian && endian !== 'MM') {
      return {};
    }

    const readU16 = (offset: number): number | null => {
      if (offset < 0 || offset + 2 > exifBuffer.length) return null;
      return littleEndian
        ? exifBuffer.readUInt16LE(offset)
        : exifBuffer.readUInt16BE(offset);
    };

    const readU32 = (offset: number): number | null => {
      if (offset < 0 || offset + 4 > exifBuffer.length) return null;
      return littleEndian
        ? exifBuffer.readUInt32LE(offset)
        : exifBuffer.readUInt32BE(offset);
    };

    const tiffMagic = readU16(exifStart + 2);
    if (tiffMagic !== 42) {
      return {};
    }

    const ifd0Relative = readU32(exifStart + 4);
    if (ifd0Relative === null) {
      return {};
    }

    const tagNames = new Map<number, string>([
      [0x010f, 'Make'],
      [0x0110, 'Model'],
      [0x0131, 'Software'],
      [0x0132, 'DateTime'],
      [0x9003, 'DateTimeOriginal'],
      [0x9004, 'DateTimeDigitized'],
      [0x013b, 'Artist'],
    ]);

    const values: Record<string, string> = {};
    const visitedIfdOffsets = new Set<number>();

    const readAsciiValue = (
      entryOffset: number,
      type: number,
      count: number,
    ): string | null => {
      if (type !== 2 || count <= 0) {
        return null;
      }

      const valueLength = count;
      let valueBytes: Buffer | null = null;
      if (valueLength <= 4) {
        if (entryOffset + 12 > exifBuffer.length) return null;
        valueBytes = exifBuffer.subarray(
          entryOffset + 8,
          entryOffset + 8 + valueLength,
        );
      } else {
        const rel = readU32(entryOffset + 8);
        if (rel === null) return null;
        const abs = exifStart + rel;
        if (abs < 0 || abs + valueLength > exifBuffer.length) return null;
        valueBytes = exifBuffer.subarray(abs, abs + valueLength);
      }

      const raw = valueBytes
        .toString('utf8')
        .replace(/\u0000/g, '')
        .trim();
      return raw.length > 0 ? raw : null;
    };

    const parseIfd = (ifdRelativeOffset: number): number | null => {
      if (ifdRelativeOffset <= 0 || visitedIfdOffsets.has(ifdRelativeOffset)) {
        return null;
      }
      visitedIfdOffsets.add(ifdRelativeOffset);

      const ifdAbsoluteOffset = exifStart + ifdRelativeOffset;
      const entryCount = readU16(ifdAbsoluteOffset);
      if (entryCount === null) {
        return null;
      }

      let exifSubIfdPointer: number | null = null;
      for (let i = 0; i < entryCount; i += 1) {
        const entryOffset = ifdAbsoluteOffset + 2 + i * 12;
        if (entryOffset + 12 > exifBuffer.length) {
          break;
        }

        const tag = readU16(entryOffset);
        const type = readU16(entryOffset + 2);
        const count = readU32(entryOffset + 4);
        if (tag === null || type === null || count === null) {
          continue;
        }

        if (tag === 0x8769) {
          exifSubIfdPointer = readU32(entryOffset + 8);
          continue;
        }

        const tagName = tagNames.get(tag);
        if (!tagName) {
          continue;
        }

        const asciiValue = readAsciiValue(entryOffset, type, count);
        if (asciiValue) {
          values[tagName] = asciiValue;
        }
      }

      if (exifSubIfdPointer && exifSubIfdPointer > 0) {
        parseIfd(exifSubIfdPointer);
      }

      const nextIfdPointerOffset = ifdAbsoluteOffset + 2 + entryCount * 12;
      return readU32(nextIfdPointerOffset);
    };

    const nextIfd = parseIfd(ifd0Relative);
    if (nextIfd && nextIfd > 0) {
      parseIfd(nextIfd);
    }

    return values;
  }
}
