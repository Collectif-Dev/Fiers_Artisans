/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const BATCH_ID = 'abj20260628';
const TOTAL_ARTISANS = 200;
const CERTIFIED_COUNT = 50;
const VERIFIED_ONLY_COUNT = 22;
const PORTFOLIO_ARTISANS_COUNT = 90;

const firstNames = [
  'Adama',
  'Awa',
  'Koffi',
  'Kouadio',
  'Yao',
  'Mariam',
  'Fatou',
  'Serge',
  'Didier',
  'Brice',
  'Ange',
  'Kevin',
  'Prisca',
  'Clarisse',
  'Grace',
  'Ibrahim',
  'Moustapha',
  'Daouda',
  'Fanta',
  'Kader',
  'Ismael',
  'Armand',
  'Jean',
  'Eric',
  'Roland',
  'Junior',
  'Seynabou',
  'Aminata',
  'Kouame',
  'Nadia',
  'Habib',
  'Ruth',
  'Abdoulaye',
  'Franck',
  'Cedric',
  'Noel',
  'Djeneba',
  'Aya',
  'Moussa',
  'Nene',
];

const lastNames = [
  'Kone',
  'Coulibaly',
  'Traore',
  'Kouassi',
  'NGuessan',
  'Konan',
  'Bamba',
  'Soro',
  'Toure',
  'Amani',
  'Fofana',
  'Kacou',
  'Diomande',
  'Tano',
  'Zahui',
  'Dibi',
  'Ble',
  'Aka',
  'Kanga',
  'Assi',
  'Affi',
  'Yapo',
  'NZi',
  'Kouakou',
  'Tiacoh',
  'Bakayoko',
  'Gouamene',
  'Yede',
  'Ahoua',
  'Dago',
  'Gnagne',
  'Koulibaly',
  'NDry',
  'NDa',
  'Asseu',
  'NCho',
  'KouassiYao',
  'KoffiKouame',
  'Achi',
  'Mobio',
];

const communeAnchors = [
  { commune: 'Cocody', latitude: 5.359951, longitude: -3.986951 },
  { commune: 'Plateau', latitude: 5.323746, longitude: -4.026916 },
  { commune: 'Yopougon', latitude: 5.33612, longitude: -4.08642 },
  { commune: 'Marcory', latitude: 5.28934, longitude: -3.9819 },
  { commune: 'Treichville', latitude: 5.29352, longitude: -4.00851 },
  { commune: 'Adjame', latitude: 5.35111, longitude: -4.02166 },
  { commune: 'Abobo', latitude: 5.42398, longitude: -4.01661 },
  { commune: 'Koumassi', latitude: 5.30255, longitude: -3.94474 },
  { commune: 'Port-Bouet', latitude: 5.25591, longitude: -3.93514 },
  { commune: 'Attecoube', latitude: 5.33673, longitude: -4.04776 },
  { commune: 'Bingerville', latitude: 5.35581, longitude: -3.88566 },
  { commune: 'Anyama', latitude: 5.49508, longitude: -4.05257 },
  { commune: 'Songon', latitude: 5.30415, longitude: -4.23558 },
  { commune: 'Riviera', latitude: 5.36947, longitude: -3.96334 },
  { commune: 'Angre', latitude: 5.41392, longitude: -3.96495 },
  { commune: 'Koumassi Remblais', latitude: 5.28497, longitude: -3.95715 },
];

const serviceTags = [
  'depanage',
  'renovation',
  'installation',
  'maintenance',
  'urgence',
  'qualite',
  'abidjan',
  'fiers-artisans',
];

function slugify(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function buildDbConfigs() {
  const pgConfig = {
    host: process.env.POSTGRES_HOST || 'localhost',
    port: Number(process.env.POSTGRES_PORT || 5432),
    user: process.env.POSTGRES_USER || 'fiers_artisans',
    password: process.env.POSTGRES_PASSWORD || '',
    database: process.env.POSTGRES_DB || 'fiers_artisans',
  };

  const mongoUri =
    process.env.DATABASE_MONGO_URL ||
    `mongodb://${encodeURIComponent(process.env.MONGO_USER || 'fiers_artisans')}:${encodeURIComponent(process.env.MONGO_PASSWORD || '')}@${process.env.MONGO_HOST || 'localhost'}:${process.env.MONGO_PORT || '27017'}/${process.env.MONGO_DB || 'fiers_artisans'}?authSource=admin`;

  return { pgConfig, mongoUri };
}

function pickVerificationStatus(index) {
  if (index <= CERTIFIED_COUNT) return 'CERTIFIED';
  if (index <= CERTIFIED_COUNT + VERIFIED_ONLY_COUNT) return 'VERIFIED';
  return 'PENDING';
}

function generatePhone(index) {
  const raw = 91000000 + index;
  return `07${String(raw).padStart(8, '0')}`;
}

function createSyntheticArtisans(subcategoryRows) {
  const results = [];

  for (let i = 1; i <= TOTAL_ARTISANS; i += 1) {
    const firstName = firstNames[(i - 1) % firstNames.length];
    const lastName = lastNames[Math.floor((i - 1) / 2) % lastNames.length];
    const phone = generatePhone(i);
    const email = `${BATCH_ID}.${slugify(firstName)}.${slugify(lastName)}.${String(i).padStart(3, '0')}@seed-fiers.ci`;
    const subcategory = subcategoryRows[(i - 1) % subcategoryRows.length];
    const anchor = communeAnchors[(i - 1) % communeAnchors.length];
    const latJitter = ((((i * 37) % 9) - 4) * 0.0009).toFixed(6);
    const lngJitter = ((((i * 53) % 9) - 4) * 0.001).toFixed(6);
    const latitude = Number((anchor.latitude + Number(latJitter)).toFixed(6));
    const longitude = Number((anchor.longitude + Number(lngJitter)).toFixed(6));
    const verificationStatus = pickVerificationStatus(i);
    const reviews = 10 + ((i * 13) % 180);
    const rating = Number((3.2 + ((i * 7) % 18) * 0.1).toFixed(1));
    const experienceYears = 1 + (i % 18);
    const portfolioCount = i <= PORTFOLIO_ARTISANS_COUNT ? 2 + (i % 3) : 0;
    const geoWkt = `SRID=4326;POINT(${longitude} ${latitude})`;
    const businessName = `${subcategory.subcategory_name} ${lastName} Services`;
    const description = `Artisan ivoirien specialise en ${subcategory.subcategory_name} a ${anchor.commune}, intervention sur le Grand Abidjan. Lot ${BATCH_ID}.`;

    results.push({
      index: i,
      firstName,
      lastName,
      phone,
      email,
      verificationStatus,
      categoryId: subcategory.category_id,
      categoryName: subcategory.category_name,
      subcategoryId: subcategory.subcategory_id,
      subcategoryName: subcategory.subcategory_name,
      city: 'Abidjan',
      commune: anchor.commune,
      latitude,
      longitude,
      geoWkt,
      businessName,
      description,
      experienceYears,
      reviews,
      rating,
      portfolioCount,
    });
  }

  return results;
}

function buildWorkingHours() {
  return {
    mon: { open: '08:00', close: '18:00' },
    tue: { open: '08:00', close: '18:00' },
    wed: { open: '08:00', close: '18:00' },
    thu: { open: '08:00', close: '18:00' },
    fri: { open: '08:00', close: '18:00' },
    sat: { open: '09:00', close: '15:00' },
  };
}

async function seedPostgres(client) {
  const subcategoryResult = await client.query(
    `
      SELECT
        sc.id AS subcategory_id,
        sc.name AS subcategory_name,
        c.id AS category_id,
        c.name AS category_name
      FROM subcategories sc
      INNER JOIN categories c ON c.id = sc.category_id
      WHERE c.is_active = true
      ORDER BY c.display_order ASC, c.name ASC, sc.name ASC
    `,
  );

  if (subcategoryResult.rowCount < 1) {
    throw new Error('Aucune sous-categorie active trouvee.');
  }

  const syntheticArtisans = createSyntheticArtisans(subcategoryResult.rows);
  const phones = syntheticArtisans.map((item) => item.phone);

  const duplicatePhoneCheck = await client.query(
    'SELECT phone_number FROM users WHERE phone_number = ANY($1::text[]) LIMIT 1',
    [phones],
  );

  if (duplicatePhoneCheck.rowCount > 0) {
    throw new Error(
      `Le lot ${BATCH_ID} semble deja present (phone detecte: ${duplicatePhoneCheck.rows[0].phone_number}).`,
    );
  }

  const duplicateEmailCheck = await client.query(
    "SELECT email FROM users WHERE email LIKE $1 LIMIT 1",
    [`${BATCH_ID}.%@seed-fiers.ci`],
  );

  if (duplicateEmailCheck.rowCount > 0) {
    throw new Error(
      `Le lot ${BATCH_ID} semble deja present (email detecte: ${duplicateEmailCheck.rows[0].email}).`,
    );
  }

  const workingHoursJson = JSON.stringify(buildWorkingHours());
  const createdRows = [];

  await client.query('BEGIN');
  try {
    for (const artisan of syntheticArtisans) {
      const userInsert = await client.query(
        `
          INSERT INTO users (
            phone_number,
            email,
            password_hash,
            pin_hash,
            role,
            verification_status,
            is_active,
            is_phone_verified,
            whatsapp_number,
            country_code,
            location,
            location_updated_at,
            created_at,
            updated_at
          )
          VALUES (
            $1,
            $2,
            NULL,
            NULL,
            'ARTISAN',
            $3,
            true,
            true,
            $4,
            'CI',
            ST_GeogFromText($5),
            NOW(),
            NOW(),
            NOW()
          )
          RETURNING id
        `,
        [
          artisan.phone,
          artisan.email,
          artisan.verificationStatus,
          artisan.phone,
          artisan.geoWkt,
        ],
      );

      const userId = userInsert.rows[0].id;

      const profileInsert = await client.query(
        `
          INSERT INTO artisan_profiles (
            user_id,
            first_name,
            last_name,
            business_name,
            bio,
            category_id,
            subcategory_id,
            city,
            commune,
            address,
            rating_avg,
            total_reviews,
            years_experience,
            is_available,
            is_subscription_active,
            whatsapp_number,
            working_hours,
            last_active_at,
            created_at,
            updated_at
          )
          VALUES (
            $1,
            $2,
            $3,
            $4,
            $5,
            $6,
            $7,
            $8,
            $9,
            $10,
            $11,
            $12,
            $13,
            true,
            true,
            $14,
            $15::jsonb,
            NOW() - (($16 % 12) || ' hours')::interval,
            NOW(),
            NOW()
          )
          RETURNING id
        `,
        [
          userId,
          artisan.firstName,
          artisan.lastName,
          artisan.businessName,
          artisan.description,
          artisan.categoryId,
          artisan.subcategoryId,
          artisan.city,
          artisan.commune,
          `${artisan.commune}, Abidjan`,
          artisan.rating,
          artisan.reviews,
          artisan.experienceYears,
          artisan.phone,
          workingHoursJson,
          artisan.index,
        ],
      );

      const artisanProfileId = profileInsert.rows[0].id;

      const subscriptionInsert = await client.query(
        `
          INSERT INTO subscriptions (
            artisan_profile_id,
            plan,
            amount_fcfa,
            status,
            starts_at,
            expires_at,
            auto_renew,
            created_at
          )
          VALUES (
            $1,
            'MONTHLY',
            5000,
            'ACTIVE',
            NOW() - (($2 % 18 + 1) || ' days')::interval,
            NOW() + (($3 % 25 + 35) || ' days')::interval,
            $4,
            NOW()
          )
          RETURNING id
        `,
        [artisanProfileId, artisan.index, artisan.index, artisan.index % 3 === 0],
      );

      createdRows.push({
        ...artisan,
        userId,
        artisanProfileId,
        subscriptionId: subscriptionInsert.rows[0].id,
      });
    }

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }

  return createdRows;
}

async function seedMongoPortfolios(mongoUri, createdRows) {
  const portfolioCandidates = createdRows.filter(
    (item) => item.portfolioCount > 0,
  );

  if (portfolioCandidates.length === 0) {
    return { portfolioDocs: 0, artisanWithPortfolio: 0 };
  }

  await mongoose.connect(mongoUri, {
    serverSelectionTimeoutMS: 10000,
  });

  try {
    const collection = mongoose.connection.db.collection('portfolio_items');
    const now = new Date();
    const docs = [];

    for (const artisan of portfolioCandidates) {
      for (let itemIndex = 1; itemIndex <= artisan.portfolioCount; itemIndex += 1) {
        const objectKey = `${BATCH_ID}/${artisan.artisanProfileId}/item-${itemIndex}.jpg`;
        docs.push({
          artisanProfileId: artisan.artisanProfileId,
          title: `${artisan.subcategoryName} - Projet ${itemIndex}`,
          description: `Realisation ${itemIndex} en ${artisan.subcategoryName} a ${artisan.commune} (Grand Abidjan).`,
          priceFcfa: 25000 + ((artisan.index * 7000 + itemIndex * 3000) % 225000),
          imageUrls: [
            `http://localhost:3000/api/v1/media/public/portfolio/${encodeURIComponent(objectKey)}`,
          ],
          imageObjects: [
            {
              bucket: 'portfolio',
              objectKey,
            },
          ],
          tags: [
            artisan.subcategoryName,
            artisan.categoryName,
            artisan.commune,
            serviceTags[(artisan.index + itemIndex) % serviceTags.length],
          ],
          metadata: {
            seedBatch: BATCH_ID,
            generated: true,
            latitude: artisan.latitude,
            longitude: artisan.longitude,
          },
          createdAt: now,
          updatedAt: now,
        });
      }
    }

    await collection.insertMany(docs, { ordered: false });

    return {
      portfolioDocs: docs.length,
      artisanWithPortfolio: portfolioCandidates.length,
    };
  } finally {
    await mongoose.disconnect();
  }
}

function writeRegistryFiles(createdRows) {
  const outputDir = path.resolve(
    __dirname,
    '../../infrastructure/backups/seeds',
  );
  fs.mkdirSync(outputDir, { recursive: true });

  const jsonPath = path.join(
    outputDir,
    `registry_${BATCH_ID}_artisans.json`,
  );
  const csvPath = path.join(outputDir, `registry_${BATCH_ID}_artisans.csv`);

  const registryRows = createdRows.map((row) => ({
    batch_id: BATCH_ID,
    index: row.index,
    user_id: row.userId,
    artisan_profile_id: row.artisanProfileId,
    subscription_id: row.subscriptionId,
    phone: row.phone,
    email: row.email,
    first_name: row.firstName,
    last_name: row.lastName,
    verification_status: row.verificationStatus,
    category_name: row.categoryName,
    subcategory_name: row.subcategoryName,
    city: row.city,
    commune: row.commune,
    latitude: row.latitude,
    longitude: row.longitude,
    portfolio_items: row.portfolioCount,
  }));

  fs.writeFileSync(jsonPath, JSON.stringify(registryRows, null, 2), 'utf8');

  const header = Object.keys(registryRows[0]);
  const csvLines = [header.join(',')];
  for (const row of registryRows) {
    const line = header
      .map((key) => {
        const value = row[key] ?? '';
        const raw = String(value).replace(/"/g, '""');
        return `"${raw}"`;
      })
      .join(',');
    csvLines.push(line);
  }
  fs.writeFileSync(csvPath, `${csvLines.join('\n')}\n`, 'utf8');

  return { jsonPath, csvPath };
}

async function main() {
  const { pgConfig, mongoUri } = buildDbConfigs();
  const pgClient = new Client(pgConfig);

  await pgClient.connect();
  let createdRows = [];

  try {
    createdRows = await seedPostgres(pgClient);
  } finally {
    await pgClient.end();
  }

  const portfolioSummary = await seedMongoPortfolios(mongoUri, createdRows);
  const files = writeRegistryFiles(createdRows);

  const statusCounts = createdRows.reduce(
    (acc, row) => {
      acc[row.verificationStatus] = (acc[row.verificationStatus] || 0) + 1;
      return acc;
    },
    { CERTIFIED: 0, VERIFIED: 0, PENDING: 0 },
  );

  console.log('Seed termine avec succes.');
  console.log(`Batch: ${BATCH_ID}`);
  console.log(`Total artisans crees: ${createdRows.length}`);
  console.log(`CERTIFIED: ${statusCounts.CERTIFIED}`);
  console.log(`VERIFIED: ${statusCounts.VERIFIED}`);
  console.log(`PENDING: ${statusCounts.PENDING}`);
  console.log(
    `Artisans avec portfolio: ${portfolioSummary.artisanWithPortfolio} | Items portfolio: ${portfolioSummary.portfolioDocs}`,
  );
  console.log(`Registre JSON: ${files.jsonPath}`);
  console.log(`Registre CSV: ${files.csvPath}`);
}

main().catch((error) => {
  console.error('Echec seed artisans Abidjan:', error.message);
  process.exitCode = 1;
});
