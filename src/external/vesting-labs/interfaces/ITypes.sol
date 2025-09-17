// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

interface ITypes {
	enum FeeType {
		Gas,
		DistributionToken
	}

	enum FundingType {
		Full,
		Partial
	}
}
