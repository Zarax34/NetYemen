-- WASEL NET wallet balance reconciliation audit.
--
-- OD-WALLET-01 binds the platform to a cached balance column
-- (public.wallet_accounts.cached_balance) maintained by the trusted
-- update_wallet_account_balance() trigger, on the explicit condition that the
-- cache is backed by a recurring ledger reconciliation audit. This script is
-- that audit.
--
-- READ ONLY. It never repairs drift: a cached balance that disagrees with the
-- immutable ledger is a financial integrity incident and must be investigated,
-- not silently corrected.
--
-- Ledger sign convention (see update_wallet_account_balance): DEBIT decreases
-- the balance; CREDIT and REVERSAL increase it.

BEGIN;
SET TRANSACTION READ ONLY;

DO $$
DECLARE
    v_drifted        BIGINT;
    v_orphaned       BIGINT;
    v_bad_running    BIGINT;
    v_negative       BIGINT;
    v_ambiguous      BIGINT;
    v_example        TEXT;
BEGIN
    IF to_regclass('public.wallet_accounts') IS NULL
       OR to_regclass('public.customer_wallet_ledger') IS NULL THEN
        RAISE EXCEPTION
            'HOLD: wallet reconciliation requires the commerce core migration.';
    END IF;

    -- 1. Cached balance must equal the ledger-derived balance for every account.
    WITH ledger_totals AS (
        SELECT
            user_id,
            SUM(
                CASE WHEN entry_type = 'DEBIT' THEN -amount ELSE amount END
            )::BIGINT AS derived_balance
        FROM public.customer_wallet_ledger
        GROUP BY user_id
    )
    SELECT
        count(*),
        min(
            format(
                'user %s: cached=%s derived=%s',
                wa.user_id, wa.cached_balance, COALESCE(lt.derived_balance, 0)
            )
        )
    INTO v_drifted, v_example
    FROM public.wallet_accounts wa
    LEFT JOIN ledger_totals lt ON lt.user_id = wa.user_id
    WHERE wa.cached_balance <> COALESCE(lt.derived_balance, 0);

    IF v_drifted > 0 THEN
        RAISE EXCEPTION
            'HOLD: % wallet account(s) drifted from the ledger. First: %',
            v_drifted, v_example;
    END IF;

    -- 2. Ledger entries must not exist for a user without a wallet account.
    SELECT count(DISTINCT cwl.user_id)
    INTO v_orphaned
    FROM public.customer_wallet_ledger cwl
    LEFT JOIN public.wallet_accounts wa ON wa.user_id = cwl.user_id
    WHERE wa.user_id IS NULL;

    IF v_orphaned > 0 THEN
        RAISE EXCEPTION
            'HOLD: % user(s) hold ledger entries with no wallet account.',
            v_orphaned;
    END IF;

    -- 3. balance_after must agree with the running ledger balance.
    --
    --    customer_wallet_ledger has no monotonic sequence column, so created_at
    --    is the only ordering signal and entries written inside one transaction
    --    share it exactly. Ordering such a tie group by a random UUID would
    --    manufacture false drift, so the invariant is enforced per timestamp
    --    group: the cumulative balance at the end of each group must be recorded
    --    by one of the entries in that group. Groups holding a single entry --
    --    the normal case -- are therefore checked exactly. v_ambiguous reports
    --    how many entries could only be checked at group granularity.
    WITH grouped AS (
        SELECT
            user_id,
            created_at,
            count(*) AS entries_at_instant,
            SUM(
                CASE WHEN entry_type = 'DEBIT' THEN -amount ELSE amount END
            ) AS group_delta,
            array_agg(balance_after) AS balances_at_instant
        FROM public.customer_wallet_ledger
        GROUP BY user_id, created_at
    ), cumulative AS (
        SELECT
            user_id,
            created_at,
            entries_at_instant,
            balances_at_instant,
            SUM(group_delta) OVER (
                PARTITION BY user_id
                ORDER BY created_at
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS running_balance
        FROM grouped
    )
    SELECT
        COALESCE(SUM(entries_at_instant) FILTER (
            WHERE NOT (running_balance = ANY (balances_at_instant))
        ), 0),
        COALESCE(SUM(entries_at_instant) FILTER (WHERE entries_at_instant > 1), 0)
    INTO v_bad_running, v_ambiguous
    FROM cumulative;

    IF v_bad_running > 0 THEN
        RAISE EXCEPTION
            'HOLD: % ledger entr(ies) record a balance_after that disagrees with the running ledger balance.',
            v_bad_running;
    END IF;

    -- 4. No account may be negative (defence in depth behind the CHECK constraint).
    SELECT count(*) INTO v_negative
    FROM public.wallet_accounts
    WHERE cached_balance < 0;

    IF v_negative > 0 THEN
        RAISE EXCEPTION 'HOLD: % wallet account(s) hold a negative balance.', v_negative;
    END IF;

    RAISE NOTICE
        'WALLET RECONCILIATION PASS: cached balances, running balances, account coverage, and non-negativity all agree with the ledger.';

    IF v_ambiguous > 0 THEN
        RAISE NOTICE
            'NOTE: % ledger entr(ies) share a created_at with another entry for the same user and were verified at timestamp-group granularity.',
            v_ambiguous;
    END IF;
END;
$$;

SELECT
    'PASS'::TEXT                                              AS decision,
    (SELECT count(*) FROM public.wallet_accounts)             AS wallet_accounts,
    (SELECT count(*) FROM public.customer_wallet_ledger)      AS ledger_entries,
    (SELECT COALESCE(SUM(cached_balance), 0)
       FROM public.wallet_accounts)                           AS total_cached_balance;

ROLLBACK;
