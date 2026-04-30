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
});
