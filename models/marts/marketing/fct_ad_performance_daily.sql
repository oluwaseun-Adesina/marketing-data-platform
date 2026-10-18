{#
  THE atomic fact of the platform.
  Grain: one row per platform per ad per day.
  Primary key: ad_performance_key = hash(platform, ad_id, date_day).

  Why ad/day and not campaign/day (as in the brief's example)?
  ad/day is the lowest grain BOTH platforms share. Campaign/day, platform/month,
  etc. are all exact SUMs of it, but you cannot drill from campaign back to ad.
  Model at the lowest grain, aggregate up in marts.

  Why only additive measures here (no CTR/CPC/CPM columns)?
  Ratios cannot be summed or averaged across rows. AVG(ctr) over campaigns
  gives the wrong answer, and an AI agent would happily compute it. Ratios are
  derived as SUM(clicks)/SUM(impressions) at query time (see
  mart_platform_monthly and the metric docs).

  Why spend stays in LOCAL currency here?
  Facts should be immutable observations. FX rates are reference data that can
  be corrected. If spend_eur lived in this incremental table, fixing a rate
  would leave old rows stale until a full refresh. Conversion happens in the
  marts, which are rebuilt fully on every run.

  Incremental strategy: MERGE on ad_performance_key, filtered by INGESTION
  watermark (not event date).
    * Ad platforms restate recent days (attribution windows). A restated row
      gets a new _ingested_at upstream, the watermark picks it up, and MERGE
      overwrites the old version. Append would duplicate it.
    * Filtering on ingestion time (instead of "last N days of date_day") also
      catches late restatements of OLD dates, with no magic lookback number.
    * Snapchat rows are pre-aggregated upstream from ALL country rows, so a
      restated single country still produces a complete, correct ad/day row.
    * Overlap var (incremental_overlap_hours) re-merges a small window below the
      watermark, which is safe because MERGE is idempotent.
  Honest note: at today's ~95k rows a plain table would rebuild in seconds. The
  incremental design is for daily production loads, where re-scanning years of
  history every run costs real money, and for correct restatement handling.
  Known limitation: rows DELETED at the source are not deleted here. Run
  `dbt build --full-refresh -s fct_ad_performance_daily` periodically (weekly).
#}
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = 'ad_performance_key',
        on_schema_change = 'append_new_columns',
        liquid_clustered_by = ['date_day', 'platform'],
        contract = {'enforced': true}
    )
}}

with source as (

    select * from {{ ref('int_marketing__ad_daily_unioned') }}

    {% if is_incremental() %}
    where _source_ingested_at > (
        select {{ dbt.dateadd('hour', -1 * var('incremental_overlap_hours'),
                              "coalesce(max(_source_ingested_at), cast('1900-01-01' as timestamp))") }}
        from {{ this }}
    )
    {% endif %}

)

select
    cast(ad_performance_key as string)       as ad_performance_key,
    cast(date_day as date)                   as date_day,
    cast(platform as string)                 as platform,
    cast(ad_key as string)                   as ad_key,
    cast(campaign_key as string)             as campaign_key,
    cast(ad_id as string)                    as ad_id,
    cast(ad_group_id as string)              as ad_group_id,
    cast(campaign_id as string)              as campaign_id,
    cast(account_id as string)               as account_id,
    cast(currency_code as string)            as currency_code,
    cast(spend_local as decimal(18, 6))      as spend_local,
    cast(impressions as bigint)              as impressions,
    cast(clicks as bigint)                   as clicks,
    cast(has_unreported_metrics as boolean)  as has_unreported_metrics,
    cast(source_row_count as int)            as source_row_count,
    cast(_source_ingested_at as timestamp)   as _source_ingested_at,
    cast({{ dbt.current_timestamp() }} as timestamp) as _dbt_loaded_at
from source
