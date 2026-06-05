import { execSync } from 'node:child_process';
import path from 'node:path';

import { ethers } from 'ethers';

import { getUpgradeTargetConfig } from './safe-upgrade-config';
import {
	buildPreparedUpgradeTransaction,
	buildSafeBatchFile,
	createChainReader,
	loadArtifactRuntimeBytecode,
	loadFoundryReceipt,
	normalizeAddress,
	resolveImplementationDeployment,
	resolveOutputPath,
	type UpgradeAction,
	writeSafeBatchFile,
	ZERO_BYTES32,
} from './safe-upgrade-lib';

interface CliOptions {
	action: UpgradeAction;
	out?: string;
	predecessor: string;
	receipt: string;
	rpcUrl?: string;
	safe: string;
	salt: string;
	upgradeId: string;
}

const EXPECTED_FOUNDRY_VERSION = '1.5.1';

const assertFoundryVersion = (): void => {
	const version = execSync('forge --version', { encoding: 'utf8' }).trim();
	if (!version.includes(EXPECTED_FOUNDRY_VERSION)) {
		throw new Error(
			`Foundry version mismatch. Expected ${EXPECTED_FOUNDRY_VERSION} but got: ${version}. ` +
				`Install with: foundryup -v ${EXPECTED_FOUNDRY_VERSION}`
		);
	}
};

const main = async (): Promise<void> => {
	assertFoundryVersion();
	const options = parseCliArgs(process.argv.slice(2));
	const config = getUpgradeTargetConfig(options.upgradeId);
	const receiptPath = path.resolve(process.cwd(), options.receipt);
	const receipt = loadFoundryReceipt(receiptPath);
	const deployment = resolveImplementationDeployment(receipt, config.implementationContractName);
	const localRuntimeBytecode = loadArtifactRuntimeBytecode(config.artifactPath);
	const chainReader = createChainReader(options.rpcUrl ?? config.rpcUrl);
	const preparedTransaction = await buildPreparedUpgradeTransaction({
		action: options.action,
		chainReader,
		config,
		localRuntimeBytecode,
		newImplementation: deployment.contractAddress,
		predecessor: options.predecessor,
		receiptPath,
		safeAddress: options.safe,
		salt: options.salt,
	});
	const batchFile = buildSafeBatchFile({
		chainId: config.chainId,
		safeAddress: options.safe,
		transaction: preparedTransaction.safeTransaction,
	});
	const outPath = resolveOutputPath(
		process.cwd(),
		options.out,
		config.chainId,
		config.id,
		options.action
	);

	writeSafeBatchFile(outPath, batchFile);

	console.log(
		JSON.stringify(
			{
				...preparedTransaction.verification,
				directTargetAddress: preparedTransaction.directTargetAddress,
				directTargetData: preparedTransaction.directTargetData,
				implementationDeploymentHash: deployment.transactionHash ?? null,
				outputPath: outPath,
				safeBatchChecksum: batchFile.meta.checksum,
				safeTransactionMethod: preparedTransaction.safeTransaction.contractMethod.name,
				safeTransactionTarget: preparedTransaction.safeTransaction.to,
			},
			null,
			2
		)
	);
};

const parseCliArgs = (argv: string[]): CliOptions => {
	const parsed: Record<string, string> = {};

	for (let index = 0; index < argv.length; index += 1) {
		const argument = argv[index];

		if (!argument.startsWith('--')) {
			throw new Error(`Unexpected positional argument: ${argument}`);
		}

		const key = argument.slice(2);

		if (key === 'help') {
			printHelp();
			process.exit(0);
		}

		const value = argv[index + 1];

		if (!value || value.startsWith('--')) {
			throw new Error(`Missing value for --${key}.`);
		}

		parsed[key] = value;
		index += 1;
	}

	const action = parseAction(requiredArg(parsed, 'action'));

	return {
		action,
		out: parsed.out,
		predecessor: normalizeBytes32(parsed.predecessor ?? ZERO_BYTES32),
		receipt: requiredArg(parsed, 'receipt'),
		rpcUrl: parsed['rpc-url'],
		safe: normalizeAddress(requiredArg(parsed, 'safe')),
		salt: normalizeBytes32(parsed.salt ?? ZERO_BYTES32),
		upgradeId: requiredArg(parsed, 'upgrade-id'),
	};
};

const requiredArg = (parsed: Record<string, string>, key: string): string => {
	const value = parsed[key];

	if (!value) {
		throw new Error(`Missing required argument --${key}.`);
	}

	return value;
};

const parseAction = (value: string): UpgradeAction => {
	if (value === 'direct' || value === 'execute' || value === 'schedule') {
		return value;
	}

	throw new Error(`Invalid --action ${value}. Expected one of: schedule, execute, direct.`);
};

const normalizeBytes32 = (value: string): string =>
	ethers.utils.hexZeroPad(value, 32).toLowerCase();

const printHelp = (): void => {
	console.log(`Usage:
bun script/upgrades/generate-safe-upgrade-transaction.ts \\
  --receipt <path> \\
  --upgrade-id <id> \\
  --action <schedule|execute|direct> \\
  --safe <address> \\
  [--rpc-url <url>] \\
  [--out <path>] \\
  [--predecessor <bytes32>] \\
  [--salt <bytes32>]

Known upgrade ids:
  ${Object.keys(getKnownUpgradeIds()).join('\n  ')}`);
};

const getKnownUpgradeIds = (): Record<string, true> => ({
	'base-base-emissions-controller': true,
	'intuition-atom-wallet-beacon': true,
	'intuition-offset-progressive-curve': true,
	'intuition-satellite-emissions-controller': true,
	'intuition-trust-bonding': true,
});

main().catch((error: unknown) => {
	const message = error instanceof Error ? error.message : String(error);
	console.error(message);
	process.exit(1);
});
