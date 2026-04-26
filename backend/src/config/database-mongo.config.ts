import { registerAs } from '@nestjs/config';

export default registerAs('database.mongo', () => ({
  uri:
    process.env.DATABASE_MONGO_URL ||
    `mongodb://${process.env.MONGO_USER || 'fiers_artisans'}:${process.env.MONGO_PASSWORD || 'change_me_mongo'}@${process.env.MONGO_HOST || 'localhost'}:${process.env.MONGO_PORT || '27017'}/${process.env.MONGO_DB || 'fiers_artisans'}?authSource=admin`,
}));
