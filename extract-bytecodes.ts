import * as fs from 'fs';
import * as path from 'path';

// npx tsx extract-bytecodes.ts
// List of contracts to extract bytecode for
// Add new contract names here to include them in the extraction
const CONTRACTS_TO_EXTRACT = [
  'MultiVault',
  'MultiVaultMigrationMode',
  'FeeProxy',
  'BaseEmissionsController',
  'SatelliteEmissionsController',
  'TrustBonding',
  'BondingCurveRegistry',
  'LinearCurve',
  'OffsetProgressiveCurve',
  'DynamicFeeFlatPriceCurve',
  'AtomWallet',
  'AtomWalletFactory',
  'AtomWarden',
  'Trust',
  'TrustToken',
  'WrappedTrust',
  'MultiVaultLib'
];

interface ContractArtifact {
  bytecode: {
    object: string;
    linkReferences?: Record<string, Record<string, Array<{ start: number; length: number }>>>;
    [key: string]: any;
  };
  [key: string]: any;
}

// Contracts whose bytecode contains unlinked library placeholders (populated during extraction)
const contractsWithLinkReferences = new Set<string>();

function extractBytecodes() {
  const outDir = path.join(import.meta.dirname, 'out');
  const bytecodesDir = path.join(import.meta.dirname, 'bytecodes');

  // Create bytecodes directory if it doesn't exist
  if (!fs.existsSync(bytecodesDir)) {
    fs.mkdirSync(bytecodesDir, { recursive: true });
  }

  console.log('Extracting bytecode from contracts...');

  for (const contractName of CONTRACTS_TO_EXTRACT) {
    try {
      const contractDir = path.join(outDir, `${contractName}.sol`);
      const contractFile = path.join(contractDir, `${contractName}.json`);

      if (!fs.existsSync(contractFile)) {
        console.warn(`Warning: Contract file not found for ${contractName} at ${contractFile}`);
        continue;
      }

      // Read the contract artifact
      const artifactContent = fs.readFileSync(contractFile, 'utf-8');
      const artifact: ContractArtifact = JSON.parse(artifactContent);

      if (!artifact.bytecode || !artifact.bytecode.object) {
        console.warn(`Warning: No valid bytecode found for ${contractName}`);
        continue;
      }

      const bytecode = artifact.bytecode.object.startsWith('0x')
        ? artifact.bytecode.object
        : `0x${artifact.bytecode.object}`;

      // Generate TypeScript content
      let tsContent = `export const ${contractName}Bytecode: \`0x\${string}\` =\n  '${bytecode}';\n`;

      // Bytecode that links external libraries contains __$<hash>$__ placeholders that must be
      // replaced with the deployed library address (without 0x prefix) before deployment.
      // Export the placeholder for each library so consumers can perform the substitution.
      const linkReferences = artifact.bytecode.linkReferences ?? {};
      const linkEntries: string[] = [];
      for (const [sourceFile, libraries] of Object.entries(linkReferences)) {
        for (const [libraryName, refs] of Object.entries(libraries)) {
          const { start } = refs[0];
          // Placeholders occupy 20 bytes (40 hex chars); +2 skips the 0x prefix
          const placeholder = bytecode.slice(2 + start * 2, 2 + start * 2 + 40);
          linkEntries.push(`  '${sourceFile}:${libraryName}': '${placeholder}'`);
        }
      }
      if (linkEntries.length > 0) {
        tsContent +=
          `\n// Replace each placeholder with the deployed library address (lowercase, no 0x prefix)\n` +
          `export const ${contractName}LinkReferences = {\n${linkEntries.join(',\n')}\n} as const;\n`;
        contractsWithLinkReferences.add(contractName);
      }

      // Write to TypeScript file
      const outputFile = path.join(bytecodesDir, `${contractName}.ts`);
      fs.writeFileSync(outputFile, tsContent);

      const linkNote = linkEntries.length > 0 ? `, ${linkEntries.length} link reference(s)` : '';
      console.log(`✓ Extracted bytecode for ${contractName} (${bytecode.length} bytes${linkNote})`);
    } catch (error) {
      console.error(`Error extracting bytecode for ${contractName}:`, error);
    }
  }

  // Generate index file
  generateIndexFile(bytecodesDir);

  console.log('\nBytecode extraction completed!');
  console.log(`Bytecodes saved to: ${bytecodesDir}`);
}

function generateIndexFile(bytecodesDir: string) {
  const indexContent = CONTRACTS_TO_EXTRACT
    .map(contractName => {
      const fileName = `${contractName}.ts`;
      const filePath = path.join(bytecodesDir, fileName);

      if (fs.existsSync(filePath)) {
        const exports = [`${contractName}Bytecode`];
        if (contractsWithLinkReferences.has(contractName)) {
          exports.push(`${contractName}LinkReferences`);
        }
        return `export { ${exports.join(', ')} } from './${contractName}';`;
      }
      return null;
    })
    .filter(Boolean)
    .join('\n');

  const indexFile = path.join(bytecodesDir, 'index.ts');
  fs.writeFileSync(indexFile, indexContent + '\n');
  console.log('✓ Generated index.ts file');
}

// Run the extraction
extractBytecodes();

export { extractBytecodes, CONTRACTS_TO_EXTRACT };
