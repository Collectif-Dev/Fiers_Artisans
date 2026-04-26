-- Migration: 20260415_add_artisan_subcategory
-- Purpose:
-- Add optional subcategory relation on artisan_profiles for precise metier filtering.
--
-- Apply:
--   psql "$DATABASE_URL" -f infrastructure/postgres/migrations/20260415_add_artisan_subcategory.sql

BEGIN;

ALTER TABLE artisan_profiles
  ADD COLUMN IF NOT EXISTS subcategory_id uuid;

CREATE INDEX IF NOT EXISTS "IDX_artisan_profiles_subcategory_id"
  ON artisan_profiles (subcategory_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'FK_artisan_profiles_subcategory'
  ) THEN
    ALTER TABLE artisan_profiles
      ADD CONSTRAINT "FK_artisan_profiles_subcategory"
      FOREIGN KEY (subcategory_id)
      REFERENCES subcategories(id)
      ON DELETE SET NULL;
  END IF;
END $$;

COMMIT;
