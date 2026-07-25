// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test, console } from "forge-std/src/Test.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { SIG_VALIDATION_FAILED, _packValidationData } from "@account-abstraction/core/Helpers.sol";
import { UserOperationLib } from "@account-abstraction/core/UserOperationLib.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { IAtomWalletFactory } from "src/interfaces/IAtomWalletFactory.sol";
import { BaseTest } from "tests/BaseTest.t.sol";

contract MockEntryPoint {
    using UserOperationLib for PackedUserOperation;

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_NAME_HASH = keccak256(bytes("ERC4337"));
    bytes32 private constant DOMAIN_VERSION_HASH = keccak256(bytes("0.8"));

    mapping(address account => uint256 balance) public balanceOf;

    function depositTo(address account) external payable {
        balanceOf[account] += msg.value;
    }

    function withdrawTo(address payable withdrawAddress, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        withdrawAddress.transfer(amount);
    }

    function getUserOpHash(PackedUserOperation calldata userOp) external view returns (bytes32) {
        bytes32 domainSeparator =
            keccak256(abi.encode(DOMAIN_TYPEHASH, DOMAIN_NAME_HASH, DOMAIN_VERSION_HASH, block.chainid, address(this)));

        return MessageHashUtils.toTypedDataHash(domainSeparator, userOp.hash(bytes32(0)));
    }
}

contract AtomWalletTest is BaseTest {
    uint256 private constant SECP256K1_CURVE_ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    /// @notice Test actors
    address public constant UNAUTHORIZED_USER = address(0x9999);
    address public constant NEW_OWNER = address(0x1111);
    address public constant WITHDRAW_ADDRESS = address(0x2222);
    address public constant CALL_TARGET = address(0x3333);
    address public constant CO_SIGNER = address(0x4444);

    /// @notice Test data
    bytes public constant TEST_ATOM_DATA = bytes("Test atom for wallet");
    bytes32 public TEST_ATOM_ID;
    uint256 public constant TEST_AMOUNT = 1 ether;
    uint256 public constant TEST_DEPOSIT_AMOUNT = 0.5 ether;
    bytes public constant TEST_CALLDATA = hex"deadbeef";
    uint256 public constant BASE_TIMESTAMP = 1_000_000;

    /// @notice Contract addresses
    AtomWallet public atomWallet;
    address public atomWalletAddress;
    MockEntryPoint public mockEntryPoint;

    function setUp() public override {
        TEST_ATOM_ID = calculateAtomId(TEST_ATOM_DATA);

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

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        freshWallet.initialize(address(mockEntryPoint), address(protocol.multiVault), TEST_ATOM_ID);
    }

    function test_initialState() public view {
        assertEq(address(atomWallet.entryPoint()), address(mockEntryPoint));
        assertEq(address(atomWallet.multiVault()), address(protocol.multiVault));
        assertEq(atomWallet.termId(), TEST_ATOM_ID);
        assertEq(atomWallet.owner(), address(ATOM_WARDEN));
        assertFalse(atomWallet.isClaimed());
        assertEq(atomWallet.ownerCount(), 0);
        assertEq(atomWallet.nextOwnerIndex(), 0);
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

    function test_execute_successfulByPrimaryOwnerAfterClaim() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_execute_successfulByEntryPoint() public {
        vm.prank(address(mockEntryPoint));
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_execute_successfulByMultiOwnableCoSigner() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);

        vm.prank(CO_SIGNER);
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_execute_successfulBySelfCall() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(address(atomWallet));
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_execute_revertsOnUnauthorizedUser() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwnerOrEntryPoint.selector);
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);
    }

    function test_execute_revertsPreClaimForPrimaryOwner() public {
        // Pre-claim, OZ owner() is AtomWarden, but MultiOwnable is empty, so
        // even the "owner" cannot call execute directly. This locks in the
        // intended dormant-pre-claim behavior.
        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwnerOrEntryPoint.selector);
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);
    }

    function test_execute_revertsOnTargetFailure() public {
        _claimWalletAs(NEW_OWNER);

        MockRevertingContract reverter = new MockRevertingContract();

        vm.prank(NEW_OWNER);
        vm.expectRevert("MockRevertingContract: revert");
        atomWallet.execute(address(reverter), 0, abi.encodeWithSelector(reverter.revertFunction.selector));
    }

    function test_execute_handlesZeroValue() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.execute(CALL_TARGET, 0, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, 0);
    }

    function test_execute_handlesEmptyCalldata() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, "");

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            EXECUTE BATCH FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_executeBatch_successful() public {
        _claimWalletAs(NEW_OWNER);

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

        uint256 aliceBalanceBefore = users.alice.balance;
        uint256 bobBalanceBefore = users.bob.balance;
        uint256 callTargetBalanceBefore = CALL_TARGET.balance;

        vm.deal(address(atomWallet), 6 ether);

        vm.prank(NEW_OWNER);
        atomWallet.executeBatch(destinations, values, functionCalls);

        assertEq(users.alice.balance, aliceBalanceBefore + 1 ether);
        assertEq(users.bob.balance, bobBalanceBefore + 2 ether);
        assertEq(CALL_TARGET.balance, callTargetBalanceBefore + 3 ether);
    }

    function test_executeBatch_successfulByMultiOwnableCoSigner() public {
        _claimWalletAs(NEW_OWNER);
        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);

        address[] memory destinations = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory functionCalls = new bytes[](1);
        destinations[0] = CALL_TARGET;
        values[0] = TEST_AMOUNT;
        functionCalls[0] = "";

        vm.prank(CO_SIGNER);
        atomWallet.executeBatch(destinations, values, functionCalls);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_executeBatch_revertsOnWrongArrayLengthDestinations() public {
        _claimWalletAs(NEW_OWNER);

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

        vm.prank(NEW_OWNER);
        vm.expectRevert(AtomWallet.AtomWallet_WrongArrayLengths.selector);
        atomWallet.executeBatch(destinations, values, functionCalls);
    }

    function test_executeBatch_revertsOnWrongArrayLengthValues() public {
        _claimWalletAs(NEW_OWNER);

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

        vm.prank(NEW_OWNER);
        vm.expectRevert(AtomWallet.AtomWallet_WrongArrayLengths.selector);
        atomWallet.executeBatch(destinations, values, functionCalls);
    }

    function test_executeBatch_revertsOnUnauthorizedUser() public {
        _claimWalletAs(NEW_OWNER);

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
        _claimWalletAs(NEW_OWNER);

        address[] memory destinations = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory functionCalls = new bytes[](0);

        vm.prank(NEW_OWNER);
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

        vm.startPrank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();
        vm.stopPrank();

        assertEq(atomWallet.getDeposit(), TEST_DEPOSIT_AMOUNT * 2);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW DEPOSIT FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawDepositTo_successfulByPrimaryOwner() public {
        _claimWalletAs(NEW_OWNER);

        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        uint256 balanceBefore = WITHDRAW_ADDRESS.balance;

        vm.prank(NEW_OWNER);
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), TEST_DEPOSIT_AMOUNT);

        assertEq(WITHDRAW_ADDRESS.balance, balanceBefore + TEST_DEPOSIT_AMOUNT);
        assertEq(atomWallet.getDeposit(), 0);
    }

    function test_withdrawDepositTo_successfulByCoSigner() public {
        _claimWalletAs(NEW_OWNER);
        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);

        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        uint256 balanceBefore = WITHDRAW_ADDRESS.balance;

        vm.prank(CO_SIGNER);
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), TEST_DEPOSIT_AMOUNT);

        assertEq(WITHDRAW_ADDRESS.balance, balanceBefore + TEST_DEPOSIT_AMOUNT);
        assertEq(atomWallet.getDeposit(), 0);
    }

    function test_withdrawDepositTo_successfulByWalletItself() public {
        _claimWalletAs(NEW_OWNER);

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
        _claimWalletAs(NEW_OWNER);

        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwnerOrEntryPoint.selector);
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), TEST_DEPOSIT_AMOUNT);
    }

    function test_withdrawDepositTo_handlesZeroAmount() public {
        _claimWalletAs(NEW_OWNER);

        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        uint256 balanceBefore = WITHDRAW_ADDRESS.balance;

        vm.prank(NEW_OWNER);
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), 0);

        assertEq(WITHDRAW_ADDRESS.balance, balanceBefore);
        assertEq(atomWallet.getDeposit(), TEST_DEPOSIT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_completeClaim_successful() public {
        vm.prank(address(ATOM_WARDEN));
        vm.expectEmit(true, true, true, true);
        emit AtomWallet.ClaimCompleted(address(ATOM_WARDEN), NEW_OWNER);
        atomWallet.completeClaim(NEW_OWNER);

        assertEq(atomWallet.owner(), NEW_OWNER);
        assertTrue(atomWallet.isClaimed());
        // Claimant is seeded into MultiOwnable at index 0
        assertTrue(atomWallet.isOwnerAddress(NEW_OWNER));
        assertEq(atomWallet.ownerCount(), 1);
        assertEq(atomWallet.nextOwnerIndex(), 1);
    }

    function test_completeClaim_revertsOnZeroAddress() public {
        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_InvalidClaimOwner.selector));
        atomWallet.completeClaim(address(0));
    }

    function test_completeClaim_revertsOnUnauthorizedUser() public {
        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_OnlyAtomWarden.selector));
        atomWallet.completeClaim(NEW_OWNER);
    }

    function test_completeClaim_revertsWhenAlreadyClaimed() public {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.completeClaim(NEW_OWNER);

        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_AlreadyClaimed.selector));
        atomWallet.completeClaim(users.alice);
    }

    function test_completeClaim_revertsWhenNewOwnerIsAtomWarden() public {
        // Defense-in-depth: handing the warden's own address as `newOwner` would make
        // `owner()` resolve to the warden post-claim and seed it as a MultiOwnable peer,
        // blurring the pre/post-claim distinction. The guard rejects it loudly.
        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_InvalidClaimOwner.selector));
        atomWallet.completeClaim(address(ATOM_WARDEN));
    }

    function test_transferOwnership_successfulAfterClaim() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.transferOwnership(users.alice);

        assertEq(atomWallet.owner(), users.alice);
        // MultiOwnable is kept in sync: old primary removed, new primary registered
        assertFalse(atomWallet.isOwnerAddress(NEW_OWNER));
        assertTrue(atomWallet.isOwnerAddress(users.alice));
    }

    function test_transferOwnership_emitsPrimaryOwnerTransferred() public {
        _claimWalletAs(NEW_OWNER);

        vm.expectEmit(true, true, false, false, address(atomWallet));
        emit AtomWallet.PrimaryOwnerTransferred(NEW_OWNER, users.alice);

        vm.prank(NEW_OWNER);
        atomWallet.transferOwnership(users.alice);
    }

    function test_transferOwnership_noRegressionWhenPromotingCoSigner() public {
        // Seed a co-signer, then rotate primary ownership to that co-signer.
        // Before the fix, this reverted with AlreadyOwner because transferOwnership
        // unconditionally added the new owner to MultiOwnable.
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);
        assertTrue(atomWallet.isOwnerAddress(CO_SIGNER));

        vm.prank(NEW_OWNER);
        atomWallet.transferOwnership(CO_SIGNER);

        assertEq(atomWallet.owner(), CO_SIGNER);
        assertFalse(atomWallet.isOwnerAddress(NEW_OWNER));
        assertTrue(atomWallet.isOwnerAddress(CO_SIGNER));
    }

    function test_transferOwnership_revertsBeforeClaim() public {
        // Pre-claim, MultiOwnable is empty so no external caller can pass the
        // peer-owner-or-self gate. The AtomWarden, which would have passed the
        // legacy OZ `onlyOwner` check via `owner()` resolution, is no longer in
        // the trust set for ownership rotation.
        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_OnlyOwner.selector));
        atomWallet.transferOwnership(NEW_OWNER);
    }

    function test_transferOwnership_revertsForZeroAddressAfterClaim() public {
        _claimWalletAs(NEW_OWNER);
        vm.prank(NEW_OWNER);
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_InvalidOwner.selector));
        atomWallet.transferOwnership(address(0));
    }

    function test_renounceOwnership_alwaysReverts() public {
        // Pre-claim: the legacy OZ `renounceOwnership` would have been callable by
        // `owner()` (i.e. the AtomWarden); the new explicit override hard-locks it.
        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_RenounceDisabled.selector));
        atomWallet.renounceOwnership();

        // Post-claim: same hard lock applies to the primary owner.
        _claimWalletAs(NEW_OWNER);
        vm.prank(NEW_OWNER);
        vm.expectRevert(abi.encodeWithSelector(AtomWallet.AtomWallet_RenounceDisabled.selector));
        atomWallet.renounceOwnership();
    }

    function test_ownerFunction_returnsATOM_WARDENWhenUnclaimed() public view {
        assertEq(atomWallet.owner(), address(ATOM_WARDEN));
    }

    function test_ownerFunction_returnsUserWhenClaimed() public {
        _claimWalletAs(NEW_OWNER);
        assertEq(atomWallet.owner(), NEW_OWNER);
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM FEES FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimAtomWalletDepositFees_successfulByPrimaryOwner() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.claimAtomWalletDepositFees();
    }

    function test_claimAtomWalletDepositFees_successfulByCoSigner() public {
        _claimWalletAs(NEW_OWNER);
        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);

        vm.prank(CO_SIGNER);
        atomWallet.claimAtomWalletDepositFees();
    }

    function test_claimAtomWalletDepositFees_revertsOnUnauthorizedUser() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwnerOrEntryPoint.selector);
        atomWallet.claimAtomWalletDepositFees();
    }

    /*//////////////////////////////////////////////////////////////
                        SIGNER MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_addOwnerAddress_successfulByPrimaryOwner() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);

        assertTrue(atomWallet.isOwnerAddress(CO_SIGNER));
        assertEq(atomWallet.ownerCount(), 2);
    }

    function test_addOwnerAddress_successfulByCoSigner() public {
        _claimWalletAs(NEW_OWNER);
        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);

        address secondaryCoSigner = address(0x5555);
        vm.prank(CO_SIGNER);
        atomWallet.addOwnerAddress(secondaryCoSigner);

        assertTrue(atomWallet.isOwnerAddress(secondaryCoSigner));
        assertEq(atomWallet.ownerCount(), 3);
    }

    function test_addOwnerAddress_revertsForUnauthorizedUser() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwner.selector);
        atomWallet.addOwnerAddress(CO_SIGNER);
    }

    function test_addOwnerPublicKey_successfulByCoSigner() public {
        _claimWalletAs(NEW_OWNER);
        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);

        bytes32 x = bytes32(uint256(0xAA));
        bytes32 y = bytes32(uint256(0xBB));

        vm.prank(CO_SIGNER);
        atomWallet.addOwnerPublicKey(x, y);

        assertTrue(atomWallet.isOwnerPublicKey(x, y));
        assertEq(atomWallet.ownerCount(), 3);
    }

    function test_removeOwnerAtIndex_successfulByCoSigner() public {
        _claimWalletAs(NEW_OWNER);
        vm.startPrank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);
        address secondaryCoSigner = address(0x5555);
        atomWallet.addOwnerAddress(secondaryCoSigner);
        vm.stopPrank();
        assertEq(atomWallet.ownerCount(), 3);

        // Co-signer removes the secondary co-signer at index 2
        bytes memory secondaryBytes = abi.encode(secondaryCoSigner);
        vm.prank(CO_SIGNER);
        atomWallet.removeOwnerAtIndex(2, secondaryBytes);

        assertFalse(atomWallet.isOwnerAddress(secondaryCoSigner));
        assertEq(atomWallet.ownerCount(), 2);
    }

    function test_removeOwnerAtIndex_revertsWhenRemovingPrimaryOwner() public {
        _claimWalletAs(NEW_OWNER);
        vm.prank(NEW_OWNER);
        atomWallet.addOwnerAddress(CO_SIGNER);

        // Primary owner is at index 0
        bytes memory primaryBytes = abi.encode(NEW_OWNER);

        vm.prank(CO_SIGNER);
        vm.expectRevert(AtomWallet.AtomWallet_OwnerCannotBeRemoved.selector);
        atomWallet.removeOwnerAtIndex(0, primaryBytes);
    }

    function test_signerManagement_revertsPreClaimWithOnlyOwner() public {
        // Pre-claim, MultiOwnable is empty and no external caller can satisfy the
        // peer-owner-or-self check. Revert selector is AtomWallet_OnlyOwner.
        vm.prank(address(ATOM_WARDEN));
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwner.selector);
        atomWallet.addOwnerAddress(CO_SIGNER);

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwner.selector);
        atomWallet.addOwnerPublicKey(bytes32(uint256(1)), bytes32(uint256(2)));

        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(AtomWallet.AtomWallet_OnlyOwner.selector);
        atomWallet.removeOwnerAtIndex(0, abi.encode(address(ATOM_WARDEN)));
    }

    /*//////////////////////////////////////////////////////////////
                            SIGNATURE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Regression lock for `AtomWallet._validateSignature`: the wallet packs
    ///      `validUntil = 0` and `validAfter = 0` into the returned validationData,
    ///      intentionally mirroring Coinbase Smart Wallet. Anti-replay therefore relies
    ///      entirely on EntryPoint-managed nonces, NOT on per-signature time windows.
    ///      If a future change wants to introduce bounded signatures, this test must
    ///      be deliberately updated as part of that change — a passing run here means
    ///      the unbounded-time-window posture is still in effect.
    function test_validateSignature_returnsZeroTimeBoundsByConstruction() public {
        vm.warp(BASE_TIMESTAMP);

        uint256 ownerPrivateKey = 0xA11CE;
        address expectedOwner = vm.addr(ownerPrivateKey);

        AtomWallet testWallet = _createClaimedWallet(expectedOwner);

        PackedUserOperation memory userOp = _createValidUserOpFor(testWallet);
        bytes32 userOpHash = mockEntryPoint.getUserOpHash(userOp);
        userOp.signature = _signUserOpCoinbase(ownerPrivateKey, 0, userOpHash);

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        // ERC-4337 packing: bits [0:160] = authorizer (0 on success), bits [160:208]
        // = validUntil, bits [208:256] = validAfter. Decode each window individually
        // so the assertion fails specifically against time-bound regressions rather
        // than catching them only via the bundled `_packValidationData` shape.
        uint48 decodedValidUntil = uint48(validationResult >> 160);
        uint48 decodedValidAfter = uint48(validationResult >> 208);

        assertEq(decodedValidUntil, 0, "validUntil must be 0 (no upper time bound)");
        assertEq(decodedValidAfter, 0, "validAfter must be 0 (no lower time bound)");
        // Sanity: this is the success authorizer (0), not SIG_VALIDATION_FAILED (1).
        assertEq(uint160(validationResult), 0, "authorizer slot must be 0 on success");
    }

    function test_validateSignature_successfulPostClaimWithWrapper() public {
        vm.warp(BASE_TIMESTAMP);

        uint256 ownerPrivateKey = 0xA11CE;
        address expectedOwner = vm.addr(ownerPrivateKey);

        AtomWallet testWallet = _createClaimedWallet(expectedOwner);

        PackedUserOperation memory userOp = _createValidUserOpFor(testWallet);
        bytes32 userOpHash = mockEntryPoint.getUserOpHash(userOp);
        userOp.signature = _signUserOpCoinbase(ownerPrivateKey, 0, userOpHash);

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, _packValidationData(false, 0, 0));
    }

    function test_validateSignature_returnsSigFailedPostClaimWithWrongSigner() public {
        vm.warp(BASE_TIMESTAMP);

        uint256 ownerPrivateKey = 0xA11CE;
        uint256 wrongPrivateKey = 0xB0B;
        address expectedOwner = vm.addr(ownerPrivateKey);

        AtomWallet testWallet = _createClaimedWallet(expectedOwner);

        PackedUserOperation memory userOp = _createValidUserOpFor(testWallet);
        bytes32 userOpHash = mockEntryPoint.getUserOpHash(userOp);
        // Sign with the wrong key but point the wrapper at owner index 0 (primary owner)
        userOp.signature = _signUserOpCoinbase(wrongPrivateKey, 0, userOpHash);

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, SIG_VALIDATION_FAILED);
    }

    function test_validateSignature_returnsSigFailedPreClaim() public {
        vm.warp(BASE_TIMESTAMP);

        // Pre-claim: MultiOwnable registry is empty — any signature fails to decode/dispatch
        uint256 signerPk = 0x1;
        PackedUserOperation memory userOp = _createValidUserOpFor(atomWallet);
        bytes32 userOpHash = mockEntryPoint.getUserOpHash(userOp);
        userOp.signature = _signUserOpCoinbase(signerPk, 0, userOpHash);

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = atomWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, SIG_VALIDATION_FAILED);
    }

    function test_validateSignature_returnsSigFailedOnInvalidSignatureLength() public {
        vm.warp(BASE_TIMESTAMP);

        uint256 ownerPrivateKey = 0xA11CE;
        address expectedOwner = vm.addr(ownerPrivateKey);
        AtomWallet testWallet = _createClaimedWallet(expectedOwner);

        PackedUserOperation memory userOp = _createValidUserOpFor(testWallet);
        bytes32 userOpHash = mockEntryPoint.getUserOpHash(userOp);
        userOp.signature = hex"deadbeef"; // Too short to decode as SignatureWrapper

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, SIG_VALIDATION_FAILED);
    }

    function test_validateSignature_returnsSigFailedOnInvalidSignatureSValue() public {
        vm.warp(BASE_TIMESTAMP);

        uint256 ownerPrivateKey = 0xA11CE;
        address expectedOwner = vm.addr(ownerPrivateKey);
        AtomWallet testWallet = _createClaimedWallet(expectedOwner);

        PackedUserOperation memory userOp = _createValidUserOpFor(testWallet);
        bytes32 userOpHash = mockEntryPoint.getUserOpHash(userOp);

        bytes32 signatureR = bytes32(uint256(1));
        bytes32 invalidSignatureS = bytes32(SECP256K1_CURVE_ORDER);
        uint8 signatureV = 27;
        bytes memory rawSig = abi.encodePacked(signatureR, invalidSignatureS, signatureV);
        userOp.signature = abi.encode(uint256(0), rawSig);

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, SIG_VALIDATION_FAILED);
    }

    function test_validateSignature_rejectsReplayAcrossEntryPointDomains() public {
        vm.warp(BASE_TIMESTAMP);

        uint256 ownerPrivateKey = 0xA11CE;
        address expectedOwner = vm.addr(ownerPrivateKey);
        AtomWallet testWallet = _createClaimedWallet(expectedOwner);

        PackedUserOperation memory userOp = _createValidUserOpFor(testWallet);
        bytes32 canonicalUserOpHash = mockEntryPoint.getUserOpHash(userOp);
        userOp.signature = _signUserOpCoinbase(ownerPrivateKey, 0, canonicalUserOpHash);

        MockEntryPoint alternateEntryPoint = new MockEntryPoint();
        bytes32 replayedUserOpHash = alternateEntryPoint.getUserOpHash(userOp);

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, replayedUserOpHash, 0);

        assertEq(validationResult, SIG_VALIDATION_FAILED);
    }

    function test_validateSignature_rejectsReplayAcrossChainIds() public {
        vm.warp(BASE_TIMESTAMP);

        uint256 ownerPrivateKey = 0xA11CE;
        address expectedOwner = vm.addr(ownerPrivateKey);
        AtomWallet testWallet = _createClaimedWallet(expectedOwner);

        PackedUserOperation memory userOp = _createValidUserOpFor(testWallet);
        bytes32 canonicalUserOpHash = mockEntryPoint.getUserOpHash(userOp);
        userOp.signature = _signUserOpCoinbase(ownerPrivateKey, 0, canonicalUserOpHash);

        vm.chainId(block.chainid + 1);
        bytes32 replayedUserOpHash = mockEntryPoint.getUserOpHash(userOp);

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, replayedUserOpHash, 0);

        assertEq(validationResult, SIG_VALIDATION_FAILED);
    }

    /*//////////////////////////////////////////////////////////////
                            FACTORY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_factory_deployAtomWallet_successful() public {
        vm.startPrank(users.alice);
        bytes memory atomData = bytes("New test atom");
        bytes32 atomId = calculateAtomId(atomData);
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
        bytes32 invalidAtomId = bytes32(uint256(123));

        vm.expectRevert(AtomWalletFactory.AtomWalletFactory_TermDoesNotExist.selector);
        protocol.atomWalletFactory.deployAtomWallet(invalidAtomId);
    }

    function test_factory_deployAtomWallet_revertsOnTripleId() public {
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
        bytes32 newAtomId = calculateAtomId(bytes("New test atom"));

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

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        freshFactory.initialize(address(protocol.multiVault));
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_integration_fullOwnershipTransferFlow() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.transferOwnership(users.alice);

        assertEq(atomWallet.owner(), users.alice);
        assertTrue(atomWallet.isClaimed());
        assertTrue(atomWallet.isOwnerAddress(users.alice));
        assertFalse(atomWallet.isOwnerAddress(NEW_OWNER));

        vm.prank(users.alice);
        atomWallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    function test_integration_depositAndWithdrawFlow() public {
        _claimWalletAs(NEW_OWNER);

        vm.deal(users.alice, TEST_DEPOSIT_AMOUNT);
        vm.prank(users.alice);
        atomWallet.addDeposit{ value: TEST_DEPOSIT_AMOUNT }();

        assertEq(atomWallet.getDeposit(), TEST_DEPOSIT_AMOUNT);

        uint256 balanceBefore = WITHDRAW_ADDRESS.balance;

        vm.prank(NEW_OWNER);
        atomWallet.withdrawDepositTo(payable(WITHDRAW_ADDRESS), TEST_DEPOSIT_AMOUNT);

        assertEq(WITHDRAW_ADDRESS.balance, balanceBefore + TEST_DEPOSIT_AMOUNT);
        assertEq(atomWallet.getDeposit(), 0);
    }

    function test_integration_factoryDeployAndWalletUsage() public {
        vm.startPrank(users.alice);
        bytes memory atomData = bytes("New test atom");
        bytes32 newAtomId = calculateAtomId(atomData);
        uint256 atomCost = protocol.multiVault.getAtomCost();

        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = atomData;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = atomCost;
        protocol.multiVault.createAtoms{ value: atomCost }(atomDataArray, amounts);
        vm.stopPrank();

        address deployedWallet = protocol.atomWalletFactory.deployAtomWallet(newAtomId);
        AtomWallet wallet = AtomWallet(payable(deployedWallet));

        vm.deal(deployedWallet, TEST_AMOUNT);

        // Claim before usage — pre-claim wallets are dormant
        vm.prank(address(ATOM_WARDEN));
        wallet.completeClaim(NEW_OWNER);

        vm.prank(NEW_OWNER);
        wallet.execute(CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        assertEq(CALL_TARGET.balance, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_execute_validParameters(address target, uint256 value, bytes calldata data) external {
        _excludeReservedAddresses(target);

        _claimWalletAs(NEW_OWNER);

        value = bound(value, 0, address(atomWallet).balance);

        uint256 targetBalanceBefore = target.balance;

        vm.prank(NEW_OWNER);
        atomWallet.execute(target, value, data);

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

        _claimWalletAs(users.alice);

        vm.prank(users.alice);
        atomWallet.transferOwnership(newOwner);

        assertEq(atomWallet.owner(), newOwner);
        assertTrue(atomWallet.isOwnerAddress(newOwner));
    }

    function testFuzz_executeBatch_validParameters(uint256 numberOfCalls, uint256 baseValue) external {
        numberOfCalls = bound(numberOfCalls, 1, 10);
        baseValue = bound(baseValue, 0, 1 ether);

        _claimWalletAs(NEW_OWNER);

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

        vm.prank(NEW_OWNER);
        atomWallet.executeBatch(destinations, values, functionCalls);

        for (uint256 i = 0; i < numberOfCalls; i++) {
            assertEq(destinations[i].balance, values[i]);
        }
    }

    function testFuzz_validateSignature_postClaim(uint256 ownerPrivateKey, bytes32 userOpHashSeed) external {
        vm.warp(BASE_TIMESTAMP);
        ownerPrivateKey = bound(ownerPrivateKey, 1, SECP256K1_CURVE_ORDER - 1);
        address expectedOwner = vm.addr(ownerPrivateKey);

        AtomWallet testWallet = _createClaimedWallet(expectedOwner);

        PackedUserOperation memory userOp = _createValidUserOpFor(testWallet);
        userOp.nonce = uint256(userOpHashSeed);
        bytes32 userOpHash = mockEntryPoint.getUserOpHash(userOp);
        userOp.signature = _signUserOpCoinbase(ownerPrivateKey, 0, userOpHash);

        vm.prank(address(mockEntryPoint));
        uint256 validationResult = testWallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(validationResult, _packValidationData(false, 0, 0));
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_edge_multipleOwnershipTransfers() public {
        _claimWalletAs(NEW_OWNER);

        vm.prank(NEW_OWNER);
        atomWallet.transferOwnership(users.alice);
        assertTrue(atomWallet.isOwnerAddress(users.alice));
        assertFalse(atomWallet.isOwnerAddress(NEW_OWNER));

        vm.prank(users.alice);
        atomWallet.transferOwnership(users.bob);
        assertTrue(atomWallet.isOwnerAddress(users.bob));
        assertFalse(atomWallet.isOwnerAddress(users.alice));

        assertEq(atomWallet.owner(), users.bob);
    }

    function test_edge_executeWithAllWalletBalance() public {
        _claimWalletAs(NEW_OWNER);

        uint256 walletBalance = address(atomWallet).balance;

        vm.prank(NEW_OWNER);
        atomWallet.execute(CALL_TARGET, walletBalance, "");

        assertEq(CALL_TARGET.balance, walletBalance);
        assertEq(address(atomWallet).balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-1271 isValidSignature TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isValidSignature_returnsFailurePreClaim() public view {
        // Pre-claim: empty MultiOwnable registry → all signatures invalid
        bytes32 hash = keccak256("test message");
        bytes memory signature = abi.encode(uint256(0), hex"00");

        bytes4 result = atomWallet.isValidSignature(hash, signature);
        assertEq(result, bytes4(0xffffffff));
    }

    function test_isValidSignature_returnsFailureForInvalidSignature() public view {
        bytes32 hash = keccak256("test message");
        bytes memory invalidSignature = hex"deadbeef";

        bytes4 result = atomWallet.isValidSignature(hash, invalidSignature);
        assertEq(result, bytes4(0xffffffff));
    }

    function test_isValidSignature_returnsSuccessAfterClaim() public {
        uint256 claimantPrivateKey = 0xC1A1;
        address claimant = vm.addr(claimantPrivateKey);

        vm.prank(address(ATOM_WARDEN));
        atomWallet.completeClaim(claimant);
        assertTrue(atomWallet.isClaimed());
        assertEq(atomWallet.owner(), claimant);

        bytes32 hash = keccak256("post-claim message");
        bytes memory signature = _signAndWrapReplaySafe(claimantPrivateKey, 0, hash, atomWallet);

        bytes4 result = atomWallet.isValidSignature(hash, signature);
        assertEq(result, bytes4(0x1626ba7e));
    }

    function test_isValidSignature_returnsFailureForWrongSignerAfterClaim() public {
        uint256 claimantPrivateKey = 0xC1A1;
        uint256 wrongPrivateKey = 0xDEAD;
        address claimant = vm.addr(claimantPrivateKey);

        vm.prank(address(ATOM_WARDEN));
        atomWallet.completeClaim(claimant);

        bytes32 hash = keccak256("post-claim message");
        bytes memory signature = _signAndWrapReplaySafe(wrongPrivateKey, 0, hash, atomWallet);

        bytes4 result = atomWallet.isValidSignature(hash, signature);
        assertEq(result, bytes4(0xffffffff));
    }

    function testFuzz_isValidSignature_validOwner(uint256 ownerPrivateKey, bytes32 hash) public {
        ownerPrivateKey = bound(ownerPrivateKey, 1, SECP256K1_CURVE_ORDER - 1);
        address claimant = vm.addr(ownerPrivateKey);

        AtomWallet testWallet = _createClaimedWallet(claimant);

        bytes memory signature = _signAndWrapReplaySafe(ownerPrivateKey, 0, hash, testWallet);

        bytes4 result = testWallet.isValidSignature(hash, signature);
        assertEq(result, bytes4(0x1626ba7e));
    }

    function test_isValidSignature_rejectsCrossWalletReplay() public {
        uint256 claimantPrivateKey = 0xC1A1;
        address claimant = vm.addr(claimantPrivateKey);
        AtomWallet firstWallet = _createClaimedWallet(claimant);
        AtomWallet secondWallet = _createClaimedWallet(claimant);
        bytes32 hash = keccak256("wallet-specific authorization");
        bytes memory signature = _signAndWrapReplaySafe(claimantPrivateKey, 0, hash, firstWallet);

        assertEq(firstWallet.isValidSignature(hash, signature), bytes4(0x1626ba7e));
        assertEq(secondWallet.isValidSignature(hash, signature), bytes4(0xffffffff));
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN RECEIVER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_onERC721Received_returnsCorrectSelector() public {
        (bool success, bytes memory data) = address(atomWallet)
            .call(
                abi.encodeWithSelector(
                    IERC721Receiver.onERC721Received.selector, address(0), address(0), uint256(0), ""
                )
            );
        assertTrue(success);
        assertEq(abi.decode(data, (bytes4)), IERC721Receiver.onERC721Received.selector);
    }

    function test_onERC1155Received_returnsCorrectSelector() public {
        (bool success, bytes memory data) = address(atomWallet)
            .call(
                abi.encodeWithSelector(
                    IERC1155Receiver.onERC1155Received.selector, address(0), address(0), uint256(0), uint256(0), ""
                )
            );
        assertTrue(success);
        assertEq(abi.decode(data, (bytes4)), IERC1155Receiver.onERC1155Received.selector);
    }

    function test_onERC1155BatchReceived_returnsCorrectSelector() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        (bool success, bytes memory data) = address(atomWallet)
            .call(
                abi.encodeWithSelector(
                    IERC1155Receiver.onERC1155BatchReceived.selector, address(0), address(0), ids, amounts, ""
                )
            );
        assertTrue(success);
        assertEq(abi.decode(data, (bytes4)), IERC1155Receiver.onERC1155BatchReceived.selector);
    }

    function test_supportsInterface_reportsCorrectInterfaces() public view {
        assertTrue(atomWallet.supportsInterface(type(IERC165).interfaceId));
        assertTrue(atomWallet.supportsInterface(type(IERC1271).interfaceId));
        assertTrue(atomWallet.supportsInterface(bytes4(0x150b7a02))); // IERC721Receiver
        assertTrue(atomWallet.supportsInterface(bytes4(0x4e2312e0))); // IERC1155Receiver

        assertFalse(atomWallet.supportsInterface(bytes4(0xdeadbeef)));
    }

    /*//////////////////////////////////////////////////////////////
                    ADDRESS STABILITY ACROSS BEACON UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_beaconUpgrade_preservesComputedWalletAddresses() public {
        bytes[] memory atomDataArray = new bytes[](3);
        atomDataArray[0] = bytes("address-stability-atom-1");
        atomDataArray[1] = bytes("address-stability-atom-2");
        atomDataArray[2] = bytes("address-stability-atom-3");

        uint256 atomCost = protocol.multiVault.getAtomCost();
        uint256[] memory atomAmounts = new uint256[](3);
        atomAmounts[0] = atomCost;
        atomAmounts[1] = atomCost;
        atomAmounts[2] = atomCost;

        vm.prank(users.alice);
        protocol.multiVault.createAtoms{ value: atomCost * 3 }(atomDataArray, atomAmounts);

        bytes32 atomId1 = calculateAtomId(atomDataArray[0]);
        bytes32 atomId2 = calculateAtomId(atomDataArray[1]);
        bytes32 atomId3 = calculateAtomId(atomDataArray[2]);

        address preAddr1 = protocol.atomWalletFactory.computeAtomWalletAddr(atomId1);
        address preAddr2 = protocol.atomWalletFactory.computeAtomWalletAddr(atomId2);
        address preAddr3 = protocol.atomWalletFactory.computeAtomWalletAddr(atomId3);

        address deployedAddr = protocol.atomWalletFactory.deployAtomWallet(atomId1);
        assertEq(deployedAddr, preAddr1);

        AtomWallet newImpl = new AtomWallet();
        vm.prank(users.admin);
        protocol.atomWalletBeacon.upgradeTo(address(newImpl));

        address postAddr1 = protocol.atomWalletFactory.computeAtomWalletAddr(atomId1);
        address postAddr2 = protocol.atomWalletFactory.computeAtomWalletAddr(atomId2);
        address postAddr3 = protocol.atomWalletFactory.computeAtomWalletAddr(atomId3);

        assertEq(preAddr1, postAddr1, "Deployed wallet address changed after beacon upgrade");
        assertEq(preAddr2, postAddr2, "Undeployed wallet 2 address changed after beacon upgrade");
        assertEq(preAddr3, postAddr3, "Undeployed wallet 3 address changed after beacon upgrade");

        AtomWallet upgradedWallet = AtomWallet(payable(deployedAddr));
        assertEq(address(upgradedWallet.multiVault()), address(protocol.multiVault));
        assertEq(upgradedWallet.termId(), atomId1);

        address postDeployAddr2 = protocol.atomWalletFactory.deployAtomWallet(atomId2);
        assertEq(postDeployAddr2, postAddr2, "Post-upgrade deployed address doesn't match prediction");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Claims the shared `atomWallet` as `claimant` (prank as AtomWarden).
    function _claimWalletAs(address claimant) internal {
        vm.prank(address(ATOM_WARDEN));
        atomWallet.completeClaim(claimant);
    }

    /// @dev Deploys a fresh AtomWallet proxy and claims it as `claimant`.
    function _createClaimedWallet(address claimant) internal returns (AtomWallet) {
        AtomWallet freshWallet = new AtomWallet();
        TransparentUpgradeableProxy atomWalletProxy =
            new TransparentUpgradeableProxy(address(freshWallet), users.admin, "");
        freshWallet = AtomWallet(payable(address(atomWalletProxy)));

        freshWallet.initialize(address(mockEntryPoint), address(protocol.multiVault), TEST_ATOM_ID);

        vm.prank(address(ATOM_WARDEN));
        freshWallet.completeClaim(claimant);

        return freshWallet;
    }

    function _createValidUserOpFor(AtomWallet targetWallet) internal view returns (PackedUserOperation memory) {
        bytes memory callData =
            abi.encodeWithSelector(targetWallet.execute.selector, CALL_TARGET, TEST_AMOUNT, TEST_CALLDATA);

        return PackedUserOperation({
            sender: address(targetWallet),
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

    /// @dev Signs a UserOp hash with the EIP-191 prefix applied, then wraps the ECDSA
    ///      signature into the Coinbase SignatureWrapper format expected by
    ///      `_validateSignature` (ownerIndex + raw signature bytes).
    function _signUserOpCoinbase(uint256 signerPrivateKey, uint256 ownerIndex, bytes32 userOpHash)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);
        bytes memory rawSig = abi.encodePacked(r, s, v);
        return abi.encode(ownerIndex, rawSig);
    }

    /// @dev Signs the wallet- and chain-bound replay-safe digest and wraps it in the
    ///      Coinbase SignatureWrapper format expected by `isValidSignature` (ERC-1271).
    function _signAndWrapReplaySafe(uint256 signerPrivateKey, uint256 ownerIndex, bytes32 hash, AtomWallet targetWallet)
        internal
        view
        returns (bytes memory)
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("AtomWallet")),
                keccak256(bytes("1")),
                block.chainid,
                address(targetWallet)
            )
        );
        bytes32 messageHash = keccak256(abi.encode(keccak256("CoinbaseSmartWalletMessage(bytes32 hash)"), hash));
        bytes32 replaySafeHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, replaySafeHash);
        bytes memory rawSig = abi.encodePacked(r, s, v);
        return abi.encode(ownerIndex, rawSig);
    }
}

contract MockRevertingContract {
    function revertFunction() external pure {
        revert("MockRevertingContract: revert");
    }
}
