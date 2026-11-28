{#-
    row_count_equals(model, expected)
    Fails (returns one row) when the model's row count differs from `expected`.
    Expected counts come from docs/data_issues.md or a profiling query (never estimated).
    Usage in YAML (model level):
        data_tests:
          - row_count_equals:
              arguments:
                expected: 2000
-#}
{% test row_count_equals(model, expected) %}

select
    count(*)            as actual_rows,
    {{ expected }}      as expected_rows
from {{ model }}
having count(*) <> {{ expected }}

{% endtest %}
