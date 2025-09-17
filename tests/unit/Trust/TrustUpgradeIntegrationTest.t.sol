// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelinV4/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelinV4/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Trust } from "src/Trust.sol";

contract TrustUpgradeIntegrationTest is Test {
    // Role identifiers
    bytes32 DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    // Base chain addresses (legacy TRUST token deployment & ProxyAdmin)
    address constant TRUST_PROXY = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
    address constant PROXY_ADMIN = 0x857552ab95E6cC389b977d5fEf971DEde8683e8e;

    Trust public trust; // proxied Trust (after upgrade)

    address public newAdmin = address(0xA11CE);
    address public newController = address(0xB0B);
    address public recipient = address(0xCAFE);

    function setUp() external {
        // Fork Base
        vm.createSelectFork("base");

        // Read existing proxy admin and proxy
        ProxyAdmin proxyAdmin = ProxyAdmin(PROXY_ADMIN);
        address proxyAdminOwner = proxyAdmin.owner();

        // Snapshot legacy totalSupply before upgrade (should persist after)
        uint256 supplyBefore = IERC20(TRUST_PROXY).totalSupply();

        // Deploy new Trust implementation
        Trust newImpl = new Trust();

        // Fund admin & initial admin (pranked EOAs) to perform upgrade & reinit
        vm.deal(proxyAdminOwner, 10 ether);

        // Upgrade proxy to new implementation
        vm.prank(proxyAdminOwner);
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(TRUST_PROXY), address(newImpl));

        // Point typed interface to proxy
        trust = Trust(TRUST_PROXY);

        // Reinitialize the upgraded Trust token contract
        address initialAdmin = trust.INITIAL_ADMIN();
        vm.deal(initialAdmin, 10 ether);
        vm.prank(initialAdmin);
        trust.reinitialize(newAdmin, newController);

        // Basic post-upgrade checks
        assertEq(trust.name(), "Intuition", "name override should apply post-upgrade");
        assertEq(trust.symbol(), "TRUST", "symbol should remain TRUST");
        assertTrue(trust.hasRole(DEFAULT_ADMIN_ROLE, newAdmin), "new admin should have DEFAULT_ADMIN_ROLE");
        assertTrue(trust.hasRole(CONTROLLER_ROLE, newController), "new controller should have CONTROLLER_ROLE");

        // totalSupply continuity across upgrade
        assertEq(trust.totalSupply(), supplyBefore, "totalSupply must persist across upgrade");
    }

    function test_PostUpgrade_Minting_Works_WithControllerRole() external {
        uint256 balanceBefore = trust.balanceOf(recipient);
        uint256 supplyBefore = trust.totalSupply();

        // Controller can mint
        vm.prank(newController);
        trust.mint(recipient, 1e18);

        assertEq(trust.balanceOf(recipient), balanceBefore + 1e18);
        assertEq(trust.totalSupply(), supplyBefore + 1e18);
    }

    function test_PostUpgrade_Burning_Works_WithControllerRole() external {
        // Pre-mint to recipient so we can burn
        vm.prank(newController);
        trust.mint(recipient, 2e18);

        uint256 balanceBefore = trust.balanceOf(recipient);
        uint256 supplyBefore = trust.totalSupply();

        // Controller can burn
        vm.prank(newController);
        trust.burn(recipient, 1e18);

        assertEq(trust.balanceOf(recipient), balanceBefore - 1e18);
        assertEq(trust.totalSupply(), supplyBefore - 1e18);
    }

    function test_PostUpgrade_Minting_Reverts_WithoutControllerRole() external {
        // Non-controller attempt
        address rando = address(0xDEAD);
        bytes memory expected = abi.encodeWithSignature(
            "Error(string)",
            string.concat("AccessControl: account ", _addr(rando), " is missing role ", _roleHex(CONTROLLER_ROLE))
        );

        vm.prank(rando);
        vm.expectRevert(expected);
        trust.mint(address(0xFEED), 1);
    }

    /* ----------------------------- helpers ----------------------------- */

    function _addr(address a) internal pure returns (string memory) {
        // 20-byte 0x-prefixed address, to match OZ's revert format
        return _hex(uint160(a), 20);
    }

    function _roleHex(bytes32 r) internal pure returns (string memory) {
        // 32-byte 0x-prefixed role id, to match OZ's revert format
        return _hex(uint256(r), 32);
    }

    function _hex(uint256 x, uint256 len) internal pure returns (string memory) {
        bytes16 HEX = 0x30313233343536373839616263646566; // 0..f
        bytes memory s = new bytes(2 + 2 * len);
        s[0] = "0";
        s[1] = "x";
        for (uint256 i = 0; i < len; i++) {
            uint256 shift = (len - 1 - i) * 8;
            uint8 b = uint8(x >> shift);
            s[2 + 2 * i] = HEX[b >> 4];
            s[3 + 2 * i] = HEX[b & 0x0f];
        }
        return string(s);
    }
}
