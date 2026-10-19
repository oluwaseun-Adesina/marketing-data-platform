{#
  Drop every schema in the current target catalog whose name starts with
  `prefix`. Used by the CI teardown workflow when a pull request closes:

    dbt run-operation drop_ci_schemas --args '{prefix: pr_42}' --target ci

  Guard rail: refuses to run against any target other than `ci`.
#}
{% macro drop_ci_schemas(prefix) %}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas only runs on the ci target (got '" ~ target.name ~ "')") }}
    {% endif %}
    {% if not prefix or prefix | length < 4 %}
        {{ exceptions.raise_compiler_error("Refusing to drop schemas with an empty/short prefix") }}
    {% endif %}

    {# dbt's built-in list_schemas macro dispatches per adapter
       (Databricks: SHOW SCHEMAS IN <catalog>) #}
    {% set schemas = [] %}
    {% for s in list_schemas(target.database).columns[0].values() %}
        {# match "pr_7_" so that pr_7 never drops pr_70_* #}
        {% if (s | lower).startswith((prefix ~ '_') | lower) %}
            {% do schemas.append(s) %}
        {% endif %}
    {% endfor %}

    {% for s in schemas %}
        {% do log("Dropping " ~ target.database ~ "." ~ s, info=True) %}
        {% do run_query("drop schema if exists " ~ target.database ~ "." ~ s ~ " cascade") %}
    {% endfor %}
    {% do log("Dropped " ~ schemas | length ~ " schema(s) with prefix " ~ prefix, info=True) %}
{% endmacro %}
