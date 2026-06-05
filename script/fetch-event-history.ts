/**
 * -----------------------------------------------------------------------------
 * EVENT HISTORY FETCHER
 * -----------------------------------------------------------------------------
 *
 * Example (Intuition mainnet, SharePriceChanged, filtered by termId + curveId):
 *
 * bun run fetch:event:history -- \
 *   --contract 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e \
 *   --rpc-url https://rpc.intuition.systems/http \
 *   --chain-id 1155 \
 *   --event "SharePriceChanged(bytes32 indexed termId,uint256 indexed curveId,uint256 sharePrice,uint256 totalAssets,uint256 totalShares,uint8 vaultType)" \
 *   --from 0 \
 *   --to latest \
 *   --filter "termId=0x53fc9bb27b5c56794482aca43cc4ad58d66d65e6e93f256c896300f5e645d5da,curveId=1" \
 *   --out script/output/share-price-changed.term-53fc.curve-1.json
 *
 * Query filter also supports JSON:
 * --filter '{"termId":"0x53fc9bb27b5c56794482aca43cc4ad58d66d65e6e93f256c896300f5e645d5da","curveId":"1"}'
 *
 * -----------------------------------------------------------------------------
 */

import { mkdir, writeFile } from 'node:fs/promises';
import * as path from 'node:path';
import { ethers } from 'ethers';

const DEFAULT_BLOCK_RANGE_CHUNK_SIZE = 200_000;

type ParsedCliArgs = {
	chainId: number;
	chunkSize: number;
	contractAddress: string;
	eventInput: string;
	filter: Record<string, string>;
	fromBlock: number;
	outPath?: string;
	rpcUrl: string;
	toBlock: number | 'latest';
};

type EventLogRecord = {
	args: Record<string, unknown>;
	blockHash: string;
	blockNumber: number;
	data: string;
	logIndex: number;
	topics: string[];
	transactionHash: string;
	transactionIndex: number;
};

type EventHistoryOutput = {
	config: {
		chainId: number;
		contractAddress: string;
		eventFragment: string;
		eventSignature: string;
		eventTopic: string;
		filter: Record<string, string>;
		fromBlock: number;
		queryTopics: Array<string | null>;
		resolvedToBlock: number;
		rpcUrl: string;
	};
	generatedAt: string;
	logCount: number;
	logs: EventLogRecord[];
};

function printUsage(): void {
	console.log(`
Usage:
  bun run fetch:event:history -- \\
    --contract <ADDRESS> \\
    --rpc-url <RPC_URL> \\
    --chain-id <CHAIN_ID> \\
    --event "<EVENT_SIGNATURE_OR_FRAGMENT>" \\
    --from <FROM_BLOCK> \\
    --to <TO_BLOCK|latest> \\
    [--filter "<indexedKey=value,indexedKey2=value2>"] \\
    [--out <OUTPUT_JSON_PATH>] \\
    [--chunk-size <BLOCK_RANGE_SIZE>]

Required arguments:
  --contract   Contract address to query.
  --rpc-url    JSON-RPC endpoint.
  --chain-id   Expected chain ID (validated against RPC).
  --event      Event signature/fragment. Example:
               "SharePriceChanged(bytes32 indexed termId,uint256 indexed curveId,uint256 sharePrice,uint256 totalAssets,uint256 totalShares,uint8 vaultType)"
  --from       Start block number (inclusive).
  --to         End block number (inclusive) or "latest".

Optional arguments:
  --filter     Indexed event field filters as either:
               - "termId=0x...,curveId=1"
               - '{"termId":"0x...","curveId":"1"}'
               Supported keys: indexed parameter names or 0-based indexed positions.
  --out        JSON output path. Defaults to script/output/<generated-name>.json
  --chunk-size eth_getLogs block chunk size (default: ${DEFAULT_BLOCK_RANGE_CHUNK_SIZE}).
`);
}

function parsePositiveInteger(value: string, flagName: string): number {
	const parsed = Number(value);
	if (!Number.isInteger(parsed) || parsed < 0) {
		throw new Error(`Invalid ${flagName}: ${value}`);
	}
	return parsed;
}

function parseCliArgs(argv: string[]): ParsedCliArgs {
	const argMap = new Map<string, string>();

	for (let index = 0; index < argv.length; index++) {
		const token = argv[index];

		if (token === '--help' || token === '-h') {
			printUsage();
			process.exit(0);
		}

		if (!token.startsWith('--')) {
			throw new Error(`Unexpected positional argument: ${token}`);
		}

		const withoutPrefix = token.slice(2);
		const equalsIndex = withoutPrefix.indexOf('=');

		let flagName = withoutPrefix;
		let flagValue: string | undefined;

		if (equalsIndex >= 0) {
			flagName = withoutPrefix.slice(0, equalsIndex);
			flagValue = withoutPrefix.slice(equalsIndex + 1);
		} else {
			const nextToken = argv[index + 1];
			if (!nextToken || nextToken.startsWith('--')) {
				throw new Error(`Missing value for --${flagName}`);
			}
			flagValue = nextToken;
			index += 1;
		}

		argMap.set(flagName, flagValue);
	}

	const required = (name: string): string => {
		const value = argMap.get(name);
		if (!value) {
			throw new Error(`Missing required argument --${name}`);
		}
		return value;
	};

	const contractAddressRaw = required('contract');
	if (!ethers.utils.isAddress(contractAddressRaw)) {
		throw new Error(`Invalid contract address: ${contractAddressRaw}`);
	}

	const chainId = parsePositiveInteger(required('chain-id'), 'chain-id');
	if (chainId <= 0) {
		throw new Error(`Invalid chain-id: ${chainId}`);
	}

	const fromBlock = parsePositiveInteger(required('from'), 'from');
	const toBlockRaw = required('to');
	const toBlock =
		toBlockRaw.toLowerCase() === 'latest' ? 'latest' : parsePositiveInteger(toBlockRaw, 'to');

	if (toBlock !== 'latest' && toBlock < fromBlock) {
		throw new Error(`Invalid range: --to (${toBlock}) must be >= --from (${fromBlock})`);
	}

	const filter = parseFilterArgument(argMap.get('filter'));
	const chunkSizeRaw = argMap.get('chunk-size');
	const chunkSize = chunkSizeRaw
		? parsePositiveInteger(chunkSizeRaw, 'chunk-size')
		: DEFAULT_BLOCK_RANGE_CHUNK_SIZE;

	if (chunkSize <= 0) {
		throw new Error(`Invalid chunk-size: ${chunkSize}`);
	}

	return {
		chainId,
		chunkSize,
		contractAddress: ethers.utils.getAddress(contractAddressRaw),
		eventInput: required('event'),
		filter,
		fromBlock,
		outPath: argMap.get('out'),
		rpcUrl: required('rpc-url'),
		toBlock,
	};
}

function parseFilterArgument(filterRaw?: string): Record<string, string> {
	if (!filterRaw || filterRaw.trim().length === 0) {
		return {};
	}

	const trimmedFilter = filterRaw.trim();

	if (trimmedFilter.startsWith('{')) {
		const parsed = JSON.parse(trimmedFilter) as Record<string, unknown>;
		if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object') {
			throw new Error('Invalid --filter JSON. Expected an object.');
		}

		return Object.fromEntries(Object.entries(parsed).map(([key, value]) => [key, String(value)]));
	}

	const filterEntries = trimmedFilter.split(',').map((entry) => entry.trim());
	const filter: Record<string, string> = {};

	for (const entry of filterEntries) {
		if (!entry) continue;
		const equalsIndex = entry.indexOf('=');
		if (equalsIndex <= 0 || equalsIndex === entry.length - 1) {
			throw new Error(`Invalid --filter entry: "${entry}". Expected key=value.`);
		}

		const key = entry.slice(0, equalsIndex).trim();
		const value = entry.slice(equalsIndex + 1).trim();
		filter[key] = value;
	}

	return filter;
}

function normalizeEventDeclaration(eventInput: string): string {
	const trimmedInput = eventInput.trim().replace(/;+$/, '').trim();
	return trimmedInput.startsWith('event ') ? trimmedInput : `event ${trimmedInput}`;
}

function isDynamicIndexedType(typeName: string): boolean {
	if (typeName === 'bytes' || typeName === 'string') return true;
	if (typeName.includes('[')) return true;
	if (typeName.startsWith('tuple')) return true;
	return false;
}

function coerceIndexedValue(typeName: string, rawValue: string): unknown {
	if (typeName === 'address') {
		return ethers.utils.getAddress(rawValue);
	}

	if (typeName === 'bool') {
		const normalizedValue = rawValue.toLowerCase();
		if (normalizedValue === 'true' || normalizedValue === '1') return true;
		if (normalizedValue === 'false' || normalizedValue === '0') return false;
		throw new Error(`Invalid boolean value "${rawValue}"`);
	}

	if (/^u?int(\d+)?$/.test(typeName)) {
		return ethers.BigNumber.from(rawValue);
	}

	if (/^bytes(\d+)$/.test(typeName)) {
		if (!ethers.utils.isHexString(rawValue)) {
			throw new Error(`Expected hex string for ${typeName}, got "${rawValue}"`);
		}
		const expectedLength = Number(typeName.replace('bytes', ''));
		const actualLength = ethers.utils.hexDataLength(rawValue);
		if (actualLength !== expectedLength) {
			throw new Error(
				`Invalid ${typeName} value length. Expected ${expectedLength} bytes, got ${actualLength}`
			);
		}
		return rawValue;
	}

	if (typeName === 'bytes' || typeName === 'string') {
		return rawValue;
	}

	if (ethers.utils.isHexString(rawValue)) {
		return rawValue;
	}

	return rawValue;
}

function encodeIndexedTopic(typeName: string, rawValue: string): string {
	if (isDynamicIndexedType(typeName)) {
		throw new Error(
			`Filtering dynamic indexed type "${typeName}" is not supported by this script.`
		);
	}

	const coercedValue = coerceIndexedValue(typeName, rawValue);
	return ethers.utils.defaultAbiCoder.encode([typeName], [coercedValue]).toLowerCase();
}

function buildQueryTopics(
	eventTopic: string,
	indexedInputs: ethers.utils.ParamType[],
	filter: Record<string, string>
): Array<string | null> {
	const topics: Array<string | null> = [eventTopic.toLowerCase()];
	const validKeys = new Set<string>();

	for (let index = 0; index < indexedInputs.length; index++) {
		const indexedInput = indexedInputs[index];
		if (indexedInput.name) {
			validKeys.add(indexedInput.name);
		}
		validKeys.add(String(index));
	}

	for (const filterKey of Object.keys(filter)) {
		if (!validKeys.has(filterKey)) {
			throw new Error(
				`Unknown --filter key "${filterKey}". Valid keys: ${Array.from(validKeys).join(', ')}`
			);
		}
	}

	for (let index = 0; index < indexedInputs.length; index++) {
		const indexedInput = indexedInputs[index];
		const rawFilterValue =
			(indexedInput.name ? filter[indexedInput.name] : undefined) ?? filter[String(index)];
		if (rawFilterValue === undefined) {
			topics.push(null);
			continue;
		}

		topics.push(encodeIndexedTopic(indexedInput.type, rawFilterValue));
	}

	return topics;
}

function parseProviderSuggestedRangeLimit(error: unknown): number | null {
	const normalizedError = error as { body?: string; message?: string };
	const messageBody = [normalizedError.body, normalizedError.message].filter(Boolean).join(' ');

	const blockRangeMatch = messageBody.match(/up to a\s+(\d+)\s+block range/i);
	if (blockRangeMatch) {
		return Number.parseInt(blockRangeMatch[1], 10);
	}

	const suggestionMatch = messageBody.match(
		/block range should work:\s*\[(0x[0-9a-f]+),\s*(0x[0-9a-f]+)\]/i
	);
	if (!suggestionMatch) {
		return null;
	}

	const fromBlock = Number.parseInt(suggestionMatch[1], 16);
	const toBlock = Number.parseInt(suggestionMatch[2], 16);
	if (!Number.isFinite(fromBlock) || !Number.isFinite(toBlock) || toBlock < fromBlock) {
		return null;
	}

	return toBlock - fromBlock + 1;
}

async function fetchLogsChunked(
	provider: ethers.providers.JsonRpcProvider,
	topics: Array<string | null>,
	contractAddress: string,
	fromBlock: number,
	toBlock: number,
	initialChunkSize: number
): Promise<ethers.providers.Log[]> {
	const collectedLogs: ethers.providers.Log[] = [];
	let rangeChunkSize = initialChunkSize;
	let rangeStartBlock = fromBlock;

	while (rangeStartBlock <= toBlock) {
		const rangeEndBlock = Math.min(rangeStartBlock + rangeChunkSize - 1, toBlock);

		try {
			const logs = await provider.getLogs({
				address: contractAddress,
				fromBlock: rangeStartBlock,
				toBlock: rangeEndBlock,
				topics,
			});
			collectedLogs.push(...logs);
			rangeStartBlock = rangeEndBlock + 1;
		} catch (error) {
			const suggestedRangeLimit = parseProviderSuggestedRangeLimit(error);
			if (!suggestedRangeLimit) {
				throw error;
			}

			rangeChunkSize = Math.min(rangeChunkSize, suggestedRangeLimit);
			if (rangeChunkSize < 1) {
				rangeChunkSize = 1;
			}

			console.log(
				`Reducing block chunk size to ${rangeChunkSize} due to provider log range limits.`
			);
		}
	}

	return collectedLogs;
}

function sortLogs(logs: ethers.providers.Log[]): ethers.providers.Log[] {
	return logs.sort((leftLog, rightLog) => {
		if (leftLog.blockNumber !== rightLog.blockNumber) {
			return leftLog.blockNumber - rightLog.blockNumber;
		}
		if (leftLog.transactionIndex !== rightLog.transactionIndex) {
			return leftLog.transactionIndex - rightLog.transactionIndex;
		}
		return leftLog.logIndex - rightLog.logIndex;
	});
}

function formatDecodedValue(value: unknown): unknown {
	if (ethers.BigNumber.isBigNumber(value)) {
		return value.toString();
	}
	if (Array.isArray(value)) {
		return value.map((nestedValue) => formatDecodedValue(nestedValue));
	}
	return value;
}

function shortHash(hash: string): string {
	if (hash.length < 12) return hash;
	return `${hash.slice(0, 8)}…${hash.slice(-6)}`;
}

function buildDefaultOutputPath(
	eventName: string,
	contractAddress: string,
	fromBlock: number,
	toBlock: number
): string {
	const safeEventName = eventName.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
	const fileName = `${safeEventName}-${contractAddress.toLowerCase()}-${fromBlock}-${toBlock}-${Date.now()}.json`;
	return path.resolve(process.cwd(), 'script', 'output', fileName);
}

async function main(): Promise<void> {
	const cliArgs = parseCliArgs(process.argv.slice(2));
	const provider = new ethers.providers.JsonRpcProvider(cliArgs.rpcUrl);
	const network = await provider.getNetwork();

	if (network.chainId !== cliArgs.chainId) {
		throw new Error(`RPC chain ID mismatch. Expected ${cliArgs.chainId}, got ${network.chainId}.`);
	}

	const resolvedToBlock =
		cliArgs.toBlock === 'latest' ? await provider.getBlockNumber() : cliArgs.toBlock;
	if (resolvedToBlock < cliArgs.fromBlock) {
		throw new Error(
			`Invalid block range: --from ${cliArgs.fromBlock} is greater than --to ${resolvedToBlock}`
		);
	}

	const eventDeclaration = normalizeEventDeclaration(cliArgs.eventInput);
	const eventInterface = new ethers.utils.Interface([eventDeclaration]);
	const eventFragments = Object.values(eventInterface.events);
	if (eventFragments.length !== 1) {
		throw new Error('Expected exactly one event fragment in --event.');
	}
	const eventFragment = eventFragments[0];
	const eventSignature = eventFragment.format(ethers.utils.FormatTypes.sighash);
	const eventTopic = eventInterface.getEventTopic(eventFragment);
	const indexedInputs = eventFragment.inputs.filter((input) => input.indexed);
	const queryTopics = buildQueryTopics(eventTopic, indexedInputs, cliArgs.filter);

	const eventLogs = await fetchLogsChunked(
		provider,
		queryTopics,
		cliArgs.contractAddress,
		cliArgs.fromBlock,
		resolvedToBlock,
		cliArgs.chunkSize
	);
	const sortedLogs = sortLogs(eventLogs);

	const decodedLogs: EventLogRecord[] = sortedLogs.map((log) => {
		const parsedLog = eventInterface.parseLog(log);
		const args: Record<string, unknown> = {};

		for (let index = 0; index < eventFragment.inputs.length; index++) {
			const input = eventFragment.inputs[index];
			const argName = input.name || `arg${index}`;
			args[argName] = formatDecodedValue(parsedLog.args[index]);
		}

		return {
			args,
			blockHash: log.blockHash,
			blockNumber: log.blockNumber,
			data: log.data,
			logIndex: log.logIndex,
			topics: log.topics,
			transactionHash: log.transactionHash,
			transactionIndex: log.transactionIndex,
		};
	});

	const outputPath =
		cliArgs.outPath && cliArgs.outPath.trim().length > 0
			? path.resolve(process.cwd(), cliArgs.outPath)
			: buildDefaultOutputPath(
					eventFragment.name,
					cliArgs.contractAddress,
					cliArgs.fromBlock,
					resolvedToBlock
				);
	await mkdir(path.dirname(outputPath), { recursive: true });

	const output: EventHistoryOutput = {
		config: {
			chainId: cliArgs.chainId,
			contractAddress: cliArgs.contractAddress,
			eventFragment: eventFragment.format(ethers.utils.FormatTypes.full),
			eventSignature,
			eventTopic: eventTopic.toLowerCase(),
			filter: cliArgs.filter,
			fromBlock: cliArgs.fromBlock,
			queryTopics,
			resolvedToBlock,
			rpcUrl: cliArgs.rpcUrl,
		},
		generatedAt: new Date().toISOString(),
		logCount: decodedLogs.length,
		logs: decodedLogs,
	};

	await writeFile(outputPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');

	console.log('');
	console.log('Event history fetch complete');
	console.log(`Event: ${eventSignature}`);
	console.log(`Contract: ${cliArgs.contractAddress}`);
	console.log(`Chain ID: ${cliArgs.chainId}`);
	console.log(`Block range: ${cliArgs.fromBlock} -> ${resolvedToBlock}`);
	console.log(`Indexed filters: ${JSON.stringify(cliArgs.filter)}`);
	console.log(`Logs fetched: ${decodedLogs.length}`);
	console.log(`Output JSON: ${outputPath}`);

	const previewRows = decodedLogs.slice(0, 5).map((log) => {
		const row: Record<string, string | number> = {
			blockNumber: log.blockNumber,
			logIndex: log.logIndex,
			transactionHash: shortHash(log.transactionHash),
		};

		for (const indexedInput of indexedInputs.slice(0, 3)) {
			const key = indexedInput.name || indexedInput.type;
			row[key] = String(log.args[key] ?? '-');
		}

		return row;
	});

	if (previewRows.length > 0) {
		console.log('');
		console.log('Preview (first up to 5 matching logs):');
		console.table(previewRows);
	}
}

main().catch((error: unknown) => {
	console.error(error);
	process.exit(1);
});
