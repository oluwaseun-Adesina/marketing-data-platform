{#
  Division that returns NULL (not an error, not 0, not infinity) when the
  denominator is 0 or NULL.

  Business rule: CPC on a day with 0 clicks is UNDEFINED, not 0. Reporting
  0 would say "clicks were free", which is wrong and would pull averages down.
  NULL is also what BI tools and LLM agents handle correctly (ignored by AVG,
  shown as blank).
#}
{% macro safe_divide(numerator, denominator) -%}
    ({{ numerator }}) / nullif({{ denominator }}, 0)
{%- endmacro %}
