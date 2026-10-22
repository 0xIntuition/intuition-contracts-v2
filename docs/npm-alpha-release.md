# Contracts alpha release and SDK handoff

## Prepared release scope

- Core: `@0xintuition/contracts-v2@1.1.0-alpha.1`, based on `82cfcdb` on `feat/v1.1.0-core-upgrade`.
- Router: `@0xintuition/contracts-v2-periphery@1.1.0-alpha.0`, based on `ae0c5bda358d6aabc347148658999106f4cc0a28` on
  `feat/v1.1.0-trust-swap-and-bridge-router` in
  [the periphery repository](https://github.com/0xIntuition/intuition-contracts-v2-periphery/pull/13).
- Publish both under the `alpha` dist-tag. Preserve `latest`.
- No Solidity business logic changes are required for this packaging work. Keep router ownership in the periphery
  repository.
- The periphery npm package deliberately ships the router and its interface dependencies. It does not ship or claim npm
  support for EmissionsAutomationAdapter or other periphery contracts.
- The versions were unused on 2026-10-19; check again immediately before publication. The local npm authentication check
  returned HTTP 401. Neither release has been published by this work.

The core package adds `IBaseCurveAbi` and `TimelockControllerAbi`/`TimelockControllerBytecode`, preserves the existing
exports, and adds positional library link references alongside the existing placeholder map. All generated exports must
have valid compiler output; missing contracts now fail extraction instead of silently retaining old files. The manifest
contains compiler-provided source hashes and settings plus artifact hashes. Record the final committed release revision
separately; the base revisions above are not claims that uncommitted packaging changes are already in those commits.

## Verify and publish

From each repository, using Foundry 1.8.6, Solidity 0.8.29, Node 22+ and Bun 1.3.11:

```sh
git submodule update --init --recursive
bun install --frozen-lockfile
bun run release:check
```

`release:check` builds artifacts, typechecks the packaging code, tests failure handling and output parity, installs a
real tarball in a disposable consumer, checks ESM/CJS and both TypeScript module modes, and recompiles the shipped
Solidity using only npm dependencies. ABI entries are compared structurally during the Solidity rebuild because solc can
reorder overloads when source paths change. Library placeholders are normalized only for bytecode comparison; the
published bytecode retains the link requirements. No browser or on-chain transaction is involved.

Run the contract suites separately; packaging checks do not replace protocol tests:

```sh
# Core: full suite includes network-dependent fork regressions.
bun run test
# Periphery: isolated router unit suite, no RPC required.
bun run test:router
```

After committing the prepared changes and obtaining passing CI, authenticate with an account permitted to publish to the
scope, then check versions/tags and publish from each repository:

```sh
npm whoami
npm view @0xintuition/contracts-v2 versions dist-tags --json
npm view @0xintuition/contracts-v2-periphery versions dist-tags --json
npm publish --access public --tag alpha
```

A 404 for the periphery package is expected before its first publication. `npm publish` invokes the same release checks
through `prepack`. Do not overwrite an existing version; choose a new alpha number if either was taken. Verify both
exact versions with `npm view <name>@<version> dist.integrity dist.tarball gitHead --json` and record the integrity, git
revision, and CI results in the release PR. Verify `latest` has not changed. Publication is separate from any contract
deployment or upgrade.

## Local validation on 2026-10-19

- Both repositories: frozen-lockfile install, `release:check`, and `git diff --check` passed. Six packaging regression
  tests passed across the repositories; packed ESM/CJS and TypeScript consumers passed, and npm-only Solidity rebuilds
  matched every shipped ABI/bytecode (accounting for ABI overload ordering and library placeholders as described above).
- Core non-fork suite: 2,127 passed, three invariant coverage failures, seven skipped with 256 fuzz runs and reduced
  invariant runs/depth of 32/32. The failed invariant suite was then rerun with a fresh failure cache at the normal 256
  runs and depth 500: all four tests passed. Reduced-depth failure cache entries were moved out of the active cache so
  subsequent runs do not replay the artificial coverage failures. No test assertions were relaxed.
- Core's five network-dependent test files were excluded from the local broad run. Fork regressions and hosted CI have
  not been validated by this session.
- Periphery router unit suite: 58 passed, zero failed; no live fork or transaction tests were performed.
- No Solidity business logic changed, no existing public core npm exports were removed, and the packages/Core workspaces
  were left untouched.
- Validated tarballs and integrity records are in the core repository's ignored `tmp/npm-alpha/` directory. They are
  local release candidates, not published registry versions.

## Packages repository handoff

Comparison against packages commit `23dc132` found exact ABI and bytecode matches for every shared core/router export
except `MultiVaultMigrationModeAbi` and `MultiVaultMigrationModeBytecode`. MigrationMode in packages still comes from
the old alpha. The router is an exact match to the separate periphery branch. The SDK artifacts already include the
newer dynamic-fee configuration; do not port the older application-monorepo curve over this branch.

1. Add exact devDependencies for both published versions in the packages root. Keep Solidity source packages out of
   runtime SDK dependencies. Update the lockfile and the hardcoded contracts version in
   `scripts/sync-protocol-artifacts.mjs` and version-bound tests.
2. Update `scripts/check-release-contracts.ts` to take core artifacts from `@0xintuition/contracts-v2` and the two
   router artifacts from `@0xintuition/contracts-v2-periphery`. Do not waive the router provenance check. Record both
   registry integrities and source revisions.
3. Deliberately regenerate the MigrationMode ABI/bytecode from the new core artifact, review its changed surface and
   callers, and update candidate fingerprints/provenance. The sync script's refusal to overwrite differences is
   intentional.
4. Preserve the release-age policy: wait for eligibility or use a narrowly scoped, approved, expiring exception through
   the existing exception mechanism. Do not disable the policy globally.
5. Run registry verification, `protocol:check-artifacts`, `release:contracts`, `artifacts:check`, CLI artifact
   vendoring/parity, packed consumer checks, and the complete package release gates. Validate SDK curve math against the
   published Solidity revision, including band transitions and overflow/revert behavior; matching ABI/bytecode alone
   does not prove mathematical parity.
6. The Metalayer artifacts, proxy artifacts, and derived bubbled-error ABIs are outside the shared core/router
   comparison. Retain explicit provenance for vendored third-party artifacts and the derivation of composite ABIs; do
   not mark them verified by these two packages.
7. Integrate into PR #15, then publish eligible SDK alpha versions. Core v2 should consume those exact registry versions
   and complete its identity parser, worker wiring, schema, packed-consumer CI, and acceptance work from the prior
   review. These Solidity alphas do not satisfy those independent gates.

### Agent handoff prompt

> Work in the packages repository on its existing feature branch without disturbing concurrent changes. Read AGENTS.md,
> docs/contract-artifacts.md and docs/release-readiness.md. Consume the exact published core and periphery alpha
> versions above, or use verified local tarballs for temporary testing until registry publication succeeds. Add separate
> authoritative router provenance, update the exact pins and release checker, deliberately reconcile MigrationMode, and
> run the existing release gates. Do not overwrite the current contract snapshots with older application sources. Do not
> weaken release-age, provenance, curve-parity, or Core acceptance gates to make CI green. Report any SDK math or API
> changes needed by the canonical Solidity revision. Do not merge PR #15 into main until its remaining release gates
> pass.
