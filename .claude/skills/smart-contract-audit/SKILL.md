---
name: smart-contract-audit
description: Systematic Solidity smart contract security audit using a 370-item checklist spanning 13 categories (attack patterns, DeFi, integrations, tokens, cross-chain, signatures, etc.). Use whenever the user asks to audit, review, find bugs in, or assess the security of Solidity/EVM smart contracts, or mentions solidit, slither findings, Code4rena/Sherlock/Cyfrin style review, reentrancy, oracle manipulation, access control review, or wants a checklist-driven review of a protocol. Trigger even when the user only provides a contract file and asks "is this safe?" or "any issues?".
---

# Smart Contract Security Audit

Drive a rigorous, checklist-anchored security review of Solidity/EVM smart contracts. The checklist is a curated distillation of real findings from Solodit (Code4rena, Sherlock, Cyfrin, Spearbit, etc.). Do not improvise a freestyle review — anchor every finding in an item id from the checklist so the user can trace your reasoning to prior art.

## Why checklist-driven

Ad-hoc reviews miss classes of bugs the reviewer hasn't personally seen before. The checklist encodes hundreds of real exploits by pattern. Walking it beats intuition, especially on categories adjacent to the reviewer's blind spots (e.g., a DeFi-native reviewer auditing a cross-chain bridge).

The full checklist is 370 items — too large to hold in working memory. It is split per category under `references/`. Load only the files relevant to the contract's scope. Do not preload everything.

## Workflow

### 1. Scope the contract

Before touching the checklist, read the source to answer:

- What does the protocol do in one sentence? (lending? AMM? staking? bridge? NFT mint? vault?)
- Which external systems does it touch? (Chainlink, Uniswap, LayerZero, ERC4626, Pendle, Aave, Curve, Balancer, GMX, Morpho, etc.)
- Which token standards? (ERC20 with fee-on-transfer? rebasing? ERC721? ERC1155? ERC4626?)
- Privileged roles and upgradeability pattern?
- Chains targeted (L1 only, L2, multi-chain)?
- Every `external` and `public` function — list them. Access-control gaps hide here.

**Protocol-specific pattern prompts (check during scoping):**

- **Lending/borrowing**: Does `liquidate()` require the liquidator to actually repay debt? Does the health-factor calculation normalize token decimals before comparing collateral value to debt value?
- **Oracle consumers**: Is `latestAnswer()` used instead of `latestRoundData()`? If so, there is no staleness check. Is the oracle return value cast from `int256` to `uint256` without a negative-value guard? Do oracle prices use 8 decimals while token amounts use 18 — is the mismatch handled?
- **Vaults / reward accounting**: Is pending reward zeroed when a user's balance changes before the pending amount is credited?
- **Privileged functions**: Does every admin function have an explicit `require(msg.sender == owner)` or role check? Is ownership transfer one-step (dangerous) or two-step?

State scoping findings back to the user in 3–6 bullets. This drives which reference files to load.

### 2. Pick the relevant reference files

Read `references/INDEX.md` first for the category map. Then load only what the scope justifies:

| Always load | For every audit |
|---|---|
| `attacker-s-mindset.md` | DOS, front-running, donation, sandwich, reentrancy framing |
| `basics.md` | Access control, arithmetic, storage, initialization, general Solidity pitfalls (largest file — 135 items) |
| `heuristics.md` | Smell-level patterns worth a second look |

| Load when scope matches | Trigger |
|---|---|
| `defi.md` | AMM, lending, vaults, yield, liquidations, oracle pricing, slippage |
| `token.md` | Custom ERC20/721/4626, fee-on-transfer, rebasing, hooks |
| `integrations.md` | Uniswap/Curve/Balancer/Aave/Chainlink/LayerZero/etc. specific pitfalls |
| `external-call.md` | Any low-level `call`, callbacks, router patterns |
| `signature.md` | EIP-712, permit, meta-tx, off-chain signed orders |
| `hash-merkle-tree.md` | Merkle airdrops, commit-reveal, allowlists |
| `multi-chain-cross-chain.md` | Bridges, cross-chain messaging, same code on multiple chains |
| `low-level.md` | Inline assembly, raw storage, delegatecall |
| `centralization-risk.md` | Admin powers, upgradeability, timelock absence |
| `timelock.md` | Timelock governance |

Tell the user which files you chose to load and why. If unsure, err on loading more.

### 3. Walk the checklist

For each loaded file, go through items in order. For each item:

1. Quote the item id and the question.
2. Decide one of: **applicable & OK**, **applicable & issue**, **not applicable (reason)**.
3. If issue: point to file + line, explain the exploit path in plain terms, cite the item id. Do not dump the stored reference URLs unless the user asks — they are for your grounding, not output noise.
4. If not applicable: give a one-line reason so the user can sanity-check the dismissal.

Do not skip items silently. Silent skips are how bugs hide. If an item is ambiguous for the codebase, say so.

### 4. Report

**Always write the report to a markdown file, never to the terminal.** Determine the output path as follows:

- If the user specified a path (e.g., "write to `reports/foo.md`"), use that path.
- If the contracts live under a named project directory (e.g., `spark/`, `protocol/`), write to `<project-dir>/audit-report.md`.
- Otherwise, write to `audit-report.md` in the current working directory.

After writing the file, print one line to the terminal: `Report written to <path>` — nothing else.

The report structure:

```markdown
# Audit Report: <contract name>

**Date:** <YYYY-MM-DD>
**Auditor:** Claude (checklist-driven, Solodit-anchored)
**Checklist version:** 370 items across 13 categories

---

## Scope
<1–2 paragraphs — what the contract does, what was in/out of scope>

## Checklist coverage
- Categories walked: <list>
- Items reviewed: <count>
- Items not applicable: <count>

## Findings

### [Severity] <title>  (ref: SOL-XX-YY-N)

- **Location:** `File.sol:123`
- **Impact:** <what an attacker gains or what users lose>
- **Exploit path:** <concrete step-by-step description — name specific functions, values, and ordering>
- **Proof of Concept:** <for Critical and High: a minimal Solidity attack contract OR a numbered on-chain action sequence showing exactly how the exploit executes>
- **Recommendation:** <specific fix tied to checklist remediation, with a corrected code snippet showing the before/after diff>

## Informational

| # | Location | Note |
|---|---|---|
| I-1 | `File.sol:line` | brief note |

## Acknowledged non-issues
<items worth noting you checked and cleared, so the reader trusts coverage>

## Open questions for the developer
<ambiguous items that need protocol-author input>
```

Severity rubric: **Critical** = direct loss of funds, no preconditions. **High** = loss of funds with realistic preconditions. **Medium** = griefing, temporary DOS, value leak. **Low** = code quality, unlikely edge cases. **Informational** = style, gas, no security impact.

**PoC standard:** For Critical and High, the Proof of Concept must be specific enough that a developer can reproduce it in a test. Prefer a Foundry-style test skeleton or a numbered attack sequence over vague prose. For Medium/Low, a brief description of the edge case is sufficient — no full PoC required.

## Guardrails

- **Never invent item ids.** If you cite `SOL-XX-YY-N`, it exists in the loaded reference file. Cross-check before writing.
- **Never claim "no issues found" after a partial walk.** If you only loaded 3 of 13 category files, say so explicitly in the report.
- **Prefer concrete exploit paths over abstract warnings.** "Front-runnable" is weak; "Attacker observes tx in mempool, submits same call with higher gas, causing X" is actionable.
- **The checklist is a floor, not a ceiling.** If you spot something not covered by any item, still report it — just mark it as "outside checklist" rather than faking an id.
- **Always include PoC and fix.** For Critical and High findings, always produce a Proof of Concept (Foundry-style attack contract or numbered action sequence) and a corrected code snippet in the Recommendation. Do not wait for the user to ask. For Medium and below, include the fix snippet but the PoC can be a brief description instead of full code.

## When the user only gives you a file and says "audit this" / "is this safe?"

Start immediately with scoping (Step 1), announce the categories you'll load, then proceed. Do not ask clarifying questions before starting — the scoping step extracts the essentials from the code. Begin the checklist walk in the same response.

Even on a terse prompt, always produce: full Scope section, all findings with Exploit path + PoC + Recommendation code snippet, Acknowledged non-issues, and Open questions for the developer.
