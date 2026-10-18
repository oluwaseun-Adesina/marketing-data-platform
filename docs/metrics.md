{% docs __overview__ %}
# Marketing Data Platform

One governed, documented, tested dataset for paid-advertising performance across
**Facebook Ads** and **Snapchat Ads**.

## Where to start

| You want to… | Use |
|---|---|
| Answer business questions (spend, clicks, campaigns, trends) | **`mart_campaign_daily`**, wide, no joins needed |
| Compare platforms month by month with CTR / CPC / CPM | **`mart_platform_monthly`** |
| Drill to ad / creative level | `fct_ad_performance_daily` + `dim_ads` + `dim_campaigns` |

## Rules that keep answers correct

1. **Sum `spend_eur`, never `spend_local`, across platforms or accounts.** Facebook accounts bill in USD *and* EUR.
2. **Never average a ratio.** CTR = `SUM(clicks) / SUM(impressions)` over whatever rows you are looking at.
3. **Join on `*_key` columns, never on names.** Campaign names are not unique across platforms.
4. Data coverage: Facebook **2025-01-01 → 2025-12-31**, Snapchat **2024-01-01 → 2024-12-02**.
   A side-by-side comparison for the same period will show one platform empty.

## Layers

`sources (mkt_raw)` → `staging` (typed, deduplicated, views) → `intermediate`
(platform normalisation) → `marts` (facts, dimensions, consumption tables).
Use the lineage graph (bottom-right button) to follow any column back to its raw file.
{% enddocs %}


{% docs fct_ad_performance_daily %}
Atomic, cross-platform ad performance.

**Grain: one row per platform × ad × day.** Primary key `ad_performance_key`.

Contains only **additive** measures (`spend_local`, `impressions`, `clicks`). Ratios are
deliberately absent: see the metric definitions. Spend is in **local currency**. Use
`mart_campaign_daily.spend_eur` for cross-platform totals.

Snapchat's country-level rows are summed to ad/day upstream. Facebook has no country
breakdown, so ad/day is the lowest grain both platforms share.

Incremental (`merge` on key, ingestion-time watermark) to handle platform restatements.
{% enddocs %}


{% docs mart_campaign_daily %}
**The main table for analysts, BI tools and AI agents.**

**Grain: one row per platform × campaign × day.** Unique on (`campaign_key`, `date_day`).

Pre-joined with campaign and account names. All measures are additive, so any `SUM`
over any filter is correct. `spend_eur` is comparable across platforms.

Example questions:
- *How much did we spend on Facebook last month?* → `SUM(spend_eur) WHERE platform='facebook' AND month_start = <month>`
- *Which campaign had the most clicks?* → `GROUP BY campaign_name ORDER BY SUM(clicks) DESC`
- *CPC by campaign* → `SUM(spend_eur) / NULLIF(SUM(clicks), 0)`
{% enddocs %}


{% docs mart_platform_monthly %}
Facebook vs Snapchat, month by month, with **correctly computed** efficiency ratios.

**Grain: one row per platform × month.**

`ctr`, `cpc_eur`, `cpm_eur` are ratio-of-sums at this grain and are **not re-aggregatable**:
a yearly CTR is `SUM(clicks)/SUM(impressions)` over the months, *not* `AVG(ctr)`.
{% enddocs %}


{% docs col_platform %}
Advertising platform, lower-case: `facebook` or `snapchat`.
{% enddocs %}

{% docs col_spend_local %}
Amount spent, in the ad account's own currency (see the currency column). **Do not
sum across platforms/accounts.** Currencies differ (USD and EUR).
{% enddocs %}

{% docs col_spend_eur %}
Amount spent converted to **EUR** (reporting currency): `spend_local / units_per_eur`
using the annual ECB average for the spend year (`fx_rates_annual`). **Safe to sum across
platforms and accounts.** Use this for any total or comparison.
{% enddocs %}

{% docs col_impressions %}
Number of times ads were shown. Additive. Source "null" values are treated as 0.
{% enddocs %}

{% docs col_clicks %}
Number of clicks on ads. Additive. Source "null" values are treated as 0 (the
Facebook export omits zero click counts instead of writing 0).
{% enddocs %}

{% docs metric_ctr %}
**Click-through rate** = `SUM(clicks) / SUM(impressions)`, a fraction (0.012 = 1.2%).
NULL when impressions = 0. Never average CTRs. Recompute from sums.
{% enddocs %}

{% docs metric_cpc %}
**Cost per click (EUR)** = `SUM(spend_eur) / SUM(clicks)`. NULL when clicks = 0
(undefined, not free).
{% enddocs %}

{% docs metric_cpm %}
**Cost per 1,000 impressions (EUR)** = `SUM(spend_eur) / SUM(impressions) × 1000`.
NULL when impressions = 0.
{% enddocs %}
