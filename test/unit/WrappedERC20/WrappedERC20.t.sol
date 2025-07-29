// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {WrappedERC20} from "src/v2/WrappedERC20.sol";
import {WrappedERC20Factory} from "src/v2/WrappedERC20Factory.sol";
import {Errors} from "src/libraries/Errors.sol";
import {IWrappedERC20} from "src/interfaces/IWrappedERC20.sol";
import {IWrappedERC20Factory} from "src/interfaces/IWrappedERC20Factory.sol";
import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {MultiVaultBase} from "test/MultiVaultBase.sol";

contract WrappedERC20Test is MultiVaultBase {
    address public constant UNAUTHORIZED_USER = address(0x9999);
    address public constant WRAPPER_USER = address(0x1111);

    bytes public constant TEST_ATOM_DATA = bytes("Test atom for wrapper");
    bytes32 public constant TEST_ATOM_ID = keccak256(abi.encodePacked(TEST_ATOM_DATA));
    string public constant TEST_NAME = "Test Wrapped Token";
    string public constant TEST_SYMBOL = "TWT";
    uint256 public constant TEST_BONDING_CURVE_ID = 1;
    uint256 public constant TEST_SHARES = 1000e18;
    uint256 public constant TEST_DEPOSIT_AMOUNT = 10e18;

    WrappedERC20 public wrappedToken;
    address public wrappedTokenAddress;

    event Wrapped(address indexed from, address indexed to, bytes32 termId, uint256 curveId, uint256 shares);
    event Unwrapped(address indexed from, address indexed to, bytes32 termId, uint256 curveId, uint256 shares);

    function setUp() public override {
        super.setUp();

        vm.startPrank(alice);
        uint256 atomCost = multiVault.getAtomCost();
        trustToken.mint(alice, atomCost);
        trustToken.approve(address(multiVault), atomCost);
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = TEST_ATOM_DATA;
        multiVault.createAtoms(atomDataArray, atomCost);
        vm.stopPrank();

        (, address existingFactory) = multiVault.wrapperConfig();
        wrappedERC20Factory = WrappedERC20Factory(existingFactory);

        vm.prank(admin);
        wrappedTokenAddress =
            wrappedERC20Factory.deployWrapper(TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);
        wrappedToken = WrappedERC20(wrappedTokenAddress);

        vm.startPrank(alice);
        trustToken.mint(alice, TEST_DEPOSIT_AMOUNT);
        trustToken.approve(address(multiVault), TEST_DEPOSIT_AMOUNT);
        multiVault.deposit(alice, TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_DEPOSIT_AMOUNT, 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        WRAPPEDERC20 INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_successful() public {
        WrappedERC20 freshToken = new WrappedERC20();
        TransparentUpgradeableProxy tokenProxy = new TransparentUpgradeableProxy(address(freshToken), admin, "");
        freshToken = WrappedERC20(address(tokenProxy));

        freshToken.initialize(address(multiVault), TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);

        assertEq(address(freshToken.multiVault()), address(multiVault));
        assertEq(freshToken.termId(), TEST_ATOM_ID);
        assertEq(freshToken.bondingCurveId(), TEST_BONDING_CURVE_ID);
        assertEq(freshToken.name(), TEST_NAME);
        assertEq(freshToken.symbol(), TEST_SYMBOL);
    }

    function test_initialize_revertsOnZeroAddress() public {
        WrappedERC20 freshToken = new WrappedERC20();
        TransparentUpgradeableProxy tokenProxy = new TransparentUpgradeableProxy(address(freshToken), admin, "");
        freshToken = WrappedERC20(address(tokenProxy));

        vm.expectRevert(abi.encodeWithSelector(Errors.WrappedERC20_ZeroAddress.selector));
        freshToken.initialize(address(0), TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);
    }

    function test_initialize_revertsOnDoubleInitialization() public {
        WrappedERC20 freshToken = new WrappedERC20();
        TransparentUpgradeableProxy tokenProxy = new TransparentUpgradeableProxy(address(freshToken), admin, "");
        freshToken = WrappedERC20(address(tokenProxy));

        freshToken.initialize(address(multiVault), TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);

        vm.expectRevert();
        freshToken.initialize(address(multiVault), TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);
    }

    function test_initialState() public view {
        assertEq(address(wrappedToken.multiVault()), address(multiVault));
        assertEq(wrappedToken.termId(), TEST_ATOM_ID);
        assertEq(wrappedToken.bondingCurveId(), TEST_BONDING_CURVE_ID);
        assertEq(wrappedToken.name(), TEST_NAME);
        assertEq(wrappedToken.symbol(), TEST_SYMBOL);
        assertEq(wrappedToken.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            WRAP FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_wrap_successful() public {
        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.BOTH);

        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Wrapped(alice, address(wrappedToken), TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_SHARES);
        wrappedToken.wrap(TEST_SHARES);

        assertEq(wrappedToken.balanceOf(alice), TEST_SHARES);
        assertEq(wrappedToken.totalSupply(), TEST_SHARES);
    }

    function test_wrap_revertsOnZeroShares() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.WrappedERC20_ZeroShares.selector));
        wrappedToken.wrap(0);
    }

    function test_wrap_revertsOnInsufficientShares() public {
        vm.mockCallRevert(
            address(multiVault),
            abi.encodeWithSelector(multiVault.wrapperTransfer.selector),
            abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector)
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InsufficientBalance.selector));
        wrappedToken.wrap(TEST_SHARES);
    }

    function test_wrap_revertsOnNotApproved() public {
        vm.mockCallRevert(
            address(multiVault),
            abi.encodeWithSelector(multiVault.wrapperTransfer.selector),
            abi.encodeWithSelector(Errors.MultiVault_SenderNotApproved.selector)
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_SenderNotApproved.selector));
        wrappedToken.wrap(TEST_SHARES);
    }

    function test_wrap_multipleUsers() public {
        vm.startPrank(bob);
        trustToken.mint(bob, TEST_DEPOSIT_AMOUNT);
        trustToken.approve(address(multiVault), TEST_DEPOSIT_AMOUNT);
        multiVault.deposit(bob, TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_DEPOSIT_AMOUNT, 0);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.BOTH);
        vm.stopPrank();

        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.BOTH);

        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(TEST_SHARES / 2);

        vm.prank(bob);
        wrappedToken.wrap(TEST_SHARES / 2);

        assertEq(wrappedToken.balanceOf(alice), TEST_SHARES / 2);
        assertEq(wrappedToken.balanceOf(bob), TEST_SHARES / 2);
        assertEq(wrappedToken.totalSupply(), TEST_SHARES);
    }

    /*//////////////////////////////////////////////////////////////
                            UNWRAP FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_unwrap_successful() public {
        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(TEST_SHARES);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Unwrapped(alice, address(wrappedToken), TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_SHARES);
        wrappedToken.unwrap(TEST_SHARES);

        assertEq(wrappedToken.balanceOf(alice), 0);
        assertEq(wrappedToken.totalSupply(), 0);
    }

    function test_unwrap_revertsOnZeroTokens() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.WrappedERC20_ZeroTokens.selector));
        wrappedToken.unwrap(0);
    }

    function test_unwrap_revertsOnInsufficientTokens() public {
        vm.prank(alice);
        vm.expectRevert();
        wrappedToken.unwrap(TEST_SHARES);
    }

    function test_unwrap_partialAmount() public {
        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(TEST_SHARES);

        uint256 unwrapAmount = TEST_SHARES / 2;

        vm.prank(alice);
        wrappedToken.unwrap(unwrapAmount);

        assertEq(wrappedToken.balanceOf(alice), TEST_SHARES - unwrapAmount);
        assertEq(wrappedToken.totalSupply(), TEST_SHARES - unwrapAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 STANDARD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transfer_successful() public {
        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(TEST_SHARES);

        vm.prank(alice);
        wrappedToken.transfer(bob, TEST_SHARES / 2);

        assertEq(wrappedToken.balanceOf(alice), TEST_SHARES / 2);
        assertEq(wrappedToken.balanceOf(bob), TEST_SHARES / 2);
    }

    function test_approve_successful() public {
        vm.prank(alice);
        wrappedToken.approve(bob, TEST_SHARES);

        assertEq(wrappedToken.allowance(alice, bob), TEST_SHARES);
    }

    function test_transferFrom_successful() public {
        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(TEST_SHARES);

        vm.prank(alice);
        wrappedToken.approve(bob, TEST_SHARES);

        vm.prank(bob);
        wrappedToken.transferFrom(alice, WRAPPER_USER, TEST_SHARES);

        assertEq(wrappedToken.balanceOf(alice), 0);
        assertEq(wrappedToken.balanceOf(WRAPPER_USER), TEST_SHARES);
        assertEq(wrappedToken.allowance(alice, bob), 0);
    }

    function test_transferFrom_revertsOnInsufficientAllowance() public {
        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(TEST_SHARES);

        vm.prank(bob);
        vm.expectRevert();
        wrappedToken.transferFrom(alice, WRAPPER_USER, TEST_SHARES);
    }

    /*//////////////////////////////////////////////////////////////
                        FACTORY INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_factory_initialize_successful() public {
        WrappedERC20Factory freshFactory = new WrappedERC20Factory();
        TransparentUpgradeableProxy factoryProxy = new TransparentUpgradeableProxy(address(freshFactory), admin, "");
        freshFactory = WrappedERC20Factory(address(factoryProxy));

        freshFactory.initialize(address(multiVault));

        assertEq(address(freshFactory.multiVault()), address(multiVault));
    }

    function test_factory_initialize_revertsOnZeroAddress() public {
        WrappedERC20Factory freshFactory = new WrappedERC20Factory();
        TransparentUpgradeableProxy factoryProxy = new TransparentUpgradeableProxy(address(freshFactory), admin, "");
        freshFactory = WrappedERC20Factory(address(factoryProxy));

        vm.expectRevert(abi.encodeWithSelector(Errors.WrappedERC20Factory_ZeroAddress.selector));
        freshFactory.initialize(address(0));
    }

    function test_factory_initialize_revertsOnDoubleInitialization() public {
        WrappedERC20Factory freshFactory = new WrappedERC20Factory();
        TransparentUpgradeableProxy factoryProxy = new TransparentUpgradeableProxy(address(freshFactory), admin, "");
        freshFactory = WrappedERC20Factory(address(factoryProxy));

        freshFactory.initialize(address(multiVault));

        vm.expectRevert();
        freshFactory.initialize(address(multiVault));
    }

    /*//////////////////////////////////////////////////////////////
                        FACTORY DEPLOY WRAPPER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_factory_deployWrapper_successful() public {
        bytes32 newAtomId = keccak256(abi.encodePacked("New test atom"));

        vm.startPrank(alice);
        uint256 atomCost = multiVault.getAtomCost();
        trustToken.mint(alice, atomCost);
        trustToken.approve(address(multiVault), atomCost);
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = "New test atom";
        multiVault.createAtoms(atomDataArray, atomCost);
        vm.stopPrank();

        vm.prank(admin);
        address deployedWrapper =
            wrappedERC20Factory.deployWrapper(newAtomId, TEST_BONDING_CURVE_ID, "New Wrapper", "NW");

        assertTrue(deployedWrapper != address(0));

        WrappedERC20 wrapper = WrappedERC20(deployedWrapper);
        assertEq(wrapper.termId(), newAtomId);
        assertEq(wrapper.bondingCurveId(), TEST_BONDING_CURVE_ID);
        assertEq(wrapper.name(), "New Wrapper");
        assertEq(wrapper.symbol(), "NW");
    }

    function test_factory_deployWrapper_returnsExistingWrapper() public {
        vm.prank(admin);
        address firstDeployment =
            wrappedERC20Factory.deployWrapper(TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);

        vm.prank(admin);
        address secondDeployment =
            wrappedERC20Factory.deployWrapper(TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);

        assertEq(firstDeployment, secondDeployment);
    }

    function test_factory_deployWrapper_revertsOnNonAdmin() public {
        vm.prank(UNAUTHORIZED_USER);
        vm.expectRevert(abi.encodeWithSelector(Errors.WrappedERC20Factory_OnlyAdmin.selector));
        wrappedERC20Factory.deployWrapper(TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);
    }

    function test_factory_deployWrapper_revertsOnInvalidTermId() public {
        bytes32 invalidTermId = bytes32(0);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_TermDoesNotExist.selector));
        wrappedERC20Factory.deployWrapper(invalidTermId, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);
    }

    function test_factory_deployWrapper_revertsOnInvalidBondingCurveId() public {
        uint256 invalidCurveId = 999;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.MultiVault_InvalidBondingCurveId.selector));
        wrappedERC20Factory.deployWrapper(TEST_ATOM_ID, invalidCurveId, TEST_NAME, TEST_SYMBOL);
    }

    function test_factory_deployWrapper_emitsEvent() public {
        bytes32 newAtomId = keccak256(abi.encodePacked("New test atom"));

        vm.startPrank(alice);
        uint256 atomCost = multiVault.getAtomCost();
        trustToken.mint(alice, atomCost);
        trustToken.approve(address(multiVault), atomCost);
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = "New test atom";
        multiVault.createAtoms(atomDataArray, atomCost);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectEmit(true, true, true, false);
        emit IWrappedERC20Factory.WrappedERC20Deployed(newAtomId, TEST_BONDING_CURVE_ID, address(0));
        wrappedERC20Factory.deployWrapper(newAtomId, TEST_BONDING_CURVE_ID, "New Wrapper", "NW");
    }

    /*//////////////////////////////////////////////////////////////
                        FACTORY COMPUTE ADDRESS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_factory_computeWrappedERC20Address_consistency() public view {
        address computedAddress1 =
            wrappedERC20Factory.computeWrappedERC20Address(TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);
        address computedAddress2 =
            wrappedERC20Factory.computeWrappedERC20Address(TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);

        assertEq(computedAddress1, computedAddress2);
    }

    function test_factory_computeWrappedERC20Address_matchesDeployedAddress() public view {
        address computedAddress =
            wrappedERC20Factory.computeWrappedERC20Address(TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);

        assertEq(computedAddress, wrappedTokenAddress);
    }

    function test_factory_computeWrappedERC20Address_differentForDifferentParams() public view {
        address address1 =
            wrappedERC20Factory.computeWrappedERC20Address(TEST_ATOM_ID, TEST_BONDING_CURVE_ID, TEST_NAME, TEST_SYMBOL);

        address address2 = wrappedERC20Factory.computeWrappedERC20Address(
            TEST_ATOM_ID, TEST_BONDING_CURVE_ID + 1, TEST_NAME, TEST_SYMBOL
        );

        assertTrue(address1 != address2);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_integration_fullWrapUnwrapFlow() public {
        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(TEST_SHARES);

        assertEq(wrappedToken.balanceOf(alice), TEST_SHARES);
        assertEq(wrappedToken.totalSupply(), TEST_SHARES);

        vm.prank(alice);
        wrappedToken.unwrap(TEST_SHARES);

        assertEq(wrappedToken.balanceOf(alice), 0);
        assertEq(wrappedToken.totalSupply(), 0);
    }

    function test_integration_factoryDeployAndTokenUsage() public {
        bytes32 newAtomId = keccak256(abi.encodePacked("New test atom"));

        vm.startPrank(alice);
        uint256 atomCost = multiVault.getAtomCost();
        trustToken.mint(alice, atomCost + TEST_DEPOSIT_AMOUNT);
        trustToken.approve(address(multiVault), atomCost + TEST_DEPOSIT_AMOUNT);
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = "New test atom";
        multiVault.createAtoms(atomDataArray, atomCost);
        multiVault.deposit(alice, newAtomId, TEST_BONDING_CURVE_ID, TEST_DEPOSIT_AMOUNT, 0);
        vm.stopPrank();

        vm.prank(admin);
        address deployedWrapper =
            wrappedERC20Factory.deployWrapper(newAtomId, TEST_BONDING_CURVE_ID, "New Wrapper", "NW");

        WrappedERC20 wrapper = WrappedERC20(deployedWrapper);

        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrapper.wrap(TEST_SHARES);

        assertEq(wrapper.balanceOf(alice), TEST_SHARES);

        vm.prank(alice);
        wrapper.transfer(bob, TEST_SHARES / 2);

        assertEq(wrapper.balanceOf(alice), TEST_SHARES / 2);
        assertEq(wrapper.balanceOf(bob), TEST_SHARES / 2);
    }

    function test_integration_multipleWrappersForSameTermButDifferentCurveIds() public {
        uint256 curveId2 = 2;

        address wrapper1 = wrappedTokenAddress; // already deployed in setUp()

        vm.prank(admin);
        address wrapper2 = wrappedERC20Factory.deployWrapper(TEST_ATOM_ID, curveId2, "Wrapper 2", "W2");

        assertTrue(wrapper1 != wrapper2);

        WrappedERC20 token1 = WrappedERC20(wrapper1);
        WrappedERC20 token2 = WrappedERC20(wrapper2);

        assertEq(token1.termId(), TEST_ATOM_ID);
        assertEq(token2.termId(), TEST_ATOM_ID);
        assertEq(token1.bondingCurveId(), TEST_BONDING_CURVE_ID);
        assertEq(token2.bondingCurveId(), curveId2);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_wrap_validAmounts(uint256 shares) public {
        shares = bound(shares, 1, type(uint128).max);

        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(shares);

        assertEq(wrappedToken.balanceOf(alice), shares);
        assertEq(wrappedToken.totalSupply(), shares);
    }

    function testFuzz_unwrap_validAmounts(uint256 shares) public {
        shares = bound(shares, 1, type(uint128).max);

        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(shares);

        vm.prank(alice);
        wrappedToken.unwrap(shares);

        assertEq(wrappedToken.balanceOf(alice), 0);
        assertEq(wrappedToken.totalSupply(), 0);
    }

    function testFuzz_transfer_validAmounts(uint256 shares, uint256 transferAmount) public {
        shares = bound(shares, 1, type(uint128).max);
        transferAmount = bound(transferAmount, 0, shares);

        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(shares);

        vm.prank(alice);
        wrappedToken.transfer(bob, transferAmount);

        assertEq(wrappedToken.balanceOf(alice), shares - transferAmount);
        assertEq(wrappedToken.balanceOf(bob), transferAmount);
        assertEq(wrappedToken.totalSupply(), shares);
    }

    function testFuzz_computeAddress_consistency(
        bytes32 termId,
        uint256 curveId,
        string calldata name,
        string calldata symbol
    ) public view {
        vm.assume(bytes(name).length > 0 && bytes(name).length < 100);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length < 20);

        address address1 = wrappedERC20Factory.computeWrappedERC20Address(termId, curveId, name, symbol);
        address address2 = wrappedERC20Factory.computeWrappedERC20Address(termId, curveId, name, symbol);

        assertEq(address1, address2);
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_edge_wrapUnwrapMultipleRounds() public {
        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        uint256 amount = TEST_SHARES / 4;

        for (uint256 i = 0; i < 4; i++) {
            vm.prank(alice);
            wrappedToken.wrap(amount);

            assertEq(wrappedToken.balanceOf(alice), amount * (i + 1));
        }

        for (uint256 i = 0; i < 4; i++) {
            vm.prank(alice);
            wrappedToken.unwrap(amount);

            assertEq(wrappedToken.balanceOf(alice), amount * (3 - i));
        }

        assertEq(wrappedToken.totalSupply(), 0);
    }

    function test_edge_transferToSelf() public {
        vm.mockCall(address(multiVault), abi.encodeWithSelector(multiVault.wrapperTransfer.selector), abi.encode());

        vm.prank(alice);
        wrappedToken.wrap(TEST_SHARES);

        vm.prank(alice);
        wrappedToken.transfer(alice, TEST_SHARES);

        assertEq(wrappedToken.balanceOf(alice), TEST_SHARES);
    }

    function test_edge_approveZeroAmount() public {
        vm.prank(alice);
        wrappedToken.approve(bob, TEST_SHARES);

        vm.prank(alice);
        wrappedToken.approve(bob, 0);

        assertEq(wrappedToken.allowance(alice, bob), 0);
    }

    function test_edge_factoryDeployWithLongNames() public {
        bytes32 newAtomId = keccak256(abi.encodePacked("New test atom"));

        vm.startPrank(alice);
        uint256 atomCost = multiVault.getAtomCost();
        trustToken.mint(alice, atomCost);
        trustToken.approve(address(multiVault), atomCost);
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = "New test atom";
        multiVault.createAtoms(atomDataArray, atomCost);
        vm.stopPrank();

        string memory longName = "Very Long Token Name That Should Still Work";
        string memory longSymbol = "VLTNTSTW";

        vm.prank(admin);
        address deployedWrapper =
            wrappedERC20Factory.deployWrapper(newAtomId, TEST_BONDING_CURVE_ID, longName, longSymbol);

        WrappedERC20 wrapper = WrappedERC20(deployedWrapper);
        assertEq(wrapper.name(), longName);
        assertEq(wrapper.symbol(), longSymbol);
    }

    function test_edge_factoryDeployWithEmptyStrings() public {
        bytes32 newAtomId = keccak256(abi.encodePacked("New test atom"));

        vm.startPrank(alice);
        uint256 atomCost = multiVault.getAtomCost();
        trustToken.approve(address(multiVault), atomCost);
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = "New test atom";
        multiVault.createAtoms(atomDataArray, atomCost);
        vm.stopPrank();

        vm.prank(admin);
        address deployedWrapper = wrappedERC20Factory.deployWrapper(newAtomId, TEST_BONDING_CURVE_ID, "", "");

        WrappedERC20 wrapper = WrappedERC20(deployedWrapper);
        assertEq(wrapper.name(), "");
        assertEq(wrapper.symbol(), "");
    }

    /*//////////////////////////////////////////////////////////////
                            APPROVAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_multiVaultApproval_deposit() public {
        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.DEPOSIT);

        assertTrue(multiVault.isApprovedToDeposit(address(wrappedToken), alice));
    }

    function test_multiVaultApproval_redemption() public {
        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.REDEMPTION);

        assertTrue(multiVault.isApprovedToRedeem(address(wrappedToken), alice));
    }

    function test_multiVaultApproval_both() public {
        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.BOTH);

        assertTrue(multiVault.isApprovedToDeposit(address(wrappedToken), alice));
        assertTrue(multiVault.isApprovedToRedeem(address(wrappedToken), alice));
    }

    function test_multiVaultApproval_none() public {
        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.BOTH);

        assertTrue(multiVault.isApprovedToDeposit(address(wrappedToken), alice));

        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.NONE);

        assertFalse(multiVault.isApprovedToDeposit(address(wrappedToken), alice));
        assertFalse(multiVault.isApprovedToRedeem(address(wrappedToken), alice));
    }

    /*//////////////////////////////////////////////////////////////
                            BRANCH COVERAGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_wrap_withApproval() public {
        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.BOTH);

        uint256 userShares = multiVault.balanceOf(alice, TEST_ATOM_ID, TEST_BONDING_CURVE_ID);

        vm.prank(alice);
        wrappedToken.wrap(userShares);

        assertEq(wrappedToken.balanceOf(alice), userShares);
        assertEq(wrappedToken.totalSupply(), userShares);
    }

    function test_unwrap_withApproval() public {
        vm.prank(alice);
        multiVault.approve(address(wrappedToken), IMultiVault.ApprovalTypes.BOTH);

        uint256 userShares = multiVault.balanceOf(alice, TEST_ATOM_ID, TEST_BONDING_CURVE_ID);

        vm.prank(alice);
        wrappedToken.wrap(userShares);

        vm.prank(alice);
        wrappedToken.unwrap(userShares / 2);

        assertEq(wrappedToken.balanceOf(alice), userShares / 2);
        assertEq(wrappedToken.totalSupply(), userShares / 2);
    }

    function test_factory_deployWrapper_createsNewBeaconProxy() public {
        bytes32 newAtomId = keccak256(abi.encodePacked("Unique test atom"));

        vm.startPrank(alice);
        uint256 atomCost = multiVault.getAtomCost();
        trustToken.mint(alice, atomCost);
        trustToken.approve(address(multiVault), atomCost);
        bytes[] memory atomDataArray = new bytes[](1);
        atomDataArray[0] = "Unique test atom";
        multiVault.createAtoms(atomDataArray, atomCost);
        vm.stopPrank();

        vm.prank(admin);
        address deployedWrapper =
            wrappedERC20Factory.deployWrapper(newAtomId, TEST_BONDING_CURVE_ID, "Unique Wrapper", "UW");

        uint256 codeSize;
        assembly {
            codeSize := extcodesize(deployedWrapper)
        }
        assertGt(codeSize, 0);
    }
}
