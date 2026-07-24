declare const MultiVaultAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "ATOM_SALT";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "BURN_ADDRESS";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "COUNTER_SALT";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "DEFAULT_ADMIN_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MAX_BATCH_SIZE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "TRIPLE_SALT";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "accumulatedAtomWalletDepositFees";
    readonly inputs: readonly [{
        readonly name: "atomWallet";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "accumulatedFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "accumulatedProtocolFees";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "accumulatedFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "approve";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "approvalType";
        readonly type: "uint8";
        readonly internalType: "enum ApprovalTypes";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "atom";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "data";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "atomConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "atomCreationProtocolFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "atomWalletDepositFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "atomDepositFractionAmount";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "bondingCurveConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "registry";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "defaultCurveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "calculateAtomId";
    readonly inputs: readonly [{
        readonly name: "data";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly outputs: readonly [{
        readonly name: "id";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "calculateCounterTripleId";
    readonly inputs: readonly [{
        readonly name: "subjectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "predicateId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "objectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "calculateTripleId";
    readonly inputs: readonly [{
        readonly name: "subjectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "predicateId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "objectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "claimAtomWalletDepositFees";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "computeAtomWalletAddr";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "convertToAssets";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "convertToShares";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "createAtoms";
    readonly inputs: readonly [{
        readonly name: "data";
        readonly type: "bytes[]";
        readonly internalType: "bytes[]";
    }, {
        readonly name: "assets";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "createTriples";
    readonly inputs: readonly [{
        readonly name: "subjectIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "predicateIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "objectIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "assets";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "currentEpoch";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "currentSharePrice";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "deposit";
    readonly inputs: readonly [{
        readonly name: "receiver";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "minShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "depositBatch";
    readonly inputs: readonly [{
        readonly name: "receiver";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "curveIds";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "assets";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "minShares";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "entryFeeAmount";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "exitFeeAmount";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "generalConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "admin";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "protocolMultisig";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "feeDenominator";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "trustBonding";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "minDeposit";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "minShare";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "atomDataMaxLength";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "feeThreshold";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAtom";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "data";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAtomConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct AtomConfig";
        readonly components: readonly [{
            readonly name: "atomCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomWalletDepositFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAtomCost";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAtomWarden";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getBondingCurveConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct BondingCurveConfig";
        readonly components: readonly [{
            readonly name: "registry";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "defaultCurveId";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCounterIdFromTripleId";
    readonly inputs: readonly [{
        readonly name: "tripleId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "getGeneralConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct GeneralConfig";
        readonly components: readonly [{
            readonly name: "admin";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "protocolMultisig";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "feeDenominator";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "trustBonding";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "minDeposit";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "minShare";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDataMaxLength";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "feeThreshold";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getInverseTripleId";
    readonly inputs: readonly [{
        readonly name: "tripleId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getRoleAdmin";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getShares";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTotalUtilizationForEpoch";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTriple";
    readonly inputs: readonly [{
        readonly name: "tripleId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTripleConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct TripleConfig";
        readonly components: readonly [{
            readonly name: "tripleCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDepositFractionForTriple";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTripleCost";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTripleIdFromCounterId";
    readonly inputs: readonly [{
        readonly name: "counterId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserLastActiveEpoch";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserUtilizationForEpoch";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserUtilizationInEpoch";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getVault";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getVaultFees";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct VaultFees";
        readonly components: readonly [{
            readonly name: "entryFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "exitFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "protocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getVaultType";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "enum VaultType";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getWalletConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct WalletConfig";
        readonly components: readonly [{
            readonly name: "entryPoint";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWarden";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletBeacon";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletFactory";
            readonly type: "address";
            readonly internalType: "address";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "grantRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "hasRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "hasRolledOverSystemUtilization";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "hasRolledOver";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "_generalConfig";
        readonly type: "tuple";
        readonly internalType: "struct GeneralConfig";
        readonly components: readonly [{
            readonly name: "admin";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "protocolMultisig";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "feeDenominator";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "trustBonding";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "minDeposit";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "minShare";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDataMaxLength";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "feeThreshold";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }, {
        readonly name: "_atomConfig";
        readonly type: "tuple";
        readonly internalType: "struct AtomConfig";
        readonly components: readonly [{
            readonly name: "atomCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomWalletDepositFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }, {
        readonly name: "_tripleConfig";
        readonly type: "tuple";
        readonly internalType: "struct TripleConfig";
        readonly components: readonly [{
            readonly name: "tripleCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDepositFractionForTriple";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }, {
        readonly name: "_walletConfig";
        readonly type: "tuple";
        readonly internalType: "struct WalletConfig";
        readonly components: readonly [{
            readonly name: "entryPoint";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWarden";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletBeacon";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletFactory";
            readonly type: "address";
            readonly internalType: "address";
        }];
    }, {
        readonly name: "_vaultFees";
        readonly type: "tuple";
        readonly internalType: "struct VaultFees";
        readonly components: readonly [{
            readonly name: "entryFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "exitFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "protocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }, {
        readonly name: "_bondingCurveConfig";
        readonly type: "tuple";
        readonly internalType: "struct BondingCurveConfig";
        readonly components: readonly [{
            readonly name: "registry";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "defaultCurveId";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "isAtom";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "isCounterTriple";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "isTermCreated";
    readonly inputs: readonly [{
        readonly name: "id";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "isTriple";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "maxRedeem";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "pause";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "paused";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "personalUtilization";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "utilizationAmount";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewAtomCreate";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFixedFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewDeposit";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewRedeem";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "sharesUsed";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewTripleCreate";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFixedFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "protocolFeeAmount";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "redeem";
    readonly inputs: readonly [{
        readonly name: "receiver";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "minAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "redeemBatch";
    readonly inputs: readonly [{
        readonly name: "receiver";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "curveIds";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "shares";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "minAssets";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly outputs: readonly [{
        readonly name: "received";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "renounceRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "callerConfirmation";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "revokeRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setAtomConfig";
    readonly inputs: readonly [{
        readonly name: "_atomConfig";
        readonly type: "tuple";
        readonly internalType: "struct AtomConfig";
        readonly components: readonly [{
            readonly name: "atomCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomWalletDepositFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setBondingCurveConfig";
    readonly inputs: readonly [{
        readonly name: "_bondingCurveConfig";
        readonly type: "tuple";
        readonly internalType: "struct BondingCurveConfig";
        readonly components: readonly [{
            readonly name: "registry";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "defaultCurveId";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setGeneralConfig";
    readonly inputs: readonly [{
        readonly name: "_generalConfig";
        readonly type: "tuple";
        readonly internalType: "struct GeneralConfig";
        readonly components: readonly [{
            readonly name: "admin";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "protocolMultisig";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "feeDenominator";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "trustBonding";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "minDeposit";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "minShare";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDataMaxLength";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "feeThreshold";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setTripleConfig";
    readonly inputs: readonly [{
        readonly name: "_tripleConfig";
        readonly type: "tuple";
        readonly internalType: "struct TripleConfig";
        readonly components: readonly [{
            readonly name: "tripleCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDepositFractionForTriple";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setVaultFees";
    readonly inputs: readonly [{
        readonly name: "_vaultFees";
        readonly type: "tuple";
        readonly internalType: "struct VaultFees";
        readonly components: readonly [{
            readonly name: "entryFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "exitFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "protocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setWalletConfig";
    readonly inputs: readonly [{
        readonly name: "_walletConfig";
        readonly type: "tuple";
        readonly internalType: "struct WalletConfig";
        readonly components: readonly [{
            readonly name: "entryPoint";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWarden";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletBeacon";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletFactory";
            readonly type: "address";
            readonly internalType: "address";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "supportsInterface";
    readonly inputs: readonly [{
        readonly name: "interfaceId";
        readonly type: "bytes4";
        readonly internalType: "bytes4";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "sweepAccumulatedProtocolFees";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "totalTermsCreated";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalUtilization";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "utilizationAmount";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "triple";
    readonly inputs: readonly [{
        readonly name: "tripleId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "tripleConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "tripleCreationProtocolFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "atomDepositFractionForTriple";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "unpause";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "userEpochHistory";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "vaultFees";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "entryFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "exitFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "protocolFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "walletConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "entryPoint";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "atomWarden";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "atomWalletBeacon";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "atomWalletFactory";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "event";
    readonly name: "ApprovalTypeUpdated";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "receiver";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "approvalType";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum ApprovalTypes";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "AtomConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "atomCreationProtocolFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "atomWalletDepositFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "AtomCreated";
    readonly inputs: readonly [{
        readonly name: "creator";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "atomData";
        readonly type: "bytes";
        readonly indexed: false;
        readonly internalType: "bytes";
    }, {
        readonly name: "atomWallet";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "AtomWalletDepositFeeCollected";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "AtomWalletDepositFeesClaimed";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "atomWalletOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "feesClaimed";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "BondingCurveConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "registry";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "defaultCurveId";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Deposited";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "receiver";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "vaultType";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum VaultType";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "GeneralConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "admin";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "protocolMultisig";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "feeDenominator";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "trustBonding";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "minDeposit";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "minShare";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "atomDataMaxLength";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "feeThreshold";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Paused";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "PersonalUtilizationAdded";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "valueAdded";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }, {
        readonly name: "personalUtilization";
        readonly type: "int256";
        readonly indexed: false;
        readonly internalType: "int256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "PersonalUtilizationRemoved";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "valueRemoved";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }, {
        readonly name: "personalUtilization";
        readonly type: "int256";
        readonly indexed: false;
        readonly internalType: "int256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "ProtocolFeeAccrued";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "ProtocolFeeTransferred";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "destination";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Redeemed";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "receiver";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "fees";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "vaultType";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum VaultType";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleAdminChanged";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "previousAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "newAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleGranted";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleRevoked";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "SharePriceChanged";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "sharePrice";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "vaultType";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum VaultType";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TotalUtilizationAdded";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "valueAdded";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }, {
        readonly name: "totalUtilization";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TotalUtilizationRemoved";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "valueRemoved";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }, {
        readonly name: "totalUtilization";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TripleConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "tripleCreationProtocolFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "atomDepositFractionForTriple";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TripleCreated";
    readonly inputs: readonly [{
        readonly name: "creator";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "subjectId";
        readonly type: "bytes32";
        readonly indexed: false;
        readonly internalType: "bytes32";
    }, {
        readonly name: "predicateId";
        readonly type: "bytes32";
        readonly indexed: false;
        readonly internalType: "bytes32";
    }, {
        readonly name: "objectId";
        readonly type: "bytes32";
        readonly indexed: false;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Unpaused";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "VaultFeesUpdated";
    readonly inputs: readonly [{
        readonly name: "entryFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "exitFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "protocolFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "WalletConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "entryPoint";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "atomWarden";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "atomWalletBeacon";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "atomWalletFactory";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "AccessControlBadConfirmation";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AccessControlUnauthorizedAccount";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "neededRole";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "EnforcedPause";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ExpectedPause";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "FailedCall";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientBalance";
    readonly inputs: readonly [{
        readonly name: "balance";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "needed";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVaultCore_AtomDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVaultCore_InvalidAdmin";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVaultCore_TermDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVaultCore_TripleDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_ActionExceedsMaxAssets";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_ActionExceedsMaxShares";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_ArraysNotSameLength";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_AtomDataTooLong";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_AtomDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_AtomExists";
    readonly inputs: readonly [{
        readonly name: "atomData";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_BurnFromZeroAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_BurnInsufficientBalance";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_CannotApproveOrRevokeSelf";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_CannotDirectlyInitializeCounterTriple";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_DefaultCurveMustBeInitializedViaCreatePaths";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_DepositBelowMinimumDeposit";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_DepositOrRedeemZeroShares";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_DepositTooSmallToCoverMinShares";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_EpochNotTracked";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_HasCounterStake";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InsufficientAssets";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InsufficientBalance";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InsufficientRemainingSharesInVault";
    readonly inputs: readonly [{
        readonly name: "remainingShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InsufficientSharesInVault";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InvalidArrayLength";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InvalidEpoch";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_NoAtomDataProvided";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_OnlyAssociatedAtomWallet";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_RedeemerNotApproved";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_SenderNotApproved";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_SlippageExceeded";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_TermDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_TermNotTriple";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_TripleExists";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "subjectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "predicateId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "objectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ReentrancyGuardReentrantCall";
    readonly inputs: readonly [];
}];

declare const MultiVaultMigrationModeAbi: readonly [{
    readonly type: "receive";
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "ATOM_SALT";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "BURN_ADDRESS";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "COUNTER_SALT";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "DEFAULT_ADMIN_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MAX_BATCH_SIZE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MIGRATOR_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "TRIPLE_SALT";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "accumulatedAtomWalletDepositFees";
    readonly inputs: readonly [{
        readonly name: "atomWallet";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "accumulatedFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "accumulatedProtocolFees";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "accumulatedFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "approve";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "approvalType";
        readonly type: "uint8";
        readonly internalType: "enum ApprovalTypes";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "atom";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "data";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "atomConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "atomCreationProtocolFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "atomWalletDepositFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "atomDepositFractionAmount";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "batchSetAtomData";
    readonly inputs: readonly [{
        readonly name: "creators";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "atomDataArray";
        readonly type: "bytes[]";
        readonly internalType: "bytes[]";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "batchSetTripleData";
    readonly inputs: readonly [{
        readonly name: "creators";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "tripleAtomIds";
        readonly type: "bytes32[3][]";
        readonly internalType: "bytes32[3][]";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "batchSetUserBalances";
    readonly inputs: readonly [{
        readonly name: "params";
        readonly type: "tuple";
        readonly internalType: "struct MultiVaultMigrationMode.BatchSetUserBalancesParams";
        readonly components: readonly [{
            readonly name: "termIds";
            readonly type: "bytes32[][]";
            readonly internalType: "bytes32[][]";
        }, {
            readonly name: "bondingCurveId";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "users";
            readonly type: "address[]";
            readonly internalType: "address[]";
        }, {
            readonly name: "userBalances";
            readonly type: "uint256[][]";
            readonly internalType: "uint256[][]";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "batchSetVaultTotals";
    readonly inputs: readonly [{
        readonly name: "termIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "bondingCurveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "vaultTotals";
        readonly type: "tuple[]";
        readonly internalType: "struct MultiVaultMigrationMode.VaultTotals[]";
        readonly components: readonly [{
            readonly name: "totalAssets";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "totalShares";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "bondingCurveConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "registry";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "defaultCurveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "calculateAtomId";
    readonly inputs: readonly [{
        readonly name: "data";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly outputs: readonly [{
        readonly name: "id";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "calculateCounterTripleId";
    readonly inputs: readonly [{
        readonly name: "subjectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "predicateId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "objectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "calculateTripleId";
    readonly inputs: readonly [{
        readonly name: "subjectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "predicateId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "objectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "claimAtomWalletDepositFees";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "computeAtomWalletAddr";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "convertToAssets";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "convertToShares";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "createAtoms";
    readonly inputs: readonly [{
        readonly name: "data";
        readonly type: "bytes[]";
        readonly internalType: "bytes[]";
    }, {
        readonly name: "assets";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "createTriples";
    readonly inputs: readonly [{
        readonly name: "subjectIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "predicateIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "objectIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "assets";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "currentEpoch";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "currentSharePrice";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "deposit";
    readonly inputs: readonly [{
        readonly name: "receiver";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "minShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "depositBatch";
    readonly inputs: readonly [{
        readonly name: "receiver";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "curveIds";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "assets";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "minShares";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "entryFeeAmount";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "exitFeeAmount";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "generalConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "admin";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "protocolMultisig";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "feeDenominator";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "trustBonding";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "minDeposit";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "minShare";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "atomDataMaxLength";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "feeThreshold";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAtom";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "data";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAtomConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct AtomConfig";
        readonly components: readonly [{
            readonly name: "atomCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomWalletDepositFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAtomCost";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getAtomWarden";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getBondingCurveConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct BondingCurveConfig";
        readonly components: readonly [{
            readonly name: "registry";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "defaultCurveId";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCounterIdFromTripleId";
    readonly inputs: readonly [{
        readonly name: "tripleId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "getGeneralConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct GeneralConfig";
        readonly components: readonly [{
            readonly name: "admin";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "protocolMultisig";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "feeDenominator";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "trustBonding";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "minDeposit";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "minShare";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDataMaxLength";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "feeThreshold";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getInverseTripleId";
    readonly inputs: readonly [{
        readonly name: "tripleId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getRoleAdmin";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getShares";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTotalUtilizationForEpoch";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTriple";
    readonly inputs: readonly [{
        readonly name: "tripleId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTripleConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct TripleConfig";
        readonly components: readonly [{
            readonly name: "tripleCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDepositFractionForTriple";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTripleCost";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTripleIdFromCounterId";
    readonly inputs: readonly [{
        readonly name: "counterId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserLastActiveEpoch";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserUtilizationForEpoch";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserUtilizationInEpoch";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getVault";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getVaultFees";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct VaultFees";
        readonly components: readonly [{
            readonly name: "entryFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "exitFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "protocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getVaultType";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "enum VaultType";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getWalletConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct WalletConfig";
        readonly components: readonly [{
            readonly name: "entryPoint";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWarden";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletBeacon";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletFactory";
            readonly type: "address";
            readonly internalType: "address";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "grantRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "hasRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "hasRolledOverSystemUtilization";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "hasRolledOver";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "_generalConfig";
        readonly type: "tuple";
        readonly internalType: "struct GeneralConfig";
        readonly components: readonly [{
            readonly name: "admin";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "protocolMultisig";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "feeDenominator";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "trustBonding";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "minDeposit";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "minShare";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDataMaxLength";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "feeThreshold";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }, {
        readonly name: "_atomConfig";
        readonly type: "tuple";
        readonly internalType: "struct AtomConfig";
        readonly components: readonly [{
            readonly name: "atomCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomWalletDepositFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }, {
        readonly name: "_tripleConfig";
        readonly type: "tuple";
        readonly internalType: "struct TripleConfig";
        readonly components: readonly [{
            readonly name: "tripleCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDepositFractionForTriple";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }, {
        readonly name: "_walletConfig";
        readonly type: "tuple";
        readonly internalType: "struct WalletConfig";
        readonly components: readonly [{
            readonly name: "entryPoint";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWarden";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletBeacon";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletFactory";
            readonly type: "address";
            readonly internalType: "address";
        }];
    }, {
        readonly name: "_vaultFees";
        readonly type: "tuple";
        readonly internalType: "struct VaultFees";
        readonly components: readonly [{
            readonly name: "entryFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "exitFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "protocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }, {
        readonly name: "_bondingCurveConfig";
        readonly type: "tuple";
        readonly internalType: "struct BondingCurveConfig";
        readonly components: readonly [{
            readonly name: "registry";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "defaultCurveId";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "isAtom";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "isCounterTriple";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "isTermCreated";
    readonly inputs: readonly [{
        readonly name: "id";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "isTriple";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "maxRedeem";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "pause";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "paused";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "personalUtilization";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "utilizationAmount";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewAtomCreate";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFixedFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewDeposit";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewRedeem";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "sharesUsed";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewTripleCreate";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFixedFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "protocolFeeAmount";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "redeem";
    readonly inputs: readonly [{
        readonly name: "receiver";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "minAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "redeemBatch";
    readonly inputs: readonly [{
        readonly name: "receiver";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "termIds";
        readonly type: "bytes32[]";
        readonly internalType: "bytes32[]";
    }, {
        readonly name: "curveIds";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "shares";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "minAssets";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly outputs: readonly [{
        readonly name: "received";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "renounceRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "callerConfirmation";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "revokeRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setAtomConfig";
    readonly inputs: readonly [{
        readonly name: "_atomConfig";
        readonly type: "tuple";
        readonly internalType: "struct AtomConfig";
        readonly components: readonly [{
            readonly name: "atomCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomWalletDepositFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setBondingCurveConfig";
    readonly inputs: readonly [{
        readonly name: "_bondingCurveConfig";
        readonly type: "tuple";
        readonly internalType: "struct BondingCurveConfig";
        readonly components: readonly [{
            readonly name: "registry";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "defaultCurveId";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setGeneralConfig";
    readonly inputs: readonly [{
        readonly name: "_generalConfig";
        readonly type: "tuple";
        readonly internalType: "struct GeneralConfig";
        readonly components: readonly [{
            readonly name: "admin";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "protocolMultisig";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "feeDenominator";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "trustBonding";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "minDeposit";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "minShare";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDataMaxLength";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "feeThreshold";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setTermCount";
    readonly inputs: readonly [{
        readonly name: "_termCount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setTripleConfig";
    readonly inputs: readonly [{
        readonly name: "_tripleConfig";
        readonly type: "tuple";
        readonly internalType: "struct TripleConfig";
        readonly components: readonly [{
            readonly name: "tripleCreationProtocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "atomDepositFractionForTriple";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setVaultFees";
    readonly inputs: readonly [{
        readonly name: "_vaultFees";
        readonly type: "tuple";
        readonly internalType: "struct VaultFees";
        readonly components: readonly [{
            readonly name: "entryFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "exitFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "protocolFee";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setWalletConfig";
    readonly inputs: readonly [{
        readonly name: "_walletConfig";
        readonly type: "tuple";
        readonly internalType: "struct WalletConfig";
        readonly components: readonly [{
            readonly name: "entryPoint";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWarden";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletBeacon";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "atomWalletFactory";
            readonly type: "address";
            readonly internalType: "address";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "supportsInterface";
    readonly inputs: readonly [{
        readonly name: "interfaceId";
        readonly type: "bytes4";
        readonly internalType: "bytes4";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "sweepAccumulatedProtocolFees";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "totalTermsCreated";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalUtilization";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "utilizationAmount";
        readonly type: "int256";
        readonly internalType: "int256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "triple";
    readonly inputs: readonly [{
        readonly name: "tripleId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "tripleConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "tripleCreationProtocolFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "atomDepositFractionForTriple";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "unpause";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "userEpochHistory";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "vaultFees";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "entryFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "exitFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "protocolFee";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "walletConfig";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "entryPoint";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "atomWarden";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "atomWalletBeacon";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "atomWalletFactory";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "event";
    readonly name: "ApprovalTypeUpdated";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "receiver";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "approvalType";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum ApprovalTypes";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "AtomConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "atomCreationProtocolFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "atomWalletDepositFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "AtomCreated";
    readonly inputs: readonly [{
        readonly name: "creator";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "atomData";
        readonly type: "bytes";
        readonly indexed: false;
        readonly internalType: "bytes";
    }, {
        readonly name: "atomWallet";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "AtomWalletDepositFeeCollected";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "AtomWalletDepositFeesClaimed";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "atomWalletOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "feesClaimed";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "BondingCurveConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "registry";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "defaultCurveId";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Deposited";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "receiver";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "assetsAfterFees";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "vaultType";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum VaultType";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "GeneralConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "admin";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "protocolMultisig";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "feeDenominator";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "trustBonding";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "minDeposit";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "minShare";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "atomDataMaxLength";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "feeThreshold";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Paused";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "PersonalUtilizationAdded";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "valueAdded";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }, {
        readonly name: "personalUtilization";
        readonly type: "int256";
        readonly indexed: false;
        readonly internalType: "int256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "PersonalUtilizationRemoved";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "valueRemoved";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }, {
        readonly name: "personalUtilization";
        readonly type: "int256";
        readonly indexed: false;
        readonly internalType: "int256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "ProtocolFeeAccrued";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "ProtocolFeeTransferred";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "destination";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Redeemed";
    readonly inputs: readonly [{
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "receiver";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "shares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "assets";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "fees";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "vaultType";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum VaultType";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleAdminChanged";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "previousAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "newAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleGranted";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleRevoked";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "SharePriceChanged";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "curveId";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "sharePrice";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "vaultType";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum VaultType";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TotalUtilizationAdded";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "valueAdded";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }, {
        readonly name: "totalUtilization";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TotalUtilizationRemoved";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "valueRemoved";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }, {
        readonly name: "totalUtilization";
        readonly type: "int256";
        readonly indexed: true;
        readonly internalType: "int256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TripleConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "tripleCreationProtocolFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "atomDepositFractionForTriple";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TripleCreated";
    readonly inputs: readonly [{
        readonly name: "creator";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "termId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "subjectId";
        readonly type: "bytes32";
        readonly indexed: false;
        readonly internalType: "bytes32";
    }, {
        readonly name: "predicateId";
        readonly type: "bytes32";
        readonly indexed: false;
        readonly internalType: "bytes32";
    }, {
        readonly name: "objectId";
        readonly type: "bytes32";
        readonly indexed: false;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Unpaused";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "VaultFeesUpdated";
    readonly inputs: readonly [{
        readonly name: "entryFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "exitFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "protocolFee";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "WalletConfigUpdated";
    readonly inputs: readonly [{
        readonly name: "entryPoint";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "atomWarden";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "atomWalletBeacon";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "atomWalletFactory";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "AccessControlBadConfirmation";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AccessControlUnauthorizedAccount";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "neededRole";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "EnforcedPause";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ExpectedPause";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "FailedCall";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientBalance";
    readonly inputs: readonly [{
        readonly name: "balance";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "needed";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVaultCore_AtomDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVaultCore_InvalidAdmin";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVaultCore_TermDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVaultCore_TripleDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_ActionExceedsMaxAssets";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_ActionExceedsMaxShares";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_ArraysNotSameLength";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_AtomDataTooLong";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_AtomDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_AtomExists";
    readonly inputs: readonly [{
        readonly name: "atomData";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_BurnFromZeroAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_BurnInsufficientBalance";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_CannotApproveOrRevokeSelf";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_CannotDirectlyInitializeCounterTriple";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_DefaultCurveMustBeInitializedViaCreatePaths";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_DepositBelowMinimumDeposit";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_DepositOrRedeemZeroShares";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_DepositTooSmallToCoverMinShares";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_EpochNotTracked";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_HasCounterStake";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InsufficientAssets";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InsufficientBalance";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InsufficientRemainingSharesInVault";
    readonly inputs: readonly [{
        readonly name: "remainingShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InsufficientSharesInVault";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InvalidArrayLength";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InvalidBondingCurveId";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_InvalidEpoch";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_NoAtomDataProvided";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_OnlyAssociatedAtomWallet";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_RedeemerNotApproved";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_SenderNotApproved";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_SlippageExceeded";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_TermDoesNotExist";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_TermNotTriple";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MultiVault_TripleExists";
    readonly inputs: readonly [{
        readonly name: "termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "subjectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "predicateId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "objectId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "MultiVault_ZeroAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ReentrancyGuardReentrantCall";
    readonly inputs: readonly [];
}];

declare const BaseEmissionsControllerAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "receive";
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "CONTROLLER_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "DEFAULT_ADMIN_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "GAS_CONSTANT";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "burn";
    readonly inputs: readonly [{
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "getBalance";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurrentEpoch";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurrentEpochEmissions";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurrentEpochTimestampStart";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEmissionsAtEpoch";
    readonly inputs: readonly [{
        readonly name: "epochNumber";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEmissionsAtTimestamp";
    readonly inputs: readonly [{
        readonly name: "timestamp";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochAtTimestamp";
    readonly inputs: readonly [{
        readonly name: "timestamp";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochLength";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochMintedAmount";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochTimestampEnd";
    readonly inputs: readonly [{
        readonly name: "epochNumber";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochTimestampStart";
    readonly inputs: readonly [{
        readonly name: "epochNumber";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getFinalityState";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "enum FinalityState";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getMessageGasCost";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getMetaERC20SpokeOrHub";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getRecipientDomain";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint32";
        readonly internalType: "uint32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getRoleAdmin";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getSatelliteEmissionsController";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getStartTimestamp";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTotalMinted";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTrustToken";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "grantRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "hasRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "admin";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "controller";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "token";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "metaERC20DispatchInit";
        readonly type: "tuple";
        readonly internalType: "struct MetaERC20DispatchInit";
        readonly components: readonly [{
            readonly name: "hubOrSpoke";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "recipientDomain";
            readonly type: "uint32";
            readonly internalType: "uint32";
        }, {
            readonly name: "gasLimit";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "finalityState";
            readonly type: "uint8";
            readonly internalType: "enum FinalityState";
        }];
    }, {
        readonly name: "checkpointInit";
        readonly type: "tuple";
        readonly internalType: "struct CoreEmissionsControllerInit";
        readonly components: readonly [{
            readonly name: "startTimestamp";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "emissionsLength";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "emissionsPerEpoch";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "emissionsReductionCliff";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "emissionsReductionBasisPoints";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "mintAndBridge";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "mintAndBridgeCurrentEpoch";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "quoteGasPayment";
    readonly inputs: readonly [{
        readonly name: "domain";
        readonly type: "uint32";
        readonly internalType: "uint32";
    }, {
        readonly name: "gasLimit";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "renounceRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "callerConfirmation";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "revokeRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setFinalityState";
    readonly inputs: readonly [{
        readonly name: "newFinalityState";
        readonly type: "uint8";
        readonly internalType: "enum FinalityState";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setMessageGasCost";
    readonly inputs: readonly [{
        readonly name: "newGasCost";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setMetaERC20SpokeOrHub";
    readonly inputs: readonly [{
        readonly name: "newMetaERC20SpokeOrHub";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setRecipientDomain";
    readonly inputs: readonly [{
        readonly name: "newRecipientDomain";
        readonly type: "uint32";
        readonly internalType: "uint32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setSatelliteEmissionsController";
    readonly inputs: readonly [{
        readonly name: "newSatellite";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setTrustToken";
    readonly inputs: readonly [{
        readonly name: "newToken";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "supportsInterface";
    readonly inputs: readonly [{
        readonly name: "interfaceId";
        readonly type: "bytes4";
        readonly internalType: "bytes4";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "withdraw";
    readonly inputs: readonly [{
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "FinalityStateUpdated";
    readonly inputs: readonly [{
        readonly name: "newFinalityState";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum FinalityState";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "startTimestamp";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "emissionsLength";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "emissionsPerEpoch";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "emissionsReductionCliff";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "emissionsReductionBasisPoints";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "MessageGasCostUpdated";
    readonly inputs: readonly [{
        readonly name: "newMessageGasCost";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "MetaERC20SpokeOrHubUpdated";
    readonly inputs: readonly [{
        readonly name: "newMetaERC20SpokeOrHub";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RecipientDomainUpdated";
    readonly inputs: readonly [{
        readonly name: "newRecipientDomain";
        readonly type: "uint32";
        readonly indexed: false;
        readonly internalType: "uint32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleAdminChanged";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "previousAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "newAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleGranted";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleRevoked";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "SatelliteEmissionsControllerUpdated";
    readonly inputs: readonly [{
        readonly name: "newSatelliteEmissionsController";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Transfer";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TrustBurned";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TrustMintedAndBridged";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TrustTokenUpdated";
    readonly inputs: readonly [{
        readonly name: "newTrustToken";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "AccessControlBadConfirmation";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AccessControlUnauthorizedAccount";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "neededRole";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "BaseEmissionsController_EpochMintingLimitExceeded";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseEmissionsController_InsufficientBurnableBalance";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseEmissionsController_InsufficientGasPayment";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseEmissionsController_InvalidAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseEmissionsController_InvalidEpoch";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseEmissionsController_SatelliteEmissionsControllerNotSet";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "CoreEmissionsController_InvalidCliff";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "CoreEmissionsController_InvalidEmissionsPerEpoch";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "CoreEmissionsController_InvalidReductionBasisPoints";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "CoreEmissionsController_InvalidTimestampStart";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "FailedCall";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientBalance";
    readonly inputs: readonly [{
        readonly name: "balance";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "needed";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MetaERC20Dispatcher_InvalidAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ReentrancyGuardReentrantCall";
    readonly inputs: readonly [];
}];

declare const SatelliteEmissionsControllerAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "receive";
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "CONTROLLER_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "DEFAULT_ADMIN_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "GAS_CONSTANT";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "OPERATOR_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "bridgeUnclaimedEmissions";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "getBaseEmissionsController";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurrentEpoch";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurrentEpochEmissions";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurrentEpochTimestampStart";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEmissionsAtEpoch";
    readonly inputs: readonly [{
        readonly name: "epochNumber";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEmissionsAtTimestamp";
    readonly inputs: readonly [{
        readonly name: "timestamp";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochAtTimestamp";
    readonly inputs: readonly [{
        readonly name: "timestamp";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochLength";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochTimestampEnd";
    readonly inputs: readonly [{
        readonly name: "epochNumber";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEpochTimestampStart";
    readonly inputs: readonly [{
        readonly name: "epochNumber";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getFinalityState";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "enum FinalityState";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getMessageGasCost";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getMetaERC20SpokeOrHub";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getRecipientDomain";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint32";
        readonly internalType: "uint32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getReclaimedEmissions";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getRoleAdmin";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getStartTimestamp";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getTrustBonding";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "grantRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "hasRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "admin";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "baseEmissionsController";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "metaERC20DispatchInit";
        readonly type: "tuple";
        readonly internalType: "struct MetaERC20DispatchInit";
        readonly components: readonly [{
            readonly name: "hubOrSpoke";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "recipientDomain";
            readonly type: "uint32";
            readonly internalType: "uint32";
        }, {
            readonly name: "gasLimit";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "finalityState";
            readonly type: "uint8";
            readonly internalType: "enum FinalityState";
        }];
    }, {
        readonly name: "checkpointInit";
        readonly type: "tuple";
        readonly internalType: "struct CoreEmissionsControllerInit";
        readonly components: readonly [{
            readonly name: "startTimestamp";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "emissionsLength";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "emissionsPerEpoch";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "emissionsReductionCliff";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "emissionsReductionBasisPoints";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "quoteGasPayment";
    readonly inputs: readonly [{
        readonly name: "domain";
        readonly type: "uint32";
        readonly internalType: "uint32";
    }, {
        readonly name: "gasLimit";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "renounceRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "callerConfirmation";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "revokeRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setBaseEmissionsController";
    readonly inputs: readonly [{
        readonly name: "newBaseEmissionsController";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setFinalityState";
    readonly inputs: readonly [{
        readonly name: "newFinalityState";
        readonly type: "uint8";
        readonly internalType: "enum FinalityState";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setMessageGasCost";
    readonly inputs: readonly [{
        readonly name: "newGasCost";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setMetaERC20SpokeOrHub";
    readonly inputs: readonly [{
        readonly name: "newMetaERC20SpokeOrHub";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setRecipientDomain";
    readonly inputs: readonly [{
        readonly name: "newRecipientDomain";
        readonly type: "uint32";
        readonly internalType: "uint32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setTrustBonding";
    readonly inputs: readonly [{
        readonly name: "newTrustBonding";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "supportsInterface";
    readonly inputs: readonly [{
        readonly name: "interfaceId";
        readonly type: "bytes4";
        readonly internalType: "bytes4";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "transfer";
    readonly inputs: readonly [{
        readonly name: "recipient";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "withdrawUnclaimedEmissions";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "recipient";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "BaseEmissionsControllerUpdated";
    readonly inputs: readonly [{
        readonly name: "newBaseEmissionsController";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "FinalityStateUpdated";
    readonly inputs: readonly [{
        readonly name: "newFinalityState";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum FinalityState";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "startTimestamp";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "emissionsLength";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "emissionsPerEpoch";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "emissionsReductionCliff";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "emissionsReductionBasisPoints";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "MessageGasCostUpdated";
    readonly inputs: readonly [{
        readonly name: "newMessageGasCost";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "MetaERC20SpokeOrHubUpdated";
    readonly inputs: readonly [{
        readonly name: "newMetaERC20SpokeOrHub";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "NativeTokenTransferred";
    readonly inputs: readonly [{
        readonly name: "recipient";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RecipientDomainUpdated";
    readonly inputs: readonly [{
        readonly name: "newRecipientDomain";
        readonly type: "uint32";
        readonly indexed: false;
        readonly internalType: "uint32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleAdminChanged";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "previousAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "newAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleGranted";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleRevoked";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TrustBondingUpdated";
    readonly inputs: readonly [{
        readonly name: "newTrustBonding";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "UnclaimedEmissionsBridged";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "UnclaimedEmissionsWithdrawn";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "recipient";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "AccessControlBadConfirmation";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AccessControlUnauthorizedAccount";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "neededRole";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "CoreEmissionsController_InvalidCliff";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "CoreEmissionsController_InvalidEmissionsPerEpoch";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "CoreEmissionsController_InvalidReductionBasisPoints";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "CoreEmissionsController_InvalidTimestampStart";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "FailedCall";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientBalance";
    readonly inputs: readonly [{
        readonly name: "balance";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "needed";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "MetaERC20Dispatcher_InvalidAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ReentrancyGuardReentrantCall";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SatelliteEmissionsController_InsufficientBalance";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SatelliteEmissionsController_InsufficientGasPayment";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SatelliteEmissionsController_InvalidAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SatelliteEmissionsController_InvalidAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SatelliteEmissionsController_InvalidBridgeAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SatelliteEmissionsController_InvalidWithdrawAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SatelliteEmissionsController_TrustBondingNotSet";
    readonly inputs: readonly [];
}];

declare const TrustBondingAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "BASIS_POINTS_DIVISOR";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "DEFAULT_ADMIN_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MAXTIME";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINTIME";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "PAUSER_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "YEAR";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "add_to_whitelist";
    readonly inputs: readonly [{
        readonly name: "addr";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "balanceOf";
    readonly inputs: readonly [{
        readonly name: "addr";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "balanceOfAt";
    readonly inputs: readonly [{
        readonly name: "addr";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_block";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "balanceOfAtT";
    readonly inputs: readonly [{
        readonly name: "addr";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_t";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "changeController";
    readonly inputs: readonly [{
        readonly name: "_newController";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "checkpoint";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "claimRewards";
    readonly inputs: readonly [{
        readonly name: "recipient";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "contracts_whitelist";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "controller";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "create_lock";
    readonly inputs: readonly [{
        readonly name: "_value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_unlock_time";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "currentEpoch";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "decimals";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "uint8";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "deposit_for";
    readonly inputs: readonly [{
        readonly name: "_addr";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "emissionsForEpoch";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "epoch";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "epochAtTimestamp";
    readonly inputs: readonly [{
        readonly name: "timestamp";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "epochLength";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "epochTimestampEnd";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "epochsPerYear";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getPersonalUtilizationRatio";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getRoleAdmin";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getSystemApy";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "currentApy";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "maxApy";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getSystemUtilizationRatio";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUnclaimedRewardsForEpoch";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserApy";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "currentApy";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "maxApy";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserCurrentClaimableRewards";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserInfo";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct UserInfo";
        readonly components: readonly [{
            readonly name: "personalUtilization";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "eligibleRewards";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "maxRewards";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "lockedAmount";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "lockEnd";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "bondedBalance";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getUserRewardsForEpoch";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "get_last_user_slope";
    readonly inputs: readonly [{
        readonly name: "addr";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "int128";
        readonly internalType: "int128";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "grantRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "hasClaimedRewardsForEpoch";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "hasRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "increase_amount";
    readonly inputs: readonly [{
        readonly name: "_value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "increase_amount_and_time";
    readonly inputs: readonly [{
        readonly name: "_value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_unlock_time";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "increase_unlock_time";
    readonly inputs: readonly [{
        readonly name: "_unlock_time";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "_owner";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_timelock";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_trustToken";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_epochLength";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_satelliteEmissionsController";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_systemUtilizationLowerBound";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_personalUtilizationLowerBound";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "locked";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "amount";
        readonly type: "int128";
        readonly internalType: "int128";
    }, {
        readonly name: "end";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "locked__end";
    readonly inputs: readonly [{
        readonly name: "_addr";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "multiVault";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "name";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "pause";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "paused";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "personalUtilizationLowerBound";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "point_history";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "bias";
        readonly type: "int128";
        readonly internalType: "int128";
    }, {
        readonly name: "slope";
        readonly type: "int128";
        readonly internalType: "int128";
    }, {
        readonly name: "ts";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "blk";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previousEpoch";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "remove_from_whitelist";
    readonly inputs: readonly [{
        readonly name: "addr";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "renounceRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "callerConfirmation";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "revokeRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "satelliteEmissionsController";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "setMultiVault";
    readonly inputs: readonly [{
        readonly name: "_multiVault";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setTimelock";
    readonly inputs: readonly [{
        readonly name: "_timelock";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "slope_changes";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "int128";
        readonly internalType: "int128";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "supply";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "supportsInterface";
    readonly inputs: readonly [{
        readonly name: "interfaceId";
        readonly type: "bytes4";
        readonly internalType: "bytes4";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "symbol";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "systemUtilizationLowerBound";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "timelock";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "token";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalBondedBalance";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalBondedBalanceAtEpochEnd";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalClaimedRewardsForEpoch";
    readonly inputs: readonly [{
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "totalClaimedRewards";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalLocked";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalSupply";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalSupplyAt";
    readonly inputs: readonly [{
        readonly name: "_block";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalSupplyAtT";
    readonly inputs: readonly [{
        readonly name: "t";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "transfersEnabled";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "unlock";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "unlocked";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "unpause";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "updatePersonalUtilizationLowerBound";
    readonly inputs: readonly [{
        readonly name: "newLowerBound";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "updateSatelliteEmissionsController";
    readonly inputs: readonly [{
        readonly name: "_satelliteEmissionsController";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "updateSystemUtilizationLowerBound";
    readonly inputs: readonly [{
        readonly name: "newLowerBound";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "userBondedBalanceAtEpochEnd";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "userClaimedRewardsForEpoch";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "claimedRewards";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "userEligibleRewardsForEpoch";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "epoch";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "user_point_epoch";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "user_point_history";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "bias";
        readonly type: "int128";
        readonly internalType: "int128";
    }, {
        readonly name: "slope";
        readonly type: "int128";
        readonly internalType: "int128";
    }, {
        readonly name: "ts";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "blk";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "user_point_history__ts";
    readonly inputs: readonly [{
        readonly name: "_addr";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_idx";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "version";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "withdraw";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "withdraw_and_create_lock";
    readonly inputs: readonly [{
        readonly name: "_value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "_unlock_time";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "Deposit";
    readonly inputs: readonly [{
        readonly name: "provider";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "locktime";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "deposit_type";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum VotingEscrow.DepositType";
    }, {
        readonly name: "ts";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "MinTimeSet";
    readonly inputs: readonly [{
        readonly name: "min_time";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "MultiVaultSet";
    readonly inputs: readonly [{
        readonly name: "multiVault";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Paused";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "PersonalUtilizationLowerBoundUpdated";
    readonly inputs: readonly [{
        readonly name: "newLowerBound";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RewardsClaimed";
    readonly inputs: readonly [{
        readonly name: "user";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "recipient";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleAdminChanged";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "previousAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "newAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleGranted";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleRevoked";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "SatelliteEmissionsControllerSet";
    readonly inputs: readonly [{
        readonly name: "satelliteEmissionsController";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Supply";
    readonly inputs: readonly [{
        readonly name: "prevSupply";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "supply";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "SystemUtilizationLowerBoundUpdated";
    readonly inputs: readonly [{
        readonly name: "newLowerBound";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TimelockSet";
    readonly inputs: readonly [{
        readonly name: "timelock";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "TokenSet";
    readonly inputs: readonly [{
        readonly name: "token";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Unpaused";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Withdraw";
    readonly inputs: readonly [{
        readonly name: "provider";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }, {
        readonly name: "ts";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "AccessControlBadConfirmation";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AccessControlUnauthorizedAccount";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "neededRole";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "EnforcedPause";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ExpectedPause";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ReentrancyGuardReentrantCall";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SafeERC20FailedOperation";
    readonly inputs: readonly [{
        readonly name: "token";
        readonly type: "address";
        readonly internalType: "address";
    }];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_ClaimableProtocolFeesExceedBalance";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_EpochBudgetExhausted";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_InvalidEpoch";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_InvalidStartTimestamp";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_InvalidUtilizationLowerBound";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_NoClaimingDuringFirstEpoch";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_NoRewardsToClaim";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_OnlyTimelock";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_RewardsAlreadyClaimedForEpoch";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "TrustBonding_ZeroAddress";
    readonly inputs: readonly [];
}];

declare const BondingCurveRegistryAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "acceptOwnership";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "addBondingCurve";
    readonly inputs: readonly [{
        readonly name: "bondingCurve";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "convertToAssets";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "convertToShares";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "count";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "currentPrice";
    readonly inputs: readonly [{
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "sharePrice";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "curveAddresses";
    readonly inputs: readonly [{
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "curveAddress";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "curveIds";
    readonly inputs: readonly [{
        readonly name: "curveAddress";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "curveId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurveMaxAssets";
    readonly inputs: readonly [{
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "maxAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurveMaxShares";
    readonly inputs: readonly [{
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "maxShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getCurveName";
    readonly inputs: readonly [{
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "name";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "_admin";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "isCurveIdValid";
    readonly inputs: readonly [{
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "valid";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "owner";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "pendingOwner";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewDeposit";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewMint";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewRedeem";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewWithdraw";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "id";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "registeredCurveNames";
    readonly inputs: readonly [{
        readonly name: "curveName";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly outputs: readonly [{
        readonly name: "registered";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "renounceOwnership";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "transferOwnership";
    readonly inputs: readonly [{
        readonly name: "newOwner";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "BondingCurveAdded";
    readonly inputs: readonly [{
        readonly name: "curveId";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "curveAddress";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "curveName";
        readonly type: "string";
        readonly indexed: true;
        readonly internalType: "string";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "OwnershipTransferStarted";
    readonly inputs: readonly [{
        readonly name: "previousOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "newOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "OwnershipTransferred";
    readonly inputs: readonly [{
        readonly name: "previousOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "newOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "BondingCurveRegistry_CurveAlreadyExists";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BondingCurveRegistry_CurveNameNotUnique";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BondingCurveRegistry_EmptyCurveName";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BondingCurveRegistry_InvalidCurveId";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BondingCurveRegistry_ZeroAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "OwnableInvalidOwner";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly internalType: "address";
    }];
}, {
    readonly type: "error";
    readonly name: "OwnableUnauthorizedAccount";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
}];

declare const LinearCurveAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "MAX_ASSETS";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MAX_SHARES";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "ONE_SHARE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "convertToAssets";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "convertToShares";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "currentPrice";
    readonly inputs: readonly [{
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "sharePrice";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "_name";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "maxAssets";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "maxShares";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "name";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewDeposit";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "previewMint";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "previewRedeem";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "function";
    readonly name: "previewWithdraw";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "pure";
}, {
    readonly type: "event";
    readonly name: "CurveNameSet";
    readonly inputs: readonly [{
        readonly name: "name";
        readonly type: "string";
        readonly indexed: false;
        readonly internalType: "string";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "BaseCurve_AssetsExceedTotalAssets";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_AssetsOverflowMax";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_DomainExceeded";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_EmptyStringNotAllowed";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_SharesExceedTotalShares";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_SharesOverflowMax";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}];

declare const OffsetProgressiveCurveAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "HALF_SLOPE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "UD60x18";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MAX_ASSETS";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MAX_SHARES";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "OFFSET";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "UD60x18";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "SLOPE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "UD60x18";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "convertToAssets";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "convertToShares";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "currentPrice";
    readonly inputs: readonly [{
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "sharePrice";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "_name";
        readonly type: "string";
        readonly internalType: "string";
    }, {
        readonly name: "slope18";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "offset18";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "maxAssets";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "maxShares";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "name";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewDeposit";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewMint";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewRedeem";
    readonly inputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "previewWithdraw";
    readonly inputs: readonly [{
        readonly name: "assets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalAssets";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "totalShares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "shares";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "event";
    readonly name: "CurveNameSet";
    readonly inputs: readonly [{
        readonly name: "name";
        readonly type: "string";
        readonly indexed: false;
        readonly internalType: "string";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "BaseCurve_AssetsExceedTotalAssets";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_AssetsOverflowMax";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_DomainExceeded";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_EmptyStringNotAllowed";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_SharesExceedTotalShares";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "BaseCurve_SharesOverflowMax";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "OffsetProgressiveCurve_InvalidSlope";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "PRBMath_MulDiv18_Overflow";
    readonly inputs: readonly [{
        readonly name: "x";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "y";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
}, {
    readonly type: "error";
    readonly name: "PRBMath_MulDiv_Overflow";
    readonly inputs: readonly [{
        readonly name: "x";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "y";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "denominator";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
}, {
    readonly type: "error";
    readonly name: "PRBMath_UD60x18_Sqrt_Overflow";
    readonly inputs: readonly [{
        readonly name: "x";
        readonly type: "uint256";
        readonly internalType: "UD60x18";
    }];
}];

declare const AtomWalletAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "receive";
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "acceptOwnership";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "addDeposit";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "claimAtomWalletDepositFees";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "entryPoint";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "contract IEntryPoint";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "execute";
    readonly inputs: readonly [{
        readonly name: "dest";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "data";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "executeBatch";
    readonly inputs: readonly [{
        readonly name: "calls";
        readonly type: "tuple[]";
        readonly internalType: "struct BaseAccount.Call[]";
        readonly components: readonly [{
            readonly name: "target";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "value";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "data";
            readonly type: "bytes";
            readonly internalType: "bytes";
        }];
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "executeBatch";
    readonly inputs: readonly [{
        readonly name: "dest";
        readonly type: "address[]";
        readonly internalType: "address[]";
    }, {
        readonly name: "values";
        readonly type: "uint256[]";
        readonly internalType: "uint256[]";
    }, {
        readonly name: "data";
        readonly type: "bytes[]";
        readonly internalType: "bytes[]";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "getDeposit";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getNonce";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "anEntryPoint";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_multiVault";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_termId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "isClaimed";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "multiVault";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "contract IMultiVault";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "owner";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "pendingOwner";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "renounceOwnership";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "termId";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "transferOwnership";
    readonly inputs: readonly [{
        readonly name: "newOwner";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "validateUserOp";
    readonly inputs: readonly [{
        readonly name: "userOp";
        readonly type: "tuple";
        readonly internalType: "struct PackedUserOperation";
        readonly components: readonly [{
            readonly name: "sender";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "nonce";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "initCode";
            readonly type: "bytes";
            readonly internalType: "bytes";
        }, {
            readonly name: "callData";
            readonly type: "bytes";
            readonly internalType: "bytes";
        }, {
            readonly name: "accountGasLimits";
            readonly type: "bytes32";
            readonly internalType: "bytes32";
        }, {
            readonly name: "preVerificationGas";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "gasFees";
            readonly type: "bytes32";
            readonly internalType: "bytes32";
        }, {
            readonly name: "paymasterAndData";
            readonly type: "bytes";
            readonly internalType: "bytes";
        }, {
            readonly name: "signature";
            readonly type: "bytes";
            readonly internalType: "bytes";
        }];
    }, {
        readonly name: "userOpHash";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "missingAccountFunds";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "validationData";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "withdrawDepositTo";
    readonly inputs: readonly [{
        readonly name: "withdrawAddress";
        readonly type: "address";
        readonly internalType: "address payable";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "OwnershipTransferStarted";
    readonly inputs: readonly [{
        readonly name: "previousOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "newOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "OwnershipTransferred";
    readonly inputs: readonly [{
        readonly name: "previousOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "newOwner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "AtomWallet_OnlyOwner";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AtomWallet_OnlyOwnerOrEntryPoint";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AtomWallet_WrongArrayLengths";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AtomWallet_ZeroAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ExecuteError";
    readonly inputs: readonly [{
        readonly name: "index";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "error";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "OwnableInvalidOwner";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly internalType: "address";
    }];
}, {
    readonly type: "error";
    readonly name: "OwnableUnauthorizedAccount";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
}, {
    readonly type: "error";
    readonly name: "ReentrancyGuardReentrantCall";
    readonly inputs: readonly [];
}];

declare const AtomWalletFactoryAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "computeAtomWalletAddr";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "deployAtomWallet";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "initialize";
    readonly inputs: readonly [{
        readonly name: "_multiVault";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "multiVault";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "event";
    readonly name: "AtomWalletDeployed";
    readonly inputs: readonly [{
        readonly name: "atomId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "atomWallet";
        readonly type: "address";
        readonly indexed: false;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint64";
        readonly indexed: false;
        readonly internalType: "uint64";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "AtomWalletFactory_DeployAtomWalletFailed";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AtomWalletFactory_TermDoesNotExist";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AtomWalletFactory_TermNotAtom";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "AtomWalletFactory_ZeroAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidInitialization";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotInitializing";
    readonly inputs: readonly [];
}];

declare const TrustAbi: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "DEFAULT_ADMIN_ROLE";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MAX_SUPPLY";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINTER_A";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINTER_B";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "allowance";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "approve";
    readonly inputs: readonly [{
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "balanceOf";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "baseEmissionsController";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "burn";
    readonly inputs: readonly [{
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "decimals";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "uint8";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "decreaseAllowance";
    readonly inputs: readonly [{
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "subtractedValue";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "getRoleAdmin";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "grantRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "hasRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "increaseAllowance";
    readonly inputs: readonly [{
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "addedValue";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "init";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "mint";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "minterAmountMinted";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "name";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "reinitialize";
    readonly inputs: readonly [{
        readonly name: "_admin";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "_baseEmissionsController";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "renounceRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "revokeRole";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setBaseEmissionsController";
    readonly inputs: readonly [{
        readonly name: "newBaseEmissionsController";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "supportsInterface";
    readonly inputs: readonly [{
        readonly name: "interfaceId";
        readonly type: "bytes4";
        readonly internalType: "bytes4";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "symbol";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalMinted";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalSupply";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "transfer";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "transferFrom";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "Approval";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "spender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "BaseEmissionsControllerSet";
    readonly inputs: readonly [{
        readonly name: "newBaseEmissionsController";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "uint8";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleAdminChanged";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "previousAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "newAdminRole";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleGranted";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "RoleRevoked";
    readonly inputs: readonly [{
        readonly name: "role";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "account";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "sender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Transfer";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "ExceedsMinterCap";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ExceedsTotalSupply";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotAllowedToMint";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "Trust_OnlyBaseEmissionsController";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "Trust_ZeroAddress";
    readonly inputs: readonly [];
}];

declare const TrustTokenAbi: readonly [{
    readonly type: "function";
    readonly name: "MAX_SUPPLY";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINTER_A";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "MINTER_B";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "allowance";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "approve";
    readonly inputs: readonly [{
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "balanceOf";
    readonly inputs: readonly [{
        readonly name: "account";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "decimals";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint8";
        readonly internalType: "uint8";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "decreaseAllowance";
    readonly inputs: readonly [{
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "subtractedValue";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "increaseAllowance";
    readonly inputs: readonly [{
        readonly name: "spender";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "addedValue";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "init";
    readonly inputs: readonly [];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "mint";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "minterAmountMinted";
    readonly inputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "name";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "symbol";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalMinted";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "totalSupply";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "transfer";
    readonly inputs: readonly [{
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "transferFrom";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "Approval";
    readonly inputs: readonly [{
        readonly name: "owner";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "spender";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Initialized";
    readonly inputs: readonly [{
        readonly name: "version";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "uint8";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "Transfer";
    readonly inputs: readonly [{
        readonly name: "from";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "to";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "value";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "ExceedsMinterCap";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ExceedsTotalSupply";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "NotAllowedToMint";
    readonly inputs: readonly [];
}];

export { AtomWalletAbi, AtomWalletFactoryAbi, BaseEmissionsControllerAbi, BondingCurveRegistryAbi, LinearCurveAbi, MultiVaultAbi, MultiVaultMigrationModeAbi, OffsetProgressiveCurveAbi, SatelliteEmissionsControllerAbi, TrustAbi, TrustBondingAbi, TrustTokenAbi };
