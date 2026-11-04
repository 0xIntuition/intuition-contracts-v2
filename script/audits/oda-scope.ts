/**
 * oda-scope.ts — derive the One Dollar Audit (ODA) scope from the LIVE state of
 * pull request #153, and build the per-job plan.
 *
 * The scope is intentionally NOT hardcoded to the handoff's aspirational file
 * table. It is computed from `gh pr view <PR> --json files`, filtered to
 * `src/**\/*.sol`, minus an explicit out-of-scope denylist that mirrors the
 * handoff's Section 3. This way the scope always tracks PR #153 as it evolves
 * (e.g. if the FeeProxy / curve commits land later), and any new in-scope file
 * that is not yet in the coupling map is surfaced as drift rather than skipped.
 *
 * Run directly to print the plan:
 *     npx tsx script/audits/oda-scope.ts
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import * as path from "node:path";

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
export const PR_NUMBER = process.env.ODA_PR ?? "153";
export const REPO_SLUG = process.env.ODA_REPO ?? "0xIntuition/intuition-contracts-v2";

/**
 * Out-of-scope denylist — mirrors Section 3 of the v1.1.0 handoff. A file whose
 * path matches any of these prefixes/exacts is never a primary review target.
 */
const DENYLIST_PREFIXES = [
  "src/external/", // legacy / vendored (VotingEscrow, OZ v4-v5 duality)
  "src/legacy/",
];
const DENYLIST_EXACT = new Set<string>([
  "src/Trust.sol", // legacy token
  "src/protocol/MultiVaultMigrationMode.sol", // migration-only, MIGRATOR_ROLE revoked post-migration
  "src/protocol/emissions/BaseEmissionsController.sol", // Base-chain component
  "src/protocol/emissions/MetaERC20Dispatcher.sol", // cross-chain transport (trust boundary)
  "src/protocol/curves/ProgressiveCurve.sol", // pre-existing, not part of the v1.1.0 delta
  "src/protocol/curves/OffsetProgressiveCurve.sol", // pre-existing, not part of the v1.1.0 delta
  "src/libraries/ProgressiveCurveMathLib.sol", // math for the progressive-curve family
]);

/**
 * Files that are in-scope only as CONTEXT (linked/pasted to inform a review) and
 * never commissioned as their own job: all interfaces, plus libraries that are
 * folded into an implementation contract.
 */
const CONTEXT_ONLY_EXACT = new Set<string>([
  "src/libraries/CoinbaseSmartWalletLib.sol", // P-256/WebAuthn primitives folded into AtomWallet
]);
const isInterface = (p: string) => p.startsWith("src/interfaces/");

/**
 * Coupling map: for each primary in-scope contract, the sibling files that
 * should travel with it as context (interfaces + tightly-integrated units).
 * These are provided to the auditor as authoritative GitHub permalinks; the
 * primary file itself is pasted in full.
 */
const CONTEXT_FOR: Record<string, string[]> = {
  "src/protocol/MultiVault.sol": [
    "src/protocol/MultiVaultCore.sol",
    "src/libraries/MultiVaultLib.sol",
    "src/interfaces/IMultiVault.sol",
    "src/interfaces/IMultiVaultCore.sol",
  ],
  "src/protocol/MultiVaultCore.sol": [
    "src/protocol/MultiVault.sol",
    "src/libraries/MultiVaultLib.sol",
    "src/interfaces/IMultiVaultCore.sol",
  ],
  "src/libraries/MultiVaultLib.sol": [
    "src/protocol/MultiVault.sol",
    "src/protocol/MultiVaultCore.sol",
    "src/interfaces/IMultiVault.sol",
  ],
  "src/protocol/curves/BondingCurveRegistry.sol": [
    "src/protocol/curves/BaseCurve.sol",
    "src/protocol/curves/LinearCurve.sol",
  ],
  "src/protocol/curves/BaseCurve.sol": [
    "src/protocol/curves/LinearCurve.sol",
    "src/protocol/curves/BondingCurveRegistry.sol",
  ],
  "src/protocol/curves/LinearCurve.sol": ["src/protocol/curves/BaseCurve.sol"],
  "src/protocol/wallet/AtomWallet.sol": [
    "src/libraries/CoinbaseSmartWalletLib.sol",
    "src/protocol/wallet/AtomWalletFactory.sol",
    "src/protocol/wallet/AtomWarden.sol",
    "src/interfaces/IAtomWallet.sol",
  ],
  "src/protocol/wallet/AtomWalletFactory.sol": [
    "src/protocol/wallet/AtomWallet.sol",
    "src/interfaces/IAtomWalletFactory.sol",
  ],
  "src/protocol/wallet/AtomWarden.sol": ["src/protocol/wallet/AtomWallet.sol", "src/interfaces/IAtomWarden.sol"],
  "src/protocol/emissions/TrustBonding.sol": [
    "src/protocol/emissions/CoreEmissionsController.sol",
    "src/protocol/emissions/SatelliteEmissionsController.sol",
  ],
  "src/protocol/emissions/CoreEmissionsController.sol": [
    "src/protocol/emissions/SatelliteEmissionsController.sol",
    "src/protocol/emissions/TrustBonding.sol",
  ],
  "src/protocol/emissions/SatelliteEmissionsController.sol": [
    "src/protocol/emissions/CoreEmissionsController.sol",
    "src/interfaces/ISatelliteEmissionsController.sol",
    "src/protocol/emissions/TrustBonding.sol",
  ],
  "src/periphery/FeeProxy.sol": ["src/interfaces/IFeeProxy.sol", "src/protocol/MultiVault.sol"],
};

/**
 * Optional grouping into fewer, system-level jobs (used by `--clustered`).
 * Order matters only for display. Every primary file must appear in exactly one
 * cluster; `buildJobs` validates this against the computed scope.
 */
const CLUSTERS: { id: string; title: string; primaries: string[] }[] = [
  {
    id: "multivault",
    title: "MultiVault core (vault + core + write-path library)",
    primaries: ["src/protocol/MultiVault.sol", "src/protocol/MultiVaultCore.sol", "src/libraries/MultiVaultLib.sol"],
  },
  {
    id: "curves",
    title: "Bonding-curve framework (registry + base + linear)",
    primaries: [
      "src/protocol/curves/BondingCurveRegistry.sol",
      "src/protocol/curves/BaseCurve.sol",
      "src/protocol/curves/LinearCurve.sol",
    ],
  },
  {
    id: "wallet",
    title: "AtomWallet system (wallet + factory)",
    primaries: ["src/protocol/wallet/AtomWallet.sol", "src/protocol/wallet/AtomWalletFactory.sol"],
  },
  {
    id: "warden",
    title: "AtomWarden quorum claims",
    primaries: ["src/protocol/wallet/AtomWarden.sol"],
  },
  {
    id: "trustbonding",
    title: "TrustBonding emissions + pause gating",
    primaries: ["src/protocol/emissions/TrustBonding.sol"],
  },
  {
    id: "emissions",
    title: "Emissions controllers (Intuition side)",
    primaries: [
      "src/protocol/emissions/CoreEmissionsController.sol",
      "src/protocol/emissions/SatelliteEmissionsController.sol",
    ],
  },
  {
    id: "feeproxy",
    title: "FeeProxy affiliate router",
    primaries: ["src/periphery/FeeProxy.sol"],
  },
];

export interface OdaJob {
  /** Stable slug used for filenames and dedupe (e.g. "multivault" or "multivault-sol"). */
  id: string;
  title: string;
  /** Files reviewed in full and pasted into the description. */
  primaries: string[];
  /** Sibling/interface files offered as GitHub-permalink context. */
  context: string[];
}

/** Shell out to `gh` to get the live list of files touched by the PR. */
export function prFiles(): string[] {
  const out = execFileSync(
    "gh",
    ["pr", "view", PR_NUMBER, "--repo", REPO_SLUG, "--json", "files", "--jq", ".files[].path"],
    { cwd: REPO_ROOT, encoding: "utf8" },
  );
  return out
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
}

function isDenied(p: string): boolean {
  if (DENYLIST_EXACT.has(p)) return true;
  return DENYLIST_PREFIXES.some((pre) => p.startsWith(pre));
}

export interface Scope {
  commit: string;
  /** Primary review targets: in-scope, on disk, not denied, not interface/context-only. */
  primaries: string[];
  /** In-scope-as-context files (interfaces + folded libraries) present in the PR. */
  contextFiles: string[];
  /** Files present in the PR but excluded, with the reason. */
  excluded: { path: string; reason: string }[];
  /** Primary files with no curated context entry (map drift / newly added contracts). */
  uncharted: string[];
}

/** The PR head commit, pinned so every job references identical source. */
export function headCommit(): string {
  return (
    process.env.ODA_COMMIT ??
    execFileSync("gh", ["pr", "view", PR_NUMBER, "--repo", REPO_SLUG, "--json", "headRefOid", "--jq", ".headRefOid"], {
      cwd: REPO_ROOT,
      encoding: "utf8",
    }).trim()
  );
}

export function computeScope(): Scope {
  const files = prFiles();
  const sol = files.filter((p) => p.startsWith("src/") && p.endsWith(".sol"));

  const primaries: string[] = [];
  const contextFiles: string[] = [];
  const excluded: { path: string; reason: string }[] = [];

  for (const p of sol) {
    if (!existsSync(path.join(REPO_ROOT, p))) {
      excluded.push({ path: p, reason: "not on disk (deleted in PR)" });
      continue;
    }
    if (isDenied(p)) {
      excluded.push({ path: p, reason: "out of scope (handoff §3)" });
      continue;
    }
    if (isInterface(p) || CONTEXT_ONLY_EXACT.has(p)) {
      contextFiles.push(p);
      continue;
    }
    primaries.push(p);
  }

  const charted = new Set(Object.keys(CONTEXT_FOR));
  const uncharted = primaries.filter((p) => !charted.has(p));

  return { commit: headCommit(), primaries: primaries.sort(), contextFiles: contextFiles.sort(), excluded, uncharted };
}

/** Build the job list for the chosen granularity. */
export function buildJobs(scope: Scope, granularity: "per-file" | "clustered"): OdaJob[] {
  const contextFor = (primary: string): string[] =>
    (CONTEXT_FOR[primary] ?? []).filter((c) => existsSync(path.join(REPO_ROOT, c)));

  if (granularity === "per-file") {
    return scope.primaries.map((p) => ({
      id: slug(p),
      title: path.basename(p),
      primaries: [p],
      context: uniq(contextFor(p).filter((c) => c !== p)),
    }));
  }

  // clustered: validate every primary is covered by exactly one cluster
  const covered = new Set<string>();
  const jobs: OdaJob[] = [];
  for (const c of CLUSTERS) {
    const present = c.primaries.filter((p) => scope.primaries.includes(p));
    if (present.length === 0) continue;
    present.forEach((p) => covered.add(p));
    const ctx = uniq(present.flatMap(contextFor).filter((f) => !present.includes(f)));
    jobs.push({ id: c.id, title: c.title, primaries: present, context: ctx });
  }
  // any in-scope primary not claimed by a cluster becomes its own job (drift-safe)
  for (const p of scope.primaries) {
    if (!covered.has(p)) {
      jobs.push({
        id: slug(p),
        title: `${path.basename(p)} (uncharted)`,
        primaries: [p],
        context: uniq(contextFor(p)),
      });
    }
  }
  return jobs;
}

export function githubBlob(commit: string, p: string): string {
  return `https://github.com/${REPO_SLUG}/blob/${commit}/${p}`;
}

export function readSource(p: string): string {
  return readFileSync(path.join(REPO_ROOT, p), "utf8");
}

const uniq = <T>(xs: T[]): T[] => [...new Set(xs)];
const slug = (p: string) =>
  path
    .basename(p)
    .replace(/\.sol$/, "")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .toLowerCase();

/** CLI: print the plan. */
function main(): void {
  const granularity = process.argv.includes("--clustered") ? "clustered" : "per-file";
  const scope = computeScope();
  const jobs = buildJobs(scope, granularity);

  console.log(`\nOne Dollar Audit — scope plan for PR #${PR_NUMBER} (${REPO_SLUG})`);
  console.log(`Pinned commit: ${scope.commit}`);
  console.log(`Granularity:   ${granularity}   →   ${jobs.length} job(s), ~$${jobs.length} USDC total\n`);

  console.log(`In-scope primary contracts (${scope.primaries.length}):`);
  for (const p of scope.primaries) console.log(`  • ${p}`);

  console.log(`\nContext-only files present in PR (${scope.contextFiles.length}): interfaces + folded libraries`);

  if (scope.uncharted.length) {
    console.log(`\n⚠️  DRIFT — in-scope primaries with no curated context (newly added to PR #${PR_NUMBER}?):`);
    for (const p of scope.uncharted) console.log(`  • ${p}   → add an entry to CONTEXT_FOR in oda-scope.ts`);
  }

  console.log(`\nExcluded (present in PR, not reviewed):`);
  for (const e of scope.excluded) console.log(`  • ${e.path}  — ${e.reason}`);

  console.log(`\nJobs:`);
  for (const [i, j] of jobs.entries()) {
    console.log(`  ${i + 1}. [${j.id}] ${j.title}`);
    j.primaries.forEach((p) => console.log(`why       reviewed in full → ${p}`.replace("why", "     ")));
    if (j.context.length) console.log(`        context (links) → ${j.context.join(", ")}`);
  }
  console.log("");
}

// Run main() only when invoked directly (not when imported by the runner).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
