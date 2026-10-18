-- Grain: one row per Facebook ad set (latest version).
with source as (

    select * from {{ source('facebook_ads', 'ad_groups') }}

),

typed as (

    select
        {{ clean_string('ad_group_id') }}                            as ad_group_id,
        {{ clean_string('ad_group_name') }}                          as ad_group_name,
        cast({{ clean_string('ad_group_updated_at') }} as timestamp) as ad_group_updated_at,
        _ingested_at
    from source

)

select *
from typed
qualify row_number() over (
    partition by ad_group_id
    order by ad_group_updated_at desc, _ingested_at desc
) = 1
