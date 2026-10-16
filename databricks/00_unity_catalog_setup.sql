-- =============================================================================
-- 00 · Unity Catalog layout
-- Run once as a workspace/metastore admin (your own user), in a SQL editor.
-- =============================================================================
--
-- Design: one catalog for raw data, one catalog per dbt environment.
--
--   mkt_raw    bronze. Raw files + raw tables, all STRING. Written only by the
--              ingestion step, READ-ONLY for every dbt identity.
--   mkt_dev    developers' personal schemas (dbt_<name>_staging, ...)
--   mkt_ci     ephemeral per-pull-request schemas (pr_<n>_staging, ...)
--   mkt_prod   production models: staging / intermediate / marts / elementary
--
-- Why catalog-per-environment instead of schema-per-environment:
--   * Grants are set at catalog level, so "CI can never write to prod" is one
--     missing grant rather than a naming convention someone can get wrong.
--   * The same dbt code produces the same schema names in every environment;
--     only `catalog` in the dbt target changes.
--
-- Why raw lives in its own catalog:
--   * Raw data is loaded once and shared by every environment. dev/CI/prod all
--     read the same bronze tables, so tests in CI run against real data.
--   * Nobody running dbt can modify or drop the source of truth.
-- =============================================================================

CREATE CATALOG IF NOT EXISTS mkt_raw  COMMENT 'Bronze: raw advertising data exactly as received from the platforms';
CREATE CATALOG IF NOT EXISTS mkt_dev  COMMENT 'dbt development environment (personal schemas)';
CREATE CATALOG IF NOT EXISTS mkt_ci   COMMENT 'dbt CI environment (one schema set per pull request, dropped on close)';
CREATE CATALOG IF NOT EXISTS mkt_prod COMMENT 'dbt production environment: governed marketing data product';

-- Raw landing zone for the provided CSV files
CREATE SCHEMA IF NOT EXISTS mkt_raw.landing      COMMENT 'Landing volume for raw files';
CREATE VOLUME IF NOT EXISTS mkt_raw.landing.files COMMENT 'Raw CSV exports, one folder per source table';

-- Raw (bronze) tables, one schema per source system
CREATE SCHEMA IF NOT EXISTS mkt_raw.facebook_ads COMMENT 'Raw Facebook (Meta) Ads exports';
CREATE SCHEMA IF NOT EXISTS mkt_raw.snapchat_ads COMMENT 'Raw Snapchat Ads exports';

-- Production schemas are pre-created by the admin, NOT by dbt.
-- The production service principal therefore needs no CREATE SCHEMA privilege
-- and cannot create arbitrary schemas in prod (see 02_grants.sql).
CREATE SCHEMA IF NOT EXISTS mkt_prod.staging      COMMENT 'Cleaned, typed, renamed source data (dbt views)';
CREATE SCHEMA IF NOT EXISTS mkt_prod.intermediate COMMENT 'Reusable transformation logic (dbt)';
CREATE SCHEMA IF NOT EXISTS mkt_prod.marts        COMMENT 'Consumption layer: facts, dimensions and marts for analysts, BI and AI agents';
CREATE SCHEMA IF NOT EXISTS mkt_prod.elementary   COMMENT 'Elementary observability: test results, run history, anomalies';
