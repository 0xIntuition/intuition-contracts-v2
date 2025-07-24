// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import {AtomWallet} from "src/AtomWallet.sol";
import {Errors} from "src/libraries/Errors.sol";
import {MultiVault} from "src/MultiVault.sol";
import {MultiVaultBase} from "test/MultiVaultBase.sol";

contract AtomWardenTest is MultiVaultBase {
    function setUp() public override {
        super.setUp();
    }

    function testSetMultiVault() external {
        vm.startPrank(admin);

        MultiVault newMultiVault = new MultiVault();

        atomWarden.setMultiVault(address(newMultiVault));

        assertEq(address(atomWarden.multiVault()), address(newMultiVault));

        vm.stopPrank();
    }

    function testSetInvalidMultiVault() external {
        vm.startPrank(admin);

        MultiVault newMultiVault = MultiVault(address(0));

        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_InvalidMultiVaultAddress.selector));
        atomWarden.setMultiVault(address(newMultiVault));

        vm.stopPrank();
    }

    function testClaimOwnershipOverAddressAtom() external {
        vm.startPrank(alice);

        uint256 atomCost = multiVault.getAtomCost();

        string memory atomUriString = _toLowerCaseAddress(address(alice));

        bytes32 atomId = multiVault.createAtom(abi.encodePacked(atomUriString), atomCost);

        atomWalletFactory.deployAtomWallet(atomId);

        atomWarden.claimOwnershipOverAddressAtom(atomId);

        address payable atomWalletAddress = payable(multiVault.computeAtomWalletAddr(atomId));
        address pendingOwner = AtomWallet(atomWalletAddress).pendingOwner();

        assertEq(pendingOwner, address(alice));

        AtomWallet(atomWalletAddress).acceptOwnership();

        address owner = AtomWallet(atomWalletAddress).owner();

        assertEq(owner, address(alice));

        vm.stopPrank();
    }

    function testClaimOwnershipOverAddressAtomWalletNotDeployed() external {
        vm.startPrank(alice);

        uint256 atomCost = multiVault.getAtomCost();
        string memory atomUriString = _toLowerCaseAddress(address(alice));

        bytes32 atomId = multiVault.createAtom(abi.encodePacked(atomUriString), atomCost);

        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_AtomWalletNotDeployed.selector));
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        vm.stopPrank();
    }

    function testClaimOwnershipOverAddressAtomFailsWithMismatchedHash() external {
        vm.startPrank(alice);

        uint256 atomCost = multiVault.getAtomCost();

        string memory atomUriString = _toLowerCaseAddress(address(bob));

        bytes32 atomId = multiVault.createAtom(abi.encodePacked(atomUriString), atomCost);

        atomWalletFactory.deployAtomWallet(atomId);

        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_ClaimOwnershipFailed.selector));
        atomWarden.claimOwnershipOverAddressAtom(atomId);

        vm.stopPrank();
    }

    function testClaimOwnershipOverAddressAtomAtomIdZero() external {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_AtomIdDoesNotExist.selector));
        atomWarden.claimOwnershipOverAddressAtom(bytes32(0));

        vm.stopPrank();
    }

    function testClaimOwnershipOverAddressAtomAtomIdDoesNotExist() external {
        vm.startPrank(alice);

        bytes32 fakeAtomId = keccak256(abi.encodePacked("fakeAtomId"));

        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_AtomIdDoesNotExist.selector));
        atomWarden.claimOwnershipOverAddressAtom(fakeAtomId);

        vm.stopPrank();
    }

    function testClaimOwnership() external {
        vm.startPrank(bob);

        uint256 atomCost = multiVault.getAtomCost();
        string memory atomUriString = "atom1";

        bytes32 atomId = multiVault.createAtom(abi.encodePacked(atomUriString), atomCost);

        atomWalletFactory.deployAtomWallet(atomId);

        vm.stopPrank();

        vm.startPrank(admin);

        // In this example, bob gets set as the new pending owner, but, AtomWarden's admin can set the new pending owner to be
        // any address that has proven ownership over the AtomWallet, so bob is used here only as an example, i.e. there is no
        // direct relationship between the who deploys the AtomWallet contract, and who gets set as the new pending owner.
        atomWarden.claimOwnership(atomId, bob);

        address payable atomWalletAddress = payable(multiVault.computeAtomWalletAddr(atomId));
        address pendingOwner = AtomWallet(atomWalletAddress).pendingOwner();

        assertEq(pendingOwner, address(bob));

        vm.stopPrank();

        vm.startPrank(bob);

        AtomWallet(atomWalletAddress).acceptOwnership();

        address owner = AtomWallet(atomWalletAddress).owner();

        assertEq(owner, address(bob));

        vm.stopPrank();
    }

    function testClaimOwnershipAtomIdZero() external {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_AtomIdDoesNotExist.selector));
        atomWarden.claimOwnership(bytes32(0), bob);

        vm.stopPrank();
    }

    function testClaimOwnershipAtomIdDoesNotExist() external {
        vm.startPrank(admin);

        bytes32 fakeAtomId = keccak256(abi.encodePacked("fakeAtomId"));

        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_AtomIdDoesNotExist.selector));
        atomWarden.claimOwnership(fakeAtomId, bob);

        vm.stopPrank();
    }

    function testClaimOwnershipInvalidNewOwner() external {
        vm.startPrank(bob);

        uint256 atomCost = multiVault.getAtomCost();
        string memory atomUriString = "atom1";

        bytes32 atomId = multiVault.createAtom(abi.encodePacked(atomUriString), atomCost);

        atomWalletFactory.deployAtomWallet(atomId);

        vm.stopPrank();

        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_InvalidNewOwner.selector));
        atomWarden.claimOwnership(atomId, address(0));

        vm.stopPrank();
    }

    function testClaimOwnershipWalletNotDeployed() external {
        vm.startPrank(alice);
        uint256 atomCost = multiVault.getAtomCost();
        string memory atomUriString = _toLowerCaseAddress(address(alice));
        bytes32 atomId = multiVault.createAtom(abi.encodePacked(atomUriString), atomCost);
        vm.stopPrank();

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.AtomWarden_AtomWalletNotDeployed.selector));
        atomWarden.claimOwnership(atomId, alice);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts an address to its lowercase hexadecimal string representation.
    /// @param _address The address to be converted.
    /// @return The lowercase hexadecimal string of the address.
    function _toLowerCaseAddress(address _address) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef"; // Lowercase hexadecimal characters
        bytes20 addrBytes = bytes20(_address);
        bytes memory str = new bytes(42);

        str[0] = "0";
        str[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(addrBytes[i] >> 4)]; // Upper 4 bits (first hex character)
            str[3 + i * 2] = alphabet[uint8(addrBytes[i] & 0x0f)]; // Lower 4 bits (second hex character)
        }

        return string(str);
    }
}
