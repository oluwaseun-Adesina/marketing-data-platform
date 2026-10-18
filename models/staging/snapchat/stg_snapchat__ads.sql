-- Grain: one row per Snapchat ad (latest version from the history export).
with source as (

    select * from {{ source('snapchat_ads', 'ads') }}

),

typed as (

    select
        {{ clean_string('ad_id') }}                                   as ad_id,
        {{ clean_string('ad_group_id') }}                             as ad_group_id,
        {{ clean_string('ad_name') }}                                 as ad_name,
        cast({{ clean_string('ad_detail_updated_at') }} as timestamp) as ad_updated_at,
        _ingested_at
    from source

)

select *
from typed
qualify row_number() over (
    partition by ad_id
    order by ad_updated_at desc, _ingested_at desc
) = 1
