// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SetupScript } from "script/SetupScript.s.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";

import { ERC20Mock } from "tests/mocks/ERC20Mock.sol";

/*
ETH SEPOLIA TESTNET
forge script script/intuition/governance/CreateLock.s.sol:CreateLock \
--optimizer-runs 10000 \
--rpc-url sepolia \
--broadcast \
--slow \
--verify \
--chain 11155111 \
--verifier etherscan \
--verifier-url "https://api.etherscan.io/v2/api?chainid=11155111"

INTUITION MAINNET
forge script script/intuition/governance/CreateLock.s.sol:CreateLock \
--optimizer-runs 10000 \
--rpc-url intuition \
--broadcast \
--slow \
--verify \
--chain 1155 \
--verifier blockscout \
--verifier-url 'https://intuition.calderaexplorer.xyz/api/'
*/

contract CreateLock is SetupScript {
    address public TRUST_BONDING_ADDRESS;
    uint256 public lockAmount;
    uint256 public lockDuration;

    function setUp() public override {
        super.setUp();

        if (block.chainid == NETWORK_ETHEREUM_SEPOLIA) {
            TRUST_BONDING_ADDRESS = 0x3B4f5D3CEc8702Fb99a5913A6EC0310cC8D8Da7e;
            lockAmount = 1000 * 10 ** 18;
            lockDuration = block.timestamp + 365 days;
        } else if (block.chainid == NETWORK_INTUITION) {
            TRUST_BONDING_ADDRESS = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;
            lockAmount = 1 * 10 ** 18;
            lockDuration = block.timestamp + 365 days;
        } else {
            revert("Unsupported chain for CreateLock script");
        }

        if (TRUST_BONDING_ADDRESS == address(0)) {
            revert("TRUST_BONDING_ADDRESS not set for this network");
        }
    }

    function run() public broadcast {
        _createLock();
        console2.log("");
        console2.log("LOCK CREATED: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        console2.log("Account:", broadcaster);
        console2.log("Lock Amount:", lockAmount);
        console2.log("Lock Duration (timestamp):", lockDuration);
        console2.log("veTRUST Balance:", TrustBonding(TRUST_BONDING_ADDRESS).balanceOf(broadcaster));
    }

    function _createLock() internal {
        TrustBonding trustBondingContract = TrustBonding(TRUST_BONDING_ADDRESS);

        // if user has any bonded balance, we skip creating a new lock
        uint256 existingLockedBalance = trustBondingContract.balanceOf(broadcaster);
        if (existingLockedBalance > 0) {
            console2.log("Existing veTRUST balance detected:", existingLockedBalance);
            console2.log("Skipping lock creation.");
            return;
        }

        address wrappedTrustAddress = trustBondingContract.token();
        IERC20 trustToken = IERC20(wrappedTrustAddress);

        uint256 balance = trustToken.balanceOf(broadcaster);
        if (balance < lockAmount) {
            if (block.chainid == NETWORK_INTUITION) {
                revert("Insufficient WTRUST token balance. Please acquire WTRUST on Intuition mainnet.");
            } else if (block.chainid == NETWORK_ETHEREUM_SEPOLIA) {
                ERC20Mock(address(trustToken)).mint(broadcaster, lockAmount);
                console2.log("Minted", lockAmount, "mTRUST to", broadcaster);
            }
        }

        trustToken.approve(address(trustBondingContract), lockAmount);
        console2.log("Approved TrustBonding to spend", lockAmount);

        trustBondingContract.create_lock(lockAmount, lockDuration);
        console2.log("Created lock for", broadcaster);
    }
}
