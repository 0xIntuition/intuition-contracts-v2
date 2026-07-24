# One Dollar Audit — pre-audit AI round (extends the Opus/GPT handoff)

This directory adds **[One Dollar Audit](https://www.onedollaraudit.com/)** (ODA) as another independent reviewer in the
pre-audit pseudo-audit round described in [`ai-pseudo-audit-handoff-v1.1.0.md`](../ai-pseudo-audit-handoff-v1.1.0.md).
Same posture (first-principles, adversarial, same report template) — different reviewer, and, unlike the Opus/GPT
rounds, **scoped strictly to what is currently in open PR #153**, not the whole suite.

## What One Dollar Audit is (research summary)

- **A $1, autonomous AI audit.** Operated by LeftClaw Services. You commission a job over HTTP, an AI agent (on-chain
  identity: agent `#21548`) reviews it and files a report, typically within the hour. It explicitly bills itself as _"a
  serious first pass, not a substitute for a full manual audit on high-TVL systems"_ — so we treat it exactly like the
  low-cost breadth round, not like the frontier round.
- **Endpoint:** `POST https://leftclaw.services/api/audit`. Body is JSON:
  `{ description (required, ≥10 chars), context (optional), callbackUrl (optional https webhook) }`.
- **Input is a contract address _or_ pasted source.** Our contracts deploy to the Intuition chain (1155 / 13579),
  **not** Base/Etherscan, so the "verified address" path does not apply — we must **paste source**. The repo is public,
  so pasting source (and linking GitHub) leaks nothing.
- **Payment is x402 / gasless.** The first POST returns `402` with a `payment-required` challenge; the client signs an
  **EIP-3009 `TransferWithAuthorization`** for **1 USDC on Base** (asset `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`,
  payTo `0xCfB32a7d01Ca2B4B538C83B2b38656D3502D76EA`) and retries with the signed header. A facilitator submits it
  on-chain, so **the payer pays no gas** — the wallet only needs USDC.
- **Async result.** The POST returns `{ jobId, jobUrl, statusUrl }`. Poll
  `GET https://onedollaraudit.com/api/jobs/<jobId>` →
  `{ status, stage, reportUrl (IPFS), reportHtmlUrl, pollIntervalSeconds }`, or pass a `callbackUrl` to have completion
  POSTed to you.
- **One contract / tightly-integrated system per job.** Complex protocols need multiple jobs — which is why we fan out
  one job per in-scope contract.
- **The description is public on-chain.** Fine here (public repo); never paste anything sensitive.

## The scope guarantee (this is the important part)

Scope is **computed from the live PR**, never hardcoded: `gh pr view 153 --json files` → keep `src/**/*.sol` → drop the
out-of-scope denylist (handoff §3: bridge/MetaLayer transport, Base-chain components, migration mode, legacy
`Trust`/`VotingEscrow`, the progressive-curve family) → interfaces & folded libraries become **context**, everything
else is a **primary** review target. Each job's description hard-locks the auditor to _"review only the pasted file(s),
pinned to commit `<sha>`; PR #153, not `main`, not the whole suite."_

Because it reads the PR every run, it tracks PR #153 as it evolves. If a new in-scope contract lands (e.g.
`DynamicFeeFlatPriceCurve` or the FeeProxy follow-up commit — **neither is in the PR as of the pinned commit**), the
planner flags it as **drift** so we add curated context and never silently skip it.

Current plan (13 in-scope primaries): `MultiVault`, `MultiVaultCore`, `MultiVaultLib`, `BondingCurveRegistry`,
`BaseCurve`, `LinearCurve`, `AtomWallet`, `AtomWalletFactory`, `AtomWarden`, `TrustBonding`, `CoreEmissionsController`,
`SatelliteEmissionsController`, `FeeProxy`.

## Run it — the one manual gate

Everything is automated **except funding a wallet**, which only you can do:

1. **Fund a Base wallet with USDC.** ~$13 for per-file (13 jobs) or ~$7 for clustered (7 jobs). No ETH needed (x402 is
   gasless). Use a throwaway hot wallet — its key goes in an env var.
2. **Preview first (spends nothing):**
   ```bash
   npx tsx script/audits/oda-scope.ts            # print the scope plan
   npx tsx script/audits/oda-run.ts              # dry-run: writes every job's exact description
   ```
   Inspect `reports/dry-run/*.txt` — that is byte-for-byte what each job will submit.
3. **Install the x402 client (once):**
   ```bash
   bun add -d @x402/fetch @x402/evm viem
   ```
4. **Go live:**
   ```bash
   ODA_PRIVATE_KEY=0xYOUR_FUNDED_BASE_KEY npx tsx script/audits/oda-run.ts --live --yes
   # add --clustered for 7 bigger jobs instead of 13 focused ones
   # add --only <id>   (e.g. --only feeproxy) to run a single contract
   ```
   It pays $1, creates each job, **writes the manifest before polling** (a crash never loses a paid job), then polls
   until each is `complete` and saves the report.

Reports land in `reports/<jobId>/` (`report.md`, `report.html`, `job.json`); the id map is `reports/manifest.json`.
**Idempotent:** a job already in the manifest for the same commit is skipped, so re-running to resume polling never
double-pays. Ctrl-C is safe — re-run to resume.

### Env / flags

| Var / flag                           | Purpose                                                              |
| ------------------------------------ | -------------------------------------------------------------------- |
| `ODA_PRIVATE_KEY`                    | Funded Base wallet (USDC), single signer. **Required for `--live`.** |
| `ODA_CALLBACK_URL`                   | Optional https webhook; ODA POSTs the completed report to it.        |
| `ODA_COMMIT` / `ODA_PR` / `ODA_REPO` | Override the pinned commit / PR number / repo slug.                  |
| `ODA_ENDPOINT` / `ODA_IPFS_GATEWAY`  | Override the audit endpoint / IPFS gateway.                          |
| `--clustered`                        | 7 system-level jobs instead of 13 per-file jobs.                     |
| `--only <id>`                        | Run a single job (ids printed by `oda-scope.ts`).                    |
| `--live --yes`                       | Actually spend USDC. Without both, it stays a dry-run.               |

## Per-file vs clustered

**Per-file (default)** gives each contract a dedicated $1 pass and keeps every description under the size guard (largest
is `MultiVaultLib` at ~68 KiB). **Clustered** is cheaper but the MultiVault system job is ~122 KiB and may exceed ODA's
input limit — the pinned GitHub permalink in every description is the fallback so the auditor can always pull
authoritative full source. Prefer **per-file**.

## Caveats

- ODA is a **breadth reviewer**, not the frontier round. Fold its output into the same triage / found→fixed log; a
  finding it reaches independently is high signal, but do not treat a clean pass as clearance.
- It runs **its own methodology** — we only constrain **scope** (PR #153) and request the report **template**; we can't
  force exact schema compliance, so normalize during triage.
- Same constraints as the handoff: **no AI attribution**, describe issues **by mechanism only** (no ticket ids / person
  names), full 40-hex addresses, and treat every output as a **pre-audit artifact** — not a formal audit.
