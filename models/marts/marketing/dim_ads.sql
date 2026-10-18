{#
  Ad (creative) dimension across platforms.
  Grain: one row per platform per ad_id. Key: ad_key = hash(platform, ad_id).
  Includes the ad group / ad set level as attributes. It is a pure hierarchy
  level with no metrics of its own, so it does not justify a separate dimension.
#}
with facebook as (

    select
        'facebook'          as platform,
        a.ad_id,
        a.ad_name,
        a.ad_status,
        a.ad_group_id,
        g.ad_group_name,
        a.campaign_id
    from {{ ref('stg_facebook__ads') }} a
    left join {{ ref('stg_facebook__ad_groups') }} g on a.ad_group_id = g.ad_group_id

),

snapchat as (

    select
        'snapchat'           as platform,
        a.ad_id,
        a.ad_name,
        cast(null as string) as ad_status,   -- not in the Snapchat export
        a.ad_group_id,
        g.ad_group_name,
        g.campaign_id
    from {{ ref('stg_snapchat__ads') }} a
    left join {{ ref('stg_snapchat__ad_groups') }} g on a.ad_group_id = g.ad_group_id

),

unioned as (

    select * from facebook
    union all
    select * from snapchat

)

select
    {{ dbt_utils.generate_surrogate_key(['platform', 'ad_id']) }} as ad_key,
    case when campaign_id is not null
         then {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }}
    end                                                         as campaign_key,
    platform,
    ad_id,
    ad_name,
    ad_status,
    ad_group_id,
    ad_group_name,
    campaign_id
from unioned
