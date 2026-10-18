{#
  Snapchat performance normalised to the shared platform contract.
  Grain: one row per Snapchat ad per day.

  Snapchat reports per COUNTRY. Facebook has no country, so the lowest grain
  the two platforms share is ad x day. Country rows are summed here, which is
  safe because spend, impressions and clicks are additive.
  currency_code is part of the GROUP BY on purpose: if one ad/day ever arrives
  in two currencies, it becomes two rows, the unique test on (ad_id, date_day)
  fails, and we never sum EUR with USD.

  Ad groups are joined from the DEDUPLICATED staging model (the raw history
  export holds duplicate ad groups that would double spend).
#}
with stats as (

    select * from {{ ref('stg_snapchat__ad_stats') }}

),

ad_day as (

    select
        ad_id,
        date_day,
        currency_code,
        cast(sum(spend) as decimal(18, 6))                     as spend_local,
        sum(coalesce(impressions, 0))                          as impressions,
        sum(coalesce(clicks, 0))                               as clicks,
        max(case when impressions is null or clicks is null
                 then 1 else 0 end) = 1                        as has_unreported_metrics,
        count(*)                                               as source_row_count,
        max(_ingested_at)                                      as _source_ingested_at
    from stats
    group by ad_id, date_day, currency_code

),

ads as (

    select ad_id, ad_group_id from {{ ref('stg_snapchat__ads') }}

),

ad_groups as (

    select ad_group_id, campaign_id from {{ ref('stg_snapchat__ad_groups') }}

),

campaigns as (

    select campaign_id, account_id from {{ ref('stg_snapchat__campaigns') }}

)

select
    'snapchat'                     as platform,
    ad_day.date_day,
    ad_day.ad_id,
    ads.ad_group_id,
    ad_groups.campaign_id,
    campaigns.account_id,
    ad_day.currency_code,
    ad_day.spend_local,
    ad_day.impressions,
    ad_day.clicks,
    ad_day.has_unreported_metrics,
    ad_day.source_row_count,
    ad_day._source_ingested_at

from ad_day
left join ads       on ad_day.ad_id = ads.ad_id
left join ad_groups on ads.ad_group_id = ad_groups.ad_group_id
left join campaigns on ad_groups.campaign_id = campaigns.campaign_id
