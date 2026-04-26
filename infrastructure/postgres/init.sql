-- ══════════════════════════════════════════════════════════════════════
-- Fiers Artisans — PostgreSQL Init Script
-- Extensions et configuration initiale
-- ══════════════════════════════════════════════════════════════════════

-- Activer PostGIS pour les requêtes géospatiales
CREATE EXTENSION IF NOT EXISTS postgis;

-- Activer uuid-ossp pour la génération d'UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Activer pg_trgm pour la recherche floue (autocomplete)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
