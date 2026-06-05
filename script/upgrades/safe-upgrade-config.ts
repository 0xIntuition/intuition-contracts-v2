import path from 'node:path';

import type { UpgradeTargetConfig } from './safe-upgrade-lib';

const rootPath = (...segments: string[]): string =>
	path.resolve(import.meta.dir, '..', '..', ...segments);

export const upgradeTargetRegistry: Record<string, UpgradeTargetConfig> = {
	'base-base-emissions-controller': {
		artifactPath: rootPath('out/BaseEmissionsController.sol/BaseEmissionsController.json'),
		chainId: 8453,
		executorPath: 'timelock',
		id: 'base-base-emissions-controller',
		implementationContractName: 'BaseEmissionsController',
		proxyAdminAddress: '0x58dCdf3b6F5D03835CF6556EdC798bfd690B251a',
		reinitializerCalldata: '0x',
		rpcUrl: 'https://mainnet.base.org',
		targetAddress: '0x7745bDEe668501E5eeF7e9605C746f9cDfb60667',
		targetKind: 'transparent-proxy',
		timelockAddress: '0x1E442BbB08c98100b18fa830a88E8A57b5dF9157',
	},
	'intuition-atom-wallet-beacon': {
		artifactPath: rootPath('out/AtomWallet.sol/AtomWallet.json'),
		chainId: 1155,
		executorPath: 'timelock',
		id: 'intuition-atom-wallet-beacon',
		implementationContractName: 'AtomWallet',
		rpcUrl: 'https://rpc.intuition.systems/http',
		targetAddress: '0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF',
		targetKind: 'beacon',
		timelockAddress: '0x321e5d4b20158648dFd1f360A79CAFc97190bAd1',
	},
	'intuition-offset-progressive-curve': {
		artifactPath: rootPath('out/OffsetProgressiveCurve.sol/OffsetProgressiveCurve.json'),
		chainId: 1155,
		executorPath: 'timelock',
		id: 'intuition-offset-progressive-curve',
		implementationContractName: 'OffsetProgressiveCurve',
		proxyAdminAddress: '0xe58B117aDfB0a141dC1CC22b98297294F6E2c5E7',
		reinitializerCalldata: '0x',
		rpcUrl: 'https://rpc.intuition.systems/http',
		targetAddress: '0x23afF95153aa88D28B9B97Ba97629E05D5fD335d',
		targetKind: 'transparent-proxy',
		timelockAddress: '0x321e5d4b20158648dFd1f360A79CAFc97190bAd1',
	},
	'intuition-satellite-emissions-controller': {
		artifactPath: rootPath(
			'out/SatelliteEmissionsController.sol/SatelliteEmissionsController.json'
		),
		chainId: 1155,
		executorPath: 'timelock',
		id: 'intuition-satellite-emissions-controller',
		implementationContractName: 'SatelliteEmissionsController',
		proxyAdminAddress: '0xdF60D18E86F3454309aD7734055843F7ee5f30a3',
		reinitializerCalldata: '0x',
		rpcUrl: 'https://rpc.intuition.systems/http',
		targetAddress: '0x73B8819f9b157BE42172E3866fB0Ba0d5fA0A5c6',
		targetKind: 'transparent-proxy',
		timelockAddress: '0x321e5d4b20158648dFd1f360A79CAFc97190bAd1',
	},
	'intuition-trust-bonding': {
		artifactPath: rootPath('out/TrustBonding.sol/TrustBonding.json'),
		chainId: 1155,
		executorPath: 'timelock',
		id: 'intuition-trust-bonding',
		implementationContractName: 'TrustBonding',
		proxyAdminAddress: '0xF10FEE90B3C633c4fCd49aA557Ec7d51E5AEef62',
		reinitializerCalldata: '0x',
		rpcUrl: 'https://rpc.intuition.systems/http',
		targetAddress: '0x635bBD1367B66E7B16a21D6E5A63C812fFC00617',
		targetKind: 'transparent-proxy',
		timelockAddress: '0x321e5d4b20158648dFd1f360A79CAFc97190bAd1',
	},
};

export const getUpgradeTargetConfig = (upgradeId: string): UpgradeTargetConfig => {
	const config = upgradeTargetRegistry[upgradeId];

	if (!config) {
		throw new Error(
			`Unknown upgrade id ${upgradeId}. Known ids: ${Object.keys(upgradeTargetRegistry).join(', ')}.`
		);
	}

	return config;
};
