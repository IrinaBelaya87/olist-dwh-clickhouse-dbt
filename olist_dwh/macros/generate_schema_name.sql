{#
  По умолчанию dbt склеивает схему из профиля и пользовательскую (stg_stg).
  Нам нужно, чтобы модели слоя попадали ровно в базу слоя: stg, cdm, marts.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
