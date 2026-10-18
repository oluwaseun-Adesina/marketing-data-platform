{#
  Every fact row with spend must have an FX rate for its currency and year.

  Why a dedicated test: a missing rate does not error. The LEFT JOIN yields
  NULL spend_eur, and SUM() silently skips NULLs. Total EUR spend would just be
  too low, with no visible failure. This test turns that silent gap into a
  failed build that names the missing currency/year.
#}
select
    f.currency_code,
    extract(year from f.date_day) as spend_year,
    count(*)                      as rows_without_rate,
    sum(f.spend_local)            as unconverted_spend_local
from {{ ref('fct_ad_performance_daily') }} f
left join {{ ref('fx_rates_annual') }} fx
    on  f.currency_code = fx.currency_code
    and extract(year from f.date_day) = fx.rate_year
where fx.currency_code is null
group by 1, 2
