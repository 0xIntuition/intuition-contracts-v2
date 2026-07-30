# Call-flow visualization

Call graphs and flow diagrams for the core contracts, produced for external review.

There are two kinds of artifact here, and the distinction is the point:

|                               | source                                                         | trust it for                                                                                   |
| ----------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| [`generated/`](./generated)   | regenerated from the compiled code by `bun run viz:call-flows` | **completeness** — every statically resolvable callee, no editorial judgement                  |
| the hand-authored pages below | written and maintained by hand                                 | **legibility** — ordering, value movement, and the arithmetic a bare call graph cannot express |

A stale diagram is worse than no diagram, because it is believed. Everything under `generated/` is therefore
reproducible from a single command and diffs as text, so drift shows up in review rather than in an auditor's head.

## Start here

- **[`multivault-value-paths.md`](./multivault-value-paths.md)** — deposit and redeem end to end: the `delegatecall`
  library boundary, where the curve hook is resolved and called, the ordering of state writes against value movement,
  and the batching entry points.
- **[`dynamic-fee-curve.md`](./dynamic-fee-curve.md)** — the tier ladder, the **piecewise deposit-fee walk with a fully
  worked numeric example**, the fee-hook round trip, and how a released fee pot reaches earlier cohorts.

## Regenerating

Run from the repository root:

```bash
bun run viz:call-flows
```

Output lands in `docs/call-flows/generated/` and is committed. The command is idempotent: re-running it on unchanged
sources produces no diff, which doubles as the freshness check — if `git status` is dirty after running it, the
committed diagrams no longer match the source and must be re-committed.

### Requirements

- `slither` on `PATH`. It is used as a **system-installed binary**, deliberately not added as an npm dependency — this
  repository pins dependency release ages and does not admit install scripts, and the analyzer is a developer tool
  rather than something the contracts build against. Install with `pipx install slither-analyzer` or
  `brew install slither-analyzer`.
- A working `forge build` (slither compiles the project itself).

The generator sweeps slither's intermediate `*.call-graph.dot` artifacts on both the success and failure paths, so a run
leaves nothing behind in the working tree.

## Why slither

The graph is derived from the compiled AST rather than from text matching, the binary is already a repository dev tool
(`bun run slither` wires the same analyzer for static analysis), and no new package dependency is introduced. Slither's
own output format is Graphviz `.dot`, which renders in neither GitHub nor Notion, so the generator parses it and emits
**Mermaid** plus an indented ASCII trace — both of which render natively in GitHub and Notion and diff as plain text.

## What the graph excludes

By construction, so the output stays readable and reproducible:

- vendored dependencies (OpenZeppelin, solady, account-abstraction, PRB Math)
- `tests/`, `script/`, `src/legacy/`, `src/external/`
- the OpenZeppelin v4 bases inlined into the flattened `src/Trust.sol`
- the TRUST token surface (`Trust`, `ITrust`, `TrustToken`, `WrappedTrust`) — out of scope for these paths, which move
  **native** TRUST and never call the token. This exclusion is also what makes the output reproducible: `src/Trust.sol`
  is flattened and re-declares `ITrust`, so the project holds two distinct types with that name, and slither resolves
  interface-typed calls against them non-deterministically. Leaving them in made one overview edge appear and disappear
  between runs on unchanged code.
- slither's synthetic `slitherConstructor*` pseudo-functions
- walks deeper than 6 frames from an entry point (marked in the page when it happens)

## What the graph cannot see

Worth stating explicitly, because these are exactly the places an auditor should not trust a call graph:

- **Dynamic dispatch.** `multicall` / `multicallPayable` dispatch by `delegatecall` to `address(this)` with calldata
  chosen at runtime, so they appear with **no outgoing edges**.
  [`multivault-value-paths.md` §4](./multivault-value-paths.md) covers that path by hand.
- **Interface-typed calls resolve to the interface, not the implementation.** A call to the fee hook shows up as
  `MultiVaultLib → IBaseCurve.recordDeposit`, not as `→ DynamicFeeFlatPriceCurve.recordDeposit`, because the concrete
  curve is resolved from the registry at runtime. [`dynamic-fee-curve.md` §3](./dynamic-fee-curve.md) shows the real
  round trip.
- **The `delegatecall` into `MultiVaultLib` looks like an external call.** It is drawn dashed like any cross-contract
  edge, but it executes in the `MultiVault` storage context. There is one storage context, not two.
- **Ordering and arithmetic.** A call graph says _what_ is called, never _when_ relative to state writes, nor with what
  value. Both hand-authored pages exist for that reason.

## Extending

Entry points are listed explicitly in `script/viz/generate-call-flows.ts` (`ENTRY_POINTS`) rather than swept from every
external function, so each page stays readable. Add an entry when a new value-moving entry point lands. The generator
fails loudly if a configured entry point is no longer present in the graph, so a rename cannot silently drop a diagram.
