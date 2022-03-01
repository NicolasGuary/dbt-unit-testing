{% macro extract_columns_list(query) %}
  {% if execute %}
    {% set results = run_query(query) %}
    {{ return(results.columns | map(attribute='name') | list) }}
  {% else %}
    {{ return([]) }}
  {% endif %}
{% endmacro %}

{% macro extract_columns_difference(cl1, cl2) %}
  {% set columns = cl1 | list | reject('in', cl2) | list %}
  {{ return(columns) }}
{% endmacro %}

{% macro sql_encode(s) %}
  {{ return (s.replace('"', '$$$$$$$$$$').replace('\n', '##########')) }}
{% endmacro %}

{% macro sql_decode(s) %}
  {{ return (s.replace('$$$$$$$$$$', '"').replace('##########', '\n')) -}}
{% endmacro %}

{% macro debug(value) %}
  {% do log (value, info=true) %}
{% endmacro %}

{% macro map(items, f) %}
  {% set mapped_items=[] %}
  {% for item in items %}
    {% do mapped_items.append(f(item)) %}
  {% endfor %}
  {{ return (mapped_items) }}
{% endmacro %}

{% macro node_by_id (node_id) %}
  {{ return (graph.nodes[node_id] if node_id.startswith('model') else graph.sources[node_id]) }}
{% endmacro %}

{% macro model_node (model_name) %}
  {{ return (graph.nodes["model." ~ project_name ~ "." ~ model_name]) }}
{% endmacro %}

{% macro source_node (source_name, model_name) %}
  {{ return (graph.sources["source." ~ project_name ~ "." ~ source_name ~ "." ~ model_name]) }}
{% endmacro %}

{% macro fake_source_sql(node) %}
  {% set source_relation = dbt_utils.get_relations_by_pattern(
      schema_pattern=node.schema,
      table_pattern=node.name
  ) %}
  {% if source_relation | length > 0 %}
    {%- set source_sql -%}
      select * from {{ node.schema }}.{{ node.name }} where false
    {%- endset -%}
    select {{ dbt_unit_testing.extract_columns_list(source_sql) | join (",") }}
    from {{ node.schema }}.{{ node.name }}
    where false
  {% else %}
    {% if node.columns %}
      {% set columns = [] %}
      {% for c in node.columns.values() %}
        {% do columns.append("cast(null as " ~ (c.data_type if c.data_type is not none else dbt_utils.type_string()) ~ ") as " ~ c.name) %}
      {% endfor %}
      select {{ columns | join (",") }}
    {% else %}
      {{ exceptions.raise_compiler_error("Source " ~ node.name ~ " columns must be declared in sources.yml, or it must exist in database") }}
    {% endif %}
  {% endif %}
{% endmacro %}

{% macro quote_column_name(column_name) %}
    {{ return(adapter.dispatch('quote_column_name','dbt_unit_testing')(column_name)) }}
{% endmacro %}

{% macro default__quote_column_name(column_name) -%}
    {% if column_name.startswith('"') %}
      {{ return(column_name) }}
    {% else %}
      {{ return('"' ~ column_name ~ '"') }}
    {% endif %}
{%- endmacro %}

{% macro bigquery__quote_column_name(column_name) %}
    {{ return(column_name) }}
{% endmacro %}

{% macro snowflake__quote_column_name(column_name) %}
    {% if column_name.startswith('"') %}
      {{ return(column_name) }}
    {% else %}
      {{ return('"' ~ column_name | upper ~ '"') }}
    {% endif %}
{% endmacro %}