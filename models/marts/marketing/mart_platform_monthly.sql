{#
  Platform comparison by month, with the efficiency ratios computed CORRECTLY.
  Grain: one row per platform per month. Key: (platform, month_start).

  Ratios are ratio-of-sums at THIS grain:
      ctr     = SUM(clicks) / SUM(impressions)
      cpc_eur = SUM(spend_eur) / SUM(clicks)
      cpm_eur = SUM(spend_eur) / SUM(impressions) * 1000
  They are NOT re-aggregatable. A yearly CTR is not AVG(ctr) of these months.
  To aggregate further, re-sum the additive columns (also in this table) first.
  Zero denominators give NULL via safe_divide (undefined, not 0).

  Materialized as a VIEW: it is a small aggregate over mart_campaign_daily, so
  it is always consistent with it and costs nothing to store.
#}
{{ config(materialized = 'view') }}

with campaign_daily as (

    select * from {{ ref('mart_campaign_daily') }}

),

monthly as (

    select
        month_start,
        platform,
        sum(spend_eur)                 as spend_eur,
        sum(impressions)               as impressions,
        sum(clicks)                    as clicks,
        count(distinct campaign_key)   as campaigns_with_activity,
        count(distinct date_day)       as days_with_activity
    from campaign_daily
    group by month_start, platform

)

select
    month_start,
    platform,
    cast(spend_eur as decimal(18, 2))                                            as spend_eur,
    impressions,
    clicks,
    campaigns_with_activity,
    days_with_activity,
    round({{ safe_divide('cast(clicks as double)', 'impressions') }}, 6)          as ctr,
    cast({{ safe_divide('spend_eur', 'clicks') }} as decimal(18, 4))              as cpc_eur,
    cast({{ safe_divide('spend_eur * 1000', 'impressions') }} as decimal(18, 4))  as cpm_eur
from monthly
