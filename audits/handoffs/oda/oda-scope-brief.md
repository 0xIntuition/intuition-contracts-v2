# Intuition v1.1.0 — One Dollar Audit brief (pre-audit AI pass)

<!--
  This file is injected VERBATIM as the instruction preamble of every One Dollar
  Audit job commissioned by script/audits/oda-run.ts. Keep it compact — it is
  stored on-chain as part of the job description. The per-job "THIS JOB'S SCOPE"
  section and the pasted source are appended by the runner after this text.
-->

**What this is.** An independent AI security pass commissioned _before_ the external audit. It is **not** a formal
audit, certification, warranty, or guarantee of safety. Reason from **first principles**; do not defer to prior reviews
or to comments in the code.

**Scope — read carefully.** Review **only** the file(s) listed under "THIS JOB'S SCOPE" below. They belong to **open
pull request #153** (`feat/v1.1.0-core-upgrade`) of the public repository `0xIntuition/intuition-contracts-v2`, pinned
to the commit shown. This is the v1.1.0 core upgrade **as it currently exists in PR #153** — **not** `main`, **not** the
entire contract suite, and **not** any contract that is absent from the list. If an in-scope file references a
dependency that is not itself listed, treat that dependency as trusted context (a GitHub link is provided) and keep your
findings on the in-scope file(s). Review each in-scope file **in full** — both the new v1.1.0 surface **and** the
pre-existing functions around it — because an upgrade can silently break a baseline invariant.

**System context.** Solidity 0.8.29, Foundry. Upgradeable via TransparentUpgradeableProxy (never raw ERC-1967). Deploys
to Intuition Mainnet (chain id 1155) and Intuition Testnet (chain id 13579); Intuition-chain only. Privileged actions
are gated by a 4-of-8 Safe acting through two TimelockControllers (3-day delay for parameters, 7-day for upgrades).
**Trusted-admin centralization is an accepted trust assumption:** cleanly separate "a _trusted admin_ can do X" (note
briefly, do not rank as a vulnerability) from "an _unprivileged attacker_ can do X" (this is the target).

**Out of scope — do not file findings against these:** the cross-chain bridge / MetaLayer transport leg; all Base-chain
components; migration-mode contracts (their role is revoked after a one-shot migration); legacy Trust / VotingEscrow /
vendored code; the progressive-curve family (pre-existing, not part of this delta); the deliberately-omitted TVL exit
rate-limiter (its absence is a decision, not a gap); cross-curve counter-stake aggregation (rejected by design — it
would need an unbounded loop on a hot path).

**Mandate.** Assume the in-scope code contains **at least one** fund-loss, mint/burn-imbalance, or trust-boundary bug.
For every concern, produce **either** a concrete exploit path — ordered calls, actors, and values, ideally a Foundry PoC
outline — **or** an explicit, evidenced reason none exists on the surface you reviewed. A clean pass is credible only if
it shows the refutation attempt.

**Load-bearing invariants — try to break each:**

1. **Conservation.** Every credit has a matching debit. No path mints internal shares without receiving assets, or pays
   out native value it never took in. A distributed fee/reward always has exactly one defined home and is never lost or
   double-counted.
2. **Solvency.** The vault always holds enough backing (TRUST at par) to satisfy every share's redemption. A fee/reward
   contract custodies only its redistributed value — principal never sits in it.
3. **Ledger mirror.** Any secondary accounting (curve or per-tier ledgers) stays exactly equal to the vault's share
   balances across every deposit / redeem / retune interleaving.
4. **Price integrity.** Where pricing is flat / 1:1, share price never moves; no rounding path lets a user redeem more
   than they deposited, and no path prices below par.
5. **Upgrade safety.** Upgradeable storage is append-only with correct `__gap` accounting. Any delegatecalled library's
   storage view is byte-exact with its caller's layout (a slot the library writes is the slot the caller reads).
6. **No `msg.value` replay.** In any batched / payable multicall, total native value credited across all sub-calls is
   `<= msg.value`, with no wei double-spent, and transient (EIP-1153) state is cleared on **every** exit path —
   including caught reverts and re-entrant external calls (factories, hooks). Nested value-bearing batches must be
   rejected.

**Severity model (realistic impact first, then likelihood):**

- **Critical** — permissionless / realistically reachable path to direct theft, permanent loss, insolvency, unrestricted
  mint or withdraw, or capture of upgrade/admin control.
- **High** — a core invariant or authorization boundary breaks with severe (not total) impact, or an upgrade path
  corrupts critical state (unsafe storage-layout change, exploitable reentrancy, serious accounting break).
- **Medium** — bounded loss, temporarily stuck funds, realistic griefing/DoS of a funds path, an admin footgun, or a
  spec regression that materially affects users.
- **Low** — limited impact, or weak validation already blocked by another guard.
- **Informational** — docs, hygiene, NatSpec-vs-behavior mismatch, missing non-critical test.

**Required output — package it as a professional report, findings highest-severity first.** Open with a one-paragraph
**executive summary** (scope, what was reviewed, headline result) and a **severity-count table**. Then one block per
finding:

- **Title** with a severity label
- **Description** — the mechanism of the bug
- **Affected code** — `file:line` plus the relevant snippet
- **Proof of concept** — the ordered attacker sequence (setup → calls with values → the assertion that fails, with
  before/after numbers)
- **Impact** — concrete value at risk / who loses what
- **Recommendation** — fix direction
- **Status** — Open

Then a short **"Properties checked"** section: for each invariant you could not break, one line on what you tried and
which guard defended it (negatives are deliverables — they evidence coverage). Describe every issue **by mechanism
only** — no internal ticket ids, no person names. Use full 40-hex `0x…` addresses, never shortened. Close with a
single-line verdict (`PASS` / `FAIL`) for the reviewed file(s). Treat the entire output as a **pre-audit artifact**, not
a formal audit.
