{#
  Campaign dimension across platforms.
  Grain: one row per platform per campaign_id. Key: campaign_key = hash(platform, campaign_id).

  Names live HERE, not in the incremental fact. A campaign renamed on the
  platform is picked up on the next run (this table is rebuilt fully), and every
  historical fact row shows the new name with no backfill needed (SCD type 1).
#}
with facebook as (

    select
        'facebook'               as platform,
        c.campaign_id,
        c.campaign_name,
        ca.account_id,
        acc.account_name,
        acc.currency_code        as account_currency_code
    from {{ ref('stg_facebook__campaigns') }} c
    left join {{ ref('int_facebook__campaign_accounts') }} ca on c.campaign_id = ca.campaign_id
    left join {{ ref('stg_facebook__accounts') }} acc          on ca.account_id = acc.account_id

),

snapchat as (

    select
        'snapchat'               as platform,
        campaign_id,
        campaign_name,
        account_id,
        cast(null as string)     as account_name,          -- no Snapchat account export provided
        cast(null as string)     as account_currency_code  -- currency arrives per stats row instead
    from {{ ref('stg_snapchat__campaigns') }}

),

unioned as (

    select * from facebook
    union all
    select * from snapchat

)

select
    {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }} as campaign_key,
    platform,
    campaign_id,
    campaign_name,
    account_id,
    account_name,
    account_currency_code
from unioned
