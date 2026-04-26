import { registerAs } from '@nestjs/config';

export default registerAs('minio', () => ({
  endpoint: process.env.MINIO_ENDPOINT || 'localhost',
  port: parseInt(process.env.MINIO_PORT || '9000', 10),
  useSSL: process.env.MINIO_USE_SSL === 'true',
  publicEndpoint:
    process.env.MINIO_PUBLIC_ENDPOINT || process.env.MINIO_ENDPOINT || 'localhost',
  publicPort: parseInt(
    process.env.MINIO_PUBLIC_PORT || process.env.MINIO_PORT || '9000',
    10,
  ),
  publicUseSSL:
    process.env.MINIO_PUBLIC_USE_SSL != null
      ? process.env.MINIO_PUBLIC_USE_SSL === 'true'
      : process.env.MINIO_USE_SSL === 'true',
  accessKey: process.env.MINIO_ACCESS_KEY || 'fiers_artisans_minio',
  secretKey: process.env.MINIO_SECRET_KEY || 'change_me_minio_secret',
  buckets: {
    portfolio: process.env.MINIO_BUCKET_PORTFOLIO || 'portfolio',
    documents: process.env.MINIO_BUCKET_DOCUMENTS || 'documents',
    media: process.env.MINIO_BUCKET_MEDIA || 'media',
  },
}));
