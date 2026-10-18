{#
  Facebook performance normalised to the shared platform contract.
  Grain: one row per Facebook ad per day (same as staging, no aggregation).

  Business rule, "missing metric = 0":
  In the source, clicks are "null" on 24,337 rows and an explicit 0 on only 42.
  Impressions are "null" on 1,474 rows, and every one of those has spend = 0.
  The export omits zero-valued metrics instead of writing 0, so NULL is
  coalesced to 0 for additive metrics. has_unreported_metrics keeps the
  original signal, so the assumption can be audited or reversed.
#}
with stats as (

    select * from {{ ref('stg_facebook__ad_stats') }}

),

ads as (

    select ad_id, ad_group_id, campaign_id from {{ ref('stg_facebook__ads') }}

),

accounts as (

    select account_id, currency_code from {{ ref('stg_facebook__accounts') }}

)

select
    'facebook'                                         as platform,
    stats.date_day,
    stats.ad_id,
    ads.ad_group_id,
    ads.campaign_id,
    stats.account_id,
    accounts.currency_code,
    stats.spend                                        as spend_local,
    coalesce(stats.impressions, 0)                     as impressions,
    coalesce(stats.clicks, 0)                          as clicks,
    (stats.impressions is null or stats.clicks is null) as has_unreported_metrics,
    1                                                  as source_row_count,
    stats._ingested_at                                 as _source_ingested_at

from stats
-- LEFT joins: an ad missing from the ads export must not make its spend
-- disappear. The fact's not_null(campaign_key) test flags it instead.
left join ads      on stats.ad_id = ads.ad_id
left join accounts on stats.account_id = accounts.account_id
