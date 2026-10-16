{#
  Normalise a raw STRING column: trim whitespace and turn empty strings and
  textual null tokens into real NULLs.

  Why: the platform exports write missing values as the literal text "null"
  (24k+ rows in Facebook ad_clicks). Casting "null" to BIGINT errors, and
  treating it as a value is wrong. One macro keeps the rule identical across
  every staging model.
#}
{% macro clean_string(column) -%}
    case
        when {{ column }} is null then null
        when lower(trim({{ column }})) in ('', 'null', 'none', 'nan', 'n/a') then null
        else trim({{ column }})
    end
{%- endmacro %}
