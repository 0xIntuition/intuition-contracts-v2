import { ethers } from "ethers";

const BLOCK_RANGE_CHUNK_SIZE = 100_000;
const ETHERSCAN_V2_API_URL = "https://api.etherscan.io/v2/api";

const ROLE_NAMES: Record<string, string> = {
  "0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3": "UPGRADER_ROLE",
  "0x0000000000000000000000000000000000000000000000000000000000000000": "DEFAULT_ADMIN_ROLE",
  "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6": "MINTER_ROLE",
  "0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848": "BURNER_ROLE",
  "0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a": "PAUSER_ROLE",
  "0xf66846415d2bf9eabda9e84793ff9c0ea96d87f50fc41e66aa16469c6a442f05": "TIMELOCK_ROLE",
  "0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08": "MANAGER_ROLE",
  "0xc809a7fd521f10cdc3c068621a1c61d5fd9bb3f1502a773e53811bc248d919a8": "BRIDGER_ROLE",
  "0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929": "OPERATOR_ROLE",
  "0x51f7cbaceb42eeb75cf97e030c803852f4c737abd110974f97c5041520a281fd": "TIME_LOCK_ROLE",
  "0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5": "TIMELOCK_ADMIN_ROLE",
  "0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783": "CANCELLER_ROLE",
  "0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63": "EXECUTOR_ROLE",
  "0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1": "PROPOSER_ROLE",
  "0x9c20764ee489aca9767eb49ca1ea4b9367182d11ec9bd87ff1dafc16a7009d47": "ASSET_TRANSFER_ROLE",
  "0x3e49606c6ae7fea13e1df031e21c9a3c3350a65a6842ad7cbaee71b9e7574e5a": "UPKEEP_ROLE",
  "0x7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c570223357": "CONTROLLER_ROLE",
  "0x643676d2b1119408842d7edf610075af886c8b1197b1548d80145808930e1697": "ADMIN_ROLE",
  "0xc9e19f1275fdf2eae30e12c0733c54aa5c1802256d8c46fe9ba9f631bdd6f0b5": "VALIDATOR_ROLE",
};

const ROLE_GRANTED_TOPIC = ethers.utils.id("RoleGranted(bytes32,address,address)");
const ROLE_REVOKED_TOPIC = ethers.utils.id("RoleRevoked(bytes32,address,address)");

function normalizeRoleNames(): Record<string, string> {
  return Object.fromEntries(Object.entries(ROLE_NAMES).map(([roleHash, roleName]) => [roleHash.toLowerCase(), roleName]));
}

function parseCliArguments() {
  const contractAddressRaw = process.argv[2];
  const chainIdRaw = process.argv[3];
  const fromBlockRaw = process.argv[4];
  const toBlockRaw = process.argv[5];
  const rpcUrlRaw = process.argv[6];
  const etherscanApiKeyRaw = process.argv[7];

  if (!contractAddressRaw || !chainIdRaw || !fromBlockRaw || !toBlockRaw || !rpcUrlRaw) {
    throw new Error(
      "Usage: npx tsx script/utils/fetch-roles-summary.ts <CONTRACT_ADDRESS> <CHAIN_ID> <FROM_BLOCK> <TO_BLOCK|latest> <RPC_URL> [ETHERSCAN_API_KEY]"
    );
  }

  if (!ethers.utils.isAddress(contractAddressRaw)) {
    throw new Error(`Invalid contract address: ${contractAddressRaw}`);
  }

  const contractAddress = ethers.utils.getAddress(contractAddressRaw);
  const chainId = Number(chainIdRaw);
  const fromBlock = Number(fromBlockRaw);
  const toBlock = toBlockRaw.toLowerCase() === "latest" ? "latest" : Number(toBlockRaw);

  if (!Number.isInteger(chainId) || chainId <= 0) {
    throw new Error(`Invalid chain ID: ${chainIdRaw}`);
  }
  if (!Number.isInteger(fromBlock) || fromBlock < 0) {
    throw new Error(`Invalid from block: ${fromBlockRaw}`);
  }
  if (toBlock !== "latest" && (!Number.isInteger(toBlock) || toBlock < fromBlock)) {
    throw new Error(`Invalid to block: ${toBlockRaw}`);
  }

  const etherscanApiKey = etherscanApiKeyRaw || process.env.API_KEY_ETHERSCAN;
  return { contractAddress, chainId, fromBlock, toBlock, rpcUrl: rpcUrlRaw, etherscanApiKey };
}

function parseNumberString(value: string | number | undefined): number {
  if (value === undefined) return 0;
  if (typeof value === "number") return value;
  if (value.startsWith("0x") || value.startsWith("0X")) return parseInt(value, 16);
  return parseInt(value, 10);
}

function parseProviderSuggestedRangeLimit(error: unknown): number | null {
  const normalizedError = error as { body?: string; message?: string };
  const messageBody = [normalizedError?.body, normalizedError?.message].filter(Boolean).join(" ");
  const blockRangeMatch = messageBody.match(/up to a\s+(\d+)\s+block range/i);
  if (blockRangeMatch) {
    return parseInt(blockRangeMatch[1], 10);
  }

  const suggestionMatch = messageBody.match(/block range should work:\s*\[(0x[0-9a-f]+),\s*(0x[0-9a-f]+)\]/i);
  if (!suggestionMatch) {
    return null;
  }

  const fromBlock = parseInt(suggestionMatch[1], 16);
  const toBlock = parseInt(suggestionMatch[2], 16);
  if (!Number.isFinite(fromBlock) || !Number.isFinite(toBlock) || toBlock < fromBlock) {
    return null;
  }

  return toBlock - fromBlock + 1;
}

function parseTopicsFromEtherscanLog(log: Record<string, unknown>): string[] {
  const topics = log.topics;
  if (Array.isArray(topics)) {
    return topics.map((topic) => String(topic).toLowerCase());
  }

  const parsedTopics: string[] = [];
  for (let index = 0; index < 4; index++) {
    const topic = log[`topic${index}`];
    if (typeof topic === "string" && topic.length > 0) {
      parsedTopics.push(topic.toLowerCase());
    }
  }
  return parsedTopics;
}

function mapEtherscanLogToProviderLog(log: Record<string, unknown>): ethers.providers.Log {
  const topics = parseTopicsFromEtherscanLog(log);
  return {
    address: ethers.utils.getAddress(String(log.address)),
    topics,
    data: typeof log.data === "string" ? log.data : "0x",
    blockNumber: parseNumberString(log.blockNumber as string | number | undefined),
    transactionHash: String(log.transactionHash ?? ""),
    transactionIndex: parseNumberString(log.transactionIndex as string | number | undefined),
    blockHash: String(log.blockHash ?? ""),
    logIndex: parseNumberString(log.logIndex as string | number | undefined),
    removed: false,
  };
}

async function fetchEtherscanLogsByTopic(
  contractAddress: string,
  chainId: number,
  fromBlock: number,
  toBlock: number,
  topic0: string,
  etherscanApiKey: string
): Promise<ethers.providers.Log[]> {
  const collectedLogs: ethers.providers.Log[] = [];
  const pageSize = 1000;
  let page = 1;

  while (true) {
    const queryParameters = new URLSearchParams({
      chainid: String(chainId),
      module: "logs",
      action: "getLogs",
      fromBlock: String(fromBlock),
      toBlock: String(toBlock),
      address: contractAddress,
      topic0,
      page: String(page),
      offset: String(pageSize),
      apikey: etherscanApiKey,
    });

    const response = await fetch(`${ETHERSCAN_V2_API_URL}?${queryParameters.toString()}`);
    if (!response.ok) {
      throw new Error(`Etherscan logs request failed with HTTP ${response.status}`);
    }

    const payload = (await response.json()) as {
      status?: string;
      message?: string;
      result?: unknown;
    };

    if (!Array.isArray(payload.result)) {
      const errorText = typeof payload.result === "string" ? payload.result : payload.message || "unknown";
      if (String(errorText).toLowerCase().includes("no records found")) {
        break;
      }
      throw new Error(`Etherscan logs request failed: ${errorText}`);
    }

    const pageLogs = payload.result.map((rawLog) => mapEtherscanLogToProviderLog(rawLog as Record<string, unknown>));
    collectedLogs.push(...pageLogs);

    if (pageLogs.length < pageSize) {
      break;
    }
    page += 1;
  }

  return collectedLogs;
}

async function fetchRoleLogsFromEtherscan(
  contractAddress: string,
  chainId: number,
  fromBlock: number,
  toBlock: number,
  etherscanApiKey: string
): Promise<ethers.providers.Log[]> {
  console.log(`[${contractAddress}] falling back to Etherscan logs API`);
  const grantedLogs = await fetchEtherscanLogsByTopic(
    contractAddress,
    chainId,
    fromBlock,
    toBlock,
    ROLE_GRANTED_TOPIC,
    etherscanApiKey
  );
  const revokedLogs = await fetchEtherscanLogsByTopic(
    contractAddress,
    chainId,
    fromBlock,
    toBlock,
    ROLE_REVOKED_TOPIC,
    etherscanApiKey
  );
  return [...grantedLogs, ...revokedLogs];
}

function parseAddressFromTopic(topic: string): string {
  return ethers.utils.getAddress(ethers.utils.hexDataSlice(topic, 12));
}

function getRoleSet(roleHoldersByRole: Map<string, Set<string>>, roleHash: string): Set<string> {
  let roleHolders = roleHoldersByRole.get(roleHash);
  if (!roleHolders) {
    roleHolders = new Set<string>();
    roleHoldersByRole.set(roleHash, roleHolders);
  }

  return roleHolders;
}

async function fetchRoleLogsForContract(
  provider: ethers.providers.Provider,
  contractAddress: string,
  fromBlock: number,
  toBlock: number,
  chainId: number,
  etherscanApiKey?: string
): Promise<ethers.providers.Log[]> {
  const collectedLogs: ethers.providers.Log[] = [];
  let rangeChunkSize = BLOCK_RANGE_CHUNK_SIZE;
  let rangeStartBlock = fromBlock;

  while (rangeStartBlock <= toBlock) {
    const rangeEndBlock = Math.min(rangeStartBlock + rangeChunkSize - 1, toBlock);
    console.log(
      `[${contractAddress}] fetching RoleGranted/RoleRevoked logs in block range ${rangeStartBlock}-${rangeEndBlock}`
    );

    try {
      const logs = await provider.getLogs({
        address: contractAddress,
        fromBlock: rangeStartBlock,
        toBlock: rangeEndBlock,
        topics: [[ROLE_GRANTED_TOPIC, ROLE_REVOKED_TOPIC]],
      });

      collectedLogs.push(...logs);
      rangeStartBlock = rangeEndBlock + 1;
    } catch (error) {
      const suggestedRangeLimit = parseProviderSuggestedRangeLimit(error);
      if (!suggestedRangeLimit) {
        throw error;
      }

      // If a restrictive free-tier cap is detected, use Etherscan API for practical throughput.
      if (suggestedRangeLimit <= 50) {
        if (!etherscanApiKey) {
          throw new Error(
            `RPC provider restricted eth_getLogs to ${suggestedRangeLimit} blocks. Provide ETHERSCAN_API_KEY (arg 7 or env API_KEY_ETHERSCAN) to enable fallback.`
          );
        }
        return fetchRoleLogsFromEtherscan(contractAddress, chainId, fromBlock, toBlock, etherscanApiKey);
      }

      rangeChunkSize = Math.min(rangeChunkSize, suggestedRangeLimit);
      if (rangeChunkSize < 1) {
        rangeChunkSize = 1;
      }
      console.log(`[${contractAddress}] reducing block chunk size to ${rangeChunkSize} due to provider limits`);
    }
  }

  return collectedLogs;
}

function sortLogs(logs: ethers.providers.Log[]): ethers.providers.Log[] {
  return logs.sort((leftLog, rightLog) => {
    if (leftLog.blockNumber !== rightLog.blockNumber) return leftLog.blockNumber - rightLog.blockNumber;
    if (leftLog.transactionIndex !== rightLog.transactionIndex) {
      return leftLog.transactionIndex - rightLog.transactionIndex;
    }
    return leftLog.logIndex - rightLog.logIndex;
  });
}

function buildSummaryRows(
  roleNamesByHash: Record<string, string>,
  roleHoldersByRole: Map<string, Set<string>>
): Array<{ role: string; roleHash: string; holderCount: number; holders: string }> {
  return Object.entries(roleNamesByHash)
    .map(([roleHash, roleName]) => {
      const roleHolders = Array.from(roleHoldersByRole.get(roleHash) ?? []).sort();
      return {
        role: roleName,
        roleHash,
        holderCount: roleHolders.length,
        holders: roleHolders.length > 0 ? roleHolders.join(", ") : "-",
      };
    })
    .sort((leftRow, rightRow) => {
      if (rightRow.holderCount !== leftRow.holderCount) return rightRow.holderCount - leftRow.holderCount;
      return leftRow.role.localeCompare(rightRow.role);
    });
}

async function main() {
  const { contractAddress, chainId, fromBlock, toBlock, rpcUrl, etherscanApiKey } = parseCliArguments();
  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
  const network = await provider.getNetwork();
  if (network.chainId !== chainId) {
    throw new Error(`RPC chain ID mismatch. Expected ${chainId}, got ${network.chainId}`);
  }

  const resolvedToBlock = toBlock === "latest" ? await provider.getBlockNumber() : toBlock;
  if (resolvedToBlock as number < fromBlock) {
    throw new Error(`Invalid block range: fromBlock ${fromBlock} is greater than toBlock ${resolvedToBlock}`);
  }

  const roleNamesByHash = normalizeRoleNames();
  const roleHoldersByRole = new Map<string, Set<string>>();
  const unknownRoleHashes = new Set<string>();
  let skippedUnknownRoleEvents = 0;
  let processedRoleEvents = 0;

  const roleLogs = await fetchRoleLogsForContract(
    provider,
    contractAddress,
    fromBlock,
    resolvedToBlock as number,
    chainId,
    etherscanApiKey
  );
  const sortedRoleLogs = sortLogs(roleLogs);

  for (const roleLog of sortedRoleLogs) {
    if (roleLog.removed) continue;
    if (roleLog.topics.length < 3) continue;

    const eventTopic = roleLog.topics[0]?.toLowerCase();
    const roleHash = roleLog.topics[1].toLowerCase();
    const account = parseAddressFromTopic(roleLog.topics[2]);

    if (!roleNamesByHash[roleHash]) {
      unknownRoleHashes.add(roleHash);
      skippedUnknownRoleEvents += 1;
      continue;
    }

    const roleHolders = getRoleSet(roleHoldersByRole, roleHash);
    if (eventTopic === ROLE_GRANTED_TOPIC.toLowerCase()) {
      roleHolders.add(account);
      processedRoleEvents += 1;
      continue;
    }
    if (eventTopic === ROLE_REVOKED_TOPIC.toLowerCase()) {
      roleHolders.delete(account);
      processedRoleEvents += 1;
    }
  }

  const summaryRows = buildSummaryRows(roleNamesByHash, roleHoldersByRole);

  console.log("");
  console.log(`Contract: ${contractAddress}`);
  console.log(`Chain ID: ${chainId}`);
  console.log("RPC URL source: cli argument");
  console.log(`Block range: ${fromBlock} -> ${resolvedToBlock}`);
  console.log(`Role events processed: ${processedRoleEvents}`);
  if (skippedUnknownRoleEvents > 0) {
    console.log(`Role events skipped (unknown role hash): ${skippedUnknownRoleEvents}`);
  }
  console.log("");
  console.log("Role holder summary");
  console.table(
    summaryRows.map((row) => ({
      Role: row.role,
      Holders: row.holderCount,
      "Role Hash": row.roleHash,
      "Holder Addresses": row.holders,
    }))
  );

  if (unknownRoleHashes.size > 0) {
    console.log("");
    console.log("Unknown role hashes seen (not in ROLE_NAMES):");
    for (const unknownRoleHash of Array.from(unknownRoleHashes).sort()) {
      console.log(`- ${unknownRoleHash}`);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
