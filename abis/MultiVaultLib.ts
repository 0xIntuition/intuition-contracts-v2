export const MultiVaultLibAbi = [
  {
    "type": "function",
    "name": "calculateAtomCreate",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "feeBaseAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "assetsAfterFees",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "calculateDeposit",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "isAtomVault",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "feeBaseAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "assetsAfterFees",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "calculateRedeem",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assetsAfterFees",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "sharesUsed",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "calculateTripleCreate",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "feeBaseAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "assetsAfterFees",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "computeAtomWalletAddr",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "convertToAssets",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "convertToShares",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "currentEpoch",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "currentSharePrice",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserUtilizationInEpoch",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "int256",
        "internalType": "int256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isApprovedToCreate",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isApprovedToDeposit",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isApprovedToRedeem",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isTermCreated",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "maxRedeem",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "validateRedeem",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "minAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "AtomContextRegistered",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "registrant",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "uris",
        "type": "bytes[]",
        "indexed": false,
        "internalType": "bytes[]"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomCreated",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "atomData",
        "type": "bytes",
        "indexed": false,
        "internalType": "bytes"
      },
      {
        "name": "atomWallet",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomWalletDepositFeeCollected",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "feeAmount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Deposited",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "receiver",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "assets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "assetsAfterFees",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "shares",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "receiverSharesAfter",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "vaultType",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum VaultType"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PersonalUtilizationAdded",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "valueAdded",
        "type": "int256",
        "indexed": true,
        "internalType": "int256"
      },
      {
        "name": "personalUtilization",
        "type": "int256",
        "indexed": false,
        "internalType": "int256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PersonalUtilizationRemoved",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "valueRemoved",
        "type": "int256",
        "indexed": true,
        "internalType": "int256"
      },
      {
        "name": "personalUtilization",
        "type": "int256",
        "indexed": false,
        "internalType": "int256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProtocolFeeAccrued",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "feeAmount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Redeemed",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "shares",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "accountSharesAfter",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "assetsAfterFees",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalFees",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "vaultType",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum VaultType"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "SharePriceChanged",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "curveId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "sharePrice",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "vaultType",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum VaultType"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TotalUtilizationAdded",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "valueAdded",
        "type": "int256",
        "indexed": true,
        "internalType": "int256"
      },
      {
        "name": "totalUtilization",
        "type": "int256",
        "indexed": true,
        "internalType": "int256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TotalUtilizationRemoved",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "valueRemoved",
        "type": "int256",
        "indexed": true,
        "internalType": "int256"
      },
      {
        "name": "totalUtilization",
        "type": "int256",
        "indexed": true,
        "internalType": "int256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TripleCreated",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "subjectId",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "predicateId",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "objectId",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "FailedCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InsufficientBalance",
    "inputs": [
      {
        "name": "balance",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "needed",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "MultiVaultCore_TermDoesNotExist",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "MultiVaultCore_TripleDoesNotExist",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "MultiVault_ActionExceedsMaxAssets",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_ActionExceedsMaxShares",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_ArraysNotSameLength",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_AtomDataTooLong",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_AtomExists",
    "inputs": [
      {
        "name": "atomData",
        "type": "bytes",
        "internalType": "bytes"
      }
    ]
  },
  {
    "type": "error",
    "name": "MultiVault_AtomUriCountExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_AtomUriLengthExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_BurnFromZeroAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_BurnInsufficientBalance",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_CannotDirectlyInitializeCounterTriple",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_CreatorNotApproved",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_DefaultCurveMustBeInitializedViaCreatePaths",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_DepositBelowMinimumDeposit",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_DepositOrRedeemZeroShares",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_DepositTooSmallToCoverMinShares",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_EpochNotTracked",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_HasCounterStake",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_InsufficientAssets",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_InsufficientBalance",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_InsufficientRemainingSharesInVault",
    "inputs": [
      {
        "name": "remainingShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "MultiVault_InsufficientSharesInVault",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_InvalidArrayLength",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_InvalidEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_NoAtomDataProvided",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_RedeemYieldsNoAssets",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_RedeemerNotApproved",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_SenderNotApproved",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_SlippageExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_TermDoesNotExist",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "MultiVault_TermNotTriple",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_TripleExists",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "subjectId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "predicateId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "objectId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  }
] as const;
