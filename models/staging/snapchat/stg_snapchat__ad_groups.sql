{#
  Grain: one row per Snapchat ad group (latest version).

  The raw history export has 267 rows for 264 ad groups. Three ids appear twice
  (same name, different ad_group_updated_at). Joining stats to the raw table
  would double those ad groups' spend. We keep the latest version (SCD type 1).
  If the business ever needs "the name at the time of spend", this becomes a
  dbt snapshot / SCD2 instead.
#}
with source as (

    select * from {{ source('snapchat_ads', 'ad_groups') }}

),

typed as (

    select
        {{ clean_string('ad_group_id') }}                            as ad_group_id,
        {{ clean_string('campaign_id') }}                            as campaign_id,
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
