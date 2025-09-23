// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";
import { IAtomWallet } from "src/interfaces/IAtomWallet.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

contract MockAtomWallet {
    address public owner;

    function transferOwnership(address newOwner) external {
        owner = newOwner;
    }
}

contract AtomWardenTest is BaseTest {
    AtomWarden public atomWarden;
    address public atomWardenImplementation;
    TransparentUpgradeableProxy public atomWardenProxy;

    address public constant UNAUTHORIZED_USER = address(0x9999);
    address public constant NEW_OWNER = address(0x1111);
    address public constant MOCK_MULTIVAULT = address(0x2222);
    address public constant INVALID_ADDRESS = address(0);

    bytes32 public constant TEST_ATOM_ID = keccak256(abi.encodePacked("test_atom"));
    bytes32 public constant INVALID_ATOM_ID = keccak256(abi.encodePacked("invalid_atom"));
    bytes public constant TEST_ATOM_DATA = bytes("0x1234567890abcdef1234567890abcdef12345678");

    function setUp() public override {
        super.setUp();

        atomWardenImplementation = address(new AtomWarden());
        atomWardenProxy = new TransparentUpgradeableProxy(atomWardenImplementation, users.admin, "");
        atomWarden = AtomWarden(address(atomWardenProxy));

        atomWarden.initialize(users.admin, address(protocol.multiVault));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_successful() external {
        AtomWarden freshWarden = new AtomWarden();
        TransparentUpgradeableProxy freshProxy = new TransparentUpgradeableProxy(address(freshWarden), users.admin, "");
        freshWarden = AtomWarden(address(freshProxy));

        vm.expectEmit(true, true, true, true);
        emit IAtomWarden.MultiVaultSet(address(protocol.multiVault));

        freshWarden.initialize(users.alice, address(protocol.multiVault));

        assertEq(freshWarden.owner(), users.alice);
        assertEq(address(freshWarden.multiVault()), address(protocol.multiVault));
    }

    function test_initialize_revertsOnZeroAdmin() external {
        AtomWarden freshWarden = new AtomWarden();
        TransparentUpgradeableProxy freshProxy = new TransparentUpgradeableProxy(address(freshWarden), users.admin, "");
        freshWarden = AtomWarden(address(freshProxy));

        vm.expectRevert();
        freshWarden.initialize(INVALID_ADDRESS, address(protocol.multiVault));
    }

    function test_initialize_revertsOnZeroMultiVault() external {
        AtomWarden freshWarden = new AtomWarden();
        TransparentUpgradeableProxy freshProxy = new TransparentUpgradeableProxy(address(freshWarden), users.admin, "");
        freshWarden = AtomWarden(address(freshProxy));

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidAddress.selector));
        freshWarden.initialize(users.alice, INVALID_ADDRESS);
    }

    function test_initialize_revertsOnDoubleInitialization() external {
        vm.expectRevert();
        atomWarden.initialize(users.alice, address(protocol.multiVault));
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM OWNERSHIP OVER ADDRESS ATOM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimOwnershipOverAddressAtom_successful() external {
        bytes32 atomId = _createAddressAtom(users.alice);
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.expectEmit(true, true, true, true);
        emit IAtomWarden.AtomWalletOwnershipClaimed(atomId, users.alice);

        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), users.alice);
    }

    function test_claimOwnershipOverAddressAtom_revertsOnNonExistentAtom() external {
        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.isAtom.selector, INVALID_ATOM_ID),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AtomIdDoesNotExist.selector));

        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(INVALID_ATOM_ID);
    }

    function test_claimOwnershipOverAddressAtom_revertsOnMismatchedAddress() external {
        bytes32 atomId = _createAddressAtom(users.bob);

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_ClaimOwnershipFailed.selector));

        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(atomId);
    }

    function test_claimOwnershipOverAddressAtom_revertsOnUndeployedWallet() external {
        bytes32 atomId = _createAddressAtom(users.alice);
        address nonExistentWallet = address(0x1234);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(nonExistentWallet)
        );

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AtomWalletNotDeployed.selector));

        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(atomId);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN CLAIM OWNERSHIP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimOwnership_successful() external {
        bytes32 atomId = _createValidAtom();
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.expectEmit(true, true, true, true);
        emit IAtomWarden.AtomWalletOwnershipClaimed(atomId, NEW_OWNER);

        vm.prank(users.admin);
        atomWarden.claimOwnership(atomId, NEW_OWNER);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), NEW_OWNER);
    }

    function test_claimOwnership_revertsOnZeroNewOwner() external {
        bytes32 atomId = _createValidAtom();

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidNewOwnerAddress.selector));

        vm.prank(users.admin);
        atomWarden.claimOwnership(atomId, INVALID_ADDRESS);
    }

    function test_claimOwnership_revertsOnNonExistentAtom() external {
        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.isAtom.selector, INVALID_ATOM_ID),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AtomIdDoesNotExist.selector));

        vm.prank(users.admin);
        atomWarden.claimOwnership(INVALID_ATOM_ID, NEW_OWNER);
    }

    function test_claimOwnership_revertsOnUndeployedWallet() external {
        bytes32 atomId = _createValidAtom();
        address nonExistentWallet = address(0x1234);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(nonExistentWallet)
        );

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_AtomWalletNotDeployed.selector));

        vm.prank(users.admin);
        atomWarden.claimOwnership(atomId, NEW_OWNER);
    }

    function test_claimOwnership_revertsOnUnauthorizedUser() external {
        bytes32 atomId = _createValidAtom();

        vm.expectRevert();

        vm.prank(UNAUTHORIZED_USER);
        atomWarden.claimOwnership(atomId, NEW_OWNER);
    }

    /*//////////////////////////////////////////////////////////////
                            SET MULTIVAULT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setMultiVault_successful() external {
        vm.expectEmit(true, true, true, true);
        emit IAtomWarden.MultiVaultSet(MOCK_MULTIVAULT);

        vm.prank(users.admin);
        atomWarden.setMultiVault(MOCK_MULTIVAULT);

        assertEq(address(atomWarden.multiVault()), MOCK_MULTIVAULT);
    }

    function test_setMultiVault_revertsOnZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_InvalidAddress.selector));

        vm.prank(users.admin);
        atomWarden.setMultiVault(INVALID_ADDRESS);
    }

    function test_setMultiVault_revertsOnUnauthorizedUser() external {
        vm.expectRevert();

        vm.prank(UNAUTHORIZED_USER);
        atomWarden.setMultiVault(MOCK_MULTIVAULT);
    }

    /*//////////////////////////////////////////////////////////////
                            LOWERCASE ADDRESS CONVERSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_toLowerCaseAddress_correctConversion() external {
        address randomAddress = makeAddr("randomAddress");
        bytes32 atomId = _createAddressAtom(randomAddress);
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.atom.selector, atomId),
            abi.encode(bytes(abi.encodePacked(_toLowerCaseAddress(randomAddress))))
        );

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(randomAddress);
        atomWarden.claimOwnershipOverAddressAtom(atomId);
    }

    function test_toLowerCaseAddress_zeroAddress() external {
        bytes32 atomId = _createAddressAtom(address(0));
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(address(0));
        atomWarden.claimOwnershipOverAddressAtom(atomId);
    }

    function test_toLowerCaseAddress_maxAddress() external {
        address maxAddr = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        bytes32 atomId = _createAddressAtom(maxAddr);
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(maxAddr);
        atomWarden.claimOwnershipOverAddressAtom(atomId);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_claimOwnershipOverAddressAtom_validAddress(address addr) external {
        vm.assume(addr != address(0));

        bytes32 atomId = _createAddressAtom(addr);
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(addr);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), addr);
    }

    function testFuzz_claimOwnership_validParameters(bytes32 atomId, address newOwner) external {
        vm.assume(newOwner != address(0));
        vm.assume(atomId != bytes32(0));

        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault), abi.encodeWithSelector(IMultiVault.isAtom.selector, atomId), abi.encode(true)
        );

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(users.admin);
        atomWarden.claimOwnership(atomId, newOwner);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), newOwner);
    }

    function testFuzz_setMultiVault_validAddress(address multiVaultAddr) external {
        vm.assume(multiVaultAddr != address(0));

        vm.prank(users.admin);
        atomWarden.setMultiVault(multiVaultAddr);

        assertEq(address(atomWarden.multiVault()), multiVaultAddr);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_integration_fullOwnershipClaimFlow() external {
        bytes32 atomId = _createAddressAtom(users.alice);
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), users.alice);
    }

    function test_integration_adminClaimAfterFailedUserClaim() external {
        bytes32 atomId = _createAddressAtom(users.bob);
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.expectRevert(abi.encodeWithSelector(IAtomWarden.AtomWarden_ClaimOwnershipFailed.selector));
        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        vm.prank(users.admin);
        atomWarden.claimOwnership(atomId, users.alice);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), users.alice);
    }

    function test_integration_multiVaultUpdateAndClaim() external {
        vm.prank(users.admin);
        atomWarden.setMultiVault(MOCK_MULTIVAULT);

        bytes32 atomId = _createAddressAtom(users.alice);
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(MOCK_MULTIVAULT, abi.encodeWithSelector(IMultiVault.isAtom.selector, atomId), abi.encode(true));

        vm.mockCall(
            MOCK_MULTIVAULT,
            abi.encodeWithSelector(IMultiVault.atom.selector, atomId),
            abi.encode(_toLowerCaseAddress(users.alice))
        );

        vm.mockCall(
            MOCK_MULTIVAULT,
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), users.alice);
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_edge_multipleAdminClaims() external {
        bytes32 atomId = _createValidAtom();
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(users.admin);
        atomWarden.claimOwnership(atomId, users.alice);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), users.alice);

        vm.prank(users.admin);
        atomWarden.claimOwnership(atomId, users.bob);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), users.bob);
    }

    function test_edge_claimOwnershipWithSameAddressMultipleTimes() external {
        bytes32 atomId = _createAddressAtom(users.alice);
        address atomWalletAddress = _deployMockAtomWallet(atomId);

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.computeAtomWalletAddr.selector, atomId),
            abi.encode(atomWalletAddress)
        );

        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        vm.prank(users.alice);
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        assertEq(MockAtomWallet(atomWalletAddress).owner(), users.alice);
    }

    function test_edge_multiVaultUpdateMultipleTimes() external {
        address firstMultiVault = address(0x1111);
        address secondMultiVault = address(0x2222);

        vm.prank(users.admin);
        atomWarden.setMultiVault(firstMultiVault);
        assertEq(address(atomWarden.multiVault()), firstMultiVault);

        vm.prank(users.admin);
        atomWarden.setMultiVault(secondMultiVault);
        assertEq(address(atomWarden.multiVault()), secondMultiVault);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createAddressAtom(address addr) internal returns (bytes32) {
        bytes memory atomData = abi.encodePacked(_toLowerCaseAddress(addr));
        bytes32 atomId = keccak256(abi.encodePacked(atomData));

        vm.mockCall(
            address(protocol.multiVault), abi.encodeWithSelector(IMultiVault.isAtom.selector, atomId), abi.encode(true)
        );

        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(IMultiVault.atom.selector, atomId),
            abi.encode(atomData)
        );

        return atomId;
    }

    function _createValidAtom() internal returns (bytes32) {
        bytes32 atomId = TEST_ATOM_ID;

        vm.mockCall(
            address(protocol.multiVault), abi.encodeWithSelector(IMultiVault.isAtom.selector, atomId), abi.encode(true)
        );

        return atomId;
    }

    function _deployMockAtomWallet(bytes32 atomId) internal returns (address) {
        MockAtomWallet mockWallet = new MockAtomWallet();
        address walletAddress = address(mockWallet);

        vm.etch(walletAddress, address(mockWallet).code);

        return walletAddress;
    }

    function _toLowerCaseAddress(address _address) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes20 addrBytes = bytes20(_address);
        bytes memory str = new bytes(42);

        str[0] = "0";
        str[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(addrBytes[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(addrBytes[i] & 0x0f)];
        }

        return string(str);
    }
}
