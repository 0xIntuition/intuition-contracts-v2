import { ethers } from "ethers";
import * as dotenv from "dotenv";
import yargs from "yargs"; // or any CLI arg parser you prefer
import fs from "fs";
import path from "path";
dotenv.config();

/**
 * Minimal interface for the MultiVaultMigration contract.
 * This includes *only* the migration functions used.
 */
const multiVaultMigrationAbi = [
  "function setTermCount(uint256 _termCount) external",
  "function batchSetVaultTotals(uint256[] termIds, uint256 bondingCurveId, (uint256 totalAssets, uint256 totalShares)[] vaultTotals) external",
  "function batchSetAtomData(uint256[] atomIds, bytes[] atomDataArray) external",
  "function batchSetTripleData(uint256[] tripleIds, uint256[3][] tripleAtomIds) external",
  "function batchSetUserBalances(uint256[] termIds, uint256 bondingCurveId, address user, uint256[] balances) external",
];

// --------------------------------------------------------------------------
// CLI Setup
// --------------------------------------------------------------------------
interface CliArgs {
  network: string; // e.g. "base-sepolia"
  migrationData: string; // path to JSON data
  contractAddress: string; // MultiVaultMigration contract address
  privateKey: string; // EOA private key with MIGRATOR_ROLE
  batchSize: number; // default 50
  resumeStep: number; // which main step to resume from
  resumeBatch: number; // which sub-batch to resume from
}

// We can also add the .env or .json config fallback, etc.
const argv = yargs(process.argv.slice(2))
  .option("network", {
    type: "string",
    describe: "Network to connect to (base-mainnet or base-sepolia)",
    default: "base-sepolia",
  })
  .option("migrationData", {
    type: "string",
    describe: "Path to the JSON with migration data",
    default: "script/migration/migrationData.json",
  })
  .option("contractAddress", {
    type: "string",
    describe: "MultiVaultMigration contract address",
    default: "0xF282eFd6F686A71A13b2970bb03b1Cd54c49e87C",
  })
  .option("privateKey", {
    type: "string",
    describe: "Private key of the migrator EOA",
    default: process.env.MIGRATOR_PRIVATE_KEY,
  })
  .option("batchSize", {
    type: "number",
    describe: "Batch size for each contract call",
    default: 10,
  })
  .option("resumeStep", {
    type: "number",
    describe:
      "Step index to resume from (0-based). Steps are: " +
      "0=setTermCount, 1=setVaultTotals, 2=setAtomData, 3=setTripleData, 4=setUserBalances",
    default: 0,
  })
  .option("resumeBatch", {
    type: "number",
    describe: "Batch index to resume from within a step",
    default: 0,
  })
  .help().argv as unknown as CliArgs;

// --------------------------------------------------------------------------
// Load/Check Required Environment and Data
// --------------------------------------------------------------------------
const BASE_RPC_URL =
  argv.network === "base-sepolia"
    ? process.env.BASE_SEPOLIA_RPC_URL
    : process.env.BASE_RPC_URL;
if (!BASE_RPC_URL) {
  throw new Error("Missing BASE_RPC_URL in .env");
}

const provider = new ethers.providers.JsonRpcProvider(BASE_RPC_URL);
// @ts-ignore
const signer = new ethers.Wallet(argv.privateKey, provider);

// --------------------------------------------------------------------------
// Utility Functions
// --------------------------------------------------------------------------
function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

/**
 * Check EOA balance each time we start a batch of calls.
 * If balance < 0.1 ETH, log a warning.
 */
async function checkEOABalanceWarning() {
  const balanceWei = await provider.getBalance(signer.address);
  const balanceEth = parseFloat(ethers.utils.formatEther(balanceWei));
  if (balanceEth < 0.1) {
    console.warn(
      `\n[WARNING] Balance for ${signer.address} is below 0.1 ETH (${balanceEth} ETH). ` +
        `Please top up before continuing!\n`
    );
  }
}

// --------------------------------------------------------------------------
// Main Migration Logic
// --------------------------------------------------------------------------
async function main() {
  console.log(`\n=== Starting MultiVaultMigration Script ===`);
  console.log(`RPC: ${BASE_RPC_URL}`);
  console.log(`Contract: ${argv.contractAddress}`);
  console.log(`Migrator EOA: ${signer.address}`);
  console.log(`Batch size: ${argv.batchSize}`);
  console.log(
    `Resume from step: ${argv.resumeStep}, batch: ${argv.resumeBatch}\n`
  );

  // Load migration data
  const migrationDataPath = path.resolve(argv.migrationData);
  if (!fs.existsSync(migrationDataPath)) {
    throw new Error(`Migration data file not found at ${migrationDataPath}`);
  }
  const rawData = fs.readFileSync(migrationDataPath, "utf8");
  const data = JSON.parse(rawData);

  // Attach to contract
  const multiVaultMigration = new ethers.Contract(
    argv.contractAddress,
    multiVaultMigrationAbi,
    signer
  );

  // The order in which we'll run the steps:
  // 1. setTermCount
  // 2. setVaultTotals
  // 3. setAtomData
  // 4. setTripleData
  // 5. setUserBalances
  const steps = [
    setTermCountStep,
    setVaultTotalsStep,
    setAtomDataStep,
    setTripleDataStep,
    setUserBalancesStep,
  ];

  // For convenience we map step indexes to descriptive names:
  const stepNames = [
    "setTermCount",
    "setVaultTotals",
    "setAtomData",
    "setTripleData",
    "setUserBalances",
  ];

  // Run steps in sequence, but skip up to argv.resumeStep
  for (let stepIndex = argv.resumeStep; stepIndex < steps.length; stepIndex++) {
    console.log(
      `\n=== Running Step [${stepIndex}] ${stepNames[stepIndex]} ===`
    );
    await steps[stepIndex]({
      contract: multiVaultMigration,
      data,
      batchSize: argv.batchSize,
      resumeBatch: stepIndex === argv.resumeStep ? argv.resumeBatch : 0,
    });
  }

  console.log("\n=== All Steps Completed Successfully! ===");
}

/**
 * Step 0: setTermCount
 */
async function setTermCountStep(ctx: {
  contract: ethers.Contract;
  data: any;
  batchSize: number;
  resumeBatch: number; // not used here, but we accept it for uniformity
}) {
  const { contract, data } = ctx;

  // If termCount is zero or not present, you might skip or handle differently
  if (!data.termCount || data.termCount === 0) {
    console.log(
      `termCount is not set or is zero in the data; skipping setTermCount...`
    );
    return;
  }

  try {
    await checkEOABalanceWarning();
    console.log(`Setting termCount=${data.termCount}...`);
    const tx = await contract.setTermCount(data.termCount);
    await tx.wait();
    console.log(`[setTermCount] Done. TxHash = ${tx.hash}`);
  } catch (err: any) {
    console.error(
      `[ERROR] Step 0 (setTermCount) failed: ${err.message || err}`
    );
    // If you want to do a more complex "save progress" or "exit code" logic, do that here
    throw err;
  }
}

/**
 * Step 1: setVaultTotals
 */
async function setVaultTotalsStep(ctx: {
  contract: ethers.Contract;
  data: any;
  batchSize: number;
  resumeBatch: number;
}) {
  const { contract, data, batchSize, resumeBatch } = ctx;

  if (!data.vaults || Object.keys(data.vaults).length === 0) {
    console.log(`No vaults data found; skipping setVaultTotals...`);
    return;
  }

  // The data shape is:
  // vaults: {
  //   "bondingCurve1": {
  //     "termId1": { "totalAssets": <>, "totalShares": <> },
  //     "termId2": ...
  //   },
  //   "bondingCurve2": ...
  // }

  // We'll batch by "bondingCurve" at a time, but within each bondingCurve, we chunk
  // the termIds in groups of up to `batchSize`.
  const bondingCurveIds = Object.keys(data.vaults);

  let globalBatchCounter = 0; // a global sub-batch index across all bonding curves

  for (let bcIndex = 0; bcIndex < bondingCurveIds.length; bcIndex++) {
    const bondingCurveId = bondingCurveIds[bcIndex];
    const terms = Object.entries(data.vaults[bondingCurveId]); // [[termId, { totalAssets, totalShares }], ...]
    if (terms.length === 0) continue;

    // Separate arrays for batchSetVaultTotals
    const termIdsAll = terms.map(([termId]) => Number(termId));
    const vaultTotalsAll = terms.map(
      ([, { totalAssets, totalShares }]: [string, any]) => ({
        totalAssets: ethers.BigNumber.from(totalAssets.toString()),
        totalShares: ethers.BigNumber.from(totalShares.toString()),
      })
    );

    // Now chunk them
    const termIdChunks = chunkArray(termIdsAll, batchSize);
    const vaultTotalsChunks = chunkArray(vaultTotalsAll, batchSize);

    for (
      let subBatchIndex = 0;
      subBatchIndex < termIdChunks.length;
      subBatchIndex++
    ) {
      // If we haven't caught up to resumeBatch, skip
      if (globalBatchCounter < resumeBatch) {
        globalBatchCounter++;
        continue;
      }

      await checkEOABalanceWarning();

      const termIdsChunk = termIdChunks[subBatchIndex];
      const vaultTotalsChunk = vaultTotalsChunks[subBatchIndex];
      console.log(
        `Setting Vault Totals for bondingCurveId=${bondingCurveId}, batch #${globalBatchCounter}, size=${termIdsChunk.length}`
      );

      try {
        const tx = await contract.batchSetVaultTotals(
          termIdsChunk,
          Number(bondingCurveId),
          vaultTotalsChunk
        );
        await tx.wait();
        console.log(
          `[setVaultTotals] bondingCurve=${bondingCurveId}, subBatchIndex=${subBatchIndex}, TxHash=${tx.hash}`
        );
      } catch (err: any) {
        console.error(
          `[ERROR] setVaultTotals failed at globalBatch=${globalBatchCounter}, bc=${bondingCurveId}, subBatchIndex=${subBatchIndex}: ${
            err.message || err
          }`
        );
        // Throw so script halts and user can see exactly where it failed
        throw err;
      }

      globalBatchCounter++;
    }
  }
}

/**
 * Step 2: setAtomData
 */
async function setAtomDataStep(ctx: {
  contract: ethers.Contract;
  data: any;
  batchSize: number;
  resumeBatch: number;
}) {
  const { contract, data, batchSize, resumeBatch } = ctx;

  if (!data.atoms || Object.keys(data.atoms).length === 0) {
    console.log("No atoms data found; skipping setAtomData...");
    return;
  }

  // Shape:
  // atoms: {
  //   "atomId1": { "atomURI": "..." },
  //   "atomId2": ...
  // }
  const atomEntries = Object.entries(data.atoms);
  // e.g. [["atomId1", {atomURI: "..." }], ["atomId2", ...], ...]

  // Build arrays for chunk calls
  const atomIdsAll = atomEntries.map(([atomId]) => Number(atomId));
  const atomDataAll = atomEntries.map(([, { atomURI }]: [string, any]) => {
    // Convert string to bytes if needed – or if the contract is okay with normal "string" as bytes, just do:
    return ethers.utils.toUtf8Bytes(atomURI);
  });

  const atomIdChunks = chunkArray(atomIdsAll, batchSize);
  const atomDataChunks = chunkArray(atomDataAll, batchSize);

  for (
    let subBatchIndex = resumeBatch;
    subBatchIndex < atomIdChunks.length;
    subBatchIndex++
  ) {
    await checkEOABalanceWarning();

    const atomIdsChunk = atomIdChunks[subBatchIndex];
    const atomDataChunk = atomDataChunks[subBatchIndex];
    console.log(
      `Setting Atom Data batch #${subBatchIndex}, size=${atomIdsChunk.length}`
    );

    try {
      const tx = await contract.batchSetAtomData(atomIdsChunk, atomDataChunk);
      await tx.wait();
      console.log(
        `[setAtomData] subBatchIndex=${subBatchIndex}, TxHash=${tx.hash}`
      );
    } catch (err: any) {
      console.error(
        `[ERROR] setAtomData failed at subBatchIndex=${subBatchIndex}: ${
          err.message || err
        }`
      );
      throw err;
    }
  }
}

/**
 * Step 3: setTripleData
 */
async function setTripleDataStep(ctx: {
  contract: ethers.Contract;
  data: any;
  batchSize: number;
  resumeBatch: number;
}) {
  const { contract, data, batchSize, resumeBatch } = ctx;

  if (!data.triples || Object.keys(data.triples).length === 0) {
    console.log("No triples data found; skipping setTripleData...");
    return;
  }

  // Shape:
  // "triples": {
  //   "tripleId1": { "tripleAtomIds": [0, 1, 2] }
  // }
  const tripleEntries = Object.entries(data.triples);
  // e.g. [["tripleId1", { tripleAtomIds: [0,1,2] }], ...]

  const tripleIdsAll = tripleEntries.map(([tripleId]) => Number(tripleId));
  const tripleAtomIdsAll = tripleEntries.map(
    ([, { tripleAtomIds }]: [string, any]) => tripleAtomIds
  );

  const tripleIdsChunks = chunkArray(tripleIdsAll, batchSize);
  const tripleAtomIdsChunks = chunkArray(tripleAtomIdsAll, batchSize);

  for (
    let subBatchIndex = resumeBatch;
    subBatchIndex < tripleIdsChunks.length;
    subBatchIndex++
  ) {
    await checkEOABalanceWarning();

    const tripleIdsChunk = tripleIdsChunks[subBatchIndex];
    const tripleAtomIdsChunk = tripleAtomIdsChunks[subBatchIndex];

    console.log(
      `Setting Triple Data batch #${subBatchIndex}, size=${tripleIdsChunk.length}`
    );

    try {
      const tx = await contract.batchSetTripleData(
        tripleIdsChunk,
        tripleAtomIdsChunk
      );
      await tx.wait();
      console.log(
        `[setTripleData] subBatchIndex=${subBatchIndex}, TxHash=${tx.hash}`
      );
    } catch (err: any) {
      console.error(
        `[ERROR] setTripleData failed at subBatchIndex=${subBatchIndex}: ${
          err.message || err
        }`
      );
      throw err;
    }
  }
}

/**
 * Step 4: setUserBalances
 *
 * For large numbers of user positions, this is likely by far the biggest step.
 */
async function setUserBalancesStep(ctx: {
  contract: ethers.Contract;
  data: any;
  batchSize: number;
  resumeBatch: number;
}) {
  const { contract, data, batchSize, resumeBatch } = ctx;

  // Shape:
  // "users": {
  //   "user1": {
  //     "bondingCurve1": {
  //       "termId1": { "userBalance": 1 },
  //       "termId2": { ... },
  //     },
  //     "bondingCurve2": ...
  //   },
  //   "user2": ...
  // }
  if (!data.users || Object.keys(data.users).length === 0) {
    console.log("No user data found; skipping setUserBalances...");
    return;
  }

  // We'll iterate user by user, then for each bondingCurve, gather the termIds and balances in arrays, chunk them, etc.
  const userAddresses = Object.keys(data.users);
  let globalBatchCounter = 0;

  for (let userIdx = 0; userIdx < userAddresses.length; userIdx++) {
    const userAddr = userAddresses[userIdx];
    const bondingCurves = Object.entries(data.users[userAddr]);
    // e.g. [["bondingCurve1", {...}], ["bondingCurve2", {...}]]

    for (const [bondingCurveId, termsObj] of bondingCurves) {
      // e.g. termsObj = { "termId1": { "userBalance": <number> }, ... }
      // @ts-ignore
      const termEntries = Object.entries(termsObj);
      if (termEntries.length === 0) continue;

      const termIdsAll = termEntries.map(([termId]) => Number(termId));
      const balancesAll = termEntries.map(
        ([, { userBalance }]: [string, any]) =>
          ethers.BigNumber.from(userBalance.toString())
      );

      const termIdChunks = chunkArray(termIdsAll, batchSize);
      const balanceChunks = chunkArray(balancesAll, batchSize);

      for (
        let subBatchIndex = 0;
        subBatchIndex < termIdChunks.length;
        subBatchIndex++
      ) {
        if (globalBatchCounter < resumeBatch) {
          globalBatchCounter++;
          continue;
        }

        await checkEOABalanceWarning();

        const termIdsChunk = termIdChunks[subBatchIndex];
        const balancesChunk = balanceChunks[subBatchIndex];

        console.log(
          `Setting User Balances for user=${userAddr}, bondingCurve=${bondingCurveId}, globalBatch=#${globalBatchCounter}, size=${termIdsChunk.length}`
        );
        try {
          const tx = await contract.batchSetUserBalances(
            termIdsChunk,
            Number(bondingCurveId),
            userAddr,
            balancesChunk
          );
          await tx.wait();
          console.log(
            `[setUserBalances] user=${userAddr}, bc=${bondingCurveId}, subBatchIndex=${subBatchIndex}, TxHash=${tx.hash}`
          );
        } catch (err: any) {
          console.error(
            `[ERROR] setUserBalances failed at globalBatch=${globalBatchCounter}, user=${userAddr}, bc=${bondingCurveId}, subBatchIndex=${subBatchIndex}: ${
              err.message || err
            }`
          );
          throw err;
        }

        globalBatchCounter++;
      }
    }
  }
}

// --------------------------------------------------------------------------
// Execute script
// --------------------------------------------------------------------------
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(`[FATAL] Migration script failed: ${error.message || error}`);
    process.exit(1);
  });
