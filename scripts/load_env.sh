#!/usr/bin/env bash
# Load .env into the current shell (needed by dbt, which does not read .env).
# Run from the project root:  source scripts/load_env.sh
if [ ! -f .env ]; then
    echo ".env not found in $(pwd). Run from the project root, or copy .env.example to .env first." >&2
    return 1 2>/dev/null || exit 1
fi
set -a
# shellcheck disable=SC1091
source .env
set +a
echo "Loaded .env into this shell."
