{#
  Environment-aware schema naming.

  prod      ->  <custom>                 e.g. mkt_prod.marts
  dev / ci  ->  <target.schema>_<custom> e.g. mkt_dev.dbt_oluwaseun_marts
                                              mkt_ci.pr_42_marts

  Why: in prod, consumers need stable, clean names (marts, staging).
  Everywhere else, every developer and every pull request gets an isolated
  set of schemas, so two people (or two PRs) can never overwrite each other.
  The catalog (mkt_dev / mkt_ci / mkt_prod) comes from the dbt target.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
