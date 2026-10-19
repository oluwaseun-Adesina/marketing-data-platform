-- =============================================================================
-- Section 18 business questions, answered from the consumption layer only.
-- `dbt compile -s business_questions` renders these with real table names.
-- Every query uses SUM of additive columns, and ratios are ratio-of-sums.
-- =============================================================================

-- Q1. Total advertising spend (EUR, all platforms)
select sum(spend_eur) as total_spend_eur
from {{ ref('mart_campaign_daily') }};

-- Q2/Q3. Spend, impressions, clicks per platform, with CTR / CPC / CPM
select
    platform,
    min(date_day)                                                    as first_day,
    max(date_day)                                                    as last_day,
    sum(spend_eur)                                                   as spend_eur,
    sum(impressions)                                                 as impressions,
    sum(clicks)                                                      as clicks,
    {{ safe_divide('cast(sum(clicks) as double)', 'sum(impressions)') }}  as ctr,
    {{ safe_divide('sum(spend_eur)', 'sum(clicks)') }}               as cpc_eur,
    {{ safe_divide('sum(spend_eur) * 1000', 'sum(impressions)') }}   as cpm_eur
from {{ ref('mart_campaign_daily') }}
group by platform
order by spend_eur desc;

-- Q4. Spend by campaign (top 10)
select platform, campaign_name, sum(spend_eur) as spend_eur
from {{ ref('mart_campaign_daily') }}
group by platform, campaign_name
order by spend_eur desc
limit 10;

-- Q5. Campaigns with the most impressions (top 10)
select platform, campaign_name, sum(impressions) as impressions
from {{ ref('mart_campaign_daily') }}
group by platform, campaign_name
order by impressions desc
limit 10;

-- Q6. Campaign with the most clicks
select platform, campaign_name, sum(clicks) as clicks
from {{ ref('mart_campaign_daily') }}
group by platform, campaign_name
order by clicks desc
limit 1;

-- Q7. Performance over time: monthly trend per platform
select month_start, platform, spend_eur, impressions, clicks, ctr, cpc_eur, cpm_eur
from {{ ref('mart_platform_monthly') }}
order by month_start, platform;

-- Q8. "How much did we spend on Facebook last month?"
--      "Last month" is relative to the latest data available, not today, because
--      the sample data ends in 2025. An agent should state which month it used.
select month_start, sum(spend_eur) as spend_eur
from {{ ref('mart_campaign_daily') }}
where platform = 'facebook'
  and month_start = (select max(month_start) from {{ ref('mart_campaign_daily') }} where platform = 'facebook')
group by month_start;

-- Q9. Why converting currency matters: Facebook spend by billing currency
select local_currency_code, sum(spend_local) as spend_local, sum(spend_eur) as spend_eur
from {{ ref('mart_campaign_daily') }}
where platform = 'facebook'
group by local_currency_code;
