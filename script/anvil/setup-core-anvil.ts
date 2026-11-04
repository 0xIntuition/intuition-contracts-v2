import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join } from 'node:path';

type RunTransaction = {
	transactionType?: string;
	contractName?: string;
	contractAddress?: string;
	arguments?: unknown[];
};

type RunFile = {
	transactions?: RunTransaction[];
};

// Note: Do NOT use the default Anvil deployer private key for anything other than testing locally
const DEFAULT_DEPLOYER_PRIVATE_KEY =
	'0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const DEFAULT_ADMIN = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266';
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const CHAIN_ID = '31337';
const ANVIL_HOST = process.env.ANVIL_HOST ?? '127.0.0.1';
const DEFAULT_ANVIL_PORT = Number.parseInt(process.env.ANVIL_PORT ?? '8545', 10);
const EXPLICIT_RPC_URL = process.env.ANVIL_RPC_URL?.trim();
const CORE_FAST_MODE = process.env.ANVIL_CORE_FAST_MODE === '1';
const CORE_FAST_SKIP_BASE_EMISSIONS = process.env.ANVIL_CORE_FAST_SKIP_BASE_EMISSIONS === '1';
const CORE_SKIP_SIMULATION = process.env.ANVIL_CORE_SKIP_SIMULATION !== '0';
const CORE_USE_SLOW = process.env.ANVIL_CORE_USE_SLOW === '1';
const CORE_VERBOSE = process.env.ANVIL_CORE_VERBOSE === '1';
const CORE_INLINE_TRUST_DEPLOY = process.env.ANVIL_CORE_INLINE_TRUST_DEPLOY !== '0';

const CWD = process.cwd();
const BROADCAST_DIR_INPUT = process.env.FOUNDRY_BROADCAST?.trim() || 'broadcast';
const CACHE_DIR_INPUT = process.env.FOUNDRY_CACHE_PATH?.trim() || 'cache';
const BROADCAST_DIR = isAbsolute(BROADCAST_DIR_INPUT)
	? BROADCAST_DIR_INPUT
	: join(CWD, BROADCAST_DIR_INPUT);
const EXPORT_DIR = isAbsolute(CACHE_DIR_INPUT) ? CACHE_DIR_INPUT : join(CWD, CACHE_DIR_INPUT);
const EXPORT_JSON_PATH =
	process.env.ANVIL_EXPORT_JSON_PATH?.trim() || join(EXPORT_DIR, 'anvil-core-addresses.json');
const EXPORT_ENV_PATH =
	process.env.ANVIL_EXPORT_ENV_PATH?.trim() || join(EXPORT_DIR, 'anvil-core-addresses.env');

const SCRIPT_BASE_EMISSIONS_DEPLOY =
	'script/base/BaseEmissionsControllerDeploy.s.sol:BaseEmissionsControllerDeploy';
const SCRIPT_INTUITION_DEPLOY_AND_SETUP =
	'script/intuition/IntuitionDeployAndSetup.s.sol:IntuitionDeployAndSetup';
const SCRIPT_BASE_EMISSIONS_SETUP =
	'script/base/BaseEmissionsControllerSetup.s.sol:BaseEmissionsControllerSetup';
const SCRIPT_WRAPPED_TRUST_DEPLOY = 'script/intuition/WrappedTrustDeploy.s.sol:WrappedTrustDeploy';

function getEnvOrDefault(name: string, fallback?: string): string {
	const value = process.env[name]?.trim();
	if (value && value.length > 0) {
		return value;
	}
	if (fallback !== undefined) {
		return fallback;
	}
	throw new Error(`Missing required env var: ${name}`);
}

function runCommand(args: string[], env: Record<string, string>) {
	console.log(`\n$ ${args.join(' ')}`);
	const proc = Bun.spawnSync(args, {
		cwd: CWD,
		env: { ...process.env, ...env },
		stdout: CORE_VERBOSE ? 'inherit' : 'pipe',
		stderr: CORE_VERBOSE ? 'inherit' : 'pipe',
	});

	if (proc.exitCode !== 0) {
		const stdout = proc.stdout.toString().trim();
		const stderr = proc.stderr.toString().trim();
		const details = [
			`Command failed (${proc.exitCode}): ${args.join(' ')}`,
			stdout ? `stdout:\n${stdout}` : '',
			stderr ? `stderr:\n${stderr}` : '',
		]
			.filter(Boolean)
			.join('\n\n');
		throw new Error(details);
	}
}

function runCommandCapture(args: string[]) {
	const proc = Bun.spawnSync(args, {
		cwd: CWD,
		env: process.env,
		stdout: 'pipe',
		stderr: 'pipe',
	});

	return {
		exitCode: proc.exitCode,
		stdout: proc.stdout.toString().trim(),
		stderr: proc.stderr.toString().trim(),
	};
}

function isAnvilRunning(rpcUrl: string): boolean {
	const result = runCommandCapture(['cast', 'chain-id', '--rpc-url', rpcUrl]);
	return result.exitCode === 0 && result.stdout === CHAIN_ID;
}

async function ensureAnvil() {
	if (EXPLICIT_RPC_URL) {
		if (!isAnvilRunning(EXPLICIT_RPC_URL)) {
			throw new Error(`No Anvil instance detected at ANVIL_RPC_URL=${EXPLICIT_RPC_URL}`);
		}
		console.log(`Using existing Anvil from ANVIL_RPC_URL=${EXPLICIT_RPC_URL}`);
		return {
			startedByScript: false as const,
			proc: null as Bun.Subprocess | null,
			rpcUrl: EXPLICIT_RPC_URL,
		};
	}

	let selectedPort = DEFAULT_ANVIL_PORT;
	let rpcUrl = `http://${ANVIL_HOST}:${selectedPort}`;

	if (isAnvilRunning(rpcUrl)) {
		selectedPort += 1;
		rpcUrl = `http://${ANVIL_HOST}:${selectedPort}`;
		console.log(
			`Detected existing Anvil at http://${ANVIL_HOST}:${DEFAULT_ANVIL_PORT}, starting managed Anvil at ${rpcUrl}`
		);
	} else {
		console.log(`Starting managed Anvil at ${rpcUrl}`);
	}

	const proc = Bun.spawn(
		[
			'anvil',
			'--host',
			ANVIL_HOST,
			'--port',
			selectedPort.toString(),
			'--chain-id',
			CHAIN_ID,
			'--disable-code-size-limit',
			'--silent',
		],
		{
			cwd: CWD,
			env: process.env,
			stdout: 'inherit',
			stderr: 'inherit',
		}
	);

	for (let i = 0; i < 30; i++) {
		await Bun.sleep(250);
		if (isAnvilRunning(rpcUrl)) {
			return { startedByScript: true as const, proc, rpcUrl };
		}
	}

	proc.kill();
	throw new Error('Failed to start Anvil in time');
}

function findFilesRecursive(directory: string): string[] {
	if (!existsSync(directory)) {
		return [];
	}

	const results: string[] = [];
	const entries = readdirSync(directory, { withFileTypes: true });

	for (const entry of entries) {
		const fullPath = join(directory, entry.name);
		if (entry.isDirectory()) {
			results.push(...findFilesRecursive(fullPath));
		} else {
			results.push(fullPath);
		}
	}

	return results;
}

function findLatestRunFile(scriptFileName: string): string {
	const allFiles = findFilesRecursive(BROADCAST_DIR);
	const matching = allFiles.filter((path) => {
		return (
			path.endsWith(`/run-latest.json`) &&
			path.includes(`/${scriptFileName}/`) &&
			path.includes(`/${CHAIN_ID}/`)
		);
	});

	if (matching.length === 0) {
		throw new Error(`Could not find broadcast run-latest.json for ${scriptFileName}`);
	}

	matching.sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
	return matching[0];
}

function readRunFile(scriptFileName: string): RunFile {
	const runFilePath = findLatestRunFile(scriptFileName);
	return JSON.parse(readFileSync(runFilePath, 'utf8')) as RunFile;
}

function getCreatedAddresses(runFile: RunFile, contractName: string): string[] {
	return (runFile.transactions ?? [])
		.filter(
			(tx) =>
				tx.transactionType === 'CREATE' && tx.contractName === contractName && tx.contractAddress
		)
		.map((tx) => tx.contractAddress as string);
}

function getSingleCreatedAddress(runFile: RunFile, contractName: string, label: string): string {
	const created = getCreatedAddresses(runFile, contractName);
	if (created.length === 0) {
		throw new Error(`Missing CREATE transaction for ${label} (${contractName})`);
	}
	return created[created.length - 1];
}

function getProxyAddressForImplementation(
	runFile: RunFile,
	implementationAddress: string,
	label: string
): string {
	const proxyCreates = (runFile.transactions ?? []).filter((tx) => {
		if (
			tx.transactionType !== 'CREATE' ||
			tx.contractName !== 'TransparentUpgradeableProxy' ||
			!tx.contractAddress ||
			!Array.isArray(tx.arguments)
		) {
			return false;
		}

		const [implementationArg] = tx.arguments;
		return (
			typeof implementationArg === 'string' &&
			implementationArg.toLowerCase() === implementationAddress.toLowerCase()
		);
	});

	if (proxyCreates.length === 0) {
		throw new Error(
			`Missing TransparentUpgradeableProxy CREATE for ${label} (implementation=${implementationAddress})`
		);
	}

	if (proxyCreates.length > 1) {
		throw new Error(
			`Found multiple TransparentUpgradeableProxy CREATE transactions for ${label} (implementation=${implementationAddress})`
		);
	}

	return proxyCreates[0].contractAddress as string;
}

function asEnvLine(key: string, value: string | undefined) {
	return `${key}=${value ?? ''}`;
}

function forgeScriptArgs(scriptTarget: string, rpcUrl: string): string[] {
	const args = [
		'forge',
		'script',
		scriptTarget,
		'--rpc-url',
		rpcUrl,
		'--broadcast',
		'--disable-code-size-limit',
		'--non-interactive',
	];

	if (CORE_SKIP_SIMULATION) {
		args.push('--skip-simulation');
	}

	if (CORE_USE_SLOW) {
		args.push('--slow');
	}

	return args;
}

async function main() {
	const anvil = await ensureAnvil();
	const rpcUrl = anvil.rpcUrl;

	try {
		const adminAddress = getEnvOrDefault('ANVIL_ADMIN_ADDRESS', DEFAULT_ADMIN);
		const deployerPrivateKey = getEnvOrDefault('DEPLOYER_LOCAL', DEFAULT_DEPLOYER_PRIVATE_KEY);
		const migratorAddress = getEnvOrDefault('ANVIL_MULTI_VAULT_ROLE_MIGRATOR', adminAddress);
		const protocolMultisig = getEnvOrDefault('ANVIL_PROTOCOL_MULTISIG', adminAddress);

		const forgeEnv: Record<string, string> = {
			DEPLOYER_LOCAL: deployerPrivateKey,
			ANVIL_ADMIN_ADDRESS: adminAddress,
			ANVIL_PROTOCOL_MULTISIG: protocolMultisig,
			ANVIL_MULTI_VAULT_ROLE_MIGRATOR: migratorAddress,
			ANVIL_CHAIN_ID: CHAIN_ID,
			BASE_SEPOLIA_CHAIN_ID: getEnvOrDefault('BASE_SEPOLIA_CHAIN_ID', '84532'),
		};

		let trustToken = process.env.ANVIL_TRUST_TOKEN?.trim();
		let wrappedTrustDeployed: string | undefined;
		const shouldDeployBaseEmissions = !CORE_FAST_MODE || !CORE_FAST_SKIP_BASE_EMISSIONS;

		if (!trustToken || trustToken === ZERO_ADDRESS) {
			if (CORE_INLINE_TRUST_DEPLOY) {
				if (shouldDeployBaseEmissions) {
					// BaseEmissionsController requires a non-zero token address, so deploy WrappedTrust first when needed.
					runCommand(forgeScriptArgs(SCRIPT_WRAPPED_TRUST_DEPLOY, rpcUrl), forgeEnv);
					const wrappedTrustRun = readRunFile('WrappedTrustDeploy.s.sol');
					wrappedTrustDeployed = getSingleCreatedAddress(
						wrappedTrustRun,
						'WrappedTrust',
						'WrappedTrust'
					);
					trustToken = wrappedTrustDeployed;
					forgeEnv.ANVIL_TRUST_TOKEN = wrappedTrustDeployed;
				} else {
					// Let IntuitionDeployAndSetup auto-deploy WrappedTrust on Anvil.
					trustToken = ZERO_ADDRESS;
					forgeEnv.ANVIL_TRUST_TOKEN = ZERO_ADDRESS;
				}
			} else {
				throw new Error(
					'Missing ANVIL_TRUST_TOKEN and inline trust deploy is disabled (set ANVIL_CORE_INLINE_TRUST_DEPLOY=1 or provide ANVIL_TRUST_TOKEN).'
				);
			}
		} else {
			forgeEnv.ANVIL_TRUST_TOKEN = trustToken;
		}

		let baseEmissionsUpgradesTimelock = ZERO_ADDRESS;
		let baseEmissionsImplementation = ZERO_ADDRESS;
		let baseEmissionsProxy = adminAddress;

		if (shouldDeployBaseEmissions) {
			runCommand(forgeScriptArgs(SCRIPT_BASE_EMISSIONS_DEPLOY, rpcUrl), forgeEnv);

			const baseRun = readRunFile('BaseEmissionsControllerDeploy.s.sol');
			baseEmissionsUpgradesTimelock = getSingleCreatedAddress(
				baseRun,
				'TimelockController',
				'BaseEmissions Upgrades Timelock'
			);
			baseEmissionsImplementation = getSingleCreatedAddress(
				baseRun,
				'BaseEmissionsController',
				'BaseEmissionsController Implementation'
			);
			baseEmissionsProxy = getSingleCreatedAddress(
				baseRun,
				'TransparentUpgradeableProxy',
				'BaseEmissionsController Proxy'
			);
		} else {
			console.log(
				`Fast mode enabled (ANVIL_CORE_FAST_MODE=1, ANVIL_CORE_FAST_SKIP_BASE_EMISSIONS=1): skipping BaseEmissionsController deploy/setup, using ${adminAddress} as placeholder base controller.`
			);
		}

		forgeEnv.ANVIL_BASE_EMISSIONS_CONTROLLER = baseEmissionsProxy;

		runCommand(forgeScriptArgs(SCRIPT_INTUITION_DEPLOY_AND_SETUP, rpcUrl), forgeEnv);

		const intuitionRun = readRunFile('IntuitionDeployAndSetup.s.sol');
		if (!wrappedTrustDeployed && forgeEnv.ANVIL_TRUST_TOKEN === ZERO_ADDRESS) {
			wrappedTrustDeployed = getSingleCreatedAddress(intuitionRun, 'WrappedTrust', 'WrappedTrust');
			trustToken = wrappedTrustDeployed;
		}
		const intuitionTimelocks = getCreatedAddresses(intuitionRun, 'TimelockController');

		if (intuitionTimelocks.length < 2) {
			throw new Error('Expected 2 TimelockController deployments in IntuitionDeployAndSetup');
		}

		const atomWalletImplementation = getSingleCreatedAddress(
			intuitionRun,
			'AtomWallet',
			'AtomWallet Implementation'
		);
		const atomWalletBeacon = getSingleCreatedAddress(
			intuitionRun,
			'UpgradeableBeacon',
			'AtomWallet Beacon'
		);
		const atomWalletFactoryImplementation = getSingleCreatedAddress(
			intuitionRun,
			'AtomWalletFactory',
			'AtomWalletFactory Implementation'
		);
		const atomWardenImplementation = getSingleCreatedAddress(
			intuitionRun,
			'AtomWarden',
			'AtomWarden Implementation'
		);
		const bondingCurveRegistryImplementation = getSingleCreatedAddress(
			intuitionRun,
			'BondingCurveRegistry',
			'BondingCurveRegistry Implementation'
		);
		const linearCurveImplementation = getSingleCreatedAddress(
			intuitionRun,
			'LinearCurve',
			'LinearCurve Implementation'
		);
		const satelliteEmissionsImplementation = getSingleCreatedAddress(
			intuitionRun,
			'SatelliteEmissionsController',
			'SatelliteEmissionsController Implementation'
		);
		const trustBondingImplementation = getSingleCreatedAddress(
			intuitionRun,
			'TrustBonding',
			'TrustBonding Implementation'
		);
		const multiVaultImplementation = getSingleCreatedAddress(
			intuitionRun,
			'MultiVault',
			'MultiVault Implementation'
		);

		const atomWalletFactory = getProxyAddressForImplementation(
			intuitionRun,
			atomWalletFactoryImplementation,
			'AtomWalletFactory Proxy'
		);
		const atomWarden = getProxyAddressForImplementation(
			intuitionRun,
			atomWardenImplementation,
			'AtomWarden Proxy'
		);
		const bondingCurveRegistry = getProxyAddressForImplementation(
			intuitionRun,
			bondingCurveRegistryImplementation,
			'BondingCurveRegistry Proxy'
		);
		const linearCurve = getProxyAddressForImplementation(
			intuitionRun,
			linearCurveImplementation,
			'LinearCurve Proxy'
		);
		const satelliteEmissionsController = getProxyAddressForImplementation(
			intuitionRun,
			satelliteEmissionsImplementation,
			'SatelliteEmissionsController Proxy'
		);
		const trustBonding = getProxyAddressForImplementation(
			intuitionRun,
			trustBondingImplementation,
			'TrustBonding Proxy'
		);
		const multiVault = getProxyAddressForImplementation(
			intuitionRun,
			multiVaultImplementation,
			'MultiVault Proxy'
		);

		forgeEnv.ANVIL_SATELLITE_EMISSIONS_CONTROLLER = satelliteEmissionsController;

		if (shouldDeployBaseEmissions) {
			runCommand(forgeScriptArgs(SCRIPT_BASE_EMISSIONS_SETUP, rpcUrl), forgeEnv);
		}

		mkdirSync(EXPORT_DIR, { recursive: true });
		mkdirSync(dirname(EXPORT_JSON_PATH), { recursive: true });
		mkdirSync(dirname(EXPORT_ENV_PATH), { recursive: true });

		const exportData = {
			network: 'anvil',
			chainId: Number(CHAIN_ID),
			rpcUrl,
			admin: adminAddress,
			deployer: adminAddress,
			trustToken,
			wrappedTrust: wrappedTrustDeployed,
			baseEmissionsController: {
				upgradesTimelock: baseEmissionsUpgradesTimelock,
				implementation: baseEmissionsImplementation,
				proxy: baseEmissionsProxy,
			},
			intuition: {
				upgradesTimelock: intuitionTimelocks[0],
				parametersTimelock: intuitionTimelocks[1],
				atomWalletImplementation,
				atomWalletBeacon,
				atomWalletFactoryImplementation,
				atomWalletFactory,
				atomWardenImplementation,
				atomWarden,
				bondingCurveRegistryImplementation,
				bondingCurveRegistry,
				linearCurveImplementation,
				linearCurve,
				satelliteEmissionsControllerImplementation: satelliteEmissionsImplementation,
				satelliteEmissionsController,
				trustBondingImplementation,
				trustBonding,
				multiVault,
			},
		};

		writeFileSync(EXPORT_JSON_PATH, `${JSON.stringify(exportData, null, 2)}\n`, 'utf8');

		const envContent = [
			'# Generated by script/anvil/setup-core-anvil.ts',
			asEnvLine('ANVIL_RPC_URL', rpcUrl),
			asEnvLine('ANVIL_ADMIN_ADDRESS', adminAddress),
			asEnvLine('ANVIL_TRUST_TOKEN', trustToken),
			asEnvLine('ANVIL_BASE_EMISSIONS_CONTROLLER', baseEmissionsProxy),
			asEnvLine('ANVIL_SATELLITE_EMISSIONS_CONTROLLER', satelliteEmissionsController),
			asEnvLine('ANVIL_MULTIVAULT', multiVault),
			asEnvLine('ANVIL_TRUST_BONDING', trustBonding),
			asEnvLine('ANVIL_BONDING_CURVE_REGISTRY', bondingCurveRegistry),
			asEnvLine('ANVIL_LINEAR_CURVE', linearCurve),
			asEnvLine('ANVIL_ATOM_WARDEN', atomWarden),
			asEnvLine('ANVIL_ATOM_WALLET_FACTORY', atomWalletFactory),
			'',
		].join('\n');

		writeFileSync(EXPORT_ENV_PATH, envContent, 'utf8');

		console.log('\nCore contracts deployed on Anvil and exported:');
		console.log(`- JSON: ${EXPORT_JSON_PATH}`);
		console.log(`- ENV:  ${EXPORT_ENV_PATH}`);
	} finally {
		if (anvil.startedByScript && anvil.proc) {
			anvil.proc.kill();
		}
	}
}

await main();
