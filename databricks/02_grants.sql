-- =============================================================================
-- 02 · Unity Catalog permissions (least privilege)
-- Run as admin AFTER 00 and 01. Replace the placeholders first:
--
--   <PROD_SP_APP_ID>   application ID (UUID) of service principal "sp-dbt-prod"
--   <CI_SP_APP_ID>     application ID (UUID) of service principal "sp-dbt-ci"
--   <YOUR_EMAIL>       your Databricks login (developer)
--   marketing_analysts account-level group for analysts / BI / AI-agent identities
--
-- Outside SQL, also give BOTH service principals:
--   * "Databricks SQL access" entitlement (Workspace settings > Identity and access)
--   * CAN USE on the SQL warehouse dbt connects to (Warehouse > Permissions)
-- =============================================================================
--
-- Principals and what each one may do
--
--   principal            mkt_raw        mkt_dev          mkt_ci            mkt_prod
--   -------------------  -------------  ---------------  ----------------  ---------------------------
--   sp-dbt-prod          read           -                -                 write to 5 pre-made schemas
--   sp-dbt-ci            read           -                create own schemas read (for --defer)
--   developer (you)      read           create own schemas -               read marts
--   marketing_analysts   -              -                -                 read marts ONLY
--
-- What changed from the course example, and why
--   * CREATE CATALOG ON METASTORE was dropped. A pipeline identity that can
--     create catalogs can create a whole parallel environment outside
--     governance. Catalogs are infrastructure, so an admin creates them.
--   * Prod SP has no CREATE SCHEMA. Admin pre-creates the five prod schemas
--     (00_unity_catalog_setup.sql). The SP can write into them, nothing else.
--   * Grants are schema-scoped, not catalog-wide (the example's
--     "USE SCHEMA ON CATALOG" grants every current AND future schema).
--   * Analysts see marts only. Staging and intermediate are implementation
--     details. Exposing them invites reports built on unstable, un-deduplicated
--     data, and gives an AI agent tables it must not use.
--   * Grants are on SCHEMAS, not tables. dbt drops and recreates tables and
--     views. Schema-level grants are inherited by every new object, so access
--     never silently disappears after a run.
-- =============================================================================

-- ----------------------------------------------------- 1. Production SP ------
GRANT USE CATALOG ON CATALOG mkt_raw TO `de0de794-c5f4-44fc-85f9-633bd09cf739`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_raw.facebook_ads TO `de0de794-c5f4-44fc-85f9-633bd09cf739`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_raw.snapchat_ads TO `de0de794-c5f4-44fc-85f9-633bd09cf739`;

GRANT USE CATALOG ON CATALOG mkt_prod TO `de0de794-c5f4-44fc-85f9-633bd09cf739`;
GRANT USE SCHEMA, CREATE TABLE, SELECT, MODIFY ON SCHEMA mkt_prod.staging      TO `de0de794-c5f4-44fc-85f9-633bd09cf739`;
GRANT USE SCHEMA, CREATE TABLE, SELECT, MODIFY ON SCHEMA mkt_prod.intermediate TO `de0de794-c5f4-44fc-85f9-633bd09cf739`;
GRANT USE SCHEMA, CREATE TABLE, SELECT, MODIFY ON SCHEMA mkt_prod.marts        TO `de0de794-c5f4-44fc-85f9-633bd09cf739`;
GRANT USE SCHEMA, CREATE TABLE, SELECT, MODIFY ON SCHEMA mkt_prod.elementary   TO `de0de794-c5f4-44fc-85f9-633bd09cf739`;

-- ----------------------------------------------------- 2. CI SP --------------
-- Separate identity from prod. A leaked CI secret cannot touch production data.
GRANT USE CATALOG ON CATALOG mkt_raw TO `d4869b2e-ebfa-4075-a9cb-4da934152503`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_raw.facebook_ads TO `d4869b2e-ebfa-4075-a9cb-4da934152503`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_raw.snapchat_ads TO `d4869b2e-ebfa-4075-a9cb-4da934152503`;

-- CI creates pr_<n>_* schemas per pull request. It owns what it creates, so it
-- can also drop them when the PR closes.
GRANT USE CATALOG, CREATE SCHEMA ON CATALOG mkt_ci TO `d4869b2e-ebfa-4075-a9cb-4da934152503`;

-- Read-only on prod so slim CI can --defer unchanged upstream models to prod
-- instead of rebuilding the whole DAG on every pull request.
GRANT USE CATALOG ON CATALOG mkt_prod TO `d4869b2e-ebfa-4075-a9cb-4da934152503`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_prod.staging      TO `d4869b2e-ebfa-4075-a9cb-4da934152503`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_prod.intermediate TO `d4869b2e-ebfa-4075-a9cb-4da934152503`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_prod.marts        TO `d4869b2e-ebfa-4075-a9cb-4da934152503`;

-- ----------------------------------------------------- 3. Developer ----------
GRANT USE CATALOG ON CATALOG mkt_raw TO `oluwaseunadesina8@gmail.com`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_raw.facebook_ads TO `oluwaseunadesina8@gmail.com`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_raw.snapchat_ads TO `oluwaseunadesina8@gmail.com`;

GRANT USE CATALOG, CREATE SCHEMA ON CATALOG mkt_dev TO `oluwaseunadesina8@gmail.com`;

GRANT USE CATALOG ON CATALOG mkt_prod TO `oluwaseunadesina8@gmail.com`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_prod.marts      TO `oluwaseunadesina8@gmail.com`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_prod.elementary TO `oluwaseunadesina8@gmail.com`;  -- observability

-- ----------------------------------------------------- 4. Consumers ----------
-- Analysts, BI service accounts and AI-agent identities (e.g. a Genie space or
-- an MCP server's service principal) are all members of this one group.
GRANT USE CATALOG ON CATALOG mkt_prod TO `marketing_analysts`;
GRANT USE SCHEMA, SELECT ON SCHEMA mkt_prod.marts TO `marketing_analysts`;

-- ----------------------------------------------------- Verify ----------------
SHOW GRANTS ON CATALOG mkt_prod;
SHOW GRANTS ON SCHEMA  mkt_prod.marts;
SHOW GRANTS `de0de794-c5f4-44fc-85f9-633bd09cf739` ON SCHEMA mkt_prod.marts;
