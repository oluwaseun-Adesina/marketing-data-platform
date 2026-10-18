{#
  Grain: one row per Snapchat ad per day PER COUNTRY. This grain is kept on
  purpose: staging does not aggregate. The roll-up to ad/day happens in
  int_snapchat__ad_daily, so a future country-level mart can still be built
  from this model.

  Spend check: values like 48.174024 are real currency units. Snapchat's API
  reports micro-currency (x 1,000,000), but this export is already converted.
  A row-level max-spend test guards against a future micro-currency file.
#}
with source as (

    select * from {{ source('snapchat_ads', 'ad_stats') }}

),

typed as (

    select
        {{ clean_string('ad_detail_id') }}                     as ad_id,
        cast({{ clean_string('ad_date') }} as date)            as date_day,
        upper({{ clean_string('ad_country') }})                as country_code,
        upper({{ clean_string('ad_currency_code') }})          as currency_code,
        cast({{ clean_string('ad_spend') }} as decimal(18, 6)) as spend,
        cast({{ clean_string('ad_impressions') }} as bigint)   as impressions,
        cast({{ clean_string('ad_clicks') }} as bigint)        as clicks,
        _source_file,
        _ingested_at
    from source

)

select *
from typed
qualify row_number() over (
    partition by ad_id, date_day, country_code
    order by _ingested_at desc, _source_file desc
) = 1
