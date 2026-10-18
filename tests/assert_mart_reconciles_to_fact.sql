{#
  mart_campaign_daily is an aggregation of the fact joined to dim_campaigns.
  If a dimension ever gained a duplicate key, the join would multiply spend.
  The unique test on dim_campaigns should catch that first. This is the
  end-to-end safety net on the table consumers actually read.
#}
with f as (
    select platform, sum(spend_local) as spend, sum(clicks) as clicks, sum(impressions) as impressions
    from {{ ref('fct_ad_performance_daily') }}
    group by platform
),

m as (
    select platform, sum(spend_local) as spend, sum(clicks) as clicks, sum(impressions) as impressions
    from {{ ref('mart_campaign_daily') }}
    group by platform
)

select f.platform, f.spend as fact_spend, m.spend as mart_spend
from f
left join m on f.platform = m.platform
where m.platform is null
   or abs(f.spend - m.spend) > 0.01
   or f.clicks <> m.clicks
   or f.impressions <> m.impressions
