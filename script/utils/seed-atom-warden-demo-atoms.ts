import { ethers } from 'ethers';

const EXPECTED_CHAIN_ID = 13_579;
const DEFAULT_RPC_URL = 'https://testnet.rpc.intuition.systems/http';
const DEFAULT_MULTI_VAULT_ADDRESS = '0x19Ce0e2b5b1d2f79A713CFA5cdA6efdF7AbEcee2';
const EXPLORER_BASE_URL = 'https://testnet.explorer.intuition.systems';

const RESERVED_GITHUB_USER_ROUTES = new Set([
	'about',
	'collections',
	'contact',
	'events',
	'features',
	'issues',
	'marketplace',
	'notifications',
	'orgs',
	'pricing',
	'pulls',
	'search',
	'settings',
	'sponsors',
	'team',
	'topics',
	'trending',
]);

const MULTI_VAULT_ABI = [
	'function getGeneralConfig() view returns ((address admin,address protocolMultisig,uint256 feeDenominator,address trustBonding,uint256 minDeposit,uint256 minShare,uint256 atomDataMaxLength,uint256 feeThreshold))',
	'function getAtomCost() view returns (uint256)',
	'function calculateAtomId(bytes data) view returns (bytes32)',
	'function atom(bytes32 atomId) view returns (bytes)',
	'function walletConfig() view returns ((address entryPoint,address atomWarden,address atomWalletBeacon,address atomWalletFactory))',
	'function createAtoms(bytes[] atomDatas,uint256[] assets) payable returns (bytes32[])',
	'function computeAtomWalletAddr(bytes32 atomId) view returns (address)',
] as const;

const ATOM_WALLET_FACTORY_ABI = [
	'function deployAtomWallet(bytes32 atomId) returns (address)',
] as const;

type ParsedCliArguments = {
	allowExisting: boolean;
	dnsTarget: string;
	dryRun: boolean;
	githubTarget: string;
	multiVaultAddress: string;
	privateKey: string;
	rpcUrl: string;
};

type DemoTargetKind = 'dns' | 'github';

type DemoTarget = {
	atomData: string;
	atomId: string;
	created: boolean;
	existed: boolean;
	kind: DemoTargetKind;
	normalizedTarget: string;
	portalLabel: string;
	portalMethod: 'DNS' | 'GitHub OAuth';
	shouldCreate: boolean;
	walletAddress: string;
	walletCreated: boolean;
	walletExisted: boolean;
};

function printUsage(): void {
	console.log(`
Seed AtomWarden demo atoms on Intuition testnet.

Usage:
  cd contracts/core
  bun run seed:atom-warden:demo -- \\
    --dns-target example.com \\
    --github-target your-github-login \\
    --private-key 0x...

Required flags:
  --dns-target       Raw domain or http/https URL atom for the DNS demo.
  --github-target    GitHub login or GitHub profile URL for the OAuth demo.

Optional flags:
  --private-key      Funding key used to create atoms and deploy AtomWallets.
                     Env fallback: ATOM_WARDEN_DEMO_SEED_PRIVATE_KEY, ATOM_WARDEN_SEED_PRIVATE_KEY, PRIVATE_KEY
  --rpc-url          JSON-RPC endpoint. Default: ${DEFAULT_RPC_URL}
  --multivault       MultiVault address. Default: ${DEFAULT_MULTI_VAULT_ADDRESS}
  --allow-existing   Reuse existing atoms instead of failing when the atom already exists.
  --dry-run          Print the planned atom IDs and wallet addresses without sending transactions.
  --help, -h         Show this help text.

Notes:
  - This helper is for DNS + GitHub OAuth demo atoms only.
  - Fresh atoms do not exercise the historical-creator recovery path.
  - DNS verification is domain-scoped in the current demo flow, so
    "example.com" and "https://example.com/home" both prove "example.com".
`);
}

function parseCliArguments(argv: string[]): ParsedCliArguments {
	let allowExisting = false;
	let dnsTarget = '';
	let dryRun = false;
	let githubTarget = '';
	let multiVaultAddress =
		process.env.ATOM_WARDEN_DEMO_MULTIVAULT_ADDRESS?.trim() || DEFAULT_MULTI_VAULT_ADDRESS;
	let privateKey =
		process.env.ATOM_WARDEN_DEMO_SEED_PRIVATE_KEY?.trim() ||
		process.env.ATOM_WARDEN_SEED_PRIVATE_KEY?.trim() ||
		process.env.PRIVATE_KEY?.trim() ||
		'';
	let rpcUrl =
		process.env.ATOM_WARDEN_DEMO_RPC_URL?.trim() || process.env.RPC_URL?.trim() || DEFAULT_RPC_URL;

	for (let index = 0; index < argv.length; index += 1) {
		const token = argv[index];

		if (token === '--help' || token === '-h') {
			printUsage();
			process.exit(0);
		}

		if (token === '--allow-existing') {
			allowExisting = true;
			continue;
		}

		if (token === '--dry-run') {
			dryRun = true;
			continue;
		}

		if (!token.startsWith('--')) {
			throw new Error(`Unexpected positional argument: ${token}`);
		}

		const flagName = token.slice(2);
		const nextToken = argv[index + 1];

		if (!nextToken || nextToken.startsWith('--')) {
			throw new Error(`Missing value for --${flagName}`);
		}

		switch (flagName) {
			case 'dns-target':
				dnsTarget = nextToken;
				break;
			case 'github-target':
				githubTarget = nextToken;
				break;
			case 'multivault':
				multiVaultAddress = nextToken;
				break;
			case 'private-key':
				privateKey = nextToken;
				break;
			case 'rpc-url':
				rpcUrl = nextToken;
				break;
			default:
				throw new Error(`Unknown flag: --${flagName}`);
		}

		index += 1;
	}

	if (!dnsTarget.trim()) {
		throw new Error('Missing required flag --dns-target');
	}

	if (!githubTarget.trim()) {
		throw new Error('Missing required flag --github-target');
	}

	if (!ethers.utils.isAddress(multiVaultAddress)) {
		throw new Error(`Invalid --multivault address: ${multiVaultAddress}`);
	}

	if (!rpcUrl.trim()) {
		throw new Error('Missing RPC URL. Pass --rpc-url or set RPC_URL.');
	}

	if (!dryRun && !privateKey) {
		throw new Error(
			'Missing private key. Pass --private-key or set ATOM_WARDEN_DEMO_SEED_PRIVATE_KEY.'
		);
	}

	if (privateKey && !privateKey.startsWith('0x')) {
		privateKey = `0x${privateKey}`;
	}

	if (privateKey && !/^0x[0-9a-fA-F]{64}$/.test(privateKey)) {
		throw new Error('Private key must be a 32-byte hex string.');
	}

	return {
		allowExisting,
		dnsTarget: normalizeDnsSeedInput(dnsTarget),
		dryRun,
		githubTarget: normalizeGitHubSeedInput(githubTarget),
		multiVaultAddress: ethers.utils.getAddress(multiVaultAddress),
		privateKey,
		rpcUrl: rpcUrl.trim(),
	};
}

function normalizeDnsSeedInput(value: string): string {
	const trimmedValue = value.trim();

	if (!trimmedValue) {
		throw new Error('DNS target must not be empty.');
	}

	if (normalizeDomain(trimmedValue)) {
		return trimmedValue;
	}

	try {
		const parsed = new URL(trimmedValue);
		if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
			throw new Error('DNS URL atoms must use http or https.');
		}

		if (!normalizeDomain(parsed.hostname)) {
			throw new Error('DNS URL atom hostname is not a valid domain.');
		}

		return trimmedValue;
	} catch (error) {
		if (error instanceof Error) {
			throw new Error(
				`Unsupported DNS target "${trimmedValue}". Use a raw domain or http/https URL. ${error.message}`
			);
		}

		throw new Error(
			`Unsupported DNS target "${trimmedValue}". Use a raw domain or http/https URL.`
		);
	}
}

function normalizeGitHubSeedInput(value: string): string {
	const trimmedValue = value.trim();

	if (!trimmedValue) {
		throw new Error('GitHub target must not be empty.');
	}

	if (!trimmedValue.includes('://') && !trimmedValue.includes('/')) {
		const login = trimmedValue;
		validateGitHubLogin(login);
		return `https://github.com/${login}`;
	}

	const parsed = new URL(trimmedValue);
	if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
		throw new Error('GitHub target must use http or https.');
	}

	if (parsed.hostname !== 'github.com' && parsed.hostname !== 'www.github.com') {
		throw new Error('GitHub target must point to github.com.');
	}

	const segments = parsed.pathname.split('/').filter(Boolean);
	if (segments.length !== 1) {
		throw new Error('GitHub target must be a profile URL with exactly one path segment.');
	}

	const login = segments[0] ?? '';
	validateGitHubLogin(login);

	return `https://github.com/${login}`;
}

function validateGitHubLogin(login: string): void {
	const trimmedLogin = login.trim();

	if (!trimmedLogin) {
		throw new Error('GitHub login must not be empty.');
	}

	if (!/^[a-zA-Z0-9-]+$/.test(trimmedLogin)) {
		throw new Error('GitHub login may only contain letters, numbers, and hyphens.');
	}

	if (RESERVED_GITHUB_USER_ROUTES.has(trimmedLogin.toLowerCase())) {
		throw new Error(`GitHub login "${trimmedLogin}" is reserved and not a valid profile atom.`);
	}
}

function normalizeDomain(value: string): string | undefined {
	const cleaned = value
		.trim()
		.toLowerCase()
		.replace(/^https?:\/\//, '')
		.replace(/\/$/, '');
	const domain = cleaned.split('/')[0]?.replace(/\.+$/, '');

	if (!domain || !/^(?:[a-z0-9-]+\.)+[a-z]{2,}$/i.test(domain)) {
		return undefined;
	}

	return domain;
}

function formatPortalTarget(target: DemoTarget): string {
	return target.kind === 'dns' ? target.normalizedTarget : target.atomData;
}

async function main(): Promise<void> {
	const arguments_ = parseCliArguments(process.argv.slice(2));
	const provider = new ethers.providers.JsonRpcProvider(arguments_.rpcUrl);
	const network = await provider.getNetwork();

	if (network.chainId !== EXPECTED_CHAIN_ID) {
		throw new Error(
			`Unsupported chain ID ${network.chainId}. This helper is intended for Intuition testnet (${EXPECTED_CHAIN_ID}).`
		);
	}

	const signer = arguments_.dryRun
		? ethers.Wallet.createRandom().connect(provider)
		: new ethers.Wallet(arguments_.privateKey, provider);
	const multiVault = new ethers.Contract(arguments_.multiVaultAddress, MULTI_VAULT_ABI, signer);
	const generalConfig = await multiVault.getGeneralConfig();
	const atomCost = await multiVault.getAtomCost();
	const assetsPerAtom = atomCost.add(generalConfig.minDeposit);
	const walletConfig = await multiVault.walletConfig();
	const atomWalletFactoryAddress = ethers.utils.getAddress(walletConfig.atomWalletFactory);
	const atomWalletFactory = new ethers.Contract(
		atomWalletFactoryAddress,
		ATOM_WALLET_FACTORY_ABI,
		signer
	);

	const targets: DemoTarget[] = [
		{
			atomData: arguments_.dnsTarget,
			atomId: await multiVault.calculateAtomId(ethers.utils.toUtf8Bytes(arguments_.dnsTarget)),
			created: false,
			existed: false,
			kind: 'dns',
			normalizedTarget:
				normalizeDomain(arguments_.dnsTarget) ?? new URL(arguments_.dnsTarget).hostname,
			portalLabel: 'DNS atom',
			portalMethod: 'DNS',
			shouldCreate: false,
			walletAddress: ethers.constants.AddressZero,
			walletCreated: false,
			walletExisted: false,
		},
		{
			atomData: arguments_.githubTarget,
			atomId: await multiVault.calculateAtomId(ethers.utils.toUtf8Bytes(arguments_.githubTarget)),
			created: false,
			existed: false,
			kind: 'github',
			normalizedTarget: arguments_.githubTarget,
			portalLabel: 'GitHub atom',
			portalMethod: 'GitHub OAuth',
			shouldCreate: false,
			walletAddress: ethers.constants.AddressZero,
			walletCreated: false,
			walletExisted: false,
		},
	];

	for (const target of targets) {
		const storedAtomData = await multiVault.atom(target.atomId);
		target.existed = storedAtomData !== '0x';
		target.shouldCreate = !target.existed;

		if (target.existed && !arguments_.allowExisting) {
			throw new Error(
				`${target.portalLabel} already exists for "${target.atomData}". Re-run with --allow-existing to reuse it.`
			);
		}
	}

	const targetsToCreate = targets.filter((target) => target.shouldCreate);
	const totalAssetsRequired = assetsPerAtom.mul(targetsToCreate.length);

	console.log(`Network: ${network.name} (${network.chainId})`);
	console.log(`RPC URL: ${arguments_.rpcUrl}`);
	console.log(`MultiVault: ${arguments_.multiVaultAddress}`);
	console.log(`AtomWalletFactory: ${atomWalletFactoryAddress}`);
	console.log(`Sender: ${signer.address}`);
	console.log(`Atom cost: ${ethers.utils.formatEther(atomCost)} tTRUST`);
	console.log(`Min deposit: ${ethers.utils.formatEther(generalConfig.minDeposit)} tTRUST`);
	console.log(`Assets per atom: ${ethers.utils.formatEther(assetsPerAtom)} tTRUST`);

	if (targetsToCreate.length > 0) {
		console.log(`Atoms to create: ${targetsToCreate.length}`);
		console.log(`Total assets required: ${ethers.utils.formatEther(totalAssetsRequired)} tTRUST`);
	}

	if (!arguments_.dryRun && totalAssetsRequired.gt(0)) {
		const balance = await signer.getBalance();
		if (balance.lt(totalAssetsRequired)) {
			throw new Error(
				`Insufficient balance. Need at least ${ethers.utils.formatEther(totalAssetsRequired)} tTRUST before gas, have ${ethers.utils.formatEther(balance)}.`
			);
		}
	}

	if (targetsToCreate.length > 0 && !arguments_.dryRun) {
		const atomDatas = targetsToCreate.map((target) => ethers.utils.toUtf8Bytes(target.atomData));
		const assets = targetsToCreate.map(() => assetsPerAtom);
		const createAtomsTransaction = await multiVault.createAtoms(atomDatas, assets, {
			value: totalAssetsRequired,
		});
		const createAtomsReceipt = await createAtomsTransaction.wait();

		console.log(
			`Created ${targetsToCreate.length} atom(s): ${EXPLORER_BASE_URL}/tx/${createAtomsReceipt.transactionHash}`
		);

		for (const target of targetsToCreate) {
			target.created = true;
		}
	}

	for (const target of targets) {
		target.walletAddress = await multiVault.computeAtomWalletAddr(target.atomId);
		const walletCodeBefore = await provider.getCode(target.walletAddress);
		target.walletExisted = walletCodeBefore !== '0x';

		if (!target.walletExisted && !arguments_.dryRun) {
			const deployWalletTransaction = await atomWalletFactory.deployAtomWallet(target.atomId);
			const deployWalletReceipt = await deployWalletTransaction.wait();
			console.log(
				`Deployed ${target.portalLabel} wallet: ${EXPLORER_BASE_URL}/tx/${deployWalletReceipt.transactionHash}`
			);
			target.walletCreated = true;
		}
	}

	console.log('\nPortal inputs');
	for (const target of targets) {
		console.log(`- ${target.portalLabel}`);
		console.log(`  method: ${target.portalMethod}`);
		console.log(`  atom data: ${target.atomData}`);
		console.log(`  portal target: ${formatPortalTarget(target)}`);
		console.log(`  atom id: ${target.atomId}`);
		console.log(`  atom wallet: ${target.walletAddress}`);
		console.log(`  atom existed: ${target.existed ? 'yes' : 'no'}`);
		console.log(`  atom created now: ${target.created ? 'yes' : 'no'}`);
		console.log(`  wallet existed: ${target.walletExisted ? 'yes' : 'no'}`);
		console.log(`  wallet created now: ${target.walletCreated ? 'yes' : 'no'}`);
		console.log(`  explorer: ${EXPLORER_BASE_URL}/address/${target.walletAddress}`);
	}

	console.log('\nCopy/paste env-style output');
	console.log(`ATOM_WARDEN_DEMO_DNS_ATOM_ID=${targets[0].atomId}`);
	console.log(`ATOM_WARDEN_DEMO_DNS_ATOM_WALLET=${targets[0].walletAddress}`);
	console.log(`ATOM_WARDEN_DEMO_DNS_TARGET=${targets[0].atomData}`);
	console.log(`ATOM_WARDEN_DEMO_GITHUB_ATOM_ID=${targets[1].atomId}`);
	console.log(`ATOM_WARDEN_DEMO_GITHUB_ATOM_WALLET=${targets[1].walletAddress}`);
	console.log(`ATOM_WARDEN_DEMO_GITHUB_TARGET=${targets[1].atomData}`);
}

main().catch((error: unknown) => {
	if (error instanceof Error) {
		console.error(`\nError: ${error.message}`);
	} else {
		console.error('\nError: unknown failure');
	}

	process.exit(1);
});
