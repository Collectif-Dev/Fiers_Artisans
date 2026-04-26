import { registerAs } from '@nestjs/config';

export default registerAs('database.postgres', () => ({
  type: 'postgres' as const,
  host: process.env.POSTGRES_HOST || 'localhost',
  port: parseInt(process.env.POSTGRES_PORT || '5432', 10),
  username: process.env.POSTGRES_USER || 'fiers_artisans',
  password: process.env.POSTGRES_PASSWORD || 'change_me_postgres',
  database: process.env.POSTGRES_DB || 'fiers_artisans',
  url: process.env.DATABASE_POSTGRES_URL,
  autoLoadEntities: true,
  synchronize: process.env.NODE_ENV !== 'production',
  logging: process.env.NODE_ENV === 'development',
}));
