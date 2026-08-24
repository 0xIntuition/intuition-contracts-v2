# Dynamic-fee curve review

Review target: `330980a6e2cad0aa602b5d11c961b75f2236a690` (`feat/v1.1.0-core-upgrade`)  
Review date: 2026-08-23  
Primary scope: `DynamicFeeFlatPriceCurve`, its `IBaseCurve` integration through `MultiVaultLib`, the 13-tier deploy
seed, and the deposit/redeem/claim economy.

This is an internal code and economic-design review, not an external audit or a safety guarantee.

## Outcome

The accounting core is coherent: fees withheld by `MultiVault` are forwarded unchanged, principal remains in the 1:1
vault, curve obligations remain solvent, and the curve-side share ledger follows the vault ledger. The targeted current
suite passed 128 tests, including 10,000-case fuzz properties, the 13-tier fixture, integration tests, adversarial
economics, stateful invariants, and gas profiles.

One new code defect was confirmed:

- **DF-01 — Medium:** `depositGrowthBps` and `withdrawalGrowthBps` accept arbitrary `uint256` values, but the capped fee
  getter multiplies before it clamps. A configuration accepted by `setConfig` can therefore panic in tier 1 or above and
  temporarily halt affected deposits or redeems.

One material documentation defect was confirmed:

- **DF-02 — Low:** `docs/call-flows/dynamic-fee-curve.md` still describes the pre-replay economics in several places.
  Its worked fee, source-tier routing, and depositor-exclusion statements disagree with current code and tests.

The main remaining questions are economic decisions, not accounting failures:

- A two-address actor can recover essentially all curve-level deposit and withdrawal fees in a controlled arrangement.
  Current end-to-end washes remain negative because separate `MultiVault` fees still leak value, but the dynamic fee is
  not itself an anti-wash barrier.
- `minEligibleTierStake` ships disabled (`0`), preserving the ability of very small tier cohorts to capture whole
  kernel-weighted slices.
- Holder buckets are sticky through drawdowns and ladder retunes. That deliberately causes temporary earning blackouts
  and protocol accrual when every holder bucket sits above the vault.
- Quote traversal and record-time distribution traverse different net amounts because `MultiVault` fees are invisible to
  `quoteDepositFee`. Conservation holds, but near a boundary the fee can be distributed from a different set of bands
  than the set used to price it.

The average-atom extension found a more fundamental product-fit question:

- At the production tier-3/tier-4 settings, an ordinary atom deposit retains about 95.25%/94.75%, and a no-reward flat
  round trip loses about 9.99%/10.94% before gas.
- A holder recorded in the current source-tier bucket earns no deposit fees from activity that remains in that tier. In
  the ordinary same-band case, an atom that stalls at tier 3 or tier 4 leaves its frontier users paying the largest fee
  seen so far without earning until the atom advances again.
- `MultiVault.previewRedeem` is not holder-accurate for the dynamic curve even though execution already uses an internal
  account-aware calculation.
- Live ladder-geometry retunes redefine bucket meaning across every atom without migrating positions.

## Important tier-count clarification

The deploy seed has `tierCount = 13`, which means valid indexes are **tier 0 through tier 12**. Tier 12 is terminal and
unbounded. **Tier 13 does not exist.** If the product requirement literally needs tiers 0 through 13, the configuration
must use `tierCount = 14`; that would turn today's terminal tier 12 into a bounded tier and make tier 13 terminal.

## Documents

1. [`01-mechanics-and-lifecycle.md`](./01-mechanics-and-lifecycle.md) — first-principles formulas, 13-tier production
   table, end-to-end deposit/redeem/claim flows, and fee routing.
2. [`02-up-down-scenarios.md`](./02-up-down-scenarios.md) — linear climbs, multi-band deposits, drawdowns, recoveries,
   re-deposits, terminal-tier behavior, and retunes.
3. [`03-findings-and-decisions.md`](./03-findings-and-decisions.md) — audit finding write-ups and explicit pre-launch
   economic decisions.
4. [`04-verification.md`](./04-verification.md) — invariants, executed tests, independent calculations, and coverage
   limits.
5. [`05-average-atom-model.md`](./05-average-atom-model.md) — production-scale 1k–10k TRUST simulations, stalled
   tier-3/tier-4 cohort economics, dollar-budget translation, and up/down hysteresis.
6. [`06-pre-audit-product-decisions.md`](./06-pre-audit-product-decisions.md) — first-principles product assessment, new
   UX/governance findings, mechanism choices, and prioritized pre-audit changes.
7. [`07-variable-naming-alignment-proposal.md`](./07-variable-naming-alignment-proposal.md) — line-specific core naming
   proposal, canonical asset/share lifecycle vocabulary, ABI impact, and the recommended pre-deployment rename package.

## Recommended pre-launch actions

1. Fix DF-01 with overflow-safe saturating fee math and add regression tests for both fee schedules.
2. Update the existing call-flow document to the current grossed-up quote plus per-band replay model.
3. Obtain explicit sign-off that the dynamic fee may be recovered across controlled addresses and that
   `minEligibleTierStake = 0` is the desired launch setting.
4. Decide whether 13 tiers means 13 total tiers (`0..12`, current code) or a highest index of 13 (`0..13`, 14 total).
5. Treat any ladder retune as an economic migration event, with simulation against live bucket occupancy before the
   timelocked transaction is proposed.
6. Decide whether frontier users are intentionally ineligible until the next tier. If stable tier-3/tier-4 users are
   meant to earn from ordinary activity, redesign the charging/distribution rule before audit.
7. Add a generic account-aware, full-stack redeem preview to `MultiVault`; the holder-aware calculation already exists
   internally.
8. Make ladder geometry immutable after initialization, or require a new curve ID for a new ladder.
9. Define an explicit maximum entry and no-reward round-trip cost for the $20–$100 target user, then retune bps to that
   constraint.
10. Commit production-config full-stack lifecycle and adversarial P&L tests around 1k–10k TRUST users and tier-3/tier-4
    atoms.
