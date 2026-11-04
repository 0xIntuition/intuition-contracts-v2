import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";

const root = resolve(import.meta.dirname, "..");
const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const temp = mkdtempSync(join(tmpdir(), "intuition-packed-"));
const run = (command, args, cwd = temp) =>
  execFileSync(command, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
try {
  // The caller builds first; ignore lifecycle scripts here to avoid recursive packing.
  const [pack] = JSON.parse(run("npm", ["pack", "--ignore-scripts", "--json", "--pack-destination", temp], root));
  assert(pack.files.some((file) => file.path === "artifact-manifest.json"));
  assert(pack.files.some((file) => file.path.endsWith(".sol")));
  assert(!pack.files.some((file) => /^(tests|script|lib|node_modules)\//.test(file.path)));
  writeFileSync(join(temp, "package.json"), JSON.stringify({ private: true, type: "module" }));
  run("npm", ["install", "--ignore-scripts", "--no-audit", "--no-fund", join(temp, pack.filename)]);
  const check = `
    import assert from 'node:assert/strict';
    import { createHash } from 'node:crypto';
        import { createRequire } from 'node:module';
    const require = createRequire(import.meta.url);
    const esm = await import(${JSON.stringify(pkg.name)});
    const abis = await import(${JSON.stringify(pkg.name + "/abis")});
    const bytecodes = await import(${JSON.stringify(pkg.name + "/bytecodes")});
    const cjs = require(${JSON.stringify(pkg.name)});
    const cjsAbis = require(${JSON.stringify(pkg.name + "/abis")});
    const cjsBytecodes = require(${JSON.stringify(pkg.name + "/bytecodes")});
    const manifest = require(${JSON.stringify(pkg.name + "/artifact-manifest.json")});
    const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
    assert.equal(manifest.version, ${JSON.stringify(pkg.version)});
    for (const [name, artifact] of Object.entries(manifest.artifacts)) {
      for (const exports of [esm, cjs, abis, cjsAbis]) assert.equal(hash(exports[name + 'Abi']), artifact.abiSha256);
      if (artifact.bytecodeSha256) for (const exports of [esm, cjs, bytecodes, cjsBytecodes]) assert.equal(hash(exports[name + 'Bytecode']), artifact.bytecodeSha256);
    }
  `;
  writeFileSync(join(temp, "consumer.mjs"), check);
  run("node", ["consumer.mjs"]);
  const manifest = JSON.parse(readFileSync(join(root, "artifact-manifest.json"), "utf8"));
  const name = Object.keys(manifest.artifacts)[0];
  const typecheck = `import { ${name}Abi } from '${pkg.name}/abis';\nimport { ${name}Bytecode } from '${pkg.name}/bytecodes';\nconst abi: readonly unknown[] = ${name}Abi;\nconst bytecode: \`0x\${string}\` = ${name}Bytecode;\n`;
  for (const extension of ["mts", "cts"]) {
    writeFileSync(join(temp, `consumer.${extension}`), typecheck);
    run(join(root, "node_modules/.bin/tsc"), [
      "--noEmit",
      "--strict",
      "--skipLibCheck",
      "--target",
      "es2022",
      "--module",
      "NodeNext",
      "--moduleResolution",
      "NodeNext",
      `consumer.${extension}`,
    ]);
  }
  for (const source of Object.values(manifest.artifacts).flatMap((artifact) => Object.keys(artifact.sources))) {
    if (source.startsWith("src/") || source.startsWith("contracts/"))
      assert(existsSync(join(temp, "node_modules", pkg.name, source)), `Missing shipped source ${source}`);
  }
  // Compile the shipped sources with only npm-installed dependencies, without repository submodules.
  const periphery = pkg.name.endsWith("-periphery");
  const sourceDir = periphery ? "contracts" : "src";
  const prefix = `node_modules/${pkg.name}/`;
  const remappings = periphery
    ? [`contracts/=${prefix}contracts/`, "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/"]
    : [
        `src/=${prefix}src/`,
        "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/",
        "@openzeppelin/contracts-upgradeable/=node_modules/@openzeppelin/contracts-upgradeable/",
        "@openzeppelin-v4/contracts/=node_modules/@openzeppelin-v4/contracts/",
        "@openzeppelin-v4/contracts-upgradeable/=node_modules/@openzeppelin-v4/contracts-upgradeable/",
        "solady/=node_modules/solady/src/",
        "@prb/math/=node_modules/@prb/math/",
        "@account-abstraction/=node_modules/@account-abstraction/contracts/",
      ];
  writeFileSync(
    join(temp, "foundry.toml"),
    `[profile.default]\nsrc = "${prefix}${sourceDir}"\nsolc = "0.8.29"\nevm_version = "cancun"\noptimizer = true\noptimizer_runs = 10000\nbytecode_hash = "none"\nremappings = ${JSON.stringify(remappings)}\n`,
  );
  run("forge", ["build"]);
  // File names affect library placeholders; compare the unlinked bytes with addresses zeroed.
  const normalize = (value) => value.replace(/^0x/, "").replace(/__\$[0-9a-f]{34}\$__/g, "0".repeat(40));
  const upstreamBytecodes = await import(join(root, "dist/bytecodes/index.js"));
  const upstreamAbis = await import(join(root, "dist/abis/index.js"));
  const orderedAbi = (abi) => abi.map((item) => JSON.stringify(item)).sort();
  for (const [name, artifact] of Object.entries(manifest.artifacts)) {
    const file = join(temp, "out", `${name}.sol`, `${name}.json`);
    // TimelockController is exported from OpenZeppelin but not imported by the shipped core sources.
    if (!existsSync(file)) {
      assert.equal(name, "TimelockController");
      run("forge", ["build", "node_modules/@openzeppelin/contracts/governance/TimelockController.sol"]);
    }
    const rebuilt = JSON.parse(readFileSync(file, "utf8"));
    // solc can reorder overloads when dependency source paths change. Keep all entries and compare their full structures.
    assert.deepEqual(orderedAbi(rebuilt.abi), orderedAbi(upstreamAbis[name + "Abi"]), `${name}: npm source ABI drift`);
    if (artifact.bytecodeSha256)
      assert.equal(
        normalize(rebuilt.bytecode.object),
        normalize(upstreamBytecodes[name + "Bytecode"]),
        `${name}: npm source bytecode drift`,
      );
  }
  console.log(
    `${pkg.name}@${pkg.version}: packed ESM, CJS, TypeScript and npm-only Solidity rebuild passed.\n${pack.integrity}`,
  );
} finally {
  if (process.env.KEEP_PACKED_TEST) console.log(`Packed test directory: ${temp}`);
  else rmSync(temp, { recursive: true, force: true });
}
