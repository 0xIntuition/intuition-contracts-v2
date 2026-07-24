---
name: audit-contract
description: |
  Adversarial smart contract security audit. Auto-selects 5-7 specialist agents
  based on contract features (from a roster of 11). Attacks from every relevant
  angle: SWC registry, signatures, reentrancy, state machine, ERC20 edge cases,
  economic exploits, game theory, L2-specific, flash loans, DoS/griefing, privacy,
  backend integration. Runs Slither if available. Writes Foundry PoC tests for
  critical findings. Produces a ranked finding list with severity and code fixes.
  Triggers on: "audit this contract", "security review",
  "attack this contract", "find vulnerabilities".
allowed-tools:
  - Agent
  - Read
  - Grep
  - Glob
  - Bash
  - WebSearch
  - WebFetch
  - AskUserQuestion
argument-hint: "[path to .sol file] [--thorough] [--include-backend <path>] [--focus agent1,agent2]"
---

# Adversarial Smart Contract Audit

You are an orchestrator that runs a structured adversarial security audit on a Solidity smart contract. You auto-select specialist agents based on the contract's features, each attacks from a different angle, then you synthesize findings into a prioritized report.

## When to Use

- Pre-deployment security review of Solidity contracts
- Evaluating a contract's security posture before integrating with it
- Auditing forks/modifications of known protocols
- Finding vulnerabilities in CTF challenges or audit contests

## When NOT to Use

- **Non-Solidity contracts** — this skill is Solidity-focused. For Rust/Move/Cairo, adapt manually.
- **Formal verification needs** — if you need mathematical proof of correctness, use Certora, Halmos, or KEVM instead. This skill finds bugs, it doesn't prove absence of bugs.
- **Already professionally audited + unchanged** — if the code was audited by a reputable firm and hasn't changed, run a differential review instead of a full audit.
- **Gas optimization only** — this is a security audit, not a gas audit.

## Rationalizations to Reject

If you catch yourself thinking any of these during the audit, stop and investigate deeper.

| Rationalization | Why It's Wrong | Required Action |
|---|---|---|
| "This is standard OpenZeppelin, it's safe" | OpenZeppelin versions have CVEs. Constructor args and overrides can break guarantees. | Check the exact OZ version and how it's configured |
| "Solidity 0.8 prevents overflows" | `unchecked` blocks, casting between int sizes, and `abi.decode` bypass SafeMath | Grep for `unchecked`, explicit casts, and assembly |
| "The contract is small, so it's probably safe" | Small contracts compose into large attack surfaces. Simple code has simple bugs. | Audit it fully — small contracts get the same process |
| "nonReentrant is present, reentrancy is covered" | Cross-function and cross-contract reentrancy bypass single-function guards | Map ALL shared state across functions |
| "This is an admin function, trust assumptions apply" | Admin key compromise is a real threat model. Admin functions need review too. | Assess admin powers and what a compromised key can do |
| "The tests pass, so the logic is correct" | Tests verify intended behavior. Audits verify unintended behavior. | Ignore test results when evaluating security |
| "This pattern looks safe" | Pattern recognition is not analysis. Context determines safety. | Trace the full data flow before concluding |

## Input

The contract to audit is: $ARGUMENTS

If $ARGUMENTS is empty or unclear:
- Look at conversation history for a contract being discussed.
- Check the current working directory for `.sol` files.
- If still unclear, use AskUserQuestion.

**Flags** (parsed from $ARGUMENTS):
- `--thorough` — run all 11 agents instead of auto-selected subset
- `--include-backend <path>` — include off-chain backend code in scope (Agent 8)
- `--focus agent1,agent2,...` — run only named agents (e.g., `--focus reentrancy,signatures`)

## Step 0: Understand the contract

Before spawning agents, fully understand what you're auditing.

1. **Read the contract source** — every `.sol` file under `src/`. Understand the state machine, access control, token flows, and external calls.
2. **Read existing tests** — check `test/` to understand what's already covered. Don't duplicate.
3. **Read deployment scripts** — check `script/` for deployment parameters, constructor args, role grants.
4. **Identify the token** — what ERC20 is used? Is it standard (USDC, USDT) or arbitrary? This changes the attack surface dramatically.
5. **Identify the chain** — L1 vs L2 matters for MEV, sequencer, gas costs.
6. **Check for prior audits** — look for audit reports, CLAUDE.md security notes, known accepted risks.

Distill this into a **Contract Brief** that every agent receives. Include:
- Contract name, chain, token
- Lines of code count
- State machine diagram (states + transitions + who can trigger)
- Access control roles and what each can do
- All external calls (token transfers, delegatecalls, etc.)
- Known accepted risks (so agents don't re-report them)
- Deployment parameters

### Step 0.1: Entry-Point Analysis

Before selecting specialist agents, **map the complete attack surface**. Spawn one agent to produce a structured entry-point table covering ALL contracts in scope.

For every contract file, identify all **state-changing** entry points (external/public functions that are NOT view/pure). Classify each:

| Classification | Description |
|---|---|
| **Public (Unrestricted)** | Callable by any EOA or contract with no access restriction |
| **Role-Restricted** | Gated by onlyOwner, onlyAdmin, hasRole, require(msg.sender == X), etc. |
| **Contract-Only** | Callbacks, interface hooks, functions that check tx.origin != msg.sender |
| **Review Required** | Ambiguous access control (dynamic trust lists, conditional restrictions) |

Output format per contract:
```
| Function | File:Line | Access | Classification |
|----------|-----------|--------|----------------|
```

**Why this matters**: This prevents scoping gaps. Every public unrestricted entry point is a potential attack vector. If a contract in scope isn't in this table, it's been missed.

Add the entry-point table to the Contract Brief.

### Step 0.2: Invariant Extraction

For each core function (deposit, withdraw, claim, transfer, state transitions), document **explicit invariants** — conditions that must ALWAYS hold before and after the function executes.

Format:
```
INV-1: [invariant statement]
  - Relied on by: [which functions assume this]
  - Violated if: [what would break it]
```

Minimum 3 invariants per core function. Examples:
- "totalStaked == sum of all userInfo[x].amount"
- "After deposit, user.rewardDebt == user.amount * accRewardPerShare / PRECISION"
- "No user can hold shares on both sides of a triple simultaneously"

**Why this matters**: Specialist agents check whether these invariants can be violated. This turns bug-finding from "look for known patterns" into "prove this property can break." The VotingEscrow underflow (Intuition, $XX loss) would have been caught by documenting "INV: _supply_at requires point.ts <= t" and checking whether all callers guarantee it.

Add the invariant list to the Contract Brief.

### Step 0.5: Auto-select agents

Based on the Contract Brief, select which agents to run. Default is 5-7 agents. Use all 11 only if `--thorough` is passed.

**Selection rules:**

| Agent | Run if... |
|-------|-----------|
| 1. SWC Registry | **Always** — baseline check |
| 2. Signatures | Contract uses ecrecover, EIP-712, or any signature verification |
| 3. Reentrancy | Contract makes external calls (token transfers, delegatecalls, low-level calls) |
| 4. State Machine | Contract has >2 states, role-based access control, or is upgradeable (proxy/UUPS) |
| 5. ERC20 Edge Cases | Contract interacts with ERC20 tokens |
| 6. Economic/Game Theory | Contract involves payments, fees, multi-party incentives |
| 7. L2-Specific | Contract deploys on L2 AND has time-sensitive operations |
| 8. Backend Integration | `--include-backend` flag passed with a path to backend code |
| 9. Flash Loans | Contract has deposit/withdraw in same tx potential, or interacts with DeFi protocols |
| 10. DoS/Griefing | Contract has multi-party flows where one party can block others |
| 11. Privacy | Contract handles sensitive data or has public state that could leak business info |

Print the selection:
```
Selected agents: SWC Registry, Reentrancy, State Machine, ERC20, Economic (5 agents)
Estimated time: ~4-6 minutes
Use --thorough for all 11 agents, or --focus to pick specific ones.
```

If `--focus` is passed, run only the named agents regardless of auto-selection.

## Step 1: Pre-flight checks

### 1a. Static analysis (Slither + Semgrep)

Check if Slither and Semgrep are available. **Never auto-install.**

```bash
which slither 2>/dev/null
which semgrep 2>/dev/null
```

**Slither:**
- If available: run `slither src/ --filter-paths "lib/|node_modules/" 2>&1 || true` and capture output.
- If not available: print `"Slither not found — install with: pipx install slither-analyzer"` and continue.

**Semgrep:**
- If available: run `semgrep --config p/solidity-security src/ 2>&1 || true` and capture output.
- If not available: print `"Semgrep not found — install with: pipx install semgrep"` and continue.

Pass tool outputs (or "not available" notes) to agents.

### 1b. Dependency version check

Check OpenZeppelin and other dependency versions for known CVEs:

```bash
cat lib/openzeppelin-contracts/package.json 2>/dev/null | grep version || cat node_modules/@openzeppelin/contracts/package.json 2>/dev/null | grep version || echo "OZ version not found"
```

Flag if OZ version is below 4.9.3 (known reentrancy guard bug) or below 5.0.0 (if contract uses 5.x patterns). Check `foundry.toml` or `remappings.txt` for pinned dependency versions.

### 1c. Foundry check

Verify the project compiles:

```bash
forge build 2>&1
```

- If it fails: print the error. PoC round (Step 2.5) will be skipped. Note this for agents.
- If it succeeds: PoC round is available.

## Step 2: Spawn specialist agents

Spawn the **auto-selected agents** (or all 11 if `--thorough`). Use `subagent_type: "general-purpose"` so they have tool access.

**After each agent completes, immediately print a progress line:**
```
[2/5] Reentrancy agent done — 0 CRITICAL, 1 HIGH, 0 MEDIUM found
```

Every agent MUST:
- Read the actual contract code (not just the brief)
- Ground findings in specific line numbers and function names
- Rate each finding: CRITICAL / HIGH / MEDIUM / LOW / INFO
- Provide a concrete exploit scenario or proof that it's not exploitable
- Check the entry-point table — focus on Public (Unrestricted) entry points first, they're the primary attack surface
- Check the invariant list — can any invariant be violated through your attack angle?
- Keep response to 200-400 words
- Not report known accepted risks unless they found a new angle

---

### Agent Playbooks

Each agent receives its specific playbook from [references/agent-playbooks.md](references/agent-playbooks.md). The playbook defines the agent's role, attack vectors to check, and instructions.

**Quick reference — agent roles:**
1. **SWC Registry** — systematic SWC-100 through SWC-136 check
2. **Signatures** — replay, malleability, ecrecover(0), domain separator, ERC-4337
3. **Reentrancy** — classic, cross-function, read-only, ERC777, transient storage (EIP-1153)
4. **State Machine** — transition matrix, role escalation, initialization, proxy/UUPS
5. **ERC20 Edge Cases** — fee-on-transfer, rebasing, pausable, blacklist, vault inflation (ERC-4626)
6. **Economic** — MEV, collusion, fee rounding, griefing, incentive misalignment
7. **L2-Specific** — sequencer downtime, timestamp, reorgs, cross-chain replay
8. **Backend** — tx confirmation, RPC, nonce, key security, event parsing (opt-in)
9. **Flash Loans** — amplification, sandwich, atomic arbitrage, oracle manipulation
10. **DoS/Griefing** — fund locking, reverting receiver, gas griefing, storage bloat
11. **Privacy** — mempool visibility, identity correlation, storage slot reading

---

## Step 2.5: Proof-of-Concept round (conditional)

**Pre-check**: Only run this step if `forge build` succeeded in Step 1c.

After all agents report, check if any CRITICAL or HIGH findings were reported. If yes:

1. For each CRITICAL/HIGH finding, spawn an agent to **write a Foundry test** that demonstrates the exploit. Use `isolation: "worktree"` so it doesn't pollute the repo.
2. The test should:
   - Set up the contract with realistic parameters
   - Execute the attack step-by-step
   - Assert the attacker's gain or the victim's loss
   - If the attack is blocked, the test should demonstrate that too (revert expected)
3. Run `forge test --match-path <poc-file> -vvv` to verify the PoC compiles and runs.

**If a PoC fails to compile or execute:**
- Do NOT silently downgrade the finding
- Record the failure explicitly: `"PoC FAILED: [exact error]. Finding remains HIGH — manual verification recommended."`
- Include the failed test code and the compile/runtime error in the report so the user can retry

**If a PoC succeeds (exploit works):** finding is confirmed CRITICAL regardless of agent's original rating.
**If a PoC succeeds (exploit blocked):** finding is downgraded with explanation.

If `forge build` failed in Step 1c, skip this step entirely and note in the report:
```
PoC validation: SKIPPED (project failed to compile — see Step 1c errors)
All CRITICAL/HIGH findings are unvalidated. Manual review strongly recommended.
```

## Step 2.75: False-Positive Gate Review

After all agents report and PoCs are attempted, spawn ONE agent to **challenge every CRITICAL and HIGH finding**. This agent's job is to disprove findings, not confirm them.

For each CRITICAL/HIGH finding, apply these 6 gates:

| Gate | Question | PASS if... | FAIL if... |
|------|----------|------------|------------|
| **1. Reachability** | Can an attacker actually reach this code path with controlled input? | Clear path from external call to vulnerable code | Code is unreachable, requires trusted caller, or input is bounded upstream |
| **2. Validation Chain** | Is there upstream validation that prevents the attack? | No prior check blocks the exploit | A require/assert/if-revert earlier in the call chain makes the condition impossible |
| **3. Math Bounds** | Do the math constraints actually allow the vulnerable condition? | Algebraic proof that vulnerable values are possible | Math proves the condition cannot occur (e.g., underflow impossible due to prior bounds) |
| **4. State Preconditions** | Can the contract actually be in the required state for the exploit? | State is reachable through normal or adversarial usage | Required state is unreachable or requires trusted-role cooperation |
| **5. Economic Viability** | Is the attack profitable or at least cheap enough to grief? | Attack cost < extracted value, OR griefing cost is low | Attack costs more than it extracts with no griefing benefit |
| **6. Environment** | Do environmental protections (reentrancy guards, pauses, timelocks) prevent it? | No environmental protection blocks the exploit | nonReentrant, whenNotPaused, timelock, or similar blocks it entirely |

**Verdict per finding:**
- All 6 gates PASS → **TRUE POSITIVE** (stays at current severity)
- Any gate FAIL → **FALSE POSITIVE** or **DOWNGRADE** with documented reason

```
FP-CHECK: [C-1] Reward pool drainage via withdrawUnusedRewards
  Gate 1 (Reachability): PASS — onlyOwner, but owner IS the threat model here
  Gate 2 (Validation):   PASS — no check that withdrawn amount < owed rewards
  Gate 3 (Math Bounds):  PASS — owner can withdraw full balance
  Gate 4 (State):        PASS — any state with funded rewards
  Gate 5 (Economic):     PASS — pure profit for malicious owner
  Gate 6 (Environment):  PASS — no timelock, no multisig at contract level
  VERDICT: TRUE POSITIVE — confirmed CRITICAL
```

**Why this matters**: LLMs are biased toward seeing bugs. Pattern-matching "this looks dangerous" produces false positives that waste the user's time and erode trust. The gate review forces evidence-based verification of each finding. Trail of Bits reports that this step alone eliminates 30-50% of initial findings as false positives.

Pass the gate review results to the synthesis agent.

## Step 2.9: Variant Analysis

For each TRUE POSITIVE from the FP-Check, search the entire codebase for the same root cause pattern in other functions or contracts. A bug found once often exists in sibling code.

For example:
- If an unchecked return value is found in `deposit()`, grep for the same call pattern in `withdraw()`, `claim()`, etc.
- If a missing access control is found on `setFee()`, check all other setter functions.
- If a rounding error is found in share calculation, check all other division operations.

Use Grep to search for the pattern. Report any variants found as additional findings at the same severity.

## Step 3: Synthesize findings (single agent)

Spawn ONE synthesis agent with:
- The Contract Brief (including entry-point table and invariant list)
- All agent outputs (only the selected agents, not all 11)
- PoC test results (which exploits succeeded, which were blocked, which failed to compile)
- FP-Check gate review results (which findings passed, which were downgraded/rejected)
- Slither output (or "Slither not available" note)
- Extended thinking enabled (ultrathink)

**Instruction**: "Synthesize all findings into a final audit report. De-duplicate findings that multiple agents flagged — credit all agents that found it. Findings with working PoC exploits are automatically CRITICAL. Findings where the PoC showed the attack is blocked should be downgraded. Findings where the PoC failed to compile remain at original severity with a note. Findings that FAILED the FP-Check gate review should be excluded or listed separately as 'Investigated but not confirmed.' Never include a finding that failed a gate review at CRITICAL or HIGH severity."

The report MUST follow this format:

```
## Audit Verdict: [NO CRITICAL ISSUES DETECTED / ISSUES FOUND — FIXES REQUIRED / CRITICAL ISSUES — DO NOT DEPLOY]

### Contract: [name] on [chain]
### Audited: [date]
### Scope: [files audited]
### Agents run: [list of agents that ran]
### Agents skipped: [list + reason, e.g., "Backend (no --include-backend flag)"]
### Static analysis: [Slither available/skipped]
### PoC validation: [available/skipped + reason]
### FP-Check: [X of Y findings confirmed as TRUE POSITIVE, Z downgraded/rejected]
### Entry points analyzed: [N public unrestricted, M role-restricted, P contract-only]

---

### CRITICAL (must fix before deployment — funds at risk)
For each finding:
- **[C-N] Title**
  - Severity: CRITICAL
  - PoC status: CONFIRMED (compiled & passed) / DRAFT (failed to compile — manual verification needed) / SKIPPED (reason)
  - Location: `file.sol:lineNumber` — `functionName()`
  - Description: What's wrong
  - Exploit scenario: Step-by-step how an attacker would exploit this
  - Recommendation: Specific code change (include a diff-ready patch where possible)
  - Agents that found it: [list]

### HIGH (should fix — significant risk)
[Same format]

### MEDIUM (recommended fix — moderate risk)
[Same format]

### LOW (minor issues)
[Same format]

### INFORMATIONAL (best practices, gas optimizations)
[Same format]

### Accepted Risks (documented, not bugs)
[List known accepted risks from the brief + any new ones agents agreed are acceptable]

### What's Strong
- [2-4 bullets on security practices done well]

### Recommended Next Steps
1. [Ordered list of actions]
2. [If relevant: "Run invariant fuzzing with Echidna/Medusa on [specific invariant] — this is the natural next step after an AI audit and catches stateful bugs that static analysis misses"]
3. [If relevant: "Consider formal verification for the state machine"]

### Audit Scope Limitations
- This audit was generated by AI agents using static analysis and adversarial reasoning. It is NOT a professional security audit.
- Proof-of-concept tests are best-effort drafts that may require manual adjustment to compile and run.
- Coverage is limited to the Solidity source provided. Dependency/supply chain analysis, formal verification, and invariant fuzzing are out of scope.
- For contracts managing significant value, commission an independent audit from a qualified security firm before deploying to mainnet.
```

## Step 4: Present results

Show the user the synthesized report. Do NOT dump all agent outputs.

After presenting, ask: "Want me to expand on any finding, or start fixing the critical/high issues?"

## Important rules

- **Evidence over theory.** Every finding must reference specific code. "Could be vulnerable to X" is not a finding. "Line 142 calls transfer() before updating state on line 145" is a finding.
- **No false positives.** A finding that doesn't apply wastes the user's time and erodes trust. If a pattern exists but is mitigated (e.g., nonReentrant is present), say so explicitly.
- **Concrete exploits.** For CRITICAL/HIGH findings, include a step-by-step exploit scenario with actual function calls.
- **PoC failures are NOT silent downgrades.** If a PoC fails to compile, the finding stays at its original severity with an explicit note. The user decides.
- **Respect accepted risks.** If the Contract Brief lists known accepted risks, don't re-report them unless you found a new angle.
- **Check the specific token.** Generic "ERC20 could be weird" is useless. Check the actual token (USDC, USDT, DAI, etc.) and its specific behaviors.
- **Backend is opt-in.** Only audit backend code if `--include-backend` is passed. Don't crawl the repo without consent.
- **Run Slither if available, skip gracefully if not.** Never auto-install packages on the user's system.
- **Compare to real hacks.** Agents should reference real-world exploits where the same pattern was used. Rekt.news and DeFiLlama hacks DB are good references.
- **De-duplicate across agents.** Multiple agents may flag the same issue (e.g., reentrancy). The synthesis must merge these into one finding and credit all agents.
- **Progress over silence.** Print a status line after each agent completes. Never let the user stare at nothing for minutes.
- **ultrathink** — Enable extended thinking for the synthesis round.

## Reference: Real-world exploit patterns to check

These are patterns from actual mainnet exploits. Every agent should keep these in mind:

| Exploit | Pattern | Notable Hacks |
|---------|---------|---------------|
| Reentrancy | External call before state update | The DAO ($60M), Cream Finance ($130M) |
| Flash loan price manipulation | Borrow, manipulate, profit, repay | bZx ($8M), Harvest Finance ($34M) |
| Access control | Missing onlyOwner/role check | Parity Multisig ($30M), Ronin Bridge ($625M) |
| Oracle manipulation | Spot price as oracle | Mango Markets ($114M) |
| Signature replay | Missing chainId/nonce | Wintermute ($160M across chains) |
| Integer overflow | Pre-0.8 unchecked math | BEC Token ($1B), SMT Token |
| Delegatecall to untrusted | Proxy storage collision | Parity kill ($300M frozen) |
| Front-running | Mempool transaction visibility | Sandwich attacks ($1M+/day aggregate) |
| Insufficient validation | Missing zero-address check | Various bridge exploits |
| Logic error in state machine | Unexpected state transition | Wormhole ($320M) |
| Uninitialized proxy | Implementation can be initialized | Nomad Bridge ($190M) |
| Token approval drain | Leftover approvals exploited | Various DEX hacks |
| Supply chain attack | Compromised signing UI / dependency | Bybit ($1.5B via Safe{Wallet} JS injection) |
| Vault share inflation | First depositor manipulates share price | Multiple ERC-4626 vaults (2024) |
| Transient storage reentrancy | EIP-1153 tstore/tload lock bypass | Emerging vector (2025+) |
