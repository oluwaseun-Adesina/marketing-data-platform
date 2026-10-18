{#
  Both platforms stacked into one shape, with surrogate keys.
  Grain: one row per platform per ad per day.

  Materialized EPHEMERAL: it is a pure UNION ALL + key hashing with a single
  consumer (the fact). Persisting it would store a full copy of the data for no
  reader. Ephemeral inlines it as a CTE into the fact's SQL.

  Surrogate keys hash platform INTO the key. Facebook and Snapchat ids come
  from different id spaces. Today they never collide (numeric vs UUID), but
  nothing guarantees that, and a cross-platform collision would silently merge
  two campaigns. Campaign NAME is never used as a key.
#}
{{ config(materialized='ephemeral') }}
{%- set platforms =['int_facebook__ad_daily', 'int_snapchat__ad_daily'] -%}

with unioned as (

    {% for model in platforms %}
    select
        platform,
        date_day,
        ad_id,
        ad_group_id,
        campaign_id,
        account_id,
        currency_code,
        spend_local,
        impressions,
        clicks,
        has_unreported_metrics,
        source_row_count,
        _source_ingested_at
    from {{ ref(model) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

)

select
    {{ dbt_utils.generate_surrogate_key(['platform', 'ad_id', 'date_day']) }} as ad_performance_key,
    {{ dbt_utils.generate_surrogate_key(['platform', 'ad_id']) }}             as ad_key,
    -- NULL (not a hash of NULL) when the campaign is unknown, so the not_null
    -- test on the fact catches orphaned spend instead of hiding it.
    case when campaign_id is not null
         then {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }}
    end                                                                        as campaign_key,
    *
from unioned
