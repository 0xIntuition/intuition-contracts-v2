import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, cpSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { readArtifacts, extractArtifacts } from "./extract-artifacts";

const hash = (value: unknown) => createHash("sha256").update(JSON.stringify(value)).digest("hex");

test("built ESM and CommonJS exports match compiler output and release manifest", async () => {
  const esm = await import("../dist/" + "index.js");
  const cjs = require("../dist/index.cjs");
  const manifest = JSON.parse(readFileSync("artifact-manifest.json", "utf8"));
  const pkg = JSON.parse(readFileSync("package.json", "utf8"));
  assert.equal(manifest.version, pkg.version);
  for (const { name, artifact, bytecode, placeholders } of readArtifacts()) {
    assert.deepEqual(esm[`${name}Abi`], artifact.abi);
    assert.deepEqual(cjs[`${name}Abi`], artifact.abi);
    assert.equal(manifest.artifacts[name].abiSha256, hash(artifact.abi));
    if (bytecode) {
      assert.equal(esm[`${name}Bytecode`], bytecode);
      assert.equal(cjs[`${name}Bytecode`], bytecode);
      assert.equal(manifest.artifacts[name].bytecodeSha256, hash(bytecode));
      if (Object.keys(placeholders).length) {
        assert.deepEqual(esm[`${name}LinkReferences`], placeholders);
        assert.deepEqual(esm[`${name}LinkReferencePositions`], artifact.bytecode.linkReferences);
      }
    }
  }
});

test("missing or malformed artifacts fail without changing previous output", () => {
  const dir = mkdtempSync(join(tmpdir(), "contracts-extract-"));
  try {
    const out = join(dir, "out");
    const target = join(dir, "abis");
    mkdirSync(target);
    writeFileSync(join(target, "index.ts"), "sentinel");
    assert.throws(() => extractArtifacts("abis", out, target));
    assert.equal(readFileSync(join(target, "index.ts"), "utf8"), "sentinel");
    for (const { name } of readArtifacts()) cpSync(`out/${name}.sol`, join(out, `${name}.sol`), { recursive: true });
    const file = join(out, "MultiVault.sol/MultiVault.json");
    const artifact = JSON.parse(readFileSync(file, "utf8"));
    artifact.bytecode.linkReferences = {};
    writeFileSync(file, JSON.stringify(artifact));
    assert.throws(() => extractArtifacts("bytecodes", out, target), /unaccounted-for/);
    assert.equal(readFileSync(join(target, "index.ts"), "utf8"), "sentinel");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("successful extraction removes obsolete generated exports", () => {
  const dir = mkdtempSync(join(tmpdir(), "contracts-stale-"));
  try {
    writeFileSync(join(dir, "Obsolete.ts"), "export const stale = true;");
    extractArtifacts("abis", undefined, dir);
    assert.equal(existsSync(join(dir, "Obsolete.ts")), false);
    assert.match(readFileSync(join(dir, "index.ts"), "utf8"), /IBaseCurveAbi/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
