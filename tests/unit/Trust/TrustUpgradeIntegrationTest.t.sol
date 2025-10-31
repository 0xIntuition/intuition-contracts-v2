// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelinV4/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelinV4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ITrust } from "src/interfaces/ITrust.sol";
import { Trust } from "src/Trust.sol";

contract TrustUpgradeIntegrationTest is Test {
    // Role identifiers
    bytes32 DEFAULT_ADMIN_ROLE = 0x00;

    // Base chain addresses (TRUST proxy address & ProxyAdmin)
    address public constant TRUST_PROXY = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
    address public constant PROXY_ADMIN = 0x857552ab95E6cC389b977d5fEf971DEde8683e8e;

    // Trust proxy instance
    Trust public trust;

    // New admin & controller addresses to be set during upgrade
    address public newAdmin = 0xBc01aB3839bE8933f6B93163d129a823684f4CDF;
    address public newController = 0x000000000000000000000000000000000000dEaD;
    address public recipient = address(0xCAFE);

    //  Block number at the time of the Trust implementation upgrade on Base mainnet
    uint256 public constant UPGRADE_BLOCK = 37_484_415;

    // Snapshot of totalSupply before the upgrade
    uint256 public supplyBefore;

    function setUp() external {
        // Fork Base just before the upgrade so that reinitialization can be tested
        vm.createSelectFork("base", UPGRADE_BLOCK - 1);

        // Read existing proxy admin and proxy
        ProxyAdmin proxyAdmin = ProxyAdmin(PROXY_ADMIN);
        address proxyAdminOwner = proxyAdmin.owner();

        // Snapshot legacy totalSupply before upgrade
        supplyBefore = IERC20(TRUST_PROXY).totalSupply();

        // Deploy new Trust implementation
        Trust newImpl = new Trust();

        // Prepare upgrade calldata to call reinitialize(_initialAdmin, _baseEmissionsController)
        bytes memory upgradeCalldata =
            hex"a9d951a3000000000000000000000000bc01ab3839be8933f6b93163d129a823684f4cdf000000000000000000000000000000000000000000000000000000000000dead";

        // Upgrade proxy to new implementation and call reinitialize
        vm.prank(proxyAdminOwner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(TRUST_PROXY), address(newImpl), upgradeCalldata);

        // Point typed interface to proxy
        trust = Trust(TRUST_PROXY);
    }

    function test_VerifyStateIntegrityPostUpgrade() external view {
        // Basic post-upgrade checks
        assertEq(trust.name(), "Intuition", "name override should apply post-upgrade");
        assertEq(trust.symbol(), "TRUST", "symbol should remain TRUST");
        assertTrue(trust.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), "new admin should have DEFAULT_ADMIN_ROLE");
        assertEq(trust.baseEmissionsController(), newController, "baseEmissionsController should be set");

        // totalSupply continuity across upgrade
        assertEq(trust.totalSupply(), supplyBefore, "totalSupply must persist across upgrade");
    }

    function test_ReinitializeShouldRevert_WhenCalledAgain() external {
        vm.expectRevert("Initializable: contract is already initialized");
        trust.reinitialize(newAdmin, newController);
    }

    function test_PostUpgrade_Minting_Works_OnlyWhenCalledByBaseEmissionsController() external {
        uint256 balanceBefore = trust.balanceOf(recipient);
        uint256 totalSupplyBefore = trust.totalSupply();

        // Controller can mint
        vm.prank(newController);
        trust.mint(recipient, 1e18);

        assertEq(trust.balanceOf(recipient), balanceBefore + 1e18);
        assertEq(trust.totalSupply(), totalSupplyBefore + 1e18);
    }

    function test_PostUpgrade_Minting_Reverts_WhenNotCalledByBaseEmissionsController() external {
        // Non-controller attempt
        address rando = address(0x1234);

        vm.prank(rando);
        vm.expectRevert(ITrust.Trust_OnlyBaseEmissionsController.selector);
        trust.mint(address(0xFEED), 1);
    }

    function test_SelfBurnSucceeds() external {
        address burner = address(0xABCD);

        // Mint some tokens to burner
        vm.prank(newController);
        trust.mint(burner, 100e18);

        uint256 balanceBefore = trust.balanceOf(burner);
        uint256 totalSupplyBefore = trust.totalSupply();

        // Burner burns their own tokens
        vm.prank(burner);
        trust.burn(40e18);

        assertEq(trust.balanceOf(burner), balanceBefore - 40e18);
        assertEq(trust.totalSupply(), totalSupplyBefore - 40e18);
    }

    function test_SetBaseEmissionsController_shouldSucceedIfCalledByAdmin() external {
        address anotherController = address(0xBEEF);

        vm.prank(newAdmin);
        trust.setBaseEmissionsController(anotherController);

        assertEq(trust.baseEmissionsController(), anotherController);
    }

    function test_SetBaseEmissionsController_shouldRevertIfNotCalledByAdmin() external {
        address rando = address(0x5678);
        address anotherController = address(0xBEEF);

        vm.prank(rando);
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000005678 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        trust.setBaseEmissionsController(anotherController);
    }
}
