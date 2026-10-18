-- Grain: one row per Snapchat campaign. The export has no updated_at, so the
-- most recently ingested version wins.
with source as (

    select * from {{ source('snapchat_ads', 'campaigns') }}

),

typed as (

    select
        {{ clean_string('campaign_id') }}   as campaign_id,
        {{ clean_string('account_id') }}    as account_id,
        {{ clean_string('campaign_name') }} as campaign_name,
        _ingested_at
    from source

)

select *
from typed
qualify row_number() over (
    partition by campaign_id
    order by _ingested_at desc
) = 1
