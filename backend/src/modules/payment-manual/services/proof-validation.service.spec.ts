import sharp from 'sharp';
import { BadRequestException } from '@nestjs/common';
import { ProofValidationService } from './proof-validation.service';

describe('ProofValidationService', () => {
  const service = new ProofValidationService();

  async function buildImage(
    width: number,
    height: number,
    format: 'jpeg' | 'png' | 'webp' = 'jpeg',
  ) {
    return sharp({
      create: {
        width,
        height,
        channels: 3,
        background: { r: 120, g: 120, b: 120 },
      },
    })
      [format]()
      .toBuffer();
  }

  it('accepts valid image proof', async () => {
    const buffer = await buildImage(800, 900, 'jpeg');

    const result = await service.validateImage({
      buffer,
      mimetype: 'image/jpeg',
      size: buffer.length,
      originalname: 'proof.jpg',
    } as Express.Multer.File);

    expect(result.width).toBe(800);
    expect(result.height).toBe(900);
    expect(result.mimeType).toBe('image/jpeg');
  });

  it('accepts a valid image even when the client mime header is inconsistent', async () => {
    const buffer = await buildImage(800, 900, 'png');

    const result = await service.validateImage({
      buffer,
      mimetype: 'application/pdf',
      size: buffer.length,
      originalname: 'proof.pdf',
    } as Express.Multer.File);

    expect(result.format).toBe('png');
    expect(result.mimeType).toBe('image/png');
  });

  it('rejects images with insufficient resolution', async () => {
    const buffer = await buildImage(320, 320, 'png');

    await expect(
      service.validateImage({
        buffer,
        mimetype: 'image/png',
        size: buffer.length,
        originalname: 'proof.png',
      } as Express.Multer.File),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
