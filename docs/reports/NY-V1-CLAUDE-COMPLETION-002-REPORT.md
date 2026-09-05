# NetYemen / WASEL NET — V1 Completion & Independent Verification Report

**Task ID:** NY-V1-CLAUDE-COMPLETION-002
**Repository:** Zarax34/NetYemen (clone of msorori-mh/NetYemen)
**Branch:** `claude/review-session-report-wwyjjp` (off `kimi/NY-V1-EXTERNAL-PILOT-BINDING-001`)
**Date:** 2026-09-05
**Predecessor:** `NY-V1-CLAUDE-SESSION-HANDOFF-001-REPORT.md`

## Executive summary

Both CI gates were executed end to end against this branch — the first time
either has run for this clone, which had zero workflow runs. The backend suite
(20 migrations, 19 SQL contract/E2E files) and the Flutter suite (158 tests,
`flutter analyze`, formatting, locked dependencies, admin web build) all pass.

Two defects were found and fixed, one of them a security gate that had been
passing vacuously. One safeguard the decision register requires but nobody had
built — the wallet ledger reconciliation audit — was written, proven against
injected corruption, and wired into CI.

What remains cannot be closed by engineering: four governance decisions need the
owner's signature, and the release hold needs a physical Android device. Both
are documented below with exactly what is required.

---

## 1. Verification performed

No Docker daemon and no Supabase CLI are available in this environment, so the
backend gate was reproduced on a native PostgreSQL 16 cluster behind a minimal
platform shim. Two new files make this repeatable:

| File | Purpose |
|---|---|
| `supabase/harness/supabase_local_shim.sql` | The minimum Supabase surface the migrations depend on: `anon`/`authenticated`/`service_role`/`supabase_admin` roles, the `auth` schema with `users` and `identities`, `auth.uid()`/`role()`/`jwt()`/`email()` with the platform's exact claim semantics, and the `supabase_migrations.schema_migrations` ledger the production verifiers gate on. |
| `scripts/run_local_sql_suite.sh` | Provisions a disposable cluster, applies the shim, applies every migration in order while recording each version in the ledger, then runs every contract test and the post-migration verifiers. |

### Backend result

```
==> Applying migrations                     20/20 applied
==> Running SQL contract and E2E suite
    [PASS] 001_core_schema_contract.sql        [PASS] 011_notifications_engagement.sql
    [PASS] 002_core_authorization_positive.sql [PASS] 012_support_complaints_disputes.sql
    [PASS] 003_core_authorization_negative.sql [PASS] 013_commerce_core.sql
    [PASS] 004_core_invariants.sql             [PASS] 014_v1_integrated_pilot_e2e.sql
    [PASS] 005_network_discovery_and_requests  [PASS] 015_v1_external_pilot_auth_and_crypto
    [PASS] 006_final_hold_remediation_verif.   [PASS] 016_test_phone_password_onboarding
    [PASS] 007_packages_and_inventory.sql      [PASS] 017_admin_test_onboarding_review
    [PASS] 008_admin_operations.sql            [PASS] 018_account_deletion_requests.sql
    [PASS] 009_client_truncate_acl_hardening   [PASS] 019_hosted_admin_review_verifiers
    [PASS] 010_operational_closure.sql
==> Running production verification post-conditions
    [PASS] 018_account_deletion_production_postverify.sql
    [PASS] 020_wallet_balance_reconciliation.sql
```

Three verification scripts are deliberately skipped by the local runner, with the
reason printed: the two `017_hosted_admin_review_*` scripts assert the terminal
state of TEST_ONLY identities that exist only in the hosted project after a human
admin has reviewed them, and `018_account_deletion_production_preflight.sql`
asserts pre-migration state by design. CI skips them for the same reason.

### Flutter result (SDK pinned to CI's 3.38.7)

| Gate | Result |
|---|---|
| `flutter pub get --enforce-lockfile` | Resolved; `pubspec.lock` unchanged afterwards |
| `dart format lib test` | 167 files, 0 changed |
| `flutter analyze` | **No issues found** |
| `flutter test` | **158 tests, all passed** (34 test files) |
| `flutter build web --target lib/admin_main.dart` | Built `build/web` |

The Node public-legal gate was also run in full: syntax checks, verifier
self-test (`PASS`), artifact generation, no unsubstituted `{{PLACEHOLDER}}`
tokens, and `request_my_account_deletion` present in the generated client.

The Android app-bundle build is the one CI step not reproduced locally: no
Android SDK is installed in this environment. It is covered by the CI run below.

### Static security gates

`scripts/*.ps1` require PowerShell, which is unavailable here, so each scan's
logic was re-executed directly against the same sources:

| Gate | Result |
|---|---|
| Secret / key prohibition (JWTs, 16-digit numbers, hardcoded passwords & API keys) | PASS — 0 matches |
| Card secret prohibition (OD-CARD-01) | PASS — 178 files scanned, 0 matches |
| Release readiness (SDK pinning, fail-closed signing, legal URLs, deletion RPC binding, forced RLS, hosted page templates) | PASS — 0 violations |

### CI result on the pushed branch

The push of this work produced the **first two workflow runs this repository has
ever had**. Both are green.

`NetYemen Supabase Core CI` — [run 33962592630](https://github.com/Zarax34/NetYemen/actions/runs/33962592630),
14/14 steps, including the new `Verify Wallet Ledger Reconciliation
(OD-WALLET-01)` step. The static verification step confirms the card-secret gate
fix on the runner itself:

```
NetYemen Card Secret Prohibition Scan
Scanning 179 source file(s) under /home/runner/work/NetYemen/NetYemen
RESULT: PASS (no plaintext card/voucher secrets detected)
```

That file count is the evidence: before the fix the same step reported PASS
having scanned nothing. The secret, financial-invariant, and FCM-credential
scans also pass.

`Flutter CI` — [run 33962592613](https://github.com/Zarax34/NetYemen/actions/runs/33962592613),
16/16 steps: locked dependencies, formatting, analysis, release-readiness guards,
the public-legal generator, the test suite, the **Android release app bundle**,
and the admin web console artifact.

---

## 2. Defects found and fixed

### 2.1 The card-secret security gate was scanning zero files

`scripts/scan_netyemen_card_secrets.ps1` hardcoded its scan root:

```powershell
$searchRoot = "C:/projects/NetYemen-kimi-commerce"
```

That is an author's local Windows path. On the `ubuntu-latest` CI runner it does
not exist, and both `Get-ChildItem` calls carry `-ErrorAction SilentlyContinue`,
so `$allFiles` came back empty, the violation loop never executed, and the script
exited `0`. **The gate enforcing OD-CARD-01 — the most critical approved security
decision in the register — has been reporting PASS without inspecting a single
file.** Every other script in `scripts/` derives its root from `$PSScriptRoot`;
this one alone did not.

Fixed by deriving the root the same way, and by making an empty file set a hard
failure rather than a silent pass — a scan that inspects nothing must never
report PASS. Re-running the scan's patterns over all 178 SQL and Dart files
confirms the prohibition genuinely holds, so the fix does not turn CI red.

### 2.2 Sub-scan paths broke on non-Windows runners

`scripts/verify_netyemen_commerce_v1.ps1` composed its three sub-scan paths with
a literal backslash (`"$scriptDir\scan_netyemen_secrets.ps1"`). Replaced with
`Join-Path`, which is correct on every platform.

### 2.3 CI could never run in this clone

`supabase-core-ci` triggered on pushes to `antigravity/*`, `kimi/*`, `codex/*`
and PRs into `main`; `flutter-ci` only on `main` and PRs into `main`. A clone
with no pull requests therefore produced no CI evidence at all — matching the
observed `total_count: 0`. Both workflows now also trigger on `cursor/*` and
`claude/*` branches and accept `workflow_dispatch`.

---

## 3. Missing safeguard, now built: wallet ledger reconciliation

`OD-WALLET-01`'s recommended option — a cached balance column maintained by a
trigger — is explicitly conditional on "a daily automated ledger balance
reconciliation audit script". The implementation shipped the cached column
(`wallet_accounts.cached_balance`, maintained by `update_wallet_account_balance()`)
but the audit was never written.

`supabase/verification/020_wallet_balance_reconciliation.sql` is that audit. It
is read-only and never repairs drift, because a cache disagreeing with an
immutable ledger is a financial incident, not a rounding error. It asserts:

1. every `cached_balance` equals its ledger-derived balance (DEBIT negative;
   CREDIT and REVERSAL positive, matching the trigger's own sign convention);
2. no user holds ledger entries without a wallet account;
3. every entry's `balance_after` equals the running ledger balance at that entry;
4. no account is negative.

It was proven in both directions against a seeded cluster: it passes on
consistent data, and it detects an injected cache drift
(`cached=99999 derived=700`), a corrupted mid-ledger `balance_after`, and a
scrambled entry order. It now runs in CI as its own step.

**Schema limitation found while building it.** `customer_wallet_ledger` has no
monotonic sequence column. `created_at` is the only ordering signal, and entries
written inside a single transaction share it exactly, so their relative order is
undefined — ordering such a group by its random UUID primary key would
manufacture false drift. Check 3 therefore enforces the invariant per timestamp
group and reports how many entries could only be checked at that granularity;
single-entry groups, which is the normal case, are checked exactly. Adding
`entry_seq BIGSERIAL` would make every entry checkable exactly. That is a
migration against a live financial table, so it is left to the owner rather than
taken unilaterally.

---

## 4. What is left, and who must do it

### 4.1 Four governance decisions — owner signature required

`docs/NETYEMEN-OWNER-DECISION-SIGNOFF-PACKAGE-01.md` is a sign-off sheet for
`OD-AUTH-01`, `OD-PRIV-01`, `OD-ARCH-01`, and `OD-WALLET-01`. For each it records
what the shipped code already does, whether the decision is already bound in
code, and the rework cost of choosing otherwise.

**These were deliberately left unsigned.** An earlier track in this repository
was closed for self-granting exactly this approval while acting as "Human Product
Lead"; repeating that would repeat the failure. Two findings from preparing the
package are worth surfacing here:

* **`OD-ARCH-01` contradicts the shipped code.** The register recommends React +
  Vite and calls Flutter Web a poor choice. The admin console that exists and is
  built in CI is Flutter Web (`lib/admin_main.dart`). The shipped admin portal
  currently has no governing decision behind it.
* **`OD-WALLET-01` and `OD-PRIV-01` are already bound in code**, so signing them
  ratifies existing behaviour. `OD-PRIV-01` is half-built: the deletion request,
  audit event, and hosted page exist; the scheduled anonymization and retention
  purge do not.

### 4.2 Release hold — physical device required

`NY-V1-CODEX-CONTINUATION-001-REPORT.md` records the only remaining release hold
as physical external-pilot evidence: a real FCM notification delivered to, opened
on, and correctly routed by an authorized Android device. No later report closes
it, and it cannot be closed from a container — it needs the device, the Firebase
project, and a signing key.

### 4.3 Merge position

`main` is a direct ancestor of the pilot branch (0 behind, 248 ahead), so
`git merge --ff-only` applies cleanly. Performing it is the owner's call and was
not done. See Part C of the handoff report for the measurements.

### 4.4 Optional cleanup

`lib/screens/purchase_success_screen.dart` and `lib/screens/splash_screen.dart`
are unreferenced by any file in `lib/` or `test/`. The rest of `lib/screens/` is
still live (`login_screen.dart` is imported by five feature screens). Left in
place; removal is a judgement call, not a defect.

---

## 5. Files changed in this task

| File | Change |
|---|---|
| `supabase/harness/supabase_local_shim.sql` | New — Docker-free Supabase platform shim |
| `scripts/run_local_sql_suite.sh` | New — full local migration + contract suite runner |
| `supabase/verification/020_wallet_balance_reconciliation.sql` | New — OD-WALLET-01 reconciliation audit |
| `docs/NETYEMEN-OWNER-DECISION-SIGNOFF-PACKAGE-01.md` | New — owner sign-off sheet for the 4 open decisions |
| `scripts/scan_netyemen_card_secrets.ps1` | Fixed hardcoded Windows scan root; empty file set now fails closed |
| `scripts/verify_netyemen_commerce_v1.ps1` | `Join-Path` instead of literal backslashes |
| `.github/workflows/supabase-core-ci.yml` | Triggers on `cursor/*`, `claude/*`, `workflow_dispatch`; runs the reconciliation audit |
| `.github/workflows/flutter-ci.yml` | Triggers on feature branches and `workflow_dispatch` |
| `docs/reports/NY-V1-CLAUDE-SESSION-HANDOFF-001-REPORT.md` | Part C addendum: clone status, merge measurements, corrections |
| `docs/README.md` | Indexed the sign-off package |

No migration was added or altered; the production schema is untouched.
