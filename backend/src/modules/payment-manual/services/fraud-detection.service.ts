import { Injectable } from '@nestjs/common';
import { ExifData } from './exif-extractor.service';

@Injectable()
export class FraudDetectionService {
  scoreImage(_hash: string, _exif: ExifData, _metadata: Record<string, unknown>): number {
    // Phase 1: stub kept intentionally deterministic.
    return 0.0;
  }
}
