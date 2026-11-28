{#-
    clean_code(col)
    clean_text() + upper-case, for ID and code columns (customer_id, product_id, employee_id, ...),
    so keys match across sources whatever case the source used.
-#}
{% macro clean_code(col) -%}
    upper({{ clean_text(col) }})
{%- endmacro %}
