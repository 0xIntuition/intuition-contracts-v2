/*
================================================================================
  v1.1.0 core upgrade — Safe TX-Builder batch generator (Intuition Mainnet 1155)
================================================================================

  Emits every Safe transaction the v1.1.0 core upgrade needs, as numbered
  TX-Builder JSON batches written next to this file. Import them into the Safe
  in file order; `execution-order.md` in this folder is the canonical runbook.

  WHY THIS EXISTS. Hand-building these transactions in the Safe UI on a mainnet
  is the highest-human-error step of the rollout. Generating them from a
  committed script moves the effort from construction to verification.

  DESIGN RULES (deliberate; do not "improve" them away):

  1. SELF-CONTAINED. Every address, selector, and parameter is a named constant
     in this one file, each with a comment justifying its value. Nothing is
     imported from a shared registry. Duplication across release folders is
     CORRECT: each release folder is a frozen record of what was signed, and
     must not shift when a shared config is edited later.

  2. DETERMINISTIC AND BYTE-STABLE. No timestamps, no `createdAt`, no random
     salt, no run-dependent field anywhere in the output. Re-running on
     unchanged input produces byte-identical files, so a clean `git diff` after
     a regeneration is the proof that nothing drifted. This is the whole point.

     `meta.checksum` IS emitted, and does not conflict with this: it is derived
     purely from the file's content, so identical inputs yield an identical
     checksum. It is the value Safe's importer recomputes and compares, and
     omitting it makes the importer warn "file was modified" on every import —
     training signers to click through a tamper alert.

  3. OFFLINE. Pure ABI encoding from committed constants. No RPC, no network,
     no live state reads, no env vars. It runs correctly on a plane. Live values
     that this script depends on (timelock delay, role holders) are recorded as
     constants with the date they were verified, and re-checked by the runbook's
     pre-flight `cast` commands rather than fetched here.

  4. SELF-VERIFYING. Every file is decoded back immediately after it is written
     and the decoded arguments are printed beside their expected values. Running
     the generator is itself a verification pass.

  5. NEVER SILENT. Optional steps whose constants are unset are skipped with a
     loud WARNING naming what stays broken. A batch set that quietly omits the
     signer grants looks complete and is not.

  HARD ON-CHAIN CONSTRAINTS encoded here — see execution-order.md for the full
  reasoning:

  - Every registered curve upgrades in the SAME timelock operation as the
    MultiVault. The upgraded MultiVault probes the standardized fee-hook getters
    on the registry-resolved curve on every deposit and redeem; the live curve
    proxies run implementations that predate those selectors. Swap the vault
    without the curves and every deposit and redeem on the chain reverts.

  - Reinitializers are SEPARATE Admin-Safe transactions, never embedded in
    `upgradeAndCall`. Embedded reinit calldata executes via delegatecall with
    `msg.sender == ProxyAdmin`, which holds neither role, and reverts.

  USAGE (from the repository root):

    bun script/intuition/v1.1.0/safe-txs/generate-v1.1.0-safe-batches.ts

  The DEPLOYED IMPLEMENTATIONS block below is filled in AFTER the deploy script
  runs. Until then the generator refuses to emit anything.
================================================================================
*/

import { writeFileSync } from "node:fs";
import path from "node:path";

import { ethers } from "ethers";

/* ===================================================================== */
/*                        DEPLOYED IMPLEMENTATIONS                       */
/* ===================================================================== */

/*
  Filled in after running, from the repository root:

    forge script script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol:DeployCoreUpgradeImplementations \
      --optimizer-runs 10000 --rpc-url intuition --broadcast --slow --verify \
      --chain 1155 --verifier blockscout \
      --verifier-url 'https://intuition.calderaexplorer.xyz/api/'

  Paste the six printed implementation addresses here, then regenerate. The
  committed JSON diff then shows exactly what changed and nothing else.

  MultiVault is linked against MultiVaultLib, which Foundry auto-deploys and
  links as the first broadcast transaction. Its address lands in
  broadcast/DeployCoreUpgradeImplementations.s.sol/1155/run-latest.json. Record
  it below for the record and for verification — it is NOT referenced by any
  transaction (the linked MultiVault implementation address is what the batch
  points at), but a MultiVault implementation verified without its library is a
  half-verified contract, so the runbook checks it explicitly.
*/

const PLACEHOLDER = "0xPLACEHOLDER";

const DEPLOYED_IMPLEMENTATIONS = {
  multiVault: PLACEHOLDER,
  trustBonding: PLACEHOLDER,
  atomWarden: PLACEHOLDER,
  atomWallet: PLACEHOLDER,
  linearCurve: PLACEHOLDER,
  offsetProgressiveCurve: PLACEHOLDER,
};

/** Recorded for verification only; not referenced by any transaction. */
const MULTIVAULT_LIB = PLACEHOLDER;

/*
  The DynamicFeeFlatPriceCurve proxy, deployed separately by
  script/intuition/DeployDynamicFeeFlatPriceCurve.s.sol. It is a FRESH contract,
  not a proxy upgrade — nothing about it belongs in the timelock operation. Its
  only Safe transaction is the registry registration in step 08.
*/
const DYNAMIC_FEE_FLAT_PRICE_CURVE_PROXY = PLACEHOLDER;

/*
  NOTE ON FeeProxy — deliberately absent from this file.

  FeeProxy also ships with v1.1.0 and, like the curve above, is a fresh
  deployment rather than an upgrade. Unlike the curve it needs NO Safe
  transaction at all: its admin, treasury, MultiVault target and proxy admin are
  all set by the atomic `initialize` in script/intuition/FeeProxyDeploy.s.sol,
  and no core contract holds a reference to it, so there is nothing to register
  or wire afterwards.

  Recorded here so its absence reads as a decision rather than an oversight.
*/

/* ===================================================================== */
/*                      OPTIONAL / OPERATOR-SUPPLIED                     */
/* ===================================================================== */

/*
  These are not known at authoring time. Leave them empty and the corresponding
  steps are skipped with a loud WARNING; fill them in and the steps are emitted.

  Constants, not env vars: an env override would break byte-stability, so the
  same repo state would emit different JSON depending on someone's shell, and
  the value that actually got signed would not be recorded in git. Change a
  value by editing the constant and regenerating — the diff IS the review.
*/

/**
 * Backend signer keys to receive AtomWarden SIGNER_ROLE.
 *
 * `AtomWarden.reinitialize` leaves `signerCount == 0`, and
 * `claimWithAuthorization` reverts until at least `signatureThreshold` accounts
 * hold SIGNER_ROLE. Without these grants, wallet claims stay broken after an
 * otherwise-successful upgrade.
 */
const ATOM_WARDEN_SIGNERS: string[] = [];

/**
 * Target AtomWarden signature threshold, applied AFTER the signer grants.
 *
 * `setSignatureThreshold` reverts when `newThreshold > signerCount`, so the
 * signers must already hold the role. Leave at 0 to skip — `reinitialize`
 * already sets the threshold to ATOM_WARDEN_REINIT.signatureThreshold.
 */
const ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD = 0;

/**
 * A separate lower-threshold pauser Safe (e.g. 1-of-N or 2-of-N).
 *
 * PAUSER_ROLE is already granted to `generalConfig.admin` by
 * `MultiVault.reinitialize`, so this is purely additive. The admin is a
 * high-threshold Safe, which is a slow instrument for the one action whose
 * entire value is being fast.
 */
const MULTIVAULT_PAUSER_SAFE = "";

/* ===================================================================== */
/*                              CHAIN / SAFE                             */
/* ===================================================================== */

/** Intuition Mainnet. The v1.1.0 core upgrade is Intuition-chain-only. */
const CHAIN_ID = 1155;

/**
 * The Admin Safe — Gnosis Safe v1.3.0, 4-of-8. Verified on-chain 2026-07-27.
 *
 * This ONE address signs every batch in this folder, because it holds all of:
 *   - PROPOSER_ROLE, EXECUTOR_ROLE and CANCELLER_ROLE on the Upgrades Timelock
 *   - DEFAULT_ADMIN_ROLE on MultiVault and AtomWarden
 *     (`MultiVault.generalConfig().admin`, which also gates
 *      `AtomWarden.reinitialize` via an explicit msg.sender check)
 *   - `owner()` of the BondingCurveRegistry
 *
 * The upgrade/reinitializer split is therefore a ROLE separation executed
 * through two different instruments — timelock-mediated for the upgrades,
 * direct for everything else — NOT a separation between two Safe addresses.
 * Do not go looking for a second Safe; there isn't one.
 */
const ADMIN_SAFE = "0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb";

/**
 * Safe TX-Builder version. Matches the repo's previously-generated batch at
 * script/upgrades/out/test-intuition-trust-bonding-schedule.json.
 */
const TX_BUILDER_VERSION = "1.17.1";

/* ===================================================================== */
/*                             ADDRESS BOOK                              */
/* ===================================================================== */

/*
  Intuition Mainnet (1155). Mirrors `_addresses()` in
  script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol, which is the
  authoritative spec of this upgrade. Full addresses everywhere, never
  abbreviated — an abbreviated address cannot be verified by eye against a
  block explorer.
*/

const UPGRADES_TIMELOCK = "0x321e5d4b20158648dFd1f360A79CAFc97190bAd1";

/**
 * Parameters TimelockController — bootstrapped into `MultiVault.timelock` by
 * `MultiVault.reinitialize`. Distinct from the Upgrades Timelock: this one
 * gates parameter changes (verified minDelay 259200 = 3 days, 2026-07-27),
 * the other gates implementation swaps (604800 = 7 days).
 */
const PARAMETERS_TIMELOCK = "0x71b0F1ABebC2DaA0b7B5C3f9b72FAa1cd9F35FEA";

const MULTIVAULT_PROXY = "0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e";
const MULTIVAULT_PROXY_ADMIN = "0x1999faD6477e4fa9aA0FF20DaafC32F7B90005C8";
const TRUST_BONDING_PROXY = "0x635bBD1367B66E7B16a21D6E5A63C812fFC00617";
const TRUST_BONDING_PROXY_ADMIN = "0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62";
const ATOM_WARDEN_PROXY = "0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165";
const ATOM_WARDEN_PROXY_ADMIN = "0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A";

/** AtomWallet is a BEACON, not a transparent proxy — it swaps via `upgradeTo`. */
const ATOM_WALLET_BEACON = "0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF";

const BONDING_CURVE_REGISTRY = "0xd0E488Fb32130232527eedEB72f8cE2BFC0F9930";
const LINEAR_CURVE_PROXY = "0xc3eFD5471dc63d74639725f381f9686e3F264366";
const LINEAR_CURVE_PROXY_ADMIN = "0x6365D6eD0caf54d6290D866d56C043d3fCDc3B8c";
const OFFSET_PROGRESSIVE_CURVE_PROXY = "0x23afF95153aa88D28B9B97Ba97629E05D5fD335d";
const OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN = "0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7";

/* ===================================================================== */
/*                          TIMELOCK OPERATION                           */
/* ===================================================================== */

/**
 * `getMinDelay()` on the Upgrades Timelock. Verified on-chain 2026-07-27:
 * 604800 seconds = 7 days.
 *
 * `scheduleBatch` reverts if `delay < getMinDelay()`, so a delay increase
 * between now and execution would make step 01 revert — harmless, but re-check
 * it with the runbook's pre-flight command rather than trusting this constant.
 */
const TIMELOCK_DELAY_SECONDS = 604_800;

/** No predecessor: this operation does not depend on another timelock operation. */
const TIMELOCK_PREDECESSOR = `0x${"00".repeat(32)}`;

/**
 * Salt, derived from a fixed release string — deterministic, never random.
 *
 * The salt distinguishes this operation from any other with identical calls, so
 * it must be stable across regenerations (a random salt would change the
 * operation id on every run and break byte-stability). It is also what makes
 * the operation id reproducible by a reviewer from this file alone.
 */
const TIMELOCK_SALT_PREIMAGE = "intuition-core-upgrade-v1.1.0";
const TIMELOCK_SALT = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(TIMELOCK_SALT_PREIMAGE));

/* ===================================================================== */
/*                      ATOMWARDEN REINITIALIZE SEED                     */
/* ===================================================================== */

/*
  The known-good baseline the deploy script uses, with one deliberate
  divergence noted below. The admin can retune any of these through the regular
  setters afterwards, without an upgrade.
*/

const ATOM_WARDEN_REINIT = {
  /** 365 days. */
  claimWindow: 365 * 24 * 60 * 60,
  minFeeThreshold: 0,
  /** Must be > 0; `reinitialize` reverts on 0. */
  signatureThreshold: 1,
  /** 1 hour. */
  maxValidAfter: 60 * 60,
  /** 1 day. */
  maxValidUntil: 24 * 60 * 60,
  /*
	  DELIBERATE DIVERGENCE FROM THE DEPLOY SCRIPT. It defaults this to 0, which
	  DISABLES the per-window claim cap entirely. We ship the cap ARMED at 100
	  claims per 1-day window: the cap is one of the new v1.1.0 safety features,
	  and launching it inert would mean an external reviewer sees a new safety
	  control switched off in production. 100/day is deliberately generous —
	  high enough not to throttle legitimate claim volume, low enough to bound
	  abuse.
	*/
  maxClaimsPerWindow: 100,
  /** 1 day. Must be > 0. */
  claimCapWindow: 24 * 60 * 60,
};

/* ===================================================================== */
/*                             ROLE IDENTIFIERS                          */
/* ===================================================================== */

/** keccak256("SIGNER_ROLE") — AtomWarden. */
const SIGNER_ROLE = "0xe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f70";

/** keccak256("PAUSER_ROLE") — MultiVault. */
const PAUSER_ROLE = "0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a";

/* ===================================================================== */
/*                             ABI FRAGMENTS                             */
/* ===================================================================== */

/*
  Human-readable fragments, matching the style already used across
  script/upgrades/. Kept minimal and local so a reviewer can check each
  signature against the contract source without leaving this file.
*/

const PROXY_ADMIN_ABI = ["function upgradeAndCall(address proxy, address implementation, bytes data) external payable"];

const BEACON_ABI = ["function upgradeTo(address newImplementation) external"];

const TIMELOCK_ABI = [
  "function scheduleBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt, uint256 delay) external",
  "function executeBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) external payable",
];

const MULTIVAULT_ABI = [
  "function reinitialize(address _timelock) external",
  "function grantRole(bytes32 role, address account) external",
];

const ATOM_WARDEN_ABI = [
  "function reinitialize(uint256 _claimWindow, uint256 _minFeeThreshold, uint256 _signatureThreshold, uint48 _maxValidAfter, uint48 _maxValidUntil, uint256 _maxClaimsPerWindow, uint256 _claimCapWindow) external",
  "function grantRole(bytes32 role, address account) external",
  "function setSignatureThreshold(uint256 newThreshold) external",
];

const REGISTRY_ABI = ["function addBondingCurve(address bondingCurve) external"];

const proxyAdmin = new ethers.utils.Interface(PROXY_ADMIN_ABI);
const beacon = new ethers.utils.Interface(BEACON_ABI);
const timelock = new ethers.utils.Interface(TIMELOCK_ABI);
const multiVault = new ethers.utils.Interface(MULTIVAULT_ABI);
const atomWarden = new ethers.utils.Interface(ATOM_WARDEN_ABI);
const registry = new ethers.utils.Interface(REGISTRY_ABI);

/* ===================================================================== */
/*                                 TYPES                                 */
/* ===================================================================== */

type SafeTransaction = {
  to: string;
  value: string;
  data: string;
  contractMethod: null;
  contractInputsValues: null;
};

type SafeBatchFile = {
  version: string;
  chainId: string;
  meta: {
    name: string;
    description: string;
    txBuilderVersion: string;
    createdFromSafeAddress: string;
    createdFromOwnerAddress: string;
    checksum: string | null;
  };
  transactions: SafeTransaction[];
};

/** One decoded transaction, for the self-verification printout. */
type DecodedTransaction = {
  iface: ethers.utils.Interface;
  label: string;
};

type Batch = {
  step: string;
  slug: string;
  name: string;
  description: string;
  transactions: SafeTransaction[];
  decoders: DecodedTransaction[];
};

/* ===================================================================== */
/*                               HELPERS                                 */
/* ===================================================================== */

const isPlaceholder = (value: string): boolean =>
  value === PLACEHOLDER || value === "" || !ethers.utils.isAddress(value) || value === ethers.constants.AddressZero;

/** EIP-55 checksum. A checksummed address is verifiable by eye; a lowercase one is not. */
const addr = (value: string): string => ethers.utils.getAddress(value);

const tx = (to: string, data: string): SafeTransaction => ({
  to: addr(to),
  value: "0",
  data: data.toLowerCase(),
  contractMethod: null,
  contractInputsValues: null,
});

/* ===================================================================== */
/*                          THE TIMELOCK PAYLOADS                        */
/* ===================================================================== */

/**
 * The six upgrades, in the order the deploy script prints them.
 *
 * ALL SIX MOVE TOGETHER. `LinearCurve` and `OffsetProgressiveCurve` are not
 * optional extras: the upgraded MultiVault calls `hasDepositFeeHook()` /
 * `hasRedeemFeeHook()` on the registry-resolved curve on EVERY deposit and
 * redeem, and the live curve implementations predate those selectors. Removing
 * either curve from this array bricks every deposit and redeem on the chain.
 *
 * Each upgrade carries EMPTY calldata. The reinitializers are separate
 * Admin-Safe transactions (steps 03 and 04) because embedded reinit calldata
 * would execute via delegatecall with `msg.sender == ProxyAdmin`, which holds
 * neither role, and revert.
 */
const buildUpgradeCalls = (): Array<{ label: string; target: string; payload: string }> => [
  {
    label: "MultiVault upgrade",
    target: MULTIVAULT_PROXY_ADMIN,
    payload: proxyAdmin.encodeFunctionData("upgradeAndCall", [
      addr(MULTIVAULT_PROXY),
      addr(DEPLOYED_IMPLEMENTATIONS.multiVault),
      "0x",
    ]),
  },
  {
    label: "TrustBonding upgrade",
    target: TRUST_BONDING_PROXY_ADMIN,
    payload: proxyAdmin.encodeFunctionData("upgradeAndCall", [
      addr(TRUST_BONDING_PROXY),
      addr(DEPLOYED_IMPLEMENTATIONS.trustBonding),
      "0x",
    ]),
  },
  {
    label: "AtomWarden upgrade",
    target: ATOM_WARDEN_PROXY_ADMIN,
    payload: proxyAdmin.encodeFunctionData("upgradeAndCall", [
      addr(ATOM_WARDEN_PROXY),
      addr(DEPLOYED_IMPLEMENTATIONS.atomWarden),
      "0x",
    ]),
  },
  {
    label: "AtomWallet beacon upgrade",
    target: ATOM_WALLET_BEACON,
    payload: beacon.encodeFunctionData("upgradeTo", [addr(DEPLOYED_IMPLEMENTATIONS.atomWallet)]),
  },
  {
    label: "LinearCurve upgrade [REQUIRED with MultiVault]",
    target: LINEAR_CURVE_PROXY_ADMIN,
    payload: proxyAdmin.encodeFunctionData("upgradeAndCall", [
      addr(LINEAR_CURVE_PROXY),
      addr(DEPLOYED_IMPLEMENTATIONS.linearCurve),
      "0x",
    ]),
  },
  {
    label: "OffsetProgressiveCurve upgrade [REQUIRED with MultiVault]",
    target: OFFSET_PROGRESSIVE_CURVE_PROXY_ADMIN,
    payload: proxyAdmin.encodeFunctionData("upgradeAndCall", [
      addr(OFFSET_PROGRESSIVE_CURVE_PROXY),
      addr(DEPLOYED_IMPLEMENTATIONS.offsetProgressiveCurve),
      "0x",
    ]),
  },
];

/**
 * The timelock operation id, as TimelockController computes it:
 * `keccak256(abi.encode(targets, values, payloads, predecessor, salt))`.
 *
 * Printed so a signer can check `isOperationReady(id)` on-chain between step 01
 * and step 02 rather than trusting that the two batches describe the same
 * operation. They do by construction — both are built from this one array — but
 * the id makes that checkable rather than merely asserted.
 */
const operationId = (targets: string[], values: string[], payloads: string[]): string =>
  ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["address[]", "uint256[]", "bytes[]", "bytes32", "bytes32"],
      [targets, values, payloads, TIMELOCK_PREDECESSOR, TIMELOCK_SALT],
    ),
  );

/* ===================================================================== */
/*                             BATCH BUILDERS                            */
/* ===================================================================== */

const warnings: string[] = [];

const buildBatches = (): Batch[] => {
  const batches: Batch[] = [];

  const calls = buildUpgradeCalls();
  const targets = calls.map((call) => addr(call.target));
  const values = calls.map(() => "0");
  const payloads = calls.map((call) => call.payload);
  const opId = operationId(targets, values, payloads);

  /* --- 01: schedule ------------------------------------------------- */

  batches.push({
    step: "01",
    slug: "upgrades-timelock-schedule",
    name: "v1.1.0 [01] Upgrades Timelock — scheduleBatch (6 upgrades)",
    description: [
      "EXECUTE NOW. Signed by the Admin Safe acting as the Upgrades Timelock PROPOSER.",
      "",
      `Schedules ONE atomic timelock operation containing all six v1.1.0 implementation swaps: MultiVault, TrustBonding, AtomWarden, AtomWallet (beacon), LinearCurve and OffsetProgressiveCurve. Operation id ${opId}.`,
      "",
      "ALL SIX MUST MOVE TOGETHER. The upgraded MultiVault probes the standardized fee-hook getters on the registry-resolved curve on every deposit and redeem, and the live curve implementations predate those selectors. A batch missing either curve makes every deposit and redeem on the chain revert. This is why scheduleBatch/executeBatch is used rather than six separate schedule/execute operations: executeBatch succeeds or reverts as a unit.",
      "",
      `Scheduling changes nothing on its own — it only starts the ${TIMELOCK_DELAY_SECONDS}-second (7-day) timelock. Nothing is upgraded until step 02 executes. Safe to sign and execute immediately.`,
      "",
      "NEXT: wait out the delay, verify isOperationReady(id), then import step 02.",
    ].join("\n"),
    transactions: [
      tx(
        UPGRADES_TIMELOCK,
        timelock.encodeFunctionData("scheduleBatch", [
          targets,
          values,
          payloads,
          TIMELOCK_PREDECESSOR,
          TIMELOCK_SALT,
          TIMELOCK_DELAY_SECONDS,
        ]),
      ),
    ],
    decoders: [{ iface: timelock, label: "TimelockController.scheduleBatch" }],
  });

  /* --- 02: execute -------------------------------------------------- */

  batches.push({
    step: "02",
    slug: "upgrades-timelock-execute",
    name: "v1.1.0 [02] Upgrades Timelock — executeBatch (6 upgrades)",
    description: [
      "HOLD. Do not sign until step 01 has executed and the timelock delay has fully elapsed.",
      "",
      `Executes the operation scheduled in step 01 — id ${opId}. Identical targets, values and payloads; the timelock recomputes the id from them, so any divergence from step 01 makes this revert rather than execute something unintended.`,
      "",
      `DEPENDS ON: step 01, plus ${TIMELOCK_DELAY_SECONDS} seconds (7 days) elapsed. Verify with isOperationReady(${opId}) on the Upgrades Timelock before signing; it returns false until the operation is ripe.`,
      "",
      "THIS IS THE UPGRADE. All six implementations swap in one transaction. Immediately afterwards, verify a deposit and a redeem still succeed on BOTH curve ids before proceeding — that is the property the atomic batch exists to protect.",
      "",
      "NEXT: steps 03 and 04 (the reinitializers). The upgrade is NOT complete without them.",
    ].join("\n"),
    transactions: [
      tx(
        UPGRADES_TIMELOCK,
        timelock.encodeFunctionData("executeBatch", [targets, values, payloads, TIMELOCK_PREDECESSOR, TIMELOCK_SALT]),
      ),
    ],
    decoders: [{ iface: timelock, label: "TimelockController.executeBatch" }],
  });

  /* --- 03: MultiVault.reinitialize ---------------------------------- */

  batches.push({
    step: "03",
    slug: "admin-safe-multivault-reinitialize",
    name: "v1.1.0 [03] MultiVault.reinitialize",
    description: [
      "HOLD until step 02 has executed and been verified. Signed by the Admin Safe DIRECTLY (it holds DEFAULT_ADMIN_ROLE) — not through the timelock.",
      "",
      `Bootstraps MultiVault.timelock to the Parameters TimelockController ${PARAMETERS_TIMELOCK} and grants PAUSER_ROLE to generalConfig.admin.`,
      "",
      "This is a SEPARATE transaction rather than calldata embedded in the step 01/02 upgradeAndCall, and must stay that way: embedded reinit calldata executes via delegatecall with msg.sender == ProxyAdmin, which holds neither role, and reverts.",
      "",
      "REQUIRED — the upgrade is not complete without this.",
      "",
      "DEPENDS ON: step 02.",
    ].join("\n"),
    transactions: [tx(MULTIVAULT_PROXY, multiVault.encodeFunctionData("reinitialize", [addr(PARAMETERS_TIMELOCK)]))],
    decoders: [{ iface: multiVault, label: "MultiVault.reinitialize" }],
  });

  /* --- 04: AtomWarden.reinitialize ---------------------------------- */

  batches.push({
    step: "04",
    slug: "admin-safe-atomwarden-reinitialize",
    name: "v1.1.0 [04] AtomWarden.reinitialize",
    description: [
      "HOLD until step 02 has executed and been verified. Signed by the Admin Safe DIRECTLY — AtomWarden.reinitialize is gated on msg.sender == MultiVault.generalConfig().admin, which is this Safe.",
      "",
      `Seeds the claim parameters: claimWindow ${ATOM_WARDEN_REINIT.claimWindow}s (365 days), minFeeThreshold ${ATOM_WARDEN_REINIT.minFeeThreshold}, signatureThreshold ${ATOM_WARDEN_REINIT.signatureThreshold}, maxValidAfter ${ATOM_WARDEN_REINIT.maxValidAfter}s (1 hour), maxValidUntil ${ATOM_WARDEN_REINIT.maxValidUntil}s (1 day), maxClaimsPerWindow ${ATOM_WARDEN_REINIT.maxClaimsPerWindow}, claimCapWindow ${ATOM_WARDEN_REINIT.claimCapWindow}s (1 day).`,
      "",
      `NOTE maxClaimsPerWindow = ${ATOM_WARDEN_REINIT.maxClaimsPerWindow}: the per-window claim cap ships ARMED. The deploy script defaults this to 0, which disables the cap entirely. The cap is one of the new v1.1.0 safety features and is deliberately launched active; the admin can retune it through the regular setter without an upgrade.`,
      "",
      "AFTER THIS, signerCount == 0 and signed claims REVERT until step 05 grants SIGNER_ROLE. That is safe-by-default and intentional, but it means the upgrade is not operationally finished here.",
      "",
      "REQUIRED — the upgrade is not complete without this.",
      "",
      "DEPENDS ON: step 02. NEXT: step 05.",
    ].join("\n"),
    transactions: [
      tx(
        ATOM_WARDEN_PROXY,
        atomWarden.encodeFunctionData("reinitialize", [
          ATOM_WARDEN_REINIT.claimWindow,
          ATOM_WARDEN_REINIT.minFeeThreshold,
          ATOM_WARDEN_REINIT.signatureThreshold,
          ATOM_WARDEN_REINIT.maxValidAfter,
          ATOM_WARDEN_REINIT.maxValidUntil,
          ATOM_WARDEN_REINIT.maxClaimsPerWindow,
          ATOM_WARDEN_REINIT.claimCapWindow,
        ]),
      ),
    ],
    decoders: [{ iface: atomWarden, label: "AtomWarden.reinitialize" }],
  });

  /* --- 05: AtomWarden signer grants --------------------------------- */

  if (ATOM_WARDEN_SIGNERS.length === 0) {
    warnings.push(
      "SKIPPED step 05 (AtomWarden SIGNER_ROLE grants) — ATOM_WARDEN_SIGNERS is empty.\n" +
        "    CONSEQUENCE: signerCount stays 0 after step 04, so claimWithAuthorization REVERTS\n" +
        "    and wallet claims stay BROKEN after an otherwise-successful upgrade.\n" +
        "    Fill in ATOM_WARDEN_SIGNERS and regenerate before the rollout.",
    );
  } else {
    batches.push({
      step: "05",
      slug: "admin-safe-atomwarden-grant-signer-role",
      name: "v1.1.0 [05] AtomWarden — grant SIGNER_ROLE",
      description: [
        "HOLD until step 04 has executed. Signed by the Admin Safe DIRECTLY (DEFAULT_ADMIN_ROLE).",
        "",
        `Grants SIGNER_ROLE to ${ATOM_WARDEN_SIGNERS.length} backend signer key(s). These are the same call repeated per address, which is why they share one batch; every other Admin-Safe step is one transaction per file.`,
        "",
        "WHY THIS IS PART OF THE RELEASE, NOT CLEANUP: step 04 leaves signerCount == 0, and claimWithAuthorization reverts until at least signatureThreshold accounts hold SIGNER_ROLE. Skip this and wallet claims stay broken.",
        "",
        "DEPENDS ON: step 04. NEXT: step 06 — and the 05-before-06 order is load-bearing, not stylistic. setSignatureThreshold reverts when newThreshold > signerCount, so these grants must be executed and confirmed FIRST.",
      ].join("\n"),
      transactions: ATOM_WARDEN_SIGNERS.map((signer) =>
        tx(ATOM_WARDEN_PROXY, atomWarden.encodeFunctionData("grantRole", [SIGNER_ROLE, addr(signer)])),
      ),
      decoders: ATOM_WARDEN_SIGNERS.map(() => ({
        iface: atomWarden,
        label: "AtomWarden.grantRole",
      })),
    });
  }

  /* --- 06: AtomWarden.setSignatureThreshold ------------------------- */

  if (ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD === 0) {
    warnings.push(
      "SKIPPED step 06 (AtomWarden.setSignatureThreshold) — ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD is 0.\n" +
        `    CONSEQUENCE: the threshold stays at ${ATOM_WARDEN_REINIT.signatureThreshold}, as set by step 04.\n` +
        "    That is a valid end state, but it is a DEFAULT rather than a decision. Set the\n" +
        "    constant if the intended production threshold differs.",
    );
  } else if (ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD > ATOM_WARDEN_SIGNERS.length) {
    /*
		  Fail loudly rather than emit a transaction that is guaranteed to revert
		  on-chain. `setSignatureThreshold` reverts when newThreshold > signerCount,
		  and signerCount after step 05 is exactly ATOM_WARDEN_SIGNERS.length.
		*/
    throw new Error(
      `ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD (${ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD}) exceeds the ` +
        `number of signers granted in step 05 (${ATOM_WARDEN_SIGNERS.length}). ` +
        "setSignatureThreshold would revert on-chain. Add signers or lower the threshold.",
    );
  } else {
    batches.push({
      step: "06",
      slug: "admin-safe-atomwarden-set-signature-threshold",
      name: "v1.1.0 [06] AtomWarden.setSignatureThreshold",
      description: [
        "HOLD until step 05 has EXECUTED AND CONFIRMED. Signed by the Admin Safe DIRECTLY (DEFAULT_ADMIN_ROLE).",
        "",
        `Raises the authorized-claim signature threshold to ${ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD}.`,
        "",
        `ORDER IS LOAD-BEARING. setSignatureThreshold reverts when newThreshold > signerCount. Step 05 grants the roles that make signerCount ${ATOM_WARDEN_SIGNERS.length}; executing this batch before step 05 lands REVERTS on-chain. Confirm AtomWarden.signerCount() >= ${ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD} before signing.`,
        "",
        "DEPENDS ON: step 05.",
      ].join("\n"),
      transactions: [
        tx(
          ATOM_WARDEN_PROXY,
          atomWarden.encodeFunctionData("setSignatureThreshold", [ATOM_WARDEN_TARGET_SIGNATURE_THRESHOLD]),
        ),
      ],
      decoders: [{ iface: atomWarden, label: "AtomWarden.setSignatureThreshold" }],
    });
  }

  /* --- 07: MultiVault pauser grant ---------------------------------- */

  if (MULTIVAULT_PAUSER_SAFE === "") {
    warnings.push(
      "SKIPPED step 07 (MultiVault PAUSER_ROLE grant) — MULTIVAULT_PAUSER_SAFE is empty.\n" +
        "    CONSEQUENCE: PAUSER_ROLE is held ONLY by the 4-of-8 Admin Safe (granted by step 03).\n" +
        "    Pausing remains possible, but only through a high-threshold Safe — a slow instrument\n" +
        "    for the one action whose entire value is being fast. Not a correctness problem.",
    );
  } else {
    batches.push({
      step: "07",
      slug: "admin-safe-multivault-grant-pauser-role",
      name: "v1.1.0 [07] MultiVault — grant PAUSER_ROLE to the pauser Safe",
      description: [
        "HOLD until step 03 has executed. Signed by the Admin Safe DIRECTLY (DEFAULT_ADMIN_ROLE).",
        "",
        `Grants PAUSER_ROLE to ${addr(MULTIVAULT_PAUSER_SAFE)}, a separate lower-threshold Safe for faster incident response.`,
        "",
        "PURELY ADDITIVE and non-urgent: step 03 already granted PAUSER_ROLE to generalConfig.admin, so the protocol is pausable without this. This exists because the admin is a high-threshold Safe, which is slow for an action whose value is speed.",
        "",
        "DEPENDS ON: step 03.",
      ].join("\n"),
      transactions: [
        tx(MULTIVAULT_PROXY, multiVault.encodeFunctionData("grantRole", [PAUSER_ROLE, addr(MULTIVAULT_PAUSER_SAFE)])),
      ],
      decoders: [{ iface: multiVault, label: "MultiVault.grantRole" }],
    });
  }

  /* --- 08: register the new curve ----------------------------------- */

  if (isPlaceholder(DYNAMIC_FEE_FLAT_PRICE_CURVE_PROXY)) {
    warnings.push(
      "SKIPPED step 08 (BondingCurveRegistry.addBondingCurve) — DYNAMIC_FEE_FLAT_PRICE_CURVE_PROXY\n" +
        "    is still a placeholder. CONSEQUENCE: the DynamicFeeFlatPriceCurve is not registered and\n" +
        "    is unusable. This is EXPECTED while the curve has not been deployed; it is a separate\n" +
        "    follow-up executed after the upgrade is confirmed, not part of the upgrade itself.",
    );
  } else {
    batches.push({
      step: "08",
      slug: "admin-safe-register-dynamic-fee-curve",
      name: "v1.1.0 [08] BondingCurveRegistry.addBondingCurve — DynamicFeeFlatPriceCurve",
      description: [
        "HOLD. Execute only AFTER the upgrade (steps 01-04) is confirmed live and healthy. Signed by the Admin Safe DIRECTLY (it is the registry owner).",
        "",
        `Registers the DynamicFeeFlatPriceCurve proxy ${addr(DYNAMIC_FEE_FLAT_PRICE_CURVE_PROXY)} under a fresh curve id.`,
        "",
        "DELIBERATELY NOT BUNDLED WITH THE UPGRADE. The upgrade batch carries a hard atomicity requirement and stays exactly as large as that requires and no larger. Registering a curve into a registry that the upgraded MultiVault has not yet been confirmed to read correctly also inverts the natural verification order.",
        "",
        "IRREVERSIBLE. Curve ids are append-only and cannot be removed. Before signing, verify on-chain: (a) the curve's multiVault() equals the production MultiVault proxy — its record hooks are onlyMultiVault, and a miswired curve makes every deposit and redeem on its id revert forever; (b) the curve's owner() has been transferred off the deploying EOA to this Safe; (c) a fork simulation of this transaction followed by a deposit on the new curve id succeeds.",
        "",
        "DEPENDS ON: steps 01-04 executed and verified.",
      ].join("\n"),
      transactions: [
        tx(
          BONDING_CURVE_REGISTRY,
          registry.encodeFunctionData("addBondingCurve", [addr(DYNAMIC_FEE_FLAT_PRICE_CURVE_PROXY)]),
        ),
      ],
      decoders: [{ iface: registry, label: "BondingCurveRegistry.addBondingCurve" }],
    });
  }

  return batches;
};

/* ===================================================================== */
/*                          WRITE + SELF-VERIFY                          */
/* ===================================================================== */

/*
  Safe's TX-Builder checksum, reimplemented locally (self-contained by design).

  The importer recomputes this over the file — with `meta.checksum` removed and
  `meta.name` nulled — and shows a "file was modified" warning when it does not
  match. Emitting `null` would trigger that warning on every import and teach
  signers to click through a tamper alert, which is the opposite of what this
  tooling is for.

  The checksum is derived purely from the file's content, so it stays
  byte-stable: identical inputs produce an identical checksum.

  The serializer is Safe's, quirks included — keys sorted, the key array emitted
  first, then each value followed by a TRAILING comma. It must be reproduced
  exactly or the value will not match what the importer computes.
*/

const stringifyReplacer = (_key: string, value: unknown): unknown => (value === undefined ? null : value);

const serializeJSONObject = (value: unknown): string => {
  if (Array.isArray(value)) {
    return `[${value.map((item) => serializeJSONObject(item)).join(",")}]`;
  }

  if (typeof value === "object" && value !== null) {
    const keys = Object.keys(value).sort();
    let serialized = `{${JSON.stringify(keys, stringifyReplacer)}`;

    for (const key of keys) {
      serialized += `${serializeJSONObject((value as Record<string, unknown>)[key])},`;
    }

    return `${serialized}}`;
  }

  return `${JSON.stringify(value, stringifyReplacer)}`;
};

const calculateChecksum = (batchFile: SafeBatchFile): string => {
  const { checksum: _omitted, ...metaWithoutChecksum } = batchFile.meta;

  return ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes(serializeJSONObject({ ...batchFile, meta: { ...metaWithoutChecksum, name: null } })),
  );
};

const toFile = (batch: Batch): SafeBatchFile => {
  const batchFile: SafeBatchFile = {
    version: "1.0",
    chainId: String(CHAIN_ID),
    meta: {
      name: batch.name,
      description: batch.description,
      txBuilderVersion: TX_BUILDER_VERSION,
      createdFromSafeAddress: addr(ADMIN_SAFE),
      createdFromOwnerAddress: "",
      checksum: null,
    },
    transactions: batch.transactions,
  };

  return { ...batchFile, meta: { ...batchFile.meta, checksum: calculateChecksum(batchFile) } };
};

/**
 * Decodes each written transaction back from its calldata and prints the
 * arguments. A mis-encoded parameter is then caught here, at authoring time,
 * rather than in the Safe UI or on-chain.
 */
const printDecoded = (batch: Batch): void => {
  batch.transactions.forEach((transaction, index) => {
    const decoder = batch.decoders[index];
    const parsed = decoder.iface.parseTransaction({ data: transaction.data });

    console.log(`    tx[${index}] -> ${transaction.to}`);
    console.log(`      method : ${decoder.label}(${parsed.functionFragment.inputs.map((i) => i.type).join(",")})`);
    console.log(`      value  : ${transaction.value}`);
    parsed.functionFragment.inputs.forEach((input, argIndex) => {
      const value = parsed.args[argIndex];
      const rendered = Array.isArray(value)
        ? `[\n${value.map((item: unknown) => `          ${String(item)}`).join("\n")}\n        ]`
        : String(value);
      console.log(`      ${input.name} (${input.type}) = ${rendered}`);
    });
  });
};

const main = (): void => {
  console.log("");
  console.log("v1.1.0 core upgrade — Safe TX-Builder batch generator");
  console.log(`  chain          : ${CHAIN_ID} (Intuition Mainnet)`);
  console.log(`  signing Safe   : ${addr(ADMIN_SAFE)}`);
  console.log(`  timelock       : ${addr(UPGRADES_TIMELOCK)}`);
  console.log(`  timelock delay : ${TIMELOCK_DELAY_SECONDS}s`);
  console.log(`  salt preimage  : "${TIMELOCK_SALT_PREIMAGE}"`);
  console.log(`  salt           : ${TIMELOCK_SALT}`);
  console.log("");

  /*
	  The guard. A batch built against a placeholder implementation address is
	  precisely the failure mode this tooling exists to prevent, so emitting is
	  impossible until every address is real.
	*/
  const missing = Object.entries(DEPLOYED_IMPLEMENTATIONS)
    .filter(([, value]) => isPlaceholder(value))
    .map(([key]) => key);

  if (missing.length > 0) {
    console.error("REFUSING TO EMIT — the DEPLOYED IMPLEMENTATIONS block is not filled in.");
    console.error("");
    console.error("  Still placeholder / zero / malformed:");
    for (const key of missing) {
      console.error(`    - ${key}`);
    }
    console.error("");
    console.error("  Run the deploy script, then paste the printed implementation addresses into");
    console.error("  the DEPLOYED IMPLEMENTATIONS block at the top of this file and re-run:");
    console.error("");
    console.error(
      "    forge script script/intuition/v1.1.0/DeployCoreUpgradeImplementations.s.sol:DeployCoreUpgradeImplementations \\",
    );
    console.error("      --optimizer-runs 10000 --rpc-url intuition --broadcast --slow --verify \\");
    console.error("      --chain 1155 --verifier blockscout \\");
    console.error("      --verifier-url 'https://intuition.calderaexplorer.xyz/api/'");
    console.error("");
    console.error("  No files were written.");
    process.exit(1);
  }

  if (isPlaceholder(MULTIVAULT_LIB)) {
    warnings.push(
      "MULTIVAULT_LIB is not recorded. It is not referenced by any transaction, but the\n" +
        "    MultiVault implementation is LINKED against it — record the address from\n" +
        "    broadcast/.../run-latest.json so the library can be verified alongside the\n" +
        "    implementation. A linked contract verified without its library is half-verified.",
    );
  }

  const batches = buildBatches();
  const outDir = import.meta.dir;

  for (const batch of batches) {
    const fileName = `${batch.step}-intuition-${CHAIN_ID}-${batch.slug}.json`;
    const outPath = path.join(outDir, fileName);

    /*
		  Tab-indented with a trailing newline, matching the repo's existing Safe
		  batch writer. No `createdAt`: it is run-dependent and would break
		  byte-stability. The checksum IS emitted — it is derived from the content,
		  so it is stable, and omitting it makes Safe warn on every import.
		*/
    writeFileSync(outPath, `${JSON.stringify(toFile(batch), null, "\t")}\n`, "utf8");

    console.log(`  wrote ${fileName}`);
    console.log(`    name : ${batch.name}`);
    printDecoded(batch);
    console.log("");
  }

  if (warnings.length > 0) {
    console.log("");
    for (const warning of warnings) {
      console.log(`WARNING: ${warning}`);
      console.log("");
    }
  }

  console.log("");
  console.log(`Wrote ${batches.length} batch file(s) to this folder.`);
  console.log("");
  console.log("BEFORE SIGNING ANYTHING:");
  console.log("  - Decode every transaction in the Safe UI and compare against the printout above.");
  console.log("  - Cross-check every address against a block explorer. Never trust an abbreviation.");
  console.log("  - Simulate each batch before signing it.");
  console.log("  - Follow execution-order.md. The order is load-bearing, not advisory.");
  console.log("");
};

main();
