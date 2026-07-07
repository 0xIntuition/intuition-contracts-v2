import * as fs from 'fs';
import * as path from 'path';

// npx tsx extract-bytecodes.ts
// List of contracts to extract bytecode for
// Add new contract names here to include them in the extraction
const CONTRACTS_TO_EXTRACT = [
  'MultiVault',
  'MultiVaultMigrationMode',
  'BaseEmissionsController',
  'SatelliteEmissionsController',
  'TrustBonding',
  'BondingCurveRegistry',
  'LinearCurve',
  'OffsetProgressiveCurve',
  'AtomWallet',
  'AtomWalletFactory',
  'Trust',
  'TrustToken'
];

interface ContractArtifact {
  bytecode: {
    object: string;
    [key: string]: any;
  };
  [key: string]: any;
}

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
      const tsContent = `export const ${contractName}Bytecode: \`0x\${string}\` =\n  '${bytecode}';\n`;

      // Write to TypeScript file
      const outputFile = path.join(bytecodesDir, `${contractName}.ts`);
      fs.writeFileSync(outputFile, tsContent);

      console.log(`✓ Extracted bytecode for ${contractName} (${bytecode.length} bytes)`);
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
        return `export { ${contractName}Bytecode } from './${contractName}';`;
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
