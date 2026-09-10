import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

import { ethers } from 'ethers';

export type UpgradeTargetKind = 'transparent-proxy' | 'beacon';
export type UpgradeExecutorPath = 'timelock' | 'direct';
export type UpgradeAction = 'schedule' | 'execute' | 'direct';

export interface UpgradeTargetConfig {
	id: string;
	chainId: number;
	rpcUrl: string;
	targetKind: UpgradeTargetKind;
	executorPath: UpgradeExecutorPath;
	targetAddress: string;
	implementationContractName: string;
	artifactPath: string;
	proxyAdminAddress?: string;
	timelockAddress?: string;
	reinitializerCalldata?: string;
}

export interface FoundryBroadcastReceipt {
	transactions: FoundryBroadcastTransaction[];
}

export interface FoundryBroadcastTransaction {
	transactionType?: string;
	contractName?: string | null;
	contractAddress?: string | null;
	hash?: string;
	transaction?: {
		chainId?: string;
		input?: string;
	};
}

export interface ImplementationDeployment {
	contractName: string;
	contractAddress: string;
	transactionHash?: string;
}

export interface ChainReader {
	getCode(address: string): Promise<string>;
	getStorageAt(address: string, position: string): Promise<string>;
	call(address: string, data: string): Promise<string>;
}

export interface SafeBatchFile {
	version: string;
	chainId: string;
	createdAt: number;
	meta: SafeBatchMetadata;
	transactions: SafeTransaction[];
}

export interface SafeBatchMetadata {
	name: string;
	description: string;
	txBuilderVersion: string;
	createdFromSafeAddress: string;
	createdFromOwnerAddress: string;
	checksum?: string;
}

export interface SafeTransaction {
	to: string;
	value: string;
	data: null;
	contractMethod: SafeContractMethod;
	contractInputsValues: Record<string, string> | null;
}

export interface SafeContractMethod {
	inputs: SafeContractMethodInput[];
	name: string;
	payable: boolean;
}

export interface SafeContractMethodInput {
	internalType: string;
	name: string;
	type: string;
}

export interface VerificationResult {
	action: UpgradeAction;
	chainId: number;
	currentImplementation: string;
	deployedRuntimeBytecodeMatchesArtifact: boolean;
	executorAddress: string;
	executorOwner: string;
	newImplementation: string;
	receiptPath: string;
	safeAddress: string;
	targetAddress: string;
	timelockDelaySeconds?: string;
}

export interface PreparedUpgradeTransaction {
	directTargetAddress: string;
	directTargetData: string;
	implementationAddress: string;
	safeTransaction: SafeTransaction;
	verification: VerificationResult;
}

interface ContractMethodDefinition {
	fragment: {
		inputs: SafeContractMethodInput[];
		name: string;
		stateMutability: 'view' | 'nonpayable' | 'payable';
		type: 'function';
	};
	iface: ethers.utils.Interface;
}

const SAFE_BATCH_VERSION = '1.0';
const SAFE_TX_BUILDER_VERSION = '1.17.1';
const ZERO_BYTES = '0x';
export const ZERO_BYTES32 = `0x${'00'.repeat(32)}`;
export const EIP1967_IMPLEMENTATION_SLOT =
	'0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';

const PROXY_ADMIN_UPGRADE_AND_CALL = createContractMethodDefinition({
	type: 'function',
	name: 'upgradeAndCall',
	stateMutability: 'payable',
	inputs: [
		{
			internalType: 'contract ITransparentUpgradeableProxy',
			name: 'proxy',
			type: 'address',
		},
		{
			internalType: 'address',
			name: 'implementation',
			type: 'address',
		},
		{
			internalType: 'bytes',
			name: 'data',
			type: 'bytes',
		},
	],
});

const UPGRADEABLE_BEACON_UPGRADE_TO = createContractMethodDefinition({
	type: 'function',
	name: 'upgradeTo',
	stateMutability: 'nonpayable',
	inputs: [
		{
			internalType: 'address',
			name: 'newImplementation',
			type: 'address',
		},
	],
});

const TIMELOCK_SCHEDULE = createContractMethodDefinition({
	type: 'function',
	name: 'schedule',
	stateMutability: 'nonpayable',
	inputs: [
		{
			internalType: 'address',
			name: 'target',
			type: 'address',
		},
		{
			internalType: 'uint256',
			name: 'value',
			type: 'uint256',
		},
		{
			internalType: 'bytes',
			name: 'data',
			type: 'bytes',
		},
		{
			internalType: 'bytes32',
			name: 'predecessor',
			type: 'bytes32',
		},
		{
			internalType: 'bytes32',
			name: 'salt',
			type: 'bytes32',
		},
		{
			internalType: 'uint256',
			name: 'delay',
			type: 'uint256',
		},
	],
});

const TIMELOCK_EXECUTE = createContractMethodDefinition({
	type: 'function',
	name: 'execute',
	stateMutability: 'payable',
	inputs: [
		{
			internalType: 'address',
			name: 'target',
			type: 'address',
		},
		{
			internalType: 'uint256',
			name: 'value',
			type: 'uint256',
		},
		{
			internalType: 'bytes',
			name: 'data',
			type: 'bytes',
		},
		{
			internalType: 'bytes32',
			name: 'predecessor',
			type: 'bytes32',
		},
		{
			internalType: 'bytes32',
			name: 'salt',
			type: 'bytes32',
		},
	],
});

const OWNABLE_OWNER = new ethers.utils.Interface([
	'function owner() external view returns (address)',
]);
const BEACON_IMPLEMENTATION = new ethers.utils.Interface([
	'function implementation() external view returns (address)',
]);
const TIMELOCK_GET_MIN_DELAY = new ethers.utils.Interface([
	'function getMinDelay() external view returns (uint256)',
]);

export const createChainReader = (rpcUrl: string): ChainReader => {
	const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

	return {
		call: (address: string, data: string) =>
			provider.call({
				data,
				to: normalizeAddress(address),
			}),
		getCode: (address: string) => provider.getCode(normalizeAddress(address)),
		getStorageAt: (address: string, position: string) =>
			provider.getStorageAt(normalizeAddress(address), position),
	};
};

export const loadFoundryReceipt = (receiptPath: string): FoundryBroadcastReceipt => {
	const parsed = JSON.parse(readFileSync(receiptPath, 'utf8')) as Partial<FoundryBroadcastReceipt>;

	if (!parsed || !Array.isArray(parsed.transactions)) {
		throw new Error(`Receipt at ${receiptPath} is not a Foundry broadcast receipt.`);
	}

	return {
		transactions: parsed.transactions,
	};
};

export const resolveImplementationDeployment = (
	receipt: FoundryBroadcastReceipt,
	implementationContractName: string
): ImplementationDeployment => {
	const matches = receipt.transactions.filter(
		(transaction) =>
			transaction.transactionType === 'CREATE' &&
			transaction.contractName === implementationContractName &&
			typeof transaction.contractAddress === 'string'
	);

	if (matches.length === 0) {
		throw new Error(
			`Receipt does not contain a CREATE transaction for ${implementationContractName}.`
		);
	}

	if (matches.length > 1) {
		throw new Error(
			`Receipt contains multiple CREATE transactions for ${implementationContractName}.`
		);
	}

	const [match] = matches;

	return {
		contractAddress: normalizeAddress(match.contractAddress ?? ''),
		contractName: implementationContractName,
		transactionHash: match.hash,
	};
};

export const loadArtifactRuntimeBytecode = (artifactPath: string): string => {
	const parsed = JSON.parse(readFileSync(artifactPath, 'utf8')) as {
		deployedBytecode?: { object?: string } | string;
	};
	const deployedBytecode =
		typeof parsed.deployedBytecode === 'string'
			? parsed.deployedBytecode
			: parsed.deployedBytecode?.object;

	if (!deployedBytecode || deployedBytecode === ZERO_BYTES) {
		throw new Error(`Artifact at ${artifactPath} does not contain deployed runtime bytecode.`);
	}

	return normalizeHex(deployedBytecode);
};

export const assertActionAllowed = (config: UpgradeTargetConfig, action: UpgradeAction): void => {
	if (config.executorPath === 'timelock' && action === 'direct') {
		throw new Error(`Upgrade ${config.id} is timelock-controlled and cannot use --action direct.`);
	}

	if (config.executorPath === 'direct' && action !== 'direct') {
		throw new Error(
			`Upgrade ${config.id} is direct-execution only and cannot use --action ${action}.`
		);
	}
};

export const verifyUpgradeState = async ({
	action,
	chainReader,
	config,
	localRuntimeBytecode,
	newImplementation,
	receiptPath,
	safeAddress,
}: {
	action: UpgradeAction;
	chainReader: ChainReader;
	config: UpgradeTargetConfig;
	localRuntimeBytecode: string;
	newImplementation: string;
	receiptPath: string;
	safeAddress: string;
}): Promise<VerificationResult> => {
	assertActionAllowed(config, action);

	const normalizedSafeAddress = normalizeAddress(safeAddress);
	const normalizedImplementation = normalizeAddress(newImplementation);
	const onchainImplementationCode = normalizeHex(
		await chainReader.getCode(normalizedImplementation)
	);

	if (onchainImplementationCode === ZERO_BYTES) {
		throw new Error(`No deployed runtime bytecode found at ${normalizedImplementation}.`);
	}

	if (onchainImplementationCode !== normalizeHex(localRuntimeBytecode)) {
		throw new Error(
			`On-chain runtime bytecode at ${normalizedImplementation} does not match the local artifact for ${config.implementationContractName}.`
		);
	}

	const currentImplementation =
		config.targetKind === 'transparent-proxy'
			? await readTransparentProxyImplementation(chainReader, config.targetAddress)
			: await readBeaconImplementation(chainReader, config.targetAddress);

	if (currentImplementation === normalizedImplementation) {
		throw new Error(
			`${config.id} already points at ${normalizedImplementation}; refusing to export a no-op upgrade.`
		);
	}

	const executorAddress =
		config.targetKind === 'transparent-proxy'
			? normalizeAddress(config.proxyAdminAddress ?? '')
			: normalizeAddress(config.targetAddress);
	const executorOwner = await readOwnableOwner(chainReader, executorAddress);
	const expectedOwner =
		config.executorPath === 'timelock'
			? normalizeAddress(config.timelockAddress ?? '')
			: normalizedSafeAddress;

	if (executorOwner !== expectedOwner) {
		throw new Error(
			`Executor owner mismatch for ${config.id}: expected ${expectedOwner}, got ${executorOwner}.`
		);
	}

	const verification: VerificationResult = {
		action,
		chainId: config.chainId,
		currentImplementation,
		deployedRuntimeBytecodeMatchesArtifact: true,
		executorAddress,
		executorOwner,
		newImplementation: normalizedImplementation,
		receiptPath,
		safeAddress: normalizedSafeAddress,
		targetAddress: normalizeAddress(config.targetAddress),
	};

	if (action === 'schedule') {
		verification.timelockDelaySeconds = (
			await readTimelockMinDelay(chainReader, config.timelockAddress ?? '')
		).toString();
	}

	return verification;
};

export const buildPreparedUpgradeTransaction = async ({
	action,
	chainReader,
	config,
	newImplementation,
	predecessor,
	receiptPath,
	safeAddress,
	salt,
	localRuntimeBytecode,
}: {
	action: UpgradeAction;
	chainReader: ChainReader;
	config: UpgradeTargetConfig;
	localRuntimeBytecode: string;
	newImplementation: string;
	predecessor: string;
	receiptPath: string;
	safeAddress: string;
	salt: string;
}): Promise<PreparedUpgradeTransaction> => {
	const verification = await verifyUpgradeState({
		action,
		chainReader,
		config,
		localRuntimeBytecode,
		newImplementation,
		receiptPath,
		safeAddress,
	});

	const directTransaction = buildDirectUpgradeTransaction(config, verification.newImplementation);

	if (action === 'direct') {
		return {
			directTargetAddress: directTransaction.to,
			directTargetData: encodeContractMethod(
				directTransaction.contractMethod,
				directTransaction.contractInputsValues
			),
			implementationAddress: verification.newImplementation,
			safeTransaction: directTransaction,
			verification,
		};
	}

	const timelockDelay = verification.timelockDelaySeconds ?? ZERO_BYTES32;

	return {
		directTargetAddress: directTransaction.to,
		directTargetData: encodeContractMethod(
			directTransaction.contractMethod,
			directTransaction.contractInputsValues
		),
		implementationAddress: verification.newImplementation,
		safeTransaction: buildTimelockTransaction({
			action,
			config,
			delay: timelockDelay,
			predecessor,
			salt,
			targetData: encodeContractMethod(
				directTransaction.contractMethod,
				directTransaction.contractInputsValues
			),
			targetAddress: directTransaction.to,
		}),
		verification,
	};
};

export const buildSafeBatchFile = ({
	chainId,
	createdAt = Date.now(),
	safeAddress,
	transaction,
}: {
	chainId: number;
	createdAt?: number;
	safeAddress: string;
	transaction: SafeTransaction;
}): SafeBatchFile => {
	const draft: SafeBatchFile = {
		chainId: String(chainId),
		createdAt,
		meta: {
			createdFromOwnerAddress: '',
			createdFromSafeAddress: normalizeAddress(safeAddress),
			description: '',
			name: 'Transactions Batch',
			txBuilderVersion: SAFE_TX_BUILDER_VERSION,
		},
		transactions: [transaction],
		version: SAFE_BATCH_VERSION,
	};

	return {
		...draft,
		meta: {
			...draft.meta,
			checksum: calculateSafeChecksum(draft),
		},
	};
};

export const calculateSafeChecksum = (batchFile: SafeBatchFile): string => {
	const { checksum: _checksum, ...metaWithoutChecksum } = batchFile.meta;
	const serialized = serializeJSONObject({
		...batchFile,
		meta: {
			...metaWithoutChecksum,
			name: null,
		},
	});

	return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(serialized));
};

export const resolveOutputPath = (
	cwd: string,
	outPath: string | undefined,
	chainId: number,
	upgradeId: string,
	action: UpgradeAction
): string => {
	if (outPath) {
		return path.resolve(cwd, outPath);
	}

	return path.resolve(cwd, 'script/upgrades/out', `${chainId}-${upgradeId}-${action}.json`);
};

export const writeSafeBatchFile = (outPath: string, batchFile: SafeBatchFile): void => {
	mkdirSync(path.dirname(outPath), { recursive: true });
	writeFileSync(outPath, `${JSON.stringify(batchFile, null, '\t')}\n`, 'utf8');
};

const buildDirectUpgradeTransaction = (
	config: UpgradeTargetConfig,
	newImplementation: string
): SafeTransaction => {
	if (config.targetKind === 'transparent-proxy') {
		return {
			contractInputsValues: {
				data: normalizeHex(config.reinitializerCalldata ?? ZERO_BYTES),
				implementation: normalizeAddress(newImplementation),
				proxy: normalizeAddress(config.targetAddress),
			},
			contractMethod: toSafeContractMethod(PROXY_ADMIN_UPGRADE_AND_CALL.fragment),
			data: null,
			to: normalizeAddress(config.proxyAdminAddress ?? ''),
			value: '0',
		};
	}

	return {
		contractInputsValues: {
			newImplementation: normalizeAddress(newImplementation),
		},
		contractMethod: toSafeContractMethod(UPGRADEABLE_BEACON_UPGRADE_TO.fragment),
		data: null,
		to: normalizeAddress(config.targetAddress),
		value: '0',
	};
};

const buildTimelockTransaction = ({
	action,
	config,
	delay,
	predecessor,
	salt,
	targetAddress,
	targetData,
}: {
	action: Exclude<UpgradeAction, 'direct'>;
	config: UpgradeTargetConfig;
	delay: string;
	predecessor: string;
	salt: string;
	targetAddress: string;
	targetData: string;
}): SafeTransaction => {
	const contractMethod = action === 'schedule' ? TIMELOCK_SCHEDULE : TIMELOCK_EXECUTE;
	const contractInputsValues =
		action === 'schedule'
			? {
					data: normalizeHex(targetData),
					delay: ethers.BigNumber.from(delay).toString(),
					predecessor: normalizeHex(predecessor),
					salt: normalizeHex(salt),
					target: normalizeAddress(targetAddress),
					value: '0',
				}
			: {
					data: normalizeHex(targetData),
					predecessor: normalizeHex(predecessor),
					salt: normalizeHex(salt),
					target: normalizeAddress(targetAddress),
					value: '0',
				};

	return {
		contractInputsValues,
		contractMethod: toSafeContractMethod(contractMethod.fragment),
		data: null,
		to: normalizeAddress(config.timelockAddress ?? ''),
		value: '0',
	};
};

const encodeContractMethod = (
	contractMethod: SafeContractMethod,
	contractInputsValues: Record<string, string> | null
): string => {
	const definition = toContractMethodDefinition(contractMethod);
	const args = definition.fragment.inputs.map((input) => {
		if (!contractInputsValues) {
			return null;
		}

		return contractInputsValues[input.name];
	});

	return normalizeHex(definition.iface.encodeFunctionData(definition.fragment.name, args));
};

const readOwnableOwner = async (chainReader: ChainReader, address: string): Promise<string> => {
	const result = await chainReader.call(
		normalizeAddress(address),
		OWNABLE_OWNER.encodeFunctionData('owner')
	);
	const [owner] = OWNABLE_OWNER.decodeFunctionResult('owner', result);

	return normalizeAddress(owner);
};

const readTransparentProxyImplementation = async (
	chainReader: ChainReader,
	proxyAddress: string
): Promise<string> => {
	const storage = await chainReader.getStorageAt(
		normalizeAddress(proxyAddress),
		EIP1967_IMPLEMENTATION_SLOT
	);

	return normalizeAddress(`0x${storage.slice(-40)}`);
};

const readBeaconImplementation = async (
	chainReader: ChainReader,
	beaconAddress: string
): Promise<string> => {
	const result = await chainReader.call(
		normalizeAddress(beaconAddress),
		BEACON_IMPLEMENTATION.encodeFunctionData('implementation')
	);
	const [implementation] = BEACON_IMPLEMENTATION.decodeFunctionResult('implementation', result);

	return normalizeAddress(implementation);
};

const readTimelockMinDelay = async (
	chainReader: ChainReader,
	timelockAddress: string
): Promise<ethers.BigNumber> => {
	const result = await chainReader.call(
		normalizeAddress(timelockAddress),
		TIMELOCK_GET_MIN_DELAY.encodeFunctionData('getMinDelay')
	);
	const [delay] = TIMELOCK_GET_MIN_DELAY.decodeFunctionResult('getMinDelay', result);

	return ethers.BigNumber.from(delay);
};

const serializeJSONObject = (value: unknown): string => {
	if (Array.isArray(value)) {
		return `[${value.map((item) => serializeJSONObject(item)).join(',')}]`;
	}

	if (typeof value === 'object' && value !== null) {
		let serialized = '';
		const keys = Object.keys(value).sort();

		serialized += `{${JSON.stringify(keys, stringifyReplacer)}`;

		for (const key of keys) {
			serialized += `${serializeJSONObject((value as Record<string, unknown>)[key])},`;
		}

		return `${serialized}}`;
	}

	return `${JSON.stringify(value, stringifyReplacer)}`;
};

const stringifyReplacer = (_key: string, value: unknown): unknown =>
	value === undefined ? null : value;

function createContractMethodDefinition(
	fragment: ContractMethodDefinition['fragment']
): ContractMethodDefinition {
	return {
		fragment,
		iface: new ethers.utils.Interface([fragment]),
	};
}

function toSafeContractMethod(fragment: ContractMethodDefinition['fragment']): SafeContractMethod {
	return {
		inputs: fragment.inputs,
		name: fragment.name,
		payable: fragment.stateMutability === 'payable',
	};
}

function toContractMethodDefinition(contractMethod: SafeContractMethod): ContractMethodDefinition {
	return createContractMethodDefinition({
		inputs: contractMethod.inputs,
		name: contractMethod.name,
		stateMutability: contractMethod.payable ? 'payable' : 'nonpayable',
		type: 'function',
	});
}

export const normalizeAddress = (address: string): string => ethers.utils.getAddress(address);

export const normalizeHex = (value: string): string => {
	if (!value.startsWith('0x')) {
		throw new Error(`Expected a hex string, received ${value}.`);
	}

	return value.toLowerCase();
};
