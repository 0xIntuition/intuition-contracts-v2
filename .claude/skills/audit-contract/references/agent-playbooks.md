# Agent Playbooks

Detailed playbooks for each of the 11 specialist agents. The orchestrator spawns the auto-selected subset with the Contract Brief + the relevant playbook section below.

---

### Agent 1: SWC Registry Scanner

**Role**: Systematically check every SWC entry against the contract.

**Playbook** (check these SWC IDs):
- SWC-100: Function default visibility
- SWC-101: Integer overflow/underflow (Solidity >=0.8 has built-in checks, but verify unchecked blocks)
- SWC-102: Outdated compiler version
- SWC-103: Floating pragma
- SWC-104: Unchecked call return value
- SWC-105: Unprotected ether withdrawal
- SWC-106: Unprotected selfdestruct
- SWC-107: Reentrancy (basic check — Agent 3 goes deeper)
- SWC-108: State variable default visibility
- SWC-110: Assert violation / improper use
- SWC-111: Deprecated functions
- SWC-112: Delegatecall to untrusted callee
- SWC-113: DoS with failed call
- SWC-114: Transaction order dependence (front-running)
- SWC-115: Authorization through tx.origin
- SWC-116: Block values as time proxy
- SWC-118: Incorrect constructor name
- SWC-119: Shadowing state variables
- SWC-120: Weak randomness
- SWC-124: Write to arbitrary storage
- SWC-125: Incorrect inheritance order
- SWC-127: Arbitrary jump with function type variable
- SWC-128: DoS with block gas limit
- SWC-129: Typographical error (=+ vs +=)
- SWC-130: Right-to-left override control character
- SWC-131: Presence of unused variables
- SWC-132: Unexpected ether balance
- SWC-134: Message call with hardcoded gas amount
- SWC-135: Code with no effects
- SWC-136: Unencrypted private data on-chain

**Instruction**: "For each SWC, check if the pattern exists in this contract. Skip ones that are clearly N/A (e.g., no selfdestruct = skip SWC-106). Focus on the ones that ARE relevant."

### Agent 2: EIP-712 & Signature Attacks

**Role**: Attack the signature verification logic.

**Playbook**:
- **Replay attacks**: Can a valid signature be replayed on a different chain? Different contract deployment? Different job? After contract upgrade?
- **Malleability**: Does the contract check `s <= secp256k1n/2`? (EIP-2). Can the same signature be submitted twice with different (v,s) values?
- **ecrecover returns address(0)**: Does the contract check that the recovered address is not address(0)? An invalid signature returns 0x0 — if any role maps to 0x0, that's a critical vulnerability.
- **Domain separator**: Is chainId included? Is the contract address included? Is there a salt? What happens if the contract is deployed at the same address on a different chain (CREATE2)?
- **Nonce handling**: Are nonces used? Can they be skipped? Can they be reused? Is there a nonce per job or global?
- **Signature length**: What happens with truncated signatures? Empty bytes? Oversized data?
- **EIP-1271 (contract signatures)**: Does the contract support smart contract wallets? Should it?
- **Permit integration**: If the token supports permit(), can permit + deposit be front-run?
- **ERC-4337 Account Abstraction**: If the contract is a paymaster, validator, or smart wallet module, check UserOperation validation phase restrictions (no access to external storage), bundler griefing vectors, and signature validation in `validateUserOp`. Reference Trail of Bits' "six failure modes" analysis.

**Instruction**: "Try to construct a concrete exploit for each attack vector. If the contract uses OpenZeppelin's ECDSA or EIP712, check the specific version for known issues. If the contract interacts with ERC-4337 infrastructure, check validation phase storage restrictions."

### Agent 3: Reentrancy & External Calls

**Role**: Find reentrancy vulnerabilities through all external call paths.

**Playbook**:
- **Classic reentrancy**: Map every external call (token transfers, delegatecalls). For each, check: is state updated BEFORE the call? Is nonReentrant used?
- **Cross-function reentrancy**: Can a callback from function A re-enter function B that reads stale state? Map all state that's shared between functions.
- **Read-only reentrancy**: Can a view function return stale data during a reentrant call? (Relevant if other contracts read this contract's state.)
- **ERC20 callback reentrancy**: ERC777 tokens have transfer hooks. Does the contract assume ERC20 transfers are non-reentrant? Is the token address immutable?
- **Create2 reentrancy**: Can an attacker deploy a contract at a predictable address that reenters during construction?
- **transferFrom reentrancy**: Some tokens (e.g., imBTC) have callbacks on transferFrom. Check if deposit() is safe.
- **Transient storage reentrancy (EIP-1153)**: Locks using `tstore`/`tload` reset per transaction, not per call. A `nonReentrant` guard implemented with transient storage behaves differently than SSTORE-based guards — it allows reentry across transactions in the same block. Check if the contract uses transient storage for reentrancy protection and whether this creates a new attack surface.

**Instruction**: "For each external call in the contract, trace the full call stack. Determine if any state is read after the call that was set before the call. nonReentrant blocks same-function reentry but NOT cross-function reentry on different contracts. If transient storage (EIP-1153) is used, verify locks persist correctly across the full call context."

### Agent 4: State Machine & Access Control

**Role**: Find invalid state transitions and access control bypasses.

**Playbook**:
- **Transition matrix**: Build a complete matrix of (current_state, function) → (allowed?, new_state). Every cell must be either "allowed" or "reverts". Look for missing revert checks.
- **State finality**: Terminal states must be unreachable from. Can any function transition OUT of a terminal state?
- **Role escalation**: Can any role grant itself more permissions? Can the DEFAULT_ADMIN_ROLE be renounced, bricking the contract?
- **Initialization attacks**: Can anyone call initialize/constructor-like functions after deployment? Are roles granted atomically in deploy?
- **Proxy & upgradeability**: If upgradeable, check: (a) Can the implementation contract be initialized directly by an attacker? (Nomad Bridge, $190M). (b) UUPS: is `_authorizeUpgrade` protected with access control? Can it be removed in an upgrade, bricking upgradeability? (c) Transparent proxy: storage slot collisions between proxy admin and implementation? (d) Storage layout: do upgrades preserve slot ordering? New variables must be appended, never inserted. (e) Is there a timelock on upgrades? (f) Can `delegatecall` to a malicious implementation `selfdestruct` the proxy?
- **Race conditions**: Can two transactions targeting the same entity both succeed? E.g., release() and dispute() in the same block.
- **Multi-instance isolation**: Can actions on instance A affect instance B? Shared state?
- **Conservation invariant**: `sum(all held amounts in non-terminal states) == contract token balance` at all times. Fuzz this.

**Instruction**: "Build the full transition matrix. If there are N states and M functions, that's N*M cells to check. Every cell matters. Also verify the conservation invariant holds under all transitions."

### Agent 5: ERC20 Token Edge Cases

**Role**: Attack through token behavior rather than contract logic.

**Playbook**:
- **Fee-on-transfer tokens**: If the token charges fees, `transferFrom(amount)` delivers less than `amount`. Does the contract account for this? Is the token immutable?
- **Rebasing tokens**: If the token's balance changes spontaneously (aave aTokens, stETH), does the contract handle balance != deposited amount?
- **Pausable tokens**: USDC can be paused by Circle. When paused, all transfers revert. Can this lock funds in the contract forever? Is there an emergency escape?
- **Blacklistable tokens**: USDC can blacklist addresses. If a party is blacklisted, transfers to them revert. Does multi-party payout handle partial failure? **Enumerate EVERY address that appears in a safeTransfer/transfer call — not just the obvious parties (depositor, payee). Check third-party recipients (arbitrators, fee collectors, treasury addresses). If any recipient's transfer is mandatory (no if > 0 guard, or the amount is always nonzero by construction), blacklisting that address bricks the entire function.**
- **Upgradeable tokens**: USDC is a proxy. The implementation can change. Could a future upgrade break the contract's assumptions?
- **Return value handling**: Does the contract check return values of transfer/transferFrom? Some tokens return false instead of reverting. Is SafeERC20 used?
- **No-return tokens**: Some tokens (old USDT) don't return a bool. SafeERC20.safeTransfer handles this.
- **Approval race**: If changing allowance from non-zero to non-zero, some tokens are vulnerable to front-running. Is approve() used safely?
- **Decimals**: Does the contract assume specific decimals? What if the token has 0 decimals?
- **MAX_UINT approval**: Does the contract rely on infinite approval? Can it be drained by a malicious token?
- **ERC-4626 vault inflation attack**: If the contract is a vault or interacts with ERC-4626, check the first-depositor attack — an attacker can frontrun the first deposit with a tiny deposit + direct token transfer to inflate the share price, causing subsequent depositors to receive 0 shares due to rounding. Check if `_decimalsOffset()` or virtual shares/assets are used as mitigation.

**Instruction**: "Focus on the SPECIFIC token this contract uses. If it's USDC, check Circle's actual blacklist/pause behavior. If it's arbitrary, every edge case matters. If ERC-4626, check the share inflation vector."

### Agent 6: Economic & Game Theory Attacks

**Role**: Find ways to extract value or game the system through economic incentives.

**Playbook**:
- **MEV / front-running**: Can a miner/sequencer reorder transactions for profit? E.g., see a resolve() in the mempool and front-run with dispute().
- **Collusion**: Can any two parties collude against a third? What's the maximum extractable value? Do fee caps limit damage?
- **Fee rounding attacks**: With small amounts, do fee calculations round to 0? Can an attacker use dust amounts to avoid fees? Fuzz fee calculations for all edge values.
- **Griefing attacks**: Can someone force another party into a worse position at low cost to themselves?
- **Sniping/front-running deposits**: Can an attacker act on someone else's behalf before them?
- **Bait-and-switch**: Can a proposal made in one state be accepted in a different, more advantageous state?
- **Timestamp manipulation**: On L2s, the sequencer controls block.timestamp. Can manipulated timestamps affect time-sensitive operations?
- **Multi-instance economic attacks**: Can an attacker leverage multiple instances against each other?
- **Incentive misalignment**: Are there situations where a rational actor's best move harms the system? Map out the game tree for each participant.
- **Alternative path comparison**: If multiple functions can reach the same terminal state (e.g., resolve() and forceRelease() both exit Disputed), **compare what each party receives from each path**. Any difference in payout, fee, or timing creates an incentive to prefer one path. Check whether a party can manipulate which path executes (e.g., by stalling, front-running, or colluding with a gatekeeper). Fee bypasses through timeout/fallback paths are a common pattern.

**Instruction**: "Think like a rational economic actor trying to maximize their profit at others' expense. For each attack, calculate: what's the attacker's cost, what's the victim's loss, and what's the probability of success? When multiple code paths reach the same end state, always compare economic outcomes across paths."

### Agent 7: L2 & Chain-Specific Attacks

**Role**: Find vulnerabilities specific to the deployment chain.

**Playbook**:
- **Sequencer downtime**: On L2s, the sequencer can go down. During downtime, no transactions process. If the contract has time-sensitive operations (dispute windows, timeouts), sequencer downtime can cause unfair expiry.
- **L1→L2 message delays**: If the contract interacts with L1, messages take ~7 days (optimistic rollup). Relevant?
- **Gas price spikes**: L2 gas is usually cheap but can spike. Can gas price spikes make certain operations economically unfeasible?
- **Block.timestamp on L2**: On L2s, block.timestamp comes from the sequencer. It's generally reliable but not guaranteed to match L1 time exactly.
- **CREATE2 + reorg**: On L2s, reorgs are possible (pre-finality on L1). Can a contract deployed via CREATE2 be frontrun on reorg?
- **Chain-specific precompiles**: Does the contract use any chain-specific features?
- **Cross-chain replay**: If deployed on multiple chains, can transactions be replayed? Is chainId in the domain separator?
- **Bridge interactions**: Does the contract interact with any bridges?
- **EIP-4844 blob data**: Does the contract rely on calldata that might move to blobs?

**Instruction**: "Check what chain this is deployed on and research that specific chain's quirks. Base is an OP Stack L2 — check for OP Stack-specific issues."

### Agent 8: Backend & Integration Review

**Requires**: `--include-backend <path>` flag. If not provided, skip this agent.

**Role**: Attack the off-chain integration layer. Smart contracts don't exist in isolation.

**Playbook**:
- **Transaction confirmation**: Does the backend wait for transaction confirmation before updating DB state? `writeContract()` in viem returns a tx hash BEFORE the tx is mined. If the backend writes to DB immediately, a reverted tx creates state divergence.
- **RPC reliability**: Does the backend have fallback RPCs? What happens if the RPC returns stale data (load-balanced nodes at different block heights)?
- **Nonce management**: If the backend sends multiple transactions, are nonces handled correctly? Concurrent calls can cause nonce conflicts.
- **Private key security**: Where is the relayer key stored? Is it in env vars, a secrets manager, an HSM? Can it be extracted from server memory?
- **Event parsing**: Does the backend parse on-chain events correctly? ABI changes can break event parsing silently.
- **Error handling**: What happens when an on-chain call reverts? Does the backend retry? Does it surface the revert reason?
- **Race conditions**: Can the backend process two requests for the same entity simultaneously? Is there locking?
- **Input validation**: Does the backend validate addresses, amounts, IDs before sending on-chain? Can a malformed input cause unexpected behavior?
- **Gas estimation**: Does the backend estimate gas correctly? What happens if gas estimation fails?
- **Relayer as chokepoint**: If the relayer wallet runs out of ETH/gas, all on-chain operations stop. Is there monitoring?

**Instruction**: "Read the backend code at the path provided. Check every function that calls writeContract/readContract. Trace the full flow from API request to on-chain execution to DB update."

### Agent 9: Flash Loan & DeFi Composability Attacks

**Role**: Find vulnerabilities exploitable through atomic composability — flash loans, sandwich attacks, and multi-protocol interactions.

**Playbook**:
- **Flash loan amplification**: Can an attacker borrow unlimited tokens via flash loan (Aave, dYdX, Balancer) to manipulate contract state within a single transaction?
- **Sandwich attacks**: Can a transaction be sandwiched (front-run + back-run) profitably?
- **Atomic arbitrage**: Can an attacker compose multiple contract calls in a single tx to create a risk-free profit? E.g., deposit + complete + release all in one tx via a malicious contract.
- **Price oracle manipulation**: If the contract references any external price (even indirectly via token value), can a flash loan move that price within a single block?
- **Composability with other protocols**: If tokens are yield-bearing or LP tokens, can their value be manipulated mid-transaction?
- **Callback exploitation**: Can a caller be a smart contract that uses callbacks to manipulate state?
- **Single-tx drain**: Map every possible sequence of function calls an attacker could execute atomically. Can any sequence drain funds or create an inconsistent state?

**Instruction**: "Write a concrete Foundry test that demonstrates each viable attack. If the attack is blocked, explain exactly what prevents it. Focus on the atomic (single-transaction) nature of flash loans — the attacker has unlimited capital but must repay within the same tx."

### Agent 10: DoS, Griefing & Fund Locking

**Role**: Find ways to permanently or temporarily brick the contract, lock funds, or make operations prohibitively expensive — without stealing anything.

**Playbook**:
- **Permanent fund locking**: Can funds become permanently irretrievable? Check every terminal state — is there always a path to withdraw? What if all parties disappear?
- **Reverting receiver DoS**: If a recipient's `receive()`/`fallback()` reverts (or if it's a contract with no receive function), does it block payouts to ALL parties?
- **Gas griefing**: Can an attacker make a function consume excessive gas? Unbounded loops, large storage reads, returndata bombs from malicious contracts.
- **Storage bloat**: Can an attacker create unlimited storage entries (e.g., unlimited instances with dust amounts)?
- **Admin key loss**: What happens if the admin/relayer private key is lost? Can the contract be recovered? Can roles be re-granted?
- **Pause griefing**: If the contract is pausable, can a compromised admin pause it permanently? Is there a timelock on pause?
- **Block stuffing**: Can an attacker fill blocks to prevent time-sensitive operations?
- **Self-destruct interactions**: Can a self-destructing contract force ETH into the contract, breaking any balance checks?
- **Token approval drainage**: Can a previously-approved spender drain the contract's token balance?
- **Denial by front-running**: Can an attacker front-run a legitimate transaction to make it revert?
- **Stuck funds enumeration**: Is there any combination of party actions (or inactions) that results in funds stuck with no path to release? Enumerate all parties being unresponsive.

**Instruction**: "The goal is NOT to steal funds — it's to make the contract unusable or lock funds forever. For each attack, determine: is it permanent or temporary? What's the attacker's cost vs. the victim's damage? Can the contract admin recover from it?"

### Agent 11: Privacy & Information Leakage

**Role**: Find sensitive information that's exposed on-chain or through transaction patterns.

**Playbook**:
- **Pending transaction visibility**: All pending transactions are visible in the mempool (or sequencer queue on L2). Can seeing a pending transaction allow front-running for profit?
- **Amount as signal**: Are amounts public? Does this leak business-sensitive information?
- **Party identity correlation**: Can on-chain addresses be correlated with real identities through the backend API?
- **Privileged role identity**: Are privileged addresses public? Can this be used to pressure/bribe them off-chain?
- **Transaction timing analysis**: Can the pattern of operations reveal information about the service being performed?
- **Revert reason leakage**: Do revert messages expose internal state that should be private?
- **Event data exposure**: Do emitted events contain more information than necessary?
- **Storage slot reading**: Anyone can read all storage slots directly (even "private" variables). Is any sensitive data stored on-chain that shouldn't be?

**Instruction**: "Think like an adversary who wants to gather intelligence, not steal funds. What can you learn about the parties and their deals just by watching the chain? Does any of this information create an attack vector when combined with off-chain data?"
