# Audit Report: AtomWalletFactory + CoinbaseSmartWalletLib (Cluster E — CREATE2 wallet deploy + P-256/WebAuthn/ERC-1271 primitives)

**Date:** 2026-07-24
**Auditor:** Checklist-driven, Solodit-anchored review (Cyfrin/audit-checklist, 370 items / 13 categories)
**Method:** `smart-contract-audit` skill walk, run as **round-3 breadth backstop** for the v1.1.0 internal pre-audit (handoff `audits/handoffs/ai-pseudo-audit-handoff-v1.1.0.md`, cluster E). Independent of the frontier round; cross-referenced only to mark duplicates.
**Reviewed commit:** `b52557bc5d1e87537e621fc13917240d40044c24` (branch `feat/v1.1.0-core-upgrade`)
**Targets:**
- `src/protocol/wallet/AtomWalletFactory.sol` (interface `src/interfaces/IAtomWalletFactory.sol`)
- `src/libraries/CoinbaseSmartWalletLib.sol`

**Toolchain confirmed:** Solidity `0.8.29`, `evm_version = "cancun"` (EIP-1153 / EIP-6780), Solady (`WebAuthn`, `P256`, `SignatureCheckerLib`), OpenZeppelin `5.4.0`, TransparentUpgradeableProxy; BeaconProxy for wallets.

> **Pre-audit artifact.** Internal, checklist-anchored review — **not** a formal audit, certification, or guarantee. Directed breadth coverage feeding the external audit. Every finding is anchored to a checklist item id (a floor, not a ceiling). Finding ids use the `LC-E-F-NN` namespace (factory/lib) to stay distinct from the `AtomWallet` sibling agent.

---

## Scope

Two units, both on the atom-wallet lifecycle:

- **`AtomWalletFactory`** deploys ERC-4337 AtomWallets deterministically. `deployAtomWallet(bytes32 atomId)` is **permissionless**: it checks the term exists and is an atom (not a triple) via `MultiVault`, builds the BeaconProxy creation code + init args, computes the CREATE2 address, returns early if the wallet already exists, else deploys via raw `create2` with `salt = atomId`. `computeAtomWalletAddr` is the pure address oracle used by `MultiVault`/`MultiVaultLib` (atom-creation attribution, fee routing) and `AtomWarden` (`_getAtomWallet` before `completeClaim`). Storage is `multiVault` (slot 0) + `uint256[50] __gap`; `multiVault` is set once in `initialize` and has **no setter**. `initialize` uses the OZ `initializer` modifier.
- **`CoinbaseSmartWalletLib`** is a stateless internal library inlined into `AtomWallet`. It provides MultiOwnable owner management (ERC-7201 storage) and the non-reverting `isValidSignature(bytes32 hash, bytes signature)` dispatcher: EOA owners (32-byte) via Solady `SignatureCheckerLib.isValidSignatureNow`, passkey owners (64-byte P-256) via Solady `WebAuthn.verify` / `P256`. It also ships `replaySafeHash` / `domainSeparator` (EIP-712, bound to `address(this)`+chainId) — **but these are never invoked by the verification path.**

External systems touched: `MultiVault` / `MultiVaultCore` (term/atom checks, `walletConfig`), the `AtomWallet` implementation behind the beacon, and Solady precompile wrappers. All first-party / deterministic-address, except the P-256 verifier infrastructure (precompile or Solady verifier contract), which is a chain-level dependency (see LC-E-F-03).

**Headline result:** no new Critical/High on this surface. The two frontier signature findings that live in the Coinbase lib were **independently re-derived from source and confirmed** (not merely trusted from the log): **LC-E-F-01 = Fable-E-01** (ERC-1271 verifies the raw digest — no `address(this)` binding) and **LC-E-F-02 = Fable-E-03** (ECDSA path accepts high-s). Two additional config-contingent items were found (P-256 verifier deployment dependency; `walletConfig` mutation orphaning). The factory's CREATE2 determinism defeats every reorg/front-run/squat hypothesis in the task brief.

## Checklist coverage

- **Categories walked (9):** Attacker's Mindset (25), Basics (135), Heuristics (17), Signature (5), Low Level (5), External Call (14), Hash/Merkle (5) — plus targeted re-reads of the Solady `WebAuthn` / `P256` / `SignatureCheckerLib` source. **~206 items.**
- **Categories not loaded (4):** DeFi, Token, Integrations, Timelock/Multi-chain — **not applicable**: neither unit handles ERC20/4626 accounting, oracle pricing, AMM/lending, or bridge messaging. Partial walk by design.
- **Result:** 0 Critical, 0 High, 1 Medium (dup), 2 Low, 1 Informational-dup + Informational table, 2 config-risks, 2 open questions.

---

## Findings

### [Medium] LC-E-F-01 — ERC-1271 `isValidSignature` verifies the raw digest; no `address(this)`/chainId binding → cross-wallet replay  (ref: SOL-Signature-1, SOL-Signature-4, SOL-AM-ReplayAttack-2)
**Status: Confirmed (dup Fable-E-01).** Independently re-derived from source below.

- **Location:** `CoinbaseSmartWalletLib.sol:102-161` — EOA verify at `:146` (`SignatureCheckerLib.isValidSignatureNow(ownerAddr, hash, signatureData)`), passkey challenge at `:157` (`challenge: abi.encode(hash)`); the **unused** `replaySafeHash` / `domainSeparator` at `:303` / `:311`. Consumer: `AtomWallet.sol:341-346` passes the raw `hash` straight through.
- **Independent verification (not taken on faith from the frontier log):**
  1. `AtomWallet.isValidSignature(hash, sig)` calls `CoinbaseSmartWalletLib.isValidSignature(hash, sig)` with the **caller-supplied `hash` unmodified** (`AtomWallet.sol:342`).
  2. In the lib, the EOA branch verifies the signature over `hash` directly (`:146`); the passkey branch sets the WebAuthn challenge to `abi.encode(hash)` (`:157`) — again the raw hash, no wrapping.
  3. Grepped the lib: `replaySafeHash` and `domainSeparator` (the only functions that mix in `address(this)`+`block.chainid`) are **not referenced anywhere in the verification path** — they are dead code. `MESSAGE_TYPEHASH` (`:50`), `_hashStruct` (`:392`) and `_eip712Hash` (`:397`) are likewise reachable only from those two unused wrappers.
  4. Upstream Coinbase `ERC1271.isValidSignature` wraps the input as `_validateSignature(replaySafeHash(hash), sig)`. This port drops the wrap. Divergence confirmed.
- **Impact:** acceptance is **account-independent**. Any digest that a co-owned key validates on `walletA` validates identically on `walletB` when the same key/passkey owns both (the normal case — one principal claims many atom wallets). Under an EIP-712 integration whose digest does **not** bind the owner account (canonical case: Permit2 `SignatureTransfer`, which signs token/amount/spender/nonce/deadline + the Permit2 domain but takes the `owner` as a call argument), one legitimate signature can be replayed against a sibling wallet to move that sibling's tokens. Funds risk with realistic preconditions → Medium.
- **Exploit path (PoC outline):**
  1. Alice's key owns `walletA` and `walletB`; both hold token T and have approved Permit2.
  2. Alice signs one Permit2 permit intending `walletA`; digest `H` does not encode `walletA`.
  3. `walletA.isValidSignature(H, sig) == 0x1626ba7e` (intended).
  4. Attacker calls `Permit2.permitTransferFrom(permit, details, /*owner=*/walletB, sig)`; Permit2 calls `walletB.isValidSignature(H, sig)` → `0x1626ba7e` (Permit2 nonces are per-owner, so `walletB`'s space is fresh) → `walletB`'s T is transferred to the spender.
  5. Assertion that fails: a signature scoped to `walletA` authorizes a transfer on `walletB`.
- **Recommendation:** verify against `CoinbaseSmartWalletLib.replaySafeHash(hash, name, version)` (already implemented, currently dead) instead of the raw `hash`, or otherwise mix `address(this)`+chainId into both the ECDSA hash and the WebAuthn challenge. If raw-digest verification is deliberately retained, delete the `replaySafeHash`/`domainSeparator`/`MESSAGE_TYPEHASH` dead code and drop the Permit2/Seaport compatibility claim in the NatSpec at `AtomWallet.sol:333-334`.
- **Regression test:** two wallets, same owner key, one signature — validates on the target, must go **red** on the sibling once binding is added. Mutation-check: removing the `replaySafeHash` wrap must re-break the test.
- **Variant sweep:** EOA owner (`:146`) — same bug; passkey owner (`:157`, `abi.encode(hash)` challenge) — same bug; ERC-1271 contract owner via the Solady fallback in `isValidSignatureNow` — same bug. UserOp/4337 path — **safe**: `_validateSignature` hashes `userOpHash` (`AtomWallet.sol:498`), which the EntryPoint binds to `sender`+chainId+nonce, so ERC-1271↔UserOp reuse is additionally blocked by the `\x19Ethereum Signed Message` prefix.

### [Low] LC-E-F-03 — P-256 / WebAuthn owner path is inert unless the RIP-7212 precompile or Solady verifier is deployed on the Intuition chain  (ref: SOL-EC-12, SOL-AM-DOSA-6, SOL-LL-4)
**Status: Open — config/deployment gate. NEW (not in the frontier E-0x set).**

- **Location:** `CoinbaseSmartWalletLib.sol:154-157` → Solady `WebAuthn.verify` → `P256.verifySignature` (`lib/solady/src/utils/P256.sol:80-110`). Verifier addresses: RIP-7212 precompile `0x0000000000000000000000000000000000000100`; Solady Solidity verifier `0x000000000000D01eA45F9eFD5c54f037Fa57Ea1a`.
- **Analysis:** `P256.verifySignature` zeroizes the return slot, staticcalls the precompile, and — when `returndatasize()==0` and the CANARY has no code — staticcalls the Solady verifier. If **neither** the precompile nor the verifier contract exists on the chain, the staticcall to a codeless address "succeeds" with empty returndata, the return slot stays `0`, and `isValid := lt(gt(s,_HALF_N), eq(1, mload(0x00)))` evaluates to **`false`**. So the path **fails closed** — this is the correct SOL-LL-4 discipline (checks the returned value, not call success) and is **not** a security bug. **PASS on security; flagged as an operational gate.**
- **Impact:** if Intuition mainnet (`1155`) / testnet (`13579`) ship without the RIP-7212 precompile and without the Solady verifier at `0x000000000000D01eA45F9eFD5c54f037Fa57Ea1a`, **every** passkey-owner signature check silently returns `false`: passkey owners can never validate a UserOp or an ERC-1271 message. Users who register a P-256 key as their only owner would be locked out (address-owner path still works). No fund loss, no unauthorized access — a silent feature-dead condition.
- **Recommendation:** add a deploy-time assertion (or a `P256.hasPrecompileOrVerifier()` health check in the deploy/verify script) that the verifier infrastructure is present on each target chain before enabling passkey onboarding. Document the dependency next to `addOwnerPublicKey`.
- **Regression test:** fork/anvil without the verifier → assert a known-good passkey signature returns `false` (proves fail-closed); with the verifier deployed → asserts `true`.
- **Variant sweep:** affects both the ERC-1271 read path and the 4337 `_validateSignature` passkey branch; EOA-owner path unaffected.

### [Low] LC-E-F-04 — Mutating `walletConfig.entryPoint` / `atomWalletBeacon` after wallets exist orphans already-deployed wallets  (ref: SOL-Heuristics-11, SOL-Basics-Function-4, SOL-Basics-Initialization-1)
**Status: Open — trusted-admin footgun (timelocked). Note per the "trusted-admin ≠ attacker" mandate.**

- **Location:** `AtomWalletFactory.sol:144-161` (`_getDeploymentData` reads `entryPoint` and `atomWalletBeacon` from `MultiVaultCore.walletConfig()` on every call and folds them into the CREATE2 init code), driving `computeAtomWalletAddr` (`:125-133`). `walletConfig` is settable via `MultiVault.setWalletConfig` (`MultiVault.sol:835`, `onlyTimelock`).
- **Analysis:** the deterministic address is a function of `atomId` **and** the current `entryPoint` + `atomWalletBeacon` (via `initData` and the BeaconProxy constructor args). Routine implementation upgrades go through the **beacon** (`UpgradeableBeacon.upgradeTo`) and leave the beacon **address** unchanged, so addresses are stable across upgrades — the common case is safe. But if an admin ever swaps the `entryPoint` or the `atomWalletBeacon` **address** in `walletConfig` after wallets are live, `computeAtomWalletAddr(atomId)` returns a **new** address for every atom. `MultiVault`/`AtomWarden` would then compute/route to freshly-deployable addresses, and any previously-deployed wallet (with balances, deposit credit, or a completed claim) becomes unreachable through the protocol's address oracle.
- **Impact:** protocol-wide mis-attribution / stranded wallets on a single reconfig. Not attacker-reachable (4-of-8 Safe through a 3-day timelock, out-of-scope centralization per handoff §3) — filed as a consequence note, not an exploit.
- **Recommendation:** treat `entryPoint`/`atomWalletBeacon` as effectively immutable post-launch; if either must change, do it before any wallet is deployed, or add an explicit migration. Consider a NatSpec warning on `setWalletConfig` and a deploy-verify invariant that these two fields never change once atoms exist.
- **Variant sweep:** `multiVault` in the factory has no setter (immutable post-init) — safe; the exposure is only the `MultiVaultCore`-sourced `entryPoint`/`atomWalletBeacon`.

---

## Informational

| # | Location | Note (checklist ref) |
|---|---|---|
| I-1 | `CoinbaseSmartWalletLib.sol:146` | **ECDSA path accepts high-s / EIP-2098 malleable signatures** — **Confirmed (dup Fable-E-03).** Independently verified: Solady `SignatureCheckerLib` header states verbatim *"This implementation does NOT check if a signature is non-malleable"*; the EOA branch recovers via ecrecover with no `s <= N/2` clamp. Not an auth bypass (still needs the key) and irrelevant to the nonce-bound 4337 path; matters only to off-chain integrators that dedupe by signature bytes, and it compounds LC-E-F-01. **Note the asymmetry:** the **passkey** path is non-malleable — `P256.verifySignature` rejects `s > N/2` (`P256.sol:108`, and `WebAuthn.sol:142-143`). So malleability is EOA-only. (SOL-Signature-2, SOL-Basics-VI-OVI-3.) |
| I-2 | `CoinbaseSmartWalletLib.sol:50,303,311,392,397` | **Dead EIP-712 code.** `replaySafeHash`, `domainSeparator`, `_eip712Hash`, `_hashStruct`, `MESSAGE_TYPEHASH` are unreachable from the verification path (root cause of LC-E-F-01). Either wire `replaySafeHash` into `isValidSignature` (fixes LC-E-F-01) or delete them; shipping unused domain-separation helpers next to an unbound verifier is misleading. (SOL-Basics-Function-4, SOL-Heuristics-6.) |
| I-3 | `CoinbaseSmartWalletLib.sol:235-250,356-389` | **`removeOwnerByAddress` is O(n)** over `nextOwnerIndex` and duplicates `_removeAtIndex` as `_removeAtIndexMemory`. Bounded in practice (owner adds are owner-gated; expected single-digit signer counts) so not a forced-DoS vector, but note the unbounded-loop shape and the copy-paste. (SOL-Basics-AL-9, SOL-Heuristics-1.) |
| I-4 | `AtomWalletFactory.sol:110`; `IAtomWalletFactory.sol:20` | `AtomWalletDeployed` emits the `atomWallet` address **non-indexed** (only `atomId` indexed). Fine functionally; minor indexer ergonomics. Correctly emitted **only** on the fresh-deploy branch, not the idempotent early return. (SOL-Basics-Event-1.) |
| I-5 | `AtomWalletFactory.sol:74` | `deployAtomWallet` is **permissionless** — intentional and benign: deployment grants no ownership (pre-claim `owner()` resolves to the AtomWarden; ownership is set only by `AtomWallet.completeClaim`, `onlyAtomWarden`). Recorded so the missing access control is not mistaken for a gap. (SOL-Basics-AC-2, SOL-Basics-Function-9.) |

---

## Configuration risk (go-live decisions)

1. **P-256 verifier presence (LC-E-F-03).** Before enabling passkey onboarding on `1155` / `13579`, assert `P256.hasPrecompileOrVerifier()` (or check `0x000000000000D01eA45F9eFD5c54f037Fa57Ea1a` has code) in the deploy/verify script. Absent it, the passkey path is silently inert (fails closed).
2. **`walletConfig` immutability (LC-E-F-04).** Add a deploy-verify invariant that `entryPoint` and `atomWalletBeacon` never change after the first atom exists; route wallet-implementation changes through the beacon, never by swapping the beacon address.

---

## Open questions for the developer

- **OQ-1 (LC-E-F-01 remediation intent).** Is raw-digest ERC-1271 deliberate? If yes, the Permit2/Seaport compatibility claim at `AtomWallet.sol:333-334` should be withdrawn and the dead `replaySafeHash` machinery removed; if no, wrap the digest with `replaySafeHash(hash, name, version)` in `CoinbaseSmartWalletLib.isValidSignature`. The two co-keyed-wallet exposure only bites when a user owns ≥2 wallets with the same key **and** uses an owner-unbound EIP-712 integration — confirm whether that combination is in the intended UX.
- **OQ-2 (verifier deployment).** Confirm the RIP-7212 precompile or the Solady verifier is deployed on both Intuition networks, and that address-owner claims remain the default so a passkey-only lockout is not user-reachable.

---

## Acknowledged non-issues (properties checked and cleared)

Each line is a task-brief hypothesis attempted and refuted, with the defending mechanism cited.

- **PASS — CREATE2 reorg safety** (SOL-Basics-BR-1). The factory uses `create2` with `salt = atomId` (`AtomWalletFactory.sol:102-104`), not `create`, and the init code is fully determined by `atomId` + protocol config (no attacker-influenced args). The same `atomId` yields the same wallet with the same owner-resolution across any reorg; nothing to steal by re-ordering. BR-1's prescribed fix ("use CREATE2") is already in place.
- **PASS — Deploy front-run / dust grief** (SOL-AM-FrA-1/2/3, SOL-Basics-Function-3). `deployAtomWallet` is idempotent (`code.length != 0 ⇒ return existing`, `:88-93`) and the init args are not caller-controllable, so a front-runner only pre-pays gas for the identical wallet. No parameter divergence, no ownership gain.
- **PASS — Malicious-code address squatting.** The CREATE2 preimage includes the **factory** as deployer (`:130`), so only the factory can produce the predicted address; an attacker cannot plant different bytecode there from any other account. Post-Cancun `selfdestruct` (EIP-6780) cannot vacate-and-reclaim it either.
- **PASS — Deploy-vs-`completeClaim` ordering hijack** (task brief, SOL-AM-FrA-2). `AtomWarden._getAtomWallet` requires `code.length != 0` before claiming; deployment sets no owner (`owner()` pre-claim = `multiVault.getAtomWarden()`), and `completeClaim` is `onlyAtomWarden`. Ordering deploy vs claim grants no capability.
- **PASS — `SignatureWrapper` decode never reverts on malformed input** (SOL-LL-1, SOL-Basics-VI-OVI-12). `isValidSignature` manually bounds-checks before `abi.decode`: `length >= 96` (`:105`), offset field `== 64` (`:112`), `dataLen <= length` (`:119`), and `length >= 96 + paddedDataLen` (`:121`) with overflow-safe padding (dataLen already bounded by length). The subsequent tuple decode cannot revert, and every failure returns `false` (ERC-4337 non-revert contract honored).
- **PASS — WebAuthn malformed-input handling** (SOL-LL-1, SOL-HMT-3). `WebAuthn.tryDecodeAuth` is non-reverting and leaves `clientDataJSON` empty on bad input, which makes `WebAuthn.verify` return `false`; unknown owner-bytes length returns `false` (`:160`). No revert, no fail-open.
- **PASS — Precompile return-data-size discipline** (SOL-LL-4). `P256.verifySignature` zeroizes the return slot before the staticcalls and decides on `eq(1, mload(0x00))`, **not** on call success — a non-existent precompile/verifier leaves the slot `0` ⇒ `false`. The sha256 chain in `WebAuthn.verify` guards with `if iszero(returndatasize()) { invalid() }` (`WebAuthn.sol:139`).
- **PASS — `abi.encode` vs `abi.encodePacked` hash-collision** (SOL-Basics-VI-SVI-4). The WebAuthn challenge `abi.encode(hash)` (`:157`) is a single fixed-size `bytes32` (no dynamic-type ambiguity); `computeAtomWalletAddr` (`:130`) and `_getDeploymentData` (`:160`) use `encodePacked` only for the canonical CREATE2 preimage / creation-code concatenation (all fixed-size or a single trailing blob) — no collidable multi-dynamic-arg hashing.
- **PASS — `ownerCount` underflow** (SOL-Basics-Math-7). `nextOwnerIndex - removedOwnersCount`: every removal targets an existing index (`_removeAtIndex` reverts `NoOwnerAtIndex` on a re-removal, `:360`), so `removedOwnersCount <= nextOwnerIndex` always holds.
- **PASS — Reentrancy in `deployAtomWallet`** (SOL-AM-ReentrancyAttack-2, SOL-EC-13). `AtomWallet.initialize` performs no external call that can re-enter the factory during BeaconProxy construction; the idempotency check + `create2` are effect-free until deployment. A re-entrant same-`atomId` deploy could not double-create (CREATE2 collision), and there is no state to corrupt.
- **PASS — `tx.origin`, delegatecall, `msg.value` in loops** (SOL-Basics-AC-7, SOL-EC-3/10/11). None present. The factory's only assembly is the `create2` deploy; the library's assembly is memory-safe storage-pointer / word reads.
- **Cross-ref (dup Fable-E-02, sibling scope):** `CoinbaseSmartWalletLib.removeOwnerByAddress` is the mechanism behind `AtomWallet.transferOwnership` evicting the primary owner past the `removeOwnerAtIndex` guard. The composition/severity call belongs to the `AtomWallet` cluster-E sibling; not re-filed here.

---

## Appendix — methodology & provenance

- **Skill:** `smart-contract-audit` (project-local `.claude/skills/smart-contract-audit`; checklist adapted from `Cyfrin/audit-checklist`).
- **Round:** 3 (low-cost breadth backstop). Independent checklist walk; frontier cluster-E signature items were **re-derived from source**, not trusted from the log, and marked Confirmed where reproduced.
- **Verification performed:** full source read of both targets + `IAtomWalletFactory`; read of the consuming `AtomWallet.isValidSignature` / `_validateSignature`; **read of the actual Solady sources** (`WebAuthn.sol`, `P256.sol`, `SignatureCheckerLib.sol`) to confirm malleability behavior and precompile return-data handling; `forge inspect AtomWalletFactory storage-layout` (2 slots: `multiVault` @0, `__gap[50]` @1); grep of `deployAtomWallet`/`computeAtomWalletAddr`/`walletConfig` call sites across `src/`.
- **Not performed (recommended next):** a Foundry PoC for LC-E-F-01 (two co-keyed wallets + one signature validating on both) and a fork test for LC-E-F-03 (fail-closed without the verifier). Neither is required for this breadth pass; both are the gating tests named above.
- **Merge note:** map into the found→fixed log as `LC-E-F-01 … LC-E-F-04`. `LC-E-F-01` = **dup Fable-E-01** (Medium); `I-1` = **dup Fable-E-03** (Informational). `LC-E-F-03`/`LC-E-F-04` are net-new config-risk items from this round. Diligence-scale mapping: Medium→Medium, Low→Minor, Informational→Informational.

**VERDICT: PASS** (cluster E factory+lib surface — no High/Critical property failed; the one Medium (LC-E-F-01) is a confirmed duplicate of the frontier finding, on a funds path only under owner-unbound EIP-712 integrations, and is the single item worth fixing or explicitly risk-accepting (with the Permit2 claim removed) before external audit). Residual items are Low/Informational plus two config gates (P-256 verifier presence; `walletConfig` immutability).
