-- Grain: one row per Facebook ad (latest version).
with source as (

    select * from {{ source('facebook_ads', 'ads') }}

),

typed as (

    select
        {{ clean_string('ad_id') }}                         as ad_id,
        {{ clean_string('ad_group_id') }}                   as ad_group_id,
        {{ clean_string('campaign_id') }}                   as campaign_id,
        {{ clean_string('account_id') }}                    as account_id,
        {{ clean_string('ad_name') }}                       as ad_name,
        upper({{ clean_string('ad_status') }})              as ad_status,
        cast({{ clean_string('ad_updated_at') }} as timestamp) as ad_updated_at,
        _ingested_at
    from source

)

select *
from typed
qualify row_number() over (
    partition by ad_id
    order by ad_updated_at desc, _ingested_at desc
) = 1
