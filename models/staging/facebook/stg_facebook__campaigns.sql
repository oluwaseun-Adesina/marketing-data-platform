-- Grain: one row per Facebook campaign (latest version).
with source as (

    select * from {{ source('facebook_ads', 'campaigns') }}

),

typed as (

    select
        {{ clean_string('campaign_id') }}                            as campaign_id,
        {{ clean_string('campaign_name') }}                          as campaign_name,
        cast({{ clean_string('campaign_updated_at') }} as timestamp) as campaign_updated_at,
        _ingested_at
    from source

)

select *
from typed
qualify row_number() over (
    partition by campaign_id
    order by campaign_updated_at desc, _ingested_at desc
) = 1
