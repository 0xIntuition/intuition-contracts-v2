import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import { contracts, abiOnly } from "./artifact-config";

type Links = Record<string, Record<string, { start: number; length: number }[]>>;
interface Artifact {
  abi: unknown[];
  bytecode: { object: string; linkReferences?: Links };
  metadata: { compiler: { version: string }; settings: unknown; sources: unknown };
}
const root = resolve(import.meta.dirname, "..");
const sha256 = (value: unknown) => createHash("sha256").update(JSON.stringify(value)).digest("hex");

export function readArtifacts(outDir = resolve(root, "out")) {
  // Read and validate everything before touching any generated file.
  return [...contracts, ...abiOnly].map((name) => {
    const artifact: Artifact = JSON.parse(readFileSync(resolve(outDir, `${name}.sol`, `${name}.json`), "utf8"));
    if (!Array.isArray(artifact.abi) || artifact.abi.length === 0) throw new Error(`${name}: invalid ABI`);
    if (!artifact.metadata?.compiler?.version) throw new Error(`${name}: missing compiler metadata`);
    const hasBytecode = (contracts as readonly string[]).includes(name);
    const bytecode = artifact.bytecode?.object;
    if (hasBytecode && (!bytecode || bytecode === "0x")) throw new Error(`${name}: missing creation bytecode`);
    const placeholders: Record<string, string> = {};
    if (hasBytecode) {
      const body = bytecode.replace(/^0x/, "");
      let linked = body;
      for (const [source, libraries] of Object.entries(artifact.bytecode.linkReferences ?? {})) {
        for (const [library, references] of Object.entries(libraries)) {
          if (!references.length) throw new Error(`${name}: empty link references`);
          const placeholder = body.slice(references[0].start * 2, (references[0].start + 20) * 2);
          if (!/^__\$[0-9a-f]{34}\$__$/.test(placeholder)) throw new Error(`${name}: invalid library placeholder`);
          for (const ref of references) {
            if (ref.length !== 20 || body.slice(ref.start * 2, (ref.start + ref.length) * 2) !== placeholder)
              throw new Error(`${name}: inconsistent library references`);
          }
          placeholders[`${source}:${library}`] = placeholder;
          linked = linked.replaceAll(placeholder, "0".repeat(40));
        }
      }
      if (!/^(?:[0-9a-fA-F]{2})+$/.test(linked))
        throw new Error(`${name}: invalid or unaccounted-for bytecode placeholders`);
    }
    return {
      name,
      artifact,
      hasBytecode,
      bytecode: hasBytecode ? `0x${bytecode.replace(/^0x/, "")}` : undefined,
      placeholders,
    };
  });
}

export function extractArtifacts(
  kind: "abis" | "bytecodes",
  outDir = resolve(root, "out"),
  targetDir = resolve(root, kind),
) {
  const artifacts = readArtifacts(outDir);
  mkdirSync(targetDir, { recursive: true });
  const exports: string[] = [];
  const generated = new Set(["index.ts"]);
  for (const { name, artifact, hasBytecode, bytecode, placeholders } of artifacts) {
    if (kind === "bytecodes" && !hasBytecode) continue;
    const symbol = `${name}${kind === "abis" ? "Abi" : "Bytecode"}`;
    let content =
      kind === "abis"
        ? `export const ${symbol} = ${JSON.stringify(artifact.abi, null, 2)} as const;\n`
        : `export const ${symbol}: \`0x\${string}\` =\n  '${bytecode}';\n`;
    const names = [symbol];
    if (kind === "bytecodes" && Object.keys(placeholders).length) {
      content += `\n// Replace every placeholder with the deployed library address (without 0x).\nexport const ${name}LinkReferences = ${JSON.stringify(placeholders, null, 2)} as const;\n`;
      content += `export const ${name}LinkReferencePositions = ${JSON.stringify(artifact.bytecode.linkReferences, null, 2)} as const;\n`;
      names.push(`${name}LinkReferences`, `${name}LinkReferencePositions`);
    }
    writeFileSync(resolve(targetDir, `${name}.ts`), content);
    generated.add(`${name}.ts`);
    exports.push(`export { ${names.join(", ")} } from './${name}';`);
  }
  for (const file of readdirSync(targetDir)) {
    if (file.endsWith(".ts") && !generated.has(file)) rmSync(resolve(targetDir, file));
  }
  writeFileSync(resolve(targetDir, "index.ts"), exports.join("\n") + "\n");
  console.log(`Extracted ${exports.length} ${kind}.`);
}

export function writeManifest() {
  const artifacts = readArtifacts();
  const pkg = JSON.parse(readFileSync(resolve(root, "package.json"), "utf8"));
  const manifest = {
    schemaVersion: 1,
    package: pkg.name,
    version: pkg.version,
    // Compiler metadata includes the source hashes and settings actually used by solc.
    artifacts: Object.fromEntries(
      artifacts.map(({ name, artifact, bytecode }) => [
        name,
        {
          abiSha256: sha256(artifact.abi),
          ...(bytecode
            ? { bytecodeSha256: sha256(bytecode), linkReferences: artifact.bytecode.linkReferences ?? {} }
            : {}),
          compiler: artifact.metadata.compiler,
          settings: artifact.metadata.settings,
          sources: artifact.metadata.sources,
        },
      ]),
    ),
  };
  writeFileSync(resolve(root, "artifact-manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
}
