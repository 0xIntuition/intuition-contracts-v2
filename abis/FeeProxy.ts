export const FeeProxyAbi = [
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
] as const;
