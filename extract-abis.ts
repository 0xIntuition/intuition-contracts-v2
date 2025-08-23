import * as fs from 'fs';
import * as path from 'path';

// npx tsx extract-abis.ts
// List of contracts to extract ABIs for
// Add new contract names here to include them in the extraction
const CONTRACTS_TO_EXTRACT = [
  'Trust',
  'MultiVault',
  'AtomWalletFactory',
  'SateliteEmissionsController',
  'TrustBonding',
  'BondingCurveRegistry',
  'LinearCurve',
  'ProgressiveCurve',
  'OffsetProgressiveCurve',
  'AtomWallet',
  'TrustToken'
];

interface ContractArtifact {
  abi: any[];
  [key: string]: any;
}

function extractAbis() {
  const outDir = path.join(__dirname, 'out');
  const abisDir = path.join(__dirname, 'abis');

  // Create abis directory if it doesn't exist
  if (!fs.existsSync(abisDir)) {
    fs.mkdirSync(abisDir, { recursive: true });
  }

  console.log('Extracting ABIs from contracts...');

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

      if (!artifact.abi || !Array.isArray(artifact.abi)) {
        console.warn(`Warning: No valid ABI found for ${contractName}`);
        continue;
      }

      // Generate TypeScript content
      const tsContent = `export const ${contractName}Abi = ${JSON.stringify(artifact.abi, null, 2)} as const;\n`;

      // Write to TypeScript file
      const outputFile = path.join(abisDir, `${contractName}.ts`);
      fs.writeFileSync(outputFile, tsContent);

      console.log(`✓ Extracted ABI for ${contractName} (${artifact.abi.length} functions/events)`);
    } catch (error) {
      console.error(`Error extracting ABI for ${contractName}:`, error);
    }
  }

  // Generate index file
  generateIndexFile(abisDir);

  console.log('\nABI extraction completed!');
  console.log(`ABIs saved to: ${abisDir}`);
}

function generateIndexFile(abisDir: string) {
  const indexContent = CONTRACTS_TO_EXTRACT
    .map(contractName => {
      const fileName = `${contractName}.ts`;
      const filePath = path.join(abisDir, fileName);
      
      if (fs.existsSync(filePath)) {
        return `export { ${contractName}Abi } from './${contractName}';`;
      }
      return null;
    })
    .filter(Boolean)
    .join('\n');

  const indexFile = path.join(abisDir, 'index.ts');
  fs.writeFileSync(indexFile, indexContent + '\n');
  console.log('✓ Generated index.ts file');
}

// Run the extraction
if (require.main === module) {
  extractAbis();
}

export { extractAbis, CONTRACTS_TO_EXTRACT };