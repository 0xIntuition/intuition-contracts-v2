"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// index.ts
var index_exports = {};
__export(index_exports, {
  AtomWalletAbi: () => AtomWalletAbi,
  AtomWalletBytecode: () => AtomWalletBytecode,
  AtomWalletFactoryAbi: () => AtomWalletFactoryAbi,
  AtomWalletFactoryBytecode: () => AtomWalletFactoryBytecode,
  AtomWardenAbi: () => AtomWardenAbi,
  AtomWardenBytecode: () => AtomWardenBytecode,
  BaseEmissionsControllerAbi: () => BaseEmissionsControllerAbi,
  BaseEmissionsControllerBytecode: () => BaseEmissionsControllerBytecode,
  BondingCurveRegistryAbi: () => BondingCurveRegistryAbi,
  BondingCurveRegistryBytecode: () => BondingCurveRegistryBytecode,
  DynamicFeeFlatPriceCurveAbi: () => DynamicFeeFlatPriceCurveAbi,
  DynamicFeeFlatPriceCurveBytecode: () => DynamicFeeFlatPriceCurveBytecode,
  FeeProxyAbi: () => FeeProxyAbi,
  FeeProxyBytecode: () => FeeProxyBytecode,
  LinearCurveAbi: () => LinearCurveAbi,
  LinearCurveBytecode: () => LinearCurveBytecode,
  MultiVaultAbi: () => MultiVaultAbi,
  MultiVaultBytecode: () => MultiVaultBytecode,
  MultiVaultLibAbi: () => MultiVaultLibAbi,
  MultiVaultLibBytecode: () => MultiVaultLibBytecode,
  MultiVaultLinkReferences: () => MultiVaultLinkReferences,
  MultiVaultMigrationModeAbi: () => MultiVaultMigrationModeAbi,
  MultiVaultMigrationModeBytecode: () => MultiVaultMigrationModeBytecode,
  MultiVaultMigrationModeLinkReferences: () => MultiVaultMigrationModeLinkReferences,
  OffsetProgressiveCurveAbi: () => OffsetProgressiveCurveAbi,
  OffsetProgressiveCurveBytecode: () => OffsetProgressiveCurveBytecode,
  SatelliteEmissionsControllerAbi: () => SatelliteEmissionsControllerAbi,
  SatelliteEmissionsControllerBytecode: () => SatelliteEmissionsControllerBytecode,
  TrustAbi: () => TrustAbi,
  TrustBondingAbi: () => TrustBondingAbi,
  TrustBondingBytecode: () => TrustBondingBytecode,
  TrustBytecode: () => TrustBytecode,
  TrustTokenAbi: () => TrustTokenAbi,
  TrustTokenBytecode: () => TrustTokenBytecode,
  WrappedTrustAbi: () => WrappedTrustAbi,
  WrappedTrustBytecode: () => WrappedTrustBytecode
});
module.exports = __toCommonJS(index_exports);

// abis/MultiVault.ts
var MultiVaultAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "ATOM_SALT",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "BURN_ADDRESS",
    "inputs": [],
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
    "name": "COUNTER_SALT",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MAX_BATCH_SIZE",
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
    "name": "PAUSER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "TRIPLE_SALT",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "accumulatedAtomWalletDepositFees",
    "inputs": [
      {
        "name": "atomWallet",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "accumulatedFees",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "accumulatedProtocolFees",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "accumulatedFees",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "approve",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "approvalType",
        "type": "uint8",
        "internalType": "enum ApprovalTypes"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "atom",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "atomConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "atomCreationProtocolFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "atomWalletDepositFee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "atomCreatedAt",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "createdAt",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "atomCreators",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "atomDepositFractionAmount",
    "inputs": [
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
    "name": "bondingCurveConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "registry",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "defaultCurveId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "calculateAtomId",
    "inputs": [
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "id",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "calculateCounterTripleId",
    "inputs": [
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
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "calculateTripleId",
    "inputs": [
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
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "claimAtomWalletDepositFees",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
    "name": "createAtoms",
    "inputs": [
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createAtomsFor",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createAtomsWithUris",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "uris",
        "type": "bytes[][]",
        "internalType": "bytes[][]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTriples",
    "inputs": [
      {
        "name": "subjectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "predicateIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "objectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTriplesFor",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "subjectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "predicateIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "objectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
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
    "name": "deposit",
    "inputs": [
      {
        "name": "receiver",
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
      },
      {
        "name": "minShares",
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
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "depositBatch",
    "inputs": [
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "curveIds",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "minShares",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "entryFeeAmount",
    "inputs": [
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
    "name": "exitFeeAmount",
    "inputs": [
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
    "name": "generalConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "admin",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "protocolMultisig",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "feeDenominator",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "trustBonding",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "minDeposit",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "minShare",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "atomDataMaxLength",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "feeThreshold",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtom",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct AtomConfig",
        "components": [
          {
            "name": "atomCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomWalletDepositFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomCost",
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
    "name": "getAtomCreatedAt",
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
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomCreator",
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
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomUriConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "maxUriCount",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "maxUriLength",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomWarden",
    "inputs": [],
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
    "name": "getBondingCurveConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct BondingCurveConfig",
        "components": [
          {
            "name": "registry",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "defaultCurveId",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCounterIdFromTripleId",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "getGeneralConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct GeneralConfig",
        "components": [
          {
            "name": "admin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "protocolMultisig",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeDenominator",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "trustBonding",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "minDeposit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minShare",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDataMaxLength",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "feeThreshold",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getInverseTripleId",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getShares",
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
    "name": "getTotalUtilizationForEpoch",
    "inputs": [
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
    "name": "getTriple",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getTripleConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct TripleConfig",
        "components": [
          {
            "name": "tripleCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDepositFractionForTriple",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getTripleCost",
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
    "name": "getTripleIdFromCounterId",
    "inputs": [
      {
        "name": "counterId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserLastActiveEpoch",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
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
    "name": "getUserUtilizationForEpoch",
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
    "name": "getVault",
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
      },
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
    "name": "getVaultFees",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct VaultFees",
        "components": [
          {
            "name": "entryFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "exitFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "protocolFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getVaultType",
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
        "type": "uint8",
        "internalType": "enum VaultType"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getWalletConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct WalletConfig",
        "components": [
          {
            "name": "entryPoint",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWarden",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletBeacon",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletFactory",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
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
    "name": "hasRolledOverSystemUtilization",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "hasRolledOver",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "_generalConfig",
        "type": "tuple",
        "internalType": "struct GeneralConfig",
        "components": [
          {
            "name": "admin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "protocolMultisig",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeDenominator",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "trustBonding",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "minDeposit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minShare",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDataMaxLength",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "feeThreshold",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_atomConfig",
        "type": "tuple",
        "internalType": "struct AtomConfig",
        "components": [
          {
            "name": "atomCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomWalletDepositFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_tripleConfig",
        "type": "tuple",
        "internalType": "struct TripleConfig",
        "components": [
          {
            "name": "tripleCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDepositFractionForTriple",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_walletConfig",
        "type": "tuple",
        "internalType": "struct WalletConfig",
        "components": [
          {
            "name": "entryPoint",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWarden",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletBeacon",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletFactory",
            "type": "address",
            "internalType": "address"
          }
        ]
      },
      {
        "name": "_vaultFees",
        "type": "tuple",
        "internalType": "struct VaultFees",
        "components": [
          {
            "name": "entryFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "exitFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "protocolFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_bondingCurveConfig",
        "type": "tuple",
        "internalType": "struct BondingCurveConfig",
        "components": [
          {
            "name": "registry",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "defaultCurveId",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
        "name": "approved",
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
        "name": "approved",
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
        "name": "approved",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isAtom",
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
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isCounterTriple",
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
    "name": "isTermCreated",
    "inputs": [
      {
        "name": "id",
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
    "name": "isTriple",
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
    "name": "lastSystemUtilizationEpoch",
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
    "name": "maxRedeem",
    "inputs": [
      {
        "name": "sender",
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
    "name": "multicall",
    "inputs": [
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "values",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "results",
        "type": "bytes[]",
        "internalType": "bytes[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "pause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
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
    "name": "personalUtilization",
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
        "name": "utilizationAmount",
        "type": "int256",
        "internalType": "int256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewAtomCreate",
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
        "name": "assetsAfterFixedFees",
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
    "name": "previewDeposit",
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
        "name": "shares",
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
    "name": "previewRedeem",
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
    "name": "previewTripleCreate",
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
        "name": "assetsAfterFixedFees",
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
    "name": "protocolFeeAmount",
    "inputs": [
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
    "name": "redeem",
    "inputs": [
      {
        "name": "receiver",
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
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "redeemBatch",
    "inputs": [
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "curveIds",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "shares",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "minAssets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "reinitialize",
    "inputs": [
      {
        "name": "_timelock",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "callerConfirmation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setAtomConfig",
    "inputs": [
      {
        "name": "_atomConfig",
        "type": "tuple",
        "internalType": "struct AtomConfig",
        "components": [
          {
            "name": "atomCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomWalletDepositFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setAtomUriConfig",
    "inputs": [
      {
        "name": "maxUriCount",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "maxUriLength",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setBondingCurveConfig",
    "inputs": [
      {
        "name": "_bondingCurveConfig",
        "type": "tuple",
        "internalType": "struct BondingCurveConfig",
        "components": [
          {
            "name": "registry",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "defaultCurveId",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setGeneralConfig",
    "inputs": [
      {
        "name": "_generalConfig",
        "type": "tuple",
        "internalType": "struct GeneralConfig",
        "components": [
          {
            "name": "admin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "protocolMultisig",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeDenominator",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "trustBonding",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "minDeposit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minShare",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDataMaxLength",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "feeThreshold",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTimelock",
    "inputs": [
      {
        "name": "_timelock",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTripleConfig",
    "inputs": [
      {
        "name": "_tripleConfig",
        "type": "tuple",
        "internalType": "struct TripleConfig",
        "components": [
          {
            "name": "tripleCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDepositFractionForTriple",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setVaultFees",
    "inputs": [
      {
        "name": "_vaultFees",
        "type": "tuple",
        "internalType": "struct VaultFees",
        "components": [
          {
            "name": "entryFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "exitFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "protocolFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setWalletConfig",
    "inputs": [
      {
        "name": "_walletConfig",
        "type": "tuple",
        "internalType": "struct WalletConfig",
        "components": [
          {
            "name": "entryPoint",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWarden",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletBeacon",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletFactory",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "sweepAccumulatedProtocolFees",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "timelock",
    "inputs": [],
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
    "name": "totalTermsCreated",
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
    "name": "totalUtilization",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "utilizationAmount",
        "type": "int256",
        "internalType": "int256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "triple",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tripleConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "tripleCreationProtocolFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "atomDepositFractionForTriple",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "unpause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "userEpochHistory",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "vaultFees",
    "inputs": [],
    "outputs": [
      {
        "name": "entryFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "exitFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "protocolFee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "walletConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "entryPoint",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "atomWarden",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "atomWalletBeacon",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "atomWalletFactory",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "ApprovalTypeUpdated",
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
        "name": "approvalType",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum ApprovalTypes"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomConfigUpdated",
    "inputs": [
      {
        "name": "atomCreationProtocolFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "atomWalletDepositFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
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
    "name": "AtomUriConfigUpdated",
    "inputs": [
      {
        "name": "maxUriCount",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
      },
      {
        "name": "maxUriLength",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
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
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomWalletDepositFeesClaimed",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "atomWalletOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "feesClaimed",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "BondingCurveConfigUpdated",
    "inputs": [
      {
        "name": "registry",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "defaultCurveId",
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
    "name": "GeneralConfigUpdated",
    "inputs": [
      {
        "name": "admin",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "protocolMultisig",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "feeDenominator",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "trustBonding",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "minDeposit",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "minShare",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "atomDataMaxLength",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "feeThreshold",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Paused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
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
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProtocolFeeTransferred",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "destination",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
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
        "name": "shares",
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
        "name": "assets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "fees",
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
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
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
    "name": "TimelockSet",
    "inputs": [
      {
        "name": "timelock",
        "type": "address",
        "indexed": true,
        "internalType": "address"
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
    "name": "TripleConfigUpdated",
    "inputs": [
      {
        "name": "tripleCreationProtocolFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "atomDepositFractionForTriple",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
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
    "type": "event",
    "name": "Unpaused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "VaultFeesUpdated",
    "inputs": [
      {
        "name": "entryFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "exitFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "protocolFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "WalletConfigUpdated",
    "inputs": [
      {
        "name": "entryPoint",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "atomWarden",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "atomWalletBeacon",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "atomWalletFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AccessControlBadConfirmation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AccessControlUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "neededRole",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "EnforcedPause",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ExpectedPause",
    "inputs": []
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
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVaultCore_AtomDoesNotExist",
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
    "name": "MultiVaultCore_InvalidAdmin",
    "inputs": []
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
        "name": "termId",
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
    "name": "MultiVault_AtomDoesNotExist",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
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
    "name": "MultiVault_CannotApproveOrRevokeSelf",
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
    "name": "MultiVault_InvalidAtomUriConfig",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_InvalidEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_MulticallValueMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_NestedMulticall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_NoAtomDataProvided",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_OnlyAssociatedAtomWallet",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_OnlyTimelock",
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
        "name": "termId",
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
  },
  {
    "type": "error",
    "name": "MultiVault_UnexpectedValue",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_ZeroAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  }
];

// abis/MultiVaultMigrationMode.ts
var MultiVaultMigrationModeAbi = [
  {
    "type": "receive",
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "ATOM_SALT",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "BURN_ADDRESS",
    "inputs": [],
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
    "name": "COUNTER_SALT",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MAX_BATCH_SIZE",
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
    "name": "MIGRATOR_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "PAUSER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "TRIPLE_SALT",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "accumulatedAtomWalletDepositFees",
    "inputs": [
      {
        "name": "atomWallet",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "accumulatedFees",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "accumulatedProtocolFees",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "accumulatedFees",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "approve",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "approvalType",
        "type": "uint8",
        "internalType": "enum ApprovalTypes"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "atom",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "atomConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "atomCreationProtocolFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "atomWalletDepositFee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "atomCreatedAt",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "createdAt",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "atomCreators",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "atomDepositFractionAmount",
    "inputs": [
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
    "name": "batchSetAtomData",
    "inputs": [
      {
        "name": "creators",
        "type": "address[]",
        "internalType": "address[]"
      },
      {
        "name": "atomDataArray",
        "type": "bytes[]",
        "internalType": "bytes[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "batchSetTripleData",
    "inputs": [
      {
        "name": "creators",
        "type": "address[]",
        "internalType": "address[]"
      },
      {
        "name": "tripleAtomIds",
        "type": "bytes32[3][]",
        "internalType": "bytes32[3][]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "batchSetUserBalances",
    "inputs": [
      {
        "name": "params",
        "type": "tuple",
        "internalType": "struct MultiVaultMigrationMode.BatchSetUserBalancesParams",
        "components": [
          {
            "name": "termIds",
            "type": "bytes32[][]",
            "internalType": "bytes32[][]"
          },
          {
            "name": "bondingCurveId",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "users",
            "type": "address[]",
            "internalType": "address[]"
          },
          {
            "name": "userBalances",
            "type": "uint256[][]",
            "internalType": "uint256[][]"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "batchSetVaultTotals",
    "inputs": [
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "bondingCurveId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "vaultTotals",
        "type": "tuple[]",
        "internalType": "struct MultiVaultMigrationMode.VaultTotals[]",
        "components": [
          {
            "name": "totalAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "totalShares",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "bondingCurveConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "registry",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "defaultCurveId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "calculateAtomId",
    "inputs": [
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "id",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "calculateCounterTripleId",
    "inputs": [
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
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "calculateTripleId",
    "inputs": [
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
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "claimAtomWalletDepositFees",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
    "name": "createAtoms",
    "inputs": [
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createAtomsFor",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createAtomsWithUris",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "uris",
        "type": "bytes[][]",
        "internalType": "bytes[][]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTriples",
    "inputs": [
      {
        "name": "subjectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "predicateIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "objectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTriplesFor",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "subjectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "predicateIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "objectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
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
    "name": "deposit",
    "inputs": [
      {
        "name": "receiver",
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
      },
      {
        "name": "minShares",
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
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "depositBatch",
    "inputs": [
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "curveIds",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "minShares",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "entryFeeAmount",
    "inputs": [
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
    "name": "exitFeeAmount",
    "inputs": [
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
    "name": "generalConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "admin",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "protocolMultisig",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "feeDenominator",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "trustBonding",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "minDeposit",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "minShare",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "atomDataMaxLength",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "feeThreshold",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtom",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct AtomConfig",
        "components": [
          {
            "name": "atomCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomWalletDepositFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomCost",
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
    "name": "getAtomCreatedAt",
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
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomCreator",
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
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomUriConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "maxUriCount",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "maxUriLength",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAtomWarden",
    "inputs": [],
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
    "name": "getBondingCurveConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct BondingCurveConfig",
        "components": [
          {
            "name": "registry",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "defaultCurveId",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCounterIdFromTripleId",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "getGeneralConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct GeneralConfig",
        "components": [
          {
            "name": "admin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "protocolMultisig",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeDenominator",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "trustBonding",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "minDeposit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minShare",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDataMaxLength",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "feeThreshold",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getInverseTripleId",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getShares",
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
    "name": "getTotalUtilizationForEpoch",
    "inputs": [
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
    "name": "getTriple",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getTripleConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct TripleConfig",
        "components": [
          {
            "name": "tripleCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDepositFractionForTriple",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getTripleCost",
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
    "name": "getTripleIdFromCounterId",
    "inputs": [
      {
        "name": "counterId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserLastActiveEpoch",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
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
    "name": "getUserUtilizationForEpoch",
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
    "name": "getVault",
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
      },
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
    "name": "getVaultFees",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct VaultFees",
        "components": [
          {
            "name": "entryFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "exitFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "protocolFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getVaultType",
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
        "type": "uint8",
        "internalType": "enum VaultType"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getWalletConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct WalletConfig",
        "components": [
          {
            "name": "entryPoint",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWarden",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletBeacon",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletFactory",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
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
    "name": "hasRolledOverSystemUtilization",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "hasRolledOver",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "_generalConfig",
        "type": "tuple",
        "internalType": "struct GeneralConfig",
        "components": [
          {
            "name": "admin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "protocolMultisig",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeDenominator",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "trustBonding",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "minDeposit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minShare",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDataMaxLength",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "feeThreshold",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_atomConfig",
        "type": "tuple",
        "internalType": "struct AtomConfig",
        "components": [
          {
            "name": "atomCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomWalletDepositFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_tripleConfig",
        "type": "tuple",
        "internalType": "struct TripleConfig",
        "components": [
          {
            "name": "tripleCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDepositFractionForTriple",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_walletConfig",
        "type": "tuple",
        "internalType": "struct WalletConfig",
        "components": [
          {
            "name": "entryPoint",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWarden",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletBeacon",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletFactory",
            "type": "address",
            "internalType": "address"
          }
        ]
      },
      {
        "name": "_vaultFees",
        "type": "tuple",
        "internalType": "struct VaultFees",
        "components": [
          {
            "name": "entryFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "exitFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "protocolFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "_bondingCurveConfig",
        "type": "tuple",
        "internalType": "struct BondingCurveConfig",
        "components": [
          {
            "name": "registry",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "defaultCurveId",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
        "name": "approved",
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
        "name": "approved",
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
        "name": "approved",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isAtom",
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
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isCounterTriple",
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
    "name": "isTermCreated",
    "inputs": [
      {
        "name": "id",
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
    "name": "isTriple",
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
    "name": "lastSystemUtilizationEpoch",
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
    "name": "maxRedeem",
    "inputs": [
      {
        "name": "sender",
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
    "name": "multicall",
    "inputs": [
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "values",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "results",
        "type": "bytes[]",
        "internalType": "bytes[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "pause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
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
    "name": "personalUtilization",
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
        "name": "utilizationAmount",
        "type": "int256",
        "internalType": "int256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewAtomCreate",
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
        "name": "assetsAfterFixedFees",
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
    "name": "previewDeposit",
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
        "name": "shares",
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
    "name": "previewRedeem",
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
    "name": "previewTripleCreate",
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
        "name": "assetsAfterFixedFees",
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
    "name": "protocolFeeAmount",
    "inputs": [
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
    "name": "redeem",
    "inputs": [
      {
        "name": "receiver",
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
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "redeemBatch",
    "inputs": [
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "curveIds",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "shares",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "minAssets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "reinitialize",
    "inputs": [
      {
        "name": "_timelock",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "callerConfirmation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setAtomConfig",
    "inputs": [
      {
        "name": "_atomConfig",
        "type": "tuple",
        "internalType": "struct AtomConfig",
        "components": [
          {
            "name": "atomCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomWalletDepositFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setAtomUriConfig",
    "inputs": [
      {
        "name": "maxUriCount",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "maxUriLength",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setBondingCurveConfig",
    "inputs": [
      {
        "name": "_bondingCurveConfig",
        "type": "tuple",
        "internalType": "struct BondingCurveConfig",
        "components": [
          {
            "name": "registry",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "defaultCurveId",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setGeneralConfig",
    "inputs": [
      {
        "name": "_generalConfig",
        "type": "tuple",
        "internalType": "struct GeneralConfig",
        "components": [
          {
            "name": "admin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "protocolMultisig",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeDenominator",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "trustBonding",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "minDeposit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minShare",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDataMaxLength",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "feeThreshold",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTermCount",
    "inputs": [
      {
        "name": "_termCount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTimelock",
    "inputs": [
      {
        "name": "_timelock",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTripleConfig",
    "inputs": [
      {
        "name": "_tripleConfig",
        "type": "tuple",
        "internalType": "struct TripleConfig",
        "components": [
          {
            "name": "tripleCreationProtocolFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "atomDepositFractionForTriple",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setVaultFees",
    "inputs": [
      {
        "name": "_vaultFees",
        "type": "tuple",
        "internalType": "struct VaultFees",
        "components": [
          {
            "name": "entryFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "exitFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "protocolFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setWalletConfig",
    "inputs": [
      {
        "name": "_walletConfig",
        "type": "tuple",
        "internalType": "struct WalletConfig",
        "components": [
          {
            "name": "entryPoint",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWarden",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletBeacon",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomWalletFactory",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "sweepAccumulatedProtocolFees",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "timelock",
    "inputs": [],
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
    "name": "totalTermsCreated",
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
    "name": "totalUtilization",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "utilizationAmount",
        "type": "int256",
        "internalType": "int256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "triple",
    "inputs": [
      {
        "name": "tripleId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tripleConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "tripleCreationProtocolFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "atomDepositFractionForTriple",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "unpause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "userEpochHistory",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "vaultFees",
    "inputs": [],
    "outputs": [
      {
        "name": "entryFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "exitFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "protocolFee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "walletConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "entryPoint",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "atomWarden",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "atomWalletBeacon",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "atomWalletFactory",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "ApprovalTypeUpdated",
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
        "name": "approvalType",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum ApprovalTypes"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomConfigUpdated",
    "inputs": [
      {
        "name": "atomCreationProtocolFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "atomWalletDepositFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
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
    "name": "AtomUriConfigUpdated",
    "inputs": [
      {
        "name": "maxUriCount",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
      },
      {
        "name": "maxUriLength",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
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
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomWalletDepositFeesClaimed",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "atomWalletOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "feesClaimed",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "BondingCurveConfigUpdated",
    "inputs": [
      {
        "name": "registry",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "defaultCurveId",
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
    "name": "GeneralConfigUpdated",
    "inputs": [
      {
        "name": "admin",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "protocolMultisig",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "feeDenominator",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "trustBonding",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "minDeposit",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "minShare",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "atomDataMaxLength",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "feeThreshold",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Paused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
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
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProtocolFeeTransferred",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "destination",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
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
        "name": "shares",
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
        "name": "assets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "fees",
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
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
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
    "name": "TimelockSet",
    "inputs": [
      {
        "name": "timelock",
        "type": "address",
        "indexed": true,
        "internalType": "address"
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
    "name": "TripleConfigUpdated",
    "inputs": [
      {
        "name": "tripleCreationProtocolFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "atomDepositFractionForTriple",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
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
    "type": "event",
    "name": "Unpaused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "VaultFeesUpdated",
    "inputs": [
      {
        "name": "entryFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "exitFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "protocolFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "WalletConfigUpdated",
    "inputs": [
      {
        "name": "entryPoint",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "atomWarden",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "atomWalletBeacon",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "atomWalletFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AccessControlBadConfirmation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AccessControlUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "neededRole",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "EnforcedPause",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ExpectedPause",
    "inputs": []
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
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVaultCore_AtomDoesNotExist",
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
    "name": "MultiVaultCore_InvalidAdmin",
    "inputs": []
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
        "name": "termId",
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
    "name": "MultiVault_AtomDoesNotExist",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
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
    "name": "MultiVault_CannotApproveOrRevokeSelf",
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
    "name": "MultiVault_InvalidAtomUriConfig",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_InvalidBondingCurveId",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_InvalidEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_MulticallValueMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_NestedMulticall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_NoAtomDataProvided",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_OnlyAssociatedAtomWallet",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_OnlyTimelock",
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
        "name": "termId",
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
  },
  {
    "type": "error",
    "name": "MultiVault_UnexpectedValue",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MultiVault_ZeroAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  }
];

// abis/FeeProxy.ts
var FeeProxyAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "receive",
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "BPS_DIVISOR",
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
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "PAUSER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "affiliateConfig",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "config",
        "type": "tuple",
        "internalType": "struct AffiliateConfig",
        "components": [
          {
            "name": "fees",
            "type": "tuple",
            "internalType": "struct FeeConfig",
            "components": [
              {
                "name": "depositBps",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "creationBps",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "depositFixedFee",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "creationFixedFee",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          },
          {
            "name": "feeRecipient",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "registeredAt",
            "type": "uint64",
            "internalType": "uint64"
          },
          {
            "name": "paused",
            "type": "bool",
            "internalType": "bool"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "affiliateStats",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "stats",
        "type": "tuple",
        "internalType": "struct AffiliateStats",
        "components": [
          {
            "name": "txCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "uniqueUsers",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "totalGrossAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "totalFees",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "totalForwardedAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositGrossAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositFees",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositForwardedAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationGrossAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationFees",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationForwardedAssets",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "affiliateUserStats",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "stats",
        "type": "tuple",
        "internalType": "struct AffiliateUserStats",
        "components": [
          {
            "name": "txCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "totalGrossAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "totalFees",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "totalForwardedAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositGrossAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositFees",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositForwardedAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationGrossAssets",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationFees",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationForwardedAssets",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "claimRefund",
    "inputs": [],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimRefundTo",
    "inputs": [
      {
        "name": "recipient",
        "type": "address",
        "internalType": "address payable"
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "createAtomsVia",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "atomDatas",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "feeGuard",
        "type": "tuple",
        "internalType": "struct FeeGuard",
        "components": [
          {
            "name": "maxFeeBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createAtomsWithUrisVia",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "atomDatas",
        "type": "bytes[]",
        "internalType": "bytes[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "uris",
        "type": "bytes[][]",
        "internalType": "bytes[][]"
      },
      {
        "name": "feeGuard",
        "type": "tuple",
        "internalType": "struct FeeGuard",
        "components": [
          {
            "name": "maxFeeBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTriplesVia",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "subjectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "predicateIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "objectIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "feeGuard",
        "type": "tuple",
        "internalType": "struct FeeGuard",
        "components": [
          {
            "name": "maxFeeBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "depositBatchVia",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "curveIds",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "assets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "minShares",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "feeGuard",
        "type": "tuple",
        "internalType": "struct FeeGuard",
        "components": [
          {
            "name": "maxFeeBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "depositVia",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "receiver",
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
      },
      {
        "name": "grossAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "minShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "feeGuard",
        "type": "tuple",
        "internalType": "struct FeeGuard",
        "components": [
          {
            "name": "maxFeeBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
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
    "name": "initialize",
    "inputs": [
      {
        "name": "multiVault_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "treasury_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "admin_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "maxFeeBps_",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "maxFixedFee_",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "registrationFee_",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isAffiliateActive",
    "inputs": [
      {
        "name": "affiliate",
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
    "name": "isAffiliateRegistered",
    "inputs": [
      {
        "name": "affiliate",
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
    "name": "maxFeeBps",
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
    "name": "maxFixedFee",
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
    "name": "multiVault",
    "inputs": [],
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
    "name": "pause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "pauseAffiliate",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
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
    "name": "pendingRefund",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewCreationFee",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "grossAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "fee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "forwarded",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewDepositFee",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "grossAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "fee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "forwarded",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "registerAffiliate",
    "inputs": [
      {
        "name": "fees",
        "type": "tuple",
        "internalType": "struct FeeConfig",
        "components": [
          {
            "name": "depositBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "feeRecipient",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "registrationFee",
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
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "callerConfirmation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxFeeBps",
    "inputs": [
      {
        "name": "newMaxFeeBps",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxFixedFee",
    "inputs": [
      {
        "name": "newMaxFixedFee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setRegistrationFee",
    "inputs": [
      {
        "name": "newRegistrationFee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "treasury",
    "inputs": [],
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
    "name": "unpause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "unpauseAffiliate",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "updateAffiliateFees",
    "inputs": [
      {
        "name": "fees",
        "type": "tuple",
        "internalType": "struct FeeConfig",
        "components": [
          {
            "name": "depositBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "updateFeeRecipient",
    "inputs": [
      {
        "name": "recipient",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "AffiliateFeePaid",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AffiliateFeeRecipientUpdated",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "previous",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "current",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AffiliateFeesUpdated",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "previous",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct FeeConfig",
        "components": [
          {
            "name": "depositBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "current",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct FeeConfig",
        "components": [
          {
            "name": "depositBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AffiliatePaused",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AffiliateRegistered",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "feeRecipient",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "fees",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct FeeConfig",
        "components": [
          {
            "name": "depositBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "creationFixedFee",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "registrationFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AffiliateUnpaused",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "CreatedAtomsVia",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "totalGrossAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalForwardedAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "atomCount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "CreatedTriplesVia",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "totalGrossAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalForwardedAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "tripleCount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "DepositedBatchVia",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "affiliate",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "totalGrossAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "totalForwardedAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "DepositedVia",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "affiliate",
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
        "name": "grossAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "fee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "forwardedAssets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "shares",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxFeeBpsUpdated",
    "inputs": [
      {
        "name": "previous",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "current",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxFixedFeeUpdated",
    "inputs": [
      {
        "name": "previous",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "current",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Paused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RefundClaimed",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RefundCredited",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RegistrationFeeForwarded",
    "inputs": [
      {
        "name": "treasury",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RegistrationFeeUpdated",
    "inputs": [
      {
        "name": "previous",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "current",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Unpaused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AccessControlBadConfirmation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AccessControlUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "neededRole",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "EnforcedPause",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ExpectedPause",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FailedCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FeeProxy_AffiliateAlreadyPaused",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_AffiliateAlreadyRegistered",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_AffiliateNotPaused",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_AffiliateNotRegistered",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_AffiliatePaused",
    "inputs": [
      {
        "name": "affiliate",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_BpsExceedsCallerGuard",
    "inputs": [
      {
        "name": "configured",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "callerMax",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_BpsExceedsCap",
    "inputs": [
      {
        "name": "bps",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "cap",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_FeeExceedsGross",
    "inputs": [
      {
        "name": "fee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "gross",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_FixedFeeExceedsCallerGuard",
    "inputs": [
      {
        "name": "configured",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "callerMax",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_FixedFeeExceedsCap",
    "inputs": [
      {
        "name": "fixedFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "cap",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_InsufficientValue",
    "inputs": [
      {
        "name": "supplied",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "required",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_LengthMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FeeProxy_MaxFeeBpsOutOfRange",
    "inputs": [
      {
        "name": "requested",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_NoRefundOwed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FeeProxy_ProxyNotApprovedForCreation",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "proxy",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_ProxyNotApprovedForDeposit",
    "inputs": [
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "proxy",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_ReceiverNotApproved",
    "inputs": [
      {
        "name": "receiver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "caller",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_RefundRecipientIsProxy",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FeeProxy_RegistrationFeeMismatch",
    "inputs": [
      {
        "name": "sent",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "required",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_UnauthorizedEthSender",
    "inputs": [
      {
        "name": "sender",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "FeeProxy_ZeroAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FeeProxy_ZeroValue",
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
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  }
];

// abis/BaseEmissionsController.ts
var BaseEmissionsControllerAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "receive",
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "CONTROLLER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "GAS_CONSTANT",
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
    "name": "burn",
    "inputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getBalance",
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
    "name": "getCurrentEpoch",
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
    "name": "getCurrentEpochEmissions",
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
    "name": "getCurrentEpochTimestampStart",
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
    "name": "getEmissionsAtEpoch",
    "inputs": [
      {
        "name": "epochNumber",
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
    "name": "getEmissionsAtTimestamp",
    "inputs": [
      {
        "name": "timestamp",
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
    "name": "getEpochAtTimestamp",
    "inputs": [
      {
        "name": "timestamp",
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
    "name": "getEpochLength",
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
    "name": "getEpochMintedAmount",
    "inputs": [
      {
        "name": "epoch",
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
    "name": "getEpochTimestampEnd",
    "inputs": [
      {
        "name": "epochNumber",
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
    "name": "getEpochTimestampStart",
    "inputs": [
      {
        "name": "epochNumber",
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
    "name": "getFinalityState",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "enum FinalityState"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getMessageGasCost",
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
    "name": "getMetaERC20SpokeOrHub",
    "inputs": [],
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
    "name": "getRecipientDomain",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getSatelliteEmissionsController",
    "inputs": [],
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
    "name": "getStartTimestamp",
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
    "name": "getTotalMinted",
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
    "name": "getTrustToken",
    "inputs": [],
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
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
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
    "name": "initialize",
    "inputs": [
      {
        "name": "admin",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "controller",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "metaERC20DispatchInit",
        "type": "tuple",
        "internalType": "struct MetaERC20DispatchInit",
        "components": [
          {
            "name": "hubOrSpoke",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "recipientDomain",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "gasLimit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "finalityState",
            "type": "uint8",
            "internalType": "enum FinalityState"
          }
        ]
      },
      {
        "name": "checkpointInit",
        "type": "tuple",
        "internalType": "struct CoreEmissionsControllerInit",
        "components": [
          {
            "name": "startTimestamp",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "emissionsLength",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "emissionsPerEpoch",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "emissionsReductionCliff",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "emissionsReductionBasisPoints",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "mintAndBridge",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "mintAndBridgeCurrentEpoch",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "quoteGasPayment",
    "inputs": [
      {
        "name": "domain",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "gasLimit",
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
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "callerConfirmation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setFinalityState",
    "inputs": [
      {
        "name": "newFinalityState",
        "type": "uint8",
        "internalType": "enum FinalityState"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMessageGasCost",
    "inputs": [
      {
        "name": "newGasCost",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMetaERC20SpokeOrHub",
    "inputs": [
      {
        "name": "newMetaERC20SpokeOrHub",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setRecipientDomain",
    "inputs": [
      {
        "name": "newRecipientDomain",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setSatelliteEmissionsController",
    "inputs": [
      {
        "name": "newSatellite",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTrustToken",
    "inputs": [
      {
        "name": "newToken",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "withdraw",
    "inputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "FinalityStateUpdated",
    "inputs": [
      {
        "name": "newFinalityState",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum FinalityState"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "startTimestamp",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "emissionsLength",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "emissionsPerEpoch",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "emissionsReductionCliff",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "emissionsReductionBasisPoints",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MessageGasCostUpdated",
    "inputs": [
      {
        "name": "newMessageGasCost",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MetaERC20SpokeOrHubUpdated",
    "inputs": [
      {
        "name": "newMetaERC20SpokeOrHub",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RecipientDomainUpdated",
    "inputs": [
      {
        "name": "newRecipientDomain",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "SatelliteEmissionsControllerUpdated",
    "inputs": [
      {
        "name": "newSatelliteEmissionsController",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Transfer",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TrustBurned",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TrustMintedAndBridged",
    "inputs": [
      {
        "name": "to",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TrustTokenUpdated",
    "inputs": [
      {
        "name": "newTrustToken",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AccessControlBadConfirmation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AccessControlUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "neededRole",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "BaseEmissionsController_EpochMintingLimitExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseEmissionsController_InsufficientBurnableBalance",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseEmissionsController_InsufficientGasPayment",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseEmissionsController_InvalidAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseEmissionsController_InvalidEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseEmissionsController_SatelliteEmissionsControllerNotSet",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidCliff",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidEmissionsLength",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidEmissionsPerEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidReductionBasisPoints",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidTimestampStart",
    "inputs": []
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
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MetaERC20Dispatcher_InvalidAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  }
];

// abis/SatelliteEmissionsController.ts
var SatelliteEmissionsControllerAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "receive",
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "CONTROLLER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "GAS_CONSTANT",
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
    "name": "OPERATOR_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "bridgeUnclaimedEmissions",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "getBaseEmissionsController",
    "inputs": [],
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
    "name": "getCurrentEpoch",
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
    "name": "getCurrentEpochEmissions",
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
    "name": "getCurrentEpochTimestampStart",
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
    "name": "getEmissionsAtEpoch",
    "inputs": [
      {
        "name": "epochNumber",
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
    "name": "getEmissionsAtTimestamp",
    "inputs": [
      {
        "name": "timestamp",
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
    "name": "getEpochAtTimestamp",
    "inputs": [
      {
        "name": "timestamp",
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
    "name": "getEpochLength",
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
    "name": "getEpochTimestampEnd",
    "inputs": [
      {
        "name": "epochNumber",
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
    "name": "getEpochTimestampStart",
    "inputs": [
      {
        "name": "epochNumber",
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
    "name": "getFinalityState",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "enum FinalityState"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getMessageGasCost",
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
    "name": "getMetaERC20SpokeOrHub",
    "inputs": [],
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
    "name": "getRecipientDomain",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getReclaimedEmissions",
    "inputs": [
      {
        "name": "epoch",
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
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getStartTimestamp",
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
    "name": "getTrustBonding",
    "inputs": [],
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
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
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
    "name": "initialize",
    "inputs": [
      {
        "name": "admin",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "baseEmissionsController",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "metaERC20DispatchInit",
        "type": "tuple",
        "internalType": "struct MetaERC20DispatchInit",
        "components": [
          {
            "name": "hubOrSpoke",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "recipientDomain",
            "type": "uint32",
            "internalType": "uint32"
          },
          {
            "name": "gasLimit",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "finalityState",
            "type": "uint8",
            "internalType": "enum FinalityState"
          }
        ]
      },
      {
        "name": "checkpointInit",
        "type": "tuple",
        "internalType": "struct CoreEmissionsControllerInit",
        "components": [
          {
            "name": "startTimestamp",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "emissionsLength",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "emissionsPerEpoch",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "emissionsReductionCliff",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "emissionsReductionBasisPoints",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "quoteGasPayment",
    "inputs": [
      {
        "name": "domain",
        "type": "uint32",
        "internalType": "uint32"
      },
      {
        "name": "gasLimit",
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
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "callerConfirmation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setBaseEmissionsController",
    "inputs": [
      {
        "name": "newBaseEmissionsController",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setFinalityState",
    "inputs": [
      {
        "name": "newFinalityState",
        "type": "uint8",
        "internalType": "enum FinalityState"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMessageGasCost",
    "inputs": [
      {
        "name": "newGasCost",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMetaERC20SpokeOrHub",
    "inputs": [
      {
        "name": "newMetaERC20SpokeOrHub",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setRecipientDomain",
    "inputs": [
      {
        "name": "newRecipientDomain",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTrustBonding",
    "inputs": [
      {
        "name": "newTrustBonding",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "transfer",
    "inputs": [
      {
        "name": "recipient",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "withdrawUnclaimedEmissions",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "recipient",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "BaseEmissionsControllerUpdated",
    "inputs": [
      {
        "name": "newBaseEmissionsController",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "FinalityStateUpdated",
    "inputs": [
      {
        "name": "newFinalityState",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum FinalityState"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "startTimestamp",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "emissionsLength",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "emissionsPerEpoch",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "emissionsReductionCliff",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "emissionsReductionBasisPoints",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MessageGasCostUpdated",
    "inputs": [
      {
        "name": "newMessageGasCost",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MetaERC20SpokeOrHubUpdated",
    "inputs": [
      {
        "name": "newMetaERC20SpokeOrHub",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "NativeTokenTransferred",
    "inputs": [
      {
        "name": "recipient",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RecipientDomainUpdated",
    "inputs": [
      {
        "name": "newRecipientDomain",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TrustBondingUpdated",
    "inputs": [
      {
        "name": "newTrustBonding",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "UnclaimedEmissionsBridged",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "UnclaimedEmissionsWithdrawn",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "recipient",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AccessControlBadConfirmation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AccessControlUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "neededRole",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidCliff",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidEmissionsLength",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidEmissionsPerEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidReductionBasisPoints",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CoreEmissionsController_InvalidTimestampStart",
    "inputs": []
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
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MetaERC20Dispatcher_InvalidAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SatelliteEmissionsController_InsufficientBalance",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SatelliteEmissionsController_InsufficientGasPayment",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SatelliteEmissionsController_InvalidAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SatelliteEmissionsController_InvalidAmount",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SatelliteEmissionsController_InvalidBridgeAmount",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SatelliteEmissionsController_InvalidWithdrawAmount",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SatelliteEmissionsController_PreviouslyBridgedUnclaimedEmissions",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SatelliteEmissionsController_TrustBondingNotSet",
    "inputs": []
  }
];

// abis/TrustBonding.ts
var TrustBondingAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "BASIS_POINTS_DIVISOR",
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
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MAXTIME",
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
    "name": "MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND",
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
    "name": "MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND",
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
    "name": "MINTIME",
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
    "name": "PAUSER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "YEAR",
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
    "name": "add_to_whitelist",
    "inputs": [
      {
        "name": "addr",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "balanceOf",
    "inputs": [
      {
        "name": "addr",
        "type": "address",
        "internalType": "address"
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
    "name": "balanceOfAt",
    "inputs": [
      {
        "name": "addr",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_block",
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
    "name": "balanceOfAtT",
    "inputs": [
      {
        "name": "addr",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_t",
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
    "name": "changeController",
    "inputs": [
      {
        "name": "_newController",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "checkpoint",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimRewards",
    "inputs": [
      {
        "name": "recipient",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "contracts_whitelist",
    "inputs": [
      {
        "name": "",
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
    "name": "controller",
    "inputs": [],
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
    "name": "create_lock",
    "inputs": [
      {
        "name": "_value",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_unlock_time",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
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
    "name": "decimals",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "deposit_for",
    "inputs": [
      {
        "name": "_addr",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_value",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "emissionsForEpoch",
    "inputs": [
      {
        "name": "epoch",
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
    "name": "epoch",
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
    "name": "epochAtTimestamp",
    "inputs": [
      {
        "name": "timestamp",
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
    "name": "epochLength",
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
    "name": "epochTimestampEnd",
    "inputs": [
      {
        "name": "epoch",
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
    "name": "epochsPerYear",
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
    "name": "getPersonalUtilizationRatio",
    "inputs": [
      {
        "name": "account",
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
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getSystemApy",
    "inputs": [],
    "outputs": [
      {
        "name": "currentApy",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "maxApy",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getSystemUtilizationRatio",
    "inputs": [
      {
        "name": "epoch",
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
    "name": "getUnclaimedRewardsForEpoch",
    "inputs": [
      {
        "name": "epoch",
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
    "name": "getUserApy",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "currentApy",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "maxApy",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserCurrentClaimableRewards",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
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
    "name": "getUserInfo",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct UserInfo",
        "components": [
          {
            "name": "personalUtilization",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "eligibleRewards",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxRewards",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "lockedAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "lockEnd",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "bondedBalance",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserRewardsForEpoch",
    "inputs": [
      {
        "name": "account",
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
        "type": "uint256",
        "internalType": "uint256"
      },
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
    "name": "get_last_user_slope",
    "inputs": [
      {
        "name": "addr",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "int128",
        "internalType": "int128"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasClaimedRewardsForEpoch",
    "inputs": [
      {
        "name": "account",
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
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
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
    "name": "increase_amount",
    "inputs": [
      {
        "name": "_value",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "increase_amount_and_time",
    "inputs": [
      {
        "name": "_value",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_unlock_time",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "increase_unlock_time",
    "inputs": [
      {
        "name": "_unlock_time",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "_owner",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_timelock",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_trustToken",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_epochLength",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_satelliteEmissionsController",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_systemUtilizationLowerBound",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_personalUtilizationLowerBound",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "locked",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "int128",
        "internalType": "int128"
      },
      {
        "name": "end",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "locked__end",
    "inputs": [
      {
        "name": "_addr",
        "type": "address",
        "internalType": "address"
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
    "name": "multiVault",
    "inputs": [],
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
    "name": "name",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "pause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
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
    "name": "personalUtilizationLowerBound",
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
    "name": "point_history",
    "inputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "bias",
        "type": "int128",
        "internalType": "int128"
      },
      {
        "name": "slope",
        "type": "int128",
        "internalType": "int128"
      },
      {
        "name": "ts",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "blk",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previousEpoch",
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
    "name": "remove_from_whitelist",
    "inputs": [
      {
        "name": "addr",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "callerConfirmation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "satelliteEmissionsController",
    "inputs": [],
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
    "name": "setMultiVault",
    "inputs": [
      {
        "name": "_multiVault",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTimelock",
    "inputs": [
      {
        "name": "_timelock",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "slope_changes",
    "inputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "int128",
        "internalType": "int128"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "supply",
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
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "symbol",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "systemUtilizationLowerBound",
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
    "name": "timelock",
    "inputs": [],
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
    "name": "token",
    "inputs": [],
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
    "name": "totalBondedBalance",
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
    "name": "totalBondedBalanceAtEpochEnd",
    "inputs": [
      {
        "name": "epoch",
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
    "name": "totalClaimedRewardsForEpoch",
    "inputs": [
      {
        "name": "epoch",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "totalClaimedRewards",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalLocked",
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
    "name": "totalSupply",
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
    "name": "totalSupplyAt",
    "inputs": [
      {
        "name": "_block",
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
    "name": "totalSupplyAtT",
    "inputs": [
      {
        "name": "t",
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
    "name": "transfersEnabled",
    "inputs": [],
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
    "name": "unlock",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "unlocked",
    "inputs": [],
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
    "name": "unpause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "updatePersonalUtilizationLowerBound",
    "inputs": [
      {
        "name": "newLowerBound",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "updateSatelliteEmissionsController",
    "inputs": [
      {
        "name": "_satelliteEmissionsController",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "updateSystemUtilizationLowerBound",
    "inputs": [
      {
        "name": "newLowerBound",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "userBondedBalanceAtEpochEnd",
    "inputs": [
      {
        "name": "account",
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
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "userClaimedRewardsForEpoch",
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
        "name": "claimedRewards",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "userEligibleRewardsForEpoch",
    "inputs": [
      {
        "name": "account",
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
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "user_point_epoch",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
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
    "name": "user_point_history",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "bias",
        "type": "int128",
        "internalType": "int128"
      },
      {
        "name": "slope",
        "type": "int128",
        "internalType": "int128"
      },
      {
        "name": "ts",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "blk",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "user_point_history__ts",
    "inputs": [
      {
        "name": "_addr",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_idx",
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
    "name": "version",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "withdraw",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "withdraw_and_create_lock",
    "inputs": [
      {
        "name": "_value",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_unlock_time",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "Deposit",
    "inputs": [
      {
        "name": "provider",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "value",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "locktime",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "deposit_type",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum VotingEscrow.DepositType"
      },
      {
        "name": "ts",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MinTimeSet",
    "inputs": [
      {
        "name": "min_time",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MultiVaultSet",
    "inputs": [
      {
        "name": "multiVault",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Paused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PersonalUtilizationLowerBoundUpdated",
    "inputs": [
      {
        "name": "newLowerBound",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RewardsClaimed",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "recipient",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "SatelliteEmissionsControllerSet",
    "inputs": [
      {
        "name": "satelliteEmissionsController",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Supply",
    "inputs": [
      {
        "name": "prevSupply",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "supply",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "SystemUtilizationLowerBoundUpdated",
    "inputs": [
      {
        "name": "newLowerBound",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TimelockSet",
    "inputs": [
      {
        "name": "timelock",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TokenSet",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Unpaused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Withdraw",
    "inputs": [
      {
        "name": "provider",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "value",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "ts",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AccessControlBadConfirmation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AccessControlUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "neededRole",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "EnforcedPause",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ExpectedPause",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SafeERC20FailedOperation",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "TrustBonding_ClaimableProtocolFeesExceedBalance",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_EpochBudgetExhausted",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_InvalidEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_InvalidStartTimestamp",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_InvalidUtilizationLowerBound",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_NoClaimingDuringFirstEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_NoRewardsToClaim",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_OnlyTimelock",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_RewardsAlreadyClaimedForEpoch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TrustBonding_ZeroAddress",
    "inputs": []
  }
];

// abis/BondingCurveRegistry.ts
var BondingCurveRegistryAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "acceptOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "addBondingCurve",
    "inputs": [
      {
        "name": "bondingCurve",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "convertToAssets",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
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
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "count",
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
    "name": "currentPrice",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "sharePrice",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "curveAddresses",
    "inputs": [
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "curveAddress",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "curveIds",
    "inputs": [
      {
        "name": "curveAddress",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "curveId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCurveMaxAssets",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "maxAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCurveMaxShares",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "maxShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCurveName",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "name",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "_admin",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isCurveIdValid",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "valid",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "owner",
    "inputs": [],
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
    "name": "pendingOwner",
    "inputs": [],
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
    "name": "previewDeposit",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewMint",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewRedeem",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewWithdraw",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "registeredCurveNames",
    "inputs": [
      {
        "name": "curveName",
        "type": "string",
        "internalType": "string"
      }
    ],
    "outputs": [
      {
        "name": "registered",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "renounceOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "transferOwnership",
    "inputs": [
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "BondingCurveAdded",
    "inputs": [
      {
        "name": "curveId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "curveAddress",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "curveName",
        "type": "string",
        "indexed": true,
        "internalType": "string"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwnershipTransferStarted",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwnershipTransferred",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "BondingCurveRegistry_CurveAlreadyExists",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BondingCurveRegistry_CurveNameNotUnique",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BondingCurveRegistry_EmptyCurveName",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BondingCurveRegistry_InvalidCurveId",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BondingCurveRegistry_ZeroAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OwnableInvalidOwner",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "OwnableUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ]
  }
];

// abis/LinearCurve.ts
var LinearCurveAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "MAX_ASSETS",
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
    "name": "MAX_SHARES",
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
    "name": "ONE_SHARE",
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
    "name": "convertToAssets",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "convertToShares",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "currentPrice",
    "inputs": [
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "sharePrice",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hasDepositFeeHook",
    "inputs": [],
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
    "name": "hasRedeemFeeHook",
    "inputs": [],
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
    "name": "initialize",
    "inputs": [
      {
        "name": "_name",
        "type": "string",
        "internalType": "string"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "maxAssets",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "maxShares",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "name",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewDeposit",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "previewMint",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "previewRedeem",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "previewWithdraw",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "quoteDepositFee",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
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
    "name": "quoteRedeemFee",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
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
    "name": "recordDeposit",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "recordRedeem",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "event",
    "name": "CurveNameSet",
    "inputs": [
      {
        "name": "name",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "BaseCurve_AssetsExceedTotalAssets",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_AssetsOverflowMax",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_DomainExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_EmptyStringNotAllowed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_FeeHooksNotSupported",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_SharesExceedTotalShares",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_SharesOverflowMax",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  }
];

// abis/OffsetProgressiveCurve.ts
var OffsetProgressiveCurveAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "HALF_SLOPE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "UD60x18"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MAX_ASSETS",
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
    "name": "MAX_SHARES",
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
    "name": "OFFSET",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "UD60x18"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "SLOPE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "UD60x18"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "convertToAssets",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
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
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "currentPrice",
    "inputs": [
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "sharePrice",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "hasDepositFeeHook",
    "inputs": [],
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
    "name": "hasRedeemFeeHook",
    "inputs": [],
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
    "name": "initialize",
    "inputs": [
      {
        "name": "_name",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "slope18",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "offset18",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "maxAssets",
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
    "name": "maxShares",
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
    "name": "name",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewDeposit",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewMint",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewRedeem",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewWithdraw",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "quoteDepositFee",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
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
    "name": "quoteRedeemFee",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
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
    "name": "recordDeposit",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "recordRedeem",
    "inputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "event",
    "name": "CurveNameSet",
    "inputs": [
      {
        "name": "name",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "BaseCurve_AssetsExceedTotalAssets",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_AssetsOverflowMax",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_DomainExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_EmptyStringNotAllowed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_FeeHooksNotSupported",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_SharesExceedTotalShares",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_SharesOverflowMax",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OffsetProgressiveCurve_InvalidSlope",
    "inputs": []
  },
  {
    "type": "error",
    "name": "PRBMath_MulDiv18_Overflow",
    "inputs": [
      {
        "name": "x",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "y",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "PRBMath_MulDiv_Overflow",
    "inputs": [
      {
        "name": "x",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "y",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "denominator",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "PRBMath_UD60x18_Sqrt_Overflow",
    "inputs": [
      {
        "name": "x",
        "type": "uint256",
        "internalType": "UD60x18"
      }
    ]
  }
];

// abis/DynamicFeeFlatPriceCurve.ts
var DynamicFeeFlatPriceCurveAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "ACC_PRECISION",
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
    "name": "BPS",
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
    "name": "MAX_ASSETS",
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
    "name": "MAX_DEPOSIT_CAP_BPS",
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
    "name": "MAX_KERNEL_SPREAD",
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
    "name": "MAX_MIN_ELIGIBLE_TIER_STAKE",
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
    "name": "MAX_SHARES",
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
    "name": "MAX_TIER_COUNT",
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
    "name": "MAX_WITHDRAWAL_CAP_BPS",
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
    "name": "ONE_SHARE",
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
    "name": "TIER_PRECISION",
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
    "name": "accFeePerShare",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "tier",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "acc",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "acceptOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "bankedEarnings",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "claim",
    "inputs": [
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimable",
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
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "claimableAcross",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "termIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "clearTierFeeOverride",
    "inputs": [
      {
        "name": "tier",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "convertToAssets",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "convertToShares",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "currentPrice",
    "inputs": [
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "sharePrice",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "depositFeeBps",
    "inputs": [
      {
        "name": "tier",
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
    "name": "earned",
    "inputs": [
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct DynamicFeeConfig",
        "components": [
          {
            "name": "width0",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "tierCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "growthGBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositBaseBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositGrowthBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositCapBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "fulcrumAlpha",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "kernelSpread",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalBaseBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalGrowthBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalCapBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalToFulcrumTiersBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositToPriorTierBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minEligibleTierStake",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "hasDepositFeeHook",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "hasRedeemFeeHook",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "_name",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "_owner",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_multiVault",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_config",
        "type": "tuple",
        "internalType": "struct DynamicFeeConfig",
        "components": [
          {
            "name": "width0",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "tierCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "growthGBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositBaseBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositGrowthBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositCapBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "fulcrumAlpha",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "kernelSpread",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalBaseBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalGrowthBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalCapBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalToFulcrumTiersBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositToPriorTierBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minEligibleTierStake",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "_name",
        "type": "string",
        "internalType": "string"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "maxAssets",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "maxShares",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "multiVault",
    "inputs": [],
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
    "name": "name",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "owner",
    "inputs": [],
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
    "name": "pendingFor",
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
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "pendingOwner",
    "inputs": [],
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
    "name": "previewDeposit",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "previewMint",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "previewRedeem",
    "inputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "previewRedeemFor",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
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
      }
    ],
    "outputs": [
      {
        "name": "assetsAfterCurveFee",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "fee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewWithdraw",
    "inputs": [
      {
        "name": "assets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalAssets",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "totalShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "protocolAccrued",
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
    "name": "quoteDepositFee",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "baseAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "fee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "quoteRedeemFee",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "grossAssets",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "fee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "recordDeposit",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "netStake",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "recordRedeem",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "withdrawnStake",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "renounceOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "rewardDebt",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "debt",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "setConfig",
    "inputs": [
      {
        "name": "_config",
        "type": "tuple",
        "internalType": "struct DynamicFeeConfig",
        "components": [
          {
            "name": "width0",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "tierCount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "growthGBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositBaseBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositGrowthBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositCapBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "fulcrumAlpha",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "kernelSpread",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalBaseBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalGrowthBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalCapBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "withdrawalToFulcrumTiersBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "depositToPriorTierBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minEligibleTierStake",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTierFeeOverride",
    "inputs": [
      {
        "name": "tier",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "newDepositFeeBps",
        "type": "uint16",
        "internalType": "uint16"
      },
      {
        "name": "newWithdrawalFeeBps",
        "type": "uint16",
        "internalType": "uint16"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "sweepProtocol",
    "inputs": [
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "tierFeeOverride",
    "inputs": [
      {
        "name": "tier",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "isSet",
        "type": "bool",
        "internalType": "bool"
      },
      {
        "name": "depositFeeBps",
        "type": "uint16",
        "internalType": "uint16"
      },
      {
        "name": "withdrawalFeeBps",
        "type": "uint16",
        "internalType": "uint16"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tierOf",
    "inputs": [
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
    "name": "tierStake",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "tier",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "stake",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tierUpperEdge",
    "inputs": [
      {
        "name": "k",
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
    "name": "tierWidthAt",
    "inputs": [
      {
        "name": "k",
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
    "name": "transferOwnership",
    "inputs": [
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "userAvgTier",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "avgTierScaled",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "userStake",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "stake",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "userTier",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "user",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "tier",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "vaultStake",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "stake",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "withdrawalFeeBps",
    "inputs": [
      {
        "name": "tier",
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
    "type": "event",
    "name": "Claimed",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ConfigUpdated",
    "inputs": [
      {
        "name": "width0",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "tierCount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "growthGBps",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "fulcrumAlpha",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "kernelSpread",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "CurveNameSet",
    "inputs": [
      {
        "name": "name",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "DepositBandRecorded",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "bandTier",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "bandStake",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "bandFee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "DepositRecorded",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "netStake",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "fee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "sourceTier",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "accountTier",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "accountAvgTier",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MinEligibleTierStakeUpdated",
    "inputs": [
      {
        "name": "previousMinEligibleTierStake",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "newMinEligibleTierStake",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwnershipTransferStarted",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwnershipTransferred",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProtocolAccruedIncreased",
    "inputs": [
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProtocolSwept",
    "inputs": [
      {
        "name": "to",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RedeemRecorded",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "withdrawnStake",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "fee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "exitTier",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TierFeeOverrideCleared",
    "inputs": [
      {
        "name": "tier",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TierFeeOverrideSet",
    "inputs": [
      {
        "name": "tier",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "depositFeeBps",
        "type": "uint16",
        "indexed": false,
        "internalType": "uint16"
      },
      {
        "name": "withdrawalFeeBps",
        "type": "uint16",
        "indexed": false,
        "internalType": "uint16"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "WithdrawalFeeRerouted",
    "inputs": [
      {
        "name": "termId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "exitTier",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "recipientTier",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "BaseCurve_AssetsExceedTotalAssets",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_AssetsOverflowMax",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_DomainExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_EmptyStringNotAllowed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_FeeHooksNotSupported",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_SharesExceedTotalShares",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BaseCurve_SharesOverflowMax",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DynamicFeeFlatPriceCurve_DuplicateTermIds",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DynamicFeeFlatPriceCurve_InvalidConfig",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DynamicFeeFlatPriceCurve_InvalidMinEligibleTierStake",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DynamicFeeFlatPriceCurve_InvalidTierOverride",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DynamicFeeFlatPriceCurve_NothingToClaim",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DynamicFeeFlatPriceCurve_OnlyMultiVault",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DynamicFeeFlatPriceCurve_TierCountCannotShrink",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DynamicFeeFlatPriceCurve_ZeroAddress",
    "inputs": []
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
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OwnableInvalidOwner",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "OwnableUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  }
];

// abis/AtomWallet.ts
var AtomWalletAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "fallback",
    "stateMutability": "payable"
  },
  {
    "type": "receive",
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "addDeposit",
    "inputs": [],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "addOwnerAddress",
    "inputs": [
      {
        "name": "signer",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "addOwnerPublicKey",
    "inputs": [
      {
        "name": "x",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "y",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimAtomWalletDepositFees",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "completeClaim",
    "inputs": [
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "entryPoint",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IEntryPoint"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "execute",
    "inputs": [
      {
        "name": "dest",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "value",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "executeBatch",
    "inputs": [
      {
        "name": "calls",
        "type": "tuple[]",
        "internalType": "struct BaseAccount.Call[]",
        "components": [
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "value",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "data",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "executeBatch",
    "inputs": [
      {
        "name": "dest",
        "type": "address[]",
        "internalType": "address[]"
      },
      {
        "name": "values",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "data",
        "type": "bytes[]",
        "internalType": "bytes[]"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "getDeposit",
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
    "name": "getNonce",
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
    "name": "initialize",
    "inputs": [
      {
        "name": "anEntryPoint",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_multiVault",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_termId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isClaimed",
    "inputs": [],
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
    "name": "isOwnerAddress",
    "inputs": [
      {
        "name": "account",
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
    "name": "isOwnerPublicKey",
    "inputs": [
      {
        "name": "x",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "y",
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
    "name": "isValidSignature",
    "inputs": [
      {
        "name": "hash",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "signature",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes4",
        "internalType": "bytes4"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "multiVault",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IMultiVault"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "nextOwnerIndex",
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
    "name": "owner",
    "inputs": [],
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
    "name": "ownerAtIndex",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "ownerCount",
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
    "name": "removeOwnerAtIndex",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "ownr",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "termId",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "transferOwnership",
    "inputs": [
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "validateUserOp",
    "inputs": [
      {
        "name": "userOp",
        "type": "tuple",
        "internalType": "struct PackedUserOperation",
        "components": [
          {
            "name": "sender",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "nonce",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "initCode",
            "type": "bytes",
            "internalType": "bytes"
          },
          {
            "name": "callData",
            "type": "bytes",
            "internalType": "bytes"
          },
          {
            "name": "accountGasLimits",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "preVerificationGas",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "gasFees",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "paymasterAndData",
            "type": "bytes",
            "internalType": "bytes"
          },
          {
            "name": "signature",
            "type": "bytes",
            "internalType": "bytes"
          }
        ]
      },
      {
        "name": "userOpHash",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "missingAccountFunds",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "validationData",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "withdrawDepositTo",
    "inputs": [
      {
        "name": "withdrawAddress",
        "type": "address",
        "internalType": "address payable"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "AddOwner",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "owner",
        "type": "bytes",
        "indexed": false,
        "internalType": "bytes"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ClaimCompleted",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PrimaryOwnerTransferred",
    "inputs": [
      {
        "name": "previousClaimant",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newClaimant",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RemoveOwner",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "owner",
        "type": "bytes",
        "indexed": false,
        "internalType": "bytes"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AlreadyOwner",
    "inputs": [
      {
        "name": "owner",
        "type": "bytes",
        "internalType": "bytes"
      }
    ]
  },
  {
    "type": "error",
    "name": "AtomWallet_AlreadyClaimed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_InvalidClaimOwner",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_InvalidOwner",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_OnlyAtomWarden",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_OnlyOwner",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_OnlyOwnerOrEntryPoint",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_OwnerCannotBeRemoved",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_RenounceDisabled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_WrongArrayLengths",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWallet_ZeroAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ExecuteError",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "error",
        "type": "bytes",
        "internalType": "bytes"
      }
    ]
  },
  {
    "type": "error",
    "name": "FnSelectorNotRecognized",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "LastOwner",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NoOwnerAtIndex",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OwnerNotFound",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "WrongOwnerAtIndex",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "expectedOwner",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "actualOwner",
        "type": "bytes",
        "internalType": "bytes"
      }
    ]
  }
];

// abis/AtomWalletFactory.ts
var AtomWalletFactoryAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
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
    "name": "deployAtomWallet",
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
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "_multiVault",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "multiVault",
    "inputs": [],
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
    "type": "event",
    "name": "AtomWalletDeployed",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
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
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AtomWalletFactory_DeployAtomWalletFailed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWalletFactory_TermDoesNotExist",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWalletFactory_TermNotAtom",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWalletFactory_ZeroAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  }
];

// abis/AtomWarden.ts
var AtomWardenAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "CLAIM_AUTHORIZATION_TYPEHASH",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MAX_BATCH_SIZE",
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
    "name": "OPERATOR_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "SIGNER_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "batchGrantAtomWalletOwnership",
    "inputs": [
      {
        "name": "atomIds",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      },
      {
        "name": "newOwners",
        "type": "address[]",
        "internalType": "address[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimAsCreatorAfterExpiry",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimCapWindow",
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
    "name": "claimNonces",
    "inputs": [
      {
        "name": "claimant",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "nonce",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "claimOwnershipOverAddressAtom",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimWindow",
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
    "name": "claimWithAuthorization",
    "inputs": [
      {
        "name": "authorization",
        "type": "tuple",
        "internalType": "struct IAtomWarden.ClaimAuthorization",
        "components": [
          {
            "name": "claimant",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "atomId",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "claimType",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "nonce",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "validAfter",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "validUntil",
            "type": "uint48",
            "internalType": "uint48"
          }
        ]
      },
      {
        "name": "signature",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "claimsInWindow",
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
    "name": "currentClaimWindowId",
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
    "name": "eip712Domain",
    "inputs": [],
    "outputs": [
      {
        "name": "fields",
        "type": "bytes1",
        "internalType": "bytes1"
      },
      {
        "name": "name",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "version",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "chainId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "verifyingContract",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "salt",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "extensions",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "grantAtomWalletOwnership",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
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
    "name": "incrementNonce",
    "inputs": [
      {
        "name": "claimant",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "admin",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_multiVault",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_claimWindow",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_minFeeThreshold",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_signatureThreshold",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_maxValidAfter",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_maxValidUntil",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_maxClaimsPerWindow",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_claimCapWindow",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "maxClaimsPerWindow",
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
    "name": "maxValidAfter",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "maxValidUntil",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "minFeeThreshold",
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
    "name": "multiVault",
    "inputs": [],
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
    "name": "pause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "paused",
    "inputs": [],
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
    "name": "reinitialize",
    "inputs": [
      {
        "name": "_claimWindow",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_minFeeThreshold",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_signatureThreshold",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_maxValidAfter",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_maxValidUntil",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "_maxClaimsPerWindow",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "_claimCapWindow",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "callerConfirmation",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setClaimCapWindow",
    "inputs": [
      {
        "name": "newValue",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setClaimWindow",
    "inputs": [
      {
        "name": "newClaimWindow",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxClaimsPerWindow",
    "inputs": [
      {
        "name": "newValue",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxValidAfter",
    "inputs": [
      {
        "name": "newValue",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxValidUntil",
    "inputs": [
      {
        "name": "newValue",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMinFeeThreshold",
    "inputs": [
      {
        "name": "newThreshold",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMultiVault",
    "inputs": [
      {
        "name": "_multiVault",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setSignatureThreshold",
    "inputs": [
      {
        "name": "newThreshold",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "signatureThreshold",
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
    "name": "signerCount",
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
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "unpause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "AtomWalletOwnershipClaimed",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "claimant",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomWalletOwnershipClaimedByAuthorization",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "claimant",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "firstSigner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "claimType",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "signers",
        "type": "uint16",
        "indexed": false,
        "internalType": "uint16"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomWalletOwnershipClaimedByCreator",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "creator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "accumulatedFees",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AtomWalletOwnershipGranted",
    "inputs": [
      {
        "name": "atomId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "operator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ClaimCapWindowSet",
    "inputs": [
      {
        "name": "oldValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "newValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ClaimNonceIncremented",
    "inputs": [
      {
        "name": "claimant",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newNonce",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ClaimWindowSet",
    "inputs": [
      {
        "name": "oldValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "newValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "EIP712DomainChanged",
    "inputs": [],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxClaimsPerWindowSet",
    "inputs": [
      {
        "name": "oldValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "newValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxValidAfterSet",
    "inputs": [
      {
        "name": "oldValue",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      },
      {
        "name": "newValue",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxValidUntilSet",
    "inputs": [
      {
        "name": "oldValue",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      },
      {
        "name": "newValue",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MinFeeThresholdSet",
    "inputs": [
      {
        "name": "oldValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "newValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MultiVaultSet",
    "inputs": [
      {
        "name": "multiVault",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Paused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "SignatureThresholdSet",
    "inputs": [
      {
        "name": "oldValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "newValue",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Unpaused",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AccessControlBadConfirmation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AccessControlUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "neededRole",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "AtomWarden_AlreadyClaimed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_ArrayLengthMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_AtomIdDoesNotExist",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_AtomWalletNotDeployed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_BatchTooLarge",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_ClaimCapExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_ClaimOwnershipFailed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_ClaimWindowNotElapsed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_CreatorClaimDisabled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_CreatorUnknown",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_InsufficientSigners",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_InvalidAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_InvalidClaimCapWindow",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_InvalidNewOwnerAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_InvalidNonce",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_InvalidSignature",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_InvalidThreshold",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_InvalidTimeWindow",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_MinFeeThresholdNotMet",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_NonCanonicalSignerOrder",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_NotAtomCreator",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_SignatureLengthInvalid",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_UnauthorizedClaimant",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_UnauthorizedReinitializer",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AtomWarden_ValidityWindowTooLong",
    "inputs": []
  },
  {
    "type": "error",
    "name": "EnforcedPause",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ExpectedPause",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "StringsInsufficientHexLength",
    "inputs": [
      {
        "name": "value",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "length",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  }
];

// abis/Trust.ts
var TrustAbi = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "DEFAULT_ADMIN_ROLE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MAX_SUPPLY",
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
    "name": "MINTER_A",
    "inputs": [],
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
    "name": "MINTER_B",
    "inputs": [],
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
    "name": "allowance",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
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
    "name": "approve",
    "inputs": [
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "balanceOf",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
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
    "name": "baseEmissionsController",
    "inputs": [],
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
    "name": "burn",
    "inputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "decimals",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "decreaseAllowance",
    "inputs": [
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "subtractedValue",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getRoleAdmin",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "grantRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "hasRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
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
    "name": "increaseAllowance",
    "inputs": [
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "addedValue",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "init",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "mint",
    "inputs": [
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "minterAmountMinted",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
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
    "name": "name",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "reinitialize",
    "inputs": [
      {
        "name": "_admin",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_baseEmissionsController",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "revokeRole",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setBaseEmissionsController",
    "inputs": [
      {
        "name": "newBaseEmissionsController",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "supportsInterface",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "bytes4",
        "internalType": "bytes4"
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
    "name": "symbol",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalMinted",
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
    "name": "totalSupply",
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
    "name": "transfer",
    "inputs": [
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "transferFrom",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "Approval",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "spender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "value",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "BaseEmissionsControllerSet",
    "inputs": [
      {
        "name": "newBaseEmissionsController",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleAdminChanged",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "previousAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "newAdminRole",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleGranted",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RoleRevoked",
    "inputs": [
      {
        "name": "role",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "sender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Transfer",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "value",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "ExceedsMinterCap",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ExceedsTotalSupply",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotAllowedToMint",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Trust_OnlyBaseEmissionsController",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Trust_ZeroAddress",
    "inputs": []
  }
];

// abis/TrustToken.ts
var TrustTokenAbi = [
  {
    "type": "function",
    "name": "MAX_SUPPLY",
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
    "name": "MINTER_A",
    "inputs": [],
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
    "name": "MINTER_B",
    "inputs": [],
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
    "name": "allowance",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
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
    "name": "approve",
    "inputs": [
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "balanceOf",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
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
    "name": "decimals",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "decreaseAllowance",
    "inputs": [
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "subtractedValue",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "increaseAllowance",
    "inputs": [
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "addedValue",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "init",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "mint",
    "inputs": [
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "minterAmountMinted",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
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
    "name": "name",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "symbol",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalMinted",
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
    "name": "totalSupply",
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
    "name": "transfer",
    "inputs": [
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "transferFrom",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "Approval",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "spender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "value",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Transfer",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "value",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "ExceedsMinterCap",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ExceedsTotalSupply",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotAllowedToMint",
    "inputs": []
  }
];

// abis/WrappedTrust.ts
var WrappedTrustAbi = [
  {
    "type": "receive",
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "allowance",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
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
    "name": "approve",
    "inputs": [
      {
        "name": "spender",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "balanceOf",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
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
    "name": "decimals",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "deposit",
    "inputs": [],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "name",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "symbol",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "totalSupply",
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
    "name": "transfer",
    "inputs": [
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "transferFrom",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "withdraw",
    "inputs": [
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "Approval",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "spender",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Deposit",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Transfer",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "to",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Withdrawal",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
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
  }
];

// abis/MultiVaultLib.ts
var MultiVaultLibAbi = [
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
        "name": "assetsAfterFixedFees",
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
        "name": "assetsAfterMinSharesCost",
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
        "name": "assetsAfterFixedFees",
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
        "name": "sender",
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
        "name": "amount",
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
        "name": "amount",
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
        "name": "shares",
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
        "name": "assets",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "fees",
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
        "name": "termId",
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
        "name": "termId",
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
];

// bytecodes/MultiVault.ts
var MultiVaultBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b6159bf806100d65f395ff3fe608060405260043610610671575f3560e01c8063844cc15711610348578063c69f03bc116101bd578063e9576f23116100fd578063f679bf091161009d578063f9d320da11610078578063f9d320da146116ad578063fa321611146116cc578063fc4a75f81461175b578063fccc28131461177a575f5ffd5b8063f679bf091461165c578063f7e7d1fd1461166f578063f87d29ac1461168e575f5ffd5b8063f22df312116100d8578063f22df312146115a1578063f5719008146115c0578063f5da42f3146115df578063f5e6bfb914611631575f5ffd5b8063e9576f2314611501578063ecedd54114611520578063ee3abe3814611553575f5ffd5b8063d38119ef11610168578063dea9423a11610143578063dea9423a14611474578063df62fa8814611487578063e63ab1e91461149a578063e731a481146114cd575f5ffd5b8063d38119ef146113f1578063d547741f14611422578063d91c360b14611441575f5ffd5b8063cfdbf25411610198578063cfdbf25414611359578063d33219b41461136d578063d34ddc051461138c575f5ffd5b8063c69f03bc146112fc578063c8b179281461131b578063c9cedcd01461133a575f5ffd5b8063a18dc31911610288578063ab19bcd411610233578063bb0b5ebb1161020e578063bb0b5ebb14611280578063bdacb3031461129f578063c12f7947146112be578063c5a90945146112dd575f5ffd5b8063ab19bcd414611239578063b15d757814611258578063b7a9f5b21461126b575f5ffd5b8063a3bb4f6e11610263578063a3bb4f6e146111c5578063a3d81fdc14611207578063a814c1fe14611226575f5ffd5b8063a18dc31914611174578063a217fddf14611193578063a3a9f885146111a6575f5ffd5b806391d14854116102f3578063983dda1e116102ce578063983dda1e1461104b5780639c93ef961461106a5780639e4cb31114611136578063a0ae55c714611155575f5ffd5b806391d1485414610f2a578063927a97a114610f8d578063970a5fc514611018575f5ffd5b806385a095c41161032357806385a095c414610eb45780638938639f14610edf5780638bb444bc14610efe575f5ffd5b8063844cc15714610e505780638456cb5914610e8357806384e100db14610e97575f5ffd5b806344fcc1f1116104e957806362b3bd4a11610429578063768bc3e2116103c95780637d4eaa91116103a45780637d4eaa9114610dd95780637e66abfd14610df85780637e6c54db14610e175780637f833f0414610e36575f5ffd5b8063768bc3e214610d7c5780637762b6a614610d9b5780637a9d980f14610dc6575f5ffd5b80636961cd1c116104045780636961cd1c14610cff5780636ced5d3f14610d2b57806372188e3f14610d4a5780637667180814610d68575f5ffd5b806362b3bd4a14610c9e578063678eae2314610cb25780636828caa614610ce0575f5ffd5b80635b6dd6bc116104945780635ecb42451161046f5780635ecb424514610c225780636001ab6814610c4d5780636140330914610c6c57806362a80f3d14610c7f575f5ffd5b80635b6dd6bc14610b9a5780635b7946f114610bcd5780635c975abb14610bec575f5ffd5b80634656c5f1116104c45780634656c5f114610b1257806347bf425214610b3157806358717e0d14610b7b575f5ffd5b806344fcc1f114610a855780634523e2bc14610abb57806345ab471614610ada575f5ffd5b80632747a57e116105b457806333332d391161055f5780633c6bbf451161053a5780633c6bbf45146109fd5780633e27173c14610a1d5780633f4ba83a14610a5e5780634342e96614610a72575f5ffd5b806333332d39146109aa57806336568abe146109be5780633696ac72146109dd575f5ffd5b80632eddd6771161058f5780632eddd677146109375780632f2ff15d146109785780632fb1d27014610997575f5ffd5b80632747a57e146108bf5780632db27075146108f95780632e1aa0f214610918575f5ffd5b80631a2385de1161061f5780631fdc812e116105fa5780631fdc812e14610806578063218e250d14610834578063248a9ca31461085357806324e73572146108a0575f5ffd5b80631a2385de146107a25780631e19e2c8146107c15780631f5575fb146107db575f5ffd5b80630f924db71161064f5780630f924db7146106ff578063139d4fa51461074b57806313ee9df41461076c575f5ffd5b806301a217601461067557806301ffc9a7146106ae5780630d65c91c146106dd575b5f5ffd5b348015610680575f5ffd5b5061069461068f366004614790565b61178f565b604080519283526020830191909152015b60405180910390f35b3480156106b9575f5ffd5b506106cd6106c83660046147b0565b6117b7565b60405190151581526020016106a5565b3480156106e8575f5ffd5b506106f161184f565b6040519081526020016106a5565b34801561070a575f5ffd5b506107336107193660046147ef565b5f908152602360205260409020546001600160a01b031690565b6040516001600160a01b0390911681526020016106a5565b348015610756575f5ffd5b5061076a610765366004614909565b61185d565b005b348015610777575f5ffd5b506107806118dc565b60408051825181526020808401519082015291810151908201526060016106a5565b3480156107ad575f5ffd5b506106f16107bc366004614790565b611922565b3480156107cc575f5ffd5b50600b54600c54610694919082565b3480156107e6575f5ffd5b506106f16107f53660046147ef565b601c6020525f908152604090205481565b348015610811575f5ffd5b506106cd6108203660046147ef565b5f9081526018602052604090205460ff1690565b34801561083f575f5ffd5b5061073361084e3660046147ef565b6119be565b34801561085e575f5ffd5b506106f161086d3660046147ef565b5f9081527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015490565b3480156108ab575f5ffd5b5061076a6108ba366004614952565b6119c8565b3480156108ca575f5ffd5b506108de6108d9366004614790565b611a1c565b604080519384526020840192909252908201526060016106a5565b348015610904575f5ffd5b5061069461091336600461496c565b611ac2565b348015610923575f5ffd5b506106f161093236600461496c565b611c33565b348015610942575f5ffd5b506040805180820182525f80825260209182015281518083019092526009548252600a54908201525b6040516106a59190614995565b348015610983575f5ffd5b5061076a6109923660046149ac565b611c98565b6106f16109a53660046149da565b611ce1565b3480156109b5575f5ffd5b506106f1611ddb565b3480156109c9575f5ffd5b5061076a6109d83660046149ac565b611de4565b6109f06109eb366004614a53565b611e35565b6040516106a59190614aed565b610a10610a0b366004614b6e565b61206d565b6040516106a59190614c3c565b348015610a28575f5ffd5b506106f1610a37366004614c7e565b6001600160a01b03919091165f908152601f60209081526040808320938352929052205490565b348015610a69575f5ffd5b5061076a612145565b61076a610a80366004614ca8565b612162565b348015610a90575f5ffd5b506106f1610a9f366004614c7e565b601f60209081525f928352604080842090915290825290205481565b348015610ac6575f5ffd5b506106f1610ad536600461496c565b6122c0565b348015610ae5575f5ffd5b506040805180820182525f8082526020918201528151808301909252600b548252600c549082015261096b565b348015610b1d575f5ffd5b506106cd610b2c366004614cd7565b612420565b348015610b3c575f5ffd5b50610b64610b4b3660046147ef565b60246020525f908152604090205465ffffffffffff1681565b60405165ffffffffffff90911681526020016106a5565b348015610b86575f5ffd5b506106f1610b9536600461496c565b6124be565b348015610ba5575f5ffd5b506106f1610bb4366004614d03565b6001600160a01b03165f90815260208052604090205490565b348015610bd8575f5ffd5b5061076a610be7366004614d75565b61258f565b348015610bf7575f5ffd5b507fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff166106cd565b348015610c2d575f5ffd5b506106f1610c3c366004614d03565b601d6020525f908152604090205481565b348015610c58575f5ffd5b506106f1610c673660046147ef565b6125ed565b610a10610c7a366004614a53565b6125fd565b348015610c8a575f5ffd5b506106f1610c993660046147ef565b612696565b348015610ca9575f5ffd5b506106f15f5481565b348015610cbd575f5ffd5b506106cd610ccc3660046147ef565b60216020525f908152604090205460ff1681565b348015610ceb575f5ffd5b506106f1610cfa366004614d8f565b6126a0565b348015610d0a575f5ffd5b50610d1e610d193660046147ef565b6126aa565b6040516106a59190614e23565b348015610d36575f5ffd5b506106f1610d45366004614e35565b612749565b348015610d55575f5ffd5b506011546012546013546108de92919083565b348015610d73575f5ffd5b506106f16127b2565b348015610d87575f5ffd5b506106f1610d963660046147ef565b6127bb565b348015610da6575f5ffd5b506106f1610db53660046147ef565b601e6020525f908152604090205481565b610a10610dd4366004614e67565b6127ca565b348015610de4575f5ffd5b50610694610df336600461496c565b6128a5565b348015610e03575f5ffd5b5061076a610e12366004614f5c565b612a2a565b348015610e22575f5ffd5b5061076a610e31366004615098565b612b0d565b348015610e41575f5ffd5b50600954600a54610694919082565b348015610e5b575f5ffd5b506106f17f23ad11f0a1505378b82984192ad0461e6a012820fc5bf2e4ba16513f8e43055281565b348015610e8e575f5ffd5b5061076a612ca6565b348015610ea2575f5ffd5b50600e546001600160a01b0316610733565b348015610ebf575f5ffd5b506106f1610ece3660046147ef565b5f9081526019602052604090205490565b348015610eea575f5ffd5b506106f1610ef936600461496c565b612ce0565b348015610f09575f5ffd5b50610f1d610f183660046147ef565b612d4e565b6040516106a59190615141565b348015610f35575f5ffd5b506106cd610f443660046149ac565b5f9182527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408084206001600160a01b0393909316845291905290205460ff1690565b348015610f98575f5ffd5b50600154600254600354600454600554600654600754600854610fcd976001600160a01b039081169781169695169392919088565b604080516001600160a01b03998a1681529789166020890152870195909552959092166060850152608084015260a083015260c082019290925260e0810191909152610100016106a5565b348015611023575f5ffd5b50610b646110323660046147ef565b5f9081526024602052604090205465ffffffffffff1690565b348015611056575f5ffd5b5061076a61106536600461515b565b612d58565b348015611075575f5ffd5b506110db604080516080810182525f8082526020820181905291810182905260608101919091525060408051608081018252600d546001600160a01b039081168252600e5481166020830152600f54811692820192909252601054909116606082015290565b6040516106a591905f6080820190506001600160a01b0383511682526001600160a01b0360208401511660208301526001600160a01b0360408401511660408301526001600160a01b03606084015116606083015292915050565b348015611141575f5ffd5b50610d1e6111503660046147ef565b612e0b565b348015611160575f5ffd5b506106cd61116f366004614cd7565b612e16565b34801561117f575f5ffd5b506108de61118e3660046147ef565b612e79565b34801561119e575f5ffd5b506106f15f81565b3480156111b1575f5ffd5b5061076a6111c03660046147ef565b612eed565b3480156111d0575f5ffd5b506014546015546111e8916001600160a01b03169082565b604080516001600160a01b0390931683526020830191909152016106a5565b348015611212575f5ffd5b5061076a6112213660046147ef565b613063565b6106f1611234366004615175565b61311a565b348015611244575f5ffd5b506106cd611253366004614cd7565b61320d565b610a106112663660046151b5565b613270565b348015611276575f5ffd5b506106f160255481565b34801561128b575f5ffd5b506106f161129a366004614c7e565b613345565b3480156112aa575f5ffd5b5061076a6112b9366004614d03565b613366565b3480156112c9575f5ffd5b506108de6112d83660046147ef565b613377565b3480156112e8575f5ffd5b506108de6112f7366004614790565b61342e565b348015611307575f5ffd5b506106f16113163660046147ef565b61348c565b348015611326575f5ffd5b5061076a611335366004615266565b61349c565b348015611345575f5ffd5b506106f16113543660046147ef565b61353f565b348015611364575f5ffd5b506106f1609681565b348015611378575f5ffd5b50602254610733906001600160a01b031681565b348015611397575f5ffd5b50600d54600e54600f546010546113be936001600160a01b03908116938116928116911684565b604080516001600160a01b03958616815293851660208501529184169183019190915290911660608201526080016106a5565b3480156113fc575f5ffd5b50611405613549565b6040805163ffffffff9384168152929091166020830152016106a5565b34801561142d575f5ffd5b5061076a61143c3660046149ac565b6135ab565b34801561144c575f5ffd5b506106f17fc50959b2b0264fed58f3489f13cdf8345df0911245cc2b741070787ee7aceaa281565b610a10611482366004614e67565b6135ee565b610a10611495366004615281565b61362b565b3480156114a5575f5ffd5b506106f17f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a81565b3480156114d8575f5ffd5b506107336114e73660046147ef565b60236020525f90815260409020546001600160a01b031681565b34801561150c575f5ffd5b506106cd61151b3660046147ef565b6136c6565b34801561152b575f5ffd5b506106f17fe7cbc1eb0e9b3f8688b0bc91a8278f7d2867f14f2a10dc3f0d9fcfdc32dada1281565b34801561155e575f5ffd5b506106f161156d366004614e35565b5f828152601b6020908152604080832084845282528083206001600160a01b03871684526002019091529020549392505050565b3480156115ac575f5ffd5b5061076a6115bb366004614952565b6136db565b3480156115cb575f5ffd5b506106cd6115da3660046147ef565b613728565b3480156115ea575f5ffd5b506040805180820182525f808252602091820152815180830183526014546001600160a01b03168082526015549183019182528351908152905191810191909152016106a5565b34801561163c575f5ffd5b506106f161164b3660046147ef565b5f908152601e602052604090205490565b610a1061166a366004614e67565b6137b5565b34801561167a575f5ffd5b5061076a611689366004614d03565b61382f565b348015611699575f5ffd5b506106f16116a8366004614c7e565b61399a565b3480156116b8575f5ffd5b506106f16116c73660046147ef565b6139fc565b3480156116d7575f5ffd5b506116e0613a0c565b6040516106a591905f610100820190506001600160a01b0383511682526001600160a01b036020840151166020830152604083015160408301526001600160a01b0360608401511660608301526080830151608083015260a083015160a083015260c083015160c083015260e083015160e083015292915050565b348015611766575f5ffd5b506106cd6117753660046147ef565b613ac5565b348015611785575f5ffd5b5061073361dead81565b5f828152601b60209081526040808320848452909152902080546001909101545b9250929050565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f7965db0b00000000000000000000000000000000000000000000000000000000148061184957507f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff000000000000000000000000000000000000000000000000000000008316145b92915050565b5f611858613acf565b905090565b611865613aec565b8051601480547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b03909216918217905560208083015160158190556040519081527f8e32e306972875584ae78a6586b19f2b97a9dbc1a78a73ea8ff3b207c7da23cf910160405180910390a250565b6118fd60405180606001604052805f81526020015f81526020015f81525090565b5060408051606081018252601154815260125460208201526013549181019190915290565b6040517f1a2385de00000000000000000000000000000000000000000000000000000000815260048101839052602481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90631a2385de906044015b602060405180830381865af4158015611993573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906119b79190615303565b9392505050565b5f61184982613b32565b6119d0613aec565b80516009819055602080830151600a81905560408051938452918301527f6c59cf3d8d700a9538f44d5c8acf1889183727b7cf4669f0141f7ab689bdc81091015b60405180910390a150565b6040517f01e25f3000000000000000000000000000000000000000000000000000000000815260048101839052602481018290525f908190819073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__906301e25f30906044015b606060405180830381865af4158015611a91573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611ab5919061531a565b9250925092509250925092565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018490525f90819073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015611b2d573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611b519190615345565b611b8f576040517f4762af7d000000000000000000000000000000000000000000000000000000008152600481018690526024015b60405180910390fd5b6040517fdcd2af4900000000000000000000000000000000000000000000000000000000815260048101869052602481018590526044810184905273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063dcd2af49906064016040805180830381865af4158015611c03573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611c279190615364565b91509150935093915050565b604080517f23ad11f0a1505378b82984192ad0461e6a012820fc5bf2e4ba16513f8e4305526020808301919091528183018690526060820185905260808083018590528351808403909101815260a090920190925280519101205f905b949350505050565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020526040902060010154611cd181613bbf565b611cdb8383613bc9565b50505050565b5f611cea613c95565b611cf2613cf1565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__6358a19d5e86868686611d18613d72565b6040517fffffffff0000000000000000000000000000000000000000000000000000000060e088901b1681526001600160a01b039095166004860152602485019390935260448401919091526064830152608482015260a401602060405180830381865af4158015611d8c573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611db09190615303565b9050611c9060017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f611858613dae565b6001600160a01b0381163314611e26576040517f6697b23200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611e308282613dbf565b505050565b606060ff5f5c1615611e73576040517f2578e65d00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b838214611eac576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b835f805b82811015611ee657858582818110611eca57611eca615386565b9050602002013582611edc91906153e0565b9150600101611eb0565b50348114611f20576040517f8871330400000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60015f805c60ff19168217905d508167ffffffffffffffff811115611f4757611f47614806565b604051908082528060200260200182016040528015611f7a57816020015b6060815260200190600190039081611f655790505b5092505f5b8281101561205257858582818110611f9957611f99615386565b90506020020135600181905d505f80308a8a85818110611fbb57611fbb615386565b9050602002810190611fcd91906153f3565b604051611fdb929190615454565b5f60405180830381855af49150503d805f8114612013576040519150601f19603f3d011682016040523d82523d5f602084013e612018565b606091505b50915091508161202a57805160208201fd5b8086848151811061203d5761203d615386565b60209081029190910101525050600101611f7f565b505f8060015d505f60ff19815c16815d505050949350505050565b6060612077613c95565b61207f613cf1565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__634f9a2e148a8a8a8a8a8a8a8a6120a9613d72565b6040518a63ffffffff1660e01b81526004016120cd999897969594939291906154ac565b5f60405180830381865af41580156120e7573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f1916820160405261210e9190810190615536565b905061213960017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b98975050505050505050565b5f61214f81613bbf565b612157613e63565b61215f613ebe565b50565b61216a613f2a565b612172613cf1565b336001600160a01b03831681036121b5576040517f8163594d00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f8260078111156121c8576121c8615114565b036121fe576001600160a01b038082165f908152601a60209081526040808320938716835292905220805460ff19169055612247565b81600781111561221057612210615114565b6001600160a01b038281165f908152601a60209081526040808320938816835292905220805460ff191660ff929092169190911790555b806001600160a01b0316836001600160a01b03167f82a44452b8f9b854115b84acf31076a4deb9edd2530d246cf0d96c97a6ae619b8460405161228a91906155cc565b60405180910390a3506122bc60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5050565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018490525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015612329573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061234d9190615345565b612386576040517f4762af7d00000000000000000000000000000000000000000000000000000000815260048101859052602401611b86565b6040517f4523e2bc00000000000000000000000000000000000000000000000000000000815260048101859052602481018490526044810183905273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90634523e2bc906064015b602060405180830381865af41580156123fc573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611c909190615303565b6040517f4656c5f10000000000000000000000000000000000000000000000000000000081526001600160a01b038084166004830152821660248201525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90634656c5f1906044015b602060405180830381865af415801561249a573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906119b79190615345565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018490525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015612527573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061254b9190615345565b612584576040517f4762af7d00000000000000000000000000000000000000000000000000000000815260048101859052602401611b86565b611c90848484613f69565b612597613aec565b80516011819055602080830151601281905560408085015160138190558151948552928401919091528201527f1456f0760ace81355304bceb3062ae05afa5fbb02ec5460188d98fed953e6d4190606001611a11565b5f61184982601160010154613fca565b6060612607613c95565b61260f613cf1565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63d93e991486868686612635613d72565b6040518663ffffffff1660e01b81526004016126559594939291906156c0565b5f60405180830381865af415801561266f573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f19168201604052611db09190810190615536565b5f61184982613fdc565b5f6118498261400f565b5f8181526016602052604090208054606091906126c6906156f9565b80601f01602080910402602001604051908101604052809291908181526020018280546126f2906156f9565b801561273d5780601f106127145761010080835404028352916020019161273d565b820191905f5260205f20905b81548152906001019060200180831161272057829003601f168201915b50505050509050919050565b6040517f6ced5d3f0000000000000000000000000000000000000000000000000000000081526001600160a01b038416600482015260248101839052604481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90636ced5d3f906064016123e1565b5f611858614070565b5f6118498260115f0154613fca565b60606127d4613c95565b6127dc613cf1565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63864c5fbf8b8b8b8b8b8b8b8b8b612807613d72565b6040518b63ffffffff1660e01b815260040161282c9a9998979695949392919061574a565b5f60405180830381865af4158015612846573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f1916820160405261286d9190810190615536565b905061289860017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b9998505050505050505050565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018490525f90819073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015612910573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906129349190615345565b61296d576040517f4762af7d00000000000000000000000000000000000000000000000000000000815260048101869052602401611b86565b5f612977866140dc565b6040517fd9dff30f000000000000000000000000000000000000000000000000000000008152600481018890526024810187905260448101869052811515606482015290915073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063d9dff30f90608401606060405180830381865af41580156129f7573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612a1b919061531a565b91989197509095505050505050565b612a32613aec565b63ffffffff82161580612a49575063ffffffff8116155b15612a80576040517f51af1f3e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60408051808201825263ffffffff8481168083529084166020928301819052602680547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016831764010000000083021790558351918252918101919091527f2b5bf708791497e53be4b967ae0d20fd869e30f845d57915ead6d434636546c8910160405180910390a15050565b5f612b166140fd565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f81158015612b425750825b90505f8267ffffffffffffffff166001148015612b5e5750303b155b905081158015612b6c575080155b15612ba3576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff00000000000000001660011785558315612c045784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b612c0c614125565b612c1461412d565b612c1c614125565b612c2a8b8b8b8b8b8b61413d565b8a51612c37905f90613bc9565b508315612c995784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b5050505050505050505050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a612cd081613bbf565b612cd8613c95565b61215f61420b565b604080517f23ad11f0a1505378b82984192ad0461e6a012820fc5bf2e4ba16513f8e4305526020808301919091528183018690526060820185905260808083018590528351808403909101815260a090920190925280519101205f90612d4581614266565b95945050505050565b5f611849826142a0565b612d60613aec565b8051600d80546001600160a01b039283167fffffffffffffffffffffffff00000000000000000000000000000000000000009182168117909255602080850151600e805491861691841682179055604080870151600f80549188169186168217905560608801516010805491909816951685179096555192835292917fa56701aea90c1cdd1c40fe625d4bc2f0d52b88214278fea3ae2db7b703f3681691015b60405180910390a450565b60606118498261434a565b6040517fa0ae55c70000000000000000000000000000000000000000000000000000000081526001600160a01b038084166004830152821660248201525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063a0ae55c79060440161247f565b5f81815260176020526040808220815160608101928390528392839283929160039082845b815481526020019060010190808311612e9e5750505050509050805f60038110612eca57612eca615386565b602002015181600160200201518260026020020151935093509350509193909250565b612ef5613cf1565b5f612eff82613b32565b9050336001600160a01b03821614612f43576040517f2fe8e7fc00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001600160a01b0381165f908152601d60205260409020548015613038576001600160a01b0382165f818152601d6020908152604080832083905580517f8da5cb5b0000000000000000000000000000000000000000000000000000000081529051929392638da5cb5b926004808401939192918290030181865afa158015612fce573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612ff291906157c1565b9050612ffe8183614422565b81816001600160a01b0316857f93a8f3b2bae86deadc28b666f9f65297764642ef13b22d1de09b2125e163bd8460405160405180910390a4505b505061215f60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b61306b613cf1565b5f818152601c60205260408120549081900361308757506130f1565b5f828152601c60205260408120556002546130ab906001600160a01b031682614422565b6002546040518281526001600160a01b039091169083907f0e19f21371647f79bb7c3f1e363266315b211fcca3836e7a71425cc0c4ab6a8e9060200160405180910390a3505b61215f60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f613123613f2a565b61312b613c95565b613133613cf1565b6040517fa814c1fe0000000000000000000000000000000000000000000000000000000081526001600160a01b03871660048201526024810186905260448101859052606481018490526084810183905273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063a814c1fe9060a401602060405180830381865af41580156131be573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906131e29190615303565b9050612d4560017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b6040517fab19bcd40000000000000000000000000000000000000000000000000000000081526001600160a01b038084166004830152821660248201525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063ab19bcd49060440161247f565b606061327a613c95565b613282613cf1565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63a713c75e898989898989896132ab613d72565b6040518963ffffffff1660e01b81526004016132ce9897969594939291906157dc565b5f60405180830381865af41580156132e8573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f1916820160405261330f9190810190615536565b905061333a60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b979650505050505050565b60208052815f5260405f20816003811061335d575f80fd5b01549150829050565b61336e613aec565b61215f816144c7565b5f81815260176020526040808220815160608101928390528392839283929160039082845b81548152602001906001019080831161339c57505050505090505f5f1b815f600381106133cb576133cb615386565b60200201511480156133df57506020810151155b80156133ed57506040810151155b15613427576040517f08848f3b00000000000000000000000000000000000000000000000000000000815260048101869052602401611b86565b805f612eca565b6040517f5eb53bd400000000000000000000000000000000000000000000000000000000815260048101839052602481018290525f908190819073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90635eb53bd490604401611a76565b5f61184982600b60010154613fca565b6134a4613aec565b6134ad81614568565b80606001516001600160a01b031681602001516001600160a01b0316825f01516001600160a01b03167faf8d85bc3313be057acad92fcdd8829b909273359b6a033f2f4348787b8df3f3846040015185608001518660a001518760c001518860e00151604051612e00959493929190948552602085019390935260408401919091526060830152608082015260a00190565b5f61184982614266565b6040805180820190915260265463ffffffff8082168084526401000000009092041660208301525f91829115613580578051613583565b60055b9250806020015163ffffffff165f146135a05780602001516135a4565b6102bc5b9150509091565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b62680060205260409020600101546135e481613bbf565b611cdb8383613dbf565b60606135f8613c95565b613600613cf1565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63a20efbea8b8b8b8b8b8b8b8b8b612807613d72565b6060613635613c95565b61363d613cf1565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__6323683bbd8787878787613664613d72565b6040518763ffffffff1660e01b8152600401613685969594939291906158e3565b5f60405180830381865af415801561369f573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f191682016040526131e29190810190615536565b5f818152601960205260408120541515611849565b6136e3613aec565b8051600b819055602080830151600c81905560408051938452918301527f4a883a35415345b4e144c4eb6e7a784a553b46997702b6889f682e4dea64c35f9101611a11565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015613791573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906118499190615345565b60606137bf613f2a565b6137c7613c95565b6137cf613cf1565b6040517ff679bf0900000000000000000000000000000000000000000000000000000000815273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f679bf099061282c908d908d908d908d908d908d908d908d908d9060040161592c565b5f61383981613bbf565b60025f6138446140fd565b805490915068010000000000000000900460ff16806138715750805467ffffffffffffffff808416911610155b156138a8576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b80547fffffffffffffffffffffffffffffffffffffffffffffff0000000000000000001667ffffffffffffffff831617680100000000000000001781556138ee846144c7565b600154613925907f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a906001600160a01b0316613bc9565b5061392e614070565b60255580547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16815560405167ffffffffffffffff831681527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a150505050565b6040517ff87d29ac0000000000000000000000000000000000000000000000000000000081526001600160a01b0383166004820152602481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f87d29ac90604401611978565b5f61184982601160020154613fca565b613a676040518061010001604052805f6001600160a01b031681526020015f6001600160a01b031681526020015f81526020015f6001600160a01b031681526020015f81526020015f81526020015f81526020015f81525090565b5060408051610100810182526001546001600160a01b03908116825260025481166020830152600354928201929092526004549091166060820152600554608082015260065460a082015260075460c082015260085460e082015290565b5f611849826140dc565b6006545f90613adf90600261599b565b600b5461185891906153e0565b6022546001600160a01b03163314613b30576040517f5661cf6e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b565b6040517f218e250d000000000000000000000000000000000000000000000000000000008152600481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063218e250d90602401602060405180830381865af4158015613b9b573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061184991906157c1565b61215f8133614632565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff16613c8c575f848152602082815260408083206001600160a01b03871684529091529020805460ff19166001179055613c423390565b6001600160a01b0316836001600160a01b0316857f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a46001915050611849565b5f915050611849565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff1615613b30576040517fd93c066500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b7f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0080547ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01613d6c576040517f3ee5aeb500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60029055565b5f60ff815c16613d8157503490565b5060015c90565b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b6006546009545f91611858916153e0565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff1615613c8c575f848152602082815260408083206001600160a01b0387168085529252808320805460ff1916905551339287917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a46001915050611849565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff16613b30576040517f8dfc202b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b613ec6613e63565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300805460ff191681557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516001600160a01b039091168152602001611a11565b613f32613d72565b15613b30576040517fd4d97d0100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6040517f58717e0d0000000000000000000000000000000000000000000000000000000081526004810184905260248101839052604481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__906358717e0d906064016123e1565b6003545f906119b790849084906146be565b5f818152601960205260408120541561400157505f9081526019602052604090205490565b61184982614266565b919050565b5f7fc50959b2b0264fed58f3489f13cdf8345df0911245cc2b741070787ee7aceaa28280519060200120604051602001614053929190918252602082015260400190565b604051602081830303815290604052805190602001209050919050565b5f73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63766718086040518163ffffffff1660e01b8152600401602060405180830381865af41580156140b8573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906118589190615303565b5f81815260166020526040812080546140f4906156f9565b15159392505050565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00611849565b613b306146eb565b6141356146eb565b613b30614729565b6141456146eb565b61414e86614568565b8451600955602094850151600a558351600b5592840151600c558151600d80547fffffffffffffffffffffffff00000000000000000000000000000000000000009081166001600160a01b039384161790915583860151600e80548316918416919091179055604080850151600f8054841691851691909117905560609094015160108054831691841691909117905582516011558286015160125591909201516013558251601480549092169216919091179055015160155550565b614213613c95565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300805460ff191660011781557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a25833613f12565b604080517fe7cbc1eb0e9b3f8688b0bc91a8278f7d2867f14f2a10dc3f0d9fcfdc32dada1260208201529081018290525f90606001614053565b5f5f6142ab836140dc565b5f8481526018602090815260408083205460199092529091205491925060ff16901515821580156142da575081155b80156142e4575080155b1561431e576040517fbdd4a69900000000000000000000000000000000000000000000000000000000815260048101869052602401611b86565b821561432e57505f949350505050565b801561433f57506002949350505050565b506001949350505050565b5f81815260166020526040812080546060929190614367906156f9565b80601f0160208091040260200160405190810160405280929190818152602001828054614393906156f9565b80156143de5780601f106143b5576101008083540402835291602001916143de565b820191905f5260205f20905b8154815290600101906020018083116143c157829003601f168201915b5050505050905080515f03611849576040517fb615632f00000000000000000000000000000000000000000000000000000000815260048101849052602401611b86565b80471015614465576040517fcf47918100000000000000000000000000000000000000000000000000000000815247600482015260248101829052604401611b86565b5f5f836001600160a01b0316836040515f6040518083038185875af1925050503d805f81146144af576040519150601f19603f3d011682016040523d82523d5f602084013e6144b4565b606091505b509150915081611cdb57611cdb81614731565b6001600160a01b038116614507576040517f68de5c4b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b602280547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b0383169081179091556040517f7e7ee4175d63f671fac3401d5f401ed18d1f48a586e756f404d5696fc77a7058905f90a250565b80516001600160a01b03166145a9576040517fc9f9ba1500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8051600180546001600160a01b039283167fffffffffffffffffffffffff0000000000000000000000000000000000000000918216179091556020830151600280549184169183169190911790556040830151600355606083015160048054919093169116179055608081015160055560a081015160065560c081015160075560e00151600855565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408083206001600160a01b038516845290915290205460ff166122bc576040517fe2517d3f0000000000000000000000000000000000000000000000000000000081526001600160a01b038216600482015260248101839052604401611b86565b828202831584820484141782026146dc5763ad251c275f526004601cfd5b81810615159190040192915050565b6146f3614772565b613b30576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b613d886146eb565b80511561474057805160208201fd5b6040517fd6bda27500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61477b6140fd565b5468010000000000000000900460ff16919050565b5f5f604083850312156147a1575f5ffd5b50508035926020909101359150565b5f602082840312156147c0575f5ffd5b81357fffffffff00000000000000000000000000000000000000000000000000000000811681146119b7575f5ffd5b5f602082840312156147ff575f5ffd5b5035919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b6040805190810167ffffffffffffffff8111828210171561485657614856614806565b60405290565b604051610100810167ffffffffffffffff8111828210171561485657614856614806565b604051601f8201601f1916810167ffffffffffffffff811182821017156148a9576148a9614806565b604052919050565b6001600160a01b038116811461215f575f5ffd5b803561400a816148b1565b5f604082840312156148e0575f5ffd5b6148e8614833565b905081356148f5816148b1565b815260209182013591810191909152919050565b5f60408284031215614919575f5ffd5b6119b783836148d0565b5f60408284031215614933575f5ffd5b61493b614833565b823581526020928301359281019290925250919050565b5f60408284031215614962575f5ffd5b6119b78383614923565b5f5f5f6060848603121561497e575f5ffd5b505081359360208301359350604090920135919050565b815181526020808301519082015260408101611849565b5f5f604083850312156149bd575f5ffd5b8235915060208301356149cf816148b1565b809150509250929050565b5f5f5f5f608085870312156149ed575f5ffd5b84356149f8816148b1565b966020860135965060408601359560600135945092505050565b5f5f83601f840112614a22575f5ffd5b50813567ffffffffffffffff811115614a39575f5ffd5b6020830191508360208260051b85010111156117b0575f5ffd5b5f5f5f5f60408587031215614a66575f5ffd5b843567ffffffffffffffff811115614a7c575f5ffd5b614a8887828801614a12565b909550935050602085013567ffffffffffffffff811115614aa7575f5ffd5b614ab387828801614a12565b95989497509550505050565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b5f602082016020835280845180835260408501915060408160051b8601019250602086015f5b82811015614b62577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc0878603018452614b4d858351614abf565b94506020938401939190910190600101614b13565b50929695505050505050565b5f5f5f5f5f5f5f5f6080898b031215614b85575f5ffd5b883567ffffffffffffffff811115614b9b575f5ffd5b614ba78b828c01614a12565b909950975050602089013567ffffffffffffffff811115614bc6575f5ffd5b614bd28b828c01614a12565b909750955050604089013567ffffffffffffffff811115614bf1575f5ffd5b614bfd8b828c01614a12565b909550935050606089013567ffffffffffffffff811115614c1c575f5ffd5b614c288b828c01614a12565b999c989b5096995094979396929594505050565b602080825282518282018190525f918401906040840190835b81811015614c73578351835260209384019390920191600101614c55565b509095945050505050565b5f5f60408385031215614c8f575f5ffd5b8235614c9a816148b1565b946020939093013593505050565b5f5f60408385031215614cb9575f5ffd5b8235614cc4816148b1565b91506020830135600881106149cf575f5ffd5b5f5f60408385031215614ce8575f5ffd5b8235614cf3816148b1565b915060208301356149cf816148b1565b5f60208284031215614d13575f5ffd5b81356119b7816148b1565b5f60608284031215614d2e575f5ffd5b6040516060810167ffffffffffffffff81118282101715614d5157614d51614806565b60409081528335825260208085013590830152928301359281019290925250919050565b5f60608284031215614d85575f5ffd5b6119b78383614d1e565b5f60208284031215614d9f575f5ffd5b813567ffffffffffffffff811115614db5575f5ffd5b8201601f81018413614dc5575f5ffd5b803567ffffffffffffffff811115614ddf57614ddf614806565b614df26020601f19601f84011601614880565b818152856020838501011115614e06575f5ffd5b816020840160208301375f91810160200191909152949350505050565b602081525f6119b76020830184614abf565b5f5f5f60608486031215614e47575f5ffd5b8335614e52816148b1565b95602085013595506040909401359392505050565b5f5f5f5f5f5f5f5f5f60a08a8c031215614e7f575f5ffd5b8935614e8a816148b1565b985060208a013567ffffffffffffffff811115614ea5575f5ffd5b614eb18c828d01614a12565b90995097505060408a013567ffffffffffffffff811115614ed0575f5ffd5b614edc8c828d01614a12565b90975095505060608a013567ffffffffffffffff811115614efb575f5ffd5b614f078c828d01614a12565b90955093505060808a013567ffffffffffffffff811115614f26575f5ffd5b614f328c828d01614a12565b915080935050809150509295985092959850929598565b803563ffffffff8116811461400a575f5ffd5b5f5f60408385031215614f6d575f5ffd5b614f7683614f49565b9150614f8460208401614f49565b90509250929050565b5f6101008284031215614f9e575f5ffd5b614fa661485c565b90508135614fb3816148b1565b8152614fc1602083016148c5565b602082015260408281013590820152614fdc606083016148c5565b60608201526080828101359082015260a0808301359082015260c0808301359082015260e09182013591810191909152919050565b5f60808284031215615021575f5ffd5b6040516080810167ffffffffffffffff8111828210171561504457615044614806565b6040529050808235615055816148b1565b81526020830135615065816148b1565b60208201526040830135615078816148b1565b6040820152606083013561508b816148b1565b6060919091015292915050565b5f5f5f5f5f5f6102a087890312156150ae575f5ffd5b6150b88888614f8d565b95506150c8886101008901614923565b94506150d8886101408901614923565b93506150e8886101808901615011565b92506150f8886102008901614d1e565b91506151088861026089016148d0565b90509295509295509295565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b602081016003831061515557615155615114565b91905290565b5f6080828403121561516b575f5ffd5b6119b78383615011565b5f5f5f5f5f60a08688031215615189575f5ffd5b8535615194816148b1565b97602087013597506040870135966060810135965060800135945092505050565b5f5f5f5f5f5f5f6080888a0312156151cb575f5ffd5b87356151d6816148b1565b9650602088013567ffffffffffffffff8111156151f1575f5ffd5b6151fd8a828b01614a12565b909750955050604088013567ffffffffffffffff81111561521c575f5ffd5b6152288a828b01614a12565b909550935050606088013567ffffffffffffffff811115615247575f5ffd5b6152538a828b01614a12565b989b979a50959850939692959293505050565b5f6101008284031215615277575f5ffd5b6119b78383614f8d565b5f5f5f5f5f60608688031215615295575f5ffd5b85356152a0816148b1565b9450602086013567ffffffffffffffff8111156152bb575f5ffd5b6152c788828901614a12565b909550935050604086013567ffffffffffffffff8111156152e6575f5ffd5b6152f288828901614a12565b969995985093965092949392505050565b5f60208284031215615313575f5ffd5b5051919050565b5f5f5f6060848603121561532c575f5ffd5b5050815160208301516040909301519094929350919050565b5f60208284031215615355575f5ffd5b815180151581146119b7575f5ffd5b5f5f60408385031215615375575f5ffd5b505080516020909101519092909150565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b80820180821115611849576118496153b3565b5f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1843603018112615426575f5ffd5b83018035915067ffffffffffffffff821115615440575f5ffd5b6020019150368190038213156117b0575f5ffd5b818382375f9101908152919050565b8183525f7f07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff831115615493575f5ffd5b8260051b80836020870137939093016020019392505050565b60a081525f6154bf60a083018b8d615463565b82810360208401526154d2818a8c615463565b905082810360408401526154e781888a615463565b905082810360608401526154fc818688615463565b9150508260808301529a9950505050505050505050565b5f67ffffffffffffffff82111561552c5761552c614806565b5060051b60200190565b5f60208284031215615546575f5ffd5b815167ffffffffffffffff81111561555c575f5ffd5b8201601f8101841361556c575f5ffd5b805161557f61557a82615513565b614880565b8082825260208201915060208360051b8501019250868311156155a0575f5ffd5b6020840193505b828410156155c25783518252602093840193909101906155a7565b9695505050505050565b602081016008831061515557615155615114565b81835281816020850137505f602082840101525f6020601f19601f840116840101905092915050565b5f8383855260208501945060208460051b820101835f5b868110156156b457601f198484030188525f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1893603018112615664575f5ffd5b880160208101925035905067ffffffffffffffff811115615683575f5ffd5b803603821315615691575f5ffd5b61569c8582846155e0565b60209a8b019a90955093909301925050600101615620565b50909695505050505050565b606081525f6156d3606083018789615609565b82810360208401526156e6818688615463565b9150508260408301529695505050505050565b600181811c9082168061570d57607f821691505b602082108103615744577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b6001600160a01b038b16815260c060208201525f61576c60c083018b8d615463565b828103604084015261577f818a8c615463565b9050828103606084015261579481888a615463565b905082810360808401526157a9818688615463565b9150508260a08301529b9a5050505050505050505050565b5f602082840312156157d1575f5ffd5b81516119b7816148b1565b6001600160a01b038916815260a060208201525f6157fe60a08301898b615609565b828103604084015261581181888a615463565b905082810360608401528085825260208201905060208660051b830101875f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe18a3603015b898210156158c757601f198685030185528235818112615874575f5ffd5b8b0160208101903567ffffffffffffffff811115615890575f5ffd5b8060051b36038213156158a1575f5ffd5b6158ac868284615609565b95505050602083019250602085019450600182019150615856565b5050508093505050508260808301529998505050505050505050565b6001600160a01b0387168152608060208201525f615905608083018789615609565b8281036040840152615918818688615463565b915050826060830152979650505050505050565b6001600160a01b038a16815260a060208201525f61594e60a083018a8c615463565b828103604084015261596181898b615463565b90508281036060840152615976818789615463565b9050828103608084015261598b818587615463565b9c9b505050505050505050505050565b8082028115828204841417611849576118496153b356fea164736f6c634300081d000a";
var MultiVaultLinkReferences = {
  "src/libraries/MultiVaultLib.sol:MultiVaultLib": "__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__"
};

// bytecodes/MultiVaultMigrationMode.ts
var MultiVaultMigrationModeBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b61699f806100d65f395ff3fe6080604052600436106106b6575f3560e01c80638456cb5911610369578063c8b17928116101c8578063e9576f23116100fd578063f679bf091161009d578063f9d320da11610078578063f9d320da146117c7578063fa321611146117e6578063fc4a75f814611875578063fccc281314611894575f5ffd5b8063f679bf0914611776578063f7e7d1fd14611789578063f87d29ac146117a8575f5ffd5b8063f22df312116100d8578063f22df312146116bb578063f5719008146116da578063f5da42f3146116f9578063f5e6bfb91461174b575f5ffd5b8063e9576f231461161b578063ecedd5411461163a578063ee3abe381461166d575f5ffd5b8063d91c360b11610168578063df62fa8811610143578063df62fa8814611582578063e5ef6cc414611595578063e63ab1e9146115b4578063e731a481146115e7575f5ffd5b8063d91c360b1461151d578063dbc2aaa614611550578063dea9423a1461156f575f5ffd5b8063d33219b4116101a3578063d33219b414611449578063d34ddc0514611468578063d38119ef146114cd578063d547741f146114fe575f5ffd5b8063c8b17928146113f7578063c9cedcd014611416578063cfdbf25414611435575f5ffd5b8063a18dc3191161029e578063b15d75781161023e578063bdacb30311610219578063bdacb3031461137b578063c12f79471461139a578063c5a90945146113b9578063c69f03bc146113d8575f5ffd5b8063b15d757814611334578063b7a9f5b214611347578063bb0b5ebb1461135c575f5ffd5b8063a3bb4f6e11610279578063a3bb4f6e146112a1578063a3d81fdc146112e3578063a814c1fe14611302578063ab19bcd414611315575f5ffd5b8063a18dc31914611250578063a217fddf1461126f578063a3a9f88514611282575f5ffd5b806395e3db78116103095780639c93ef96116102e45780639c93ef96146111275780639e4cb311146111f35780639f08f39514611212578063a0ae55c714611231575f5ffd5b806395e3db78146110b6578063970a5fc5146110d5578063983dda1e14611108575f5ffd5b80638938639f116103445780638938639f14610f7d5780638bb444bc14610f9c57806391d1485414610fc8578063927a97a11461102b575f5ffd5b80638456cb5914610f2157806384e100db14610f3557806385a095c414610f52575f5ffd5b80634523e2bc116105155780636828caa61161044a5780637762b6a6116103ea5780637e66abfd116103c55780637e66abfd14610e965780637e6c54db14610eb55780637f833f0414610ed4578063844cc15714610eee575f5ffd5b80637762b6a614610e395780637a9d980f14610e645780637d4eaa9114610e77575f5ffd5b80636fae2e15116104255780636fae2e1514610db557806372188e3f14610de85780637667180814610e06578063768bc3e214610e1a575f5ffd5b80636828caa614610d4b5780636961cd1c14610d6a5780636ced5d3f14610d96575f5ffd5b80635c975abb116104b557806361403309116104905780636140330914610cd757806362a80f3d14610cea57806362b3bd4a14610d09578063678eae2314610d1d575f5ffd5b80635c975abb14610c575780635ecb424514610c8d5780636001ab6814610cb8575f5ffd5b806347bf4252116104f057806347bf425214610b9c57806358717e0d14610be65780635b6dd6bc14610c055780635b7946f114610c38575f5ffd5b80634523e2bc14610b2657806345ab471614610b455780634656c5f114610b7d575f5ffd5b80632747a57e116105eb57806336568abe1161058b5780633e27173c116105665780633e27173c14610a885780633f4ba83a14610ac95780634342e96614610add57806344fcc1f114610af0575f5ffd5b806336568abe14610a295780633696ac7214610a485780633c6bbf4514610a68575f5ffd5b80632eddd677116105c65780632eddd677146109a25780632f2ff15d146109e35780632fb1d27014610a0257806333332d3914610a15575f5ffd5b80632747a57e1461092a5780632db27075146109645780632e1aa0f214610983575f5ffd5b80631a2385de116106565780631fdc812e116106315780631fdc812e14610871578063218e250d1461089f578063248a9ca3146108be57806324e735721461090b575f5ffd5b80631a2385de1461080d5780631e19e2c81461082c5780631f5575fb14610846575f5ffd5b80630f924db7116106915780630f924db71461074b578063139d4fa51461079757806313ee9df4146107b8578063192e7ffe146107ee575f5ffd5b806301a21760146106c157806301ffc9a7146106fa5780630d65c91c14610729575f5ffd5b366106bd57005b5f5ffd5b3480156106cc575f5ffd5b506106e06106db36600461537e565b6118a9565b604080519283526020830191909152015b60405180910390f35b348015610705575f5ffd5b5061071961071436600461539e565b6118d1565b60405190151581526020016106f1565b348015610734575f5ffd5b5061073d611969565b6040519081526020016106f1565b348015610756575f5ffd5b5061077f6107653660046153dd565b5f908152602360205260409020546001600160a01b031690565b6040516001600160a01b0390911681526020016106f1565b3480156107a2575f5ffd5b506107b66107b13660046154f7565b611977565b005b3480156107c3575f5ffd5b506107cc6119f6565b60408051825181526020808401519082015291810151908201526060016106f1565b3480156107f9575f5ffd5b506107b6610808366004615552565b611a3c565b348015610818575f5ffd5b5061073d61082736600461537e565b611b6f565b348015610837575f5ffd5b50600b54600c546106e0919082565b348015610851575f5ffd5b5061073d6108603660046153dd565b601c6020525f908152604090205481565b34801561087c575f5ffd5b5061071961088b3660046153dd565b5f9081526018602052604090205460ff1690565b3480156108aa575f5ffd5b5061077f6108b93660046153dd565b611c0b565b3480156108c9575f5ffd5b5061073d6108d83660046153dd565b5f9081527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015490565b348015610916575f5ffd5b506107b6610925366004615628565b611c15565b348015610935575f5ffd5b5061094961094436600461537e565b611c69565b604080519384526020840192909252908201526060016106f1565b34801561096f575f5ffd5b506106e061097e366004615642565b611d0f565b34801561098e575f5ffd5b5061073d61099d366004615642565b611e80565b3480156109ad575f5ffd5b506040805180820182525f80825260209182015281518083019092526009548252600a54908201525b6040516106f1919061566b565b3480156109ee575f5ffd5b506107b66109fd366004615682565b611ee5565b61073d610a103660046156b0565b611f2e565b348015610a20575f5ffd5b5061073d612028565b348015610a34575f5ffd5b506107b6610a43366004615682565b612031565b610a5b610a563660046156e8565b612082565b6040516106f19190615782565b610a7b610a76366004615803565b6122ba565b6040516106f191906158d1565b348015610a93575f5ffd5b5061073d610aa2366004615913565b6001600160a01b03919091165f908152601f60209081526040808320938352929052205490565b348015610ad4575f5ffd5b506107b6612392565b6107b6610aeb36600461593d565b6123af565b348015610afb575f5ffd5b5061073d610b0a366004615913565b601f60209081525f928352604080842090915290825290205481565b348015610b31575f5ffd5b5061073d610b40366004615642565b61250d565b348015610b50575f5ffd5b506040805180820182525f8082526020918201528151808301909252600b548252600c54908201526109d6565b348015610b88575f5ffd5b50610719610b9736600461596c565b61266d565b348015610ba7575f5ffd5b50610bcf610bb63660046153dd565b60246020525f908152604090205465ffffffffffff1681565b60405165ffffffffffff90911681526020016106f1565b348015610bf1575f5ffd5b5061073d610c00366004615642565b61270b565b348015610c10575f5ffd5b5061073d610c1f366004615998565b6001600160a01b03165f90815260208052604090205490565b348015610c43575f5ffd5b506107b6610c52366004615a0a565b6127dc565b348015610c62575f5ffd5b507fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff16610719565b348015610c98575f5ffd5b5061073d610ca7366004615998565b601d6020525f908152604090205481565b348015610cc3575f5ffd5b5061073d610cd23660046153dd565b61283a565b610a7b610ce53660046156e8565b61284a565b348015610cf5575f5ffd5b5061073d610d043660046153dd565b6128e3565b348015610d14575f5ffd5b5061073d5f5481565b348015610d28575f5ffd5b50610719610d373660046153dd565b60216020525f908152604090205460ff1681565b348015610d56575f5ffd5b5061073d610d65366004615a24565b6128ed565b348015610d75575f5ffd5b50610d89610d843660046153dd565b6128f7565b6040516106f19190615ab8565b348015610da1575f5ffd5b5061073d610db0366004615aca565b612996565b348015610dc0575f5ffd5b5061073d7f600e5f1c60beb469a3fa6dd3814a4ae211cc6259a6d033bae218a742f2af01d381565b348015610df3575f5ffd5b5060115460125460135461094992919083565b348015610e11575f5ffd5b5061073d6129ff565b348015610e25575f5ffd5b5061073d610e343660046153dd565b612a08565b348015610e44575f5ffd5b5061073d610e533660046153dd565b601e6020525f908152604090205481565b610a7b610e72366004615afc565b612a17565b348015610e82575f5ffd5b506106e0610e91366004615642565b612af2565b348015610ea1575f5ffd5b506107b6610eb0366004615bf1565b612c77565b348015610ec0575f5ffd5b506107b6610ecf366004615d2d565b612d5a565b348015610edf575f5ffd5b50600954600a546106e0919082565b348015610ef9575f5ffd5b5061073d7f23ad11f0a1505378b82984192ad0461e6a012820fc5bf2e4ba16513f8e43055281565b348015610f2c575f5ffd5b506107b6612ef3565b348015610f40575f5ffd5b50600e546001600160a01b031661077f565b348015610f5d575f5ffd5b5061073d610f6c3660046153dd565b5f9081526019602052604090205490565b348015610f88575f5ffd5b5061073d610f97366004615642565b612f2d565b348015610fa7575f5ffd5b50610fbb610fb63660046153dd565b612f9b565b6040516106f19190615dea565b348015610fd3575f5ffd5b50610719610fe2366004615682565b5f9182527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408084206001600160a01b0393909316845291905290205460ff1690565b348015611036575f5ffd5b5060015460025460035460045460055460065460075460085461106b976001600160a01b039081169781169695169392919088565b604080516001600160a01b03998a1681529789166020890152870195909552959092166060850152608084015260a083015260c082019290925260e0810191909152610100016106f1565b3480156110c1575f5ffd5b506107b66110d03660046156e8565b612fa5565b3480156110e0575f5ffd5b50610bcf6110ef3660046153dd565b5f9081526024602052604090205465ffffffffffff1690565b348015611113575f5ffd5b506107b6611122366004615df8565b61315c565b348015611132575f5ffd5b50611198604080516080810182525f8082526020820181905291810182905260608101919091525060408051608081018252600d546001600160a01b039081168252600e5481166020830152600f54811692820192909252601054909116606082015290565b6040516106f191905f6080820190506001600160a01b0383511682526001600160a01b0360208401511660208301526001600160a01b0360408401511660408301526001600160a01b03606084015116606083015292915050565b3480156111fe575f5ffd5b50610d8961120d3660046153dd565b61320f565b34801561121d575f5ffd5b506107b661122c366004615e12565b61321a565b34801561123c575f5ffd5b5061071961124b36600461596c565b613610565b34801561125b575f5ffd5b5061094961126a3660046153dd565b613673565b34801561127a575f5ffd5b5061073d5f81565b34801561128d575f5ffd5b506107b661129c3660046153dd565b6136e7565b3480156112ac575f5ffd5b506014546015546112c4916001600160a01b03169082565b604080516001600160a01b0390931683526020830191909152016106f1565b3480156112ee575f5ffd5b506107b66112fd3660046153dd565b61385d565b61073d611310366004615e49565b613914565b348015611320575f5ffd5b5061071961132f36600461596c565b613a07565b610a7b611342366004615e89565b613a6a565b348015611352575f5ffd5b5061073d60255481565b348015611367575f5ffd5b5061073d611376366004615913565b613b3f565b348015611386575f5ffd5b506107b6611395366004615998565b613b60565b3480156113a5575f5ffd5b506109496113b43660046153dd565b613b71565b3480156113c4575f5ffd5b506109496113d336600461537e565b613c28565b3480156113e3575f5ffd5b5061073d6113f23660046153dd565b613c86565b348015611402575f5ffd5b506107b6611411366004615f3a565b613c96565b348015611421575f5ffd5b5061073d6114303660046153dd565b613d39565b348015611440575f5ffd5b5061073d609681565b348015611454575f5ffd5b5060225461077f906001600160a01b031681565b348015611473575f5ffd5b50600d54600e54600f5460105461149a936001600160a01b03908116938116928116911684565b604080516001600160a01b03958616815293851660208501529184169183019190915290911660608201526080016106f1565b3480156114d8575f5ffd5b506114e1613d43565b6040805163ffffffff9384168152929091166020830152016106f1565b348015611509575f5ffd5b506107b6611518366004615682565b613da5565b348015611528575f5ffd5b5061073d7fc50959b2b0264fed58f3489f13cdf8345df0911245cc2b741070787ee7aceaa281565b34801561155b575f5ffd5b506107b661156a3660046153dd565b613de8565b610a7b61157d366004615afc565b613e17565b610a7b611590366004615f55565b613e54565b3480156115a0575f5ffd5b506107b66115af366004615fd7565b613eef565b3480156115bf575f5ffd5b5061073d7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a81565b3480156115f2575f5ffd5b5061077f6116013660046153dd565b60236020525f90815260409020546001600160a01b031681565b348015611626575f5ffd5b506107196116353660046153dd565b6141ad565b348015611645575f5ffd5b5061073d7fe7cbc1eb0e9b3f8688b0bc91a8278f7d2867f14f2a10dc3f0d9fcfdc32dada1281565b348015611678575f5ffd5b5061073d611687366004615aca565b5f828152601b6020908152604080832084845282528083206001600160a01b03871684526002019091529020549392505050565b3480156116c6575f5ffd5b506107b66116d5366004615628565b6141c2565b3480156116e5575f5ffd5b506107196116f43660046153dd565b61420f565b348015611704575f5ffd5b506040805180820182525f808252602091820152815180830183526014546001600160a01b03168082526015549183019182528351908152905191810191909152016106f1565b348015611756575f5ffd5b5061073d6117653660046153dd565b5f908152601e602052604090205490565b610a7b611784366004615afc565b61429c565b348015611794575f5ffd5b506107b66117a3366004615998565b614316565b3480156117b3575f5ffd5b5061073d6117c2366004615913565b614481565b3480156117d2575f5ffd5b5061073d6117e13660046153dd565b6144e3565b3480156117f1575f5ffd5b506117fa6144f3565b6040516106f191905f610100820190506001600160a01b0383511682526001600160a01b036020840151166020830152604083015160408301526001600160a01b0360608401511660608301526080830151608083015260a083015160a083015260c083015160c083015260e083015160e083015292915050565b348015611880575f5ffd5b5061071961188f3660046153dd565b6145ac565b34801561189f575f5ffd5b5061077f61dead81565b5f828152601b60209081526040808320848452909152902080546001909101545b9250929050565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f7965db0b00000000000000000000000000000000000000000000000000000000148061196357507f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff000000000000000000000000000000000000000000000000000000008316145b92915050565b5f6119726145b6565b905090565b61197f6145d3565b8051601480547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b03909216918217905560208083015160158190556040519081527f8e32e306972875584ae78a6586b19f2b97a9dbc1a78a73ea8ff3b207c7da23cf910160405180910390a250565b611a1760405180606001604052805f81526020015f81526020015f81525090565b5060408051606081018252601154815260125460208201526013549181019190915290565b7f600e5f1c60beb469a3fa6dd3814a4ae211cc6259a6d033bae218a742f2af01d3611a6681614619565b835f03611a9f576040517f3ddd53eb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84828114611ad9576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b81811015611b6557611b5d888883818110611af857611af8616073565b9050602002013587878785818110611b1257611b12616073565b9050604002015f0135888886818110611b2d57611b2d616073565b90506040020160200135611b588d8d88818110611b4c57611b4c616073565b90506020020135614623565b6146cd565b600101611adb565b5050505050505050565b6040517f1a2385de00000000000000000000000000000000000000000000000000000000815260048101839052602481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90631a2385de906044015b602060405180830381865af4158015611be0573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611c0491906160a0565b9392505050565b5f61196382614758565b611c1d6145d3565b80516009819055602080830151600a81905560408051938452918301527f6c59cf3d8d700a9538f44d5c8acf1889183727b7cf4669f0141f7ab689bdc81091015b60405180910390a150565b6040517f01e25f3000000000000000000000000000000000000000000000000000000000815260048101839052602481018290525f908190819073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__906301e25f30906044015b606060405180830381865af4158015611cde573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611d0291906160b7565b9250925092509250925092565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018490525f90819073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015611d7a573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611d9e91906160e2565b611ddc576040517f4762af7d000000000000000000000000000000000000000000000000000000008152600481018690526024015b60405180910390fd5b6040517fdcd2af4900000000000000000000000000000000000000000000000000000000815260048101869052602481018590526044810184905273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063dcd2af49906064016040805180830381865af4158015611e50573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611e749190616101565b91509150935093915050565b604080517f23ad11f0a1505378b82984192ad0461e6a012820fc5bf2e4ba16513f8e4305526020808301919091528183018690526060820185905260808083018590528351808403909101815260a090920190925280519101205f905b949350505050565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020526040902060010154611f1e81614619565b611f2883836147e5565b50505050565b5f611f376148b1565b611f3f61490d565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__6358a19d5e86868686611f6561498e565b6040517fffffffff0000000000000000000000000000000000000000000000000000000060e088901b1681526001600160a01b039095166004860152602485019390935260448401919091526064830152608482015260a401602060405180830381865af4158015611fd9573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611ffd91906160a0565b9050611edd60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f6119726149ca565b6001600160a01b0381163314612073576040517f6697b23200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61207d82826149db565b505050565b606060ff5f5c16156120c0576040517f2578e65d00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8382146120f9576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b835f805b828110156121335785858281811061211757612117616073565b90506020020135826121299190616150565b91506001016120fd565b5034811461216d576040517f8871330400000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60015f805c60ff19168217905d508167ffffffffffffffff811115612194576121946153f4565b6040519080825280602002602001820160405280156121c757816020015b60608152602001906001900390816121b25790505b5092505f5b8281101561229f578585828181106121e6576121e6616073565b90506020020135600181905d505f80308a8a8581811061220857612208616073565b905060200281019061221a9190616163565b6040516122289291906161c4565b5f60405180830381855af49150503d805f8114612260576040519150601f19603f3d011682016040523d82523d5f602084013e612265565b606091505b50915091508161227757805160208201fd5b8086848151811061228a5761228a616073565b602090810291909101015250506001016121cc565b505f8060015d505f60ff19815c16815d505050949350505050565b60606122c46148b1565b6122cc61490d565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__634f9a2e148a8a8a8a8a8a8a8a6122f661498e565b6040518a63ffffffff1660e01b815260040161231a9998979695949392919061621c565b5f60405180830381865af4158015612334573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f1916820160405261235b91908101906162a6565b905061238660017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b98975050505050505050565b5f61239c81614619565b6123a4614a7f565b6123ac614ada565b50565b6123b7614b46565b6123bf61490d565b336001600160a01b0383168103612402576040517f8163594d00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f82600781111561241557612415615da9565b0361244b576001600160a01b038082165f908152601a60209081526040808320938716835292905220805460ff19169055612494565b81600781111561245d5761245d615da9565b6001600160a01b038281165f908152601a60209081526040808320938816835292905220805460ff191660ff929092169190911790555b806001600160a01b0316836001600160a01b03167f82a44452b8f9b854115b84acf31076a4deb9edd2530d246cf0d96c97a6ae619b846040516124d7919061633c565b60405180910390a35061250960017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5050565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018490525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015612576573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061259a91906160e2565b6125d3576040517f4762af7d00000000000000000000000000000000000000000000000000000000815260048101859052602401611dd3565b6040517f4523e2bc00000000000000000000000000000000000000000000000000000000815260048101859052602481018490526044810183905273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90634523e2bc906064015b602060405180830381865af4158015612649573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611edd91906160a0565b6040517f4656c5f10000000000000000000000000000000000000000000000000000000081526001600160a01b038084166004830152821660248201525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90634656c5f1906044015b602060405180830381865af41580156126e7573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611c0491906160e2565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018490525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015612774573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061279891906160e2565b6127d1576040517f4762af7d00000000000000000000000000000000000000000000000000000000815260048101859052602401611dd3565b611edd848484614b85565b6127e46145d3565b80516011819055602080830151601281905560408085015160138190558151948552928401919091528201527f1456f0760ace81355304bceb3062ae05afa5fbb02ec5460188d98fed953e6d4190606001611c5e565b5f61196382601160010154614be6565b60606128546148b1565b61285c61490d565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63d93e99148686868661288261498e565b6040518663ffffffff1660e01b81526004016128a2959493929190616436565b5f60405180830381865af41580156128bc573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f19168201604052611ffd91908101906162a6565b5f61196382614bf8565b5f61196382614c2b565b5f8181526016602052604090208054606091906129139061646f565b80601f016020809104026020016040519081016040528092919081815260200182805461293f9061646f565b801561298a5780601f106129615761010080835404028352916020019161298a565b820191905f5260205f20905b81548152906001019060200180831161296d57829003601f168201915b50505050509050919050565b6040517f6ced5d3f0000000000000000000000000000000000000000000000000000000081526001600160a01b038416600482015260248101839052604481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90636ced5d3f9060640161262e565b5f611972614c8c565b5f6119638260115f0154614be6565b6060612a216148b1565b612a2961490d565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63864c5fbf8b8b8b8b8b8b8b8b8b612a5461498e565b6040518b63ffffffff1660e01b8152600401612a799a999897969594939291906164c0565b5f60405180830381865af4158015612a93573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f19168201604052612aba91908101906162a6565b9050612ae560017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b9998505050505050505050565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018490525f90819073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015612b5d573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612b8191906160e2565b612bba576040517f4762af7d00000000000000000000000000000000000000000000000000000000815260048101869052602401611dd3565b5f612bc486614cf8565b6040517fd9dff30f000000000000000000000000000000000000000000000000000000008152600481018890526024810187905260448101869052811515606482015290915073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063d9dff30f90608401606060405180830381865af4158015612c44573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612c6891906160b7565b91989197509095505050505050565b612c7f6145d3565b63ffffffff82161580612c96575063ffffffff8116155b15612ccd576040517f51af1f3e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60408051808201825263ffffffff8481168083529084166020928301819052602680547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016831764010000000083021790558351918252918101919091527f2b5bf708791497e53be4b967ae0d20fd869e30f845d57915ead6d434636546c8910160405180910390a15050565b5f612d63614d19565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f81158015612d8f5750825b90505f8267ffffffffffffffff166001148015612dab5750303b155b905081158015612db9575080155b15612df0576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff00000000000000001660011785558315612e515784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b612e59614d41565b612e61614d49565b612e69614d41565b612e778b8b8b8b8b8b614d59565b8a51612e84905f906147e5565b508315612ee65784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b5050505050505050505050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a612f1d81614619565b612f256148b1565b6123ac614e27565b604080517f23ad11f0a1505378b82984192ad0461e6a012820fc5bf2e4ba16513f8e4305526020808301919091528183018690526060820185905260808083018590528351808403909101815260a090920190925280519101205f90612f9281614e82565b95945050505050565b5f61196382614623565b7f600e5f1c60beb469a3fa6dd3814a4ae211cc6259a6d033bae218a742f2af01d3612fcf81614619565b81848114613009576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b81811015613153575f61307486868481811061302957613029616073565b905060200281019061303b9190616163565b8080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250614c2b92505050565b905085858381811061308857613088616073565b905060200281019061309a9190616163565b5f838152601660205260409020916130b3919083616582565b50808888848181106130c7576130c7616073565b90506020020160208101906130dc9190615998565b6001600160a01b03167ffd579ad7468b1720e08f84efe16900074f3ffdaaeaa82e675e5aec69bf39318988888681811061311857613118616073565b905060200281019061312a9190616163565b61313386614758565b6040516131429392919061667a565b60405180910390a35060010161300b565b50505050505050565b6131646145d3565b8051600d80546001600160a01b039283167fffffffffffffffffffffffff00000000000000000000000000000000000000009182168117909255602080850151600e805491861691841682179055604080870151600f80549188169186168217905560608801516010805491909816951685179096555192835292917fa56701aea90c1cdd1c40fe625d4bc2f0d52b88214278fea3ae2db7b703f3681691015b60405180910390a450565b606061196382614ebc565b7f600e5f1c60beb469a3fa6dd3814a4ae211cc6259a6d033bae218a742f2af01d361324481614619565b81602001355f03613281576040517f3ddd53eb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61328f60408401846166a6565b9150508015806132aa57506132a483806166a6565b90508114155b806132c357506132bd60608401846166a6565b90508114155b156132fa576040517f92cbb3c900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b81811015611f28575f61331260408601866166a6565b8381811061332257613322616073565b90506020020160208101906133379190615998565b6001600160a01b031603613377576040517f68de5c4b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b365f61338386806166a6565b8481811061339357613393616073565b90506020028101906133a591906166a6565b9092509050365f6133b960608901896166a6565b868181106133c9576133c9616073565b90506020028101906133db91906166a6565b9092509050828114613419576040517f92cbb3c900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b838110156136005782828281811061343557613435616073565b90506020020135601b5f87878581811061345157613451616073565b9050602002013581526020019081526020015f205f8b6020013581526020019081526020015f206002015f8b806040019061348c91906166a6565b8a81811061349c5761349c616073565b90506020020160208101906134b19190615998565b6001600160a01b03166001600160a01b031681526020019081526020015f20819055505f6135148686848181106134ea576134ea616073565b905060200201358b6020013586868681811061350857613508616073565b90506020020135614b85565b905085858381811061352857613528616073565b905060200201358a806040019061353f91906166a6565b8981811061354f5761354f616073565b90506020020160208101906135649190615998565b6001600160a01b0316307ff717428d3271f4ca44ee92a96ecda708463de1c200f30db4e295def5e8db6b4a60208e013585808a8a8a8181106135a8576135a8616073565b905060200201358b8b8b8181106135c1576135c1616073565b905060200201356135dd8f8f8d818110611b4c57611b4c616073565b6040516135ef9695949392919061670a565b60405180910390a45060010161341b565b50846001019450505050506132fc565b6040517fa0ae55c70000000000000000000000000000000000000000000000000000000081526001600160a01b038084166004830152821660248201525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063a0ae55c7906044016126cc565b5f81815260176020526040808220815160608101928390528392839283929160039082845b8154815260200190600101908083116136985750505050509050805f600381106136c4576136c4616073565b602002015181600160200201518260026020020151935093509350509193909250565b6136ef61490d565b5f6136f982614758565b9050336001600160a01b0382161461373d576040517f2fe8e7fc00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001600160a01b0381165f908152601d60205260409020548015613832576001600160a01b0382165f818152601d6020908152604080832083905580517f8da5cb5b0000000000000000000000000000000000000000000000000000000081529051929392638da5cb5b926004808401939192918290030181865afa1580156137c8573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906137ec9190616739565b90506137f88183614f94565b81816001600160a01b0316857f93a8f3b2bae86deadc28b666f9f65297764642ef13b22d1de09b2125e163bd8460405160405180910390a4505b50506123ac60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b61386561490d565b5f818152601c60205260408120549081900361388157506138eb565b5f828152601c60205260408120556002546138a5906001600160a01b031682614f94565b6002546040518281526001600160a01b039091169083907f0e19f21371647f79bb7c3f1e363266315b211fcca3836e7a71425cc0c4ab6a8e9060200160405180910390a3505b6123ac60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f61391d614b46565b6139256148b1565b61392d61490d565b6040517fa814c1fe0000000000000000000000000000000000000000000000000000000081526001600160a01b03871660048201526024810186905260448101859052606481018490526084810183905273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063a814c1fe9060a401602060405180830381865af41580156139b8573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906139dc91906160a0565b9050612f9260017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b6040517fab19bcd40000000000000000000000000000000000000000000000000000000081526001600160a01b038084166004830152821660248201525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063ab19bcd4906044016126cc565b6060613a746148b1565b613a7c61490d565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63a713c75e89898989898989613aa561498e565b6040518963ffffffff1660e01b8152600401613ac8989796959493929190616754565b5f60405180830381865af4158015613ae2573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f19168201604052613b0991908101906162a6565b9050613b3460017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b979650505050505050565b60208052815f5260405f208160038110613b57575f80fd5b01549150829050565b613b686145d3565b6123ac81615039565b5f81815260176020526040808220815160608101928390528392839283929160039082845b815481526020019060010190808311613b9657505050505090505f5f1b815f60038110613bc557613bc5616073565b6020020151148015613bd957506020810151155b8015613be757506040810151155b15613c21576040517f08848f3b00000000000000000000000000000000000000000000000000000000815260048101869052602401611dd3565b805f6136c4565b6040517f5eb53bd400000000000000000000000000000000000000000000000000000000815260048101839052602481018290525f908190819073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90635eb53bd490604401611cc3565b5f61196382600b60010154614be6565b613c9e6145d3565b613ca7816150da565b80606001516001600160a01b031681602001516001600160a01b0316825f01516001600160a01b03167faf8d85bc3313be057acad92fcdd8829b909273359b6a033f2f4348787b8df3f3846040015185608001518660a001518760c001518860e00151604051613204959493929190948552602085019390935260408401919091526060830152608082015260a00190565b5f61196382614e82565b6040805180820190915260265463ffffffff8082168084526401000000009092041660208301525f91829115613d7a578051613d7d565b60055b9250806020015163ffffffff165f14613d9a578060200151613d9e565b6102bc5b9150509091565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020526040902060010154613dde81614619565b611f2883836149db565b7f600e5f1c60beb469a3fa6dd3814a4ae211cc6259a6d033bae218a742f2af01d3613e1281614619565b505f55565b6060613e216148b1565b613e2961490d565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63a20efbea8b8b8b8b8b8b8b8b8b612a5461498e565b6060613e5e6148b1565b613e6661490d565b73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__6323683bbd8787878787613e8d61498e565b6040518763ffffffff1660e01b8152600401613eae9695949392919061685b565b5f60405180830381865af4158015613ec8573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d908101601f191682016040526139dc91908101906162a6565b7f600e5f1c60beb469a3fa6dd3814a4ae211cc6259a6d033bae218a742f2af01d3613f1981614619565b81848114613f53576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b81811015613153575f61404f868684818110613f7357613f73616073565b9050606002015f60038110613f8a57613f8a616073565b6020020135878785818110613fa157613fa1616073565b905060600201600160038110613fb957613fb9616073565b6020020135888886818110613fd057613fd0616073565b905060600201600260038110613fe857613fe8616073565b6020020135604080517f23ad11f0a1505378b82984192ad0461e6a012820fc5bf2e4ba16513f8e430552602082015290810184905260608101839052608081018290525f9060a0016040516020818303038152906040528051906020012090509392505050565b90505f61405b82614e82565b90506140a7828289898781811061407457614074616073565b90506060020160038060200260405190810160405280929190826003602002808284375f920191909152506151a4915050565b818989858181106140ba576140ba616073565b90506020020160208101906140cf9190615998565b6001600160a01b03167ff13505b910c49b286cf7fbaf1a78620cf7d8bda0e8e39c1baed620c08af686e789898781811061410b5761410b616073565b9050606002015f6003811061412257614122616073565b60200201358a8a8881811061413957614139616073565b90506060020160016003811061415157614151616073565b60200201358b8b8981811061416857614168616073565b90506060020160026003811061418057614180616073565b60408051948552602085810194909452920201359082015260600160405180910390a35050600101613f55565b5f818152601960205260408120541515611963565b6141ca6145d3565b8051600b819055602080830151600c81905560408051938452918301527f4a883a35415345b4e144c4eb6e7a784a553b46997702b6889f682e4dea64c35f9101611c5e565b6040517ff5719008000000000000000000000000000000000000000000000000000000008152600481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f571900890602401602060405180830381865af4158015614278573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061196391906160e2565b60606142a6614b46565b6142ae6148b1565b6142b661490d565b6040517ff679bf0900000000000000000000000000000000000000000000000000000000815273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f679bf0990612a79908d908d908d908d908d908d908d908d908d906004016168a4565b5f61432081614619565b60025f61432b614d19565b805490915068010000000000000000900460ff16806143585750805467ffffffffffffffff808416911610155b1561438f576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b80547fffffffffffffffffffffffffffffffffffffffffffffff0000000000000000001667ffffffffffffffff831617680100000000000000001781556143d584615039565b60015461440c907f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a906001600160a01b03166147e5565b50614415614c8c565b60255580547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16815560405167ffffffffffffffff831681527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a150505050565b6040517ff87d29ac0000000000000000000000000000000000000000000000000000000081526001600160a01b0383166004820152602481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f87d29ac90604401611bc5565b5f61196382601160020154614be6565b61454e6040518061010001604052805f6001600160a01b031681526020015f6001600160a01b031681526020015f81526020015f6001600160a01b031681526020015f81526020015f81526020015f81526020015f81525090565b5060408051610100810182526001546001600160a01b03908116825260025481166020830152600354928201929092526004549091166060820152600554608082015260065460a082015260075460c082015260085460e082015290565b5f61196382614cf8565b6006545f906145c6906002616913565b600b546119729190616150565b6022546001600160a01b03163314614617576040517f5661cf6e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b565b6123ac8133615220565b5f5f61462e83614cf8565b5f8481526018602090815260408083205460199092529091205491925060ff169015158215801561465d575081155b8015614667575080155b156146a1576040517fbdd4a69900000000000000000000000000000000000000000000000000000000815260048101869052602401611dd3565b82156146b157505f949350505050565b80156146c257506002949350505050565b506001949350505050565b6040517ff759917b00000000000000000000000000000000000000000000000000000000815273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063f759917b90614725908890889088908890889060040161692a565b5f6040518083038186803b15801561473b575f5ffd5b505af415801561474d573d5f5f3e3d5ffd5b505050505050505050565b6040517f218e250d000000000000000000000000000000000000000000000000000000008152600481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__9063218e250d90602401602060405180830381865af41580156147c1573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906119639190616739565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff166148a8575f848152602082815260408083206001600160a01b03871684529091529020805460ff1916600117905561485e3390565b6001600160a01b0316836001600160a01b0316857f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a46001915050611963565b5f915050611963565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff1615614617576040517fd93c066500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b7f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0080547ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01614988576040517f3ee5aeb500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60029055565b5f60ff815c1661499d57503490565b5060015c90565b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b6006546009545f9161197291616150565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff16156148a8575f848152602082815260408083206001600160a01b0387168085529252808320805460ff1916905551339287917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a46001915050611963565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff16614617576040517f8dfc202b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b614ae2614a7f565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300805460ff191681557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516001600160a01b039091168152602001611c5e565b614b4e61498e565b15614617576040517fd4d97d0100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6040517f58717e0d0000000000000000000000000000000000000000000000000000000081526004810184905260248101839052604481018290525f9073__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__906358717e0d9060640161262e565b6003545f90611c0490849084906152ac565b5f8181526019602052604081205415614c1d57505f9081526019602052604090205490565b61196382614e82565b919050565b5f7fc50959b2b0264fed58f3489f13cdf8345df0911245cc2b741070787ee7aceaa28280519060200120604051602001614c6f929190918252602082015260400190565b604051602081830303815290604052805190602001209050919050565b5f73__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__63766718086040518163ffffffff1660e01b8152600401602060405180830381865af4158015614cd4573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061197291906160a0565b5f8181526016602052604081208054614d109061646f565b15159392505050565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00611963565b6146176152d9565b614d516152d9565b614617615317565b614d616152d9565b614d6a866150da565b8451600955602094850151600a558351600b5592840151600c558151600d80547fffffffffffffffffffffffff00000000000000000000000000000000000000009081166001600160a01b039384161790915583860151600e80548316918416919091179055604080850151600f8054841691851691909117905560609094015160108054831691841691909117905582516011558286015160125591909201516013558251601480549092169216919091179055015160155550565b614e2f6148b1565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300805460ff191660011781557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a25833614b2e565b604080517fe7cbc1eb0e9b3f8688b0bc91a8278f7d2867f14f2a10dc3f0d9fcfdc32dada1260208201529081018290525f90606001614c6f565b5f81815260166020526040812080546060929190614ed99061646f565b80601f0160208091040260200160405190810160405280929190818152602001828054614f059061646f565b8015614f505780601f10614f2757610100808354040283529160200191614f50565b820191905f5260205f20905b815481529060010190602001808311614f3357829003601f168201915b5050505050905080515f03611963576040517fb615632f00000000000000000000000000000000000000000000000000000000815260048101849052602401611dd3565b80471015614fd7576040517fcf47918100000000000000000000000000000000000000000000000000000000815247600482015260248101829052604401611dd3565b5f5f836001600160a01b0316836040515f6040518083038185875af1925050503d805f8114615021576040519150601f19603f3d011682016040523d82523d5f602084013e615026565b606091505b509150915081611f2857611f288161531f565b6001600160a01b038116615079576040517f68de5c4b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b602280547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b0383169081179091556040517f7e7ee4175d63f671fac3401d5f401ed18d1f48a586e756f404d5696fc77a7058905f90a250565b80516001600160a01b031661511b576040517fc9f9ba1500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8051600180546001600160a01b039283167fffffffffffffffffffffffff0000000000000000000000000000000000000000918216179091556020830151600280549184169183169190911790556040830151600355606083015160048054919093169116179055608081015160055560a081015160065560c081015160075560e00151600855565b6040517f7b9c8fa400000000000000000000000000000000000000000000000000000000815273__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__90637b9c8fa4906151f890869086908690600401616953565b5f6040518083038186803b15801561520e575f5ffd5b505af4158015613153573d5f5f3e3d5ffd5b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408083206001600160a01b038516845290915290205460ff16612509576040517fe2517d3f0000000000000000000000000000000000000000000000000000000081526001600160a01b038216600482015260248101839052604401611dd3565b828202831584820484141782026152ca5763ad251c275f526004601cfd5b81810615159190040192915050565b6152e1615360565b614617576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6149a46152d9565b80511561532e57805160208201fd5b6040517fd6bda27500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f615369614d19565b5468010000000000000000900460ff16919050565b5f5f6040838503121561538f575f5ffd5b50508035926020909101359150565b5f602082840312156153ae575f5ffd5b81357fffffffff0000000000000000000000000000000000000000000000000000000081168114611c04575f5ffd5b5f602082840312156153ed575f5ffd5b5035919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b6040805190810167ffffffffffffffff81118282101715615444576154446153f4565b60405290565b604051610100810167ffffffffffffffff81118282101715615444576154446153f4565b604051601f8201601f1916810167ffffffffffffffff81118282101715615497576154976153f4565b604052919050565b6001600160a01b03811681146123ac575f5ffd5b8035614c268161549f565b5f604082840312156154ce575f5ffd5b6154d6615421565b905081356154e38161549f565b815260209182013591810191909152919050565b5f60408284031215615507575f5ffd5b611c0483836154be565b5f5f83601f840112615521575f5ffd5b50813567ffffffffffffffff811115615538575f5ffd5b6020830191508360208260051b85010111156118ca575f5ffd5b5f5f5f5f5f60608688031215615566575f5ffd5b853567ffffffffffffffff81111561557c575f5ffd5b61558888828901615511565b90965094505060208601359250604086013567ffffffffffffffff8111156155ae575f5ffd5b8601601f810188136155be575f5ffd5b803567ffffffffffffffff8111156155d4575f5ffd5b8860208260061b84010111156155e8575f5ffd5b959894975092955050506020019190565b5f60408284031215615609575f5ffd5b615611615421565b823581526020928301359281019290925250919050565b5f60408284031215615638575f5ffd5b611c0483836155f9565b5f5f5f60608486031215615654575f5ffd5b505081359360208301359350604090920135919050565b815181526020808301519082015260408101611963565b5f5f60408385031215615693575f5ffd5b8235915060208301356156a58161549f565b809150509250929050565b5f5f5f5f608085870312156156c3575f5ffd5b84356156ce8161549f565b966020860135965060408601359560600135945092505050565b5f5f5f5f604085870312156156fb575f5ffd5b843567ffffffffffffffff811115615711575f5ffd5b61571d87828801615511565b909550935050602085013567ffffffffffffffff81111561573c575f5ffd5b61574887828801615511565b95989497509550505050565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b5f602082016020835280845180835260408501915060408160051b8601019250602086015f5b828110156157f7577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc08786030184526157e2858351615754565b945060209384019391909101906001016157a8565b50929695505050505050565b5f5f5f5f5f5f5f5f6080898b03121561581a575f5ffd5b883567ffffffffffffffff811115615830575f5ffd5b61583c8b828c01615511565b909950975050602089013567ffffffffffffffff81111561585b575f5ffd5b6158678b828c01615511565b909750955050604089013567ffffffffffffffff811115615886575f5ffd5b6158928b828c01615511565b909550935050606089013567ffffffffffffffff8111156158b1575f5ffd5b6158bd8b828c01615511565b999c989b5096995094979396929594505050565b602080825282518282018190525f918401906040840190835b818110156159085783518352602093840193909201916001016158ea565b509095945050505050565b5f5f60408385031215615924575f5ffd5b823561592f8161549f565b946020939093013593505050565b5f5f6040838503121561594e575f5ffd5b82356159598161549f565b91506020830135600881106156a5575f5ffd5b5f5f6040838503121561597d575f5ffd5b82356159888161549f565b915060208301356156a58161549f565b5f602082840312156159a8575f5ffd5b8135611c048161549f565b5f606082840312156159c3575f5ffd5b6040516060810167ffffffffffffffff811182821017156159e6576159e66153f4565b60409081528335825260208085013590830152928301359281019290925250919050565b5f60608284031215615a1a575f5ffd5b611c0483836159b3565b5f60208284031215615a34575f5ffd5b813567ffffffffffffffff811115615a4a575f5ffd5b8201601f81018413615a5a575f5ffd5b803567ffffffffffffffff811115615a7457615a746153f4565b615a876020601f19601f8401160161546e565b818152856020838501011115615a9b575f5ffd5b816020840160208301375f91810160200191909152949350505050565b602081525f611c046020830184615754565b5f5f5f60608486031215615adc575f5ffd5b8335615ae78161549f565b95602085013595506040909401359392505050565b5f5f5f5f5f5f5f5f5f60a08a8c031215615b14575f5ffd5b8935615b1f8161549f565b985060208a013567ffffffffffffffff811115615b3a575f5ffd5b615b468c828d01615511565b90995097505060408a013567ffffffffffffffff811115615b65575f5ffd5b615b718c828d01615511565b90975095505060608a013567ffffffffffffffff811115615b90575f5ffd5b615b9c8c828d01615511565b90955093505060808a013567ffffffffffffffff811115615bbb575f5ffd5b615bc78c828d01615511565b915080935050809150509295985092959850929598565b803563ffffffff81168114614c26575f5ffd5b5f5f60408385031215615c02575f5ffd5b615c0b83615bde565b9150615c1960208401615bde565b90509250929050565b5f6101008284031215615c33575f5ffd5b615c3b61544a565b90508135615c488161549f565b8152615c56602083016154b3565b602082015260408281013590820152615c71606083016154b3565b60608201526080828101359082015260a0808301359082015260c0808301359082015260e09182013591810191909152919050565b5f60808284031215615cb6575f5ffd5b6040516080810167ffffffffffffffff81118282101715615cd957615cd96153f4565b6040529050808235615cea8161549f565b81526020830135615cfa8161549f565b60208201526040830135615d0d8161549f565b60408201526060830135615d208161549f565b6060919091015292915050565b5f5f5f5f5f5f6102a08789031215615d43575f5ffd5b615d4d8888615c22565b9550615d5d8861010089016155f9565b9450615d6d8861014089016155f9565b9350615d7d886101808901615ca6565b9250615d8d8861020089016159b3565b9150615d9d8861026089016154be565b90509295509295509295565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b60038110615de657615de6615da9565b9052565b602081016119638284615dd6565b5f60808284031215615e08575f5ffd5b611c048383615ca6565b5f60208284031215615e22575f5ffd5b813567ffffffffffffffff811115615e38575f5ffd5b820160808185031215611c04575f5ffd5b5f5f5f5f5f60a08688031215615e5d575f5ffd5b8535615e688161549f565b97602087013597506040870135966060810135965060800135945092505050565b5f5f5f5f5f5f5f6080888a031215615e9f575f5ffd5b8735615eaa8161549f565b9650602088013567ffffffffffffffff811115615ec5575f5ffd5b615ed18a828b01615511565b909750955050604088013567ffffffffffffffff811115615ef0575f5ffd5b615efc8a828b01615511565b909550935050606088013567ffffffffffffffff811115615f1b575f5ffd5b615f278a828b01615511565b989b979a50959850939692959293505050565b5f6101008284031215615f4b575f5ffd5b611c048383615c22565b5f5f5f5f5f60608688031215615f69575f5ffd5b8535615f748161549f565b9450602086013567ffffffffffffffff811115615f8f575f5ffd5b615f9b88828901615511565b909550935050604086013567ffffffffffffffff811115615fba575f5ffd5b615fc688828901615511565b969995985093965092949392505050565b5f5f5f5f60408587031215615fea575f5ffd5b843567ffffffffffffffff811115616000575f5ffd5b61600c87828801615511565b909550935050602085013567ffffffffffffffff81111561602b575f5ffd5b8501601f8101871361603b575f5ffd5b803567ffffffffffffffff811115616051575f5ffd5b876020606083028401011115616065575f5ffd5b949793965060200194505050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b5f602082840312156160b0575f5ffd5b5051919050565b5f5f5f606084860312156160c9575f5ffd5b5050815160208301516040909301519094929350919050565b5f602082840312156160f2575f5ffd5b81518015158114611c04575f5ffd5b5f5f60408385031215616112575f5ffd5b505080516020909101519092909150565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b8082018082111561196357611963616123565b5f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1843603018112616196575f5ffd5b83018035915067ffffffffffffffff8211156161b0575f5ffd5b6020019150368190038213156118ca575f5ffd5b818382375f9101908152919050565b8183525f7f07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff831115616203575f5ffd5b8260051b80836020870137939093016020019392505050565b60a081525f61622f60a083018b8d6161d3565b8281036020840152616242818a8c6161d3565b9050828103604084015261625781888a6161d3565b9050828103606084015261626c8186886161d3565b9150508260808301529a9950505050505050505050565b5f67ffffffffffffffff82111561629c5761629c6153f4565b5060051b60200190565b5f602082840312156162b6575f5ffd5b815167ffffffffffffffff8111156162cc575f5ffd5b8201601f810184136162dc575f5ffd5b80516162ef6162ea82616283565b61546e565b8082825260208201915060208360051b850101925086831115616310575f5ffd5b6020840193505b82841015616332578351825260209384019390910190616317565b9695505050505050565b602081016008831061635057616350615da9565b91905290565b81835281816020850137505f602082840101525f6020601f19601f840116840101905092915050565b5f8383855260208501945060208460051b820101835f5b8681101561642a57601f198484030188525f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe18936030181126163da575f5ffd5b880160208101925035905067ffffffffffffffff8111156163f9575f5ffd5b803603821315616407575f5ffd5b616412858284616356565b60209a8b019a90955093909301925050600101616396565b50909695505050505050565b606081525f61644960608301878961637f565b828103602084015261645c8186886161d3565b9150508260408301529695505050505050565b600181811c9082168061648357607f821691505b6020821081036164ba577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b6001600160a01b038b16815260c060208201525f6164e260c083018b8d6161d3565b82810360408401526164f5818a8c6161d3565b9050828103606084015261650a81888a6161d3565b9050828103608084015261651f8186886161d3565b9150508260a08301529b9a5050505050505050505050565b601f82111561207d57805f5260205f20601f840160051c8101602085101561655c5750805b601f840160051c820191505b8181101561657b575f8155600101616568565b5050505050565b67ffffffffffffffff83111561659a5761659a6153f4565b6165ae836165a8835461646f565b83616537565b5f601f8411600181146165fe575f85156165c85750838201355b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600387901b1c1916600186901b17835561657b565b5f83815260208120601f198716915b8281101561662d578685013582556020948501946001909201910161660d565b5086821015616668577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60f88860031b161c19848701351681555b505060018560011b0183555050505050565b604081525f61668d604083018587616356565b90506001600160a01b0383166020830152949350505050565b5f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe18436030181126166d9575f5ffd5b83018035915067ffffffffffffffff8211156166f3575f5ffd5b6020019150600581901b36038213156118ca575f5ffd5b5f60c082019050878252866020830152856040830152846060830152836080830152613b3460a0830184615dd6565b5f60208284031215616749575f5ffd5b8151611c048161549f565b6001600160a01b038916815260a060208201525f61677660a08301898b61637f565b828103604084015261678981888a6161d3565b905082810360608401528085825260208201905060208660051b830101875f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe18a3603015b8982101561683f57601f1986850301855282358181126167ec575f5ffd5b8b0160208101903567ffffffffffffffff811115616808575f5ffd5b8060051b3603821315616819575f5ffd5b61682486828461637f565b955050506020830192506020850194506001820191506167ce565b5050508093505050508260808301529998505050505050505050565b6001600160a01b0387168152608060208201525f61687d60808301878961637f565b82810360408401526168908186886161d3565b915050826060830152979650505050505050565b6001600160a01b038a16815260a060208201525f6168c660a083018a8c6161d3565b82810360408401526168d981898b6161d3565b905082810360608401526168ee8187896161d3565b905082810360808401526169038185876161d3565b9c9b505050505050505050505050565b808202811582820484141761196357611963616123565b5f60a0820190508682528560208301528460408301528360608301526163326080830184615dd6565b8381526020810183905260a0810160408201835f5b6003811015616987578151835260209283019290910190600101616968565b50505094935050505056fea164736f6c634300081d000a";
var MultiVaultMigrationModeLinkReferences = {
  "src/libraries/MultiVaultLib.sol:MultiVaultLib": "__$b869c6e4b8f03e2cd3fa34181d9d41f33f$__"
};

// bytecodes/FeeProxy.ts
var FeeProxyBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b614685806100d65f395ff3fe6080604052600436106102b9575f3560e01c8063728cdbca11610170578063b2678a9a116100d1578063cd7cde2b11610087578063e59519f111610062578063e59519f1146109db578063e63ab1e9146109fa578063f160d36914610a2d575f5ffd5b8063cd7cde2b146108ee578063d547741f1461099d578063d788dc3e146109bc575f5ffd5b8063bf769a3f116100b7578063bf769a3f1461089b578063c2b2671c146108b0578063c320c727146108cf575f5ffd5b8063b2678a9a14610874578063b5545a3c14610887575f5ffd5b806391d1485411610126578063a17314311161010c578063a17314311461082f578063a217fddf1461084e578063a3ad884414610861575f5ffd5b806391d14854146107a157806399d82c5f14610804575f5ffd5b80638456cb59116101565780638456cb591461075c5780638c3ecc45146107705780638c93fdda1461078e575f5ffd5b8063728cdbca1461071e5780637bdca1a81461073d575f5ffd5b806336568abe1161021a578063569ef79e116101d057806361d027b3116101b657806361d027b3146105d1578063649892c91461060857806368b938f0146106c3575f5ffd5b8063569ef79e1461057b5780635c975abb1461059b575f5ffd5b8063391a4df911610200578063391a4df9146105285780633f4ba83a14610547578063566b6e411461055b575f5ffd5b806336568abe146104ea57806338f8333214610509575f5ffd5b8063248a9ca31161026f5780632f2ff15d116102555780632f2ff15d146104825780633015377a146104a15780633442f4b0146104d5575f5ffd5b8063248a9ca3146103ba5780632696cbf914610407575f5ffd5b806314c44e091161029f57806314c44e0914610371578063191fe1ed14610386578063246d45691461039b575f5ffd5b806301ffc9a71461031c57806302e07b5014610350575f5ffd5b36610318575f546001600160a01b031633148015906102d85750333014155b15610316576040517fde73f9e50000000000000000000000000000000000000000000000000000000081523360048201526024015b60405180910390fd5b005b5f5ffd5b348015610327575f5ffd5b5061033b610336366004613aa1565b610a4c565b60405190151581526020015b60405180910390f35b61036361035e366004613b15565b610ae4565b604051908152602001610347565b34801561037c575f5ffd5b5061036360045481565b348015610391575f5ffd5b5061036361271081565b3480156103a6575f5ffd5b506103166103b5366004613b80565b610db9565b3480156103c5575f5ffd5b506103636103d4366004613b80565b5f9081527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015490565b348015610412575f5ffd5b50610426610421366004613b97565b610e49565b60408051825180518252602080820151818401528184015183850152606091820151828401528401516001600160a01b031660808301529183015167ffffffffffffffff1660a0820152910151151560c082015260e001610347565b34801561048d575f5ffd5b5061031661049c366004613bb2565b610f07565b3480156104ac575f5ffd5b506104c06104bb366004613be0565b610f50565b60408051928352602083019190915201610347565b3480156104e0575f5ffd5b5061036360035481565b3480156104f5575f5ffd5b50610316610504366004613bb2565b610fa2565b348015610514575f5ffd5b50610363610523366004613b97565b610ff3565b348015610533575f5ffd5b50610316610542366004613b97565b6110b7565b348015610552575f5ffd5b50610316611210565b61056e610569366004613c52565b611225565b6040516103479190613d8c565b61058e610589366004613d9e565b611454565b6040516103479190613e8d565b3480156105a6575f5ffd5b507fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff1661033b565b3480156105dc575f5ffd5b506001546105f0906001600160a01b031681565b6040516001600160a01b039091168152602001610347565b348015610613575f5ffd5b50610627610622366004613b97565b611523565b60405161034791905f6101a082019050825182526020830151602083015260408301516040830152606083015160608301526080830151608083015260a083015160a083015260c083015160c083015260e083015160e083015261010083015161010083015261012083015161012083015261014083015161014083015261016083015161016083015261018083015161018083015292915050565b3480156106ce575f5ffd5b5061033b6106dd366004613b97565b6001600160a01b03165f9081526005602052604090206004015474010000000000000000000000000000000000000000900467ffffffffffffffff16151590565b348015610729575f5ffd5b50610316610738366004613ecf565b61162d565b348015610748575f5ffd5b50610316610757366004613b97565b6118db565b348015610767575f5ffd5b50610316611a74565b34801561077b575f5ffd5b505f546105f0906001600160a01b031681565b6105f061079c366004613f40565b611aa6565b3480156107ac575f5ffd5b5061033b6107bb366004613bb2565b5f9182527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408084206001600160a01b0393909316845291905290205460ff1690565b34801561080f575f5ffd5b5061036361081e366004613b97565b60066020525f908152604090205481565b34801561083a575f5ffd5b50610316610849366004613f6b565b611d3d565b348015610859575f5ffd5b506103635f81565b61058e61086f366004613f85565b611e56565b61058e610882366004614017565b612033565b348015610892575f5ffd5b50610363612221565b3480156108a6575f5ffd5b5061036360025481565b3480156108bb575f5ffd5b506104c06108ca366004613be0565b612261565b3480156108da575f5ffd5b506103166108e9366004613b80565b612291565b3480156108f9575f5ffd5b5061090d6109083660046140d9565b6122d9565b60405161034791905f61018082019050825182526020830151602083015260408301516040830152606083015160608301526080830151608083015260a083015160a083015260c083015160c083015260e083015160e083015261010083015161010083015261012083015161012083015261014083015161014083015261016083015161016083015292915050565b3480156109a8575f5ffd5b506103166109b7366004613bb2565b6123df565b3480156109c7575f5ffd5b506103166109d6366004613b80565b612422565b3480156109e6575f5ffd5b5061033b6109f5366004613b97565b61246a565b348015610a05575f5ffd5b506103637f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a81565b348015610a38575f5ffd5b50610316610a47366004613b97565b6124e2565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f7965db0b000000000000000000000000000000000000000000000000000000001480610ade57507f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff000000000000000000000000000000000000000000000000000000008316145b92915050565b5f610aed612602565b610af5612660565b6001600160a01b038716610b35576040517ff0e4f71c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610b3e876126e1565b835f03610b77576040517f74a14a8b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b83341015610bba576040517fc50e52880000000000000000000000000000000000000000000000000000000081523460048201526024810185905260440161030d565b5f610bc48961289d565b80546002820154919250610bd79161298b565b80546002820154610be9919085612a19565b805460028201545f91610bfe91889190612aa9565b9050858110610c43576040517f84fcd80f000000000000000000000000000000000000000000000000000000008152600481018290526024810187905260440161030d565b5f610c4e8288614132565b6004840154909150610c6b906001600160a01b03168c3385612ad4565b5f546040517f2fb1d2700000000000000000000000000000000000000000000000000000000081526001600160a01b038c81166004830152602482018c9052604482018b90526064820189905290911690632fb1d27090839060840160206040518083038185885af1158015610ce3573d5f5f3e3d5ffd5b50505050506040513d601f19601f82011682018060405250810190610d089190614145565b9350610d188b338985855f612b8a565b610d2b33610d268934614132565b612e5e565b60408051888152602081018490529081018290526060810185905289906001600160a01b038d169033907f62be2ce96da4e877861c066204bd30d89a889d4bb27ca7e428d37a561ef5ea7f9060800160405180910390a4505050610dae60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b979650505050505050565b5f610dc381612f4d565b612710821115610e02576040517f0784e8ef0000000000000000000000000000000000000000000000000000000081526004810183905260240161030d565b600280549083905560408051828152602081018590527fcb160cc2f1db06f52755d5108650bbc0dc12d1b3af613578de6251fe56369d3091015b60405180910390a1505050565b610e51613a55565b506001600160a01b039081165f90815260056020908152604091829020825161010081018452815460808201908152600183015460a0830152600283015460c0830152600383015460e083015281526004909101549384169181019190915274010000000000000000000000000000000000000000830467ffffffffffffffff16918101919091527c010000000000000000000000000000000000000000000000000000000090910460ff161515606082015290565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020526040902060010154610f4081612f4d565b610f4a8383612f57565b50505050565b6001600160a01b0382165f90815260056020526040812080546002820154839291610f7d91869190612aa9565b925083831015610f9657610f918385614132565b610f98565b5f5b9150509250929050565b6001600160a01b0381163314610fe4576040517f6697b23200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610fee8282613041565b505050565b5f610ffc612660565b6001600160a01b03821661103c576040517ff0e4f71c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b306001600160a01b0383160361107e576040517feb59493c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61108782613103565b90506110b260017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b919050565b5f6110c181612f4d565b6001600160a01b0382165f908152600560205260408120600481015490917401000000000000000000000000000000000000000090910467ffffffffffffffff169003611145576040517f825ce9430000000000000000000000000000000000000000000000000000000081526001600160a01b038416600482015260240161030d565b60048101547c0100000000000000000000000000000000000000000000000000000000900460ff166111ae576040517f15f056d80000000000000000000000000000000000000000000000000000000081526001600160a01b038416600482015260240161030d565b6004810180547fffffff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffff1690556040516001600160a01b038416907fc8233ed71698d3f297dc4b872dccd5ff591ecb8978f2f54d689d1688a3fe2711905f90a2505050565b5f61121a81612f4d565b61122261319f565b50565b606061122f612602565b611237612660565b6001600160a01b038b16611277576040517ff0e4f71c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6112808b6126e1565b88158061128d5750888714155b806112985750888514155b806112a35750888314155b156112da576040517f2548ff6b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6112e88d8888865f61322f565b90506112fe81606001518e338460200151612ad4565b5f5f9054906101000a90046001600160a01b03166001600160a01b031663dea9423a82604001518e8e8e8e8e88608001518d8d6040518a63ffffffff1660e01b81526004016113549897969594939291906141a5565b5f6040518083038185885af115801561136f573d5f5f3e3d5ffd5b50505050506040513d5f823e601f3d908101601f191682016040526113979190810190614284565b91506113b28d33835f0151846020015185604001515f612b8a565b80516113c4903390610d269034614132565b80516020808301516040808501518151948552928401919091528201526001600160a01b038e169033907fada70f19226061b6de8189b655b8dd74e63b39b6ea00acf85d6b99595234e54b9060600160405180910390a35061144560017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b9b9a5050505050505050505050565b606061145e612602565b611466612660565b8815806114735750888714155b8061147e5750888514155b806114895750888314155b156114c0576040517f2548ff6b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6114c86133a5565b5f6114d78c868686600161322f565b90506114e98c8c8c8c8c8c8c8861346d565b91505061151560017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b9a9950505050505050505050565b611581604051806101a001604052805f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81525090565b506001600160a01b03165f9081526007602081815260409283902083516101a081018552815481526001820154928101929092526002810154938201939093526003830154606082015260048301546080820152600583015460a0820152600683015460c08201529082015460e082015260088201546101008201526009820154610120820152600a820154610140820152600b820154610160820152600c9091015461018082015290565b5f6116366135bd565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f811580156116625750825b90505f8267ffffffffffffffff16600114801561167e5750303b155b90508115801561168c575080155b156116c3576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156117245784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b6001600160a01b038b16158061174157506001600160a01b038a16155b8061175357506001600160a01b038916155b1561178a576040517ff0e4f71c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6127108811156117c9576040517f0784e8ef0000000000000000000000000000000000000000000000000000000081526004810189905260240161030d565b6117d16135e5565b6117d96135e5565b6117e16135ed565b6117eb5f8a612f57565b506118167f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a8a612f57565b505f80546001600160a01b03808e167fffffffffffffffffffffffff00000000000000000000000000000000000000009283161790925560018054928d169290911691909117905560028890556003879055600486905583156118ce5784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b5050505050505050505050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a61190581612f4d565b6001600160a01b0382165f908152600560205260408120600481015490917401000000000000000000000000000000000000000090910467ffffffffffffffff169003611989576040517f825ce9430000000000000000000000000000000000000000000000000000000081526001600160a01b038416600482015260240161030d565b60048101547c0100000000000000000000000000000000000000000000000000000000900460ff16156119f3576040517ff321dab10000000000000000000000000000000000000000000000000000000081526001600160a01b038416600482015260240161030d565b6004810180547fffffff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffff167c01000000000000000000000000000000000000000000000000000000001790556040516001600160a01b038416907fadccfc70b088705bc53a68ffc90184a1d6103bdb1b63b1cb5b38fccbb3190db5905f90a2505050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a611a9e81612f4d565b6112226135fd565b5f611aaf612602565b611ab7612660565b6001600160a01b038216611af7576040517ff0e4f71c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600454348114611b3c576040517fcac926c00000000000000000000000000000000000000000000000000000000081523460048201526024810182905260440161030d565b335f81815260056020526040902060048101549193509074010000000000000000000000000000000000000000900467ffffffffffffffff1615611bb7576040517fd9ee6ad00000000000000000000000000000000000000000000000000000000081526001600160a01b038416600482015260240161030d565b611bc085613676565b8435815560208501356001820155604085013560028201556060850135600382015560048101805467ffffffffffffffff421674010000000000000000000000000000000000000000027fffffffff000000000000000000000000000000000000000000000000000000009091166001600160a01b038716171790558115611c9b57600154611c58906001600160a01b031683613697565b6001546040518381526001600160a01b03909116907f7574bc52269806b4289787a8442f0e97d2204029e41a86e51baa69901b1269019060200160405180910390a25b836001600160a01b0316836001600160a01b03167e4c88cd740cc13970f60a94ac602f4143e1b920e88a944d4f1cc433299043b08785604051611d0a92919082358152602080840135908201526040808401359082015260609283013592810192909252608082015260a00190565b60405180910390a35050610ade60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b335f908152600560205260408120600481015490917401000000000000000000000000000000000000000090910467ffffffffffffffff169003611daf576040517f825ce94300000000000000000000000000000000000000000000000000000000815233600482015260240161030d565b611db882613676565b604080516080810182528254815260018301546020820152600283015491810191909152600382015460608201528282611e138282813581556020820135600182015560408201356002820155606090910135600390910155565b505060405133907fb7e6d595e2aca72ca37fb8cc84fada223087f03debea7d4fff8b2cf579e3323a90611e499084908790614310565b60405180910390a2505050565b6060611e60612602565b611e68612660565b841580611e755750848314155b15611eac576040517f2548ff6b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611eb46133a5565b5f611ec388868686600161322f565b9050611ed9816060015189338460200151612ad4565b5f54604080830151608084015191517fdf62fa880000000000000000000000000000000000000000000000000000000081526001600160a01b039093169263df62fa8892611f309133918d918d919060040161443c565b5f6040518083038185885af1158015611f4b573d5f5f3e3d5ffd5b50505050506040513d5f823e601f3d908101601f19168201604052611f739190810190614284565b9150611f8f8833835f0151846020015185604001516001612b8a565b8051611fa1903390610d269034614132565b8051602080830151604080850151815194855292840191909152820152606081018790526001600160a01b0389169033907f17b4daf0fd037ae01ac84521e7b8a10da326f1352391cba72318f6931b22948e9060800160405180910390a35061202960017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b9695505050505050565b606061203d612602565b612045612660565b8615806120525750868514155b8061205d5750868314155b15612094576040517f2548ff6b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61209c6133a5565b5f6120ab8a888886600161322f565b90506120c181606001518b338460200151612ad4565b5f54604080830151608084015191517fb15d75780000000000000000000000000000000000000000000000000000000081526001600160a01b039093169263b15d75789261211c9133918f918f91908d908d90600401614470565b5f6040518083038185885af1158015612137573d5f5f3e3d5ffd5b50505050506040513d5f823e601f3d908101601f1916820160405261215f9190810190614284565b915061217b8a33835f0151846020015185604001516001612b8a565b805161218d903390610d269034614132565b8051602080830151604080850151815194855292840191909152820152606081018990526001600160a01b038b169033907f17b4daf0fd037ae01ac84521e7b8a10da326f1352391cba72318f6931b22948e9060800160405180910390a35061221560017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b98975050505050505050565b5f61222a612660565b61223333613103565b905061225e60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b90565b6001600160a01b0382165f90815260056020526040812060018101546003820154839291610f7d91869190612aa9565b5f61229b81612f4d565b600480549083905560408051828152602081018590527f50b218c5a101ad05d53ab0a964d01da639ee79525ae4b7802ed714249740a8d59101610e3c565b6123316040518061018001604052805f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81525090565b506001600160a01b039182165f90815260086020818152604080842094909516835292835290839020835161018081018552815481526001820154938101939093526002810154938301939093526003830154606083015260048301546080830152600583015460a0830152600683015460c0830152600783015460e08301528201546101008201526009820154610120820152600a820154610140820152600b9091015461016082015290565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015461241881612f4d565b610f4a8383613041565b5f61242c81612f4d565b600380549083905560408051828152602081018590527fc345cab0f0b4eb49dd93607724568f1cb3d4fe7e78ff847219404dbc540f13a69101610e3c565b6001600160a01b0381165f908152600560205260408120600481015474010000000000000000000000000000000000000000900467ffffffffffffffff16158015906124db575060048101547c0100000000000000000000000000000000000000000000000000000000900460ff16155b9392505050565b6001600160a01b038116612522576040517ff0e4f71c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b335f908152600560205260408120600481015490917401000000000000000000000000000000000000000090910467ffffffffffffffff169003612594576040517f825ce94300000000000000000000000000000000000000000000000000000000815233600482015260240161030d565b6004810180546001600160a01b038481167fffffffffffffffffffffffff00000000000000000000000000000000000000008316811790935560405191169190829033907fa15d439b19637f4f49a6c91b956d5234fce876baa18edb119f4df154677b4136905f90a4505050565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff161561265e576040517fd93c066500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b565b7f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0080547ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016126db576040517f3ee5aeb500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60029055565b5f546040517fab19bcd40000000000000000000000000000000000000000000000000000000081523060048201526001600160a01b03838116602483015290911690819063ab19bcd490604401602060405180830381865afa158015612749573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061276d919061456c565b6127b4576040517fe86c6cca0000000000000000000000000000000000000000000000000000000081526001600160a01b038316600482015230602482015260440161030d565b6001600160a01b038216331480159061285157506040517fab19bcd40000000000000000000000000000000000000000000000000000000081523360048201526001600160a01b03838116602483015282169063ab19bcd490604401602060405180830381865afa15801561282b573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061284f919061456c565b155b15612899576040517fe73a1aba0000000000000000000000000000000000000000000000000000000081526001600160a01b038316600482015233602482015260440161030d565b5050565b6001600160a01b0381165f908152600560205260408120600481015490917401000000000000000000000000000000000000000090910467ffffffffffffffff169003612921576040517f825ce9430000000000000000000000000000000000000000000000000000000081526001600160a01b038316600482015260240161030d565b60048101547c0100000000000000000000000000000000000000000000000000000000900460ff16156110b2576040517f63f7b74c0000000000000000000000000000000000000000000000000000000081526001600160a01b038316600482015260240161030d565b600254600354818411156129d5576040517f4995c65d000000000000000000000000000000000000000000000000000000008152600481018590526024810183905260440161030d565b80831115610f4a576040517f7ee28b9f000000000000000000000000000000000000000000000000000000008152600481018490526024810182905260440161030d565b8035831115612a5e576040517fff844cd1000000000000000000000000000000000000000000000000000000008152600481018490528135602482015260440161030d565b8060200135821115610fee576040517f3525d835000000000000000000000000000000000000000000000000000000008152600481018390526020820135602482015260440161030d565b5f81612710612ab8858761458b565b612ac291906145a2565b612acc91906145da565b949350505050565b805f03612b2d57816001600160a01b0316836001600160a01b03167ff92f716a512f171e7e6573631112c7cfc0d0200c1eb5a8ab0ab22dbc481938b25f604051612b2091815260200190565b60405180910390a3610f4a565b612b378482613697565b816001600160a01b0316836001600160a01b03167ff92f716a512f171e7e6573631112c7cfc0d0200c1eb5a8ab0ab22dbc481938b283604051612b7c91815260200190565b60405180910390a350505050565b6001600160a01b038087165f90815260076020908152604080832060088352818420948a1684529390915281208054909103612bda576001826001015f828254612bd491906145da565b90915550505b6001825f015f828254612bed91906145da565b9250508190555085826002015f828254612c0791906145da565b9250508190555084826003015f828254612c2191906145da565b9250508190555083826004015f828254612c3b91906145da565b9091555050805460019082905f90612c549084906145da565b9250508190555085816001015f828254612c6e91906145da565b9250508190555084816002015f828254612c8891906145da565b9250508190555083816003015f828254612ca291906145da565b90915550508215612d83576001826009015f828254612cc191906145da565b925050819055508582600a015f828254612cdb91906145da565b925050819055508482600b015f828254612cf591906145da565b925050819055508382600c015f828254612d0f91906145da565b925050819055506001816008015f828254612d2a91906145da565b9250508190555085816009015f828254612d4491906145da565b925050819055508481600a015f828254612d5e91906145da565b925050819055508381600b015f828254612d7891906145da565b90915550612e549050565b6001826005015f828254612d9791906145da565b9250508190555085826006015f828254612db191906145da565b9250508190555084826007015f828254612dcb91906145da565b9250508190555083826008015f828254612de591906145da565b925050819055506001816004015f828254612e0091906145da565b9250508190555085816005015f828254612e1a91906145da565b9250508190555084816006015f828254612e3491906145da565b9250508190555083816007015f828254612e4e91906145da565b90915550505b5050505050505050565b805f03612e69575050565b5f826001600160a01b0316826040515f6040518083038185875af1925050503d805f8114612eb2576040519150601f19603f3d011682016040523d82523d5f602084013e612eb7565b606091505b5050905080610fee576001600160a01b0383165f9081526006602052604081208054849290612ee79084906145da565b90915550506040518281526001600160a01b038416907f57b31d08aad1b08f38687f5d1a07c24f3c09768a493b5b11f4de021a3ac6fbb990602001611e49565b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b611222813361373c565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff16613038575f848152602082815260408083206001600160a01b0387168452909152902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00166001179055612fee3390565b6001600160a01b0316836001600160a01b0316857f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a46001915050610ade565b5f915050610ade565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff1615613038575f848152602082815260408083206001600160a01b038716808552925280832080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016905551339287917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a46001915050610ade565b335f908152600660205260408120549081900361314c576040517ff779648300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b335f908152600660205260408120556131658282613697565b60405181815233907f358fe4192934d3bf28ae181feda1f4bd08ca67f5e2fad55582cce5eb67304ae99060200160405180910390a2919050565b6131a76137c8565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f0330080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001681557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516001600160a01b03909116815260200160405180910390a150565b6132666040518060a001604052805f81526020015f81526020015f81526020015f6001600160a01b03168152602001606081525090565b5f6132708761289d565b90505f8361327f578154613285565b60018201545b90505f8461329757600283015461329d565b60038301545b90506132a9828261298b565b6132b4828288612a19565b5f6132bf8989613823565b905080341015613304576040517fc50e52880000000000000000000000000000000000000000000000000000000081523460048201526024810182905260440161030d565b5f613310828585612aa9565b9050818110613355576040517f84fcd80f000000000000000000000000000000000000000000000000000000008152600481018290526024810183905260440161030d565b818652602086018190526133698183614132565b6040870181905260048601546001600160a01b03166060880152613391908b908b90856138b6565b608087015250939998505050505050505050565b5f546040517f4656c5f10000000000000000000000000000000000000000000000000000000081523060048201523360248201526001600160a01b03909116908190634656c5f190604401602060405180830381865afa15801561340b573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061342f919061456c565b611222576040517f2d07547600000000000000000000000000000000000000000000000000000000815233600482015230602482015260440161030d565b606061348382606001518a338560200151612ad4565b5f54604080840151608085015191517f7a9d980f0000000000000000000000000000000000000000000000000000000081526001600160a01b0390931692637a9d980f926134e29133918e918e918e918e918e918e91906004016145ed565b5f6040518083038185885af11580156134fd573d5f5f3e3d5ffd5b50505050506040513d5f823e601f3d908101601f191682016040526135259190810190614284565b90506135418933845f0151856020015186604001516001612b8a565b8151613553903390610d269034614132565b8151602080840151604080860151815194855292840191909152820152606081018890526001600160a01b038a169033907f972fb51dc9b3afd7a305482247d31628c9d4f433fc894b641c71491571447ff09060800160405180910390a398975050505050505050565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00610ade565b61265e6139b0565b6135f56139b0565b61265e6139ee565b613605612602565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f0330080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001660011781557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a25833613211565b6136858135604083013561298b565b6112228160200135826060013561298b565b804710156136da576040517fcf4791810000000000000000000000000000000000000000000000000000000081524760048201526024810182905260440161030d565b5f5f836001600160a01b0316836040515f6040518083038185875af1925050503d805f8114613724576040519150601f19603f3d011682016040523d82523d5f602084013e613729565b606091505b509150915081610f4a57610f4a816139f6565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408083206001600160a01b038516845290915290205460ff16612899576040517fe2517d3f0000000000000000000000000000000000000000000000000000000081526001600160a01b03821660048201526024810183905260440161030d565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff1661265e576040517f8dfc202b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f81815b818110156138ae578484828181106138415761384161464b565b905060200201355f03613880576040517f74a14a8b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8484828181106138925761389261464b565b90506020020135836138a491906145da565b9250600101613827565b505092915050565b6060838067ffffffffffffffff8111156138d2576138d2614203565b6040519080825280602002602001820160405280156138fb578160200160208202803683370190505b5091505f61390a600183614132565b90505f805b8281101561397c575f86888b8b8581811061392c5761392c61464b565b9050602002013561393d919061458b565b61394791906145a2565b90508086838151811061395c5761395c61464b565b602090810291909101015261397181846145da565b92505060010161390f565b506139878187614132565b8483815181106139995761399961464b565b602002602001018181525050505050949350505050565b6139b8613a37565b61265e576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b612f276139b0565b805115613a0557805160208201fd5b6040517fd6bda27500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f613a406135bd565b5468010000000000000000900460ff16919050565b6040518060800160405280613a8760405180608001604052805f81526020015f81526020015f81526020015f81525090565b81525f602082018190526040820181905260609091015290565b5f60208284031215613ab1575f5ffd5b81357fffffffff00000000000000000000000000000000000000000000000000000000811681146124db575f5ffd5b6001600160a01b0381168114611222575f5ffd5b80356110b281613ae0565b5f60408284031215613b0f575f5ffd5b50919050565b5f5f5f5f5f5f5f610100888a031215613b2c575f5ffd5b8735613b3781613ae0565b96506020880135613b4781613ae0565b955060408801359450606088013593506080880135925060a08801359150613b728960c08a01613aff565b905092959891949750929550565b5f60208284031215613b90575f5ffd5b5035919050565b5f60208284031215613ba7575f5ffd5b81356124db81613ae0565b5f5f60408385031215613bc3575f5ffd5b823591506020830135613bd581613ae0565b809150509250929050565b5f5f60408385031215613bf1575f5ffd5b8235613bfc81613ae0565b946020939093013593505050565b5f5f83601f840112613c1a575f5ffd5b50813567ffffffffffffffff811115613c31575f5ffd5b6020830191508360208260051b8501011115613c4b575f5ffd5b9250929050565b5f5f5f5f5f5f5f5f5f5f5f6101008c8e031215613c6d575f5ffd5b613c768c613af4565b9a50613c8460208d01613af4565b995060408c013567ffffffffffffffff811115613c9f575f5ffd5b613cab8e828f01613c0a565b909a5098505060608c013567ffffffffffffffff811115613cca575f5ffd5b613cd68e828f01613c0a565b90985096505060808c013567ffffffffffffffff811115613cf5575f5ffd5b613d018e828f01613c0a565b90965094505060a08c013567ffffffffffffffff811115613d20575f5ffd5b613d2c8e828f01613c0a565b9094509250613d4090508d60c08e01613aff565b90509295989b509295989b9093969950565b5f8151808452602084019350602083015f5b82811015613d82578151865260209586019590910190600101613d64565b5093949350505050565b602081525f6124db6020830184613d52565b5f5f5f5f5f5f5f5f5f5f60e08b8d031215613db7575f5ffd5b613dc08b613af4565b995060208b013567ffffffffffffffff811115613ddb575f5ffd5b613de78d828e01613c0a565b909a5098505060408b013567ffffffffffffffff811115613e06575f5ffd5b613e128d828e01613c0a565b90985096505060608b013567ffffffffffffffff811115613e31575f5ffd5b613e3d8d828e01613c0a565b90965094505060808b013567ffffffffffffffff811115613e5c575f5ffd5b613e688d828e01613c0a565b9094509250613e7c90508c60a08d01613aff565b90509295989b9194979a5092959850565b602080825282518282018190525f918401906040840190835b81811015613ec4578351835260209384019390920191600101613ea6565b509095945050505050565b5f5f5f5f5f5f60c08789031215613ee4575f5ffd5b8635613eef81613ae0565b95506020870135613eff81613ae0565b94506040870135613f0f81613ae0565b959894975094956060810135955060808101359460a0909101359350915050565b5f60808284031215613b0f575f5ffd5b5f5f60a08385031215613f51575f5ffd5b613f5b8484613f30565b91506080830135613bd581613ae0565b5f60808284031215613f7b575f5ffd5b6124db8383613f30565b5f5f5f5f5f5f60a08789031215613f9a575f5ffd5b8635613fa581613ae0565b9550602087013567ffffffffffffffff811115613fc0575f5ffd5b613fcc89828a01613c0a565b909650945050604087013567ffffffffffffffff811115613feb575f5ffd5b613ff789828a01613c0a565b909450925061400b90508860608901613aff565b90509295509295509295565b5f5f5f5f5f5f5f5f60c0898b03121561402e575f5ffd5b883561403981613ae0565b9750602089013567ffffffffffffffff811115614054575f5ffd5b6140608b828c01613c0a565b909850965050604089013567ffffffffffffffff81111561407f575f5ffd5b61408b8b828c01613c0a565b909650945050606089013567ffffffffffffffff8111156140aa575f5ffd5b6140b68b828c01613c0a565b90945092506140ca90508a60808b01613aff565b90509295985092959890939650565b5f5f604083850312156140ea575f5ffd5b82356140f581613ae0565b91506020830135613bd581613ae0565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b81810381811115610ade57610ade614105565b5f60208284031215614155575f5ffd5b5051919050565b8183525f7f07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff83111561418c575f5ffd5b8260051b80836020870137939093016020019392505050565b6001600160a01b038916815260a060208201525f6141c760a08301898b61415c565b82810360408401526141da81888a61415c565b905082810360608401526141ee8187613d52565b9050828103608084015261144581858761415c565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b604051601f8201601f1916810167ffffffffffffffff8111828210171561425957614259614203565b604052919050565b5f67ffffffffffffffff82111561427a5761427a614203565b5060051b60200190565b5f60208284031215614294575f5ffd5b815167ffffffffffffffff8111156142aa575f5ffd5b8201601f810184136142ba575f5ffd5b80516142cd6142c882614261565b614230565b8082825260208201915060208360051b8501019250868311156142ee575f5ffd5b6020840193505b828410156120295783518252602093840193909101906142f5565b82518152602080840151818301526040808501518184015260608086015181850152843560808501529184013560a084015283013560c083015282013560e082015261010081016124db565b81835281816020850137505f602082840101525f6020601f19601f840116840101905092915050565b5f8383855260208501945060208460051b820101835f5b8681101561443057601f198484030188525f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe18936030181126143e0575f5ffd5b880160208101925035905067ffffffffffffffff8111156143ff575f5ffd5b80360382131561440d575f5ffd5b61441885828461435c565b60209a8b019a9095509390930192505060010161439c565b50909695505050505050565b6001600160a01b0385168152606060208201525f61445e606083018587614385565b8281036040840152610dae8185613d52565b6001600160a01b0387168152608060208201525f614492608083018789614385565b82810360408401526144a48187613d52565b905082810360608401528084825260208201905060208560051b830101865f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1893603015b8882101561455a57601f198685030185528235818112614507575f5ffd5b8a0160208101903567ffffffffffffffff811115614523575f5ffd5b8060051b3603821315614534575f5ffd5b61453f868284614385565b955050506020830192506020850194506001820191506144e9565b50919c9b505050505050505050505050565b5f6020828403121561457c575f5ffd5b815180151581146124db575f5ffd5b8082028115828204841417610ade57610ade614105565b5f826145d5577f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b500490565b80820180821115610ade57610ade614105565b6001600160a01b038916815260a060208201525f61460f60a08301898b61415c565b828103604084015261462281888a61415c565b9050828103606084015261463781868861415c565b905082810360808401526114458185613d52565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffdfea164736f6c634300081d000a";

// bytecodes/BaseEmissionsController.ts
var BaseEmissionsControllerBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b6126fb806100d65f395ff3fe6080604052600436106102ae575f3560e01c80635ad0e4e011610165578063b97dd9e2116100c6578063d547741f1161007c578063f0e56dae11610062578063f0e56dae146107fd578063f9f3e18414610827578063ff1f6e1214610846575f5ffd5b8063d547741f146107bf578063dc4dab7f146107de575f5ffd5b8063c6634d11116100ac578063c6634d1114610751578063c8e497aa1461078c578063cfe8a73b146107ab575f5ffd5b8063b97dd9e2146106ea578063c3dd73a3146106fe575f5ffd5b806391d148541161011b57806397bc0b3b1161010157806397bc0b3b14610694578063a217fddf146106b8578063a6929793146106cb575f5ffd5b806391d14854146106055780639781beef14610675575f5ffd5b80637e7b75ec1161014b5780637e7b75ec146105bc57806380a5fa95146105db5780638ffa2c09146105f1575f5ffd5b80635ad0e4e01461058a57806379f9af76146105a9575f5ffd5b80632d8c580b1161020f57806336568abe116101c557806345680d87116101ab57806345680d8714610537578063528561b71461054b57806359da4d1214610576575f5ffd5b806336568abe146104f957806342966c6814610518575f5ffd5b80632e1a7d4d116101f55780632e1a7d4d1461049c5780632f2ff15d146104bb5780632f38bb3f146104da575f5ffd5b80632d8c580b1461045e5780632db731531461047d575f5ffd5b80631f89f25e11610264578063248a9ca31161024a578063248a9ca3146103de57806324eebdca1461042b57806328910e051461043f575f5ffd5b80631f89f25e146103ac5780632245498f146103bf575f5ffd5b80630ca1c5c9116102945780630ca1c5c91461036557806312065fe0146103795780631e3b94771461038b575f5ffd5b806301ffc9a7146102f0578063092c5b3b14610324575f5ffd5b366102ec57604051348152309033907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9060200160405180910390a3005b5f5ffd5b3480156102fb575f5ffd5b5061030f61030a366004612268565b610870565b60405190151581526020015b60405180910390f35b34801561032f575f5ffd5b506103577f7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c57022335781565b60405190815260200161031b565b348015610370575f5ffd5b50606d54610357565b348015610384575f5ffd5b5047610357565b348015610396575f5ffd5b506103aa6103a53660046122c8565b610908565b005b3480156103b7575f5ffd5b505f54610357565b3480156103ca575f5ffd5b506103576103d93660046122e3565b61091f565b3480156103e9575f5ffd5b506103576103f83660046122e3565b5f9081527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015490565b348015610436575f5ffd5b506103aa610929565b34801561044a575f5ffd5b506103aa6104593660046122c8565b6109c6565b348015610469575f5ffd5b506103aa6104783660046123fe565b6109d9565b348015610488575f5ffd5b506103aa6104973660046122c8565b610c54565b3480156104a7575f5ffd5b506103aa6104b63660046122e3565b610c67565b3480156104c6575f5ffd5b506103aa6104d53660046124d0565b610ce7565b3480156104e5575f5ffd5b506103aa6104f43660046122e3565b610d30565b348015610504575f5ffd5b506103aa6105133660046124d0565b610d43565b348015610523575f5ffd5b506103aa6105323660046122e3565b610da1565b348015610542575f5ffd5b50610357610ea4565b348015610556575f5ffd5b506103576105653660046122e3565b5f908152606e602052604090205490565b348015610581575f5ffd5b50610357610eb3565b348015610595575f5ffd5b506103aa6105a43660046124fe565b610ece565b6103aa6105b73660046122e3565b610ee1565b3480156105c7575f5ffd5b506103576105d63660046122e3565b610f1d565b3480156105e6575f5ffd5b50610357620186a081565b3480156105fc575f5ffd5b50603854610357565b348015610610575f5ffd5b5061030f61061f3660046124d0565b5f9182527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020908152604080842073ffffffffffffffffffffffffffffffffffffffff93909316845291905290205460ff1690565b348015610680575f5ffd5b5061035761068f3660046122e3565b610f27565b34801561069f575f5ffd5b5060375460405163ffffffff909116815260200161031b565b3480156106c3575f5ffd5b506103575f81565b3480156106d6575f5ffd5b506103576106e5366004612517565b610f31565b3480156106f5575f5ffd5b50610357610f43565b348015610709575f5ffd5b50603754640100000000900473ffffffffffffffffffffffffffffffffffffffff165b60405173ffffffffffffffffffffffffffffffffffffffff909116815260200161031b565b34801561075c575f5ffd5b506037547801000000000000000000000000000000000000000000000000900460ff1660405161031b91906125a5565b348015610797575f5ffd5b506103576107a63660046122e3565b610f4c565b3480156107b6575f5ffd5b50600154610357565b3480156107ca575f5ffd5b506103aa6107d93660046124d0565b610f56565b3480156107e9575f5ffd5b506103576107f83660046122e3565b610f99565b348015610808575f5ffd5b50606c5473ffffffffffffffffffffffffffffffffffffffff1661072c565b348015610832575f5ffd5b506103aa6108413660046125b3565b610fa3565b348015610851575f5ffd5b50606b5473ffffffffffffffffffffffffffffffffffffffff1661072c565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f7965db0b00000000000000000000000000000000000000000000000000000000148061090257507f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff000000000000000000000000000000000000000000000000000000008316145b92915050565b5f61091281610fb6565b61091b82610fc0565b5050565b5f61090282611091565b6109316110b2565b7f7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c57022335761095b81610fb6565b5f610964611133565b6037546038549192505f9161098c9163ffffffff169061098790620186a06125f9565b61114b565b905061099882826112ec565b5050506109c460017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b565b5f6109d081610fb6565b61091b826116a6565b5f6109e2611761565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f81158015610a0e5750825b90505f8267ffffffffffffffff166001148015610a2a5750303b155b905081158015610a38575080155b15610a6f576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff00000000000000001660011785558315610ad05784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b73ffffffffffffffffffffffffffffffffffffffff8a161580610b07575073ffffffffffffffffffffffffffffffffffffffff8916155b80610b26575073ffffffffffffffffffffffffffffffffffffffff8816155b15610b5d576040517f4dc3441c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610b65611789565b610b6d611791565b610b8d865f01518760200151886040015189606001518a608001516117a1565b610ba8875f0151886020015189604001518a60600151611846565b610bb25f8b61186a565b50610bdd7f7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c5702233578a61186a565b50610be788611988565b8315610c485784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50505050505050505050565b5f610c5e81610fb6565b61091b82611988565b610c6f6110b2565b5f610c7981610fb6565b604051828152339030907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef9060200160405180910390a3610cba3383611a43565b50610ce460017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b50565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020526040902060010154610d2081610fb6565b610d2a838361186a565b50505050565b5f610d3a81610fb6565b61091b82611afa565b73ffffffffffffffffffffffffffffffffffffffff81163314610d92576040517f6697b23200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610d9c8282611b2f565b505050565b5f610dab81610fb6565b610db3611c0b565b821115610dec576040517fa14b2d9800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b606b546040517f42966c680000000000000000000000000000000000000000000000000000000081526004810184905273ffffffffffffffffffffffffffffffffffffffff909116906342966c68906024015f604051808303815f87803b158015610e55575f5ffd5b505af1158015610e67573d5f5f3e3d5ffd5b50506040518481523092507f0b8dfcd0fd1673726d65811702547090d757891b53a38ae96c7d2304afa272af915060200160405180910390a25050565b5f610eae42611c9b565b905090565b5f5f610ebd611133565b9050610ec881611cd8565b91505090565b5f610ed881610fb6565b61091b82611cf3565b610ee96110b2565b7f7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c570223357610f1381610fb6565b610cba82346112ec565b5f61090282611d56565b5f61090282611cd8565b5f610f3c838361114b565b9392505050565b5f610eae611133565b5f61090282611c9b565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020526040902060010154610f8f81610fb6565b610d2a8383611b2f565b5f61090282611d80565b5f610fad81610fb6565b61091b82611db1565b610ce48133611e3a565b73ffffffffffffffffffffffffffffffffffffffff811661100d576040517f660e3d3600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b603780547fffffffffffffffff0000000000000000000000000000000000000000ffffffff1664010000000073ffffffffffffffffffffffffffffffffffffffff8416908102919091179091556040519081527f6b249399bdcf1e58a24e1f9919d11cbe3757e4f316cd1eee10410039c2ab5217906020015b60405180910390a150565b5f5f600354836110a1919061260c565b9050610f3c60025460045483611ee0565b7f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0080547ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0161112d576040517f3ee5aeb500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60029055565b5f5f5442101561114257505f90565b610eae42611d56565b5f5f603760049054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663c07e2b636040518163ffffffff1660e01b8152600401602060405180830381865afa1580156111b8573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906111dc9190612644565b73ffffffffffffffffffffffffffffffffffffffff1663f28b2daa6040518163ffffffff1660e01b8152600401602060405180830381865afa158015611224573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906112489190612644565b6040517fa692979300000000000000000000000000000000000000000000000000000000815263ffffffff861660048201526024810185905290915073ffffffffffffffffffffffffffffffffffffffff82169063a692979390604401602060405180830381865afa1580156112c0573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906112e4919061265f565b949350505050565b7f7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c57022335761131681610fb6565b606c5473ffffffffffffffffffffffffffffffffffffffff16611365576040517f01c667fd00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61136e611133565b9050808411156113aa576040517f1b4fbd3200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f848152606e6020526040902054156113ef576040517f1903154800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6113f985611091565b905080606d5f82825461140c91906125f9565b90915550505f858152606e602052604090819020829055606b5490517f40c10f190000000000000000000000000000000000000000000000000000000081523060048201526024810183905273ffffffffffffffffffffffffffffffffffffffff909116906340c10f19906044015f604051808303815f87803b158015611491575f5ffd5b505af11580156114a3573d5f5f3e3d5ffd5b5050606b546037546040517f095ea7b300000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff64010000000090920482166004820152602481018690529116925063095ea7b391506044016020604051808303815f875af1158015611527573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061154b9190612676565b506037546038545f9161156e9163ffffffff9091169061098790620186a06125f9565b9050808510156115aa576040517fc27291ac00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b603754606c546116089173ffffffffffffffffffffffffffffffffffffffff640100000000820481169263ffffffff8316929116908690869060ff780100000000000000000000000000000000000000000000000090910416611f3b565b80851115611623576116233361161e8388612695565b611a43565b606c54604080518481526020810189905273ffffffffffffffffffffffffffffffffffffffff909216917f0c542f68ba5ca16565c46bbb89e9fb35618acc85b540358211fa893679e37747910160405180910390a2505050505050565b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b73ffffffffffffffffffffffffffffffffffffffff81166116f3576040517f4dc3441c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b606c80547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff83169081179091556040517f1e0ca924142bdafe0eadf16525239beb3f7422d78bec9fa66eb78255ba24047c905f90a250565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00610902565b6109c4611fd0565b611799611fd0565b6109c461200e565b6117aa85612016565b6117b384612050565b6117bc83612089565b6117c5826120c2565b6117ce81612107565b5f8590556001849055600283905560038290556117ed81612710612695565b600455604080518681526020810186905290810184905260608101839052608081018290527f3366bff9180dc679de412e14374840b3fd49c9fcfd15d06597e2b228f094801e9060a00160405180910390a15050505050565b61184f84610fc0565b61185883611cf3565b61186182611afa565b610d2a81611db1565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020818152604080842073ffffffffffffffffffffffffffffffffffffffff8616855290915282205460ff1661197f575f8481526020828152604080832073ffffffffffffffffffffffffffffffffffffffff87168452909152902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016600117905561191b3390565b73ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff16857f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a46001915050610902565b5f915050610902565b73ffffffffffffffffffffffffffffffffffffffff81166119d5576040517f4dc3441c00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b606b80547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff83169081179091556040517f45db36c83d6c4220984dfb4424bff9aa9cacff63e6d9f75e9ffb2ea34a879da6905f90a250565b80471015611a8b576040517fcf479181000000000000000000000000000000000000000000000000000000008152476004820152602481018290526044015b60405180910390fd5b5f5f8373ffffffffffffffffffffffffffffffffffffffff16836040515f6040518083038185875af1925050503d805f8114611ae2576040519150601f19603f3d011682016040523d82523d5f602084013e611ae7565b606091505b509150915081610d2a57610d2a81612143565b60388190556040518181527fe255c1e74b23562531f25e1a67c0166033c020978c1efef546643be5fd86bfa390602001611086565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020818152604080842073ffffffffffffffffffffffffffffffffffffffff8616855290915282205460ff161561197f575f8481526020828152604080832073ffffffffffffffffffffffffffffffffffffffff8716808552925280832080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016905551339287917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a46001915050610902565b606b546040517f70a082310000000000000000000000000000000000000000000000000000000081523060048201525f9173ffffffffffffffffffffffffffffffffffffffff16906370a0823190602401602060405180830381865afa158015611c77573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610eae919061265f565b5f5f54821015611cac57505f919050565b5f611cb683611d56565b90505f60035482611cc7919061260c565b90506112e460025460045483611ee0565b5f60015482611ce791906126a8565b5f5461090291906125f9565b603780547fffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000001663ffffffff83169081179091556040519081527fc33271136afd1c5006cb4dddbd9e0a46be648e9000409f7c5218221f2b745d0c90602001611086565b5f5f54821015611d6757505f919050565b6001545f54611d769084612695565b610902919061260c565b600180545f9190611d9181856126a8565b5f54611d9d91906125f9565b611da791906125f9565b6109029190612695565b603780548291907fffffffffffffff00ffffffffffffffffffffffffffffffffffffffffffffffff167801000000000000000000000000000000000000000000000000836002811115611e0657611e0661253f565b02179055507fc9c732f0ffb4d6be1aeb4d928d268afe6a675e7604cb6e64b602b2437beca1e48160405161108691906125a5565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020908152604080832073ffffffffffffffffffffffffffffffffffffffff8516845290915290205460ff1661091b576040517fe2517d3f00000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff8216600482015260248101839052604401611a82565b5f815f03611eef575082610f3c565b5f612710611f0585670de0b6b3a76400006126a8565b611f0f919061260c565b90505f611f258285670de0b6b3a7640000612184565b9050611f31868261221b565b9695505050505050565b6040517f10a7265c00000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff8716906310a7265c908490611f9a90899089908990620186a09089906004016126bf565b5f604051808303818588803b158015611fb1575f5ffd5b505af1158015611fc3573d5f5f3e3d5ffd5b5050505050505050505050565b611fd861224a565b6109c4576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611680611fd0565b42811015610ce4576040517fc4a9308500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b805f03610ce4576040517f329d074200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b805f03610ce4576040517fa51e279700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8015806120d0575061016d81115b15610ce4576040517f88a8e51400000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6103e8811115610ce4576040517f126c648200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b80511561215257805160208201fd5b6040517fd6bda27500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b811581028315610f3c576001831684831802821890508160011c8360011c93505b8315612213578485028181018660801c82821017156121cb576349f7642b5f526004601cfd5b84900495505060018416156122085784820281810181811084888404181715612201578615612201576349f7642b5f526004601cfd5b8490049250505b8360011c93506121a5565b509392505050565b5f815f190483111561223a57811561223a5763bac65e5b5f526004601cfd5b50670de0b6b3a764000091020490565b5f612253611761565b5468010000000000000000900460ff16919050565b5f60208284031215612278575f5ffd5b81357fffffffff0000000000000000000000000000000000000000000000000000000081168114610f3c575f5ffd5b73ffffffffffffffffffffffffffffffffffffffff81168114610ce4575f5ffd5b5f602082840312156122d8575f5ffd5b8135610f3c816122a7565b5f602082840312156122f3575f5ffd5b5035919050565b6040516080810167ffffffffffffffff81118282101715612342577f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b60405290565b803563ffffffff8116811461235b575f5ffd5b919050565b80356003811061235b575f5ffd5b5f60a0828403121561237e575f5ffd5b60405160a0810167ffffffffffffffff811182821017156123c6577f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b604090815283358252602080850135908301528381013590820152606080840135908201526080928301359281019290925250919050565b5f5f5f5f5f858703610180811215612414575f5ffd5b863561241f816122a7565b9550602087013561242f816122a7565b9450604087013561243f816122a7565b935060807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa082011215612470575f5ffd5b506124796122fa565b6060870135612487816122a7565b815261249560808801612348565b602082015260a087013560408201526124b060c08801612360565b606082015291506124c48760e0880161236e565b90509295509295909350565b5f5f604083850312156124e1575f5ffd5b8235915060208301356124f3816122a7565b809150509250929050565b5f6020828403121561250e575f5ffd5b610f3c82612348565b5f5f60408385031215612528575f5ffd5b61253183612348565b946020939093013593505050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b600381106125a1577f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b9052565b60208101610902828461256c565b5f602082840312156125c3575f5ffd5b610f3c82612360565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b80820180821115610902576109026125cc565b5f8261263f577f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b500490565b5f60208284031215612654575f5ffd5b8151610f3c816122a7565b5f6020828403121561266f575f5ffd5b5051919050565b5f60208284031215612686575f5ffd5b81518015158114610f3c575f5ffd5b81810381811115610902576109026125cc565b8082028115828204841417610902576109026125cc565b5f60a08201905063ffffffff87168252856020830152846040830152836060830152611f31608083018461256c56fea164736f6c634300081d000a";

// bytecodes/SatelliteEmissionsController.ts
var SatelliteEmissionsControllerBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b61260e806100d65f395ff3fe60806040526004361061027a575f3560e01c806380a5fa951161014b578063c1d96558116100c6578063cfe8a73b1161007c578063dc4dab7f11610062578063dc4dab7f1461078d578063f5b541a6146107ac578063f9f3e184146107df575f5ffd5b8063cfe8a73b1461075a578063d547741f1461076e575f5ffd5b8063c5218797116100ac578063c5218797146106d5578063c6634d1114610700578063c8e497aa1461073b575f5ffd5b8063c1d9655814610679578063c3dd73a3146106a3575f5ffd5b806397bc0b3b1161011b578063a692979311610101578063a692979314610627578063a9059cbb14610646578063b97dd9e214610665575f5ffd5b806397bc0b3b146105f0578063a217fddf14610614575f5ffd5b806380a5fa95146105375780638ffa2c091461054d57806391d14854146105615780639781beef146105d1575f5ffd5b80632f38bb3f116101f55780634f799d1f116101ab5780635a9e6263116101915780635a9e6263146104da5780635ad0e4e0146104f95780637e7b75ec14610518575f5ffd5b80634f799d1f1461047b57806359da4d12146104c6575f5ffd5b80633e4cbb54116101db5780633e4cbb541461043557806345680d87146104485780634caf8f271461045c575f5ffd5b80632f38bb3f146103f757806336568abe14610416575f5ffd5b80631e3b94771161024a5780632245498f116102305780632245498f1461036c578063248a9ca31461038b5780632f2ff15d146103d8575f5ffd5b80631e3b94771461033a5780631f89f25e14610359575f5ffd5b806301ffc9a714610285578063092c5b3b146102b957806318487a25146102fa5780631a20071b1461031b575f5ffd5b3661028157005b5f5ffd5b348015610290575f5ffd5b506102a461029f36600461217b565b6107fe565b60405190151581526020015b60405180910390f35b3480156102c4575f5ffd5b506102ec7f7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c57022335781565b6040519081526020016102b0565b348015610305575f5ffd5b506103196103143660046121db565b610896565b005b348015610326575f5ffd5b506103196103353660046122b2565b6108ad565b348015610345575f5ffd5b506103196103543660046121db565b610abc565b348015610364575f5ffd5b505f546102ec565b348015610377575f5ffd5b506102ec6103863660046123cf565b610acf565b348015610396575f5ffd5b506102ec6103a53660046123cf565b5f9081527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015490565b3480156103e3575f5ffd5b506103196103f23660046123e6565b610ad9565b348015610402575f5ffd5b506103196104113660046123cf565b610b22565b348015610421575f5ffd5b506103196104303660046123e6565b610b35565b6103196104433660046123cf565b610b93565b348015610453575f5ffd5b506102ec610e45565b348015610467575f5ffd5b506103196104763660046121db565b610e54565b348015610486575f5ffd5b50606b5473ffffffffffffffffffffffffffffffffffffffff165b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020016102b0565b3480156104d1575f5ffd5b506102ec610e67565b3480156104e5575f5ffd5b506103196104f43660046123e6565b610e82565b348015610504575f5ffd5b50610319610513366004612414565b6110d7565b348015610523575f5ffd5b506102ec6105323660046123cf565b6110ea565b348015610542575f5ffd5b506102ec620186a081565b348015610558575f5ffd5b506038546102ec565b34801561056c575f5ffd5b506102a461057b3660046123e6565b5f9182527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020908152604080842073ffffffffffffffffffffffffffffffffffffffff93909316845291905290205460ff1690565b3480156105dc575f5ffd5b506102ec6105eb3660046123cf565b6110f4565b3480156105fb575f5ffd5b5060375460405163ffffffff90911681526020016102b0565b34801561061f575f5ffd5b506102ec5f81565b348015610632575f5ffd5b506102ec61064136600461242d565b6110fe565b348015610651575f5ffd5b50610319610660366004612455565b611110565b348015610670575f5ffd5b506102ec611286565b348015610684575f5ffd5b50606c5473ffffffffffffffffffffffffffffffffffffffff166104a1565b3480156106ae575f5ffd5b50603754640100000000900473ffffffffffffffffffffffffffffffffffffffff166104a1565b3480156106e0575f5ffd5b506102ec6106ef3660046123cf565b5f908152606d602052604090205490565b34801561070b575f5ffd5b506037547801000000000000000000000000000000000000000000000000900460ff166040516102b091906124d7565b348015610746575f5ffd5b506102ec6107553660046123cf565b61128f565b348015610765575f5ffd5b506001546102ec565b348015610779575f5ffd5b506103196107883660046123e6565b611299565b348015610798575f5ffd5b506102ec6107a73660046123cf565b6112dc565b3480156107b7575f5ffd5b506102ec7f97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b92981565b3480156107ea575f5ffd5b506103196107f93660046124e5565b6112e6565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f7965db0b00000000000000000000000000000000000000000000000000000000148061089057507f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff000000000000000000000000000000000000000000000000000000008316145b92915050565b5f6108a0816112f9565b6108a982611306565b5050565b5f6108b66113c1565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f811580156108e25750825b90505f8267ffffffffffffffff1660011480156108fe5750303b155b90508115801561090c575080155b15610943576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156109a45784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b73ffffffffffffffffffffffffffffffffffffffff89166109f1576040517f6e92e42a00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6109f96113e9565b610a016113f3565b610a21865f01518760200151886040015189606001518a60800151611403565b610a3c875f0151886020015189604001518a606001516114a8565b610a465f8a6114cc565b50610a50886115ea565b8315610ab15784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b505050505050505050565b5f610ac6816112f9565b6108a9826116a5565b5f61089082611776565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020526040902060010154610b12816112f9565b610b1c83836114cc565b50505050565b5f610b2c816112f9565b6108a982611797565b73ffffffffffffffffffffffffffffffffffffffff81163314610b84576040517f6697b23200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610b8e82826117cc565b505050565b7f97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929610bbd816112f9565b606b5473ffffffffffffffffffffffffffffffffffffffff16610c0c576040517f7dcf968400000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b606b546040517f93186fec000000000000000000000000000000000000000000000000000000008152600481018490525f9173ffffffffffffffffffffffffffffffffffffffff16906393186fec90602401602060405180830381865afa158015610c79573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610c9d91906124fe565b9050805f03610cd8576040517f950e30d200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f838152606d602052604090205415610d1d576040517f24e2edc900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f838152606d60205260408120829055603754603854610d509163ffffffff1690610d4b90620186a0612542565b6118a8565b905080341015610d8c576040517ffbe4b03000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b603754606c54610dea9173ffffffffffffffffffffffffffffffffffffffff640100000000820481169263ffffffff8316929116908690869060ff780100000000000000000000000000000000000000000000000090910416611a49565b80341115610e0557610e0533610e008334612555565b611acd565b837ff5b02a4a84f69f6d76231306dd2ee2ba4245323e13570b73a1afede8dbce06dc83604051610e3791815260200190565b60405180910390a250505050565b5f610e4f42611b84565b905090565b5f610e5e816112f9565b6108a9826115ea565b5f5f610e71611bc1565b9050610e7c81611bd9565b91505090565b610e8a611bf4565b5f610e94816112f9565b606b5473ffffffffffffffffffffffffffffffffffffffff16610ee3576040517f7dcf968400000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b606b546040517f93186fec000000000000000000000000000000000000000000000000000000008152600481018590525f9173ffffffffffffffffffffffffffffffffffffffff16906393186fec90602401602060405180830381865afa158015610f50573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610f7491906124fe565b9050805f03610faf576040517fcf8d21a800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b73ffffffffffffffffffffffffffffffffffffffff8316610ffc576040517f6e92e42a00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f848152606d602052604090205415611041576040517f24e2edc900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f848152606d6020526040902081905561105b8382611acd565b8273ffffffffffffffffffffffffffffffffffffffff16847fdc098da8255798f27ce8323f97122047cef9a7eef7e10e3df697d0bcc95338ff836040516110a491815260200190565b60405180910390a350506108a960017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f6110e1816112f9565b6108a982611c9b565b5f61089082611cfe565b5f61089082611bd9565b5f61110983836118a8565b9392505050565b611118611bf4565b7f7b765e0e932d348852a6f810bfa1ab891e259123f02db8cdcde614c570223357611142816112f9565b73ffffffffffffffffffffffffffffffffffffffff831661118f576040517f6e92e42a00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b815f036111c8576040517f124afb8300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b81471015611202576040517f4ce5fdab00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61120c8383611acd565b8273ffffffffffffffffffffffffffffffffffffffff167f5b3892aae118c1f1b3fac379d1af36f4d40b8826cfe8305ccd62ab53c6cfb1e58360405161125491815260200190565b60405180910390a2506108a960017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f610e4f611bc1565b5f61089082611b84565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b62680060205260409020600101546112d2816112f9565b610b1c83836117cc565b5f61089082611d28565b5f6112f0816112f9565b6108a982611d59565b6113038133611de2565b50565b73ffffffffffffffffffffffffffffffffffffffff8116611353576040517f6e92e42a00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b606b80547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff83169081179091556040517f83e46c5b4477344afeda8cfb1f70e8eb484ea3e36e87c5dbdf1026fb27ee0c3f905f90a250565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00610890565b6113f1611e88565b565b6113fb611e88565b6113f1611ec6565b61140c85611ece565b61141584611f08565b61141e83611f41565b61142782611f7a565b61143081611fbf565b5f85905560018490556002839055600382905561144f81612710612555565b600455604080518681526020810186905290810184905260608101839052608081018290527f3366bff9180dc679de412e14374840b3fd49c9fcfd15d06597e2b228f094801e9060a00160405180910390a15050505050565b6114b1846116a5565b6114ba83611c9b565b6114c382611797565b610b1c81611d59565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020818152604080842073ffffffffffffffffffffffffffffffffffffffff8616855290915282205460ff166115e1575f8481526020828152604080832073ffffffffffffffffffffffffffffffffffffffff87168452909152902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016600117905561157d3390565b73ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff16857f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a46001915050610890565b5f915050610890565b73ffffffffffffffffffffffffffffffffffffffff8116611637576040517f6e92e42a00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b606c80547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff83169081179091556040517f7551acf8b23c682c5bdf99e1745536ac40a18ffb5ed7c719cf738bc6f3df9586905f90a250565b73ffffffffffffffffffffffffffffffffffffffff81166116f2576040517f660e3d3600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b603780547fffffffffffffffff0000000000000000000000000000000000000000ffffffff1664010000000073ffffffffffffffffffffffffffffffffffffffff8416908102919091179091556040519081527f6b249399bdcf1e58a24e1f9919d11cbe3757e4f316cd1eee10410039c2ab5217906020015b60405180910390a150565b5f5f600354836117869190612568565b905061110960025460045483611ffb565b60388190556040518181527fe255c1e74b23562531f25e1a67c0166033c020978c1efef546643be5fd86bfa39060200161176b565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020818152604080842073ffffffffffffffffffffffffffffffffffffffff8616855290915282205460ff16156115e1575f8481526020828152604080832073ffffffffffffffffffffffffffffffffffffffff8716808552925280832080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016905551339287917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a46001915050610890565b5f5f603760049054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663c07e2b636040518163ffffffff1660e01b8152600401602060405180830381865afa158015611915573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061193991906125a0565b73ffffffffffffffffffffffffffffffffffffffff1663f28b2daa6040518163ffffffff1660e01b8152600401602060405180830381865afa158015611981573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906119a591906125a0565b6040517fa692979300000000000000000000000000000000000000000000000000000000815263ffffffff861660048201526024810185905290915073ffffffffffffffffffffffffffffffffffffffff82169063a692979390604401602060405180830381865afa158015611a1d573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611a4191906124fe565b949350505050565b73ffffffffffffffffffffffffffffffffffffffff86166310a7265c611a6f8585612542565b878787620186a0876040518763ffffffff1660e01b8152600401611a979594939291906125bb565b5f604051808303818588803b158015611aae575f5ffd5b505af1158015611ac0573d5f5f3e3d5ffd5b5050505050505050505050565b80471015611b15576040517fcf479181000000000000000000000000000000000000000000000000000000008152476004820152602481018290526044015b60405180910390fd5b5f5f8373ffffffffffffffffffffffffffffffffffffffff16836040515f6040518083038185875af1925050503d805f8114611b6c576040519150601f19603f3d011682016040523d82523d5f602084013e611b71565b606091505b509150915081610b1c57610b1c81612056565b5f5f54821015611b9557505f919050565b5f611b9f83611cfe565b90505f60035482611bb09190612568565b9050611a4160025460045483611ffb565b5f5f54421015611bd057505f90565b610e4f42611cfe565b5f60015482611be891906125ea565b5f546108909190612542565b7f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0080547ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01611c6f576040517f3ee5aeb500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60029055565b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b603780547fffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000001663ffffffff83169081179091556040519081527fc33271136afd1c5006cb4dddbd9e0a46be648e9000409f7c5218221f2b745d0c9060200161176b565b5f5f54821015611d0f57505f919050565b6001545f54611d1e9084612555565b6108909190612568565b600180545f9190611d3981856125ea565b5f54611d459190612542565b611d4f9190612542565b6108909190612555565b603780548291907fffffffffffffff00ffffffffffffffffffffffffffffffffffffffffffffffff167801000000000000000000000000000000000000000000000000836002811115611dae57611dae612471565b02179055507fc9c732f0ffb4d6be1aeb4d928d268afe6a675e7604cb6e64b602b2437beca1e48160405161176b91906124d7565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020908152604080832073ffffffffffffffffffffffffffffffffffffffff8516845290915290205460ff166108a9576040517fe2517d3f00000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff8216600482015260248101839052604401611b0c565b611e90612097565b6113f1576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611c75611e88565b42811015611303576040517fc4a9308500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b805f03611303576040517f329d074200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b805f03611303576040517fa51e279700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b801580611f88575061016d81115b15611303576040517f88a8e51400000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6103e8811115611303576040517f126c648200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f815f0361200a575082611109565b5f61271061202085670de0b6b3a76400006125ea565b61202a9190612568565b90505f6120408285670de0b6b3a76400006120b5565b905061204c868261214c565b9695505050505050565b80511561206557805160208201fd5b6040517fd6bda27500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6120a06113c1565b5468010000000000000000900460ff16919050565b811581028315611109576001831684831802821890508160011c8360011c93505b8315612144578485028181018660801c82821017156120fc576349f7642b5f526004601cfd5b84900495505060018416156121395784820281810181811084888404181715612132578615612132576349f7642b5f526004601cfd5b8490049250505b8360011c93506120d6565b509392505050565b5f815f190483111561216b57811561216b5763bac65e5b5f526004601cfd5b50670de0b6b3a764000091020490565b5f6020828403121561218b575f5ffd5b81357fffffffff0000000000000000000000000000000000000000000000000000000081168114611109575f5ffd5b73ffffffffffffffffffffffffffffffffffffffff81168114611303575f5ffd5b5f602082840312156121eb575f5ffd5b8135611109816121ba565b6040516080810167ffffffffffffffff8111828210171561223e577f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b60405290565b60405160a0810167ffffffffffffffff8111828210171561223e577f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b803563ffffffff8116811461229f575f5ffd5b919050565b80356003811061229f575f5ffd5b5f5f5f5f8486036101608112156122c7575f5ffd5b85356122d2816121ba565b945060208601356122e2816121ba565b935060807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc082011215612313575f5ffd5b61231b6121f6565b6040870135612329816121ba565b81526123376060880161228c565b60208201526080870135604082015261235260a088016122a4565b6060820152925060a07fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4082011215612388575f5ffd5b50612391612244565b60c0860135815260e0860135602082015261010086013560408201526101208601356060820152610140909501356080860152509194909350909190565b5f602082840312156123df575f5ffd5b5035919050565b5f5f604083850312156123f7575f5ffd5b823591506020830135612409816121ba565b809150509250929050565b5f60208284031215612424575f5ffd5b6111098261228c565b5f5f6040838503121561243e575f5ffd5b6124478361228c565b946020939093013593505050565b5f5f60408385031215612466575f5ffd5b8235612447816121ba565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b600381106124d3577f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b9052565b60208101610890828461249e565b5f602082840312156124f5575f5ffd5b611109826122a4565b5f6020828403121561250e575f5ffd5b5051919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b8082018082111561089057610890612515565b8181038181111561089057610890612515565b5f8261259b577f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b500490565b5f602082840312156125b0575f5ffd5b8151611109816121ba565b5f60a08201905063ffffffff8716825285602083015284604083015283606083015261204c608083018461249e565b80820281158282048414176108905761089061251556fea164736f6c634300081d000a";

// bytecodes/TrustBonding.ts
var TrustBondingBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b61579c806100d65f395ff3fe608060405234801561000f575f5ffd5b50600436106105c2575f3560e01c806376671808116102fc578063bef97c871161019d578063d7ed5ff3116100f3578063ee4358011161009e578063f77c479111610079578063f77c479114610e04578063fc0c546a14610e17578063ff368f6f14610e2a575f5ffd5b8063ee43580114610dd5578063ef5cfb8c14610dde578063eff7a61214610df1575f5ffd5b8063e7cc6176116100ce578063e7cc617614610daf578063ed50d91c14610db7578063ee00ef3a14610dca575f5ffd5b8063d7ed5ff314610d62578063da020a1814610d75578063e63ab1e914610d88575f5ffd5b8063cbf9fe5f11610153578063d2b54e6e1161012e578063d2b54e6e14610d29578063d33219b414610d3c578063d547741f14610d4f575f5ffd5b8063cbf9fe5f14610c85578063d07b705f14610ccc578063d1febfb914610cdf575f5ffd5b8063c25f4b7b11610183578063c25f4b7b14610c57578063c2c4c5c114610c6a578063c94924ac14610c72575f5ffd5b8063bef97c8714610c1f578063c16246c214610c44575f5ffd5b806393ab400b11610252578063a69df4b511610208578063aded77d6116101e3578063aded77d614610bd9578063bd12751b14610be2578063bdacb30314610c0c575f5ffd5b8063a69df4b514610b93578063ac25f26614610b9b578063adc6358914610bae575f5ffd5b806395d89b411161023857806395d89b4114610b3d578063981b24d014610b79578063a217fddf14610b8c575f5ffd5b806393ab400b146106a75780639516859414610b2a575f5ffd5b80638c3ecc45116102b257806390fad1e61161028d57806390fad1e614610aad57806391d1485414610ac057806393186fec14610b17575f5ffd5b80638c3ecc4514610a7e578063900cf0cf14610a915780639094a6bf14610a9a575f5ffd5b806383914540116102e25780638391454014610a585780638456cb5914610a635780638b51bfc614610a6b575f5ffd5b80637667180814610a3d5780637c74a17414610a45575f5ffd5b80633f4ba83a116104665780635c975abb116103bc5780636a5e265011610372578063711974841161034d57806371197484146109e25780637142a6a614610a1757806371b6c4d814610a2a575f5ffd5b80636a5e2650146109af57806370a08231146109bc5780637116c60c146109cf575f5ffd5b80635ce1b906116103a25780635ce1b9061461092b5780636386c1c71461093e57806365fc38731461099c575f5ffd5b80635c975abb146108f95780635cdaab4814610923575f5ffd5b806351c38aae1161041c57806356891412116103f757806356891412146108e157806357d775f8146108e95780635b51c308146108f1575f5ffd5b806351c38aae1461086757806354fd4d501461087a57806355333008146108b6575f5ffd5b8063490d71931161044c578063490d71931461082e5780634957677c146108415780634ee2cd7e14610854575f5ffd5b80633f4ba83a1461081e5780634899912814610826575f5ffd5b80632655c9b51161051b578063313ce567116104d15780633a46273e116104ac5780633a46273e146107f05780633ccfd60b146108035780633cebb8231461080b575f5ffd5b8063313ce567146107a15780633617a204146107bb57806336568abe146107dd575f5ffd5b80632c7c1ce9116105015780632c7c1ce9146107665780632ebe88fa1461076f5780632f2ff15d1461078e575f5ffd5b80632655c9b51461071857806328d09d471461072b575f5ffd5b806311e57aad1161057b5780632331dd88116105565780632331dd88146106af5780632371eb23146106c2578063248a9ca3146106d7575f5ffd5b806311e57aad14610695578063126082cf1461069e57806318160ddd146106a7575f5ffd5b8063047fc9aa116105ab578063047fc9aa1461061b57806306fdde03146106245780630db9f2941461066d575f5ffd5b8063010ae757146105c657806301ffc9a7146105f8575b5f5ffd5b6105e56105d4366004615366565b60086020525f908152604090205481565b6040519081526020015b60405180910390f35b61060b61060636600461537f565b610e3d565b60405190151581526020016105ef565b6105e560025481565b6106606040518060400160405280601381526020017f566f74652d657363726f7765642054525553540000000000000000000000000081525081565b6040516105ef91906153be565b61068061067b366004615366565b610ed5565b604080519283526020830191909152016105ef565b6105e56109c481565b6105e561271081565b6105e5611010565b6105e56106bd366004615411565b61101f565b6106d56106d0366004615428565b611029565b005b6105e56106e5366004615411565b5f9081527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015490565b6105e5610726366004615411565b61103f565b61073e610739366004615448565b611049565b60408051600f95860b81529390940b60208401529282015260608101919091526080016105ef565b6105e560435481565b6105e561077d366004615411565b603e6020525f908152604090205481565b6106d561079c366004615470565b61109a565b6107a9601281565b60405160ff90911681526020016105ef565b61060b6107c9366004615366565b600b6020525f908152604090205460ff1681565b6106d56107eb366004615470565b6110e3565b6106d56107fe366004615448565b611134565b6106d5611146565b6106d5610819366004615366565b611181565b6106d56111d1565b6105e56111e6565b6106d561083c36600461549a565b6111ef565b6106d561084f366004615411565b611402565b6105e5610862366004615448565b611413565b6105e5610875366004615411565b61176c565b6106606040518060400160405280600581526020017f312e302e3000000000000000000000000000000000000000000000000000000081525081565b6041546108c9906001600160a01b031681565b6040516001600160a01b0390911681526020016105ef565b6002546105e5565b6105e5611776565b6105e55f5481565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff1661060b565b6105e56117fa565b610680610939366004615448565b611803565b61095161094c366004615366565b61186d565b6040516105ef91905f60c082019050825182526020830151602083015260408301516040830152606083015160608301526080830151608083015260a083015160a083015292915050565b6106d56109aa366004615428565b61197f565b60035461060b9060ff1681565b6105e56109ca366004615366565b611991565b6105e56109dd366004615411565b61199c565b610a046109f0366004615411565b60096020525f9081526040902054600f0b81565b604051600f9190910b81526020016105ef565b6106d5610a25366004615428565b6119a6565b6106d5610a38366004615411565b6119b8565b6105e5611a05565b610a04610a53366004615366565b611a0e565b6105e56301e1338081565b6106d5611a67565b6105e5610a79366004615411565b611a99565b6040546108c9906001600160a01b031681565b6105e560055481565b6106d5610aa8366004615411565b611aa3565b6106d5610abb366004615366565b611af0565b61060b610ace366004615470565b5f9182527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408084206001600160a01b0393909316845291905290205460ff1690565b6105e5610b25366004615411565b611b1b565b6105e5610b38366004615448565b611bfa565b6106606040518060400160405280600781526020017f766554525553540000000000000000000000000000000000000000000000000081525081565b6105e5610b87366004615411565b611c95565b6105e55f81565b6106d5611e8c565b6106d5610ba9366004615366565b611ea6565b6105e5610bbc366004615366565b6001600160a01b03165f9081526004602052604090206001015490565b6105e5610fa081565b6105e5610bf0366004615448565b603f60209081525f928352604080842090915290825290205481565b6106d5610c1a366004615366565b611ed4565b600a5461060b9074010000000000000000000000000000000000000000900460ff1681565b61060b610c52366004615448565b611f21565b6105e5610c65366004615448565b611f4b565b6106d5611f56565b6105e5610c80366004615366565b611fe2565b610cb2610c93366004615366565b60046020525f908152604090208054600190910154600f9190910b9082565b60408051600f9390930b83526020830191909152016105ef565b6105e5610cda366004615448565b612078565b61073e610ced366004615411565b60066020525f9081526040902080546001820154600290920154600f82810b93700100000000000000000000000000000000909304900b919084565b6105e5610d37366004615448565b612083565b6044546108c9906001600160a01b031681565b6106d5610d5d366004615470565b61208e565b6105e5610d70366004615411565b6120d1565b6105e5610d83366004615448565b612124565b6105e57f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a81565b61068061215f565b6106d5610dc5366004615366565b612307565b6105e56303c2670081565b6105e560425481565b6106d5610dec366004615366565b612354565b6106d5610dff366004615411565b612684565b600a546108c9906001600160a01b031681565b6001546108c9906001600160a01b031681565b6106d5610e38366004615366565b612695565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f7965db0b000000000000000000000000000000000000000000000000000000001480610ecf57507f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff000000000000000000000000000000000000000000000000000000008316145b92915050565b5f5f5f610ee06126e2565b90505f610eed85836126ec565b90505f610efa86846127bf565b6001600160a01b0387165f90815260046020526040902054909150600f0b821580610f2557505f8113155b15610f335750505050915091565b604154604080517fcfe8a73b00000000000000000000000000000000000000000000000000000000815290515f926001600160a01b03169163cfe8a73b9160048083019260209291908290030181865afa158015610f93573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610fb79190615507565b90505f81610fc96301e133808761554b565b610fd3919061558f565b905082610fe0858361554b565b610fea919061558f565b975082610ff96127108361554b565b611003919061558f565b9650505050505050915091565b5f61101a42612a22565b905090565b5f610ecf82612a9c565b611031612c38565b61103b8282612c94565b5050565b5f610ecf82612d8f565b6007602052815f5260405f2081633b9aca008110611065575f80fd5b6003020180546001820154600290920154600f82810b955070010000000000000000000000000000000090920490910b925084565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b62680060205260409020600101546110d381612e14565b6110dd8383612e1e565b50505050565b6001600160a01b0381163314611125576040517f6697b23200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61112f8282612ef1565b505050565b61113c612c38565b61103b8282612f95565b61114e61312f565b6111566131b0565b61117f60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b565b600a546001600160a01b03163314611197575f5ffd5b600a80547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b0392909216919091179055565b5f6111db81612e14565b6111e3613393565b50565b5f61101a613406565b5f6111f8613498565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f811580156112245750825b90505f8267ffffffffffffffff1660011480156112405750303b155b90508115801561124e575080155b15611285576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156112e65784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b6001600160a01b038c16611326576040517f0fc22bfb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61132e6134c0565b6113398c8b8b6134c8565b6113435f8d612e1e565b5061136e7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a8d612e1e565b506113788b6136f8565b61138188613799565b61138a8761383a565b611393866138b7565b83156113f45784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b505050505050505050505050565b61140a612c38565b6111e381613934565b5f438211156114695760405162461bcd60e51b815260206004820152601360248201527f626c6f636b20696e20746865206675747572650000000000000000000000000060448201526064015b60405180910390fd5b6001600160a01b0383165f90815260086020526040812054815b60808110156115125781831015611512575f60026114a184866155a2565b6114ac9060016155a2565b6114b6919061558f565b6001600160a01b0388165f908152600760205260409020909150869082633b9aca0081106114e6576114e66155b5565b6003020160020154116114fb57809350611509565b6115066001826155e2565b92505b50600101611483565b506001600160a01b0385165f90815260076020526040812083633b9aca00811061153e5761153e6155b5565b60408051608081018252600392909202929092018054600f81810b8452700100000000000000000000000000000000909104900b602083015260018101549282019290925260029091015460608201526005549091505f61159f8783613a26565b5f81815260066020908152604080832081516080810183528154600f81810b8352700100000000000000000000000000000000909104900b938101939093526001810154918301919091526002015460608201529192508084841015611695575f60068161160e8760016155a2565b815260208082019290925260409081015f2081516080810183528154600f81810b8352700100000000000000000000000000000000909104900b9381019390935260018101549183019190915260020154606080830182905286015191925061167791906155e2565b92508360400151816040015161168d91906155e2565b9150506116b9565b60608301516116a490436155e2565b91508260400151426116b691906155e2565b90505b604083015182156116f6578284606001518c6116d591906155e2565b6116df908461554b565b6116e9919061558f565b6116f390826155a2565b90505b604087015161170590826155e2565b876020015161171491906155f5565b87518890611723908390615614565b600f90810b90915288515f910b12905061175b57505093516fffffffffffffffffffffffffffffffff169650610ecf95505050505050565b505f9b9a5050505050505050505050565b5f610ecf82613aa1565b604154604080517fcfe8a73b00000000000000000000000000000000000000000000000000000000815290515f926001600160a01b03169163cfe8a73b9160048083019260209291908290030181865afa1580156117d6573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061101a9190615507565b5f61101a613b92565b5f5f5f61180e6126e2565b905080158061181c57508084115b1561182d575f5f9250925050611866565b5f61183886866126ec565b90505f61184587876127bf565b9050612710611854828461554b565b61185e919061558f565b945090925050505b9250929050565b6118a06040518060c001604052805f81526020015f81526020015f81526020015f81526020015f81526020015f81525090565b5f6118a96126e2565b90505f8082156118cc576118bd85846126ec565b91506118c985846127bf565b90505b6001600160a01b0385165f90815260046020908152604091829020825180840184528154600f0b815260019091015481830152825160c081019093528383529190810161271061191c858761554b565b611926919061558f565b81526020018481526020015f835f0151600f0b1215611945575f61195a565b82516fffffffffffffffffffffffffffffffff165b8152602001826020015181526020016119738842613bbc565b90529695505050505050565b611987612c38565b61103b8282613cae565b5f610ecf8242613bbc565b5f610ecf82612a22565b6119ae612c38565b61103b8282613d6e565b6044546001600160a01b031633146119fc576040517f8e5eaee100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6111e38161383a565b5f61101a6126e2565b6001600160a01b0381165f908152600860209081526040808320546007909252822081633b9aca008110611a4457611a446155b5565b60030201547001000000000000000000000000000000009004600f0b9392505050565b7f65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a611a9181612e14565b6111e3613efb565b5f610ecf82613f56565b6044546001600160a01b03163314611ae7576040517f8e5eaee100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6111e3816138b7565b5f611afa81612e14565b506001600160a01b03165f908152600b60205260409020805460ff19169055565b5f5f611b25611a05565b90506002811015611b3857505f92915050565b611b436002826155e2565b831115611b5257505f92915050565b6041546040517f2245498f000000000000000000000000000000000000000000000000000000008152600481018590525f916001600160a01b031690632245498f90602401602060405180830381865afa158015611bb2573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611bd69190615507565b5f858152603e6020526040902054909150611bf181836155e2565b95945050505050565b5f6001600160a01b038316611c3b576040517f0fc22bfb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611c43611a05565b821115611c7c576040517f500437ad00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611c8e83611c8984612d8f565b613bbc565b9392505050565b5f43821115611ce65760405162461bcd60e51b815260206004820152601360248201527f626c6f636b20696e2074686520667574757265000000000000000000000000006044820152606401611460565b6005545f611cf48483613a26565b5f81815260066020908152604080832081516080810183528154600f81810b8352700100000000000000000000000000000000909104900b9381019390935260018101549183019190915260020154606082015291925083831015611e1a575f600681611d628660016155a2565b815260208082019290925260409081015f2081516080810183528154600f81810b8352700100000000000000000000000000000000909104900b9381019390935260018101549183019190915260020154606080830182905285015191925014611e145782606001518160600151611dda91906155e2565b83604001518260400151611dee91906155e2565b6060850151611dfd908a6155e2565b611e07919061554b565b611e11919061558f565b91505b50611e69565b43826060015114611e69576060820151611e3490436155e2565b6040830151611e4390426155e2565b6060840151611e5290896155e2565b611e5c919061554b565b611e66919061558f565b90505b611e8282828460400151611e7d91906155a2565b613fa0565b9695505050505050565b5f611e9681612e14565b506003805460ff19166001179055565b5f611eb081612e14565b506001600160a01b03165f908152600b60205260409020805460ff19166001179055565b6044546001600160a01b03163314611f18576040517f8e5eaee100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6111e3816136f8565b6001600160a01b0382165f908152603f602090815260408083208484529091528120541515611c8e565b5f611c8e83836127bf565b60035460ff1615611fa95760405162461bcd60e51b815260206004820152601160248201527f756e6c6f636b656420676c6f62616c6c790000000000000000000000000000006044820152606401611460565b61117f5f60405180604001604052805f600f0b81526020015f81525060405180604001604052805f600f0b81526020015f81525061409a565b5f5f611fec6126e2565b9050805f03611ffd57505f92915050565b5f6120096001836155e2565b6001600160a01b0385165f908152603f6020908152604080832084845290915281205491925061271061203c87856127bf565b61204688866126ec565b612050919061554b565b61205a919061558f565b905081811161206e57505f95945050505050565b611e8282826155e2565b5f611c8e8383613bbc565b5f611c8e83836126ec565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b62680060205260409020600101546120c781612e14565b6110dd8383612ef1565b5f6120da611a05565b821115612113576040517f500437ad00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610ecf61211f83612d8f565b612a22565b6001600160a01b0382165f90815260076020526040812082633b9aca00811061214f5761214f6155b5565b6003020160010154905092915050565b5f5f5f61216b42612a22565b9050805f0361217e57505f928392509050565b5f6121876126e2565b90505f60415f9054906101000a90046001600160a01b03166001600160a01b031663cfe8a73b6040518163ffffffff1660e01b8152600401602060405180830381865afa1580156121da573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906121fe9190615507565b90505f816301e1338061221085613aa1565b61221a919061554b565b612224919061558f565b6041546040517f2245498f000000000000000000000000000000000000000000000000000000008152600481018690529192505f916001600160a01b0390911690632245498f90602401602060405180830381865afa158015612289573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906122ad9190615507565b90505f836122bf6301e133808461554b565b6122c9919061558f565b9050856122d86127108561554b565b6122e2919061558f565b9750856122f16127108361554b565b6122fb919061558f565b96505050505050509091565b6044546001600160a01b0316331461234b576040517f8e5eaee100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6111e381614767565b61235c612c38565b61236461312f565b6001600160a01b0381166123a4576040517f0fc22bfb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6123ad611a05565b9050805f036123e8576040517fb3c6be2100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6123f46001836155e2565b90505f61240133836126ec565b9050805f0361243c576040517ffbfc235e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61244733846127bf565b90505f612710612457838561554b565b612461919061558f565b9050805f0361249c576040517ffbfc235e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b335f908152603f60209081526040808320878452909152902054156124ed576040517f442ca94500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6124f785613aa1565b5f868152603e6020526040902054909150818110612541576040517f8aba80e700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61254c82846155e2565b90508084111561255a578093505b5f878152603e6020526040812080548692906125779084906155a2565b9091555050335f908152603f602090815260408083208a84529091529081902085905560415490517fa9059cbb0000000000000000000000000000000000000000000000000000000081526001600160a01b038b81166004830152602482018790529091169063a9059cbb906044015f604051808303815f87803b1580156125fd575f5ffd5b505af115801561260f573d5f5f3e3d5ffd5b50506040518681526001600160a01b038c1692503391507f9310ccfcb8de723f578a9e4282ea9f521f05ae40dc08f3068dfad528a65ee3c79060200160405180910390a350505050505050506111e360017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b61268c612c38565b6111e381614806565b6044546001600160a01b031633146126d9576040517f8e5eaee100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6111e381613799565b5f61101a42613f56565b5f6001600160a01b03831661272d576040517f0fc22bfb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b612735611a05565b82111561276e576040517f500437ad00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6127798484611bfa565b90505f612785846120d1565b9050811580612792575080155b156127a1575f92505050610ecf565b806127ab85613aa1565b6127b5908461554b565b611bf1919061558f565b5f6001600160a01b038316612800576040517f0fc22bfb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b612808611a05565b82111561281657505f610ecf565b60028210156128285750612710610ecf565b6040545f906001600160a01b031663f87d29ac856128476001876155e2565b6040517fffffffff0000000000000000000000000000000000000000000000000000000060e085901b1681526001600160a01b0390921660048301526024820152604401602060405180830381865afa1580156128a6573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906128ca9190615507565b6040805490517ff87d29ac0000000000000000000000000000000000000000000000000000000081526001600160a01b038781166004830152602482018790529293505f929091169063f87d29ac90604401602060405180830381865afa158015612937573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061295b9190615507565b90505f6129688383615662565b90505f811361297e576043549350505050610ecf565b6001600160a01b0386165f908152603f60205260408120829190816129a460018a6155e2565b81526020019081526020015f20549050805f036129f3576129cf886129ca60018a6155e2565b6126ec565b5f036129e45761271095505050505050610ecf565b60435495505050505050610ecf565b808210612a095761271095505050505050610ecf565b612a1682826043546148cf565b98975050505050505050565b5f5f612a308360055461490f565b5f8181526006602090815260409182902082516080810184528154600f81810b8352700100000000000000000000000000000000909104900b928101929092526001810154928201929092526002909101546060820152909150612a948185613fa0565b949350505050565b5f612aa5611a05565b821115612ab357505f919050565b6002821015612ac55750612710919050565b6040545f906001600160a01b031663f5e6bfb9612ae36001866155e2565b6040518263ffffffff1660e01b8152600401612b0191815260200190565b602060405180830381865afa158015612b1c573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612b409190615507565b6040805490517ff5e6bfb9000000000000000000000000000000000000000000000000000000008152600481018690529192505f916001600160a01b039091169063f5e6bfb990602401602060405180830381865afa158015612ba5573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612bc99190615507565b90505f612bd68383615662565b90505f8113612beb5750506042549392505050565b805f603e81612bfb60018a6155e2565b81526020019081526020015f20549050808210612c2057506127109695505050505050565b612c2d82826042546148cf565b979650505050505050565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff161561117f576040517fd93c066500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b612c9c61312f565b333214612d0157335f908152600b602052604090205460ff16612d015760405162461bcd60e51b815260206004820152601a60248201527f536d61727420636f6e7472616374206e6f7420616c6c6f7765640000000000006044820152606401611460565b60035460ff1615612d545760405162461bcd60e51b815260206004820152601160248201527f756e6c6f636b656420676c6f62616c6c790000000000000000000000000000006044820152606401611460565b612d5c6131b0565b612d6682826149e4565b61103b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b6041546040517fdc4dab7f000000000000000000000000000000000000000000000000000000008152600481018390525f916001600160a01b03169063dc4dab7f906024015b602060405180830381865afa158015612df0573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610ecf9190615507565b6111e38133614b72565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff16612ee1575f848152602082815260408083206001600160a01b03871684529091529020805460ff19166001179055612e973390565b6001600160a01b0316836001600160a01b0316857f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a46001915050610ecf565b5f915050610ecf565b5092915050565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff1615612ee1575f848152602082815260408083206001600160a01b0387168085529252808320805460ff1916905551339287917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a46001915050610ecf565b612f9d61312f565b60035460ff1615612ff05760405162461bcd60e51b815260206004820152601160248201527f756e6c6f636b656420676c6f62616c6c790000000000000000000000000000006044820152606401611460565b6001600160a01b0382165f9081526004602090815260409182902082518084019093528054600f0b835260010154908201528161302b575f5ffd5b5f815f0151600f0b136130805760405162461bcd60e51b815260206004820152601660248201527f4e6f206578697374696e67206c6f636b20666f756e64000000000000000000006044820152606401611460565b428160200151116130f85760405162461bcd60e51b8152602060048201526024808201527f43616e6e6f742061646420746f2065787069726564206c6f636b2e205769746860448201527f64726177000000000000000000000000000000000000000000000000000000006064820152608401611460565b61310583835f845f614bfe565b5061103b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b7f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0080547ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016131aa576040517f3ee5aeb500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60029055565b335f9081526004602090815260409182902082518084019093528054600f0b8084526001909101549183019190915260035460ff1661323d57816020015142101561323d5760405162461bcd60e51b815260206004820152601660248201527f546865206c6f636b206469646e277420657870697265000000000000000000006044820152606401611460565b6040805180820182525f80825260208083018281523383526004909152929020905181547fffffffffffffffffffffffffffffffff00000000000000000000000000000000166fffffffffffffffffffffffffffffffff90911617815590516001909101556002546132af82826155e2565b600255604080518082019091525f80825260208201526132d2903390859061409a565b6001546132e9906001600160a01b03163384614d7b565b6040805183815242602082015233917ff279e6a1f5e320cca91135676d9cb6e44ca8a08c0b88342bcdb1144f6511b568910160405180910390a27f5e2aa66efd74cce82b21852e317e5490d9ecc9e6bb953ae24d90851258cc2f5c8161334f84826155e2565b604080519283526020830191909152015b60405180910390a1505050565b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b61339b614def565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300805460ff191681557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516001600160a01b0390911681526020015b60405180910390a150565b604154604080517fcfe8a73b00000000000000000000000000000000000000000000000000000000815290515f926001600160a01b03169163cfe8a73b9160048083019260209291908290030181865afa158015613466573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061348a9190615507565b61101a906301e1338061558f565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00610ecf565b61117f614e4a565b6134d0614e4a565b6001600160a01b0382166135265760405162461bcd60e51b815260206004820152601960248201527f546f6b656e20616464726573732063616e6e6f742062652030000000000000006044820152606401611460565b61353462093a80600261554b565b8110156135a95760405162461bcd60e51b815260206004820152602660248201527f4d696e206c6f636b2074696d65206d757374206265206174206c65617374203260448201527f207765656b7300000000000000000000000000000000000000000000000000006064820152608401611460565b6135b16134c0565b6135b9614e88565b6135c35f84612e1e565b50600180546001600160a01b038481167fffffffffffffffffffffffff000000000000000000000000000000000000000090921682179092555f80805260066020908152437f54cdd369e4e8a8515e52ca72ec816c2101831ad1f18bf44102ed171459c9b4fa55427f54cdd369e4e8a8515e52ca72ec816c2101831ad1f18bf44102ed171459c9b4f955600a80547fffffffffffffffffffffff000000000000000000000000000000000000000000169488169490941774010000000000000000000000000000000000000000179093558390556040519081527fa07c91c183e42229e705a9795a1c06d76528b673788b849597364528c96eefb7910160405180910390a16040518181527fb7b2f076f6aa608ed7fe4da7593c3d2b8dbba335eb2b74f73db7a04283015c5390602001613360565b6001600160a01b038116613738576040517f0fc22bfb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b604480547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b0383169081179091556040517f7e7ee4175d63f671fac3401d5f401ed18d1f48a586e756f404d5696fc77a7058905f90a250565b6001600160a01b0381166137d9576040517f0fc22bfb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b604180547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b0383169081179091556040517f5fafdf4fe7f5187184a137e5ea4a63b70da982b2f54234bae5c24bd79b5315d6905f90a250565b61271081118061384b5750610fa081105b15613882576040517f8757af3e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60428190556040518181527f5b9d8c0f68a9a01b140ef37bd4e62ac08e118ff62d2904ba038f8abe60faf70f906020016133fb565b6127108111806138c857506109c481105b156138ff576040517f8757af3e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60438190556040518181527f1ba04c88086339cbbe88fd8d60df261986f8296fcf88a70a8d1fabea75b1f70c906020016133fb565b61393c61312f565b3332146139a157335f908152600b602052604090205460ff166139a15760405162461bcd60e51b815260206004820152601a60248201527f536d61727420636f6e7472616374206e6f7420616c6c6f7765640000000000006044820152606401611460565b60035460ff16156139f45760405162461bcd60e51b815260206004820152601160248201527f756e6c6f636b656420676c6f62616c6c790000000000000000000000000000006044820152606401611460565b6139fd81614e98565b6111e360017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f8082815b6080811015613a975781831015613a97575f6002613a4984866155a2565b613a549060016155a2565b613a5e919061558f565b5f818152600660205260409020600201549091508710613a8057809350613a8e565b613a8b6001826155e2565b92505b50600101613a2b565b5090949350505050565b5f613aaa611a05565b821115613ae3576040517f500437ad00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6041546040517f2245498f000000000000000000000000000000000000000000000000000000008152600481018490525f916001600160a01b031690632245498f90602401602060405180830381865afa158015613b43573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190613b679190615507565b90506002831015613b785792915050565b5f613b8284612a9c565b90505f6127106127b5838561554b565b5f5f613b9c6126e2565b90508015613bb457613baf6001826155e2565b613bb6565b5f5b91505090565b6001600160a01b0382165f908152600860205260408120548190613be39085908590614fa5565b6001600160a01b0385165f9081526007602052604081209192509082633b9aca008110613c1257613c126155b5565b60408051608081018252600392909202929092018054600f81810b8452700100000000000000000000000000000000909104900b602083015260018101549282018390526002015460608201529150613c6b9085615662565b8160200151613c7a91906155f5565b81518290613c89908390615614565b600f90810b90915282515f910b12159050613ca2575f81525b51600f0b949350505050565b613cb661312f565b333214613d1b57335f908152600b602052604090205460ff16613d1b5760405162461bcd60e51b815260206004820152601a60248201527f536d61727420636f6e7472616374206e6f7420616c6c6f7765640000000000006044820152606401611460565b60035460ff1615612d5c5760405162461bcd60e51b815260206004820152601160248201527f756e6c6f636b656420676c6f62616c6c790000000000000000000000000000006044820152606401611460565b613d7661312f565b333214613ddb57335f908152600b602052604090205460ff16613ddb5760405162461bcd60e51b815260206004820152601a60248201527f536d61727420636f6e7472616374206e6f7420616c6c6f7765640000000000006044820152606401611460565b60035460ff1615613e2e5760405162461bcd60e51b815260206004820152601160248201527f756e6c6f636b656420676c6f62616c6c790000000000000000000000000000006044820152606401611460565b5f821180613e3b57505f81115b613ead5760405162461bcd60e51b815260206004820152602160248201527f56616c756520616e6420556e6c6f636b2063616e6e6f7420626f74682062652060448201527f30000000000000000000000000000000000000000000000000000000000000006064820152608401611460565b5f82118015613ebb57505f81115b15613ed757613ec982614e98565b613ed2816150bb565b612d66565b5f82118015613ee4575080155b15613ef257613ed282614e98565b612d66816150bb565b613f03612c38565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300805460ff191660011781557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258336133e7565b6041546040517f7e7b75ec000000000000000000000000000000000000000000000000000000008152600481018390525f916001600160a01b031690637e7b75ec90602401612dd5565b5f5f8390505f62093a80808360400151613fba919061558f565b613fc4919061554b565b90505f5b60ff81101561406c57613fde62093a80836155a2565b91505f85831115613ff157859250614004565b505f82815260096020526040902054600f0b5b604084015161401390846155e2565b846020015161402291906155f5565b84518590614031908390615614565b600f0b905250858303614044575061406c565b80846020018181516140569190615681565b600f0b9052505060408301829052600101613fc8565b505f825f0151600f0b121561407f575f82525b50516fffffffffffffffffffffffffffffffff169392505050565b604080516080810182525f808252602082018190529181018290526060810191909152604080516080810182525f8082526020820181905291810182905260608101919091526005545f9081906001600160a01b038816156142055742876020015111801561410e57505f875f0151600f0b135b15614153578651614124906303c26700906156cf565b600f0b60208087019190915287015161413e9042906155e2565b856020015161414d91906155f5565b600f0b85525b42866020015111801561416b57505f865f0151600f0b135b156141b0578551614181906303c26700906156cf565b600f0b60208086019190915286015161419b9042906155e2565b84602001516141aa91906155f5565b600f0b84525b6020808801515f90815260098252604090205490870151600f9190910b9350156142055786602001518660200151036141eb57829150614205565b6020808701515f90815260099091526040902054600f0b91505b604080516080810182525f80825260208201524291810191909152436060820152811561428557505f8181526006602090815260409182902082516080810184528154600f81810b8352700100000000000000000000000000000000909104900b9281019290925260018101549282019290925260029091015460608201525b6040810151606082015181905f428310156142d75760408501516142a990426155e2565b60608601516142b890436155e2565b6142ca90670de0b6b3a764000061554b565b6142d4919061558f565b90505b5f62093a806142e6818761558f565b6142f0919061554b565b90505f5b60ff8110156144665761430a62093a80836155a2565b91505f4283111561431d57429250614330565b505f82815260096020526040902054600f0b5b61433a87846155e2565b886020015161434991906155f5565b88518990614358908390615614565b600f0b905250602088018051829190614372908390615681565b600f90810b90915289515f910b1215905061438b575f88525b5f8860200151600f0b12156143a1575f60208901525b604088018390529195508591670de0b6b3a76400006143c087856155e2565b6143ca908661554b565b6143d4919061558f565b6143de90866155a2565b60608901526143ee60018a6155a2565b98504283036144035750436060880152614466565b5f898152600660209081526040918290208a51918b01516fffffffffffffffffffffffffffffffff9081167001000000000000000000000000000000000292169190911781559089015160018201556060890151600290910155506001016142f4565b5060058790556001600160a01b038e16156144f4578a602001518a6020015161448f9190615614565b866020018181516144a09190615681565b600f0b9052508a518a516144b49190615614565b865187906144c3908390615681565b600f90810b90915260208801515f910b121590506144e2575f60208701525b5f865f0151600f0b12156144f4575f86525b5f878152600660209081526040918290208851918901516fffffffffffffffffffffffffffffffff90811670010000000000000000000000000000000002921691909117815590870151600182015560608701516002909101556001600160a01b038e161561475757428d6020015111156145e95760208b0151614578908a615681565b98508c602001518c602001510361459b5760208a0151614598908a615614565b98505b60208d8101515f90815260099091526040902080547fffffffffffffffffffffffffffffffff00000000000000000000000000000000166fffffffffffffffffffffffffffffffff8b161790555b428c602001511115614664578c602001518c6020015111156146645760208a01516146149089615614565b60208d8101515f90815260099091526040902080547fffffffffffffffffffffffffffffffff00000000000000000000000000000000166fffffffffffffffffffffffffffffffff831617905597505b6001600160a01b038e165f908152600860205260408120548f919061468a9060016155a2565b90508060085f846001600160a01b03166001600160a01b031681526020019081526020015f2081905550428c6040018181525050438c60600181815250508b60075f846001600160a01b03166001600160a01b031681526020019081526020015f2082633b9aca008110614700576147006155b5565b825160208401516fffffffffffffffffffffffffffffffff90811670010000000000000000000000000000000002911617600391909102919091019081556040820151600182015560609091015160029091015550505b5050505050505050505050505050565b6001600160a01b0381166147a7576040517f0fc22bfb00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b604080547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b038316908117825590517f52d161c0b054ff0f476f54f34dd34c480edb4a541cb443cf5a0f73d96acf2350905f90a250565b61480e61312f565b33321461487357335f908152600b602052604090205460ff166148735760405162461bcd60e51b815260206004820152601a60248201527f536d61727420636f6e7472616374206e6f7420616c6c6f7765640000000000006044820152606401611460565b60035460ff16156148c65760405162461bcd60e51b815260206004820152601160248201527f756e6c6f636b656420676c6f62616c6c790000000000000000000000000000006044820152606401611460565b6139fd816150bb565b5f825f036148e05750612710611c8e565b5f6148ed836127106155e2565b90505f846148fb838861554b565b614905919061558f565b611e8290856155a2565b5f815f0361491e57505f610ecf565b5f805260066020527f54cdd369e4e8a8515e52ca72ec816c2101831ad1f18bf44102ed171459c9b4f95483101561495657505f610ecf565b5f828152600660205260409020600101548310614974575080610ecf565b5f82815b6080811015613a975781831015613a97575f600261499684866155a2565b6149a19060016155a2565b6149ab919061558f565b5f8181526006602052604090206001015490915087106149cd578093506149db565b6149d86001826155e2565b92505b50600101614978565b5f82116149ef575f5ffd5b335f9081526004602090815260409182902082518084019093528054600f0b8084526001909101549183019190915215614a6b5760405162461bcd60e51b815260206004820152601960248201527f5769746864726177206f6c6420746f6b656e73206669727374000000000000006044820152606401611460565b5f62093a80614a7a818561558f565b614a84919061554b565b90505f5442614a9391906155a2565b811015614b075760405162461bcd60e51b8152602060048201526024808201527f566f74696e67206c6f636b206d757374206265206174206c65617374204d494e60448201527f54494d45000000000000000000000000000000000000000000000000000000006064820152608401611460565b614b156303c26700426155a2565b811115614b645760405162461bcd60e51b815260206004820152601e60248201527f566f74696e67206c6f636b2063616e2062652032207965617273206d617800006044820152606401611460565b6110dd338583856001614bfe565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408083206001600160a01b038516845290915290205460ff1661103b576040517fe2517d3f0000000000000000000000000000000000000000000000000000000081526001600160a01b038216600482015260248101839052604401611460565b6002548290614c0d86826155a2565b600255604080518082019091525f8082526020820152825160208085015190830152600f0b8152825187908490614c45908390615681565b600f0b9052508515614c5957602083018690525b6001600160a01b0388165f908152600460209081526040909120845181547fffffffffffffffffffffffffffffffff00000000000000000000000000000000166fffffffffffffffffffffffffffffffff90911617815590840151600190910155614cc588828561409a565b8615614ce357600154614ce3906001600160a01b031689308a615267565b8260200151886001600160a01b03167fbe9cf0e939c614fad640a623a53ba0a807c8cb503c4c4c8dacabe27b86ff2dd5898742604051614d2593929190615742565b60405180910390a37f5e2aa66efd74cce82b21852e317e5490d9ecc9e6bb953ae24d90851258cc2f5c82614d5989826155a2565b6040805192835260208301919091520160405180910390a15050505050505050565b6040516001600160a01b0383811660248301526044820183905261112f91859182169063a9059cbb906064015b604051602081830303815290604052915060e01b6020820180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff83818316178352505050506152a0565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff1661117f576040517f8dfc202b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b614e52615325565b61117f576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b614e90614e4a565b61117f615343565b335f9081526004602090815260409182902082518084019093528054600f0b8352600101549082015281614eca575f5ffd5b5f815f0151600f0b13614f1f5760405162461bcd60e51b815260206004820152601660248201527f4e6f206578697374696e67206c6f636b20666f756e64000000000000000000006044820152606401611460565b42816020015111614f975760405162461bcd60e51b8152602060048201526024808201527f43616e6e6f742061646420746f2065787069726564206c6f636b2e205769746860448201527f64726177000000000000000000000000000000000000000000000000000000006064820152608401611460565b61103b33835f846002614bfe565b5f815f03614fb457505f611c8e565b6001600160a01b0384165f90815260076020526040902060010154831015614fdd57505f611c8e565b6001600160a01b0384165f90815260076020526040902082633b9aca008110615008576150086155b5565b6003020160010154831061501d575080611c8e565b5f82815b60808110156150b057818310156150b0575f600261503f84866155a2565b61504a9060016155a2565b615054919061558f565b6001600160a01b0389165f908152600760205260409020909150879082633b9aca008110615084576150846155b5565b600302016001015411615099578093506150a7565b6150a46001826155e2565b92505b50600101615021565b509095945050505050565b335f90815260046020908152604080832081518083019092528054600f0b825260010154918101919091529062093a806150f5818561558f565b6150ff919061554b565b9050428260200151116151545760405162461bcd60e51b815260206004820152600c60248201527f4c6f636b206578706972656400000000000000000000000000000000000000006044820152606401611460565b5f825f0151600f0b136151a95760405162461bcd60e51b815260206004820152601160248201527f4e6f7468696e67206973206c6f636b65640000000000000000000000000000006044820152606401611460565b816020015181116151fc5760405162461bcd60e51b815260206004820152601f60248201527f43616e206f6e6c7920696e637265617365206c6f636b206475726174696f6e006044820152606401611460565b61520a6303c26700426155a2565b8111156152595760405162461bcd60e51b815260206004820152601e60248201527f566f74696e67206c6f636b2063616e2062652032207965617273206d617800006044820152606401611460565b61112f335f83856003614bfe565b6040516001600160a01b0384811660248301528381166044830152606482018390526110dd9186918216906323b872dd90608401614da8565b5f5f60205f8451602086015f885af1806152bf576040513d5f823e3d81fd5b50505f513d915081156152d65780600114156152e3565b6001600160a01b0384163b155b156110dd576040517f5274afe70000000000000000000000000000000000000000000000000000000081526001600160a01b0385166004820152602401611460565b5f61532e613498565b5468010000000000000000900460ff16919050565b61336d614e4a565b80356001600160a01b0381168114615361575f5ffd5b919050565b5f60208284031215615376575f5ffd5b611c8e8261534b565b5f6020828403121561538f575f5ffd5b81357fffffffff0000000000000000000000000000000000000000000000000000000081168114611c8e575f5ffd5b602081525f82518060208401528060208501604085015e5f6040828501015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011684010191505092915050565b5f60208284031215615421575f5ffd5b5035919050565b5f5f60408385031215615439575f5ffd5b50508035926020909101359150565b5f5f60408385031215615459575f5ffd5b6154628361534b565b946020939093013593505050565b5f5f60408385031215615481575f5ffd5b823591506154916020840161534b565b90509250929050565b5f5f5f5f5f5f5f60e0888a0312156154b0575f5ffd5b6154b98861534b565b96506154c76020890161534b565b95506154d56040890161534b565b9450606088013593506154ea6080890161534b565b9699959850939692959460a0840135945060c09093013592915050565b5f60208284031215615517575f5ffd5b5051919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b8082028115828204841417610ecf57610ecf61551e565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b5f8261559d5761559d615562565b500490565b80820180821115610ecf57610ecf61551e565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b81810381811115610ecf57610ecf61551e565b5f82600f0b82600f0b0280600f0b9150808214612eea57612eea61551e565b600f82810b9082900b037fffffffffffffffffffffffffffffffff8000000000000000000000000000000081126f7fffffffffffffffffffffffffffffff82131715610ecf57610ecf61551e565b8181035f831280158383131683831282161715612eea57612eea61551e565b600f81810b9083900b016f7fffffffffffffffffffffffffffffff81137fffffffffffffffffffffffffffffffff8000000000000000000000000000000082121715610ecf57610ecf61551e565b5f81600f0b83600f0b806156e5576156e5615562565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff81147fffffffffffffffffffffffffffffffff80000000000000000000000000000000831416156157395761573961551e565b90059392505050565b838152606081016004841061577e577f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b60208201939093526040015291905056fea164736f6c634300081d000a";

// bytecodes/BondingCurveRegistry.ts
var BondingCurveRegistryBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b611711806100d65f395ff3fe608060405234801561000f575f5ffd5b5060043610610178575f3560e01c80637c79f82e116100d2578063c4d66de811610088578063db92273811610063578063db9227381461034d578063e30c39781461036c578063f2fde38b14610374575f5ffd5b8063c4d66de814610314578063cba244c614610327578063cdd9e5731461033a575f5ffd5b8063a0760cad116100b8578063a0760cad146102db578063c0a24ae5146102ee578063c4c3994514610301575f5ffd5b80637c79f82e146102c05780638da5cb5b146102d3575f5ffd5b8063687da9ec11610132578063798464691161010d578063798464691461029257806379ba5097146102a55780637c11d624146102ad575f5ffd5b8063687da9ec1461020e578063715018a61461022e5780637310e80b14610238575f5ffd5b806346d2779a1161016257806346d2779a146101aa5780634a14b475146101bd5780636199b7ff146101fb575f5ffd5b8062cfbc981461017c57806306661abd146101a2575b5f5ffd5b61018f61018a3660046113d6565b610387565b6040519081526020015b60405180910390f35b61018f5f5481565b61018f6101b8366004611405565b61047e565b6101eb6101cb3660046114dd565b805160208183018101805160038252928201919093012091525460ff1681565b6040519015158152602001610199565b61018f6102093660046113d6565b610561565b61022161021c366004611405565b610613565b6040516101999190611557565b61023661070d565b005b61026d610246366004611405565b60016020525f908152604090205473ffffffffffffffffffffffffffffffffffffffff1681565b60405173ffffffffffffffffffffffffffffffffffffffff9091168152602001610199565b61018f6102a03660046113d6565b610720565b6102366107d2565b61018f6102bb3660046115aa565b610852565b61018f6102ce3660046113d6565b610940565b61026d6109f2565b61018f6102e9366004611405565b610a33565b6101eb6102fc366004611405565b610aeb565b61018f61030f3660046113d6565b610afb565b6102366103223660046115d3565b610bad565b6102366103353660046115d3565b610d16565b61018f6103483660046113d6565b611005565b61018f61035b3660046115d3565b60026020525f908152604090205481565b61026d6110b7565b6102366103823660046115d3565b6110df565b5f8161039281611196565b6103c8576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f83815260016020526040908190205490517f7f0e803000000000000000000000000000000000000000000000000000000000815260048101889052602481018790526044810186905273ffffffffffffffffffffffffffffffffffffffff90911690637f0e8030906064015b602060405180830381865afa158015610450573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906104749190611606565b9695505050505050565b5f8161048981611196565b6104bf576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f838152600160209081526040918290205482517fc65b61ca000000000000000000000000000000000000000000000000000000008152925173ffffffffffffffffffffffffffffffffffffffff9091169263c65b61ca9260048083019391928290030181865afa158015610536573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061055a9190611606565b9392505050565b5f8161056c81611196565b6105a2576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f83815260016020526040908190205490517f224fe64d00000000000000000000000000000000000000000000000000000000815260048101889052602481018790526044810186905273ffffffffffffffffffffffffffffffffffffffff9091169063224fe64d90606401610435565b60608161061f81611196565b610655576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f838152600160205260408082205481517f06fdde03000000000000000000000000000000000000000000000000000000008152915173ffffffffffffffffffffffffffffffffffffffff909116926306fdde0392600480820193918290030181865afa1580156106c8573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016820160405261055a919081019061161d565b6107156111a9565b61071e5f611201565b565b5f8161072b81611196565b610761576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f83815260016020526040908190205490517fc50cb15600000000000000000000000000000000000000000000000000000000815260048101889052602481018790526044810186905273ffffffffffffffffffffffffffffffffffffffff9091169063c50cb15690606401610435565b33806107dc6110b7565b73ffffffffffffffffffffffffffffffffffffffff1614610846576040517f118cdaa700000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff821660048201526024015b60405180910390fd5b61084f81611201565b50565b5f8361085d81611196565b610893576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f85815260016020526040908190205490517f159d4167000000000000000000000000000000000000000000000000000000008152600481018690526024810185905273ffffffffffffffffffffffffffffffffffffffff9091169063159d416790604401602060405180830381865afa158015610913573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906109379190611606565b95945050505050565b5f8161094b81611196565b610981576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f83815260016020526040908190205490517f8082729900000000000000000000000000000000000000000000000000000000815260048101889052602481018790526044810186905273ffffffffffffffffffffffffffffffffffffffff90911690638082729990606401610435565b5f807f9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c1993005b5473ffffffffffffffffffffffffffffffffffffffff1692915050565b5f81610a3e81611196565b610a74576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f838152600160209081526040918290205482517f94b2294b000000000000000000000000000000000000000000000000000000008152925173ffffffffffffffffffffffffffffffffffffffff909116926394b2294b9260048083019391928290030181865afa158015610536573d5f5f3e3d5ffd5b5f610af582611196565b92915050565b5f81610b0681611196565b610b3c576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f83815260016020526040908190205490517fe6519f6800000000000000000000000000000000000000000000000000000000815260048101889052602481018790526044810186905273ffffffffffffffffffffffffffffffffffffffff9091169063e6519f6890606401610435565b5f610bb6611255565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f81158015610be25750825b90505f8267ffffffffffffffff166001148015610bfe5750303b155b905081158015610c0c575080155b15610c43576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff00000000000000001660011785558315610ca45784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b610cad8661127d565b8315610d0e5784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b505050505050565b610d1e6111a9565b73ffffffffffffffffffffffffffffffffffffffff8116610d6b576040517f3bd67dd900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b73ffffffffffffffffffffffffffffffffffffffff81165f9081526002602052604090205415610dc7576040517f10d9656500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f8173ffffffffffffffffffffffffffffffffffffffff166306fdde036040518163ffffffff1660e01b81526004015f60405180830381865afa158015610e10573d5f5f3e3d5ffd5b505050506040513d5f823e601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0168201604052610e55919081019061161d565b905080515f03610e91576040517fa3a2038f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600381604051610ea19190611692565b9081526040519081900360200190205460ff1615610eeb576040517f3f41f42000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5f8154610ef8906116a8565b909155505f8054815260016020818152604080842080547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff88169081179091558454908552600290925292839020559051600390610f6d908490611692565b90815260405190819003602001812080549215157fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0090931692909217909155610fb7908290611692565b6040519081900381205f8054919273ffffffffffffffffffffffffffffffffffffffff861692917fa30dc6f02196f8f7bf3027ca332ca1f79dfe9a26fefb83bda889f621f72501ae91a45050565b5f8161101081611196565b611046576040517f0fa6af6600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f83815260016020526040908190205490517f1740e54500000000000000000000000000000000000000000000000000000000815260048101889052602481018790526044810186905273ffffffffffffffffffffffffffffffffffffffff90911690631740e54590606401610435565b5f807f237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c00610a16565b6110e76111a9565b7f237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c0080547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff831690811782556111506109f2565b73ffffffffffffffffffffffffffffffffffffffff167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a35050565b5f5f82118015610af55750505f54101590565b336111b26109f2565b73ffffffffffffffffffffffffffffffffffffffff161461071e576040517f118cdaa700000000000000000000000000000000000000000000000000000000815233600482015260240161083d565b7f237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c0080547fffffffffffffffffffffffff00000000000000000000000000000000000000001681556112518261128e565b5050565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00610af5565b611285611323565b61084f81611361565b7f9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c19930080547fffffffffffffffffffffffff0000000000000000000000000000000000000000811673ffffffffffffffffffffffffffffffffffffffff848116918217845560405192169182907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a3505050565b61132b6113b8565b61071e576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611369611323565b73ffffffffffffffffffffffffffffffffffffffff8116610846576040517f1e4fbdf70000000000000000000000000000000000000000000000000000000081525f600482015260240161083d565b5f6113c1611255565b5468010000000000000000900460ff16919050565b5f5f5f5f608085870312156113e9575f5ffd5b5050823594602084013594506040840135936060013592509050565b5f60208284031215611415575f5ffd5b5035919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b604051601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016810167ffffffffffffffff811182821017156114905761149061141c565b604052919050565b5f67ffffffffffffffff8211156114b1576114b161141c565b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01660200190565b5f602082840312156114ed575f5ffd5b813567ffffffffffffffff811115611503575f5ffd5b8201601f81018413611513575f5ffd5b803561152661152182611498565b611449565b81815285602083850101111561153a575f5ffd5b816020840160208301375f91810160200191909152949350505050565b602081525f82518060208401528060208501604085015e5f6040828501015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011684010191505092915050565b5f5f5f606084860312156115bc575f5ffd5b505081359360208301359350604090920135919050565b5f602082840312156115e3575f5ffd5b813573ffffffffffffffffffffffffffffffffffffffff8116811461055a575f5ffd5b5f60208284031215611616575f5ffd5b5051919050565b5f6020828403121561162d575f5ffd5b815167ffffffffffffffff811115611643575f5ffd5b8201601f81018413611653575f5ffd5b805161166161152182611498565b818152856020838501011115611675575f5ffd5b8160208401602083015e5f91810160200191909152949350505050565b5f82518060208501845e5f920191825250919050565b5f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff82036116fd577f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b506001019056fea164736f6c634300081d000a";

// bytecodes/LinearCurve.ts
var LinearCurveBytecode = "0x6080604052348015600e575f5ffd5b506015601f565b601b601f565b60cf565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff1615606e5760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460cc5780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b610d0e806100dc5f395ff3fe608060405260043610610157575f3560e01c8063827c9086116100bb578063c50cb15611610071578063d2ffd5bf11610057578063d2ffd5bf146102be578063e6519f6814610252578063f62d1888146102d8575f5ffd5b8063c50cb156146101d1578063c65b61ca14610290575f5ffd5b806394b2294b116100a157806394b2294b146102905780639df965e7146101f0578063b7d122b5146102a3575f5ffd5b8063827c9086146102055780638ef50b9614610271575f5ffd5b80633c125b4d1161011057806376b1d08f116100f657806376b1d08f1461021f5780637f0e8030146102335780638082729914610252575f5ffd5b80633c125b4d146102055780633e8ff57b1461021f575f5ffd5b80631740e545116101405780631740e545146101b2578063224fe64d146101d157806330c276af146101f0575f5ffd5b806306fdde031461015b578063159d416714610185575b5f5ffd5b348015610166575f5ffd5b5061016f6102f7565b60405161017c91906109d0565b60405180910390f35b348015610190575f5ffd5b506101a461019f366004610a23565b610382565b60405190815260200161017c565b3480156101bd575f5ffd5b506101a46101cc366004610a43565b6103ac565b3480156101dc575f5ffd5b506101a46101eb366004610a43565b6103f3565b6102036101fe366004610a6c565b610426565b005b348015610210575f5ffd5b506040515f815260200161017c565b34801561022a575f5ffd5b506101a45f1981565b34801561023e575f5ffd5b506101a461024d366004610a43565b610458565b34801561025d575f5ffd5b506101a461026c366004610a43565b610490565b34801561027c575f5ffd5b506101a461028b366004610a23565b6104b3565b34801561029b575f5ffd5b505f196101a4565b3480156102ae575f5ffd5b506101a4670de0b6b3a764000081565b3480156102c9575f5ffd5b506101a461028b366004610a6c565b3480156102e3575f5ffd5b506102036102f2366004610ab9565b6104e6565b5f805461030390610b27565b80601f016020809104026020016040519081016040528092919081815260200182805461032f90610b27565b801561037a5780601f106103515761010080835404028352916020019161037a565b820191905f5260205f20905b81548152906001019060200180831161035d57829003601f168201915b505050505081565b5f61039082845f1980610685565b6103a3670de0b6b3a764000084846106cf565b90505b92915050565b5f6103ba82845f1980610685565b6103c684845f196106f2565b82156103dc576103d784838561073a565b6103de565b835b90506103ec81835f19610766565b9392505050565b5f61040183835f1980610685565b61040d84845f19610766565b6104188484846107a9565b90506103ec81835f196106f2565b6040517f0e94648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61046683835f1980610685565b61047084846107bc565b81156104865761048184838561073a565b610488565b835b949350505050565b5f61049e82845f1980610685565b6104a884846107fa565b6104888484846106cf565b5f6040517f0e94648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6104ef610834565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f8115801561051b5750825b90505f8267ffffffffffffffff1660011480156105375750303b155b905081158015610545575080155b1561057c576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156105dd5784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b61061b87878080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061085c92505050565b831561067c5784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50505050505050565b8184118061069257508083115b156106c9576040517f9c1f834900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b50505050565b5f8280156106e7576106e28584836108e4565b6106e9565b845b95945050505050565b6106fc8282610b78565b831115610735576040517f52c4014100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b505050565b5f6107468484846108e4565b905081838509156103ec57600101806103ec5763ae47f7025f526004601cfd5b6107708282610b78565b831115610735576040517f356cd28700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f8180156106e7576106e28582866108e4565b808211156107f6576040517fd839673100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5050565b808211156107f6576040517f36172e8f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a006103a6565b610864610972565b80515f0361089e576040517fe465a80300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6108a98282610c28565b507fb7773e9891add319d8c6dd41c3664b1dba6a1dddd32fa2bf94afe68cf5bdd50f816040516108d991906109d0565b60405180910390a150565b8282028183858304148515170261096b575f198385098181108201900382848609835f03841682851161091e5763ae47f7025f526004601cfd5b93849004938382119092035f8390038390046001010292030417600260038302811880840282030280840282030280840282030280840282030280840282030280840290910302026103ec565b0492915050565b61097a6109b2565b6109b0576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b565b5f6109bb610834565b5468010000000000000000900460ff16919050565b602081525f82518060208401528060208501604085015e5f6040828501015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011684010191505092915050565b5f5f60408385031215610a34575f5ffd5b50508035926020909101359150565b5f5f5f60608486031215610a55575f5ffd5b505081359360208301359350604090920135919050565b5f5f5f60608486031215610a7e575f5ffd5b83359250602084013573ffffffffffffffffffffffffffffffffffffffff81168114610aa8575f5ffd5b929592945050506040919091013590565b5f5f60208385031215610aca575f5ffd5b823567ffffffffffffffff811115610ae0575f5ffd5b8301601f81018513610af0575f5ffd5b803567ffffffffffffffff811115610b06575f5ffd5b856020828401011115610b17575f5ffd5b6020919091019590945092505050565b600181811c90821680610b3b57607f821691505b602082108103610b72577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b818103818111156103a6577f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b601f82111561073557805f5260205f20601f840160051c81016020851015610c025750805b601f840160051c820191505b81811015610c21575f8155600101610c0e565b5050505050565b815167ffffffffffffffff811115610c4257610c42610bb0565b610c5681610c508454610b27565b84610bdd565b6020601f821160018114610c88575f8315610c715750848201515b5f19600385901b1c1916600184901b178455610c21565b5f848152602081207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08516915b82811015610cd55787850151825560209485019460019092019101610cb5565b5084821015610cf257868401515f19600387901b60f8161c191681555b50505050600190811b0190555056fea164736f6c634300081d000a";

// bytecodes/OffsetProgressiveCurve.ts
var OffsetProgressiveCurveBytecode = "0x6080604052348015600e575f5ffd5b506015601f565b601b601f565b60cf565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff1615606e5760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460cc5780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b6113e3806100dc5f395ff3fe60806040526004361061016d575f3560e01c80638b7cc629116100c6578063a88a22fd1161007c578063ce665dd811610057578063ce665dd81461032d578063d2ffd5bf14610342578063e6519f681461027e575f5ffd5b8063a88a22fd14610304578063c50cb156146101e7578063c65b61ca14610319575f5ffd5b806394b2294b116100ac57806394b2294b146102d1578063977d08c0146102e55780639df965e714610206575f5ffd5b80638b7cc6291461029d5780638ef50b96146102b2575f5ffd5b80633c125b4d116101265780637f0e8030116101015780637f0e80301461025f578063808272991461027e578063827c90861461021b575f5ffd5b80633c125b4d1461021b5780633e8ff57b1461023557806376b1d08f1461024a575f5ffd5b80631740e545116101565780631740e545146101c8578063224fe64d146101e757806330c276af14610206575f5ffd5b806306fdde0314610171578063159d41671461019b575b5f5ffd5b34801561017c575f5ffd5b5061018561035c565b604051610192919061102b565b60405180910390f35b3480156101a6575f5ffd5b506101ba6101b536600461107e565b6103e7565b604051908152602001610192565b3480156101d3575f5ffd5b506101ba6101e236600461109e565b610424565b3480156101f2575f5ffd5b506101ba61020136600461109e565b6104a7565b6102196102143660046110c7565b6104bb565b005b348015610226575f5ffd5b506040515f8152602001610192565b348015610240575f5ffd5b506101ba60045481565b348015610255575f5ffd5b506101ba60055481565b34801561026a575f5ffd5b506101ba61027936600461109e565b6104ed565b348015610289575f5ffd5b506101ba61029836600461109e565b610552565b3480156102a8575f5ffd5b506101ba60015481565b3480156102bd575f5ffd5b506101ba6102cc36600461107e565b61055e565b3480156102dc575f5ffd5b506005546101ba565b3480156102f0575f5ffd5b506102196102ff366004611114565b610591565b34801561030f575f5ffd5b506101ba60025481565b348015610324575f5ffd5b506004546101ba565b348015610338575f5ffd5b506101ba60035481565b34801561034d575f5ffd5b506101ba6102cc3660046110c7565b5f80546103689061118e565b80601f01602080910402602001604051908101604052809291908181526020018280546103949061118e565b80156103df5780601f106103b6576101008083540402835291602001916103df565b820191905f5260205f20905b8154815290600101906020018083116103c257829003601f168201915b505050505081565b5f6103f882846005546004546107fc565b5f610406845b600354610846565b905061041a6104178260015461085b565b90565b9150505b92915050565b5f61043582846005546004546107fc565b6104428484600454610869565b5f61044c846103fe565b90505f61045e8287610846565b610846565b90505f61047b61046d836108b1565b610476856108bc565b6108c7565b90505f61048a826002546108d5565b905080945061049c85876005546108ec565b505050509392505050565b5f6104b384848461092f565b949350505050565b6040517f0e94648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6104fe83836005546004546107fc565b61050884846109a3565b5f610512836103fe565b90505f610521866002546109e1565b90505f610536610530846108bc565b836108c7565b90505f61054684610476846109f8565b98975050505050505050565b5f6104b3848484610a6b565b5f6040517f0e94648f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61059a610ac4565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f811580156105c65750825b90505f8267ffffffffffffffff1660011480156105e25750303b155b9050811580156105f0575080155b15610627576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156106885784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b6106c689898080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250610aec92505050565b8615806106dc57506106d960028861120c565b15155b15610713576040517fd63d061900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8660015561072561041760028961124c565b600255856003555f61075661074e610749610417670de0b6b3a76400005f1961124c565b6109f8565b6003546108c7565b90505f61078661077e61077361076e85600354610846565b6108bc565b6104766003546108b1565b60025461085b565b6004929092555060055583156107f15784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b505050505050505050565b8184118061080957508083115b15610840576040517f9c1f834900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b50505050565b5f610854610417838561125f565b9392505050565b5f6108546104178484610b74565b6108738282611272565b8311156108ac576040517f52c4014100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b505050565b5f61041e82836108d5565b5f61041e828361085b565b5f6108546104178385611272565b5f6108546104178484670de0b6b3a7640000610c59565b6108f68282611272565b8311156108ac576040517f356cd28700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61094083836005546004546107fc565b61094d84846005546108ec565b5f610957836103fe565b90505f610972610966836108bc565b61045988600254610c85565b90505f610987610981836109f8565b846108c7565b90508093506109998486600454610869565b5050509392505050565b808211156109dd576040517fd839673100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5050565b5f61085461041784670de0b6b3a764000085610c59565b5f817812725dd1d243aba0e75fe645cc4873f9e65afe688c928e1f21811115610a55576040517fedc236ad000000000000000000000000000000000000000000000000000000008152600481018490526024015b60405180910390fd5b610854610417670de0b6b3a76400008302610c9c565b5f610a7c82846005546004546107fc565b610a868484610e1d565b5f610a90846103fe565b90505f610a9d82876108c7565b90505f610ab5610aac846108bc565b610476846108bc565b90505f6105468260025461085b565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a0061041e565b610af4610e57565b80515f03610b2e576040517fe465a80300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f610b3982826112fd565b507fb7773e9891add319d8c6dd41c3664b1dba6a1dddd32fa2bf94afe68cf5bdd50f81604051610b69919061102b565b60405180910390a150565b5f80805f19848609848602925082811083820303915050805f03610ba55750670de0b6b3a76400009004905061041e565b670de0b6b3a76400008110610bf0576040517f5173648d0000000000000000000000000000000000000000000000000000000081526004810186905260248101859052604401610a4c565b5f670de0b6b3a7640000858709620400008185030493109091037d40000000000000000000000000000000000000000000000000000000000002919091177faccb18165bd6fe31ae1cf318dc5b51eee0e1ba569b88cd74c1773b91fac106690291505092915050565b5f610c65848484610e97565b9050818385091561085457600101806108545763ae47f7025f526004601cfd5b5f61085461041784670de0b6b3a764000085610f25565b5f815f03610cab57505f919050565b506001817001000000000000000000000000000000008110610cd25760409190911b9060801c5b680100000000000000008110610ced5760209190911b9060401c5b6401000000008110610d045760109190911b9060201c5b620100008110610d195760089190911b9060101c5b6101008110610d2d5760049190911b9060081c5b60108110610d405760029190911b9060041c5b60048110610d5057600182901b91505b6001828481610d6157610d616111df565b048301901c91506001828481610d7957610d796111df565b048301901c91506001828481610d9157610d916111df565b048301901c91506001828481610da957610da96111df565b048301901c91506001828481610dc157610dc16111df565b048301901c91506001828481610dd957610dd96111df565b048301901c91506001828481610df157610df16111df565b048301901c91505f828481610e0857610e086111df565b049050808310610e16578092505b5050919050565b808211156109dd576040517f36172e8f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610e5f61100d565b610e95576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b565b82820281838583041485151702610f1e575f198385098181108201900382848609835f038416828511610ed15763ae47f7025f526004601cfd5b93849004938382119092035f839003839004600101029203041760026003830281188084028203028084028203028084028203028084028203028084028203028084029091030202610854565b0492915050565b5f80805f19858709858702925082811083820303915050805f03610f5c57838281610f5257610f526111df565b0492505050610854565b838110610fa6576040517f63a05778000000000000000000000000000000000000000000000000000000008152600481018790526024810186905260448101859052606401610a4c565b5f8486880960026001871981018816978890046003810283188082028403028082028403028082028403028082028403028082028403029081029092039091025f889003889004909101858311909403939093029303949094049190911702949350505050565b5f611016610ac4565b5468010000000000000000900460ff16919050565b602081525f82518060208401528060208501604085015e5f6040828501015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011684010191505092915050565b5f5f6040838503121561108f575f5ffd5b50508035926020909101359150565b5f5f5f606084860312156110b0575f5ffd5b505081359360208301359350604090920135919050565b5f5f5f606084860312156110d9575f5ffd5b83359250602084013573ffffffffffffffffffffffffffffffffffffffff81168114611103575f5ffd5b929592945050506040919091013590565b5f5f5f5f60608587031215611127575f5ffd5b843567ffffffffffffffff81111561113d575f5ffd5b8501601f8101871361114d575f5ffd5b803567ffffffffffffffff811115611163575f5ffd5b876020828401011115611174575f5ffd5b602091820198909750908601359560400135945092505050565b600181811c908216806111a257607f821691505b6020821081036111d9577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b5f8261121a5761121a6111df565b500690565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f8261125a5761125a6111df565b500490565b8082018082111561041e5761041e61121f565b8181038181111561041e5761041e61121f565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b601f8211156108ac57805f5260205f20601f840160051c810160208510156112d75750805b601f840160051c820191505b818110156112f6575f81556001016112e3565b5050505050565b815167ffffffffffffffff81111561131757611317611285565b61132b81611325845461118e565b846112b2565b6020601f82116001811461135d575f83156113465750848201515b5f19600385901b1c1916600184901b1784556112f6565b5f848152602081207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08516915b828110156113aa578785015182556020948501946001909201910161138a565b50848210156113c757868401515f19600387901b60f8161c191681555b50505050600190811b0190555056fea164736f6c634300081d000a";

// bytecodes/DynamicFeeFlatPriceCurve.ts
var DynamicFeeFlatPriceCurveBytecode = "0x6080604052348015600e575f5ffd5b5060156025565b601b6025565b60216025565b60d5565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560745760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460d25780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b61455e806100e25f395ff3fe608060405260043610610391575f3560e01c8063827c9086116101de578063c2375b0211610108578063dd6133921161009d578063f14709761161006d578063f147097614610b02578063f2fde38b14610b21578063f62d188814610b40578063fa998af214610b5f575f5ffd5b8063dd61339214610a6a578063e30c397814610acf578063e6519f6814610720578063e8d4da1214610ae3575f5ffd5b8063c65b61ca116100d8578063c65b61ca146107f9578063d178145814610a0d578063d2ffd5bf14610a2c578063d9c1036614610a4b575f5ffd5b8063c2375b0214610913578063c34b2d2b14610932578063c3f909d414610951578063c50cb1561461049e575f5ffd5b80639b60f6831161017e578063ac135cb31161014e578063ac135cb3146108aa578063b391c508146108d5578063b7d122b514610501578063bb371ca7146108f4575f5ffd5b80639b60f6831461080c5780639df965e714610842578063a6e82b8814610855578063a9a3a5f61461088b575f5ffd5b80638da5cb5b116101b95780638da5cb5b146107905780638ef50b96146107a4578063923b2d12146107c357806394b2294b146107f9575f5ffd5b8063827c908614610538578063872b56ce1461042a5780638c3ecc451461073f575f5ffd5b8063434fed35116102bf578063715018a61161025f57806376b1d08f1161022f57806376b1d08f1461055357806379ba5097146106ed5780637f0e8030146107015780638082729914610720575f5ffd5b8063715018a6146106a557806372411bf314610501578063728c3dbe146106b957806375ae6a42146106d8575f5ffd5b80635782851b1161029a5780635782851b146105fb5780635e7f223b1461061a578063680ce1be146106505780636d9c89dc14610686575f5ffd5b8063434fed351461056757806353f96df2146105a8578063565c3ae1146105c7575f5ffd5b8063224fe64d1161033557806332fcd9661161030557806332fcd9661461050157806339c3722e1461051c5780633c125b4d146105385780633e8ff57b14610553575f5ffd5b8063224fe64d1461049e578063249d39e9146104bd57806330c276af146104d257806332ae829b146104e5575f5ffd5b806313e517d41161037057806313e517d41461042a578063159d41671461043f5780631740e5451461045e57806319540ee81461047d575f5ffd5b80628cc2621461039557806306fdde03146103d35780630c14d06f146103f4575b5f5ffd5b3480156103a0575f5ffd5b506103c06103af366004613f6d565b60186020525f908152604090205481565b6040519081526020015b60405180910390f35b3480156103de575f5ffd5b506103e7610b73565b6040516103ca9190613f86565b3480156103ff575f5ffd5b506103c061040e366004613fd9565b601660209081525f928352604080842090915290825290205481565b348015610435575f5ffd5b506103c06107d081565b34801561044a575f5ffd5b506103c0610459366004614003565b610bfe565b348015610469575f5ffd5b506103c0610478366004614023565b610c28565b348015610488575f5ffd5b5061049c610497366004614063565b610c6f565b005b3480156104a9575f5ffd5b506103c06104b8366004614023565b610c83565b3480156104c8575f5ffd5b506103c061271081565b61049c6104e036600461407e565b610cb6565b3480156104f0575f5ffd5b506103c06803782dace9d900000081565b34801561050c575f5ffd5b506103c0670de0b6b3a764000081565b348015610527575f5ffd5b506103c0683635c9adc5dea0000081565b348015610543575f5ffd5b50604051600181526020016103ca565b34801561055e575f5ffd5b506103c05f1981565b348015610572575f5ffd5b506103c0610581366004613f6d565b73ffffffffffffffffffffffffffffffffffffffff165f9081526018602052604090205490565b3480156105b3575f5ffd5b506103c06105c23660046140b1565b61108b565b3480156105d2575f5ffd5b506105e66105e136600461407e565b611095565b604080519283526020830191909152016103ca565b348015610606575f5ffd5b506103c06106153660046140c8565b611147565b348015610625575f5ffd5b506103c0610634366004614003565b601360209081525f928352604080842090915290825290205481565b34801561065b575f5ffd5b506103c061066a366004614003565b601260209081525f928352604080842090915290825290205481565b348015610691575f5ffd5b506103c06106a03660046140b1565b611181565b3480156106b0575f5ffd5b5061049c61118b565b3480156106c4575f5ffd5b5061049c6106d336600461412e565b61119e565b3480156106e3575f5ffd5b506103c060195481565b3480156106f8575f5ffd5b5061049c611408565b34801561070c575f5ffd5b506103c061071b366004614023565b611485565b34801561072b575f5ffd5b506103c061073a366004614023565b6114bd565b34801561074a575f5ffd5b5060015461076b9073ffffffffffffffffffffffffffffffffffffffff1681565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020016103ca565b34801561079b575f5ffd5b5061076b6114e0565b3480156107af575f5ffd5b506103c06107be366004614003565b611521565b3480156107ce575f5ffd5b506103c06107dd366004613fd9565b601560209081525f928352604080842090915290825290205481565b348015610804575f5ffd5b505f196103c0565b348015610817575f5ffd5b506103c0610826366004613fd9565b601460209081525f928352604080842090915290825290205481565b61049c61085036600461407e565b611539565b348015610860575f5ffd5b506103c061086f366004613fd9565b601760209081525f928352604080842090915290825290205481565b348015610896575f5ffd5b5061049c6108a53660046141b2565b61165e565b3480156108b5575f5ffd5b506103c06108c43660046140b1565b60116020525f908152604090205481565b3480156108e0575f5ffd5b506103c06108ef36600461422c565b6117ef565b3480156108ff575f5ffd5b506103c061090e3660046140b1565b61195c565b34801561091e575f5ffd5b506103c061092d366004613f6d565b611966565b34801561093d575f5ffd5b506103c061094c3660046140c8565b611a64565b34801561095c575f5ffd5b50610965611a6f565b6040516103ca91905f6101c082019050825182526020830151602083015260408301516040830152606083015160608301526080830151608083015260a083015160a083015260c083015160c083015260e083015160e08301526101008301516101008301526101208301516101208301526101408301516101408301526101608301516101608301526101808301516101808301526101a08301516101a083015292915050565b348015610a18575f5ffd5b5061049c610a273660046140b1565b611b57565b348015610a37575f5ffd5b506103c0610a4636600461407e565b611bbc565b348015610a56575f5ffd5b506103c0610a653660046140b1565b611c5e565b348015610a75575f5ffd5b50610aad610a843660046140b1565b60106020525f908152604090205460ff81169061ffff6101008204811691630100000090041683565b60408051931515845261ffff92831660208501529116908201526060016103ca565b348015610ada575f5ffd5b5061076b611c68565b348015610aee575f5ffd5b506103c0610afd36600461426b565b611c90565b348015610b0d575f5ffd5b506103c0610b1c3660046140b1565b611e28565b348015610b2c575f5ffd5b5061049c610b3b366004613f6d565b611e32565b348015610b4b575f5ffd5b5061049c610b5a3660046142ba565b611ee9565b348015610b6a575f5ffd5b506103c0604081565b5f8054610b7f906142ed565b80601f0160208091040260200160405190810160405280929190818152602001828054610bab906142ed565b8015610bf65780601f10610bcd57610100808354040283529160200191610bf6565b820191905f5260205f20905b815481529060010190602001808311610bd957829003601f168201915b505050505081565b5f610c0c82845f1980612088565b610c1f670de0b6b3a764000084846120d2565b90505b92915050565b5f610c3682845f1980612088565b610c4284845f196120f3565b8215610c5857610c53848385612136565b610c5a565b835b9050610c6881835f19612162565b9392505050565b610c776121a5565b610c80816121fd565b50565b5f610c9183835f1980612088565b610c9d84845f19612162565b610ca88484846126a9565b9050610c6881835f196120f3565b610cbe6126bc565b610cc661270d565b5f83815260116020526040812054349190610ce09061278e565b5f86815260156020908152604080832073ffffffffffffffffffffffffffffffffffffffff89168452909152902054909150610d1c86866127d5565b5f86815260146020908152604080832073ffffffffffffffffffffffffffffffffffffffff8916845290915281208054869290610d5a908490614365565b90915550505f86815260126020908152604080832084845290915281208054869290610d87908490614365565b90915550505f86815260146020908152604080832073ffffffffffffffffffffffffffffffffffffffff89168452909152812054600d54909190610dcf9086906127106128f7565b90505f610ddc8287614365565b5f8a8152601260209081526040808320888452909152812054919250908190610e06908690614365565b90508215610f6657610e178161291c565b15610e6257610e2f83670de0b6b3a764000083612930565b5f8c81526013602090815260408083208a845290915281208054909190610e57908490614378565b90915550610f669050565b805f03610f1c575f5f610e758d896129b7565b90925090508015610f0857610e9385670de0b6b3a764000083612930565b5f8e815260136020908152604080832086845290915281208054909190610ebb908490614378565b909155505060408051898152602081018490529081018690528d907f0d296a10d388c382eb16ea0fadf4fdfc75bf320dc45334fa6a40b62bcab10b779060600160405180910390a2610f15565b610f128585614378565b93505b5050610f66565b8260195f828254610f2d9190614378565b90915550506040518381527fbc1a3517590016c72b4696257bec20e894df2ebed6cb8876da197009563616329060200160405180910390a15b610f7c8b610f748487614378565b898989612a69565b5f8b8152601360209081526040808320898452909152902054610fa9908690670de0b6b3a7640000612930565b5f8c815260176020908152604080832073ffffffffffffffffffffffffffffffffffffffff8f1684528252808320939093558d82526011905290812080548b9290610ff5908490614365565b9091555050604080518a8152602081018a905290810187905273ffffffffffffffffffffffffffffffffffffffff8b16908c907f7ad3d882454aa9a6f13a920fa5002c6f67865aa7a5b85c949721087051fc33509060600160405180910390a3505050505050505061108660017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b505050565b5f610c228261278e565b5f83815260146020908152604080832073ffffffffffffffffffffffffffffffffffffffff86168452909152812054819081906110e8575f868152601160205260409020546110e39061278e565b611118565b5f86815260156020908152604080832073ffffffffffffffffffffffffffffffffffffffff891684529091529020545b905061113061112682612c59565b8590612710612cb8565b915061113c8285614365565b925050935093915050565b5f6111528383612ce5565b73ffffffffffffffffffffffffffffffffffffffff84165f90815260186020526040902054610c1f9190614378565b5f610c2282612dc9565b6111936121a5565b61119c5f612e67565b565b5f6111a7612eb7565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f811580156111d35750825b90505f8267ffffffffffffffff1660011480156111ef5750303b155b9050811580156111fd575080155b15611234576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156112955784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b73ffffffffffffffffffffffffffffffffffffffff881615806112cc575073ffffffffffffffffffffffffffffffffffffffff8716155b15611303576040517fe732132600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6113418a8a8080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250612edf92505050565b61134a88612f67565b611352612f78565b600180547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff891617905561139b866121fd565b83156113fc5784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50505050505050505050565b3380611412611c68565b73ffffffffffffffffffffffffffffffffffffffff161461147c576040517f118cdaa700000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff821660048201526024015b60405180910390fd5b610c8081612e67565b5f61149383835f1980612088565b61149d8484612f88565b81156114b3576114ae848385612136565b6114b5565b835b949350505050565b5f6114cb82845f1980612088565b6114d58484612fc2565b6114b58484846120d2565b5f807f9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c1993005b5473ffffffffffffffffffffffffffffffffffffffff1692915050565b5f82815260116020526040812054610c1f9083612ffc565b6115416126bc565b61154961270d565b5f8381526011602052604081205434916115628261278e565b9050835f0361157b576115768684836130d3565b6115a1565b6115888686848787613181565b6115928483614378565b5f878152601160205260409020555b5f86815260156020908152604080832073ffffffffffffffffffffffffffffffffffffffff8916808552908352818420548a8552601684528285208286528452938290205482518981529384018890529183018590526060830193909352608082015287907e9f244766dc7cd1ffbe13d1bcd0b417d25cac24f6bff7a882c5892f75cebba79060a00160405180910390a350505061108660017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b6116666121a5565b60035483106116a1576040517f7b0d211e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60075461ffff831611806116ba5750600c5461ffff8216115b156116f1576040517f7b0d211e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b604080516060810182526001815261ffff84811660208084018281528684168587018181525f8b81526010855288902096518754935191517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000009094169015157fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000ff161761010091871691909102177fffffffffffffffffffffffffffffffffffffffffffffffffffffff0000ffffff16630100000092909516919091029390931790935583519081529182015284917f04229b31ebbb9ff5197a6b46d1137139e0f58d83a5f3e3501e2e2bc03c21d6c4910160405180910390a2505050565b5f6117f861270d565b815f5b81811015611899575f60145f8787858181106118195761181961438b565b9050602002013581526020019081526020015f205f3373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020015f20541115611891576118918585838181106118845761188461438b565b90506020020135336127d5565b6001016117fb565b50335f9081526018602052604081205492508290036118e4576040517f4d05ab1100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b335f818152601860205260408120556118fd90836132c1565b60405182815233907fd8138f8a3f377c5259ca548e70e4c2de94f129f5a11036a15b69513cba2b426a9060200160405180910390a250610c2260017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f610c2282613373565b5f61196f6121a5565b61197761270d565b73ffffffffffffffffffffffffffffffffffffffff82166119c4576040517fe732132600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6019549050805f036119d757505f611a36565b5f6019556119e582826132c1565b8173ffffffffffffffffffffffffffffffffffffffff167f4a8e53ea1147241c18d4626eb8ce2d266f4c1b1ba8c508e60c2910b89e157d9482604051611a2d91815260200190565b60405180910390a25b611a5f60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b919050565b5f610c1f8383612ce5565b611ad3604051806101c001604052805f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81526020015f81525090565b50604080516101c08101825260025481526003546020820152600454918101919091526005546060820152600654608082015260075460a082015260085460c082015260095460e0820152600a54610100820152600b54610120820152600c54610140820152600d54610160820152600e54610180820152600f546101a082015290565b611b5f6121a5565b5f8181526010602052604080822080547fffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000001690555182917f26cadbc43237eb5ce83fbf2da5a4770c76dc2eb1a97cad454998a67af81e646791a250565b5f83815260146020908152604080832073ffffffffffffffffffffffffffffffffffffffff861684529091528120548190611c0d575f85815260116020526040902054611c089061278e565b611c3d565b5f85815260156020908152604080832073ffffffffffffffffffffffffffffffffffffffff881684529091529020545b9050611c55611c4b82612c59565b8490612710612cb8565b95945050505050565b5f610c22826133c1565b5f807f237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c00611504565b5f81818167ffffffffffffffff811115611cac57611cac6143b8565b604051908082528060200260200182016040528015611cd5578160200160208202803683370190505b5090505f5b82811015611d2257858582818110611cf457611cf461438b565b905060200201355f1c828281518110611d0f57611d0f61438b565b6020908102919091010152600101611cda565b50611d2c816133f3565b60015b82811015611db45781611d43600183614365565b81518110611d5357611d5361438b565b6020026020010151828281518110611d6d57611d6d61438b565b602002602001015103611dac576040517fb5f52e1700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600101611d2f565b5073ffffffffffffffffffffffffffffffffffffffff86165f9081526018602052604081205493505b82811015611e1e57611e0a87838381518110611dfb57611dfb61438b565b60200260200101515f1b612ce5565b611e149085614378565b9350600101611ddd565b5050509392505050565b5f610c2282612c59565b611e3a6121a5565b7f237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c0080547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff83169081178255611ea36114e0565b73ffffffffffffffffffffffffffffffffffffffff167f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e2270060405160405180910390a35050565b5f611ef2612eb7565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f81158015611f1e5750825b90505f8267ffffffffffffffff166001148015611f3a5750303b155b905081158015611f48575080155b15611f7f576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff00000000000000001660011785558315611fe05784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b61201e87878080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250612edf92505050565b831561207f5784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50505050505050565b8184118061209557508083115b156120cc576040517f9c1f834900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b50505050565b5f8280156120ea576120e5858483612930565b611c55565b50929392505050565b6120fd8282614365565b831115611086576040517f52c4014100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f612142848484612930565b90508183850915610c685760010180610c685763ae47f7025f526004601cfd5b61216c8282614365565b831115611086576040517f356cd28700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b336121ae6114e0565b73ffffffffffffffffffffffffffffffffffffffff161461119c576040517f118cdaa7000000000000000000000000000000000000000000000000000000008152336004820152602401611473565b8035158061221b57506fffffffffffffffffffffffffffffffff8135115b15612252576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60208101351580612267575060408160200135115b1561229e576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6122ab61271060646143e5565b816040013511156122e8576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600354158015906122fe57506003546020820135105b15612335576040517fe0608cd600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6127108160c001351115612375576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60e0810135158061239257506803782dace9d90000008160e00135115b156123c9576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8060a00135816060013511806123e457506107d08160a00135115b1561241b576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b806101400135816101000135118061243957506107d0816101400135115b15612470576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61271081610160013511156124b1576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61271081610180013511156124f2576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b683635c9adc5dea00000816101a00135111561253a576040517f4581e63d00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600f805482356002556020830135600381905560408401356004556060840135600555608084013560065560a084013560075560c084013560085560e0840135600955610100840135600a55610120840135600b55610140840135600c55610160840135600d55610180840135600e556101a0840135909255906125c9906125c490600190614365565b612dc9565b5f03612601576040517fc72fcf8100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b604080518335815260208085013590820152838201358183015260c0840135606082015260e0840135608082015290517f2ba978126f856e763cfc2e7694871d83c30f5c931c5e16443db1e38c63dafd219181900360a00190a180826101a00135146126a557604080518281526101a084013560208201527f24c3163d05eb550233212590acc8893ed456789a3735996dcc5f8a41b71acb90910160405180910390a15b5050565b5f8180156120ea576120e5858286612930565b60015473ffffffffffffffffffffffffffffffffffffffff16331461119c576040517f04c0e89300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b7f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0080547ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01612788576040517f3ee5aeb500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60029055565b5f815f0361279d57505f919050565b6003545f5b818110156127c9576127b381612dc9565b8410156127c1579392505050565b6001016127a2565b50610c68600182614365565b5f82815260156020908152604080832073ffffffffffffffffffffffffffffffffffffffff8516808552908352818420548685526013845282852081865284528285205487865260148552838620928652919093529083205491929161284391670de0b6b3a7640000612930565b5f85815260176020908152604080832073ffffffffffffffffffffffffffffffffffffffff88168452909152902054909150808211156128c1576128878183614365565b73ffffffffffffffffffffffffffffffffffffffff85165f90815260186020526040812080549091906128bb908490614378565b90915550505b505f93845260176020908152604080862073ffffffffffffffffffffffffffffffffffffffff9095168652939052919092205550565b828202831584820484141782026129155763ad251c275f526004601cfd5b0492915050565b5f5f82118015610c22575050600f54111590565b82820281838583041485151702612915575f198385098181108201900382848609835f03841682851161296a5763ae47f7025f526004601cfd5b93849004938382119092035f839003839004600101029203041760026003830281188084028203028084028203028084028203028084028203028084028203028084029091030202610c68565b6003545f908190816129ca856001614378565b90505b81811015612a11575f8681526012602090815260408083208484529091529020546129f78161291c565b15612a08579093509150612a629050565b506001016129cd565b50835b8015612a59575f8681526012602090815260408083205f1990940180845293909152902054612a428161291c565b15612a53579093509150612a629050565b50612a14565b505f5f92509250505b9250929050565b8315612c2c57825f819003612ac7578460195f828254612a899190614378565b90915550506040518581527fbc1a3517590016c72b4696257bec20e894df2ebed6cb8876da197009563616329060200160405180910390a150612c2c565b5f612afc670de0b6b3a764000061271084600260060154612710612aeb9190614365565b612af591906143e5565b91906128f7565b90505f8267ffffffffffffffff811115612b1857612b186143b8565b604051908082528060200260200182016040528015612b41578160200160208202803683370190505b5090505f8367ffffffffffffffff811115612b5e57612b5e6143b8565b604051908082528060200260200182016040528015612b87578160200160208202803683370190505b5090505f612b9a8a86868a8a8888613579565b9050805f03612bba57612bb08a8a878786613664565b5050505050612c2c565b5f612bc98b8b88858888613775565b612bd3908b614365565b90508015612c25578060195f828254612bec9190614378565b90915550506040518181527fbc1a3517590016c72b4696257bec20e894df2ebed6cb8876da197009563616329060200160405180910390a15b5050505050505b5050505050565b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f818152601060205260408120600c54815460ff1615612c8d5781546301000000900461ffff168181106114b55781611c55565b600b545f90612c9c90866143e5565b600a54612ca99190614378565b90508181106114b55781611c55565b82820283158482048414178202612cd65763ad251c275f526004601cfd5b81810615159190040192915050565b5f81815260146020908152604080832073ffffffffffffffffffffffffffffffffffffffff86168452909152812054808203612d24575f915050610c22565b5f8381526013602090815260408083206015835281842073ffffffffffffffffffffffffffffffffffffffff891685528352818420548452909152812054612d76908390670de0b6b3a7640000612930565b5f85815260176020908152604080832073ffffffffffffffffffffffffffffffffffffffff8a168452909152902054909150808211612db5575f612dbf565b612dbf8183614365565b9695505050505050565b6004545f90808203612ded57612de0836001614378565b600254610c6891906143e5565b5f612e0e670de0b6b3a7640000612710612e078582614378565b9190612930565b90505f612e2e82612e20876001614378565b670de0b6b3a764000061385f565b90505f612e4684670de0b6b3a7640000612710612930565b9050612dbf612e5d670de0b6b3a764000084614365565b6002549083612930565b7f237e158222e3e6968b72b9db0d8043aacf074ad9f650f0d1606b4d82ee432c0080547fffffffffffffffffffffffff00000000000000000000000000000000000000001681556126a5826138f6565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00610c22565b612ee761398b565b80515f03612f21576040517fe465a80300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f612f2c8282614440565b507fb7773e9891add319d8c6dd41c3664b1dba6a1dddd32fa2bf94afe68cf5bdd50f81604051612f5c9190613f86565b60405180910390a150565b612f6f61398b565b610c80816139c9565b612f8061398b565b61119c613a20565b808211156126a5576040517fd839673100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b808211156126a5576040517f36172e8f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f8183826130098261278e565b90505f600160026001015461301e9190614365565b90505b83156130c9575f61303183613373565b9050848284101561307d575f8561304786612dc9565b6130519190614365565b90505f61306c6127106130648682614365565b849190612cb8565b90508281101561307a578092505b50505b5f61308b8284612710612cb8565b90506130978189614378565b97506130a38288614365565b96506130af8183614365565b6130b99087614378565b9550846001019450505050613021565b5050505092915050565b815f036130df57505050565b600e545f906130f29084906127106128f7565b90505f6130ff8285614365565b90508115613174575f5f6131138786613a28565b909250905080156131645761313184670de0b6b3a764000083612930565b5f88815260136020908152604080832086845290915281208054909190613159908490614378565b909155506131719050565b61316e8484614378565b92505b50505b612c2c8582855f5f612a69565b5f61318b8461278e565b90505f60016002600101546131a09190614365565b9050808214806131c157506131b482612dc9565b6131be8587614378565b11155b156131da576131d38787848787613a7b565b5050612c2c565b5f5f5f6131e988888787613d14565b919450925090505f805b838110156132b3575f6132068289614378565b90505f85613215846001614378565b0361322b57613224848b614365565b9050613283565b84156132835761327461326c61324084613373565b6127108a87815181106132555761325561438b565b60200260200101516128f79092919063ffffffff16565b8b90876128f7565b90506132808185614378565b93505b6132a98e8e848a878151811061329b5761329b61438b565b602002602001015185613a7b565b50506001016131f3565b505050505050505050505050565b80471015613304576040517fcf47918100000000000000000000000000000000000000000000000000000000815247600482015260248101829052604401611473565b5f5f8373ffffffffffffffffffffffffffffffffffffffff16836040515f6040518083038185875af1925050503d805f811461335b576040519150601f19603f3d011682016040523d82523d5f602084013e613360565b606091505b5091509150816120cc576120cc81613e2e565b5f818152601060205260408120600754815460ff16156133a5578154610100900461ffff168181106114b55781611c55565b6006545f906133b490866143e5565b600554612ca99190614378565b5f815f036133d257610c225f612dc9565b6133e06125c4600184614365565b6133e983612dc9565b610c229190614365565b6134eb565b61018082840311613455576020820180518351106134195780518351825283525b5b6020018381116120cc578051828201805182811161343a5750505061341a565b5b60208201528301805182811161343b57506020015261341a565b81601f1683830160061c60051b018251815180821061347057905b85518082106134855790818310613485579091905b865282528352518390835b5b6020018051821161349157825b84018051831061349e579250828110156134bf578051835182528352613490565b50508360208201146134d9576134d98460208301846133f8565b8281146120cc576120cc8184846133f8565b8051600281106126a557601f19602083018260051b8401805b80518185015111613516578301613504565b82811161352557505050505050565b50805b8051818501511061353a578301613528565b828111613563575b82518251845282526020909201919083019081831061354257505050505050565b505f85526135728183856133f8565b5050509052565b6009545f9060015b888111613657575f613593828b614365565b5f8c81526012602090815260408083208484529091529020549091508882036135c3576135c08882614365565b90505b6135cc8161291c565b6135d357505f5b80866135e0600186614365565b815181106135f0576135f061438b565b6020908102919091010152801561364d575f61361561360f858d613e6f565b86613ea0565b90508088613624600187614365565b815181106136345761363461438b565b60209081029190910101526136498187614378565b9550505b5050600101613581565b5050979650505050505050565b5f805f1960015b8681116136d4575f8561367f600184614365565b8151811061368f5761368f61438b565b602002602001015190505f8111156136cb575f6136ac8389613e6f565b9050838110156136c9579250826136c3838a614365565b95508194505b505b5060010161366b565b508115613721576136ee87670de0b6b3a764000084612930565b5f89815260136020908152604080832087845290915281208054909190613716908490614378565b9091555061376b9050565b8660195f8282546137329190614378565b90915550506040518781527fbc1a3517590016c72b4696257bec20e894df2ebed6cb8876da197009563616329060200160405180910390a15b5050505050505050565b5f60015b858111613854575f8461378d600184614365565b8151811061379d5761379d61438b565b602002602001015190505f81111561384b575f6137bb8983896128f7565b9050801561384957613803670de0b6b3a7640000866137db600187614365565b815181106137eb576137eb61438b565b6020026020010151836129309092919063ffffffff16565b5f8b81526013602052604081209061381b868c614365565b81526020019081526020015f205f8282546138369190614378565b9091555061384690508185614378565b93505b505b50600101613779565b509695505050505050565b811581028315610c68576001831684831802821890508160011c8360011c93505b83156138ee578485028181018660801c82821017156138a6576349f7642b5f526004601cfd5b84900495505060018416156138e357848202818101818110848884041817156138dc5786156138dc576349f7642b5f526004601cfd5b8490049250505b8360011c9350613880565b509392505050565b7f9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c19930080547fffffffffffffffffffffffff0000000000000000000000000000000000000000811673ffffffffffffffffffffffffffffffffffffffff848116918217845560405192169182907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a3505050565b613993613ede565b61119c576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6139d161398b565b73ffffffffffffffffffffffffffffffffffffffff811661147c576040517f1e4fbdf70000000000000000000000000000000000000000000000000000000081525f6004820152602401611473565b612c3361398b565b5f80825b8015613a6f575f8581526012602090815260408083205f1990940180845293909152902054613a5a8161291c565b15613a69579092509050612a62565b50613a2c565b505f9485945092505050565b613a868582856130d3565b5f85815260146020908152604080832073ffffffffffffffffffffffffffffffffffffffff881680855290835281842054898552601584528285209185529252909120548115613ada57613ada87876127d5565b5f613ae58584614378565b90505f835f03613b0857613b01670de0b6b3a7640000886143e5565b9050613b66565b613b1f8683612e07670de0b6b3a76400008b6143e5565b5f8a815260166020908152604080832073ffffffffffffffffffffffffffffffffffffffff8d168452909152902054613b59908685612930565b613b639190614378565b90505b5f613b7082613efc565b9050838114613be0578415613bad575f8a815260126020908152604080832087845290915281208054879290613ba7908490614365565b90915550505b5f8a815260126020908152604080832084845290915281208054859290613bd5908490614378565b90915550613c0e9050565b5f8a815260126020908152604080832084845290915281208054899290613c08908490614378565b90915550505b5f8a815260146020908152604080832073ffffffffffffffffffffffffffffffffffffffff8d168085529083528184208790558d84526016835281842081855283528184208690558d84526015835281842090845282528083208490558c835260138252808320848452909152902054613c92908490670de0b6b3a7640000612930565b5f8b815260176020908152604080832073ffffffffffffffffffffffffffffffffffffffff8e16808552908352928190209390935582518b81529081018a9052918201889052908b907fd5313eb21d362e6ff7ead1db591cb80b4b593f058fe8eaca3c4b0105ee4d0fce9060600160405180910390a350505050505050505050565b60605f5f838511613d3957613d298585614365565b613d34906001614378565b613d3c565b60015b67ffffffffffffffff811115613d5457613d546143b8565b604051908082528060200260200182016040528015613d7d578160200160208202803683370190505b50925085875b8115613e22578186881015613db7575f82613d9d8a612dc9565b613da79190614365565b905081811015613db5578091505b505b80868681518110613dca57613dca61438b565b602002602001018181525050613dec613de289613373565b82906127106128f7565b613df69085614378565b9350613e028184614365565b9250613e0e8183614378565b915087600101975084600101945050613d83565b50509450945094915050565b805115613e3d57805160208201fd5b6040517fd6bda27500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f80613e83670de0b6b3a7640000856143e5565b9050828111613e96576114ae8184614365565b6114b58382614365565b5f80613eb584670de0b6b3a7640000856128f7565b9050670de0b6b3a76400008110613ecc575f6114b5565b6114b581670de0b6b3a7640000614365565b5f613ee7612eb7565b5468010000000000000000900460ff16919050565b5f80670de0b6b3a7640000613f12600282614519565b613f1c9085614378565b613f269190614519565b90505f6001600260010154613f3b9190614365565b9050808211610c6857816114b5565b803573ffffffffffffffffffffffffffffffffffffffff81168114611a5f575f5ffd5b5f60208284031215613f7d575f5ffd5b610c1f82613f4a565b602081525f82518060208401528060208501604085015e5f6040828501015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011684010191505092915050565b5f5f60408385031215613fea575f5ffd5b82359150613ffa60208401613f4a565b90509250929050565b5f5f60408385031215614014575f5ffd5b50508035926020909101359150565b5f5f5f60608486031215614035575f5ffd5b505081359360208301359350604090920135919050565b5f6101c0828403121561405d575f5ffd5b50919050565b5f6101c08284031215614074575f5ffd5b610c1f838361404c565b5f5f5f60608486031215614090575f5ffd5b833592506140a060208501613f4a565b929592945050506040919091013590565b5f602082840312156140c1575f5ffd5b5035919050565b5f5f604083850312156140d9575f5ffd5b6140e283613f4a565b946020939093013593505050565b5f5f83601f840112614100575f5ffd5b50813567ffffffffffffffff811115614117575f5ffd5b602083019150836020828501011115612a62575f5ffd5b5f5f5f5f5f6102208688031215614143575f5ffd5b853567ffffffffffffffff811115614159575f5ffd5b614165888289016140f0565b9096509450614178905060208701613f4a565b925061418660408701613f4a565b9150614195876060880161404c565b90509295509295909350565b803561ffff81168114611a5f575f5ffd5b5f5f5f606084860312156141c4575f5ffd5b833592506141d4602085016141a1565b91506141e2604085016141a1565b90509250925092565b5f5f83601f8401126141fb575f5ffd5b50813567ffffffffffffffff811115614212575f5ffd5b6020830191508360208260051b8501011115612a62575f5ffd5b5f5f6020838503121561423d575f5ffd5b823567ffffffffffffffff811115614253575f5ffd5b61425f858286016141eb565b90969095509350505050565b5f5f5f6040848603121561427d575f5ffd5b61428684613f4a565b9250602084013567ffffffffffffffff8111156142a1575f5ffd5b6142ad868287016141eb565b9497909650939450505050565b5f5f602083850312156142cb575f5ffd5b823567ffffffffffffffff8111156142e1575f5ffd5b61425f858286016140f0565b600181811c9082168061430157607f821691505b60208210810361405d577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b81810381811115610c2257610c22614338565b80820180821115610c2257610c22614338565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b8082028115828204841417610c2257610c22614338565b601f82111561108657805f5260205f20601f840160051c810160208510156144215750805b601f840160051c820191505b81811015612c2c575f815560010161442d565b815167ffffffffffffffff81111561445a5761445a6143b8565b61446e8161446884546142ed565b846143fc565b6020601f8211600181146144a0575f83156144895750848201515b5f19600385901b1c1916600184901b178455612c2c565b5f848152602081207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08516915b828110156144ed57878501518255602094850194600190920191016144cd565b508482101561450a57868401515f19600387901b60f8161c191681555b50505050600190811b01905550565b5f8261454c577f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b50049056fea164736f6c634300081d000a";

// bytecodes/AtomWallet.ts
var AtomWalletBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b613698806100d65f395ff3fe6080604052600436106101ba575f3560e01c80636133f985116100eb578063a2e1a8d811610089578063c399ec8811610063578063c399ec881461053a578063d087d2881461054e578063d948fd2e14610562578063f2fde38b14610576576101c1565b8063a2e1a8d8146104d2578063b0d691fe146104f1578063b61d27f61461051b576101c1565b80638c3ecc45116100c55780638c3ecc451461042d5780638da5cb5b1461047d5780638ea69029146104915780639bfe79ae146104bd576101c1565b80636133f985146103db578063715018a6146103fa57806389625b571461040e576101c1565b806334fcd5be116101585780634a58db19116101325780634a58db191461036f5780634d44560d1461037757806354cfe02d1461039657806357c9ca14146103aa576101c1565b806334fcd5be1461031e57806347e1da2a1461033d578063481379cc14610350576101c1565b80630f0f3f24116101945780630f0f3f241461026f5780631626ba7e1461029057806319822f7c146102e057806329565e3b146102ff576101c1565b806301ffc9a7146101fa578063066a1eb71461022e5780630db026221461024d576101c1565b366101c157005b5f3560e01c63bc197c81811463f23a6e6182141763150b7a02821417156101ec57806020526020603cf35b50633c10b94e5f526004601cfd5b348015610205575f5ffd5b50610219610214366004612e19565b610597565b60405190151581526020015b60405180910390f35b348015610239575f5ffd5b50610219610248366004612e58565b6106c7565b348015610258575f5ffd5b506102616106d9565b604051908152602001610225565b34801561027a575f5ffd5b5061028e610289366004612e99565b6106e7565b005b34801561029b575f5ffd5b506102af6102aa366004612ef9565b6106fb565b6040517fffffffff000000000000000000000000000000000000000000000000000000009091168152602001610225565b3480156102eb575f5ffd5b506102616102fa366004612f41565b61080b565b34801561030a575f5ffd5b5061028e610319366004612e58565b610829565b348015610329575f5ffd5b5061028e610338366004612fd1565b61083f565b61028e61034b366004613010565b610975565b34801561035b575f5ffd5b5061028e61036a366004612e99565b610ab1565b61028e610d3f565b348015610382575f5ffd5b5061028e6103913660046130af565b610dd9565b3480156103a1575f5ffd5b5061028e610e7b565b3480156103b5575f5ffd5b506001546102199074010000000000000000000000000000000000000000900460ff1681565b3480156103e6575f5ffd5b5061028e6103f53660046130d9565b610f3b565b348015610405575f5ffd5b5061028e611198565b348015610419575f5ffd5b5061028e610428366004612ef9565b6111ca565b348015610438575f5ffd5b505f546104589073ffffffffffffffffffffffffffffffffffffffff1681565b60405173ffffffffffffffffffffffffffffffffffffffff9091168152602001610225565b348015610488575f5ffd5b50610458611276565b34801561049c575f5ffd5b506104b06104ab366004613117565b611344565b604051610225919061315c565b3480156104c8575f5ffd5b5061026160025481565b3480156104dd575f5ffd5b506102196104ec366004612e99565b61134f565b3480156104fc575f5ffd5b5060015473ffffffffffffffffffffffffffffffffffffffff16610458565b348015610526575f5ffd5b5061028e61053536600461316e565b611359565b348015610545575f5ffd5b506102616113d2565b348015610559575f5ffd5b50610261611481565b34801561056d575f5ffd5b506102616114fb565b348015610581575f5ffd5b5061028e610590366004612e99565b611524565b565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f01ffc9a700000000000000000000000000000000000000000000000000000000148061062957507fffffffff0000000000000000000000000000000000000000000000000000000082167f1626ba7e00000000000000000000000000000000000000000000000000000000145b8061067557507fffffffff0000000000000000000000000000000000000000000000000000000082167f150b7a0200000000000000000000000000000000000000000000000000000000145b806106c157507fffffffff0000000000000000000000000000000000000000000000000000000082167f4e2312e000000000000000000000000000000000000000000000000000000000145b92915050565b5f6106d2838361163a565b9392505050565b5f6106e26116a7565b905090565b6106ef6116fd565b6106f88161174a565b50565b5f5f610772856040518060400160405280600a81526020017f41746f6d57616c6c6574000000000000000000000000000000000000000000008152506040518060400160405280600181526020017f3100000000000000000000000000000000000000000000000000000000000000815250611784565b90506107b38185858080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061189592505050565b156107e157507f1626ba7e0000000000000000000000000000000000000000000000000000000090506106d2565b507fffffffff00000000000000000000000000000000000000000000000000000000949350505050565b5f610814611ad2565b61081e8484611b53565b90506106d282611c07565b6108316116fd565b61083b8282611c4c565b5050565b610847611c69565b61084f611cea565b805f5b8181101561094a573684848381811061086d5761086d6131c6565b905060200281019061087f91906131f3565b90505f6108dd6108926020840184612e99565b60208401356108a4604086018661322f565b8080601f0160208091040260200160405190810160405280939291908181526020018383808284375f920191909152505050505a611cf2565b90508061094057836001036108f9576108f4611d08565b610940565b826109035f611d19565b6040517f5a154675000000000000000000000000000000000000000000000000000000008152600401610937929190613290565b60405180910390fd5b5050600101610852565b505061083b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b61097d611d70565b610985611c69565b8483811415806109955750838214155b156109cc576040517f3dd4113e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b81811015610a7e57610a768888838181106109eb576109eb6131c6565b9050602002016020810190610a009190612e99565b878784818110610a1257610a126131c6565b90506020020135868685818110610a2b57610a2b6131c6565b9050602002810190610a3d919061322f565b8080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250611de192505050565b6001016109ce565b5050610aa960017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b505050505050565b610ab9611e5a565b73ffffffffffffffffffffffffffffffffffffffff8116610b06576040517f6dc5ed5500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166384e100db6040518163ffffffff1660e01b8152600401602060405180830381865afa158015610b6f573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610b9391906132a8565b73ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff1603610bf7576040517f6dc5ed5500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60015474010000000000000000000000000000000000000000900460ff1615610c4c576040517fc7d9f29300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f610c55611276565b600180547fffffffffffffffffffffff00ffffffffffffffffffffffffffffffffffffffff16740100000000000000000000000000000000000000001790556003805473ffffffffffffffffffffffffffffffffffffffff85167fffffffffffffffffffffffff00000000000000000000000000000000000000009091161790559050610ce18261174a565b8173ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff167f5a4dc5590905991b4122d57f7ed23ae20db5533defce148e1cb34e46776c203b60405160405180910390a35050565b60015473ffffffffffffffffffffffffffffffffffffffff166040517fb760faf900000000000000000000000000000000000000000000000000000000815230600482015273ffffffffffffffffffffffffffffffffffffffff919091169063b760faf99034906024015f604051808303818588803b158015610dc0575f5ffd5b505af1158015610dd2573d5f5f3e3d5ffd5b5050505050565b610de1611d70565b60015473ffffffffffffffffffffffffffffffffffffffff166040517f205c287800000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff848116600483015260248201849052919091169063205c2878906044015f604051808303815f87803b158015610e69575f5ffd5b505af1158015610aa9573d5f5f3e3d5ffd5b610e83611d70565b610e8b611c69565b5f546002546040517fa3a9f88500000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff9092169163a3a9f88591610ee59160040190815260200190565b5f604051808303815f87803b158015610efc575f5ffd5b505af1158015610f0e573d5f5f3e3d5ffd5b5050505061059560017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f610f44611f4b565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f81158015610f705750825b90505f8267ffffffffffffffff166001148015610f8c5750303b155b905081158015610f9a575080155b15610fd1576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156110325784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b73ffffffffffffffffffffffffffffffffffffffff881661107f576040517f60bf8fdf00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b73ffffffffffffffffffffffffffffffffffffffff87166110cc576040517f60bf8fdf00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6110d4611f73565b6001805473ffffffffffffffffffffffffffffffffffffffff808b167fffffffffffffffffffffffff0000000000000000000000000000000000000000928316179092555f8054928a16929091169190911790556002869055831561118e5784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b5050505050505050565b6040517f7674884100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6111d26116fd565b5f6111db611276565b6040805173ffffffffffffffffffffffffffffffffffffffff9092166020830152016040516020818303038152906040529050808051906020012083836040516112269291906132c3565b604051809103902003611265576040517f4be1fa4600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611270848484611f83565b50505050565b6001545f9074010000000000000000000000000000000000000000900460ff16611327575f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166384e100db6040518163ffffffff1660e01b8152600401602060405180830381865afa158015611303573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906106e291906132a8565b5060035473ffffffffffffffffffffffffffffffffffffffff1690565b60606106c182611fd4565b5f6106c182612092565b611361611d70565b611369611c69565b6113a9848484848080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250611de192505050565b61127060017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b5f6113f260015473ffffffffffffffffffffffffffffffffffffffff1690565b6040517f70a0823100000000000000000000000000000000000000000000000000000000815230600482015273ffffffffffffffffffffffffffffffffffffffff91909116906370a08231906024015b602060405180830381865afa15801561145d573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906106e291906132d2565b5f6114a160015473ffffffffffffffffffffffffffffffffffffffff1690565b6040517f35567e1a0000000000000000000000000000000000000000000000000000000081523060048201525f602482015273ffffffffffffffffffffffffffffffffffffffff91909116906335567e1a90604401611442565b5f6106e27f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f005490565b61152c6116fd565b73ffffffffffffffffffffffffffffffffffffffff8116611579576040517fa70269ad00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6003805473ffffffffffffffffffffffffffffffffffffffff8381167fffffffffffffffffffffffff0000000000000000000000000000000000000000831617909255166115c68161210f565b6115cf82612092565b6115dc576115dc8261174a565b8173ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff167f7489915888c00526cd0b8e6b0076d4c9d3042cb1d79053bb447014b6364fecb460405160405180910390a35050565b60408051602081018490529081018290525f907f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f039060600160408051601f198184030181529082905261168c916132e9565b9081526040519081900360200190205460ff16905092915050565b7f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f01547f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f0080545f926116f79161332c565b91505090565b333014801590611713575061171133612092565b155b15610595576040517fbe9bd06600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6040805173ffffffffffffffffffffffffffffffffffffffff831660208201526106f891015b60405160208183030381529060405261228e565b8151602080840191909120825182840120604080517f8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f818601528082019390935260608301919091524660808301523060a0808401919091528151808403909101815260c0830182528051908401207f9b493d222105fee7df163ab5d57f0bf1ffd2da04dd5fafbe10b54c41c1adc65760e084015261010080840188905282518085039091018152610120840183528051908501207f19010000000000000000000000000000000000000000000000000000000000006101408501526101428401919091526101628084019190915281518084039091018152610182909201905280519101205f905b949350505050565b5f6060825110156118a757505f6106c1565b6040828101519081146118bd575f9150506106c1565b606083015183518111156118d5575f925050506106c1565b5f601f196118e483601f61333f565b1690506118f281606061333f565b855114611904575f93505050506106c1565b5f5f8680602001905181019061191a919061337f565b915091505f6119467f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f0090565b5f8481526002820160205260408120805492935090916119659061343e565b80601f01602080910402602001604051908101604052809291908181526020018280546119919061343e565b80156119dc5780601f106119b3576101008083540402835291602001916119dc565b820191905f5260205f20905b8154815290600101906020018083116119bf57829003601f168201915b5050505050905080515f036119fa575f9750505050505050506106c1565b8051602003611a555773ffffffffffffffffffffffffffffffffffffffff611a2182613489565b1115611a36575f9750505050505050506106c1565b6020810151611a46818c866122c9565b985050505050505050506106c1565b8051604003611ac3575f5f82806020019051810190611a7491906134ac565b915091505f611a82866123cc565b9050611ab28d604051602001611a9a91815260200190565b6040516020818303038152906040525f8386866124b4565b9a50505050505050505050506106c1565b505f9998505050505050505050565b60015473ffffffffffffffffffffffffffffffffffffffff163314610595576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601c60248201527f6163636f756e743a206e6f742066726f6d20456e747279506f696e74000000006044820152606401610937565b6040517f19457468657265756d205369676e6564204d6573736167653a0a3332000000006020820152603c81018290525f908190605c0160408051601f19818403018152919052805160209091012090505f611bf082611bb761010088018861322f565b8080601f0160208091040260200160405190810160405280939291908181526020018383808284375f9201919091525061189592505050565b9050611bfe81155f5f6125eb565b95945050505050565b80156106f8576040515f90339083908381818185875af1925050503d805f8114610dd2576040519150601f19603f3d011682016040523d82523d5f602084013e610dd2565b604080516020810184905290810182905261083b90606001611770565b7f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0080547ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01611ce4576040517f3ee5aeb500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60029055565b610595611d70565b5f5f5f845160208601878987f195945050505050565b610595611d145f611d19565b61261e565b60603d8215611d2d5782811115611d2d5750815b604051602082018101604052818152815f602083013e9392505050565b60017f9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f0055565b60015473ffffffffffffffffffffffffffffffffffffffff163314801590611d985750333014155b8015611daa5750611da833612092565b155b15610595576040517fc8f823bf00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5f8473ffffffffffffffffffffffffffffffffffffffff168484604051611e0991906132e9565b5f6040518083038185875af1925050503d805f8114611e43576040519150601f19603f3d011682016040523d82523d5f602084013e611e48565b606091505b509150915081610dd257805160208201fd5b5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166384e100db6040518163ffffffff1660e01b8152600401602060405180830381865afa158015611ec3573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190611ee791906132a8565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610595576040517fee4a08b600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a006106c1565b611f7b612626565b610595612664565b611f8b6116a7565b600103611fc4576040517f948bf89700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611fcf83838361266c565b505050565b5f8181527f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f026020526040902080546060919061200f9061343e565b80601f016020809104026020016040519081016040528092919081815260200182805461203b9061343e565b80156120865780601f1061205d57610100808354040283529160200191612086565b820191905f5260205f20905b81548152906001019060200180831161206957829003601f168201915b50505050509050919050565b5f7f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f006040805173ffffffffffffffffffffffffffffffffffffffff85166020820152600392909201910160408051601f19818403018152908290526120f6916132e9565b9081526040519081900360200190205460ff1692915050565b5f7f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f006040805173ffffffffffffffffffffffffffffffffffffffff851660208201529192505f910160408051601f1981840301815291905282549091505f5b81811015612243575f818152600285016020526040812080546121909061343e565b80601f01602080910402602001604051908101604052809291908181526020018280546121bc9061343e565b80156122075780601f106121de57610100808354040283529160200191612207565b820191905f5260205f20905b8154815290600101906020018083116121ea57829003601f168201915b505050505090505f815111801561222b575083805190602001208180519060200120145b1561223a57610aa98285612899565b5060010161216e565b506040517f49c59bd100000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff85166004820152602401610937565b6106f8817f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f008054905f6122c0836134ce565b91905055612aaf565b5f73ffffffffffffffffffffffffffffffffffffffff8416156106d257604051843b61238457825160408114612307576041811461234157506123c4565b604084015160ff81901c601b016020527f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff16606052612354565b60608401515f1a60205260408401516060525b50835f5260208301516040526020600160805f60015afa5180861860601b3d119250505f606052806040526123c4565b631626ba7e60e01b808252846004830152602482016040815284516020018060448501828860045afa905060208260443d01868b5afa9151911691141691505b509392505050565b6124016040518060c0016040528060608152602001606081526020015f81526020015f81526020015f81526020015f81525090565b815160c081106124ae5760208301818101818251018281108260c0830111171561242d575050506124ae565b808151019250806020820151018181108382111782851084861117171561245757505050506124ae565b828151602083010111838551602087010111171561247857505050506124ae565b8386528060208701525060408101516040860152606081015160608601526080810151608086015260a081015160a08601525050505b50919050565b5f5f5f6124c388600180612bd9565b905060208601518051602082019150604088015160608901518451600d81017f226368616c6c656e6765223a220000000000000000000000000000000000000060981c8752848482011060228286890101515f1a14168160138901208286890120141685846014011085851760801c107f2274797065223a22776562617574686e2e67657422000000000000000000000060581c8589015160581c14161698505080865250505087515189151560021b600117808160218c51015116146020831188161696505085156125bf57602089510181810180516020600160208601856020868a8c60025afa60011b5afa51915295503d90506125bf57fe5b50505082156125e0576125dd8287608001518860a001518888612ce5565b92505b505095945050505050565b5f60d08265ffffffffffff16901b60a08465ffffffffffff16901b85612611575f612614565b60015b1717949350505050565b805160208201fd5b61262e612d7e565b610595576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611d4a612626565b5f8381527f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f026020526040812080547f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f009291906126c79061343e565b80601f01602080910402602001604051908101604052809291908181526020018280546126f39061343e565b801561273e5780601f106127155761010080835404028352916020019161273e565b820191905f5260205f20905b81548152906001019060200180831161272157829003601f168201915b5050505050905080515f03612782576040517f68188e7a00000000000000000000000000000000000000000000000000000000815260048101869052602401610937565b83836040516127929291906132c3565b60405180910390208180519060200120146127e157848484836040517f781f2e39000000000000000000000000000000000000000000000000000000008152600401610937949392919061350f565b8160030184846040516127f59291906132c3565b908152604080516020928190038301902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001690555f87815260028501909252812061284291612dcf565b600182018054905f612853836134ce565b9190505550847fcf95bbfe6f870f8cc40482dc3dccdafd268f0e9ce0a4f24ea1bea9be64e505ff858560405161288a929190613545565b60405180910390a25050505050565b5f8281527f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f026020526040812080547f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f009291906128f49061343e565b80601f01602080910402602001604051908101604052809291908181526020018280546129209061343e565b801561296b5780601f106129425761010080835404028352916020019161296b565b820191905f5260205f20905b81548152906001019060200180831161294e57829003601f168201915b5050505050905080515f036129af576040517f68188e7a00000000000000000000000000000000000000000000000000000000815260048101859052602401610937565b82805190602001208180519060200120146129fc578383826040517f781f2e3900000000000000000000000000000000000000000000000000000000815260040161093793929190613558565b8160030183604051612a0e91906132e9565b908152604080516020928190038301902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001690555f868152600285019092528120612a5b91612dcf565b600182018054905f612a6c836134ce565b9190505550837fcf95bbfe6f870f8cc40482dc3dccdafd268f0e9ce0a4f24ea1bea9be64e505ff84604051612aa1919061315c565b60405180910390a250505050565b612ab882612d9c565b15612af157816040517f8d16255a000000000000000000000000000000000000000000000000000000008152600401610937919061315c565b6040517f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f00906001907f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f0390612b469086906132e9565b908152604080516020928190038301902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016931515939093179092555f8481526002840190915220612b9b84826135d0565b50817f38109edc26e166b5579352ce56a50813177eb25208fd90d61f2f37838622022084604051612bcc919061315c565b60405180910390a2505050565b6060835180156123c4576003600282010460021b60405192507f4142434445464748494a4b4c4d4e4f505152535455565758595a616263646566601f526106708515027f6768696a6b6c6d6e6f707172737475767778797a303132333435363738392d5f18603f526020830181810183886020010180515f82525b60038a0199508951603f8160121c16515f53603f81600c1c1651600153603f8160061c1651600253603f811651600353505f518452600484019350828410612c545790526020016040527f3d3d00000000000000000000000000000000000000000000000000000000000060038406600204808303919091525f861515909102918290035290038252509392505050565b5f6040518681528560208201528460408201528360608201528260808201525f5f5260205f60a0836101005afa503d612d49576d1ab2e8006fd8b71907bf06a5bdee3b612d495760205f60a0836dd01ea45f9efd5c54f037fa57ea1a5afa612d4957fe5b505f516001147f7fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a8851110905095945050505050565b5f612d87611f4b565b5468010000000000000000900460ff16919050565b5f7f97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f00600301826040516120f691906132e9565b508054612ddb9061343e565b5f825580601f10612dea575050565b601f0160209004905f5260205f20908101906106f891905b80821115612e15575f8155600101612e02565b5090565b5f60208284031215612e29575f5ffd5b81357fffffffff00000000000000000000000000000000000000000000000000000000811681146106d2575f5ffd5b5f5f60408385031215612e69575f5ffd5b50508035926020909101359150565b73ffffffffffffffffffffffffffffffffffffffff811681146106f8575f5ffd5b5f60208284031215612ea9575f5ffd5b81356106d281612e78565b5f5f83601f840112612ec4575f5ffd5b50813567ffffffffffffffff811115612edb575f5ffd5b602083019150836020828501011115612ef2575f5ffd5b9250929050565b5f5f5f60408486031215612f0b575f5ffd5b83359250602084013567ffffffffffffffff811115612f28575f5ffd5b612f3486828701612eb4565b9497909650939450505050565b5f5f5f60608486031215612f53575f5ffd5b833567ffffffffffffffff811115612f69575f5ffd5b84016101208187031215612f7b575f5ffd5b95602085013595506040909401359392505050565b5f5f83601f840112612fa0575f5ffd5b50813567ffffffffffffffff811115612fb7575f5ffd5b6020830191508360208260051b8501011115612ef2575f5ffd5b5f5f60208385031215612fe2575f5ffd5b823567ffffffffffffffff811115612ff8575f5ffd5b61300485828601612f90565b90969095509350505050565b5f5f5f5f5f5f60608789031215613025575f5ffd5b863567ffffffffffffffff81111561303b575f5ffd5b61304789828a01612f90565b909750955050602087013567ffffffffffffffff811115613066575f5ffd5b61307289828a01612f90565b909550935050604087013567ffffffffffffffff811115613091575f5ffd5b61309d89828a01612f90565b979a9699509497509295939492505050565b5f5f604083850312156130c0575f5ffd5b82356130cb81612e78565b946020939093013593505050565b5f5f5f606084860312156130eb575f5ffd5b83356130f681612e78565b9250602084013561310681612e78565b929592945050506040919091013590565b5f60208284031215613127575f5ffd5b5035919050565b5f81518084528060208401602086015e5f602082860101526020601f19601f83011685010191505092915050565b602081525f6106d2602083018461312e565b5f5f5f5f60608587031215613181575f5ffd5b843561318c81612e78565b935060208501359250604085013567ffffffffffffffff8111156131ae575f5ffd5b6131ba87828801612eb4565b95989497509550505050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b5f82357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa1833603018112613225575f5ffd5b9190910192915050565b5f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1843603018112613262575f5ffd5b83018035915067ffffffffffffffff82111561327c575f5ffd5b602001915036819003821315612ef2575f5ffd5b828152604060208201525f61188d604083018461312e565b5f602082840312156132b8575f5ffd5b81516106d281612e78565b818382375f9101908152919050565b5f602082840312156132e2575f5ffd5b5051919050565b5f82518060208501845e5f920191825250919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b818103818111156106c1576106c16132ff565b808201808211156106c1576106c16132ff565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b5f5f60408385031215613390575f5ffd5b8251602084015190925067ffffffffffffffff8111156133ae575f5ffd5b8301601f810185136133be575f5ffd5b805167ffffffffffffffff8111156133d8576133d8613352565b604051601f19603f601f19601f8501160116810181811067ffffffffffffffff8211171561340857613408613352565b60405281815282820160200187101561341f575f5ffd5b8160208401602083015e5f602083830101528093505050509250929050565b600181811c9082168061345257607f821691505b6020821081036124ae577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b805160208083015191908110156124ae575f1960209190910360031b1b16919050565b5f5f604083850312156134bd575f5ffd5b505080516020909101519092909150565b5f5f1982036134df576134df6132ff565b5060010190565b81835281816020850137505f602082840101525f6020601f19601f840116840101905092915050565b848152606060208201525f6135286060830185876134e6565b828103604084015261353a818561312e565b979650505050505050565b602081525f61188d6020830184866134e6565b838152606060208201525f613570606083018561312e565b8281036040840152613582818561312e565b9695505050505050565b601f821115611fcf57805f5260205f20601f840160051c810160208510156135b15750805b601f840160051c820191505b81811015610dd2575f81556001016135bd565b815167ffffffffffffffff8111156135ea576135ea613352565b6135fe816135f8845461343e565b8461358c565b6020601f821160018114613630575f83156136195750848201515b5f19600385901b1c1916600184901b178455610dd2565b5f84815260208120601f198516915b8281101561365f578785015182556020948501946001909201910161363f565b508482101561367c57868401515f19600387901b60f8161c191681555b50505050600190811b0190555056fea164736f6c634300081d000a";

// bytecodes/AtomWalletFactory.ts
var AtomWalletFactoryBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b610eb9806100d65f395ff3fe608060405234801561000f575f5ffd5b506004361061004a575f3560e01c8063218e250d1461004e57806336391a371461008a5780638c3ecc451461009d578063c4d66de8146100bc575b5f5ffd5b61006161005c3660046107be565b6100d1565b60405173ffffffffffffffffffffffffffffffffffffffff909116815260200160405180910390f35b6100616100983660046107be565b61017f565b5f546100619073ffffffffffffffffffffffffffffffffffffffff1681565b6100cf6100ca3660046107f9565b6103f8565b005b5f5f6100dc836105f9565b8051602091820120604080517fff00000000000000000000000000000000000000000000000000000000000000818501523060601b7fffffffffffffffffffffffffffffffffffffffff0000000000000000000000001660218201526035810196909652605580870192909252805180870390920182526075909501909452835193019290922073ffffffffffffffffffffffffffffffffffffffff1692915050565b5f80546040517ff57190080000000000000000000000000000000000000000000000000000000081526004810184905273ffffffffffffffffffffffffffffffffffffffff9091169063f571900890602401602060405180830381865afa1580156101ec573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610210919061081b565b610246576040517fa167f9ff00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f546040517f1fdc812e0000000000000000000000000000000000000000000000000000000081526004810184905273ffffffffffffffffffffffffffffffffffffffff90911690631fdc812e90602401602060405180830381865afa1580156102b2573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906102d6919061081b565b1561030d576040517fe44dea9e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f610317836105f9565b90505f610323846100d1565b905073ffffffffffffffffffffffffffffffffffffffff81163b801561034b57509392505050565b5f858451602086015ff5905073ffffffffffffffffffffffffffffffffffffffff81166103a4576040517fcbace66600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60405173ffffffffffffffffffffffffffffffffffffffff8216815286907f28e919d2d53ab1466f9059b052ec59fb6279aadb2459ccd3f4949ab6c7db5c769060200160405180910390a295945050505050565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000810460ff16159067ffffffffffffffff165f811580156104425750825b90505f8267ffffffffffffffff16600114801561045e5750303b155b90508115801561046c575080155b156104a3576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156105045784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b73ffffffffffffffffffffffffffffffffffffffff8616610551576040517f3dfa6a7100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f80547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff881617905583156105f15784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b505050505050565b60605f5f5f5f9054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663d34ddc056040518163ffffffff1660e01b8152600401608060405180830381865afa158015610666573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061068a919061083a565b5092505091505f604051806020016106a1906107b1565b8181037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe09081018352601f9091011660408181525f805473ffffffffffffffffffffffffffffffffffffffff888116602486015216604484015260648084018a90528251808503909101815260849093018252602080840180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff167f6133f9850000000000000000000000000000000000000000000000000000000017905291519394509192610772918691859101610896565b6040516020818303038152906040529050828160405160200161079692919061091d565b60405160208183030381529060405295505050505050919050565b6105738061093a83390190565b5f602082840312156107ce575f5ffd5b5035919050565b73ffffffffffffffffffffffffffffffffffffffff811681146107f6575f5ffd5b50565b5f60208284031215610809575f5ffd5b8135610814816107d5565b9392505050565b5f6020828403121561082b575f5ffd5b81518015158114610814575f5ffd5b5f5f5f5f6080858703121561084d575f5ffd5b8451610858816107d5565b6020860151909450610869816107d5565b604086015190935061087a816107d5565b606086015190925061088b816107d5565b939692955090935050565b73ffffffffffffffffffffffffffffffffffffffff83168152604060208201525f82518060408401528060208501606085015e5f6060828501015260607fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8301168401019150509392505050565b5f81518060208401855e5f93019283525090919050565b5f61093161092b8386610906565b84610906565b94935050505056fe60a060405260405161057338038061057383398101604081905261002291610353565b61002c828261003e565b506001600160a01b0316608052610444565b610047826100fb565b6040516001600160a01b038316907f1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e905f90a28051156100ef576100ea826001600160a01b0316635c60da1b6040518163ffffffff1660e01b8152600401602060405180830381865afa1580156100c0573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906100e49190610415565b82610209565b505050565b6100f761027c565b5050565b806001600160a01b03163b5f0361013557604051631933b43b60e21b81526001600160a01b03821660048201526024015b60405180910390fd5b807fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d5080546001600160a01b0319166001600160a01b0392831617905560408051635c60da1b60e01b815290515f92841691635c60da1b9160048083019260209291908290030181865afa1580156101ae573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906101d29190610415565b9050806001600160a01b03163b5f036100f757604051634c9c8ce360e01b81526001600160a01b038216600482015260240161012c565b60605f5f846001600160a01b031684604051610225919061042e565b5f60405180830381855af49150503d805f811461025d576040519150601f19603f3d011682016040523d82523d5f602084013e610262565b606091505b50909250905061027385838361029d565b95945050505050565b341561029b5760405163b398979f60e01b815260040160405180910390fd5b565b6060826102b2576102ad826102fc565b6102f5565b81511580156102c957506001600160a01b0384163b155b156102f257604051639996b31560e01b81526001600160a01b038516600482015260240161012c565b50805b9392505050565b80511561030b57805160208201fd5b60405163d6bda27560e01b815260040160405180910390fd5b80516001600160a01b038116811461033a575f5ffd5b919050565b634e487b7160e01b5f52604160045260245ffd5b5f5f60408385031215610364575f5ffd5b61036d83610324565b60208401519092506001600160401b03811115610388575f5ffd5b8301601f81018513610398575f5ffd5b80516001600160401b038111156103b1576103b161033f565b604051601f8201601f19908116603f011681016001600160401b03811182821017156103df576103df61033f565b6040528181528282016020018710156103f6575f5ffd5b8160208401602083015e5f602083830101528093505050509250929050565b5f60208284031215610425575f5ffd5b6102f582610324565b5f82518060208501845e5f920191825250919050565b60805161011861045b5f395f602301526101185ff3fe608060405261000c61000e565b005b61001e610019610020565b6100b3565b565b5f7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16635c60da1b6040518163ffffffff1660e01b8152600401602060405180830381865afa15801561008a573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906100ae91906100d1565b905090565b365f5f375f5f365f845af43d5f5f3e8080156100cd573d5ff35b3d5ffd5b5f602082840312156100e1575f5ffd5b815173ffffffffffffffffffffffffffffffffffffffff81168114610104575f5ffd5b939250505056fea164736f6c634300081d000aa164736f6c634300081d000a";

// bytecodes/AtomWarden.ts
var AtomWardenBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60c9565b7ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00805468010000000000000000900460ff161560685760405163f92ee8a960e01b815260040160405180910390fd5b80546001600160401b039081161460c65780546001600160401b0319166001600160401b0390811782556040519081527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b50565b613bb3806100d65f395ff3fe608060405234801561000f575f5ffd5b50600436106102d8575f3560e01c80638c3ecc4511610187578063d547741f116100dd578063eeb58fa211610093578063f5743c4c1161006e578063f5743c4c14610677578063f5b541a61461068a578063fe74e1ca146106b1575f5ffd5b8063eeb58fa21461063e578063f0a128a314610651578063f4be0a9f14610664575f5ffd5b8063db6c7d3e116100c3578063db6c7d3e146105f9578063e88725f414610618578063ed50d91c1461062b575f5ffd5b8063d547741f146105d3578063d8cbc8ac146105e6575f5ffd5b8063b47b05fc1161013d578063c5d37ae111610118578063c5d37ae1146105af578063c80b62fd146105b8578063cfdbf254146105cb575f5ffd5b8063b47b05fc14610581578063bbde537414610593578063bccc672a146105a6575f5ffd5b8063a1ebf35d1161016d578063a1ebf35d1461054a578063a217fddf14610571578063a82f2e2614610578575f5ffd5b80638c3ecc45146104c957806391d14854146104f3575f5ffd5b80633f4ba83a1161023c5780635c975abb116101f25780637ca548c6116101cd5780637ca548c61461049d5780638456cb59146104a657806384b0196e146104ae575f5ffd5b80635c975abb1461044d57806367a0d84714610477578063779f528b1461048a575f5ffd5b806344be73801161022257806344be7380146104285780635706a93f146104315780635a26eb7f1461043a575f5ffd5b80633f4ba83a1461040d578063433970d614610415575f5ffd5b80631c0d9a61116102915780632c35650a116102775780632c35650a146103de5780632f2ff15d146103e757806336568abe146103fa575f5ffd5b80631c0d9a6114610394578063248a9ca31461039d575f5ffd5b806316606a31116102c157806316606a311461031957806317b2d4f51461034c5780631802be7f1461035f575f5ffd5b806301ffc9a7146102dc5780630bcd44a414610304575b5f5ffd5b6102ef6102ea366004613357565b6106c4565b60405190151581526020015b60405180910390f35b6103176103123660046133c4565b61075c565b005b600654610335906601000000000000900465ffffffffffff1681565b60405165ffffffffffff90911681526020016102fb565b61031761035a36600461344e565b610a07565b6103867f4921076d5d938fe26df63349746edbe28c18a74bcf69f980b8858c1e568dc9c481565b6040519081526020016102fb565b61038660075481565b6103866103ab3660046134b1565b5f9081527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015490565b610386600a5481565b6103176103f53660046134c8565b610d27565b6103176104083660046134c8565b610d70565b610317610dc1565b6103176104233660046134b1565b610dd6565b61038660035481565b61038660085481565b61031761044836600461353e565b610ded565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff166102ef565b6103176104853660046134b1565b610eef565b6103176104983660046135aa565b610f02565b61038660055481565b610317611166565b6104b6611178565b6040516102fb979695949392919061367b565b5f546104db906001600160a01b031681565b6040516001600160a01b0390911681526020016102fb565b6102ef6105013660046134c8565b5f9182527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408084206001600160a01b0393909316845291905290205460ff1690565b6103867fe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f7081565b6103865f81565b61038660045481565b6006546103359065ffffffffffff1681565b6103176105a13660046134b1565b611277565b61038660095481565b61038660025481565b6103176105c636600461372d565b61130c565b610386609681565b6103176105e13660046134c8565b61131f565b6103176105f43660046134b1565b611362565b610386610607366004613748565b60016020525f908152604090205481565b6103176106263660046134c8565b611375565b610317610639366004613748565b6113a9565b61031761064c3660046134b1565b6113bc565b61031761065f36600461372d565b6113cf565b6103176106723660046134b1565b6113e2565b610317610685366004613748565b61178e565b6103867f97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b92981565b6103176106bf3660046134b1565b611850565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f7965db0b00000000000000000000000000000000000000000000000000000000148061075657507f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff000000000000000000000000000000000000000000000000000000008316145b92915050565b5f610765611aea565b805490915060ff68010000000000000000820416159067ffffffffffffffff165f811580156107915750825b90505f8267ffffffffffffffff1660011480156107ad5750303b155b9050811580156107bb575080155b156107f2576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b84547fffffffffffffffffffffffffffffffffffffffffffffffff000000000000000016600117855583156108535784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16680100000000000000001785555b895f0361088c576040517fb1d1f9ae00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610894611b12565b6109086040518060400160405280600a81526020017f41746f6d57617264656e000000000000000000000000000000000000000000008152506040518060400160405280600181526020017f3200000000000000000000000000000000000000000000000000000000000000815250611b1c565b610910611b12565b6109198e611b2e565b6109228d611ba3565b61092b8c611c4f565b6109348b611c95565b61093d89611cd3565b61094688611d44565b61094f86611dc3565b61095887611e47565b60048a9055604080515f8152602081018c90527f86f674391b876df89514893e9ffbba76e944695b1513b5607e057254499d7ab7910160405180910390a183156109f75784547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff168555604051600181527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a15b5050505050505050505050505050565b60025f610a12611aea565b805490915068010000000000000000900460ff1680610a3f5750805467ffffffffffffffff808416911610155b15610a76576040517ff92ee8a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b80547fffffffffffffffffffffffffffffffffffffffffffffff0000000000000000001667ffffffffffffffff831617680100000000000000001781555f8054604080517ffa32161100000000000000000000000000000000000000000000000000000000815290516001600160a01b039092169163fa32161191600480820192610100929091908290030181865afa158015610b15573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610b39919061379b565b519050336001600160a01b03821614610b7e576040517f3374a91900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b875f03610bb7576040517fb1d1f9ae00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610bbf611b12565b610c336040518060400160405280600a81526020017f41746f6d57617264656e000000000000000000000000000000000000000000008152506040518060400160405280600181526020017f3200000000000000000000000000000000000000000000000000000000000000815250611b1c565b610c3b611b12565b610c4481611b2e565b610c4d8a611c4f565b610c5689611c95565b610c5f87611cd3565b610c6886611d44565b610c7184611dc3565b610c7a85611e47565b6004889055604080515f8152602081018a90527f86f674391b876df89514893e9ffbba76e944695b1513b5607e057254499d7ab7910160405180910390a15080547fffffffffffffffffffffffffffffffffffffffffffffff00ffffffffffffffff16815560405167ffffffffffffffff831681527fc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d29060200160405180910390a1505050505050505050565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b6268006020526040902060010154610d6081611ecb565b610d6a8383611ed5565b50505050565b6001600160a01b0381163314610db2576040517f6697b23200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610dbc8282611f22565b505050565b5f610dcb81611ecb565b610dd3611f7c565b50565b5f610de081611ecb565b610de982611c95565b5050565b7f97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929610e1781611ecb565b83828114610e51576040517f637d545700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6096811115610e8c576040517f8de7b57100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b81811015610ee657610ede878783818110610eab57610eab61383d565b90506020020135868684818110610ec457610ec461383d565b9050602002016020810190610ed99190613748565b612006565b600101610e8e565b50505050505050565b5f610ef981611ecb565b610de982611e47565b610f0a61210f565b610f176020840184613748565b6001600160a01b0316336001600160a01b031614610f61576040517f76f1dd6a00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610f6e836020013561216b565b5f610f7c8460200135612224565b9050610f87816122f2565b60015f610f976020870187613748565b6001600160a01b03166001600160a01b031681526020019081526020015f2054846060013514610ff3576040517f994c33b100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61101b61100660a086016080870161372d565b61101660c0870160a0880161372d565b612389565b5f5f6110288686866124ad565b915091506110346126b2565b60015f6110446020890189613748565b6001600160a01b03908116825260208083019390935260409091015f208054600101905584169063481379cc9061107d90890189613748565b6040517fffffffff0000000000000000000000000000000000000000000000000000000060e084901b1681526001600160a01b0390911660048201526024015f604051808303815f87803b1580156110d3575f5ffd5b505af11580156110e5573d5f5f3e3d5ffd5b5050506001600160a01b03831690506111016020880188613748565b6001600160a01b031660208801357fbf95bdd8e776795f5ee66a948ca1f64c00ffe9d063780c563ad095c0958702a861114060608b0160408c0161386a565b6040805160ff909216825261ffff871660208301520160405180910390a4505050505050565b5f61117081611ecb565b610dd361272c565b5f60608082808083817fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d10080549091501580156111b657506001810154155b611221576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601560248201527f4549503731323a20556e696e697469616c697a6564000000000000000000000060448201526064015b60405180910390fd5b6112296127a5565b611231612878565b604080515f808252602082019092527f0f000000000000000000000000000000000000000000000000000000000000009c939b5091995046985030975095509350915050565b5f61128181611ecb565b81158061128f575060055482115b156112c6576040517fb1d1f9ae00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600480549083905560408051828152602081018590527f86f674391b876df89514893e9ffbba76e944695b1513b5607e057254499d7ab7910160405180910390a1505050565b5f61131681611ecb565b610de982611d44565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602052604090206001015461135881611ecb565b610d6a8383611f22565b5f61136c81611ecb565b610de982611dc3565b7f97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b92961139f81611ecb565b610dbc8383612006565b5f6113b381611ecb565b610de982611ba3565b5f6113c681611ecb565b610de982611c4f565b5f6113d981611ecb565b610de982611cd3565b6113ea61210f565b6002545f03611425576040517f39c1afbe00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61142e8161216b565b5f80546040517f0f924db7000000000000000000000000000000000000000000000000000000008152600481018490526001600160a01b0390911690630f924db790602401602060405180830381865afa15801561148e573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906114b2919061388a565b90506001600160a01b0381166114f4576040517fe057efb000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001600160a01b0381163314611536576040517fbe31360400000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61154083612224565b905061154b816122f2565b5f80546040517f5ecb42450000000000000000000000000000000000000000000000000000000081526001600160a01b03848116600483015290911690635ecb424590602401602060405180830381865afa1580156115ac573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906115d091906138a5565b905060035481101561160e576040517f85cff25d00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f80546040517f970a5fc5000000000000000000000000000000000000000000000000000000008152600481018790526001600160a01b039091169063970a5fc590602401602060405180830381865afa15801561166e573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061169291906138bc565b90506002548165ffffffffffff166116aa9190613904565b4210156116e3576040517fd71001ab00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6040517f481379cc0000000000000000000000000000000000000000000000000000000081523360048201526001600160a01b0384169063481379cc906024015f604051808303815f87803b15801561173a575f5ffd5b505af115801561174c573d5f5f3e3d5ffd5b50506040518481523392508791507fcb0f018854207708af6a96d4a78924c15e6a23e3876fd07e8a0284e0431101669060200160405180910390a35050505050565b7f97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b9296117b881611ecb565b6001600160a01b0382166117f8576040517f3aa0b87700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001600160a01b0382165f8181526001602081815260409283902080549092019182905591519081527f993a190cf6f1cb07dd137577c5476514c04303c193c5f54b61e85131f8764e82910160405180910390a25050565b61185861210f565b5f611862336128c9565b6040516020016118729190613917565b60405160208183030381529060405290505f61188d336128df565b60405160200161189d9190613917565b604080517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0818403018152908290525f80547f6828caa6000000000000000000000000000000000000000000000000000000008452919350916001600160a01b0390911690636828caa69061191690869060040161392d565b602060405180830381865afa158015611931573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061195591906138a5565b5f80546040517f6828caa600000000000000000000000000000000000000000000000000000000815292935090916001600160a01b0390911690636828caa6906119a390869060040161392d565b602060405180830381865afa1580156119be573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906119e291906138a5565b90508185141580156119f45750808514155b15611a2b576040517f559f821700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611a348561216b565b5f611a3e86612224565b9050611a49816122f2565b6040517f481379cc0000000000000000000000000000000000000000000000000000000081523360048201526001600160a01b0382169063481379cc906024015f604051808303815f87803b158015611aa0575f5ffd5b505af1158015611ab2573d5f5f3e3d5ffd5b50506040513392508891507f370ab9259d16fd6cc8f5a9f36513a6e5160e35e804cf7434a717ae9ecf2ae815905f90a3505050505050565b5f807ff0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00610756565b611b1a6129a5565b565b611b246129a5565b610de982826129e3565b6001600160a01b038116611b6e576040517f3aa0b87700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611b785f82611ed5565b50610de97f97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b92982611ed5565b6001600160a01b038116611be3576040517f3aa0b87700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f80547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b0383169081179091556040519081527f52d161c0b054ff0f476f54f34dd34c480edb4a541cb443cf5a0f73d96acf2350906020015b60405180910390a150565b600280549082905560408051828152602081018490527f6f88ee581d7bf536cf22db87b1ba056c0cccc44c5a37341bdae366f5339ecad891015b60405180910390a15050565b600380549082905560408051828152602081018490527f45f6a7099afef2c6ad29593291427f5017eab5a69ba80d5a4bb0af867b83688d9101611c89565b6006805465ffffffffffff8381167fffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000083168117909355604080519190921680825260208201939093527fdb39f112360f067da46193a919af96901465f8daab44d4e5836e73f064daf47e9101611c89565b6006805465ffffffffffff83811666010000000000008181027fffffffffffffffffffffffffffffffffffffffff000000000000ffffffffffff85161790945560408051949093049091168084526020840191909152917f3f871a1f772c61791592de2868f905a1576c85c4ab01cb28608c31d61b3dc4379101611c89565b805f03611dfc576040517fdab99eaa00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6008805490829055611e0e824261396c565b60095560408051828152602081018490527f03937ef8050dfab2453c44b9ed5d6e208c397eabbb9894c77096a479278a76899101611c89565b8015801590611e565750600854155b15611e8d576040517fdab99eaa00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600780549082905560408051828152602081018490527f761fb31df50b45330bcc1030f1eaf9b4f02625d670a9cb50e9d1c8e0204359c29101611c89565b610dd38133612a55565b5f611ee08383612ae1565b9050808015611f0e57507fe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f7083145b156107565760058054600101905592915050565b5f611f2d8383612bcb565b9050808015611f5b57507fe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f7083145b8015611f6857505f600554115b1561075657600580545f1901905592915050565b611f84612c8d565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f0330080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001681557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516001600160a01b039091168152602001611c44565b6001600160a01b038116612046576040517f1cc0e0ea00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b61204f8261216b565b5f61205983612224565b9050612064816122f2565b6040517f481379cc0000000000000000000000000000000000000000000000000000000081526001600160a01b03838116600483015282169063481379cc906024015f604051808303815f87803b1580156120bd575f5ffd5b505af11580156120cf573d5f5f3e3d5ffd5b50506040513392506001600160a01b038516915085907f27dc5e2041543e9fa3d5cf76a96a47134117b453b8791dd5c5d23cacd1cbc501905f90a4505050565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff1615611b1a576040517fd93c066500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f546040517ffc4a75f8000000000000000000000000000000000000000000000000000000008152600481018390526001600160a01b039091169063fc4a75f890602401602060405180830381865afa1580156121ca573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906121ee919061397f565b610dd3576040517f792f079000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f80546040517f218e250d000000000000000000000000000000000000000000000000000000008152600481018490526001600160a01b039091169063218e250d90602401602060405180830381865afa158015612284573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906122a8919061388a565b9050806001600160a01b03163b5f036122ed576040517f7b7aa15100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b919050565b806001600160a01b03166357c9ca146040518163ffffffff1660e01b8152600401602060405180830381865afa15801561232e573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190612352919061397f565b15610dd3576040517fe80396ae00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60065461239e9065ffffffffffff1642613904565b8265ffffffffffff1611156123df576040517faae24fc500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6006546123fe906601000000000000900465ffffffffffff1642613904565b8165ffffffffffff16111561243f576040517faae24fc500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8165ffffffffffff168165ffffffffffff16108061246457508165ffffffffffff1642105b8061247657508065ffffffffffff1642115b15610de9576040517f32a8f11f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f80806124b984612ce8565b600454909150808210156124f9576040517fd3cdb9cf00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61250b61250689612d7e565b612e52565b90505f805b848110156126a2575f61252482604161399e565b90505f80612580868d858e61253a826041613904565b92612547939291906139b5565b8080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250612e9992505050565b5090925090505f816003811115612599576125996139dc565b146125d0576040517f16d3c96600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b846001600160a01b0316826001600160a01b03161161261b576040517f3e0dd18900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001600160a01b0382165f9081527fed82e8858f919528fd86c81da277f0812ef4876fae8bc5251645af9640d3f49f602052604090205460ff1661268b576040517f16d3c96600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b835f03612696578199505b50925050600101612510565b5083945050505050935093915050565b6007545f8190036126c05750565b5f600854426126cf919061396c565b905060095481146126e45760098190555f600a555b81600a541061271f576040517f1b650d9000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5050600a80546001019055565b61273461210f565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f0330080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001660011781557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a25833611fee565b7fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d10280546060917fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d100916127f690613a09565b80601f016020809104026020016040519081016040528092919081815260200182805461282290613a09565b801561286d5780601f106128445761010080835404028352916020019161286d565b820191905f5260205f20905b81548152906001019060200180831161285057829003601f168201915b505050505091505090565b7fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d10380546060917fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d100916127f690613a09565b60606107566001600160a01b0383166014612ee2565b60605f6128eb836128c9565b6028602282012090915060601c60295b600181111561299c57600782600f16118015612930575060608382815181106129265761292661383d565b016020015160f81c115b1561298557602060f81b83828151811061294c5761294c61383d565b0160200180517fff00000000000000000000000000000000000000000000000000000000000000908116909218909116905f82901a9053505b60049190911c9061299581613a5a565b90506128fb565b50909392505050565b6129ad613102565b611b1a576040517fd7e6bcf800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6129eb6129a5565b7fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d1007fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d102612a378482613aba565b5060038101612a468382613aba565b505f8082556001909101555050565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602090815260408083206001600160a01b038516845290915290205460ff16610de9576040517fe2517d3f0000000000000000000000000000000000000000000000000000000081526001600160a01b038216600482015260248101839052604401611218565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff16612bc2575f848152602082815260408083206001600160a01b0387168452909152902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00166001179055612b783390565b6001600160a01b0316836001600160a01b0316857f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a46001915050610756565b5f915050610756565b5f8281527f02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800602081815260408084206001600160a01b038616855290915282205460ff1615612bc2575f848152602082815260408083206001600160a01b038716808552925280832080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016905551339287917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a46001915050610756565b7fcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f033005460ff16611b1a576040517f8dfc202b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f811580612cff5750612cfc604183613b93565b15155b15612d36576040517f8ae4cbcd00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b612d4160418361396c565b905060968111156122ed576040517f8de7b57100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f7f4921076d5d938fe26df63349746edbe28c18a74bcf69f980b8858c1e568dc9c4612dad6020840184613748565b6020840135612dc2606086016040870161386a565b6060860135612dd760a088016080890161372d565b612de760c0890160a08a0161372d565b6040805160208101989098526001600160a01b0390961695870195909552606086019390935260ff909116608085015260a084015265ffffffffffff90811660c08401521660e082015261010001604051602081830303815290604052805190602001209050919050565b5f610756612e5e613120565b836040517f19010000000000000000000000000000000000000000000000000000000000008152600281019290925260228201526042902090565b5f5f5f8351604103612ed0576020840151604085015160608601515f1a612ec28882858561312e565b955095509550505050612edb565b505081515f91506002905b9250925092565b6060825f612ef184600261399e565b612efc906002613904565b67ffffffffffffffff811115612f1457612f14613763565b6040519080825280601f01601f191660200182016040528015612f3e576020820181803683370190505b5090507f3000000000000000000000000000000000000000000000000000000000000000815f81518110612f7457612f7461383d565b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff191690815f1a9053507f780000000000000000000000000000000000000000000000000000000000000081600181518110612fd657612fd661383d565b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff191690815f1a9053505f61301085600261399e565b61301b906001613904565b90505b60018111156130b7577f303132333435363738396162636465660000000000000000000000000000000083600f166010811061305c5761305c61383d565b1a60f81b8282815181106130725761307261383d565b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff191690815f1a90535060049290921c916130b081613a5a565b905061301e565b5081156130fa576040517fe22e27eb0000000000000000000000000000000000000000000000000000000081526004810186905260248101859052604401611218565b949350505050565b5f61310b611aea565b5468010000000000000000900460ff16919050565b5f613129613214565b905090565b5f80807f7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a084111561316757505f9150600390508261320a565b604080515f808252602082018084528a905260ff891692820192909252606081018790526080810186905260019060a0016020604051602081039080840390855afa1580156131b8573d5f5f3e3d5ffd5b50506040517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe001519150506001600160a01b03811661320157505f92506001915082905061320a565b92505f91508190505b9450945094915050565b5f7f8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f61323e613287565b613246613302565b60408051602081019490945283019190915260608201524660808201523060a082015260c00160405160208183030381529060405280519060200120905090565b5f7fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d100816132b26127a5565b8051909150156132ca57805160209091012092915050565b815480156132d9579392505050565b7fc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470935050505090565b5f7fa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d1008161332d612878565b80519091501561334557805160209091012092915050565b600182015480156132d9579392505050565b5f60208284031215613367575f5ffd5b81357fffffffff0000000000000000000000000000000000000000000000000000000081168114613396575f5ffd5b9392505050565b6001600160a01b0381168114610dd3575f5ffd5b65ffffffffffff81168114610dd3575f5ffd5b5f5f5f5f5f5f5f5f5f6101208a8c0312156133dd575f5ffd5b89356133e88161339d565b985060208a01356133f88161339d565b975060408a0135965060608a0135955060808a0135945060a08a013561341d816133b1565b935060c08a013561342d816133b1565b989b979a50959894979396929550929360e081013593506101000135919050565b5f5f5f5f5f5f5f60e0888a031215613464575f5ffd5b8735965060208801359550604088013594506060880135613484816133b1565b93506080880135613494816133b1565b9699959850939692959460a0840135945060c09093013592915050565b5f602082840312156134c1575f5ffd5b5035919050565b5f5f604083850312156134d9575f5ffd5b8235915060208301356134eb8161339d565b809150509250929050565b5f5f83601f840112613506575f5ffd5b50813567ffffffffffffffff81111561351d575f5ffd5b6020830191508360208260051b8501011115613537575f5ffd5b9250929050565b5f5f5f5f60408587031215613551575f5ffd5b843567ffffffffffffffff811115613567575f5ffd5b613573878288016134f6565b909550935050602085013567ffffffffffffffff811115613592575f5ffd5b61359e878288016134f6565b95989497509550505050565b5f5f5f83850360e08112156135bd575f5ffd5b60c08112156135ca575f5ffd5b5083925060c084013567ffffffffffffffff8111156135e7575f5ffd5b8401601f810186136135f7575f5ffd5b803567ffffffffffffffff81111561360d575f5ffd5b86602082840101111561361e575f5ffd5b939660209190910195509293505050565b5f81518084528060208401602086015e5f6020828601015260207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011685010191505092915050565b7fff000000000000000000000000000000000000000000000000000000000000008816815260e060208201525f6136b560e083018961362f565b82810360408401526136c7818961362f565b606084018890526001600160a01b038716608085015260a0840186905283810360c0850152845180825260208087019350909101905f5b8181101561371c5783518352602093840193909201916001016136fe565b50909b9a5050505050505050505050565b5f6020828403121561373d575f5ffd5b8135613396816133b1565b5f60208284031215613758575f5ffd5b81356133968161339d565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b80516122ed8161339d565b5f6101008284031280156137ad575f5ffd5b50604051610100810167ffffffffffffffff811182821017156137d2576137d2613763565b6040526137de83613790565b81526137ec60208401613790565b60208201526040838101519082015261380760608401613790565b60608201526080838101519082015260a0808401519082015260c0808401519082015260e0928301519281019290925250919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b5f6020828403121561387a575f5ffd5b813560ff81168114613396575f5ffd5b5f6020828403121561389a575f5ffd5b81516133968161339d565b5f602082840312156138b5575f5ffd5b5051919050565b5f602082840312156138cc575f5ffd5b8151613396816133b1565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b80820180821115610756576107566138d7565b5f82518060208501845e5f920191825250919050565b602081525f613396602083018461362f565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b5f8261397a5761397a61393f565b500490565b5f6020828403121561398f575f5ffd5b81518015158114613396575f5ffd5b8082028115828204841417610756576107566138d7565b5f5f858511156139c3575f5ffd5b838611156139cf575f5ffd5b5050820193919092039150565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b600181811c90821680613a1d57607f821691505b602082108103613a54577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b5f81613a6857613a686138d7565b505f190190565b601f821115610dbc57805f5260205f20601f840160051c81016020851015613a945750805b601f840160051c820191505b81811015613ab3575f8155600101613aa0565b5050505050565b815167ffffffffffffffff811115613ad457613ad4613763565b613ae881613ae28454613a09565b84613a6f565b6020601f821160018114613b1a575f8315613b035750848201515b5f19600385901b1c1916600184901b178455613ab3565b5f848152602081207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08516915b82811015613b675787850151825560209485019460019092019101613b47565b5084821015613b8457868401515f19600387901b60f8161c191681555b50505050600190811b01905550565b5f82613ba157613ba161393f565b50069056fea164736f6c634300081d000a";

// bytecodes/Trust.ts
var TrustBytecode = "0x6080604052348015600e575f5ffd5b5060156019565b60d3565b5f54610100900460ff161560835760405162461bcd60e51b815260206004820152602760248201527f496e697469616c697a61626c653a20636f6e747261637420697320696e697469604482015266616c697a696e6760c81b606482015260840160405180910390fd5b5f5460ff9081161460d1575f805460ff191660ff9081179091556040519081527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b565b611e4f806100e05f395ff3fe608060405234801561000f575f5ffd5b50600436106101c6575f3560e01c80634c42016e116100fe578063a457c2d71161009e578063d547741f1161006e578063d547741f14610472578063dd62ed3e14610485578063e1c7392a146104ca578063e1e1a02a146104d2575f5ffd5b8063a457c2d714610419578063a9059cbb1461042c578063a9d951a31461043f578063b1dceab314610452575f5ffd5b806391d14854116100d957806391d14854146103bc57806395d89b4114610401578063a217fddf14610409578063a2309ff814610410575f5ffd5b80634c42016e146103345780634caf8f271461037457806370a0823114610387575f5ffd5b80632f2ff15d1161016957806336568abe1161014457806336568abe146102e857806339509351146102fb57806340c10f191461030e57806342966c6814610321575f5ffd5b80632f2ff15d146102b1578063313ce567146102c657806332cb6b0c146102d5575f5ffd5b8063095ea7b3116101a4578063095ea7b31461026157806318160ddd1461027457806323b872dd1461027c578063248a9ca31461028f575f5ffd5b806301ffc9a7146101ca57806302319f19146101f257806306fdde031461021f575b5f5ffd5b6101dd6101d83660046119e8565b6104ed565b60405190151581526020015b60405180910390f35b610211610200366004611a4f565b60666020525f908152604090205481565b6040519081526020016101e9565b60408051808201909152600981527f496e74756974696f6e000000000000000000000000000000000000000000000060208201525b6040516101e99190611a68565b6101dd61026f366004611abb565b610585565b603554610211565b6101dd61028a366004611ae3565b61059c565b61021161029d366004611b1d565b5f9081526099602052604090206001015490565b6102c46102bf366004611b34565b6105bf565b005b604051601281526020016101e9565b6102116b033b2e3c9fd0803ce800000081565b6102c46102f6366004611b34565b6105e8565b6101dd610309366004611abb565b610686565b6102c461031c366004611abb565b6106d1565b6102c461032f366004611b1d565b61072c565b61034f73a4df56842887cf52c9ad59c97ec0c058e96af53381565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020016101e9565b6102c4610382366004611a4f565b610739565b610211610395366004611a4f565b73ffffffffffffffffffffffffffffffffffffffff165f9081526033602052604090205490565b6101dd6103ca366004611b34565b5f91825260996020908152604080842073ffffffffffffffffffffffffffffffffffffffff93909316845291905290205460ff1690565b61025461074c565b6102115f81565b61021160655481565b6101dd610427366004611abb565b6107dc565b6101dd61043a366004611abb565b610892565b6102c461044d366004611b5e565b61089f565b60cb5461034f9073ffffffffffffffffffffffffffffffffffffffff1681565b6102c4610480366004611b34565b610a4c565b610211610493366004611b5e565b73ffffffffffffffffffffffffffffffffffffffff9182165f90815260346020908152604080832093909416825291909152205490565b6102c4610a70565b61034f73bc01ab3839be8933f6b93163d129a823684f4cdf81565b5f7fffffffff0000000000000000000000000000000000000000000000000000000082167f7965db0b00000000000000000000000000000000000000000000000000000000148061057f57507f01ffc9a7000000000000000000000000000000000000000000000000000000007fffffffff000000000000000000000000000000000000000000000000000000008316145b92915050565b5f33610592818585610c4d565b5060019392505050565b5f336105a9858285610dcb565b6105b4858585610e68565b506001949350505050565b5f828152609960205260409020600101546105d98161108e565b6105e38383611098565b505050565b73ffffffffffffffffffffffffffffffffffffffff811633146106785760405162461bcd60e51b815260206004820152602f60248201527f416363657373436f6e74726f6c3a2063616e206f6e6c792072656e6f756e636560448201527f20726f6c657320666f722073656c66000000000000000000000000000000000060648201526084015b60405180910390fd5b610682828261118a565b5050565b335f81815260346020908152604080832073ffffffffffffffffffffffffffffffffffffffff8716845290915281205490919061059290829086906106cc908790611bb3565b610c4d565b60cb5473ffffffffffffffffffffffffffffffffffffffff163314610722576040517f7b3fa2b600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6106828282611243565b610736338261131c565b50565b5f6107438161108e565b610682826114ac565b60606037805461075b90611bc6565b80601f016020809104026020016040519081016040528092919081815260200182805461078790611bc6565b80156107d25780601f106107a9576101008083540402835291602001916107d2565b820191905f5260205f20905b8154815290600101906020018083116107b557829003601f168201915b5050505050905090565b335f81815260346020908152604080832073ffffffffffffffffffffffffffffffffffffffff87168452909152812054909190838110156108855760405162461bcd60e51b815260206004820152602560248201527f45524332303a2064656372656173656420616c6c6f77616e63652062656c6f7760448201527f207a65726f000000000000000000000000000000000000000000000000000000606482015260840161066f565b6105b48286868403610c4d565b5f33610592818585610e68565b5f54600290610100900460ff161580156108bf57505f5460ff8083169116105b6109315760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201527f647920696e697469616c697a6564000000000000000000000000000000000000606482015260840161066f565b5f80547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00001660ff83161761010017905573ffffffffffffffffffffffffffffffffffffffff83161580610998575073ffffffffffffffffffffffffffffffffffffffff8216155b156109cf576040517f7cddae9100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6109d7611567565b6109e15f84611098565b6109ea826114ac565b5f80547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff16905560405160ff821681527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a1505050565b5f82815260996020526040902060010154610a668161108e565b6105e3838361118a565b5f54610100900460ff1615808015610a8e57505f54600160ff909116105b80610aa75750303b158015610aa757505f5460ff166001145b610b195760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201527f647920696e697469616c697a6564000000000000000000000000000000000000606482015260840161066f565b5f80547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001660011790558015610b75575f80547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff166101001790555b610be96040518060400160405280600581526020017f54525553540000000000000000000000000000000000000000000000000000008152506040518060400160405280600581526020017f54525553540000000000000000000000000000000000000000000000000000008152506115e5565b8015610736575f80547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a150565b73ffffffffffffffffffffffffffffffffffffffff8316610cd55760405162461bcd60e51b8152602060048201526024808201527f45524332303a20617070726f76652066726f6d20746865207a65726f2061646460448201527f7265737300000000000000000000000000000000000000000000000000000000606482015260840161066f565b73ffffffffffffffffffffffffffffffffffffffff8216610d5e5760405162461bcd60e51b815260206004820152602260248201527f45524332303a20617070726f766520746f20746865207a65726f20616464726560448201527f7373000000000000000000000000000000000000000000000000000000000000606482015260840161066f565b73ffffffffffffffffffffffffffffffffffffffff8381165f8181526034602090815260408083209487168084529482529182902085905590518481527f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925910160405180910390a3505050565b73ffffffffffffffffffffffffffffffffffffffff8381165f908152603460209081526040808320938616835292905220545f198114610e625781811015610e555760405162461bcd60e51b815260206004820152601d60248201527f45524332303a20696e73756666696369656e7420616c6c6f77616e6365000000604482015260640161066f565b610e628484848403610c4d565b50505050565b73ffffffffffffffffffffffffffffffffffffffff8316610ef15760405162461bcd60e51b815260206004820152602560248201527f45524332303a207472616e736665722066726f6d20746865207a65726f20616460448201527f6472657373000000000000000000000000000000000000000000000000000000606482015260840161066f565b73ffffffffffffffffffffffffffffffffffffffff8216610f7a5760405162461bcd60e51b815260206004820152602360248201527f45524332303a207472616e7366657220746f20746865207a65726f206164647260448201527f6573730000000000000000000000000000000000000000000000000000000000606482015260840161066f565b73ffffffffffffffffffffffffffffffffffffffff83165f90815260336020526040902054818110156110155760405162461bcd60e51b815260206004820152602660248201527f45524332303a207472616e7366657220616d6f756e742065786365656473206260448201527f616c616e63650000000000000000000000000000000000000000000000000000606482015260840161066f565b73ffffffffffffffffffffffffffffffffffffffff8085165f8181526033602052604080822086860390559286168082529083902080548601905591517fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef906110819086815260200190565b60405180910390a3610e62565b610736813361166b565b5f82815260996020908152604080832073ffffffffffffffffffffffffffffffffffffffff8516845290915290205460ff16610682575f82815260996020908152604080832073ffffffffffffffffffffffffffffffffffffffff85168452909152902080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016600117905561112c3390565b73ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16837f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a45050565b5f82815260996020908152604080832073ffffffffffffffffffffffffffffffffffffffff8516845290915290205460ff1615610682575f82815260996020908152604080832073ffffffffffffffffffffffffffffffffffffffff8516808552925280832080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016905551339285917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a45050565b73ffffffffffffffffffffffffffffffffffffffff82166112a65760405162461bcd60e51b815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f206164647265737300604482015260640161066f565b8060355f8282546112b79190611bb3565b909155505073ffffffffffffffffffffffffffffffffffffffff82165f818152603360209081526040808320805486019055518481527fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef910160405180910390a35050565b73ffffffffffffffffffffffffffffffffffffffff82166113a55760405162461bcd60e51b815260206004820152602160248201527f45524332303a206275726e2066726f6d20746865207a65726f2061646472657360448201527f7300000000000000000000000000000000000000000000000000000000000000606482015260840161066f565b73ffffffffffffffffffffffffffffffffffffffff82165f90815260336020526040902054818110156114405760405162461bcd60e51b815260206004820152602260248201527f45524332303a206275726e20616d6f756e7420657863656564732062616c616e60448201527f6365000000000000000000000000000000000000000000000000000000000000606482015260840161066f565b73ffffffffffffffffffffffffffffffffffffffff83165f8181526033602090815260408083208686039055603580548790039055518581529192917fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef910160405180910390a3505050565b73ffffffffffffffffffffffffffffffffffffffff81166114f9576040517f7cddae9100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60cb80547fffffffffffffffffffffffff00000000000000000000000000000000000000001673ffffffffffffffffffffffffffffffffffffffff83169081179091556040517f50adc3e0257dc8e6c41ace528fe30d6d8ad7cc047bade9ff5aa2202170d2008b905f90a250565b5f54610100900460ff166115e35760405162461bcd60e51b815260206004820152602b60248201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960448201527f6e697469616c697a696e67000000000000000000000000000000000000000000606482015260840161066f565b565b5f54610100900460ff166116615760405162461bcd60e51b815260206004820152602b60248201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960448201527f6e697469616c697a696e67000000000000000000000000000000000000000000606482015260840161066f565b610682828261170a565b5f82815260996020908152604080832073ffffffffffffffffffffffffffffffffffffffff8516845290915290205460ff16610682576116aa8161179f565b6116b58360206117be565b6040516020016116c6929190611c2e565b604080517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08184030181529082905262461bcd60e51b825261066f91600401611a68565b5f54610100900460ff166117865760405162461bcd60e51b815260206004820152602b60248201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960448201527f6e697469616c697a696e67000000000000000000000000000000000000000000606482015260840161066f565b60366117928382611d10565b5060376105e38282611d10565b606061057f73ffffffffffffffffffffffffffffffffffffffff831660145b60605f6117cc836002611de9565b6117d7906002611bb3565b67ffffffffffffffff8111156117ef576117ef611c98565b6040519080825280601f01601f191660200182016040528015611819576020820181803683370190505b5090507f3000000000000000000000000000000000000000000000000000000000000000815f8151811061184f5761184f611e00565b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff191690815f1a9053507f7800000000000000000000000000000000000000000000000000000000000000816001815181106118b1576118b1611e00565b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff191690815f1a9053505f6118eb846002611de9565b6118f6906001611bb3565b90505b6001811115611992577f303132333435363738396162636465660000000000000000000000000000000085600f166010811061193757611937611e00565b1a60f81b82828151811061194d5761194d611e00565b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff191690815f1a90535060049490941c9361198b81611e2d565b90506118f9565b5083156119e15760405162461bcd60e51b815260206004820181905260248201527f537472696e67733a20686578206c656e67746820696e73756666696369656e74604482015260640161066f565b9392505050565b5f602082840312156119f8575f5ffd5b81357fffffffff00000000000000000000000000000000000000000000000000000000811681146119e1575f5ffd5b803573ffffffffffffffffffffffffffffffffffffffff81168114611a4a575f5ffd5b919050565b5f60208284031215611a5f575f5ffd5b6119e182611a27565b602081525f82518060208401528060208501604085015e5f6040828501015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011684010191505092915050565b5f5f60408385031215611acc575f5ffd5b611ad583611a27565b946020939093013593505050565b5f5f5f60608486031215611af5575f5ffd5b611afe84611a27565b9250611b0c60208501611a27565b929592945050506040919091013590565b5f60208284031215611b2d575f5ffd5b5035919050565b5f5f60408385031215611b45575f5ffd5b82359150611b5560208401611a27565b90509250929050565b5f5f60408385031215611b6f575f5ffd5b611b7883611a27565b9150611b5560208401611a27565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b8082018082111561057f5761057f611b86565b600181811c90821680611bda57607f821691505b602082108103611c11577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b5f81518060208401855e5f93019283525090919050565b7f416363657373436f6e74726f6c3a206163636f756e742000000000000000000081525f611c5f6017830185611c17565b7f206973206d697373696e6720726f6c65200000000000000000000000000000008152611c8f6011820185611c17565b95945050505050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b601f8211156105e357805f5260205f20601f840160051c81016020851015611cea5750805b601f840160051c820191505b81811015611d09575f8155600101611cf6565b5050505050565b815167ffffffffffffffff811115611d2a57611d2a611c98565b611d3e81611d388454611bc6565b84611cc5565b6020601f821160018114611d70575f8315611d595750848201515b5f19600385901b1c1916600184901b178455611d09565b5f848152602081207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08516915b82811015611dbd5787850151825560209485019460019092019101611d9d565b5084821015611dda57868401515f19600387901b60f8161c191681555b50505050600190811b01905550565b808202811582820484141761057f5761057f611b86565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b5f81611e3b57611e3b611b86565b505f19019056fea164736f6c634300081d000a";

// bytecodes/TrustToken.ts
var TrustTokenBytecode = "0x6080604052348015600e575f5ffd5b506112e28061001c5f395ff3fe608060405234801561000f575f5ffd5b506004361061012f575f3560e01c80634c42016e116100ad578063a457c2d71161007d578063dd62ed3e11610063578063dd62ed3e146102ae578063e1c7392a146102f3578063e1e1a02a146102fb575f5ffd5b8063a457c2d714610288578063a9059cbb1461029b575f5ffd5b80634c42016e1461020257806370a082311461024257806395d89b4114610277578063a2309ff81461027f575f5ffd5b806323b872dd1161010257806332cb6b0c116100e857806332cb6b0c146101c757806339509351146101da57806340c10f19146101ed575f5ffd5b806323b872dd146101a5578063313ce567146101b8575f5ffd5b806302319f191461013357806306fdde0314610165578063095ea7b31461017a57806318160ddd1461019d575b5f5ffd5b610152610141366004610f60565b60666020525f908152604090205481565b6040519081526020015b60405180910390f35b61016d610316565b60405161015c9190610f80565b61018d610188366004610fd3565b6103a6565b604051901515815260200161015c565b603554610152565b61018d6101b3366004610ffb565b6103bf565b6040516012815260200161015c565b6101526b033b2e3c9fd0803ce800000081565b61018d6101e8366004610fd3565b6103e2565b6102006101fb366004610fd3565b61042d565b005b61021d73a4df56842887cf52c9ad59c97ec0c058e96af53381565b60405173ffffffffffffffffffffffffffffffffffffffff909116815260200161015c565b610152610250366004610f60565b73ffffffffffffffffffffffffffffffffffffffff165f9081526033602052604090205490565b61016d610638565b61015260655481565b61018d610296366004610fd3565b610647565b61018d6102a9366004610fd3565b6106fd565b6101526102bc366004611035565b73ffffffffffffffffffffffffffffffffffffffff9182165f90815260346020908152604080832093909416825291909152205490565b61020061070a565b61021d73bc01ab3839be8933f6b93163d129a823684f4cdf81565b60606036805461032590611066565b80601f016020809104026020016040519081016040528092919081815260200182805461035190611066565b801561039c5780601f106103735761010080835404028352916020019161039c565b820191905f5260205f20905b81548152906001019060200180831161037f57829003601f168201915b5050505050905090565b5f336103b38185856108e8565b60019150505b92915050565b5f336103cc858285610a66565b6103d7858585610b22565b506001949350505050565b335f81815260346020908152604080832073ffffffffffffffffffffffffffffffffffffffff871684529091528120549091906103b390829086906104289087906110e4565b6108e8565b3373bc01ab3839be8933f6b93163d129a823684f4cdf148061046257503373a4df56842887cf52c9ad59c97ec0c058e96af533145b6104b35760405162461bcd60e51b815260206004820152601660248201527f4e6f7420617574686f72697a656420746f206d696e740000000000000000000060448201526064015b60405180910390fd5b5f3373bc01ab3839be8933f6b93163d129a823684f4cdf146104f75760646104e86b033b2e3c9fd0803ce800000060336110f7565b6104f2919061110e565b61051a565b60646105106b033b2e3c9fd0803ce800000060316110f7565b61051a919061110e565b90506b033b2e3c9fd0803ce80000008260655461053791906110e4565b11156105855760405162461bcd60e51b815260206004820152601360248201527f4d617820737570706c792065786365656465640000000000000000000000000060448201526064016104aa565b335f9081526066602052604090205481906105a19084906110e4565b11156105ef5760405162461bcd60e51b815260206004820152601f60248201527f4d696e74696e672063617020657863656564656420666f72206d696e7465720060448201526064016104aa565b8160655f82825461060091906110e4565b9091555050335f90815260666020526040812080548492906106239084906110e4565b9091555061063390508383610d48565b505050565b60606037805461032590611066565b335f81815260346020908152604080832073ffffffffffffffffffffffffffffffffffffffff87168452909152812054909190838110156106f05760405162461bcd60e51b815260206004820152602560248201527f45524332303a2064656372656173656420616c6c6f77616e63652062656c6f7760448201527f207a65726f00000000000000000000000000000000000000000000000000000060648201526084016104aa565b6103d782868684036108e8565b5f336103b3818585610b22565b5f54610100900460ff161580801561072857505f54600160ff909116105b806107415750303b15801561074157505f5460ff166001145b6107b35760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201527f647920696e697469616c697a656400000000000000000000000000000000000060648201526084016104aa565b5f80547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00166001179055801561080f575f80547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff166101001790555b6108836040518060400160405280600581526020017f54525553540000000000000000000000000000000000000000000000000000008152506040518060400160405280600581526020017f5452555354000000000000000000000000000000000000000000000000000000815250610e22565b80156108e5575f80547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff169055604051600181527f7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb38474024989060200160405180910390a15b50565b73ffffffffffffffffffffffffffffffffffffffff83166109705760405162461bcd60e51b8152602060048201526024808201527f45524332303a20617070726f76652066726f6d20746865207a65726f2061646460448201527f726573730000000000000000000000000000000000000000000000000000000060648201526084016104aa565b73ffffffffffffffffffffffffffffffffffffffff82166109f95760405162461bcd60e51b815260206004820152602260248201527f45524332303a20617070726f766520746f20746865207a65726f20616464726560448201527f737300000000000000000000000000000000000000000000000000000000000060648201526084016104aa565b73ffffffffffffffffffffffffffffffffffffffff8381165f8181526034602090815260408083209487168084529482529182902085905590518481527f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925910160405180910390a3505050565b73ffffffffffffffffffffffffffffffffffffffff8381165f908152603460209081526040808320938616835292905220547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8114610b1c5781811015610b0f5760405162461bcd60e51b815260206004820152601d60248201527f45524332303a20696e73756666696369656e7420616c6c6f77616e636500000060448201526064016104aa565b610b1c84848484036108e8565b50505050565b73ffffffffffffffffffffffffffffffffffffffff8316610bab5760405162461bcd60e51b815260206004820152602560248201527f45524332303a207472616e736665722066726f6d20746865207a65726f20616460448201527f647265737300000000000000000000000000000000000000000000000000000060648201526084016104aa565b73ffffffffffffffffffffffffffffffffffffffff8216610c345760405162461bcd60e51b815260206004820152602360248201527f45524332303a207472616e7366657220746f20746865207a65726f206164647260448201527f657373000000000000000000000000000000000000000000000000000000000060648201526084016104aa565b73ffffffffffffffffffffffffffffffffffffffff83165f9081526033602052604090205481811015610ccf5760405162461bcd60e51b815260206004820152602660248201527f45524332303a207472616e7366657220616d6f756e742065786365656473206260448201527f616c616e6365000000000000000000000000000000000000000000000000000060648201526084016104aa565b73ffffffffffffffffffffffffffffffffffffffff8085165f8181526033602052604080822086860390559286168082529083902080548601905591517fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef90610d3b9086815260200190565b60405180910390a3610b1c565b73ffffffffffffffffffffffffffffffffffffffff8216610dab5760405162461bcd60e51b815260206004820152601f60248201527f45524332303a206d696e7420746f20746865207a65726f20616464726573730060448201526064016104aa565b8060355f828254610dbc91906110e4565b909155505073ffffffffffffffffffffffffffffffffffffffff82165f818152603360209081526040808320805486019055518481527fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef910160405180910390a35b5050565b5f54610100900460ff16610e9e5760405162461bcd60e51b815260206004820152602b60248201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960448201527f6e697469616c697a696e6700000000000000000000000000000000000000000060648201526084016104aa565b610e1e82825f54610100900460ff16610f1f5760405162461bcd60e51b815260206004820152602b60248201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960448201527f6e697469616c697a696e6700000000000000000000000000000000000000000060648201526084016104aa565b6036610f2b83826111be565b50603761063382826111be565b803573ffffffffffffffffffffffffffffffffffffffff81168114610f5b575f5ffd5b919050565b5f60208284031215610f70575f5ffd5b610f7982610f38565b9392505050565b602081525f82518060208401528060208501604085015e5f6040828501015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011684010191505092915050565b5f5f60408385031215610fe4575f5ffd5b610fed83610f38565b946020939093013593505050565b5f5f5f6060848603121561100d575f5ffd5b61101684610f38565b925061102460208501610f38565b929592945050506040919091013590565b5f5f60408385031215611046575f5ffd5b61104f83610f38565b915061105d60208401610f38565b90509250929050565b600181811c9082168061107a57607f821691505b6020821081036110b1577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b808201808211156103b9576103b96110b7565b80820281158282048414176103b9576103b96110b7565b5f82611141577f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b500490565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b601f82111561063357805f5260205f20601f840160051c810160208510156111985750805b601f840160051c820191505b818110156111b7575f81556001016111a4565b5050505050565b815167ffffffffffffffff8111156111d8576111d8611146565b6111ec816111e68454611066565b84611173565b6020601f82116001811461123d575f83156112075750848201515b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600385901b1c1916600184901b1784556111b7565b5f848152602081207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08516915b8281101561128a578785015182556020948501946001909201910161126a565b50848210156112c657868401517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600387901b60f8161c191681555b50505050600190811b0190555056fea164736f6c634300081d000a";

// bytecodes/WrappedTrust.ts
var WrappedTrustBytecode = "0x60c0604052600d60809081526c15dc985c1c19590815149554d5609a1b60a0525f9061002b908261010d565b5060408051808201909152600681526515d5149554d560d21b6020820152600190610056908261010d565b506002805460ff1916601217905534801561006f575f5ffd5b506101c7565b634e487b7160e01b5f52604160045260245ffd5b600181811c9082168061009d57607f821691505b6020821081036100bb57634e487b7160e01b5f52602260045260245ffd5b50919050565b601f82111561010857805f5260205f20601f840160051c810160208510156100e65750805b601f840160051c820191505b81811015610105575f81556001016100f2565b50505b505050565b81516001600160401b0381111561012657610126610075565b61013a816101348454610089565b846100c1565b6020601f82116001811461016c575f83156101555750848201515b5f19600385901b1c1916600184901b178455610105565b5f84815260208120601f198516915b8281101561019b578785015182556020948501946001909201910161017b565b50848210156101b857868401515f19600387901b60f8161c191681555b50505050600190811b01905550565b610940806101d45f395ff3fe6080604052600436106100bb575f3560e01c8063313ce56711610071578063a9059cbb1161004c578063a9059cbb146101eb578063d0e30db01461020a578063dd62ed3e14610212575f5ffd5b8063313ce5671461018157806370a08231146101ac57806395d89b41146101d7575f5ffd5b806318160ddd116100a157806318160ddd1461012757806323b872dd146101435780632e1a7d4d14610162575f5ffd5b806306fdde03146100ce578063095ea7b3146100f8575f5ffd5b366100ca576100c8610248565b005b5f5ffd5b3480156100d9575f5ffd5b506100e26102a2565b6040516100ef9190610751565b60405180910390f35b348015610103575f5ffd5b506101176101123660046107cc565b61032d565b60405190151581526020016100ef565b348015610132575f5ffd5b50475b6040519081526020016100ef565b34801561014e575f5ffd5b5061011761015d3660046107f4565b6103a6565b34801561016d575f5ffd5b506100c861017c36600461082e565b6105b5565b34801561018c575f5ffd5b5060025461019a9060ff1681565b60405160ff90911681526020016100ef565b3480156101b7575f5ffd5b506101356101c6366004610845565b60036020525f908152604090205481565b3480156101e2575f5ffd5b506100e2610634565b3480156101f6575f5ffd5b506101176102053660046107cc565b610641565b6100c8610248565b34801561021d575f5ffd5b5061013561022c36600461085e565b600460209081525f928352604080842090915290825290205481565b335f90815260036020526040812080543492906102669084906108bc565b909155505060405134815233907fe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c9060200160405180910390a2565b5f80546102ae906108cf565b80601f01602080910402602001604051908101604052809291908181526020018280546102da906108cf565b80156103255780601f106102fc57610100808354040283529160200191610325565b820191905f5260205f20905b81548152906001019060200180831161030857829003601f168201915b505050505081565b335f81815260046020908152604080832073ffffffffffffffffffffffffffffffffffffffff8716808552925280832085905551919290917f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925906103949086815260200190565b60405180910390a35060015b92915050565b73ffffffffffffffffffffffffffffffffffffffff83165f908152600360205260408120548211156103d6575f5ffd5b73ffffffffffffffffffffffffffffffffffffffff8416331480159061044b575073ffffffffffffffffffffffffffffffffffffffff84165f9081526004602090815260408083203384529091529020547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff14155b156104d05773ffffffffffffffffffffffffffffffffffffffff84165f90815260046020908152604080832033845290915290205482111561048b575f5ffd5b73ffffffffffffffffffffffffffffffffffffffff84165f908152600460209081526040808320338452909152812080548492906104ca908490610920565b90915550505b73ffffffffffffffffffffffffffffffffffffffff84165f9081526003602052604081208054849290610504908490610920565b909155505073ffffffffffffffffffffffffffffffffffffffff83165f908152600360205260408120805484929061053d9084906108bc565b925050819055508273ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff167fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef846040516105a391815260200190565b60405180910390a35060019392505050565b335f908152600360205260409020548111156105cf575f5ffd5b335f90815260036020526040812080548392906105ed908490610920565b909155505060405181815233907f7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b659060200160405180910390a26106313382610654565b50565b600180546102ae906108cf565b5f61064d3384846103a6565b9392505050565b8047101561069b576040517fcf4791810000000000000000000000000000000000000000000000000000000081524760048201526024810182905260440160405180910390fd5b5f5f8373ffffffffffffffffffffffffffffffffffffffff16836040515f6040518083038185875af1925050503d805f81146106f2576040519150601f19603f3d011682016040523d82523d5f602084013e6106f7565b606091505b50915091508161070a5761070a81610710565b50505050565b80511561071f57805160208201fd5b6040517fd6bda27500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b602081525f82518060208401528060208501604085015e5f6040828501015260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011684010191505092915050565b803573ffffffffffffffffffffffffffffffffffffffff811681146107c7575f5ffd5b919050565b5f5f604083850312156107dd575f5ffd5b6107e6836107a4565b946020939093013593505050565b5f5f5f60608486031215610806575f5ffd5b61080f846107a4565b925061081d602085016107a4565b929592945050506040919091013590565b5f6020828403121561083e575f5ffd5b5035919050565b5f60208284031215610855575f5ffd5b61064d826107a4565b5f5f6040838503121561086f575f5ffd5b610878836107a4565b9150610886602084016107a4565b90509250929050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b808201808211156103a0576103a061088f565b600181811c908216806108e357607f821691505b60208210810361091a577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b818103818111156103a0576103a061088f56fea164736f6c634300081d000a";

// bytecodes/MultiVaultLib.ts
var MultiVaultLibBytecode = "0x6151e5610034600b8282823980515f1a607314602857634e487b7160e01b5f525f60045260245ffd5b305f52607381538281f3fe73000000000000000000000000000000000000000030146080604052600436106101dc575f3560e01c80637b9c8fa411610109578063d93e9914116100a9578063f571900811610079578063f5719008146104fc578063f679bf091461050f578063f759917b1461052e578063f87d29ac1461054d575f5ffd5b8063d93e991414610483578063d9dff30f146104a2578063dcd2af49146104b5578063dd6342d1146104dd575f5ffd5b8063a20efbea116100e4578063a20efbea14610413578063a713c75e14610432578063a814c1fe14610451578063ab19bcd414610470575f5ffd5b80637b9c8fa4146103c2578063864c5fbf146103e1578063a0ae55c714610400575f5ffd5b80634656c5f11161017f5780635d19ffdf1161014f5780635d19ffdf146103465780635eb53bd4146103655780636ced5d3f1461037857806376671808146103ba575f5ffd5b80634656c5f1146102d25780634f9a2e14146102f557806358717e0d1461031457806358a19d5e14610327575f5ffd5b8063218e250d116101ba578063218e250d1461025557806323683bbd146102805780632fe8f64c146102ac5780634523e2bc146102bf575f5ffd5b806301e25f30146101e05780631a2385de146102135780631f555ba914610234575b5f5ffd5b6101f36101ee3660046143b0565b610560565b604080519384526020840192909252908201526060015b60405180910390f35b6102266102213660046143b0565b61057a565b60405190815260200161020a565b81801561023f575f5ffd5b5061025361024e3660046143ef565b61063a565b005b610268610263366004614419565b610648565b6040516001600160a01b03909116815260200161020a565b81801561028b575f5ffd5b5061029f61029a366004614478565b6106cf565b60405161020a9190614502565b6102536102ba366004614544565b610739565b6102266102cd366004614589565b61074d565b6102e56102e03660046145b2565b610763565b604051901515815260200161020a565b818015610300575f5ffd5b5061029f61030f3660046145e9565b61076e565b610226610322366004614589565b61079f565b818015610332575f5ffd5b506102266103413660046146be565b6107ab565b818015610351575f5ffd5b506102536103603660046143ef565b610810565b6101f36103733660046143b0565b61081a565b6102266103863660046146fe565b5f918252601b602090815260408084209284529181528183206001600160a01b039490941683526002909301909252205490565b610226610827565b8180156103cd575f5ffd5b506102536103dc36600461475d565b6108b1565b8180156103ec575f5ffd5b5061029f6103fb3660046147ea565b6108c1565b6102e561040e3660046145b2565b610933565b81801561041e575f5ffd5b5061029f61042d3660046147ea565b61093e565b81801561043d575f5ffd5b5061029f61044c3660046148d4565b610b21565b81801561045c575f5ffd5b5061022661046b3660046146be565b610bd2565b6102e561047e3660046145b2565b610c3c565b81801561048e575f5ffd5b5061029f61049d36600461498c565b610c47565b6101f36104b0366004614a0c565b610c65565b6104c86104c3366004614589565b610c85565b6040805192835260208301919091520161020a565b8180156104e8575f5ffd5b506102266104f7366004614a4a565b610ca0565b6102e561050a366004614419565b610cad565b81801561051a575f5ffd5b5061029f610529366004614a82565b610cb7565b818015610539575f5ffd5b50610253610548366004614b64565b610ea0565b61022661055b3660046143ef565b610ead565b5f5f5f61056d858561101c565b9250925092509250925092565b5f828152601b6020908152604080832084845282528083206014546001820154825484517f7c11d62400000000000000000000000000000000000000000000000000000000815260048101899052602481019290925260448201529251859492936001600160a01b0390921692637c11d62492606480820193918290030181865afa15801561060b573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061062f9190614bb0565b925050505b92915050565b61064482826110ec565b5050565b5f80601001546040517f218e250d000000000000000000000000000000000000000000000000000000008152600481018490526001600160a01b039091169063218e250d90602401602060405180830381865afa1580156106ab573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906106349190614bc7565b60606106db338861123c565b610711576040517f508e81aa00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61071d858585611290565b905061072d888888888886611350565b98975050505050505050565b610746858585858561148d565b5050505050565b5f6107598484846115f6565b90505b9392505050565b5f61075c838361123c565b60605f61077c858585611290565b9050610790338c8c8c8c8c8c8c8c8a6116c2565b9b9a5050505050505050505050565b5f6107598484846118b9565b5f6107b6338761193f565b6107ec576040517fd76f6ff800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6107f686836110ec565b610804338787878688611962565b90505b95945050505050565b6106448282611c04565b5f5f5f61056d8585611d49565b60048054604080517f7667180800000000000000000000000000000000000000000000000000000000815290515f936001600160a01b03909316926376671808928082019260209290918290030181865afa158015610888573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906108ac9190614bb0565b905090565b6108bc838383611dfd565b505050565b60606108cd338c61123c565b610903576040517f508e81aa00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f61090f858585611290565b90506109238c8c8c8c8c8c8c8c8c8a6116c2565b9c9b505050505050505050505050565b5f61075c8383611e8e565b60605f61094c878785611290565b90508980158061095c5750609681115b15610993576040517f92cbb3c900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8067ffffffffffffffff8111156109ac576109ac614730565b6040519080825280602002602001820160405280156109d5578160200160208202803683370190505b50925080891415806109e75750808714155b806109f25750808514155b15610a29576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610a33338e61193f565b610a69576040517fd76f6ff800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b81811015610b0657610ae1338f8f8f85818110610a8a57610a8a614be2565b905060200201358e8e86818110610aa357610aa3614be2565b905060200201358d8d87818110610abc57610abc614be2565b905060200201358c8c88818110610ad557610ad5614be2565b90506020020135611962565b848281518110610af357610af3614be2565b6020908102919091010152600101610a6b565b50610b118d836110ec565b50509a9950505050505050505050565b6060610b2d338a61123c565b610b63576040517f508e81aa00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b86838114610b9d576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610ba78585611eb1565b5f610bb3888886611290565b90505f610bc48c8c8c8c8c87611350565b9050610790818d898961201a565b5f610bdd3387611e8e565b610c13576040517f25d56e6200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5f610c233389898989896120e0565b91509150610c318883611c04565b979650505050505050565b5f61075c838361193f565b60605f610c55858585611290565b9050610c31338888888886611350565b5f5f5f610c74878787876121df565b509199909850909650945050505050565b5f5f610c938585855f61223a565b5090969095509350505050565b5f610807858585856123d1565b5f610634826124a4565b6060871580610cc65750609688115b15610cfd576040517f92cbb3c900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8767ffffffffffffffff811115610d1657610d16614730565b604051908082528060200260200182016040528015610d3f578160200160208202803683370190505b5090508786141580610d515750878414155b80610d5c5750878214155b15610d93576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b610d9d338b611e8e565b610dd3576040517f25d56e6200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f805b89811015610e87575f5f610e4e338f8f8f87818110610df757610df7614be2565b905060200201358e8e88818110610e1057610e10614be2565b905060200201358d8d89818110610e2957610e29614be2565b905060200201358c8c8a818110610e4257610e42614be2565b905060200201356120e0565b9092509050610e5d8285614c3c565b935080858481518110610e7257610e72614be2565b60209081029190910101525050600101610dd6565b50610e928b82611c04565b509998505050505050505050565b61074685858585856124df565b5f5f610eb7610827565b905080831115610ef3576040517f2edbbfb200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001600160a01b0384165f90815260208052604080822081516060810192839052839290919060039082845b815481526020019060010190808311610f1f575050505050905084815f60038110610f4c57610f4c614be2565b602002015111610f90576001600160a01b0386165f908152601f8301602052604081209082815b602002015181526020019081526020015f20549350505050610634565b60208101518510610fbd576001600160a01b0386165f908152601f83016020526040812090826001610f73565b60408101518510610fea576001600160a01b0386165f908152601f83016020526040812090826002610f73565b6040517fde728b9000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6015545f908190819081908161103061276a565b90508087101561106c576040517f7d3287c000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6110778289614c4f565b90505f61108b828660110160020154612791565b90505f6110978b6127a3565b6110a1575f6110b2565b6110b28387600b0160010154612791565b90505f816110c08486614c4f565b6110ca9190614c4f565b90505f6110d88d88846115f6565b9a5093985096505050505050509250925092565b6110f582612823565b5f5f6110ff610827565b6001600160a01b0385165f9081526020848101905260409020805491925090821461113f5780541561113b576001810180546002830155815490555b8181555b5f828152601e840160205260408120805486929061115e908490614c62565b90915550505f828152601e840160205260408082205490519091869185917f75ba148093b67b99a3a73383328e124a6ff020639d126ec6a0adb55766d3221791a46001600160a01b0385165f908152601f840160209081526040808320858452909152812080548692906111d3908490614c62565b90915550506001600160a01b0385165f818152601f8501602090815260408083208684528252918290205491519182528692859290917ffbc12b3b70d38b479dc83423a10420167e484f3fe4f16391b77b925194168a3391015b60405180910390a45050505050565b5f816001600160a01b0316836001600160a01b0316148061075c575060045b6001600160a01b039283165f908152601a602090815260408083209690951682529490945291909220541660ff161515919050565b5f8280158061129f5750609681115b156112d6576040517f92cbb3c900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b8181101561130e578585828181106112f2576112f2614be2565b90506020020135836113049190614c3c565b92506001016112d8565b50818314611348576040517f7b0a37cf00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b509392505050565b6060845f81900361138d576040517f7a291d9100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8084146113c6576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f8167ffffffffffffffff8111156113e0576113e0614730565b604051908082528060200260200182016040528015611409578160200160208202803683370190505b5090505f5b828110156114815761145c8a8a8a8481811061142c5761142c614be2565b905060200281019061143e9190614cb6565b8a8a8681811061145057611450614be2565b9050602002013561298e565b82828151811061146e5761146e614be2565b602090810291909101015260010161140e565b5061072d898386612c35565b5f825f036114c7576040517f78dd5f8800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f868152601b82016020908152604080832088845282528083206001600160a01b038816845260020190915290205483111561152f576040517fe5e7340700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f868152601b820160209081526040808320888452909152812060010154611558908590614c4f565b60068301549091508110156115a1576040517ff89b912f000000000000000000000000000000000000000000000000000000008152600481018290526024015b60405180910390fd5b5f6115ae8888878961223a565b50509050838110156115ec576040517f40a0e8d200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5050505050505050565b6014545f848152601b60209081526040808320868452909152808220805460019091015491517f6199b7ff000000000000000000000000000000000000000000000000000000008152600481018690526024810191909152604481019190915260648101859052909182916001600160a01b03909116908190636199b7ff906084015b602060405180830381865afa158015611694573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906116b89190614bb0565b9695505050505050565b6060885f846116cf61276a565b6116d99190614d17565b9050815f03611714576040517f92cbb3c900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b88821415806117235750868214155b8061172e5750848214155b15611765576040517f479ca36900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8084101561179f576040517f7b0a37cf00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f8267ffffffffffffffff8111156117b9576117b9614730565b6040519080825280602002602001820160405280156117e2578160200160208202803683370190505b5090505f5b838110156118815761185c8f8f8f8481811061180557611805614be2565b905060200201358e8e8581811061181e5761181e614be2565b905060200201358d8d8681811061183757611837614be2565b905060200201358c8c8781811061185057611850614be2565b90506020020135612c60565b82828151811061186e5761186e614be2565b60209081029190910101526001016117e7565b50600b545f90611892908590614d17565b905061189d81612e49565b6118a78f876110ec565b509d9c50505050505050505050505050565b6014545f848152601b602090815260408083208684529091528082206001810154905491517f7c79f82e000000000000000000000000000000000000000000000000000000008152600481018690526024810191909152604481019190915260648101859052909182916001600160a01b03909116908190637c79f82e90608401611679565b5f816001600160a01b0316836001600160a01b0316148061075c5750600161125b565b5f61196c83612eb4565b5f61197686612ef3565b90505f81600281111561198b5761198b614c89565b14611a135761199b868689612f9d565b156119d2576040517f332c26cd00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6119dc868661302d565b15611a13576040517f9328221200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f868152601b602090815260408083208884529091528120600101546015549015908714818015611a415750805b15611a78576040517fdc2025b500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b818015611a83575080155b92505f91508190508080611aac8b8b8b848a6002811115611aa657611aa6614c89565b146121df565b9350935093509350611ac38b8b8b8787878e61308d565b611acc83613325565b611ad58b6133a9565b15611af357611af38b611aed855f5b60110154612791565b886133e3565b5f866002811115611b0657611b06614c89565b03611b1b57611b158b84613421565b50611b41565b611b248b6127a3565b15611b4157611b418b611b3c855f5b600c0154612791565b613536565b5f8515611b7f57611b568d8d8d86898c613586565b90505f876002811115611b6b57611b6b614c89565b14611b7a57611b7a8c8c613618565b611b90565b611b8d8d8d8d86898c6136a5565b90505b611b9c8c8e8488613708565b8b8d6001600160a01b03168f6001600160a01b03167ff717428d3271f4ca44ee92a96ecda708463de1c200f30db4e295def5e8db6b4a8e8e888b888f604051611bea96959493929190614d67565b60405180910390a450929c9b505050505050505050505050565b611c0d82612823565b5f5f611c17610827565b6001600160a01b0385165f90815260208481019052604090208054919250908214611c5757805415611c53576001810180546002830155815490555b8181555b5f828152601e8401602052604081208054869290611c76908490614d96565b90915550505f828152601e840160205260408082205490519091869185917f15347e028ad43baa634bf63b5062f97a54a8b497ec496dd31c9b2da27fa3640491a46001600160a01b0385165f908152601f84016020908152604080832085845290915281208054869290611ceb908490614d96565b90915550506001600160a01b0385165f818152601f8501602090815260408083208684528252918290205491519182528692859290917f62c25a075382083421af11238f1e987f397e822e4d32d143ce60ba2ff98910f6910161122d565b6015545f9081908190819081611d5d61379b565b905080871015611d99576040517f7d3287c000000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b611da38188614c4f565b94505f611db7868560110160020154612791565b90505f611dcb878660090160010154612791565b905080611dd88389614c4f565b611de29190614c4f565b9550611def8a85886115f6565b975050505050509250925092565b5f838152601760205260408120611e169083600361435e565b505f8481526018820160209081526040808320805460017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00918216811790925587855282852080549091169091179055601784019091529020611e7b9083600361435e565b505f928352601901602052506040902055565b5f816001600160a01b0316836001600160a01b0316148061075c5750600261125b565b6040805180820190915260265463ffffffff8082168084526401000000009092041660208301525f03611ee357600581525b806020015163ffffffff165f03611efd576102bc60208201525b815f5b81811015610746575f858583818110611f1b57611f1b614be2565b9050602002810190611f2d9190614dbc565b855190925063ffffffff168211159050611f73576040517fa438a68600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f5b8181101561201057846020015163ffffffff16878785818110611f9a57611f9a614be2565b9050602002810190611fac9190614dbc565b83818110611fbc57611fbc614be2565b9050602002810190611fce9190614cb6565b90501115612008576040517f12782be600000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600101611f75565b5050600101611f00565b83515f5b818110156120d85783838281811061203857612038614be2565b905060200281019061204a9190614dbc565b1590506120d057846001600160a01b031686828151811061206d5761206d614be2565b60200260200101517e6dfca493b1686f1cc639fa9675dbd6f4a694a9d3230c346f3879d9253820978686858181106120a7576120a7614be2565b90506020028101906120b99190614dbc565b6040516120c7929190614e67565b60405180910390a35b60010161201e565b505050505050565b5f5f5f6120ec87612ef3565b90506120fb87878a888861148d565b5f6121078888886118b9565b90505f5f6121178a8a8a8e61223a565b925050915061212583613325565b6121308a8a8a6137af565b1561214d5761214d8a612147855f60120154612791565b866133e3565b5f61215c8c8c8c878d8a613814565b905061216a8b8d848c61385d565b6121748c846138cb565b8a6001600160a01b03808e16908f167f5ab85658e5658520d47644e1417584159fc8edb9712149792a9337ff5e1048a48d8d86896121b2818d614c4f565b8d6040516121c596959493929190614d67565b60405180910390a450919b909a5098505050505050505050565b5f5f5f61220660405180604001604052805f6001600160a01b031681526020015f81525090565b841561222457612217888888613970565b935093509350935061222f565b612217888888613b44565b945094509450949050565b5f5f61226060405180604001604052805f6001600160a01b031681526020015f81525090565b5f5f61226d8989896118b9565b90505f612281828460110160020154612791565b90505f61228f8b8b8b6137af565b612299575f6122aa565b6122aa838560110160010154612791565b90506122b58a613c6f565b6001600160a01b03168086521561235e5784516040517fd2ffd5bf000000000000000000000000000000000000000000000000000000008152600481018d90526001600160a01b038a81166024830152604482018690529091169063d2ffd5bf90606401602060405180830381865afa158015612334573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906123589190614bb0565b60208601525b60208501515f9061236f8385614c3c565b6123799190614c3c565b90508381106123b4576040517fdfaf733300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f6123bf8286614c4f565b9d9a9c50959a50505050505050505050565b5f6001600160a01b038516612412576040517f9d3907e300000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f848152601b6020908152604080832086845282528083206001600160a01b038916845260020191829052909120548381101561247b576040517f9d398e1e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6001600160a01b03969096165f9081526020919091526040902091909403908190559392505050565b5f8181526016602052604081208054829182916124c090614f42565b9050118061075c57505f92835260180160205250604090205460ff1690565b5f8060148101546040517fa0760cad000000000000000000000000000000000000000000000000000000008152600481018890529192506001600160a01b0316905f90829063a0760cad90602401602060405180830381865afa158015612548573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061256c9190614bb0565b6040517f46d2779a000000000000000000000000000000000000000000000000000000008152600481018990529091505f906001600160a01b038416906346d2779a90602401602060405180830381865afa1580156125cd573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906125f19190614bb0565b90508187111561262d576040517fbd7fcd1e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b80861115612667576040517f4a308f9900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f898152601b8501602090815260408083208b84529091528082208981556001810189905590517f7c11d624000000000000000000000000000000000000000000000000000000008152600481018b905260248101899052604481018a90529091906001600160a01b03861690637c11d62490606401602060405180830381865afa1580156126f8573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061271c9190614bb0565b9050898b7fcc9bc63a4b047be4850fcbada8d7ed7aa097ed4f6c3b55bebc7e108ea1d2f824838c8c8c6040516127559493929190614f93565b60405180910390a35050505050505050505050565b6006545f90819061277c906002614d17565b600b82015461278b9190614c3c565b91505090565b5f61075c828260030154859190613d79565b5f8181526017602052604080822081516060810192839052839290919060039082845b8154815260200190600101908083116127c657505050505090506127ff815f600381106127f5576127f5614be2565b60200201516133a9565b801561281157506128118160016127f5565b801561075c575061075c8160026127f5565b5f5f61282d610827565b6001600160a01b0384165f908152602084810190526040902054909150811580159061286957505f82815260218401602052604090205460ff16155b156128fa575f828152602184016020908152604080832080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff001660011790556025860154808452601e87019092529091205480158015906128d857505f848152601e86016020526040902054155b156128f0575f848152601e8601602052604090208190555b5050602583018290555b8181036129075750505050565b6001600160a01b0384165f908152601f840160209081526040808320848452909152902054801580159061295d57506001600160a01b0385165f908152601f850160209081526040808320868452909152902054155b15610746576001600160a01b03949094165f908152601f939093016020908152604080852093855292905250902055565b5f828082036129c9576040517f7a291d9100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6007545f90821115612a07576040517f977c5b1100000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b612a4586868080601f0160208091040260200160405190810160405280939291908181526020018383808284375f92019190915250613da692505050565b5f8181526016830160205260409020805491945090612a6390614f42565b159050612aa05785856040517fb4856ebc000000000000000000000000000000000000000000000000000000008152600401611598929190614fb5565b5f8381526016820160205260409020612aba86888361500c565b505f838152602382016020908152604080832080547fffffffffffffffffffffffff0000000000000000000000000000000000000000166001600160a01b038c1617905560248401909152812080547fffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000164265ffffffffffff161790556015820154908080612b498789611d49565b925092509250612b5882613325565b5f612b638884613421565b90505f612b748d8a8886895f613586565b9050888d6001600160a01b03167ffd579ad7468b1720e08f84efe16900074f3ffdaaeaa82e675e5aec69bf3931898e8e86604051612bb493929190615122565b60405180910390a3888d6001600160a01b03168e6001600160a01b03167ff717428d3271f4ca44ee92a96ecda708463de1c200f30db4e295def5e8db6b4a898e888b885f604051612c0a96959493929190614d67565b60405180910390a4865f015f8154612c219061514e565b909155505050505050505050949350505050565b6009545f90612c45908490614d17565b9050612c5081612e49565b612c5a84836110ec565b50505050565b604080517f23ad11f0a1505378b82984192ad0461e6a012820fc5bf2e4ba16513f8e4305526020808301919091528183018790526060820186905260808083018690528351808403909101815260a09092019092528051910120612cc681868686613e07565b612ccf85613e64565b612cd884613e64565b612ce183613e64565b60408051606081018252868152602081018690529081018490525f612d0583613ea6565b9050612d12838284611dfd565b6015545f90818080612d24888a61101c565b925092509250612d3382613325565b5f612d438e8a8785886001613586565b9050612d4e896127a3565b15612d6857612d6889611b3c8589600b0160010154612791565b612d728986613618565b888e6001600160a01b03167ff13505b910c49b286cf7fbaf1a78620cf7d8bda0e8e39c1baed620c08af686e78f8f8f604051612dc1939291909283526020830191909152604082015260600190565b60405180910390a3888e6001600160a01b03168f6001600160a01b03167ff717428d3271f4ca44ee92a96ecda708463de1c200f30db4e295def5e8db6b4a888e878a886001604051612e1896959493929190614d67565b60405180910390a46002865f015f828254612e339190614c3c565b9091555050505050505050505095945050505050565b5f612e52610827565b5f818152601c6020526040812080549293508492909190612e74908490614c3c565b9091555050604051828152339082907fc7a5742f069dec143091f9dc7c9ca18f1212ac3f76cd16f5f8aa6f5cab9b2afc9060200160405180910390a35050565b600554811015612ef0576040517fe219a6cd00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b50565b5f5f612efe83613ee0565b5f8481526018602090815260408083205460199092529091205491925060ff1690151582158015612f2d575081155b8015612f37575080155b15612f71576040517fbdd4a69900000000000000000000000000000000000000000000000000000000815260048101869052602401611598565b8215612f8157505f949350505050565b8015612f9257506002949350505050565b506001949350505050565b5f83815260186020526040812054819060ff16612fe6576040517f5f916b8700000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f612ff086613f01565b5f908152601b9092016020908152604080842087855282528084206001600160a01b03871685526002019091529091205415159150509392505050565b5f828152601b6020908152604080832084845290915281206001015415801561306257505f8381526019602052604090205415155b801561075c57506015545f848152601b6020908152604080832093835292905220600101541561075c565b835f036130c6576040517f78dd5f8800000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b80841015613100576040517f40a0e8d200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b6014546001600160a01b03165f6131178588614c4f565b5f8a8152601b602090815260408083208c845290915290205461313b908690614c3c565b6131459190614c3c565b6040517fa0760cad000000000000000000000000000000000000000000000000000000008152600481018a90529091506001600160a01b0383169063a0760cad90602401602060405180830381865afa1580156131a4573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906131c89190614bb0565b811115613201576040517fbd7fcd1e00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b505f888152601b602090815260408083208a845290915281206001015415613229575f61322d565b6006545b5f8a8152601b602090815260408083208c8452909152902060010154613254908890614c3c565b61325e9190614c3c565b6040517f46d2779a000000000000000000000000000000000000000000000000000000008152600481018a90529091506001600160a01b038316906346d2779a90602401602060405180830381865afa1580156132bd573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906132e19190614bb0565b81111561331a576040517f4a308f9900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b505050505050505050565b5f5f613338838360110160020154612791565b90505f613343610827565b90508183601c015f8381526020019081526020015f205f8282546133679190614c3c565b9091555050604051828152339082907fc7a5742f069dec143091f9dc7c9ca18f1212ac3f76cd16f5f8aa6f5cab9b2afc9060200160405180910390a350505050565b6015545f828152601b6020908152604080832084845290915281206001015460085491928392909190811015612f9257505f949350505050565b6015545f848152601b60209081526040808320848452909152812080549192916120d89087908490613416908990614c3c565b8460010154886124df565b5f808060108101546040517f218e250d000000000000000000000000000000000000000000000000000000008152600481018790529192505f916001600160a01b039091169063218e250d90602401602060405180830381865afa15801561348b573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906134af9190614bc7565b90505f6134c3858460090160010154612791565b6001600160a01b0383165f908152601d850160205260408120805492935083929091906134f1908490614c3c565b9091555050604051818152339087907f2ef7be1e4972d779c5501d1e4658106fc78e92a99800d2f69140c78b84068e199060200160405180910390a350949350505050565b5f5f5f61354285613f34565b919450925090505f613555600386615185565b905061356a848261356587612ef3565b6133e3565b613578838261356586612ef3565b6120d8828261356585612ef3565b6006545f868152601b602090815260408083208884529091528120909182916135ec89896135b48186613ffd565b84546135c1908c90614c3c565b6135cb9190614c3c565b858a86600101546135dc9190614c3c565b6135e69190614c3c565b896124df565b5f6135f98b8b8b8a614098565b905061360961dead8b8b86614098565b509a9950505050505050505050565b5f5f61362384613f01565b5f8581526019602052604081205491925090613640576002613643565b60015b5f838152601b850160209081526040808320888452909152902060068501549192509061369784876136758185613ffd565b85546136819190614c3c565b8486600101546136919190614c3c565b876124df565b6115ec61dead858884614098565b5f858152601b6020908152604080832087845290915281205481906136fc90889088906136d3908990614c3c565b5f8b8152601b8601602090815260408083208d8452909152902060010154613691908990614c3c565b61072d88888887614098565b81516001600160a01b031615612c5a57815160208301516040517f9df965e7000000000000000000000000000000000000000000000000000000008152600481018790526001600160a01b0386811660248301526044820185905290921691639df965e791906064015b5f604051808303818588803b158015613789575f5ffd5b505af115801561331a573d5f5f3e3d5ffd5b6006546009545f91829161278b9190614c3c565b6015545f848152601b6020908152604080832084845290915281206001015490918291828287036137eb576137e48683614c4f565b90506137ee565b50805b6008840154811015613806575f94505050505061075c565b506001979650505050505050565b5f858152601b60209081526040808320878452909152812080546138519088908890613841908990614c4f565b8785600101546136919190614c4f565b61072d888888876123d1565b81516001600160a01b031615612c5a57815160208301516040517f30c276af000000000000000000000000000000000000000000000000000000008152600481018790526001600160a01b03868116602483015260448201859052909216916330c276af9190606401613772565b8047101561390e576040517fcf47918100000000000000000000000000000000000000000000000000000000815247600482015260248101829052604401611598565b5f5f836001600160a01b0316836040515f6040518083038185875af1925050503d805f8114613958576040519150601f19603f3d011682016040523d82523d5f602084013e61395d565b606091505b509150915081612c5a57612c5a81614115565b5f5f5f61399760405180604001604052805f6001600160a01b031681526020015f81525090565b5f878152601b60209081526040808320898452909152902060010154859350613a0e575f6139c55f88614156565b9050808611613a00576040517f8f7bebd500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b613a0a8185614c4f565b9350505b5f613a1e84825b60130154612791565b90505f613a2a896133a9565b613a34575f613a3e565b613a3e855f611ae4565b90505f613a4f8682600a0154612791565b90508082613a5d8589614c4f565b613a679190614c4f565b613a719190614c4f565b9450505050613a7f8661419a565b6001600160a01b031680825215613b2e5780516040517f8ef50b9600000000000000000000000000000000000000000000000000000000815260048101899052602481018590526001600160a01b0390911690638ef50b9690604401602060405180830381865afa158015613af6573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190613b1a9190614bb0565b60208201819052613b2b9083614c4f565b91505b613b39878784614271565b935093509350935093565b5f5f5f613b6b60405180604001604052805f6001600160a01b031681526020015f81525090565b849250613b78878761302d565b15613baf576040517f9328221200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f878152601b60209081526040808320898452909152902060010154613c24575f613bdb600188614156565b9050808611613c16576040517f8f7bebd500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b613c208185614c4f565b9350505b5f613c2f8482613a15565b90505f613c3b896133a9565b613c45575f613c4f565b613c4f855f611ae4565b90505f613c5b8a6127a3565b613c65575f613a4f565b613a4f865f611b33565b5f8080601401546040517f7310e80b000000000000000000000000000000000000000000000000000000008152600481018590526001600160a01b0390911690637310e80b90602401602060405180830381865afa158015613cd3573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190613cf79190614bc7565b90506001600160a01b0381161580613d6c5750806001600160a01b031663827c90866040518163ffffffff1660e01b8152600401602060405180830381865afa158015613d46573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190613d6a91906151bd565b155b1561063457505f92915050565b82820283158482048414178202613d975763ad251c275f526004601cfd5b81810615159190040192915050565b5f7fc50959b2b0264fed58f3489f13cdf8345df0911245cc2b741070787ee7aceaa28280519060200120604051602001613dea929190918252602082015260400190565b604051602081830303815290604052805190602001209050919050565b5f8481526017602052604090205415612c5a576040517f2231995900000000000000000000000000000000000000000000000000000000815260048101859052602481018490526044810183905260648101829052608401611598565b613e6d816124a4565b612ef0576040517f4762af7d00000000000000000000000000000000000000000000000000000000815260048101829052602401611598565b604080517fe7cbc1eb0e9b3f8688b0bc91a8278f7d2867f14f2a10dc3f0d9fcfdc32dada1260208201529081018290525f90606001613dea565b5f8181526016602052604081208054613ef890614f42565b15159392505050565b5f8181526019602052604081205415613f2657505f9081526019602052604090205490565b61063482613ea6565b919050565b5f81815260176020526040808220815160608101928390528392839283929160039082845b815481526020019060010190808311613f5957505050505090505f5f1b815f60038110613f8857613f88614be2565b6020020151148015613f9c57506020810151155b8015613faa57506040810151155b15613fe4576040517f08848f3b00000000000000000000000000000000000000000000000000000000815260048101869052602401611598565b8051602082015160409092015190969195509350915050565b5f80601401546040517fcdd9e573000000000000000000000000000000000000000000000000000000008152600481018490525f602482018190526044820152606481018590526001600160a01b039091169063cdd9e57390608401602060405180830381865afa158015614074573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061075c9190614bb0565b5f838152601b6020908152604080832085845282528083206001600160a01b0388168452600201909152812080548291849183906140d7908490614c3c565b90915550505f948552601b01602090815260408086209486529381528385206001600160a01b03969096168552600290950190945250902054919050565b80511561412457805160208201fd5b6040517fd6bda27500000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b5f80614166838260060154613ffd565b90505f84600281111561417b5761417b614c89565b146141905761418b816002614d17565b614192565b805b949350505050565b5f8080601401546040517f7310e80b000000000000000000000000000000000000000000000000000000008152600481018590526001600160a01b0390911690637310e80b90602401602060405180830381865afa1580156141fe573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906142229190614bc7565b90506001600160a01b0381161580613d6c5750806001600160a01b0316633c125b4d6040518163ffffffff1660e01b8152600401602060405180830381865afa158015613d46573d5f5f3e3d5ffd5b5f838152601b60209081526040808320858452909152812060010154819061435357601481015460068201546001600160a01b0390911690636199b7ff9085906142bc908890613ffd565b600685015460405160e085901b7fffffffff0000000000000000000000000000000000000000000000000000000016815260048101939093526024830191909152604482015260648101879052608401602060405180830381865afa158015614327573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061434b9190614bb0565b91505061075c565b6108078585856115f6565b826003810192821561438c579160200282015b8281111561438c578251825591602001919060010190614371565b5061439892915061439c565b5090565b5b80821115614398575f815560010161439d565b5f5f604083850312156143c1575f5ffd5b50508035926020909101359150565b6001600160a01b0381168114612ef0575f5ffd5b8035613f2f816143d0565b5f5f60408385031215614400575f5ffd5b823561440b816143d0565b946020939093013593505050565b5f60208284031215614429575f5ffd5b5035919050565b5f5f83601f840112614440575f5ffd5b50813567ffffffffffffffff811115614457575f5ffd5b6020830191508360208260051b8501011115614471575f5ffd5b9250929050565b5f5f5f5f5f5f6080878903121561448d575f5ffd5b8635614498816143d0565b9550602087013567ffffffffffffffff8111156144b3575f5ffd5b6144bf89828a01614430565b909650945050604087013567ffffffffffffffff8111156144de575f5ffd5b6144ea89828a01614430565b979a9699509497949695606090950135949350505050565b602080825282518282018190525f918401906040840190835b8181101561453957835183526020938401939092019160010161451b565b509095945050505050565b5f5f5f5f5f60a08688031215614558575f5ffd5b85359450602086013593506040860135614571816143d0565b94979396509394606081013594506080013592915050565b5f5f5f6060848603121561459b575f5ffd5b505081359360208301359350604090920135919050565b5f5f604083850312156145c3575f5ffd5b82356145ce816143d0565b915060208301356145de816143d0565b809150509250929050565b5f5f5f5f5f5f5f5f5f60a08a8c031215614601575f5ffd5b893567ffffffffffffffff811115614617575f5ffd5b6146238c828d01614430565b909a5098505060208a013567ffffffffffffffff811115614642575f5ffd5b61464e8c828d01614430565b90985096505060408a013567ffffffffffffffff81111561466d575f5ffd5b6146798c828d01614430565b90965094505060608a013567ffffffffffffffff811115614698575f5ffd5b6146a48c828d01614430565b9a9d999c50979a9699959894979660800135949350505050565b5f5f5f5f5f60a086880312156146d2575f5ffd5b85356146dd816143d0565b97602087013597506040870135966060810135965060800135945092505050565b5f5f5f60608486031215614710575f5ffd5b833561471b816143d0565b95602085013595506040909401359392505050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b5f5f5f60a0848603121561476f575f5ffd5b8335925060208401359150605f84018513614788575f5ffd5b6040516060810181811067ffffffffffffffff821117156147ab576147ab614730565b6040528060a08601878111156147bf575f5ffd5b604087015b818110156147dc5780358352602092830192016147c4565b505050809150509250925092565b5f5f5f5f5f5f5f5f5f5f60c08b8d031215614803575f5ffd5b61480c8b6143e4565b995060208b013567ffffffffffffffff811115614827575f5ffd5b6148338d828e01614430565b909a5098505060408b013567ffffffffffffffff811115614852575f5ffd5b61485e8d828e01614430565b90985096505060608b013567ffffffffffffffff81111561487d575f5ffd5b6148898d828e01614430565b90965094505060808b013567ffffffffffffffff8111156148a8575f5ffd5b6148b48d828e01614430565b9b9e9a9d50989b979a96999598949794969560a090950135949350505050565b5f5f5f5f5f5f5f5f60a0898b0312156148eb575f5ffd5b88356148f6816143d0565b9750602089013567ffffffffffffffff811115614911575f5ffd5b61491d8b828c01614430565b909850965050604089013567ffffffffffffffff81111561493c575f5ffd5b6149488b828c01614430565b909650945050606089013567ffffffffffffffff811115614967575f5ffd5b6149738b828c01614430565b999c989b50969995989497949560800135949350505050565b5f5f5f5f5f606086880312156149a0575f5ffd5b853567ffffffffffffffff8111156149b6575f5ffd5b6149c288828901614430565b909650945050602086013567ffffffffffffffff8111156149e1575f5ffd5b6149ed88828901614430565b96999598509660400135949350505050565b8015158114612ef0575f5ffd5b5f5f5f5f60808587031215614a1f575f5ffd5b8435935060208501359250604085013591506060850135614a3f816149ff565b939692955090935050565b5f5f5f5f60808587031215614a5d575f5ffd5b8435614a68816143d0565b966020860135965060408601359560600135945092505050565b5f5f5f5f5f5f5f5f5f60a08a8c031215614a9a575f5ffd5b8935614aa5816143d0565b985060208a013567ffffffffffffffff811115614ac0575f5ffd5b614acc8c828d01614430565b90995097505060408a013567ffffffffffffffff811115614aeb575f5ffd5b614af78c828d01614430565b90975095505060608a013567ffffffffffffffff811115614b16575f5ffd5b614b228c828d01614430565b90955093505060808a013567ffffffffffffffff811115614b41575f5ffd5b614b4d8c828d01614430565b915080935050809150509295985092959850929598565b5f5f5f5f5f60a08688031215614b78575f5ffd5b85359450602086013593506040860135925060608601359150608086013560038110614ba2575f5ffd5b809150509295509295909350565b5f60208284031215614bc0575f5ffd5b5051919050565b5f60208284031215614bd7575f5ffd5b8151614190816143d0565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b8082018082111561063457610634614c0f565b8181038181111561063457610634614c0f565b8082018281125f831280158216821582161715614c8157614c81614c0f565b505092915050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b5f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1843603018112614ce9575f5ffd5b83018035915067ffffffffffffffff821115614d03575f5ffd5b602001915036819003821315614471575f5ffd5b808202811582820484141761063457610634614c0f565b60038110614d63577f4e487b71000000000000000000000000000000000000000000000000000000005f52602160045260245ffd5b9052565b5f60c082019050878252866020830152856040830152846060830152836080830152610c3160a0830184614d2e565b8181035f831280158383131683831282161715614db557614db5614c0f565b5092915050565b5f5f83357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1843603018112614def575f5ffd5b83018035915067ffffffffffffffff821115614e09575f5ffd5b6020019150600581901b3603821315614471575f5ffd5b81835281816020850137505f602082840101525f60207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f840116840101905092915050565b602080825281018290525f6040600584901b8301810190830185837fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe136839003015b87821015614f35577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc08786030184528235818112614ee5575f5ffd5b890160208101903567ffffffffffffffff811115614f01575f5ffd5b803603821315614f0f575f5ffd5b614f1a878284614e20565b96505050602083019250602084019350600182019150614ea9565b5092979650505050505050565b600181811c90821680614f5657607f821691505b602082108103614f8d577f4e487b71000000000000000000000000000000000000000000000000000000005f52602260045260245ffd5b50919050565b8481526020810184905260408101839052608081016108076060830184614d2e565b602081525f610759602083018486614e20565b601f8211156108bc57805f5260205f20601f840160051c81016020851015614fed5750805b601f840160051c820191505b81811015610746575f8155600101614ff9565b67ffffffffffffffff83111561502457615024614730565b615038836150328354614f42565b83614fc8565b5f601f841160018114615088575f85156150525750838201355b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600387901b1c1916600186901b178355610746565b5f838152602081207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08716915b828110156150d557868501358255602094850194600190920191016150b5565b5086821015615110577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60f88860031b161c19848701351681555b505060018560011b0183555050505050565b604081525f615135604083018587614e20565b90506001600160a01b0383166020830152949350505050565b5f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff820361517e5761517e614c0f565b5060010190565b5f826151b8577f4e487b71000000000000000000000000000000000000000000000000000000005f52601260045260245ffd5b500490565b5f602082840312156151cd575f5ffd5b8151614190816149ff56fea164736f6c634300081d000a";
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  AtomWalletAbi,
  AtomWalletBytecode,
  AtomWalletFactoryAbi,
  AtomWalletFactoryBytecode,
  AtomWardenAbi,
  AtomWardenBytecode,
  BaseEmissionsControllerAbi,
  BaseEmissionsControllerBytecode,
  BondingCurveRegistryAbi,
  BondingCurveRegistryBytecode,
  DynamicFeeFlatPriceCurveAbi,
  DynamicFeeFlatPriceCurveBytecode,
  FeeProxyAbi,
  FeeProxyBytecode,
  LinearCurveAbi,
  LinearCurveBytecode,
  MultiVaultAbi,
  MultiVaultBytecode,
  MultiVaultLibAbi,
  MultiVaultLibBytecode,
  MultiVaultLinkReferences,
  MultiVaultMigrationModeAbi,
  MultiVaultMigrationModeBytecode,
  MultiVaultMigrationModeLinkReferences,
  OffsetProgressiveCurveAbi,
  OffsetProgressiveCurveBytecode,
  SatelliteEmissionsControllerAbi,
  SatelliteEmissionsControllerBytecode,
  TrustAbi,
  TrustBondingAbi,
  TrustBondingBytecode,
  TrustBytecode,
  TrustTokenAbi,
  TrustTokenBytecode,
  WrappedTrustAbi,
  WrappedTrustBytecode
});
