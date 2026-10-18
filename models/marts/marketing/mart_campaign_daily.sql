{#
  PRIMARY CONSUMPTION TABLE for analysts, BI tools and AI agents.
  Grain: one row per platform per campaign per day.
  Key: (campaign_key, date_day).

  * Wide and pre-joined: campaign and account names are already here, so no
    joins are needed to answer "spend by campaign".
  * Only ADDITIVE measures. Any SUM over any set of rows is correct.
  * Spend in BOTH local currency and EUR. spend_eur is the only column safe to
    sum across platforms/accounts, because Facebook accounts bill in USD and EUR.
  * Materialized as a TABLE: queried constantly by dashboards and agents,
    rebuilt fully each run (cheap) so FX corrections and campaign renames always apply.
#}
{{ config(contract = {'enforced': true}) }}

with fact as (

    select * from {{ ref('fct_ad_performance_daily') }}

),

campaigns as (

    select * from {{ ref('dim_campaigns') }}

),

fx as (

    select * from {{ ref('fx_rates_annual') }}

),

campaign_day as (

    select
        fact.campaign_key,
        fact.date_day,
        fact.platform,
        fact.currency_code,
        sum(fact.spend_local)                     as spend_local,
        sum(fact.spend_local / fx.units_per_eur)  as spend_eur,
        sum(fact.impressions)                     as impressions,
        sum(fact.clicks)                          as clicks
    from fact
    left join fx
        on  fact.currency_code = fx.currency_code
        and extract(year from fact.date_day) = fx.rate_year
    group by
        fact.campaign_key,
        fact.date_day,
        fact.platform,
        fact.currency_code

)

select
    cast(campaign_day.date_day as date)                                    as date_day,
    cast({{ dbt.date_trunc('month', 'campaign_day.date_day') }} as date)   as month_start,
    cast(campaign_day.platform as string)                                  as platform,
    cast(campaign_day.campaign_key as string)                              as campaign_key,
    cast(campaigns.campaign_id as string)                                  as campaign_id,
    cast(campaigns.campaign_name as string)                                as campaign_name,
    cast(campaigns.account_id as string)                                   as account_id,
    cast(campaigns.account_name as string)                                 as account_name,
    cast(campaign_day.currency_code as string)                             as local_currency_code,
    cast(campaign_day.spend_local as decimal(18, 6))                       as spend_local,
    cast(campaign_day.spend_eur as decimal(18, 6))                         as spend_eur,
    cast(campaign_day.impressions as bigint)                               as impressions,
    cast(campaign_day.clicks as bigint)                                    as clicks
from campaign_day
left join campaigns
    on campaign_day.campaign_key = campaigns.campaign_key
