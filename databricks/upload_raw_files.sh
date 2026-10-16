#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Upload the provided CSVs to the Unity Catalog landing volume.
# Each source table gets its own folder, so COPY INTO can point at a directory
# and new daily files can be dropped in later without changing any SQL.
#
# Prereqs: Databricks CLI >= 0.205, authenticated (`databricks auth login`).
# Usage:   ./databricks/upload_raw_files.sh /path/to/cde_dbt_sample_data
# -----------------------------------------------------------------------------
set -euo pipefail

SRC="${1:?Usage: $0 <path-to-cde_dbt_sample_data>}"
VOL="dbfs:/Volumes/mkt_raw/landing/files"

# local file                                                     -> volume folder
declare -A FILES=(
  ["facebook/ads_stats.csv"]="facebook/ads_stats"
  ["facebook/new_ads_de_randomized.csv"]="facebook/ads"
  ["facebook/new_adgroup_de_randomized.csv"]="facebook/ad_groups"
  ["facebook/new_campaign_de_randomized.csv"]="facebook/campaigns"
  ["facebook/new_acccount_de_randomized.csv"]="facebook/accounts"
  ["snapchat/snapchat_ads_stats.csv"]="snapchat/ad_stats"
  ["snapchat/snapchat_ads_ad_history_new_ad_names.csv"]="snapchat/ads"
  ["snapchat/snapchat_ads_adgroup_history_new_ad_group_names.csv"]="snapchat/ad_groups"
  ["snapchat/snapchat_ads_campaign_history_new_campaign_names.csv"]="snapchat/campaigns"
)

for f in "${!FILES[@]}"; do
  dir="${VOL}/${FILES[$f]}"
  dest="${dir}/$(basename "$f")"
  echo "-> ${dest}"
  databricks fs mkdir "${dir}"          # volumes don't auto-create parent folders
  databricks fs cp --overwrite "${SRC}/${f}" "${dest}"
done
echo "Done. Now run databricks/01_bronze_load.sql"
