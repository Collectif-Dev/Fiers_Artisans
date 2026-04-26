-- Migration: 20260413_add_review_reply_and_favorites
-- Purpose:
-- 1) Add artisan reply columns to reviews.
-- 2) Create favorite_artisans table with indexes, unique key, and foreign keys.
--
-- Apply:
--   psql "$DATABASE_URL" -f infrastructure/postgres/migrations/20260413_add_review_reply_and_favorites.sql
--
-- Rollback (manual, if needed):
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "BEGIN; DROP TABLE IF EXISTS favorite_artisans; ALTER TABLE reviews DROP COLUMN IF EXISTS artisan_reply_at; ALTER TABLE reviews DROP COLUMN IF EXISTS artisan_reply; COMMIT;"

BEGIN;

-- 1) Reviews: artisan one-time reply fields
ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS artisan_reply text;

ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS artisan_reply_at timestamp;

-- 2) Favorites table
CREATE TABLE IF NOT EXISTS favorite_artisans (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  client_profile_id uuid NOT NULL,
  artisan_profile_id uuid NOT NULL,
  created_at timestamp NOT NULL DEFAULT now(),
  CONSTRAINT "PK_favorite_artisans_id" PRIMARY KEY (id)
);

-- Unique pair (one favorite row per client/artisan pair)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'UQ_favorite_client_artisan'
  ) THEN
    ALTER TABLE favorite_artisans
      ADD CONSTRAINT "UQ_favorite_client_artisan"
      UNIQUE (client_profile_id, artisan_profile_id);
  END IF;
END $$;

-- FK -> client_profiles(id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'FK_favorite_artisans_client_profile'
  ) THEN
    ALTER TABLE favorite_artisans
      ADD CONSTRAINT "FK_favorite_artisans_client_profile"
      FOREIGN KEY (client_profile_id)
      REFERENCES client_profiles(id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- FK -> artisan_profiles(id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'FK_favorite_artisans_artisan_profile'
  ) THEN
    ALTER TABLE favorite_artisans
      ADD CONSTRAINT "FK_favorite_artisans_artisan_profile"
      FOREIGN KEY (artisan_profile_id)
      REFERENCES artisan_profiles(id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- Entity-aligned indexes
CREATE INDEX IF NOT EXISTS "IDX_favorite_client_profile"
  ON favorite_artisans (client_profile_id);

CREATE INDEX IF NOT EXISTS "IDX_favorite_artisan_profile"
  ON favorite_artisans (artisan_profile_id);

COMMIT;
