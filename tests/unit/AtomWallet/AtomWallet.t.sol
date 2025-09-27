// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console } from "forge-std/src/Test.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { IAtomWalletFactory } from "src/interfaces/IAtomWalletFactory.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

contract MockEntryPoint {
    mapping(address account => uint256 balance) public balanceOf;

    function depositTo(address account) external payable {
        balanceOf[account] += msg.value;
    }

    function withdrawTo(address payable withdrawAddress, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        withdrawAddress.transfer(amount);
    }
}

contract AtomWalletTest is BaseTest {
    /// @notice Test actors
    address public constant UNAUTHORIZED_USER = address(0x9999);
    address public constant NEW_OWNER = address(0x1111);
    address public constant WITHDRAW_ADDRESS = address(0x2222);
    address public constant CALL_TARGET = address(0x3333);

    /// @notice Test data
    bytes public constant TEST_ATOM_DATA = bytes("Test atom for wallet");
    bytes32 public constant TEST_ATOM_ID = keccak256(abi.encodePacked(TEST_ATOM_DATA));
    uint256 public constant TEST_AMOUNT = 1 ether;
    uint256 public constant TEST_DEPOSIT_AMOUNT = 0.5 ether;
    bytes public constant TEST_CALLDATA = hex"deadbeef";
    uint256 constant BASE_TIMESTAMP = 1_000_000;

    /// @notice Contract addresses
    AtomWallet public atomWallet;
    address public atomWalletAddress;
    MockEntryPoint public mockEntryPoint;

    function setUp() public override {
        // Deploy mock EntryPoint and fund it with TRUST first
        mockEntryPoint = new MockEntryPoint();
        vm.deal(address(mockEntryPoint), 1000 ether);
        vm.stopPrank();

        super.setUp();

        // Mock the walletConfig in multiVault to return mock entryPoint
        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(protocol.multiVault.walletConfig.selector),
            abi.encode(
                address(mockEntryPoint),
                address(ATOM_WARDEN),
                address(protocol.atomWalletBeacon),
                address(protocol.atomWalletFactory)
            )
        );

        // Create an atom first
        vm.startPrank(users.alice);
        bytes memory atomData = bytes("Test atom for wallet");
        uint256 atomCost = protocol.multiVault.getAtomCost();

        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = atomCost;
        protocol.multiVault.createAtoms{ value: atomCost }(atomDataArray, amounts);
        vm.stopPrank();

        // Deploy atom wallet through factory
        atomWalletAddress = protocol.atomWalletFactory.deployAtomWallet(TEST_ATOM_ID);
        atomWallet = AtomWallet(payable(atomWalletAddress));

        // Fund the atom wallet with some ETH
        vm.deal(atomWalletAddress, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_successful() public {
        // Use TransparentUpgradeableProxy to simulate upgradeable proxy behavior
        // and avoid the invalid initialization error
        AtomWallet freshWallet = new AtomWallet();
        TransparentUpgradeableProxy atomWalletProxy =
            new TransparentUpgradeableProxy(address(freshWallet), users.admin, "");
        freshWallet = AtomWallet(payable(address(atomWalletProxy)));

        freshWallet.initialize(address(mockEntryPoint), address(protocol.multiVault), TEST_ATOM_ID);

        assertEq(address(freshWallet.entryPoint()), address(mockEntryPoint));
        assertEq(address(freshWallet.multiVault()), address(protocol.multiVault));
        assertEq(freshWallet.termId(), TEST_ATOM_ID);
        assertEq(freshWallet.owner(), address(ATOM_WARDEN));
        assertFalse(freshWallet.isClaimed());
    }

    function test_initialize_revertsOnZeroEntryPoint() public {
        AtomWallet freshWallet = new AtomWallet();
        TransparentUpgradeableProxy atomWalletProxy =
            new TransparentUpgradeableProxy(address(freshWallet), users.admin, "");
        freshWallet = AtomWallet(payable(address(atomWalletProxy)));

        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_ZeroAddress.selector));
        freshWallet.initialize(address(0), address(protocol.multiVault), TEST_ATOM_ID);
    }

    function test_initialize_revertsOnZeroMultiVault() public {
        AtomWallet freshWallet = new AtomWallet();
        TransparentUpgradeableProxy atomWalletProxy =
            new TransparentUpgradeableProxy(address(freshWallet), users.admin, "");
        freshWallet = AtomWallet(payable(address(atomWalletProxy)));

        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_ZeroAddress.selector));
        freshWallet.initialize(address(mockEntryPoint), address(0), TEST_ATOM_ID);
    }

    function test_initialize_revertsOnDoubleInitialization() public {
        AtomWallet freshWallet = new AtomWallet();
        TransparentUpgradeableProxy atomWalletProxy =
            new TransparentUpgradeableProxy(address(freshWallet), users.admin, "");
        freshWallet = AtomWallet(payable(address(atomWalletProxy)));

        freshWallet.initialize(address(mockEntryPoint), address(protocol.multiVault), TEST_ATOM_ID);

        vm.expectRevert();
        freshWallet.initialize(address(mockEntryPoint), address(protocol.multiVault), TEST_ATOM_ID);
    }

    function test_initialState() public view {
        assertEq(address(atomWallet.entryPoint()), address(mockEntryPoint));
        assertEq(address(atomWallet.multiVault()), address(protocol.multiVault));
        assertEq(atomWallet.termId(), TEST_ATOM_ID);
        assertEq(atomWallet.owner(), address(ATOM_WARDEN));
        assertFalse(atomWallet.isClaimed());
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_receive_acceptsEther() public {
        uint256 balanceBefore = address(atomWallet).balance;

        vm.deal(users.alice, TEST_AMOUNT);
        vm.prank(users.alice);
        (bool success,) = address(atomWallet).call{ value: TEST_AMOUNT }("");

        assertTrue(success);
        assertEq(address(atomWallet).balance, balanceBefore + TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            EXECUTE FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_execute_successfulByOwner() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_execute_successfulByEntryPoint() public {
        vm.prank(address(mockEntryPoint));
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_execute_revertsOnUnauthorizedUser() public {
        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwnerOrEntryPoint.selector);
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);
    }

    function test_execute_revertsOnTargetFailure() public {
        // Deploy a contract that will revert
        MockRevertingContract reverter = new MockRevertingContract();

        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert("MockRevertingContract: revert");
        atomWallet.execute(address(reverter), 0, abi.encodeWithSelector(reverter.revertFunction.selector));
    }

    function test_execute_handlesZeroValue() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.execute(CALL_TARGET, 0, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, 0);
    }

    function test_execute_handlesEmptyCalldata() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, "");

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            EXECUTE BATCH FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_executeBatch_successful() public {
        address[] memory destinations = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory functionCalls = new bytes[](3);

        destinations[0] = users.alice;
        destinations[1] = users.bob;
        destinations[2] = CALL_TARGET;
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;
        functionCalls[0] = "";
        functionCalls[1] = "";
        functionCalls[2] = TEST_CALLDATA;

        // Store initial balances
        uint256 aliceBalanceBefore = users.alice.balance;
        uint256 bobBalanceBefore = users.bob.balance;
        uint256 callTargetBalanceBefore = CALL_TARGET.balance;

        // Ensure wallet has enough balance
        vm.deal(address(atomWallet), 6 ether);

        vm.prank(address(ATOM_WARDEN));
        atomWallet.executeBatch(destinations, values, functionCalls);

        assertEq(users.alice.balance, aliceBalanceBefore + 1 ether);
        assertEq(users.bob.balance, bobBalanceBefore + 2 ether);
        assertEq(CALL_TARGET.balance, callTargetBalanceBefore + 3 ether);
    }

    function test_executeBatch_revertsOnWrongArrayLengthDestinations() public {
        address[] memory destinations = new address[](2);
        uint256[] memory values = new uint256[](3);
        bytes[] memory functionCalls = new bytes[](3);

        destinations[0] = users.alice;
        destinations[1] = users.bob;
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;
        functionCalls[0] = "";
        functionCalls[1] = "";
        functionCalls[2] = TEST_CALLDATA;

        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(AtomWallet.AtomWallet_WrongArrayLengths.selector);
        atomWallet.executeBatch(destinations, values, functionCalls);
    }

    function test_executeBatch_revertsOnWrongArrayLengthValues() public {
        address[] memory destinations = new address[](3);
        uint256[] memory values = new uint256[](2);
        bytes[] memory functionCalls = new bytes[](3);

        destinations[0] = users.alice;
        destinations[1] = users.bob;
        destinations[2] = CALL_TARGET;
        values[0] = 1 ether;
        values[1] = 2 ether;
        functionCalls[0] = "";
        functionCalls[1] = "";
        functionCalls[2] = TEST_CALLDATA;

        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(AtomWallet.AtomWallet_WrongArrayLengths.selector);
        atomWallet.executeBatch(destinations, values, functionCalls);
    }

    function test_executeBatch_revertsOnUnauthorizedUser() public {
        address[] memory destinations = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory functionCalls = new bytes[](1);

        destinations[0] = users.alice;
        values[0] = 1 ether;
        functionCalls[0] = "";

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwnerOrEntryPoint.selector);
        atomWallet.executeBatch(destinations, values, functionCalls);
    }

    function test_executeBatch_handlesEmptyArrays() public {
        address[] memory destinations = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory functionCalls = new bytes[](0);

        vm.prank(address(ATOM_WARDEN));
        atomWallet.executeBatch(destinations, values, functionCalls);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_addDeposit_successful() public {
        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);

        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        assertEq(atomWallet.getDeposit(), TEST_DEPOSIT_AMOUNT);
    }

    function test_addDeposit_handlesZeroValue() public {
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: 0 }();

        assertEq(atomWallet.getDeposit(), 0);
    }

    function test_addDeposit_multipleDeposits() public {
        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT * 2);

        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        assertEq(atomWallet.getDeposit(), TEST_DEPOSIT_AMOUNT * 2);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW DEPOSIT FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawDepositTo_successfulByOwner() public {
        // First add a deposit
        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        uint256 balanceBefore = WITHDRAW_ADDRESS.balance;

        vm.prank(address(ATOM_WARDEN));
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), TEST_DEPOSIT_AMOUNT);

        assertEq(WITHDRAW_ADDRESS.balance, balanceBefore + TEST_DEPOSIT_AMOUNT);
        assertEq(atomWallet.getDeposit(), 0);
    }

    function test_withdrawDepositTo_successfulByWalletItself() public {
        // First add a deposit
        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        uint256 balanceBefore = WITHDRAW_ADDRESS.balance;

        vm.prank(address(atomWallet));
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), TEST_DEPOSIT_AMOUNT);

        assertEq(WITHDRAW_ADDRESS.balance, balanceBefore + TEST_DEPOSIT_AMOUNT);
        assertEq(atomWallet.getDeposit(), 0);
    }

    function test_withdrawDepositTo_revertsOnUnauthorizedUser() public {
        // First add a deposit
        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwner.selector);
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), TEST_DEPOSIT_AMOUNT);
    }

    function test_withdrawDepositTo_handlesZeroAmount() public {
        // First add a deposit
        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        uint256 balanceBefore = WITHDRAW_ADDRESS.balance;

        vm.prank(address(ATOM_WARDEN));
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), 0);

        assertEq(WITHDRAW_ADDRESS.balance, balanceBefore);
        assertEq(atomWallet.getDeposit(), TEST_DEPOSIT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transferOwnership_successful() public {
        vm.prank(address(ATOM_WARDEN));
        vm.expectEmit(true, true, true, true);
        emit Ownable2StepUpgradeable.OwnershipTransferStarted(address(ATOM_WARDEN), NEW_OWNER);
        atomWallet.transferOwnership(NEW_OWNER);

        assertEq(atomWallet.pendingOwner(), NEW_OWNER);
        assertEq(atomWallet.owner(), address(ATOM_WARDEN));
    }

    function test_transferOwnership_revertsOnZeroAddress() public {
        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        atomWallet.transferOwnership(address(0));
    }

    function test_transferOwnership_revertsOnUnauthorizedUser() public {
        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert();
        atomWallet.transferOwnership(NEW_OWNER);
    }

    function test_acceptOwnership_successful() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(NEW_OWNER);

        vm.prank(NEW_OWNER);
        vm.expectEmit(true, true, true, true);
        emit OwnableUpgradeable.OwnershipTransferred(address(ATOM_WARDEN), NEW_OWNER);
        atomWallet.acceptOwnership();

        assertEq(atomWallet.owner(), NEW_OWNER);
        assertEq(atomWallet.pendingOwner(), address(0));
        assertTrue(atomWallet.isClaimed());
    }

    function test_acceptOwnership_revertsOnUnauthorizedUser() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(NEW_OWNER);

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, UNAUTHORIZED_USER)
        );
        atomWallet.acceptOwnership();
    }

    function test_acceptOwnership_revertsOnNoPendingOwner() public {
        vm.prank(NEW_OWNER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, NEW_OWNER));
        atomWallet.acceptOwnership();
    }

    function test_acceptOwnership_setsClaimedFlag() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(NEW_OWNER);

        assertFalse(atomWallet.isClaimed());

        vm.prank(NEW_OWNER);
        atomWallet.acceptOwnership();

        assertTrue(atomWallet.isClaimed());
    }

    function test_ownerFunction_returnsATOM_WARDENWhenUnclaimed() public view {
        assertEq(atomWallet.owner(), address(ATOM_WARDEN));
    }

    function test_ownerFunction_returnsUserWhenClaimed() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.acceptOwnership();

        assertEq(atomWallet.owner(), NEW_OWNER);
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM FEES FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimAtomWalletDepositFees_successful() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.claimAtomWalletDepositFees();
    }

    function test_claimAtomWalletDepositFees_revertsOnUnauthorizedUser() public {
        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert();
        atomWallet.claimAtomWalletDepositFees();
    }

    function test_claimAtomWalletDepositFees_successfulAfterClaim() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.acceptOwnership();

        vm.prank(NEW_OWNER);
        atomWallet.claimAtomWalletDepositFees();
    }

    /*//////////////////////////////////////////////////////////////
                            SIGNATURE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    // The AtomWallet code does this:
    // bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
    // (address recovered, ECDSA.RecoverError recoverError, bytes32 errorArg) = ECDSA.tryRecover(hash,
    // userOp.signature);
    //
    // ECDSA.tryRecover expects the signature to be for the prefixed hash.
    // So we need to sign the prefixed message.
    function test_validateSignature_successful() public {
        vm.warp(BASE_TIMESTAMP);

        uint256 privateKey = 0x1;
        address expectedOwner = vm.addr(privateKey);

        PackedUserOperation memory userOp = _createValidUserOp();
        bytes32 userOpHash = keccak256(abi.encode(userOp));

        // AtomWallet will create this hash internally
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));

        // We need to sign the message that matches what will be passed to ecrecover
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        userOp.signature = abi.encodePacked(r, s, v);

        // Create a wallet owned by the expected owner
        AtomWallet testWallet = _createWalletOwnedBy(expectedOwner);

        // Call validateUserOp as the EntryPoint
        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, 0);
    }

    function test_validateSignature_failsOnInvalidSignature() public {
        vm.warp(BASE_TIMESTAMP); // Ensure consistent timestamp

        PackedUserOperation memory userOp = _createValidUserOp();
        bytes32 userOpHash = keccak256(abi.encode(userOp));

        // Sign with wrong key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        // Create a wallet owned by different account
        AtomWallet testWallet = _createWalletOwnedBy(vm.addr(1));

        // Call validateUserOp as the EntryPoint
        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, 1);
    }

    function test_validateSignature_failsOnExpiredSignature() public {
        vm.warp(BASE_TIMESTAMP); // Ensure consistent timestamp

        PackedUserOperation memory userOp = _createExpiredUserOp();
        bytes32 userOpHash = keccak256(abi.encode(userOp));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        AtomWallet testWallet = _createWalletOwnedBy(vm.addr(1));

        // Call validateUserOp as the EntryPoint
        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, 1);
    }

    function test_validateSignature_failsOnNotYetValidSignature() public {
        vm.warp(BASE_TIMESTAMP); // Ensure consistent timestamp

        PackedUserOperation memory userOp = _createFutureUserOp();
        bytes32 userOpHash = keccak256(abi.encode(userOp));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        AtomWallet testWallet = _createWalletOwnedBy(vm.addr(1));

        // Call validateUserOp as the EntryPoint
        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, 1);
    }

    function test_validateSignature_revertsOnInvalidCallDataLength() public {
        vm.warp(BASE_TIMESTAMP); // Ensure consistent timestamp

        PackedUserOperation memory userOp = _createValidUserOp();
        userOp.callData = hex"deadbeef"; // Too short

        bytes32 userOpHash = keccak256(abi.encode(userOp));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        AtomWallet testWallet = _createWalletOwnedBy(vm.addr(1));

        // Call validateUserOp as the EntryPoint
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_InvalidCallDataLength.selector));
        testWallet.validateUserOp(userOp, userOpHash, 0);
    }

    function test_validateSignature_revertsOnInvalidSignatureLength() public {
        vm.warp(BASE_TIMESTAMP); // Add this line to prevent underflow

        PackedUserOperation memory userOp = _createValidUserOp();
        bytes32 userOpHash = keccak256(abi.encode(userOp));

        userOp.signature = hex"deadbeef"; // Too short

        AtomWallet testWallet = _createWalletOwnedBy(vm.addr(1));

        // Call validateUserOp as the EntryPoint
        vm.prank(address(mockEntryPoint));
        vm.expectRevert();
        testWallet.validateUserOp(userOp, userOpHash, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            FACTORY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_factory_deployAtomWallet_successful() public {
        // Create new atom
        vm.startPrank(users.alice);
        bytes memory atomData = bytes("New test atom");
        bytes32 atomId = keccak256(abi.encodePacked(atomData));
        uint256 atomCost = protocol.multiVault.getAtomCost();

        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = atomCost;
        protocol.multiVault.createAtoms{ value: atomCost }(atomDataArray, amounts);
        vm.stopPrank();

        address deployedWallet = protocol.atomWalletFactory.deployAtomWallet(atomId);

        assertTrue(deployedWallet != address(0));

        AtomWallet wallet = AtomWallet(payable(deployedWallet));
        assertEq(wallet.termId(), atomId);
        assertEq(address(wallet.multiVault()), address(protocol.multiVault));
        assertEq(wallet.owner(), address(ATOM_WARDEN));
    }

    function test_factory_deployAtomWallet_returnsExistingWallet() public {
        address firstDeployment = protocol.atomWalletFactory.deployAtomWallet(TEST_ATOM_ID);
        address secondDeployment = protocol.atomWalletFactory.deployAtomWallet(TEST_ATOM_ID);

        assertEq(firstDeployment, secondDeployment);
    }

    function test_factory_deployAtomWallet_revertsOnInvalidAtomId() public {
        bytes32 invalidAtomId = bytes32(uint256(123)); // Invalid atom ID

        vm.expectRevert(AtomWalletFactory.AtomWalletFactory_TermDoesNotExist.selector);
        protocol.atomWalletFactory.deployAtomWallet(invalidAtomId);
    }

    function test_factory_deployAtomWallet_revertsOnTripleId() public {
        // Create a triple first
        vm.startPrank(users.alice);
        bytes memory atomData = bytes("subject");
        uint256 atomCost = protocol.multiVault.getAtomCost();

        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = atomData;
        atomDataArray[1] = bytes("predicate");
        atomDataArray[2] = bytes("object");
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = atomCost;
        amounts[1] = atomCost;
        amounts[2] = atomCost;
        bytes32[] memory atomIds =
            protocol.multiVault.createAtoms{ value: calculateTotalCost(amounts) }(atomDataArray, amounts);
        bytes32 subjectId = atomIds[0];
        bytes32 predicateId = atomIds[1];
        bytes32 objectId = atomIds[2];

        uint256 tripleCost = protocol.multiVault.getTripleCost();
        bytes32[] memory subjectIds = new bytes32[](1);
        bytes32[] memory predicateIds = new bytes32[](1);
        bytes32[] memory objectIds = new bytes32[](1);
        subjectIds[0] = subjectId;
        predicateIds[0] = predicateId;
        objectIds[0] = objectId;
        uint256[] memory tripleaAmounts = new uint256[](1);
        tripleaAmounts[0] = tripleCost;
        bytes32 tripleId = protocol.multiVault.createTriples{ value: tripleCost }(
            subjectIds, predicateIds, objectIds, tripleaAmounts
        )[0];
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(AtomWalletFactory.AtomWalletFactory_TermNotAtom.selector));
        protocol.atomWalletFactory.deployAtomWallet(tripleId);
    }

    function test_factory_deployAtomWallet_emitsEvent() public {
        bytes32 newAtomId = keccak256(abi.encodePacked("New test atom"));

        // Create new atom
        vm.startPrank(users.alice);
        bytes memory atomData = bytes("New test atom");
        uint256 atomCost = protocol.multiVault.getAtomCost();

        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = atomCost;
        protocol.multiVault.createAtoms{ value: atomCost }(atomDataArray, amounts);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false);
        emit IAtomWalletFactory.AtomWalletDeployed(newAtomId, address(0));

        protocol.atomWalletFactory.deployAtomWallet(newAtomId);
    }

    function test_factory_computeAtomWalletAddr_consistency() public view {
        address computedAddress1 = protocol.atomWalletFactory.computeAtomWalletAddr(TEST_ATOM_ID);
        address computedAddress2 = protocol.atomWalletFactory.computeAtomWalletAddr(TEST_ATOM_ID);

        assertEq(computedAddress1, computedAddress2);
    }

    function test_factory_computeAtomWalletAddr_matchesDeployedAddress() public view {
        address computedAddress = protocol.atomWalletFactory.computeAtomWalletAddr(TEST_ATOM_ID);

        assertEq(computedAddress, atomWalletAddress);
    }

    function test_factory_initialize_revertsOnZeroAddress() public {
        AtomWalletFactory freshFactory = new AtomWalletFactory();
        atomWalletFactoryProxy = new TransparentUpgradeableProxy(address(freshFactory), users.admin, "");
        freshFactory = AtomWalletFactory(address(atomWalletFactoryProxy));

        vm.expectRevert(abi.encodeWithSelector(AtomWalletFactory.AtomWalletFactory_ZeroAddress.selector));
        freshFactory.initialize(address(0));
    }

    function test_factory_initialize_revertsOnDoubleInitialization() public {
        AtomWalletFactory freshFactory = new AtomWalletFactory();
        atomWalletFactoryProxy = new TransparentUpgradeableProxy(address(freshFactory), users.admin, "");
        freshFactory = AtomWalletFactory(address(atomWalletFactoryProxy));

        freshFactory.initialize(address(protocol.multiVault));

        vm.expectRevert();
        freshFactory.initialize(address(protocol.multiVault));
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_integration_fullOwnershipTransferFlow() public {
        // Transfer ownership
        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(NEW_OWNER);

        assertEq(atomWallet.pendingOwner(), NEW_OWNER);
        assertEq(atomWallet.owner(), address(ATOM_WARDEN));
        assertFalse(atomWallet.isClaimed());

        // Accept ownership
        vm.prank(NEW_OWNER);
        atomWallet.acceptOwnership();

        assertEq(atomWallet.owner(), NEW_OWNER);
        assertEq(atomWallet.pendingOwner(), address(0));
        assertTrue(atomWallet.isClaimed());

        // New owner can execute
        vm.prank(NEW_OWNER);
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_integration_depositAndWithdrawFlow() public {
        // Add deposit
        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        assertEq(atomWallet.getDeposit(), TEST_DEPOSIT_AMOUNT);

        // Withdraw deposit
        uint256 balanceBefore = WITHDRAW_ADDRESS.balance;

        vm.prank(address(ATOM_WARDEN));
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), TEST_DEPOSIT_AMOUNT);

        assertEq(WITHDRAW_ADDRESS.balance, balanceBefore + TEST_DEPOSIT_AMOUNT);
        assertEq(atomWallet.getDeposit(), 0);
    }

    function test_integration_factoryDeployAndWalletUsage() public {
        // Create new atom
        vm.startPrank(users.alice);
        bytes memory atomData = bytes("New test atom");
        bytes32 newAtomId = keccak256(abi.encodePacked("New test atom"));
        uint256 atomCost = protocol.multiVault.getAtomCost();

        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = atomCost;
        protocol.multiVault.createAtoms{ value: atomCost }(atomDataArray, amounts);
        vm.stopPrank();

        // Deploy wallet
        address deployedWallet = protocol.atomWalletFactory.deployAtomWallet(newAtomId);
        AtomWallet wallet = AtomWallet(payable(deployedWallet));

        // Fund wallet
        vm.deal(deployedWallet, TEST_AMOUNT);

        // Use wallet
        vm.prank(address(ATOM_WARDEN));
        wallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_execute_validParameters(address target, uint256 value, bytes calldata data) external {
        // Exclude precompiled contracts (addresses 0x1 to 0xA)
        vm.assume(target > address(0xA));
        vm.assume(target.code.length == 0);

        // Exclude Foundry cheatcode addresses that masquerade as EOAs
        address FOUNDRY_CONSOLE = address(0x000000000000000000636F6e736F6c652e6c6f67); // "console.log"
        address FOUNDRY_CONSOLE2 = address(0x0000000000000000000000000000636f6e736f6c6532); // "console2"
        address HEVM = address(uint160(uint256(keccak256("hevm cheat code"))));
        vm.assume(target != FOUNDRY_CONSOLE && target != FOUNDRY_CONSOLE2 && target != HEVM);

        // Bound value and proceed
        value = bound(value, 0, address(atomWallet).balance);

        // Store the target's balance before the call
        uint256 targetBalanceBefore = target.balance;

        vm.prank(address(ATOM_WARDEN));
        atomWallet.execute(target, value, data);

        // Assert that the target's balance increased by the sent value
        assertEq(target.balance, targetBalanceBefore + value);
    }

    function testFuzz_addDeposit_validAmounts(uint256 amount) external {
        amount = bound(amount, 0, 100 ether);

        vm.deal(users.alice, amount);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: amount }();

        assertEq(atomWallet.getDeposit(), amount);
    }

    function testFuzz_transferOwnership_validAddresses(address newOwner) external {
        vm.assume(newOwner != address(0));

        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(newOwner);

        assertEq(atomWallet.pendingOwner(), newOwner);
        assertEq(atomWallet.owner(), address(ATOM_WARDEN));
    }

    function testFuzz_executeBatch_validParameters(uint256 numberOfCalls, uint256 baseValue) external {
        numberOfCalls = bound(numberOfCalls, 1, 10);
        baseValue = bound(baseValue, 0, 1 ether);

        address[] memory destinations = new address[](numberOfCalls);
        uint256[] memory values = new uint256[](numberOfCalls);
        bytes[] memory functionCalls = new bytes[](numberOfCalls);

        uint256 totalValue = 0;
        for (uint256 i = 0; i < numberOfCalls; i++) {
            destinations[i] = address(uint160(0x1000 + i));
            values[i] = baseValue + i;
            functionCalls[i] = "";
            totalValue += values[i];
        }

        vm.deal(address(atomWallet), totalValue);

        vm.prank(address(ATOM_WARDEN));
        atomWallet.executeBatch(destinations, values, functionCalls);

        for (uint256 i = 0; i < numberOfCalls; i++) {
            assertEq(destinations[i].balance, values[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_edge_multipleOwnershipTransfers() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(NEW_OWNER);

        vm.prank(address(ATOM_WARDEN));
        atomWallet.transferOwnership(users.alice);

        assertEq(atomWallet.pendingOwner(), users.alice);

        vm.prank(users.alice);
        atomWallet.acceptOwnership();

        assertEq(atomWallet.owner(), users.alice);
    }

    function test_edge_executeWithAllWalletBalance() public {
        uint256 walletBalance = address(atomWallet).balance;

        vm.prank(address(ATOM_WARDEN));
        atomWallet.execute(CALL_TARGET, walletBalance, "");

        assertEq(CALL_TARGET.balance, walletBalance);
        assertEq(address(atomWallet).balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createValidUserOp() internal view returns (PackedUserOperation memory) {
        // Use uint96 for timestamps to fit in 12 bytes
        uint96 validUntil = uint96(block.timestamp + 1000);
        uint96 validAfter = uint96(block.timestamp - 100);

        // Encode timestamps as uint96 (12 bytes each)
        bytes memory callData = abi.encodePacked(
            validUntil, // 12 bytes
            validAfter, // 12 bytes
            abi.encodeWithSelector(atomWallet.execute.selector, CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA)
        );

        return PackedUserOperation({
            sender: address(atomWallet),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(uint256(1_000_000) << 128 | 1_000_000),
            preVerificationGas: 21_000,
            gasFees: bytes32(uint256(1_000_000_000) << 128 | 1_000_000_000),
            paymasterAndData: "",
            signature: ""
        });
    }

    function _createExpiredUserOp() internal view returns (PackedUserOperation memory) {
        // Use uint96 for timestamps to fit in 12 bytes
        uint96 validUntil = uint96(block.timestamp - 100);
        uint96 validAfter = uint96(block.timestamp - 200);

        bytes memory callData = abi.encodePacked(
            validUntil, // 12 bytes (expired)
            validAfter, // 12 bytes
            abi.encodeWithSelector(atomWallet.execute.selector, CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA)
        );

        return PackedUserOperation({
            sender: address(atomWallet),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(uint256(1_000_000) << 128 | 1_000_000),
            preVerificationGas: 21_000,
            gasFees: bytes32(uint256(1_000_000_000) << 128 | 1_000_000_000),
            paymasterAndData: "",
            signature: ""
        });
    }

    function _createFutureUserOp() internal view returns (PackedUserOperation memory) {
        // Use uint96 for timestamps to fit in 12 bytes
        uint96 validUntil = uint96(block.timestamp + 2000);
        uint96 validAfter = uint96(block.timestamp + 1000);

        bytes memory callData = abi.encodePacked(
            validUntil, // 12 bytes
            validAfter, // 12 bytes (future)
            abi.encodeWithSelector(atomWallet.execute.selector, CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA)
        );

        return PackedUserOperation({
            sender: address(atomWallet),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(uint256(1_000_000) << 128 | 1_000_000),
            preVerificationGas: 21_000,
            gasFees: bytes32(uint256(1_000_000_000) << 128 | 1_000_000_000),
            paymasterAndData: "",
            signature: ""
        });
    }

    function _createWalletOwnedBy(address owner) internal returns (AtomWallet) {
        AtomWallet freshWallet = new AtomWallet();
        TransparentUpgradeableProxy atomWalletProxy =
            new TransparentUpgradeableProxy(address(freshWallet), users.admin, "");
        freshWallet = AtomWallet(payable(address(atomWalletProxy)));

        // Mock the multiVault to return the desired owner as address(ATOM_WARDEN)
        vm.mockCall(
            address(protocol.multiVault),
            abi.encodeWithSelector(protocol.multiVault.getAtomWarden.selector),
            abi.encode(owner)
        );

        freshWallet.initialize(address(mockEntryPoint), address(protocol.multiVault), TEST_ATOM_ID);

        return freshWallet;
    }
}

contract MockRevertingContract {
    function revertFunction() external pure {
        revert("MockRevertingContract: revert");
    }
}
