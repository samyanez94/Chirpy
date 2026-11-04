#!/bin/sh
set -eu

# Only the local container is used; no hosted credentials or database URLs.
chirpy_backend_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for chirpy_test in "$chirpy_backend_dir"/tests/*.sql; do
  printf 'Running %s\n' "$(basename "$chirpy_test")"
  docker exec -i supabase_db_chirpy \
    psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -q < "$chirpy_test"
done
printf 'All SQL integration tests passed.\n'
