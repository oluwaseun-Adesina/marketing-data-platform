{#
  Grain: one row per Facebook ad per day.

  * Types every column (bronze is all STRING).
  * Turns "null" text into real NULLs. Metrics stay NULL here, because staging
    reflects the source faithfully. The business rule "missing = 0" is applied in
    intermediate, where it is documented and unit-tested.
  * Deduplicates on (ad_id, date_day), keeping the most recently ingested
    version. Ad platforms restate recent days as attribution windows close, and a
    re-sent row must replace the old one, never sit beside it.
#}
with source as (

    select * from {{ source('facebook_ads', 'ads_stats') }}

),

typed as (

    select
        {{ clean_string('ad_id') }}                                  as ad_id,
        {{ clean_string('account_id') }}                             as account_id,
        cast({{ clean_string('ad_date') }} as date)                  as date_day,
        cast({{ clean_string('ad_spend') }} as decimal(18, 6))       as spend,
        cast({{ clean_string('ad_impressions') }} as bigint)         as impressions,
        cast({{ clean_string('ad_clicks') }} as bigint)              as clicks,
        _source_file,
        _ingested_at
    from source

)

select *
from typed
qualify row_number() over (
    partition by ad_id, date_day
    order by _ingested_at desc, _source_file desc
) = 1
