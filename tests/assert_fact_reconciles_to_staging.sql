{#
  The most important test in the project: NOTHING WAS LOST OR DOUBLE-COUNTED.

  Compares total spend / impressions / clicks per platform between staging
  (closest to raw) and the fact. Every bug that silently corrupts marketing
  numbers shows up here as a difference:
    * fan-out from a duplicated dimension row (e.g. Snapchat ad-group history)
    * rows dropped by an inner join to an incomplete dimension
    * a broken incremental filter that skips or double-loads rows
  Returns one row per platform/metric that does not reconcile.
#}
{{ config(severity = 'error') }}

with staging_totals as (

    select 'facebook' as platform,
           sum(spend) as spend,
           sum(coalesce(impressions, 0)) as impressions,
           sum(coalesce(clicks, 0)) as clicks
    from {{ ref('stg_facebook__ad_stats') }}

    union all

    select 'snapchat',
           sum(spend),
           sum(coalesce(impressions, 0)),
           sum(coalesce(clicks, 0))
    from {{ ref('stg_snapchat__ad_stats') }}

),

fact_totals as (

    select platform,
           sum(spend_local) as spend,
           sum(impressions) as impressions,
           sum(clicks)      as clicks
    from {{ ref('fct_ad_performance_daily') }}
    group by platform

)

select
    s.platform,
    s.spend        as staging_spend,       f.spend       as fact_spend,
    s.impressions  as staging_impressions, f.impressions as fact_impressions,
    s.clicks       as staging_clicks,      f.clicks      as fact_clicks
from staging_totals s
left join fact_totals f on s.platform = f.platform
where f.platform is null
   or abs(s.spend - f.spend) > 0.01
   or s.impressions <> f.impressions
   or s.clicks <> f.clicks
