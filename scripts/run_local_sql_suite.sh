#!/usr/bin/env bash
# NetYemen — Docker-free local SQL verification runner
#
# Applies supabase/harness/supabase_local_shim.sql, then every migration in
# supabase/migrations in filename order, then every contract test in
# supabase/tests, then the production verification scripts.
#
# This mirrors the "Supabase Local Authorization & Verification Gates" CI job
# for environments where Docker and the Supabase CLI are unavailable.
#
# Usage:  scripts/run_local_sql_suite.sh [PGDATA_ROOT]
# Requires: PostgreSQL 16 server binaries (initdb, pg_ctl, psql).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PGROOT="${1:-${NETYEMEN_PGROOT:-/var/lib/postgresql/nytest}}"
PGBIN="${NETYEMEN_PGBIN:-/usr/lib/postgresql/16/bin}"
PGPORT="${NETYEMEN_PGPORT:-55432}"
PGUSER_OS="${NETYEMEN_PGUSER_OS:-postgres}"
DBNAME="netyemen_verify"

as_pg() {
  if [ "$(id -u)" = "0" ]; then su "$PGUSER_OS" -c "$1"; else bash -c "$1"; fi
}

psql_run() {
  PGOPTIONS="--client-min-messages=warning" psql \
    -h "$PGROOT/run" -p "$PGPORT" -U postgres -d "$DBNAME" \
    -v ON_ERROR_STOP=1 -q "$@"
}

echo "==> Provisioning disposable cluster at $PGROOT"
rm -rf "$PGROOT"
mkdir -p "$PGROOT/pgdata" "$PGROOT/run"
if [ "$(id -u)" = "0" ]; then chown -R "$PGUSER_OS":"$PGUSER_OS" "$PGROOT"; fi
chmod 700 "$PGROOT/pgdata"

as_pg "$PGBIN/initdb -D $PGROOT/pgdata -U postgres --auth=trust -E UTF8" >/dev/null
as_pg "$PGBIN/pg_ctl -D $PGROOT/pgdata -l $PGROOT/pg.log \
  -o '-p $PGPORT -k $PGROOT/run -c listen_addresses=\"\"' -w start" >/dev/null

cleanup() {
  as_pg "$PGBIN/pg_ctl -D $PGROOT/pgdata -m immediate stop" >/dev/null 2>&1 || true
}
trap cleanup EXIT

createdb -h "$PGROOT/run" -p "$PGPORT" -U postgres "$DBNAME"

echo "==> Applying Supabase platform shim"
psql_run -f "$REPO_ROOT/supabase/harness/supabase_local_shim.sql"

echo "==> Applying migrations"
for migration in "$REPO_ROOT"/supabase/migrations/*.sql; do
  base="$(basename "$migration")"
  version="${base%%_*}"
  name="${base#*_}"
  echo "    - $base"
  psql_run -f "$migration"
  # Record the migration in the CLI ledger, as `supabase db reset` does.
  psql_run -c "INSERT INTO supabase_migrations.schema_migrations (version, name)
               VALUES ('$version', '${name%.sql}')
               ON CONFLICT (version) DO NOTHING;"
done

echo "==> Running SQL contract and E2E suite"
failed=0
for test_file in "$REPO_ROOT"/supabase/tests/*.sql; do
  name="$(basename "$test_file")"
  if psql_run -f "$test_file" >"$PGROOT/${name}.out" 2>&1; then
    echo "    [PASS] $name"
  else
    echo "    [FAIL] $name"
    sed -n '1,25p' "$PGROOT/${name}.out"
    failed=$((failed + 1))
  fi
done

# Only the account-deletion post-verify is a schema-level postcondition that a
# disposable database can satisfy, and it is the one the CI job runs. The other
# three verification scripts are hosted-project operational gates: the two
# preflights assert pre-migration state, and the hosted admin review post-verify
# asserts the terminal state of TEST_ONLY identities that exist only in the
# hosted project after a human admin has reviewed them.
echo "==> Running production verification post-conditions"
for name in 018_account_deletion_production_postverify.sql \
            020_wallet_balance_reconciliation.sql; do
  if psql_run -f "$REPO_ROOT/supabase/verification/$name" >"$PGROOT/${name}.out" 2>&1; then
    echo "    [PASS] $name"
  else
    echo "    [FAIL] $name"
    sed -n '1,25p' "$PGROOT/${name}.out"
    failed=$((failed + 1))
  fi
done
echo "    [SKIP] 017_hosted_admin_review_production_preflight.sql  (hosted-project gate)"
echo "    [SKIP] 017_hosted_admin_review_production_postverify.sql (hosted-project gate)"
echo "    [SKIP] 018_account_deletion_production_preflight.sql     (pre-migration gate)"

if [ "$failed" -ne 0 ]; then
  echo "==> $failed file(s) failed"
  exit 1
fi

echo "==> All migrations, contract tests, and verification scripts passed"
