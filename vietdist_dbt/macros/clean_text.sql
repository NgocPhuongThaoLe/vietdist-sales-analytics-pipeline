{#-
    clean_text(col)
    Shared text cleaning for every staging model (replaces the copy-pasted CASE in
    sql/silver/stg_sales_transactions.sql, docs/pain_points.md #6).
    - fake nulls: trimmed '', 'nan', 'NaN', 'None' -> NULL (guard: raw already stores blanks as NULL)
    - otherwise trim + Unicode NFC (README §I.C: visually equal Vietnamese text must match in joins)
    Vietnamese values keep their diacritics and case.
-#}
{% macro clean_text(col) -%}
    case
        when trim({{ col }}) in ('', 'nan', 'NaN', 'None') then null
        else normalize(trim({{ col }}), NFC)
    end
{%- endmacro %}
