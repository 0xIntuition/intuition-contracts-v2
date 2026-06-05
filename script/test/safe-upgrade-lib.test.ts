import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';

import { ethers } from 'ethers';

import {
	buildPreparedUpgradeTransaction,
	buildSafeBatchFile,
	type ChainReader,
	calculateSafeChecksum,
	EIP1967_IMPLEMENTATION_SLOT,
	loadFoundryReceipt,
	resolveImplementationDeployment,
	type UpgradeTargetConfig,
	ZERO_BYTES32,
} from '../upgrades/safe-upgrade-lib';

const LOCAL_RUNTIME_BYTECODE = '0x6001600155';
const NEW_IMPLEMENTATION = '0x0000000000000000000000000000000000000AAA';
const CURRENT_IMPLEMENTATION = '0x0000000000000000000000000000000000000BBB';
const SAFE_ADDRESS = '0x0000000000000000000000000000000000000CCC';
const PROXY_ADDRESS = '0x0000000000000000000000000000000000000100';
const PROXY_ADMIN_ADDRESS = '0x0000000000000000000000000000000000000200';
const BEACON_ADDRESS = '0x0000000000000000000000000000000000000300';
const TIMELOCK_ADDRESS = '0x0000000000000000000000000000000000000400';

describe('receipt parsing', () => {
	it('resolves a matching CREATE receipt', () => {
		const receiptPath = withTempReceipt({
			transactions: [
				{
					contractAddress: NEW_IMPLEMENTATION,
					contractName: 'TrustBonding',
					hash: '0x1234',
					transactionType: 'CREATE',
				},
			],
		});

		const receipt = loadFoundryReceipt(receiptPath);
		const deployment = resolveImplementationDeployment(receipt, 'TrustBonding');

		assert.equal(deployment.contractAddress, ethers.utils.getAddress(NEW_IMPLEMENTATION));
		assert.equal(deployment.contractName, 'TrustBonding');
		assert.equal(deployment.transactionHash, '0x1234');
	});

	it('rejects missing CREATE receipts', () => {
		const receiptPath = withTempReceipt({
			transactions: [
				{
					contractAddress: NEW_IMPLEMENTATION,
					contractName: 'OffsetProgressiveCurve',
					transactionType: 'CREATE',
				},
			],
		});

		const receipt = loadFoundryReceipt(receiptPath);

		assert.throws(
			() => resolveImplementationDeployment(receipt, 'TrustBonding'),
			/does not contain a CREATE transaction for TrustBonding/
		);
	});

	it('rejects duplicate CREATE receipts', () => {
		const receiptPath = withTempReceipt({
			transactions: [
				{
					contractAddress: NEW_IMPLEMENTATION,
					contractName: 'TrustBonding',
					transactionType: 'CREATE',
				},
				{
					contractAddress: CURRENT_IMPLEMENTATION,
					contractName: 'TrustBonding',
					transactionType: 'CREATE',
				},
			],
		});

		const receipt = loadFoundryReceipt(receiptPath);

		assert.throws(
			() => resolveImplementationDeployment(receipt, 'TrustBonding'),
			/multiple CREATE transactions for TrustBonding/
		);
	});
});

describe('safe batch generation', () => {
	it('builds a direct transparent proxy upgrade transaction', async () => {
		const prepared = await buildPreparedUpgradeTransaction({
			action: 'direct',
			chainReader: createTransparentProxyChainReader({
				codeAtNewImplementation: LOCAL_RUNTIME_BYTECODE,
				currentImplementation: CURRENT_IMPLEMENTATION,
				executorOwner: SAFE_ADDRESS,
			}),
			config: {
				artifactPath: 'unused',
				chainId: 1,
				executorPath: 'direct',
				id: 'direct-transparent',
				implementationContractName: 'TrustBonding',
				proxyAdminAddress: PROXY_ADMIN_ADDRESS,
				reinitializerCalldata: '0x',
				rpcUrl: 'http://localhost',
				targetAddress: PROXY_ADDRESS,
				targetKind: 'transparent-proxy',
			},
			localRuntimeBytecode: LOCAL_RUNTIME_BYTECODE,
			newImplementation: NEW_IMPLEMENTATION,
			predecessor: ZERO_BYTES32,
			receiptPath: '/tmp/receipt.json',
			safeAddress: SAFE_ADDRESS,
			salt: ZERO_BYTES32,
		});

		assert.equal(prepared.safeTransaction.to, ethers.utils.getAddress(PROXY_ADMIN_ADDRESS));
		assert.equal(prepared.safeTransaction.contractMethod.name, 'upgradeAndCall');
		assert.deepEqual(prepared.safeTransaction.contractInputsValues, {
			data: '0x',
			implementation: ethers.utils.getAddress(NEW_IMPLEMENTATION),
			proxy: ethers.utils.getAddress(PROXY_ADDRESS),
		});
	});

	it('builds a direct beacon upgrade transaction', async () => {
		const prepared = await buildPreparedUpgradeTransaction({
			action: 'direct',
			chainReader: createBeaconChainReader({
				codeAtNewImplementation: LOCAL_RUNTIME_BYTECODE,
				currentImplementation: CURRENT_IMPLEMENTATION,
				executorOwner: SAFE_ADDRESS,
			}),
			config: {
				artifactPath: 'unused',
				chainId: 1,
				executorPath: 'direct',
				id: 'direct-beacon',
				implementationContractName: 'AtomWallet',
				rpcUrl: 'http://localhost',
				targetAddress: BEACON_ADDRESS,
				targetKind: 'beacon',
			},
			localRuntimeBytecode: LOCAL_RUNTIME_BYTECODE,
			newImplementation: NEW_IMPLEMENTATION,
			predecessor: ZERO_BYTES32,
			receiptPath: '/tmp/receipt.json',
			safeAddress: SAFE_ADDRESS,
			salt: ZERO_BYTES32,
		});

		assert.equal(prepared.safeTransaction.to, ethers.utils.getAddress(BEACON_ADDRESS));
		assert.equal(prepared.safeTransaction.contractMethod.name, 'upgradeTo');
		assert.deepEqual(prepared.safeTransaction.contractInputsValues, {
			newImplementation: ethers.utils.getAddress(NEW_IMPLEMENTATION),
		});
	});

	it('wraps a direct upgrade in a timelock schedule transaction', async () => {
		const prepared = await buildPreparedUpgradeTransaction({
			action: 'schedule',
			chainReader: createTransparentProxyChainReader({
				codeAtNewImplementation: LOCAL_RUNTIME_BYTECODE,
				currentImplementation: CURRENT_IMPLEMENTATION,
				executorOwner: TIMELOCK_ADDRESS,
				timelockDelay: 172_800,
			}),
			config: {
				artifactPath: 'unused',
				chainId: 1155,
				executorPath: 'timelock',
				id: 'timelock-transparent',
				implementationContractName: 'TrustBonding',
				proxyAdminAddress: PROXY_ADMIN_ADDRESS,
				reinitializerCalldata: '0x',
				rpcUrl: 'http://localhost',
				targetAddress: PROXY_ADDRESS,
				targetKind: 'transparent-proxy',
				timelockAddress: TIMELOCK_ADDRESS,
			},
			localRuntimeBytecode: LOCAL_RUNTIME_BYTECODE,
			newImplementation: NEW_IMPLEMENTATION,
			predecessor: ZERO_BYTES32,
			receiptPath: '/tmp/receipt.json',
			safeAddress: SAFE_ADDRESS,
			salt: ZERO_BYTES32,
		});

		assert.equal(prepared.safeTransaction.to, ethers.utils.getAddress(TIMELOCK_ADDRESS));
		assert.equal(prepared.safeTransaction.contractMethod.name, 'schedule');
		assert.equal(
			prepared.safeTransaction.contractInputsValues?.target,
			ethers.utils.getAddress(PROXY_ADMIN_ADDRESS)
		);
		assert.equal(prepared.safeTransaction.contractInputsValues?.data, prepared.directTargetData);
		assert.equal(prepared.safeTransaction.contractInputsValues?.delay, '172800');
	});

	it('wraps a direct upgrade in a timelock execute transaction', async () => {
		const prepared = await buildPreparedUpgradeTransaction({
			action: 'execute',
			chainReader: createTransparentProxyChainReader({
				codeAtNewImplementation: LOCAL_RUNTIME_BYTECODE,
				currentImplementation: CURRENT_IMPLEMENTATION,
				executorOwner: TIMELOCK_ADDRESS,
			}),
			config: {
				artifactPath: 'unused',
				chainId: 1155,
				executorPath: 'timelock',
				id: 'timelock-transparent',
				implementationContractName: 'TrustBonding',
				proxyAdminAddress: PROXY_ADMIN_ADDRESS,
				reinitializerCalldata: '0x',
				rpcUrl: 'http://localhost',
				targetAddress: PROXY_ADDRESS,
				targetKind: 'transparent-proxy',
				timelockAddress: TIMELOCK_ADDRESS,
			},
			localRuntimeBytecode: LOCAL_RUNTIME_BYTECODE,
			newImplementation: NEW_IMPLEMENTATION,
			predecessor: ZERO_BYTES32,
			receiptPath: '/tmp/receipt.json',
			safeAddress: SAFE_ADDRESS,
			salt: ZERO_BYTES32,
		});

		assert.equal(prepared.safeTransaction.to, ethers.utils.getAddress(TIMELOCK_ADDRESS));
		assert.equal(prepared.safeTransaction.contractMethod.name, 'execute');
		assert.equal(
			prepared.safeTransaction.contractInputsValues?.target,
			ethers.utils.getAddress(PROXY_ADMIN_ADDRESS)
		);
		assert.equal(prepared.safeTransaction.contractInputsValues?.data, prepared.directTargetData);
		assert.ok(!('delay' in (prepared.safeTransaction.contractInputsValues ?? {})));
	});

	it('emits a single-transaction safe batch with a checksum', () => {
		const batch = buildSafeBatchFile({
			chainId: 1155,
			createdAt: 1_731_063_959_080,
			safeAddress: SAFE_ADDRESS,
			transaction: {
				contractInputsValues: {
					newImplementation: ethers.utils.getAddress(NEW_IMPLEMENTATION),
				},
				contractMethod: {
					inputs: [
						{
							internalType: 'address',
							name: 'newImplementation',
							type: 'address',
						},
					],
					name: 'upgradeTo',
					payable: false,
				},
				data: null,
				to: ethers.utils.getAddress(BEACON_ADDRESS),
				value: '0',
			},
		});

		assert.equal(batch.transactions.length, 1);
		assert.equal(
			batch.meta.checksum,
			calculateSafeChecksum({ ...batch, meta: { ...batch.meta, checksum: undefined } })
		);
	});
});

describe('checksum fixture', () => {
	it('matches the known Safe checksum example', () => {
		const checksum = calculateSafeChecksum({
			chainId: '1',
			createdAt: 1_731_063_959_080,
			meta: {
				checksum: undefined,
				createdFromOwnerAddress: '',
				createdFromSafeAddress: '0xfF501B324DC6d78dC9F983f140B9211c3EdB4dc7',
				description: '',
				name: 'Transactions Batch',
				txBuilderVersion: '1.17.1',
			},
			transactions: [
				{
					contractInputsValues: null,
					contractMethod: {
						inputs: [],
						name: 'deposit',
						payable: true,
					},
					data: null,
					to: '0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14',
					value: '100000000000000000',
				},
			],
			version: '1.0',
		});

		assert.equal(checksum, '0xbe796761ef9e98c9b4eedf8ceb96feed7cf41f9728ef8925d18eee15b718a1ba');
	});
});

describe('verification guards', () => {
	it('rejects upgrades when the proxy already points at the new implementation', async () => {
		await assert.rejects(
			() =>
				buildPreparedUpgradeTransaction({
					action: 'direct',
					chainReader: createTransparentProxyChainReader({
						codeAtNewImplementation: LOCAL_RUNTIME_BYTECODE,
						currentImplementation: NEW_IMPLEMENTATION,
						executorOwner: SAFE_ADDRESS,
					}),
					config: {
						artifactPath: 'unused',
						chainId: 1,
						executorPath: 'direct',
						id: 'direct-transparent',
						implementationContractName: 'TrustBonding',
						proxyAdminAddress: PROXY_ADMIN_ADDRESS,
						reinitializerCalldata: '0x',
						rpcUrl: 'http://localhost',
						targetAddress: PROXY_ADDRESS,
						targetKind: 'transparent-proxy',
					},
					localRuntimeBytecode: LOCAL_RUNTIME_BYTECODE,
					newImplementation: NEW_IMPLEMENTATION,
					predecessor: ZERO_BYTES32,
					receiptPath: '/tmp/receipt.json',
					safeAddress: SAFE_ADDRESS,
					salt: ZERO_BYTES32,
				}),
			/already points at/
		);
	});

	it('rejects upgrades when deployed bytecode does not match the local artifact', async () => {
		await assert.rejects(
			() =>
				buildPreparedUpgradeTransaction({
					action: 'direct',
					chainReader: createTransparentProxyChainReader({
						codeAtNewImplementation: '0x6002600255',
						currentImplementation: CURRENT_IMPLEMENTATION,
						executorOwner: SAFE_ADDRESS,
					}),
					config: {
						artifactPath: 'unused',
						chainId: 1,
						executorPath: 'direct',
						id: 'direct-transparent',
						implementationContractName: 'TrustBonding',
						proxyAdminAddress: PROXY_ADMIN_ADDRESS,
						reinitializerCalldata: '0x',
						rpcUrl: 'http://localhost',
						targetAddress: PROXY_ADDRESS,
						targetKind: 'transparent-proxy',
					},
					localRuntimeBytecode: LOCAL_RUNTIME_BYTECODE,
					newImplementation: NEW_IMPLEMENTATION,
					predecessor: ZERO_BYTES32,
					receiptPath: '/tmp/receipt.json',
					safeAddress: SAFE_ADDRESS,
					salt: ZERO_BYTES32,
				}),
			/does not match the local artifact/
		);
	});

	it('rejects timelock upgrades when executor ownership is wrong', async () => {
		await assert.rejects(
			() =>
				buildPreparedUpgradeTransaction({
					action: 'schedule',
					chainReader: createTransparentProxyChainReader({
						codeAtNewImplementation: LOCAL_RUNTIME_BYTECODE,
						currentImplementation: CURRENT_IMPLEMENTATION,
						executorOwner: SAFE_ADDRESS,
						timelockDelay: 1,
					}),
					config: {
						artifactPath: 'unused',
						chainId: 1155,
						executorPath: 'timelock',
						id: 'timelock-transparent',
						implementationContractName: 'TrustBonding',
						proxyAdminAddress: PROXY_ADMIN_ADDRESS,
						reinitializerCalldata: '0x',
						rpcUrl: 'http://localhost',
						targetAddress: PROXY_ADDRESS,
						targetKind: 'transparent-proxy',
						timelockAddress: TIMELOCK_ADDRESS,
					},
					localRuntimeBytecode: LOCAL_RUNTIME_BYTECODE,
					newImplementation: NEW_IMPLEMENTATION,
					predecessor: ZERO_BYTES32,
					receiptPath: '/tmp/receipt.json',
					safeAddress: SAFE_ADDRESS,
					salt: ZERO_BYTES32,
				}),
			/Executor owner mismatch/
		);
	});
});

const withTempReceipt = (receipt: { transactions: unknown[] }): string => {
	const tempDir = mkdtempSync(path.join(os.tmpdir(), 'safe-upgrade-lib-'));
	const receiptPath = path.join(tempDir, 'receipt.json');

	writeFileSync(receiptPath, `${JSON.stringify(receipt, null, 2)}\n`, 'utf8');

	process.on('exit', () => rmSync(tempDir, { force: true, recursive: true }));

	return receiptPath;
};

const createTransparentProxyChainReader = ({
	codeAtNewImplementation,
	currentImplementation,
	executorOwner,
	timelockDelay,
}: {
	codeAtNewImplementation: string;
	currentImplementation: string;
	executorOwner: string;
	timelockDelay?: number;
}): ChainReader => {
	const ownableInterface = new ethers.utils.Interface(['function owner() view returns (address)']);
	const timelockInterface = new ethers.utils.Interface([
		'function getMinDelay() view returns (uint256)',
	]);

	return {
		call: async (address: string, data: string) => {
			if (address === ethers.utils.getAddress(PROXY_ADMIN_ADDRESS)) {
				return ownableInterface.encodeFunctionResult('owner', [executorOwner]);
			}

			if (address === ethers.utils.getAddress(TIMELOCK_ADDRESS)) {
				return timelockInterface.encodeFunctionResult('getMinDelay', [timelockDelay ?? 0]);
			}

			throw new Error(`Unexpected call target ${address}`);
		},
		getCode: async (address: string) =>
			address === ethers.utils.getAddress(NEW_IMPLEMENTATION) ? codeAtNewImplementation : '0x',
		getStorageAt: async (address: string, position: string) => {
			assert.equal(address, ethers.utils.getAddress(PROXY_ADDRESS));
			assert.equal(position, EIP1967_IMPLEMENTATION_SLOT);
			return ethers.utils.hexZeroPad(currentImplementation, 32);
		},
	};
};

const createBeaconChainReader = ({
	codeAtNewImplementation,
	currentImplementation,
	executorOwner,
}: {
	codeAtNewImplementation: string;
	currentImplementation: string;
	executorOwner: string;
}): ChainReader => {
	const ownableInterface = new ethers.utils.Interface(['function owner() view returns (address)']);
	const beaconInterface = new ethers.utils.Interface([
		'function implementation() view returns (address)',
	]);

	return {
		call: async (address: string, data: string) => {
			if (address === ethers.utils.getAddress(BEACON_ADDRESS)) {
				if (data === ownableInterface.encodeFunctionData('owner')) {
					return ownableInterface.encodeFunctionResult('owner', [executorOwner]);
				}

				return beaconInterface.encodeFunctionResult('implementation', [currentImplementation]);
			}

			throw new Error(`Unexpected call target ${address}`);
		},
		getCode: async (address: string) =>
			address === ethers.utils.getAddress(NEW_IMPLEMENTATION) ? codeAtNewImplementation : '0x',
		getStorageAt: async () => {
			throw new Error('Beacon tests should not read proxy storage.');
		},
	};
};
