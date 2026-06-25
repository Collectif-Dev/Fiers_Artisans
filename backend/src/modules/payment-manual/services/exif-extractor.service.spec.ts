import sharp from 'sharp';
import { ExifExtractorService } from './exif-extractor.service';

describe('ExifExtractorService', () => {
  const service = new ExifExtractorService();

  it('returns empty exif metadata when absent', async () => {
    const buffer = await sharp({
      create: {
        width: 900,
        height: 700,
        channels: 3,
        background: { r: 0, g: 0, b: 0 },
      },
    })
      .jpeg()
      .toBuffer();

    const exif = await service.extract(buffer);

    expect(exif.hasExif).toBe(false);
    expect(exif.device).toBeNull();
  });

  it('detects suspicious software marker', () => {
    const suspicious = service.detectSuspiciousSoftware({
      captureDate: null,
      modifiedDate: null,
      device: null,
      software: 'Adobe Photoshop 2025',
      hasExif: true,
    });

    expect(suspicious).toBe(true);
  });

  it('extracts software, dates and device from structured EXIF tags', async () => {
    const withExif = await sharp({
      create: {
        width: 900,
        height: 700,
        channels: 3,
        background: { r: 120, g: 90, b: 80 },
      },
    })
      .jpeg()
      .withExif({
        IFD0: {
          Make: 'Apple',
          Model: 'iPhone 14',
          Software: 'Adobe Photoshop 2025',
          DateTime: '2026:04:30 11:12:13',
        },
      })
      .toBuffer();

    const exif = await service.extract(withExif);

    expect(exif.hasExif).toBe(true);
    expect(exif.device).toContain('Apple');
    expect(exif.device).toContain('iPhone 14');
    expect(exif.software).toContain('Photoshop');
    expect(exif.captureDate === null || exif.captureDate instanceof Date).toBe(
      true,
    );
    expect(
      exif.modifiedDate === null || exif.modifiedDate instanceof Date,
    ).toBe(true);
    expect(service.detectSuspiciousSoftware(exif)).toBe(true);
  });
});
