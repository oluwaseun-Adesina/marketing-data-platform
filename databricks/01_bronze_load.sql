-- =============================================================================
-- 01 · Bronze load: landing volume -> raw Delta tables (mkt_raw)
-- Run as admin (or a dedicated ingestion principal). Re-runnable.
-- =============================================================================
--
-- Decisions
-- * Every business column is STRING. Bronze is a faithful copy of the source
--   ("null" strings, odd precision and all). Typing and cleaning are business
--   logic, so they live in dbt staging where they are versioned, tested and
--   documented, not hidden in an ingestion script.
-- * Two audit columns are added:
--     _source_file  : which file the row came from (lineage / debugging)
--     _ingested_at  : when it was loaded. dbt uses this as
--                     (a) the "latest version wins" tie-breaker when a platform
--                         re-sends (restates) a row, and
--                     (b) the watermark for the incremental fact table.
-- * COPY INTO is idempotent: files already loaded are skipped. Dropping a new
--   daily export into the folder and re-running this script loads only that file.
--   CREATE TABLE AS SELECT would reload everything and duplicate rows.
-- * Source file names are messy (new_acccount_de_randomized.csv). Bronze table
--   names are clean and stable; the mapping lives in upload_raw_files.sh.
-- =============================================================================

-- ---------------------------------------------------------------- Facebook --
CREATE TABLE IF NOT EXISTS mkt_raw.facebook_ads.ads_stats (
  ad_id STRING, account_id STRING, ad_spend STRING, ad_impressions STRING,
  ad_clicks STRING, ad_date STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Facebook daily ad performance. One row per ad per day as exported.';

COPY INTO mkt_raw.facebook_ads.ads_stats
FROM (
  SELECT ad_id, account_id, ad_spend, ad_impressions, ad_clicks, ad_date,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/facebook/ads_stats/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

CREATE TABLE IF NOT EXISTS mkt_raw.facebook_ads.ads (
  ad_id STRING, campaign_id STRING, ad_group_id STRING, account_id STRING,
  ad_name STRING, ad_status STRING, ad_updated_at STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Facebook ads (creative level) with parent ad set, campaign and account ids.';

COPY INTO mkt_raw.facebook_ads.ads
FROM (
  SELECT ad_id, campaign_id, ad_group_id, account_id, ad_name, ad_status, ad_updated_at,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/facebook/ads/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

CREATE TABLE IF NOT EXISTS mkt_raw.facebook_ads.ad_groups (
  ad_group_id STRING, ad_group_name STRING, ad_group_updated_at STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Facebook ad sets (called ad groups here).';

COPY INTO mkt_raw.facebook_ads.ad_groups
FROM (
  SELECT ad_group_id, ad_group_name, ad_group_updated_at,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/facebook/ad_groups/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

CREATE TABLE IF NOT EXISTS mkt_raw.facebook_ads.campaigns (
  campaign_id STRING, campaign_name STRING, campaign_updated_at STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Facebook campaigns. Note: no account_id in this export.';

COPY INTO mkt_raw.facebook_ads.campaigns
FROM (
  SELECT campaign_id, campaign_name, campaign_updated_at,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/facebook/campaigns/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

CREATE TABLE IF NOT EXISTS mkt_raw.facebook_ads.accounts (
  account_id STRING, account_name STRING, ad_currency_code STRING,
  account_created_at STRING, account_updated_at STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Facebook ad accounts, including the account billing currency.';

COPY INTO mkt_raw.facebook_ads.accounts
FROM (
  SELECT account_id, account_name, ad_currency_code, account_created_at, account_updated_at,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/facebook/accounts/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

-- ---------------------------------------------------------------- Snapchat --
CREATE TABLE IF NOT EXISTS mkt_raw.snapchat_ads.ad_stats (
  ad_detail_id STRING, ad_currency_code STRING, ad_country STRING, ad_spend STRING,
  ad_impressions STRING, ad_clicks STRING, ad_date STRING, data_src STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Snapchat daily ad performance. One row per ad per day PER COUNTRY.';

COPY INTO mkt_raw.snapchat_ads.ad_stats
FROM (
  SELECT ad_detail_id, ad_currency_code, ad_country, ad_spend, ad_impressions,
         ad_clicks, ad_date, data_src,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/snapchat/ad_stats/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

CREATE TABLE IF NOT EXISTS mkt_raw.snapchat_ads.ads (
  ad_id STRING, ad_group_id STRING, ad_name STRING, ad_detail_updated_at STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Snapchat ads (history export).';

COPY INTO mkt_raw.snapchat_ads.ads
FROM (
  SELECT ad_id, ad_group_id, ad_name, ad_detail_updated_at,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/snapchat/ads/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

CREATE TABLE IF NOT EXISTS mkt_raw.snapchat_ads.ad_groups (
  _surrogate_key STRING, ad_group_id STRING, campaign_id STRING,
  ad_group_name STRING, ad_group_updated_at STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Snapchat ad squads / ad groups (history export, can hold several versions per id).';

COPY INTO mkt_raw.snapchat_ads.ad_groups
FROM (
  SELECT _surrogate_key, ad_group_id, campaign_id, ad_group_name, ad_group_updated_at,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/snapchat/ad_groups/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

CREATE TABLE IF NOT EXISTS mkt_raw.snapchat_ads.campaigns (
  campaign_id STRING, account_id STRING, campaign_name STRING,
  _source_file STRING, _ingested_at TIMESTAMP
) COMMENT 'Raw Snapchat campaigns (history export).';

COPY INTO mkt_raw.snapchat_ads.campaigns
FROM (
  SELECT campaign_id, account_id, campaign_name,
         _metadata.file_path AS _source_file, current_timestamp() AS _ingested_at
  FROM '/Volumes/mkt_raw/landing/files/snapchat/campaigns/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false');

-- Sanity check: expected row counts for the provided sample
-- facebook: ads_stats 92,300 | ads 98,926 | ad_groups 13,433 | campaigns 4,162 | accounts 16
-- snapchat: ad_stats 2,809   | ads 2,513  | ad_groups 267    | campaigns 109
SELECT 'facebook.ads_stats' t, count(*) n FROM mkt_raw.facebook_ads.ads_stats UNION ALL
SELECT 'facebook.ads',        count(*)   FROM mkt_raw.facebook_ads.ads       UNION ALL
SELECT 'facebook.ad_groups',  count(*)   FROM mkt_raw.facebook_ads.ad_groups UNION ALL
SELECT 'facebook.campaigns',  count(*)   FROM mkt_raw.facebook_ads.campaigns UNION ALL
SELECT 'facebook.accounts',   count(*)   FROM mkt_raw.facebook_ads.accounts  UNION ALL
SELECT 'snapchat.ad_stats',   count(*)   FROM mkt_raw.snapchat_ads.ad_stats  UNION ALL
SELECT 'snapchat.ads',        count(*)   FROM mkt_raw.snapchat_ads.ads       UNION ALL
SELECT 'snapchat.ad_groups',  count(*)   FROM mkt_raw.snapchat_ads.ad_groups UNION ALL
SELECT 'snapchat.campaigns',  count(*)   FROM mkt_raw.snapchat_ads.campaigns;
