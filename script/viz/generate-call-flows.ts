/**
 * -----------------------------------------------------------------------------
 * CALL-FLOW GENERATOR
 * -----------------------------------------------------------------------------
 *
 * Regenerates the committed call-flow diagrams under `docs/call-flows/generated/`.
 *
 *   bun run viz:call-flows
 *
 * Pipeline:
 *   1. Shell out to a system-installed `slither` with its `call-graph` printer. Slither
 *      builds the whole-project call graph from the compiled AST, so the graph reflects
 *      the code rather than a hand-maintained picture.
 *   2. Parse the emitted `all_contracts.call-graph.dot`.
 *   3. Keep only first-party contracts (declared under `src/`, minus `src/legacy` and
 *      `src/external`); vendored OpenZeppelin / solady / account-abstraction sources,
 *      tests and deploy scripts are dropped, otherwise the graph is unreadable.
 *   4. Emit Mermaid + an indented ASCII trace per entry point, plus a contract-level
 *      overview. Mermaid is used because it renders natively in GitHub and Notion and
 *      diffs as text, so a stale diagram shows up in review.
 *
 * Requirements: `slither` on PATH (installed system-wide; deliberately NOT added as an
 * npm dependency) and a working `forge build`.
 * -----------------------------------------------------------------------------
 */

import { spawnSync } from 'node:child_process';
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import * as path from 'node:path';

/* =================================================== */
/*                    CONFIGURATION                    */
/* =================================================== */

const CONTRACTS_ROOT = path.resolve(import.meta.dir, '../..');
const SRC_DIR = path.join(CONTRACTS_ROOT, 'src');
const OUTPUT_DIR = path.join(CONTRACTS_ROOT, 'docs/call-flows/generated');

/** Source subtrees excluded from the graph: vendored forks and the frozen v1 token. */
const EXCLUDED_SRC_SUBTREES = ['legacy', 'external'];

/**
 * Sources under `src/` that inline vendored code rather than importing it. Only the contract
 * such a file is named after counts as first-party; see {@link firstPartyContractNames}.
 */
const FLATTENED_SRC_FILES = ['Trust.sol'];

/**
 * The TRUST token surface, excluded by name.
 *
 * Two reasons, and the second one is the load-bearing one:
 *
 *  1. Scope. The token is an ERC20 reviewed on its own terms; these diagrams are about the
 *     vault / curve value paths, which move NATIVE TRUST and never call the token.
 *  2. Determinism. `src/Trust.sol` is flattened and re-declares `ITrust`, so the project
 *     contains two distinct types with that name. Slither resolves interface-typed calls
 *     against them non-deterministically, which made a `BaseEmissionsController -> ITrust`
 *     edge appear in some runs and not others. A committed artifact that changes without the
 *     code changing is worse than no artifact, so the ambiguous types are cut rather than
 *     tolerated. Removing this exclusion re-introduces the flap.
 */
const EXCLUDED_CONTRACTS = new Set(['Trust', 'ITrust', 'TrustToken', 'WrappedTrust']);

/**
 * Dependency trees whose contracts are not ours to diagram. Mirrors the `libs` entries in
 * `foundry.toml`; a missing directory is skipped, so this stays correct if a dependency moves.
 */
const VENDORED_DEPENDENCY_DIRS = [
	path.join(CONTRACTS_ROOT, 'node_modules'),
	path.resolve(CONTRACTS_ROOT, '../../node_modules/@openzeppelin'),
	path.resolve(CONTRACTS_ROOT, '../../node_modules/@account-abstraction'),
	path.resolve(CONTRACTS_ROOT, '../../node_modules/@prb'),
	path.resolve(CONTRACTS_ROOT, '../../node_modules/solady'),
];

/** Depth cap for the per-entry-point walks; deeper than this stops being legible. */
const MAX_DEPTH = 6;

type EntryPoint = {
	/** Output file basename, without extension. */
	slug: string;
	contract: string;
	fn: string;
	title: string;
	blurb: string;
};

/**
 * The flows an auditor is expected to walk. Kept explicit rather than "every external
 * function" so each generated page stays readable; extend the list when a new
 * value-moving entry point lands.
 */
const ENTRY_POINTS: EntryPoint[] = [
	{
		slug: 'multivault-deposit',
		contract: 'MultiVault',
		fn: 'deposit',
		title: 'MultiVault.deposit',
		blurb:
			'Single-term deposit. Crosses into MultiVaultLib by `delegatecall`, then out to the ' +
			'registry-resolved curve for the fee quote and the record hook.',
	},
	{
		slug: 'multivault-deposit-batch',
		contract: 'MultiVault',
		fn: 'depositBatch',
		title: 'MultiVault.depositBatch',
		blurb:
			'Batched deposit; each leg runs the same `_processDeposit` body as the single-term path.',
	},
	{
		slug: 'multivault-redeem',
		contract: 'MultiVault',
		fn: 'redeem',
		title: 'MultiVault.redeem',
		blurb:
			'Single-term redeem. Vault state is lowered, the curve records the exit, and only then ' +
			'is the payout sent.',
	},
	{
		slug: 'multivault-redeem-batch',
		contract: 'MultiVault',
		fn: 'redeemBatch',
		title: 'MultiVault.redeemBatch',
		blurb: 'Batched redeem; each leg runs the same `_processRedeem` body as the single-term path.',
	},
	{
		slug: 'multivault-multicall',
		contract: 'MultiVault',
		fn: 'multicall',
		title: 'MultiVault.multicall',
		blurb:
			'Batching entry point. Sub-calls re-enter this same contract by `delegatecall` to ' +
			'`address(this)`, so they are dispatched through the normal external ABI.',
	},
	{
		slug: 'multivault-create-atoms',
		contract: 'MultiVault',
		fn: 'createAtoms',
		title: 'MultiVault.createAtoms',
		blurb: 'Term creation, which seeds the default-curve vault before any deposit can route to it.',
	},
	{
		slug: 'curve-quote-deposit-fee',
		contract: 'DynamicFeeFlatPriceCurve',
		fn: 'quoteDepositFee',
		title: 'DynamicFeeFlatPriceCurve.quoteDepositFee',
		blurb:
			'The piecewise deposit-fee walk across tier bands (view; called during deposit calculation).',
	},
	{
		slug: 'curve-record-deposit',
		contract: 'DynamicFeeFlatPriceCurve',
		fn: 'recordDeposit',
		title: 'DynamicFeeFlatPriceCurve.recordDeposit',
		blurb: 'Books the depositor position and distributes the forwarded fee across the prior tiers.',
	},
	{
		slug: 'curve-record-redeem',
		contract: 'DynamicFeeFlatPriceCurve',
		fn: 'recordRedeem',
		title: 'DynamicFeeFlatPriceCurve.recordRedeem',
		blurb:
			'Books the exit and distributes the forwarded fee to the exiting tier, then the prior tiers.',
	},
	{
		slug: 'curve-preview-redeem-for',
		contract: 'DynamicFeeFlatPriceCurve',
		fn: 'previewRedeemFor',
		title: 'DynamicFeeFlatPriceCurve.previewRedeemFor',
		blurb:
			'The account-aware redeem quote. Prices the withdrawal fee at the HOLDER\'s recorded tier, ' +
			'unlike `MultiVault.previewRedeem`, which is account-agnostic and falls back to the vault\'s ' +
			'current tier. Read-only, and net of this curve\'s fee only — MultiVault\'s own protocol and ' +
			'exit fees are not modelled here.',
	},
	{
		slug: 'curve-claimable-across',
		contract: 'DynamicFeeFlatPriceCurve',
		fn: 'claimableAcross',
		title: 'DynamicFeeFlatPriceCurve.claimableAcross',
		blurb:
			'Total withdrawable across a set of terms — the figure `claim` would pay. Validates the ' +
			'input (sort-and-scan for repeats) before accumulating, so the documented equality with ' +
			'the payout cannot be broken by a duplicate term.',
	},
	{
		slug: 'curve-claim',
		contract: 'DynamicFeeFlatPriceCurve',
		fn: 'claim',
		title: 'DynamicFeeFlatPriceCurve.claim',
		blurb:
			'The pull side: a holder settles pending fee earnings and withdraws them as native TRUST.',
	},
];

/* =================================================== */
/*                    FIRST-PARTY SET                  */
/* =================================================== */

const DECLARATION_RE = /^\s*(?:abstract\s+)?(?:contract|library|interface)\s+([A-Za-z_]\w*)/gm;

/** Contract / library / interface names declared in one `.sol` file. */
function declaredInFile(file: string, into: Set<string>): Set<string> {
	for (const match of readFileSync(file, 'utf8').matchAll(DECLARATION_RE)) into.add(match[1]);
	return into;
}

/** Contract / library / interface names declared anywhere under `dir`, skipping `skip` paths. */
function declaredUnder(dir: string, into: Set<string>, skip: Set<string> = new Set()): Set<string> {
	let entries: ReturnType<typeof readdirSync>;
	try {
		entries = readdirSync(dir, { withFileTypes: true });
	} catch {
		return into; // A dependency that is not installed simply contributes nothing.
	}

	for (const entry of entries) {
		const full = path.join(dir, entry.name);
		if (skip.has(full)) continue;
		if (entry.isDirectory()) {
			declaredUnder(full, into, skip);
			continue;
		}
		if (entry.name.endsWith('.sol')) declaredInFile(full, into);
	}

	return into;
}

/**
 * Contract names the graph should keep.
 *
 * First-party = declared in a canonical `src/` file, minus every name a vendored dependency
 * also declares. Both subtractions are load-bearing:
 *
 *  - `src/legacy` and `src/external` hold a frozen v1 token and a Vyper-port fork.
 *  - `src/Trust.sol` is FLATTENED: it re-declares the OpenZeppelin **v4** upgradeable bases
 *    inline. Those names were dropped in the pinned OZ v5 tree, so scanning `node_modules`
 *    cannot see them and a `src/`-only allowlist would readmit `AddressUpgradeable`,
 *    `ERC20Upgradeable` and friends as if they were ours. For a flattened file only the
 *    contract it is named after is first-party.
 */
function firstPartyContractNames(): Set<string> {
	const flattened = new Set(FLATTENED_SRC_FILES.map((file) => path.join(SRC_DIR, file)));
	const skip = new Set([
		...EXCLUDED_SRC_SUBTREES.map((subtree) => path.join(SRC_DIR, subtree)),
		...flattened,
	]);

	const names = declaredUnder(SRC_DIR, new Set<string>(), skip);
	for (const file of flattened) names.add(path.basename(file, '.sol'));

	const vendored = new Set<string>();
	for (const dependency of VENDORED_DEPENDENCY_DIRS) declaredUnder(dependency, vendored);
	for (const name of vendored) names.delete(name);
	for (const name of EXCLUDED_CONTRACTS) names.delete(name);

	return names;
}

/* =================================================== */
/*                      DOT PARSING                    */
/* =================================================== */

type CallGraph = {
	/** Node id (`<clusterId>_<fn>`) -> qualified `Contract.fn`. */
	label: Map<string, string>;
	/** Node id -> outgoing node ids, in a stable order. */
	edges: Map<string, string[]>;
	/** Qualified `Contract.fn` -> node ids that carry it (a name can appear in several clusters). */
	byQualifiedName: Map<string, string[]>;
};

/** Slither emits the closing brace of the previous cluster on the same line as the next one. */
const CLUSTER_RE = /^\}?subgraph cluster_(\d+)_(.+?)\s*\{\s*$/;
const NODE_RE = /^"([^"]+)"\s*\[label="([^"]+)"\]$/;
const EDGE_RE = /^"([^"]+)"\s*->\s*"([^"]+)"/;
/** Node ids are `<clusterId>_<fnName>`, which is how a node maps back to its contract. */
const NODE_ID_RE = /^(\d+)_/;

/**
 * Parse slither's `all_contracts.call-graph.dot`. Clusters are declared as
 * `subgraph cluster_<id>_<ContractName>`, and every node inside one is named
 * `<clusterId>_<fnName>` — so node-to-contract resolution keys off the id prefix rather
 * than on the reader's position in the file.
 */
function parseCallGraph(dot: string, keep: Set<string>): CallGraph {
	const clusterName = new Map<string, string>();
	const rawNodes: Array<{ id: string; fn: string }> = [];
	const rawEdges: Array<[string, string]> = [];

	for (const rawLine of dot.split('\n')) {
		const line = rawLine.trim();

		const cluster = CLUSTER_RE.exec(line);
		if (cluster) {
			clusterName.set(cluster[1], cluster[2]);
			continue;
		}

		const node = NODE_RE.exec(line);
		if (node) {
			rawNodes.push({ id: node[1], fn: node[2] });
			continue;
		}

		const edge = EDGE_RE.exec(line);
		if (edge) rawEdges.push([edge[1], edge[2]]);
	}

	const label = new Map<string, string>();
	const byQualifiedName = new Map<string, string[]>();

	for (const node of rawNodes) {
		const clusterId = NODE_ID_RE.exec(node.id)?.[1];
		const contract = clusterId ? clusterName.get(clusterId) : undefined;
		if (!contract || !keep.has(contract)) continue;
		// Slither synthesises this pseudo-function for constant initialisation; it is noise here.
		if (node.fn.startsWith('slitherConstructor')) continue;
		const qualified = `${contract}.${node.fn}`;
		label.set(node.id, qualified);
		const bucket = byQualifiedName.get(qualified);
		if (bucket) bucket.push(node.id);
		else byQualifiedName.set(qualified, [node.id]);
	}

	const edges = new Map<string, string[]>();
	const seen = new Set<string>();
	for (const [from, to] of rawEdges) {
		if (!label.has(from) || !label.has(to)) continue;
		const key = `${from}>${to}`;
		if (seen.has(key)) continue;
		seen.add(key);
		const bucket = edges.get(from);
		if (bucket) bucket.push(to);
		else edges.set(from, [to]);
	}

	// Stable ordering keeps the committed output diff-free across runs.
	for (const [from, targets] of edges) {
		targets.sort((a, b) => (label.get(a) ?? a).localeCompare(label.get(b) ?? b));
		edges.set(from, targets);
	}

	return { label, edges, byQualifiedName };
}

/* =================================================== */
/*                      RENDERING                      */
/* =================================================== */

type Reachable = {
	nodes: Set<string>;
	edges: Array<[string, string]>;
	truncated: Set<string>;
};

/** Breadth-first reachability from a set of roots, capped at {@link MAX_DEPTH}. */
function reachableFrom(graph: CallGraph, roots: string[]): Reachable {
	const nodes = new Set<string>(roots);
	const edges: Array<[string, string]> = [];
	const truncated = new Set<string>();
	const depth = new Map<string, number>(roots.map((root) => [root, 0]));
	const queue = [...roots];

	while (queue.length > 0) {
		const current = queue.shift() as string;
		const currentDepth = depth.get(current) ?? 0;
		const targets = graph.edges.get(current) ?? [];
		if (currentDepth >= MAX_DEPTH) {
			if (targets.length > 0) truncated.add(current);
			continue;
		}
		for (const target of targets) {
			edges.push([current, target]);
			if (nodes.has(target)) continue;
			nodes.add(target);
			depth.set(target, currentDepth + 1);
			queue.push(target);
		}
	}

	return { nodes, edges, truncated };
}

function contractOf(qualified: string): string {
	return qualified.slice(0, qualified.indexOf('.'));
}

function functionOf(qualified: string): string {
	return qualified.slice(qualified.indexOf('.') + 1);
}

/** Mermaid node ids must be identifier-safe. */
function mermaidId(qualified: string): string {
	return qualified.replace(/[^A-Za-z0-9]/g, '_');
}

function renderMermaid(graph: CallGraph, reach: Reachable, roots: string[]): string {
	const byContract = new Map<string, Set<string>>();
	for (const node of reach.nodes) {
		const qualified = graph.label.get(node);
		if (!qualified) continue;
		const contract = contractOf(qualified);
		const bucket = byContract.get(contract);
		if (bucket) bucket.add(qualified);
		else byContract.set(contract, new Set([qualified]));
	}

	const lines = ['```mermaid', 'flowchart LR'];

	for (const contract of [...byContract.keys()].sort()) {
		lines.push(`  subgraph ${mermaidId(contract)}["${contract}"]`);
		for (const qualified of [...(byContract.get(contract) as Set<string>)].sort()) {
			lines.push(`    ${mermaidId(qualified)}["${functionOf(qualified)}"]`);
		}
		lines.push('  end');
	}

	const rendered = new Set<string>();
	for (const [from, to] of reach.edges) {
		const fromLabel = graph.label.get(from);
		const toLabel = graph.label.get(to);
		if (!fromLabel || !toLabel) continue;
		const key = `${fromLabel}>${toLabel}`;
		if (rendered.has(key)) continue;
		rendered.add(key);
		// A call that leaves the declaring contract is drawn dashed: it is either a
		// `delegatecall` into the linked library or a real external call.
		const arrow = contractOf(fromLabel) === contractOf(toLabel) ? '-->' : '-.->';
		lines.push(`  ${mermaidId(fromLabel)} ${arrow} ${mermaidId(toLabel)}`);
	}

	for (const root of roots) {
		const qualified = graph.label.get(root);
		if (qualified) lines.push(`  style ${mermaidId(qualified)} stroke-width:3px`);
	}

	lines.push('```');
	return lines.join('\n');
}

/** Indented DFS trace; repeated subtrees are elided so the text stays short. */
function renderTrace(graph: CallGraph, roots: string[]): string {
	const lines: string[] = [];
	const expanded = new Set<string>();

	const walk = (node: string, depth: number, ancestors: Set<string>) => {
		const qualified = graph.label.get(node);
		if (!qualified) return;
		const indent = '  '.repeat(depth);
		const targets = graph.edges.get(node) ?? [];

		if (ancestors.has(node)) {
			lines.push(`${indent}${qualified}  (recursion)`);
			return;
		}
		if (expanded.has(node) && targets.length > 0) {
			lines.push(`${indent}${qualified}  (expanded above)`);
			return;
		}
		if (depth >= MAX_DEPTH && targets.length > 0) {
			lines.push(`${indent}${qualified}  (depth limit)`);
			return;
		}

		lines.push(`${indent}${qualified}`);
		expanded.add(node);
		const nextAncestors = new Set(ancestors).add(node);
		for (const target of targets) walk(target, depth + 1, nextAncestors);
	};

	for (const root of roots) walk(root, 0, new Set());
	return ['```text', ...lines, '```'].join('\n');
}

type ContractOverview = { diagram: string; isolated: string[] };

/** Contract-level overview: one node per contract, one edge per cross-contract call. */
function renderContractOverview(graph: CallGraph): ContractOverview {
	const contracts = new Set<string>();
	const pairs = new Set<string>();

	for (const qualified of graph.byQualifiedName.keys()) contracts.add(contractOf(qualified));
	for (const [from, targets] of graph.edges) {
		const fromLabel = graph.label.get(from);
		if (!fromLabel) continue;
		for (const to of targets) {
			const toLabel = graph.label.get(to);
			if (!toLabel) continue;
			const fromContract = contractOf(fromLabel);
			const toContract = contractOf(toLabel);
			if (fromContract === toContract) continue;
			pairs.add(`${fromContract}>${toContract}`);
		}
	}

	const referenced = new Set<string>();
	for (const pair of pairs) {
		const [from, to] = pair.split('>');
		referenced.add(from);
		referenced.add(to);
	}

	const lines = ['```mermaid', 'flowchart LR'];
	for (const contract of [...referenced].sort()) {
		lines.push(`  ${mermaidId(contract)}["${contract}"]`);
	}
	for (const pair of [...pairs].sort()) {
		const [from, to] = pair.split('>');
		lines.push(`  ${mermaidId(from)} --> ${mermaidId(to)}`);
	}
	lines.push('```');

	const isolated = [...contracts].filter((c) => !referenced.has(c)).sort();
	return { diagram: lines.join('\n'), isolated };
}

/* =================================================== */
/*                        SLITHER                      */
/* =================================================== */

const DOT_SUFFIX = '.call-graph.dot';

/** Delete the `*.call-graph.dot` artefacts slither drops next to the project. */
function clearDotArtifacts(): void {
	for (const entry of readdirSync(CONTRACTS_ROOT)) {
		if (entry.endsWith(DOT_SUFFIX)) rmSync(path.join(CONTRACTS_ROOT, entry), { force: true });
	}
}

/**
 * Run slither's call-graph printer and return the whole-project dot source.
 *
 * Slither names its output after the target it was given and writes it relative to the
 * process CWD, so it is run from the project root with `.` as the target (which yields
 * plain `<Contract>.call-graph.dot` names) and the artefacts are swept afterwards — they
 * are an intermediate, not a deliverable.
 */
function runSlither(): string {
	clearDotArtifacts();
	try {
		const result = spawnSync(
			'slither',
			['.', '--config-file', 'slither.config.json', '--print', 'call-graph', '--fail-none'],
			{ cwd: CONTRACTS_ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }
		);

		if (result.error) {
			throw new Error(
				`could not run \`slither\` (${result.error.message}). Install it system-wide: ` +
					'`pipx install slither-analyzer` or `brew install slither-analyzer`.'
			);
		}

		try {
			return readFileSync(path.join(CONTRACTS_ROOT, `all_contracts${DOT_SUFFIX}`), 'utf8');
		} catch {
			throw new Error(
				`slither produced no call graph (exit ${result.status}).\n${result.stderr ?? ''}`
			);
		}
	} finally {
		clearDotArtifacts();
	}
}

/* =================================================== */
/*                         MAIN                        */
/* =================================================== */

const GENERATED_BANNER =
	'<!-- GENERATED FILE — do not edit by hand. Regenerate with `bun run viz:call-flows`. -->';

function main(): void {
	const keep = firstPartyContractNames();
	console.log(`first-party contracts in scope: ${keep.size}`);

	const dot = runSlither();
	const graph = parseCallGraph(dot, keep);
	console.log(
		`graph: ${graph.label.size} functions, ${[...graph.edges.values()].flat().length} edges`
	);

	mkdirSync(OUTPUT_DIR, { recursive: true });

	const written: string[] = [];
	const missing: string[] = [];

	for (const entry of ENTRY_POINTS) {
		const qualified = `${entry.contract}.${entry.fn}`;
		const roots = graph.byQualifiedName.get(qualified);
		if (!roots) {
			missing.push(qualified);
			continue;
		}

		const reach = reachableFrom(graph, roots);
		const body = [
			GENERATED_BANNER,
			'',
			`# ${entry.title}`,
			'',
			entry.blurb,
			'',
			`Reached functions: ${reach.nodes.size}. Solid arrows are calls inside one contract; ` +
				'dashed arrows leave it (either a `delegatecall` into the linked library, which still ' +
				"executes in the caller's storage context, or a genuine external call).",
			'',
			'## Graph',
			'',
			renderMermaid(graph, reach, roots),
			'',
			'## Trace',
			'',
			renderTrace(graph, roots),
			'',
		];

		if (reach.truncated.size > 0) {
			const names = [...reach.truncated].map((node) => graph.label.get(node) ?? node).sort();
			body.push(
				`> Walk capped at depth ${MAX_DEPTH}. Truncated below: ${names.map((n) => `\`${n}\``).join(', ')}.`,
				''
			);
		}

		writeFileSync(path.join(OUTPUT_DIR, `${entry.slug}.md`), body.join('\n'));
		written.push(`${entry.slug}.md`);
	}

	const overview = renderContractOverview(graph);
	writeFileSync(
		path.join(OUTPUT_DIR, 'contract-overview.md'),
		[
			GENERATED_BANNER,
			'',
			'# Contract-level call graph',
			'',
			'One node per first-party contract, one edge per cross-contract call. Vendored ' +
				'dependencies, tests, deploy scripts, `src/legacy` and `src/external` are excluded.',
			'',
			overview.diagram,
			'',
			overview.isolated.length > 0
				? `Contracts with no first-party cross-contract calls: ${overview.isolated
						.map((c) => `\`${c}\``)
						.join(', ')}.`
				: '',
			'',
		].join('\n')
	);
	written.push('contract-overview.md');

	if (missing.length > 0) {
		throw new Error(
			`entry point(s) not found in the call graph: ${missing.join(', ')}. ` +
				'Either the function was renamed or it is no longer reachable — update ENTRY_POINTS.'
		);
	}

	console.log(`wrote ${written.length} file(s) to docs/call-flows/generated/`);
	for (const file of written) console.log(`  ${file}`);
}

main();
