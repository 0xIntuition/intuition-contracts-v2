export const AtomWardenAbi = [
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
] as const;
