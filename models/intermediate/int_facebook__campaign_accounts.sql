{#
  Facebook's campaign export has no account_id, so the campaign -> account
  link is derived from the ads export (each ad carries both ids).
  Grain: one row per campaign_id.
  The unique test on campaign_id proves that every campaign maps to exactly one
  account. If that ever stops holding, this model fails rather than
  dim_campaigns silently duplicating campaigns.
#}
select distinct
    campaign_id,
    account_id
from {{ ref('stg_facebook__ads') }}
where campaign_id is not null
  and account_id is not null
