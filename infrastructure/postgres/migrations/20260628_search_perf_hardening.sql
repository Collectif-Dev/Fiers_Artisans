-- Migration: 20260628_search_perf_hardening
-- Purpose:
-- Improve search performance for geospatial filtering + text/category lookup
-- while keeping deployment controlled and repeatable.
--
-- Apply:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f infrastructure/postgres/migrations/20260628_search_perf_hardening.sql

BEGIN;

-- Needed for fast ILIKE queries using GIN trigram indexes.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Geospatial acceleration for ST_DWithin/ST_Distance.
CREATE INDEX IF NOT EXISTS idx_users_location_gist
  ON users USING GIST (location);

-- Active search scope filtering.
CREATE INDEX IF NOT EXISTS idx_artisan_profiles_active_scope
  ON artisan_profiles (is_subscription_active, is_available, category_id, subcategory_id, rating_avg DESC);

-- Trigram indexes for name/business text matching.
CREATE INDEX IF NOT EXISTS idx_artisan_profiles_first_name_trgm
  ON artisan_profiles USING GIN (first_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_artisan_profiles_last_name_trgm
  ON artisan_profiles USING GIN (last_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_artisan_profiles_business_name_trgm
  ON artisan_profiles USING GIN (business_name gin_trgm_ops);

-- Trigram indexes for category and subcategory matching.
CREATE INDEX IF NOT EXISTS idx_categories_name_trgm
  ON categories USING GIN (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_categories_slug_trgm
  ON categories USING GIN (slug gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_subcategories_name_trgm
  ON subcategories USING GIN (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_subcategories_slug_trgm
  ON subcategories USING GIN (slug gin_trgm_ops);

COMMIT;
