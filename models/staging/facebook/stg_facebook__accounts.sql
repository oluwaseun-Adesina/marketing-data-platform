-- Grain: one row per Facebook ad account (latest version).
with source as (

    select * from {{ source('facebook_ads', 'accounts') }}

),

typed as (

    select
        {{ clean_string('account_id') }}                            as account_id,
        {{ clean_string('account_name') }}                          as account_name,
        upper({{ clean_string('ad_currency_code') }})               as currency_code,
        cast({{ clean_string('account_created_at') }} as timestamp) as account_created_at,
        cast({{ clean_string('account_updated_at') }} as timestamp) as account_updated_at,
        _ingested_at
    from source

)

select *
from typed
qualify row_number() over (
    partition by account_id
    order by account_updated_at desc, _ingested_at desc
) = 1
