# WASEL NET / NetYemen — Owner Decision Sign-Off Package 01

**Task ID:** NY-V1-CLAUDE-COMPLETION-002
**Companion to:** `docs/NETYEMEN-DECISION-REGISTER-01.md`
**Prepared:** 2026-09-05
**Status:** AWAITING OWNER SIGNATURE — no entry below is approved.

---

## Why this document exists

Seven of the eleven register decisions were approved by `OWNER` on 2026-08-08.
Four remain `OPEN_DECISION`. This package is the sign-off sheet for those four.

It exists because an approval must come from the project owner and from nobody
else. An earlier implementation track in this repository self-granted approval
of the register while acting as "Human Product Lead"; that track was closed
precisely for that reason (see
`docs/reports/NY-V1-CLAUDE-SESSION-HANDOFF-001-REPORT.md`, Part A). **No agent,
contractor, or automated process may mark any row below as approved.** The
owner writes the decision, the date, and their name; only then may the register
be updated.

For each decision this package adds something the register does not have: what
the shipped code *already does*. Three of the four decisions are, in practice,
already bound by the implementation. Signing them is therefore ratification of
an existing state — and choosing the alternative now carries a rework cost that
is stated explicitly.

---

## OD-AUTH-01 — SMS OTP gateway provider

| Field | Value |
|---|---|
| Register recommendation | Option A — ALAWAEL SMS API via Edge Function |
| What the code does today | `SupabaseService.signInWithOtp(phone:)` / `verifyOTP()` — Supabase Auth's built-in OTP delivery, with **no Yemeni gateway configured**. Pilot testers are onboarded through a separate controlled phone/password path (`test_onboarding_applications`, migration `20260821090000`), which does not exercise SMS at all. |
| Bound in code? | **No.** The provider is a configuration choice, not a schema choice. |
| What signing unlocks | Real customer onboarding outside the invited pilot. Until a gateway is selected and funded, every new user must be onboarded by hand. |
| Cost of each option | Option A: one Edge Function plus retry handling; lowest per-message cost on Yemen Mobile / MTN / Sabafon. Option B: no code, higher per-message cost, and international routes to Yemen are frequently blocked. Option C: both, plus two subscriptions. |
| Engineering note | This is the only one of the four that genuinely blocks public launch. It needs a commercial contract, not a code change. |

**Owner decision:** ______________________  **Date:** ____________  **Name:** ____________

---

## OD-PRIV-01 — Data retention and anonymization

| Field | Value |
|---|---|
| Register recommendation | Option A — 5-year financial retention, immediate profile anonymization on deletion |
| What the code does today | `account_deletion_requests` (migration `20260822200000`) with forced RLS, an `ACCOUNT_DELETION_REQUESTED` audit event, the guarded `request_my_account_deletion` RPC, in-app screens, and a hosted public deletion page. The **request and audit** half of Option A is built. The **scheduled anonymization and 5-year purge** half is not: no retention job exists in the repository. |
| Bound in code? | **Partly.** The deletion request pipeline assumes an Option A-shaped policy. |
| What signing unlocks | The retention job can be written against a fixed duration. It also fixes what the published privacy page promises, which Google Play requires to be accurate. |
| Cost of each option | Option A: needs a scheduled anonymization task. Option B (indefinite): contradicts the deletion flow already shipped and the published privacy page. Option C (1 year): too short to settle a wallet dispute or an owner settlement audit. |
| Engineering note | Ledger rows must never be hard-deleted under any option; anonymization operates on `profiles` PII, not on `customer_wallet_ledger`. |

**Owner decision:** ______________________  **Date:** ____________  **Name:** ____________

---

## OD-ARCH-01 — Admin portal technology stack

| Field | Value |
|---|---|
| Register recommendation | Option 1 — React + Vite + Tailwind + shadcn/ui |
| What the code does today | **Option 3.** The admin console is Flutter Web: `lib/admin_main.dart` (`AdminConsoleApp`), built in CI by `flutter build web --target lib/admin_main.dart` and published as the `admin-web-console` artifact. It builds cleanly and covers card-vault ingest, deposit review, identity operations, and onboarding review. |
| Bound in code? | **Yes — and it contradicts the register.** The register calls Option 3 a poor choice (bundle size, desktop table UX, accessibility); the implementation shipped it anyway. |
| What signing unlocks | Either ratify Option 3 and amend the register's recommendation to match reality, or fund a React rewrite. |
| Cost of each option | Ratifying Option 3: zero — it is already built and green in CI. Switching to Option 1: a full rewrite of every admin screen plus a second deployment target and a second auth integration; the Supabase RPC surface itself would not change. |
| Engineering note | This is the widest gap between the register and the codebase. Leaving it unsigned means the shipped admin portal has no governing decision behind it. |

**Owner decision:** ______________________  **Date:** ____________  **Name:** ____________

---

## OD-WALLET-01 — Wallet balance storage

| Field | Value |
|---|---|
| Register recommendation | Option A — cached column maintained by a trusted trigger, backed by a recurring reconciliation audit |
| What the code does today | **Option A.** `wallet_accounts.cached_balance INTEGER NOT NULL DEFAULT 0` with `chk_wallet_accounts_balance_non_negative`, updated only by the `SECURITY DEFINER` trigger `update_wallet_account_balance()` on `customer_wallet_ledger` (DEBIT decreases; CREDIT and REVERSAL increase). |
| Bound in code? | **Yes.** |
| Audit condition | The register makes Option A conditional on "a daily automated ledger balance reconciliation audit script". **No such audit existed.** It has now been added as `supabase/verification/020_wallet_balance_reconciliation.sql` and runs in CI. It is read-only and never repairs drift, because a cache that disagrees with the immutable ledger is an incident, not a rounding error. |
| Cost of each option | Ratifying Option A: zero; the safeguard now exists and must be scheduled to run daily against production. Switching to Option B (live `SUM`): rewrite of the balance read path, `purchase_package`, and the deposit approval path, plus a `SUM` over the ledger inside every purchase's locking window. |
| Known schema limitation | `customer_wallet_ledger` has no monotonic sequence column, so entries written inside one transaction share `created_at` and have no defined order. The reconciliation audit checks those groups at timestamp granularity and reports how many entries were affected. Adding `entry_seq BIGSERIAL` would let every entry be checked exactly; that is a migration, so it is left to the owner. |

**Owner decision:** ______________________  **Date:** ____________  **Name:** ____________

---

## After signing

1. Update the status table in `docs/NETYEMEN-DECISION-REGISTER-01.md` (rows move
   from the `OPEN_DECISION` table to the approved table, with approver and date).
2. Append one row per decision to that document's Change Log.
3. Where a signature contradicts the shipped code (most likely OD-ARCH-01), open
   the rework as its own task — do not let the register and the codebase drift
   apart silently a second time.
