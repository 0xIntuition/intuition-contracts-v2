// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script } from "forge-std/src/Script.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ERC20Mock } from "tests/mocks/ERC20Mock.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { GovernanceWrapper } from "src/protocol/governance/GovernanceWrapper.sol";
import { IGovernanceWrapper } from "src/interfaces/IGovernanceWrapper.sol";
import { IVotesERC20V1 } from "src/external/decent/VotesERC20V1.sol";

/*
ETH SEPOLIA
forge script script/intuition/DeployGovernanceSetupToSepolia.s.sol:DeployGovernanceSetupToSepolia \
  --optimizer-runs 10000 \
  --rpc-url sepolia \
  --broadcast \
  --slow \
  --verify \
  --chain 11155111 \
  --verifier etherscan \
  --verifier-url "https://api.etherscan.io/v2/api?chainid=11155111"
*/

contract DeployGovernanceSetupToSepolia is Script {
    // The address of a contract deployer
    address public broadcaster;

    // Admin address for the deployed contracts
    address public ADMIN;

    // Core contracts
    ERC20Mock public mockTrustToken;

    TrustBonding public trustBondingImplementation;
    TransparentUpgradeableProxy public trustBondingProxy;
    ITrustBonding public trustBondingContract;

    GovernanceWrapper public governanceWrapperImplementation;
    ERC1967Proxy public governanceWrapperProxy;
    GovernanceWrapper public governanceWrapper;

    // Constants for TrustBonding initializer
    uint256 public constant EPOCH_LENGTH = 14 days;
    uint256 public constant SYSTEM_UTILIZATION_LOWER_BOUND = 4000;
    uint256 public constant PERSONAL_UTILIZATION_LOWER_BOUND = 2500;

    function setUp() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_TESTNET");
        broadcaster = vm.rememberKey(deployerKey);
        ADMIN = broadcaster;

        if (block.chainid != 11_155_111) {
            revert("This deployment script is intended for ETH Sepolia (11155111) only");
        }

        console2.log("NETWORK: =+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+");
        info("ChainID:", block.chainid);
        info("Broadcasting:", broadcaster);
    }

    function run() external {
        vm.startBroadcast(broadcaster);
        _deployMockTrustToken();
        _deployTrustBonding();
        _configureTrustBonding();
        _deployGovernanceWrapper();
        _mintAndCreateLock();
        vm.stopBroadcast();

        console2.log("");
        console2.log("DEPLOYMENTS (Sepolia 11155111):");
        console2.log("------------------------------------------");
        console2.log("Mock TRUST Token (ERC20Mock):   ", address(mockTrustToken));
        console2.log("TrustBonding Implementation:    ", address(trustBondingImplementation));
        console2.log("TrustBonding Proxy:             ", address(trustBondingProxy));
        console2.log("GovernanceWrapper Implementation:", address(governanceWrapperImplementation));
        console2.log("GovernanceWrapper Proxy:        ", address(governanceWrapperProxy));
        console2.log("------------------------------------------");
    }

    function _deployMockTrustToken() internal {
        mockTrustToken = new ERC20Mock("Mock TRUST", "mTRUST", 18);
        info("Mock TRUST Token (ERC20Mock)", address(mockTrustToken));
    }

    function _deployTrustBonding() internal {
        // 1. Deploy implementation
        trustBondingImplementation = new TrustBonding();

        // 2. Prepare initializer calldata
        bytes memory initData = abi.encodeWithSelector(
            ITrustBonding.initialize.selector,
            ADMIN, // _owner
            ADMIN, // _timelock
            address(mockTrustToken), // _trustToken
            EPOCH_LENGTH, // _epochLength (14 days)
            ADMIN, // _satelliteEmissionsController (set to deployer for testing)
            SYSTEM_UTILIZATION_LOWER_BOUND, // _systemUtilizationLowerBound (4000 bps)
            PERSONAL_UTILIZATION_LOWER_BOUND // _personalUtilizationLowerBound (2500 bps)
        );

        // 3. Deploy proxy with deployer as proxy admin owner
        trustBondingProxy = new TransparentUpgradeableProxy(address(trustBondingImplementation), ADMIN, initData);

        trustBondingContract = ITrustBonding(address(trustBondingProxy));

        info("TrustBonding Implementation", address(trustBondingImplementation));
        info("TrustBonding Proxy", address(trustBondingProxy));
    }

    function _configureTrustBonding() internal {
        // Set MultiVault to deployer for testing purposes
        trustBondingContract.setMultiVault(ADMIN);
        info("TrustBonding.multiVault set to", ADMIN);
    }

    function _deployGovernanceWrapper() internal {
        // 1. Deploy implementation
        governanceWrapperImplementation = new GovernanceWrapper();

        // 2. Prepare initializer calldata
        IVotesERC20V1.Metadata memory metadata = IVotesERC20V1.Metadata({name: "veTRUST Votes", symbol: "veTRUST"});
        IVotesERC20V1.Allocation[] memory allocations; // length 0
        bytes memory initData = abi.encodeWithSelector(
            IVotesERC20V1.initialize.selector,
            metadata, // _metadata
            allocations, // _allocations
            ADMIN, // _owner
            true, // _locked
            type(uint256).max // _maxTotalSupply
        );

        // 3. Deploy proxy with deployer as proxy admin owner
        governanceWrapperProxy =
            new ERC1967Proxy(address(governanceWrapperImplementation), initData);

        governanceWrapper = GovernanceWrapper(address(governanceWrapperProxy));

        info("GovernanceWrapper Implementation", address(governanceWrapperImplementation));
        info("GovernanceWrapper Proxy", address(governanceWrapperProxy));

        // 4. Renounce minting rights
        governanceWrapper.renounceMinting();

        // 5. Set TrustBonding address in GovernanceWrapper
        governanceWrapper.setTrustBonding(address(trustBondingContract));
    }

    function _mintAndCreateLock() internal {
        // Mint some mock TRUST to ADMIN for testing
        uint256 mintAmount = 1_000_000 * 10 ** 18;
        mockTrustToken.mint(ADMIN, mintAmount);

        // Approve TrustBonding to spend ADMIN's mock TRUST
        mockTrustToken.approve(address(trustBondingContract), mintAmount);

        // Create a lock for ADMIN
        uint256 lockAmount = 1000 * 10 ** 18;
        uint256 lockDuration = block.timestamp + 365 days;
        TrustBonding(address(trustBondingContract)).create_lock(lockAmount, lockDuration);

        info("Created test lock for ADMIN with amount", lockAmount);
        info("veTRUST balance of ADMIN", TrustBonding(address(trustBondingContract)).balanceOf(ADMIN));
    }

    function info(string memory label, address addr) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.log(addr);
        console2.log("-------------------------------------------------------------------");
    }

    function info(string memory label, uint256 data) internal pure {
        console2.log("");
        console2.log(label);
        console2.log("-------------------------------------------------------------------");
        console2.log(data);
        console2.log("-------------------------------------------------------------------");
    }
}
