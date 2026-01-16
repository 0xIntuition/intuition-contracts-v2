// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { TrustSwapRouter } from "src/utils/TrustSwapRouter.sol";
import { ITrustSwapRouter } from "src/interfaces/ITrustSwapRouter.sol";
import { IAerodromeRouter } from "src/interfaces/external/aerodrome/IAerodromeRouter.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockAerodromeRouter {
    uint256 public outputMultiplier = 1e12;
    bool public shouldFail;

    function setOutputMultiplier(uint256 multiplier) external {
        outputMultiplier = multiplier;
    }

    function setShouldFail(bool fail) external {
        shouldFail = fail;
    }

    function getAmountsOut(
        uint256 amountIn,
        IAerodromeRouter.Route[] calldata
    )
        external
        view
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn * outputMultiplier;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        IAerodromeRouter.Route[] calldata routes,
        address to,
        uint256
    )
        external
        returns (uint256[] memory amounts)
    {
        require(!shouldFail, "MockAerodromeRouter: swap failed");

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn * outputMultiplier;

        require(amounts[1] >= amountOutMin, "MockAerodromeRouter: insufficient output");

        MockERC20(routes[0].from).burn(address(this), amountIn);
        MockERC20(routes[0].to).mint(to, amounts[1]);

        return amounts;
    }
}

contract TrustSwapRouterTest is Test {
    TrustSwapRouter public trustSwapRouter;
    TrustSwapRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;

    MockERC20 public usdcToken;
    MockERC20 public trustToken;
    MockAerodromeRouter public aerodromeRouter;
    address public poolFactory;

    address public owner;
    address public user;
    address public alice;
    address public bob;

    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant TRUST_DECIMALS = 18;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        poolFactory = makeAddr("poolFactory");

        usdcToken = new MockERC20("USD Coin", "USDC", uint8(USDC_DECIMALS));
        trustToken = new MockERC20("Trust Token", "TRUST", uint8(TRUST_DECIMALS));
        aerodromeRouter = new MockAerodromeRouter();

        trustSwapRouterImplementation = new TrustSwapRouter();

        bytes memory initData = abi.encodeWithSelector(
            TrustSwapRouter.initialize.selector,
            owner,
            address(usdcToken),
            address(trustToken),
            address(aerodromeRouter),
            poolFactory,
            DEFAULT_SWAP_DEADLINE
        );

        trustSwapRouterProxy = new TransparentUpgradeableProxy(address(trustSwapRouterImplementation), owner, initData);

        trustSwapRouter = TrustSwapRouter(address(trustSwapRouterProxy));

        usdcToken.mint(user, 1_000_000e6);
        usdcToken.mint(alice, 1_000_000e6);
        usdcToken.mint(bob, 1_000_000e6);

        vm.prank(user);
        usdcToken.approve(address(trustSwapRouter), type(uint256).max);

        vm.prank(alice);
        usdcToken.approve(address(trustSwapRouter), type(uint256).max);

        vm.prank(bob);
        usdcToken.approve(address(trustSwapRouter), type(uint256).max);

        vm.label(address(trustSwapRouter), "TrustSwapRouter");
        vm.label(address(usdcToken), "USDC");
        vm.label(address(trustToken), "TRUST");
        vm.label(address(aerodromeRouter), "AerodromeRouter");
    }

    /* =================================================== */
    /*                 INITIALIZATION TESTS                */
    /* =================================================== */

    function test_initialize_successful() public view {
        assertEq(address(trustSwapRouter.usdcToken()), address(usdcToken));
        assertEq(address(trustSwapRouter.trustToken()), address(trustToken));
        assertEq(address(trustSwapRouter.aerodromeRouter()), address(aerodromeRouter));
        assertEq(trustSwapRouter.poolFactory(), poolFactory);
        assertEq(trustSwapRouter.defaultSwapDeadline(), DEFAULT_SWAP_DEADLINE);
        assertEq(trustSwapRouter.owner(), owner);
    }

    function test_initialize_revertsOnZeroOwner() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        newRouter.initialize(
            address(0),
            address(usdcToken),
            address(trustToken),
            address(aerodromeRouter),
            poolFactory,
            DEFAULT_SWAP_DEADLINE
        );
    }

    function test_initialize_revertsOnZeroUSDC() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        newRouter.initialize(
            owner, address(0), address(trustToken), address(aerodromeRouter), poolFactory, DEFAULT_SWAP_DEADLINE
        );
    }

    function test_initialize_revertsOnZeroTRUST() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        newRouter.initialize(
            owner, address(usdcToken), address(0), address(aerodromeRouter), poolFactory, DEFAULT_SWAP_DEADLINE
        );
    }

    function test_initialize_revertsOnZeroAerodromeRouter() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        newRouter.initialize(
            owner, address(usdcToken), address(trustToken), address(0), poolFactory, DEFAULT_SWAP_DEADLINE
        );
    }

    function test_initialize_revertsOnZeroPoolFactory() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        newRouter.initialize(
            owner, address(usdcToken), address(trustToken), address(aerodromeRouter), address(0), DEFAULT_SWAP_DEADLINE
        );
    }

    function test_initialize_revertsOnZeroDeadline() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidDeadline.selector));
        newRouter.initialize(owner, address(usdcToken), address(trustToken), address(aerodromeRouter), poolFactory, 0);
    }

    function test_initialize_revertsOnDoubleInitialization() public {
        vm.expectRevert();
        trustSwapRouter.initialize(
            owner, address(usdcToken), address(trustToken), address(aerodromeRouter), poolFactory, DEFAULT_SWAP_DEADLINE
        );
    }

    /* =================================================== */
    /*                 ADMIN FUNCTION TESTS                */
    /* =================================================== */

    function test_setUSDCAddress_successful() public {
        address newUSDC = makeAddr("newUSDC");

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.USDCAddressSet(newUSDC);

        vm.prank(owner);
        trustSwapRouter.setUSDCAddress(newUSDC);

        assertEq(address(trustSwapRouter.usdcToken()), newUSDC);
    }

    function test_setUSDCAddress_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        trustSwapRouter.setUSDCAddress(address(0));
    }

    function test_setUSDCAddress_revertsOnNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        trustSwapRouter.setUSDCAddress(makeAddr("newUSDC"));
    }

    function test_setTRUSTAddress_successful() public {
        address newTRUST = makeAddr("newTRUST");

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.TRUSTAddressSet(newTRUST);

        vm.prank(owner);
        trustSwapRouter.setTRUSTAddress(newTRUST);

        assertEq(address(trustSwapRouter.trustToken()), newTRUST);
    }

    function test_setTRUSTAddress_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        trustSwapRouter.setTRUSTAddress(address(0));
    }

    function test_setTRUSTAddress_revertsOnNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        trustSwapRouter.setTRUSTAddress(makeAddr("newTRUST"));
    }

    function test_setAerodromeRouter_successful() public {
        address newRouter = makeAddr("newRouter");

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.AerodromeRouterSet(newRouter);

        vm.prank(owner);
        trustSwapRouter.setAerodromeRouter(newRouter);

        assertEq(address(trustSwapRouter.aerodromeRouter()), newRouter);
    }

    function test_setAerodromeRouter_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        trustSwapRouter.setAerodromeRouter(address(0));
    }

    function test_setAerodromeRouter_revertsOnNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        trustSwapRouter.setAerodromeRouter(makeAddr("newRouter"));
    }

    function test_setPoolFactory_successful() public {
        address newFactory = makeAddr("newFactory");

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.PoolFactorySet(newFactory);

        vm.prank(owner);
        trustSwapRouter.setPoolFactory(newFactory);

        assertEq(trustSwapRouter.poolFactory(), newFactory);
    }

    function test_setPoolFactory_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        trustSwapRouter.setPoolFactory(address(0));
    }

    function test_setPoolFactory_revertsOnNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        trustSwapRouter.setPoolFactory(makeAddr("newFactory"));
    }

    function test_setDefaultSwapDeadline_successful() public {
        uint256 newDeadline = 1 hours;

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.DefaultSwapDeadlineSet(newDeadline);

        vm.prank(owner);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);

        assertEq(trustSwapRouter.defaultSwapDeadline(), newDeadline);
    }

    function test_setDefaultSwapDeadline_revertsOnZeroDeadline() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidDeadline.selector));
        trustSwapRouter.setDefaultSwapDeadline(0);
    }

    function test_setDefaultSwapDeadline_revertsOnNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        trustSwapRouter.setDefaultSwapDeadline(1 hours);
    }

    /* =================================================== */
    /*                   SWAP FUNCTION TESTS               */
    /* =================================================== */

    function test_swapToTrust_successful() public {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();
        uint256 minAmountOut = expectedOutput;

        uint256 userUsdcBalanceBefore = usdcToken.balanceOf(user);
        uint256 userTrustBalanceBefore = trustToken.balanceOf(user);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.SwappedToTrust(user, amountIn, expectedOutput);

        vm.prank(user);
        uint256 amountOut = trustSwapRouter.swapToTrust(amountIn, minAmountOut);

        assertEq(amountOut, expectedOutput);
        assertEq(usdcToken.balanceOf(user), userUsdcBalanceBefore - amountIn);
        assertEq(trustToken.balanceOf(user), userTrustBalanceBefore + expectedOutput);
    }

    function test_swapToTrust_revertsOnZeroAmountIn() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_AmountInZero.selector));
        trustSwapRouter.swapToTrust(0, 0);
    }

    function test_swapToTrust_revertsOnInsufficientOutputAmount() public {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();
        uint256 minAmountOut = expectedOutput + 1;

        vm.prank(user);
        vm.expectRevert();
        trustSwapRouter.swapToTrust(amountIn, minAmountOut);
    }

    function test_swapToTrust_multipleUsersSequential() public {
        uint256 aliceAmountIn = 100e6;
        uint256 bobAmountIn = 200e6;
        uint256 outputMultiplier = aerodromeRouter.outputMultiplier();

        vm.prank(alice);
        uint256 aliceAmountOut = trustSwapRouter.swapToTrust(aliceAmountIn, 0);

        vm.prank(bob);
        uint256 bobAmountOut = trustSwapRouter.swapToTrust(bobAmountIn, 0);

        assertEq(aliceAmountOut, aliceAmountIn * outputMultiplier);
        assertEq(bobAmountOut, bobAmountIn * outputMultiplier);
        assertEq(trustToken.balanceOf(alice), aliceAmountOut);
        assertEq(trustToken.balanceOf(bob), bobAmountOut);
    }

    function test_swapToTrust_usesCorrectDeadline() public {
        uint256 amountIn = 100e6;

        vm.warp(1000);

        vm.prank(user);
        trustSwapRouter.swapToTrust(amountIn, 0);
    }

    /* =================================================== */
    /*                 QUOTE FUNCTION TESTS                */
    /* =================================================== */

    function test_quoteSwapToTrust_successful() public view {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);

        assertEq(quotedOutput, expectedOutput);
    }

    function test_quoteSwapToTrust_returnsZeroForZeroInput() public view {
        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(0);

        assertEq(quotedOutput, 0);
    }

    function test_quoteSwapToTrust_matchesActualSwap() public {
        uint256 amountIn = 100e6;

        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);

        vm.prank(user);
        uint256 actualOutput = trustSwapRouter.swapToTrust(amountIn, 0);

        assertEq(quotedOutput, actualOutput);
    }

    /* =================================================== */
    /*                    VIEW FUNCTION TESTS              */
    /* =================================================== */

    function test_usdcToken_returnsCorrectAddress() public view {
        assertEq(address(trustSwapRouter.usdcToken()), address(usdcToken));
    }

    function test_trustToken_returnsCorrectAddress() public view {
        assertEq(address(trustSwapRouter.trustToken()), address(trustToken));
    }

    function test_aerodromeRouter_returnsCorrectAddress() public view {
        assertEq(address(trustSwapRouter.aerodromeRouter()), address(aerodromeRouter));
    }

    function test_poolFactory_returnsCorrectAddress() public view {
        assertEq(trustSwapRouter.poolFactory(), poolFactory);
    }

    function test_defaultSwapDeadline_returnsCorrectValue() public view {
        assertEq(trustSwapRouter.defaultSwapDeadline(), DEFAULT_SWAP_DEADLINE);
    }

    /* =================================================== */
    /*                   OWNERSHIP TESTS                   */
    /* =================================================== */

    function test_transferOwnership_successful() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        trustSwapRouter.transferOwnership(newOwner);

        assertEq(trustSwapRouter.pendingOwner(), newOwner);
    }

    function test_acceptOwnership_successful() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        trustSwapRouter.transferOwnership(newOwner);

        vm.prank(newOwner);
        trustSwapRouter.acceptOwnership();

        assertEq(trustSwapRouter.owner(), newOwner);
    }

    function test_renounceOwnership_successful() public {
        vm.prank(owner);
        trustSwapRouter.renounceOwnership();

        assertEq(trustSwapRouter.owner(), address(0));
    }

    /* =================================================== */
    /*                     FUZZING TESTS                   */
    /* =================================================== */

    function testFuzz_swapToTrust_variousAmounts(uint256 amountIn) public {
        amountIn = bound(amountIn, 1, 1_000_000e6);

        usdcToken.mint(user, amountIn);

        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        vm.prank(user);
        uint256 amountOut = trustSwapRouter.swapToTrust(amountIn, 0);

        assertEq(amountOut, expectedOutput);
    }

    function testFuzz_quoteSwapToTrust_variousAmounts(uint256 amountIn) public view {
        amountIn = bound(amountIn, 0, 1_000_000_000e6);

        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);

        if (amountIn == 0) {
            assertEq(quotedOutput, 0);
        } else {
            assertEq(quotedOutput, amountIn * aerodromeRouter.outputMultiplier());
        }
    }

    function testFuzz_setDefaultSwapDeadline_variousValues(uint256 newDeadline) public {
        vm.assume(newDeadline > 0);

        vm.prank(owner);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);

        assertEq(trustSwapRouter.defaultSwapDeadline(), newDeadline);
    }

    function testFuzz_setUSDCAddress_variousAddresses(address newUSDC) public {
        vm.assume(newUSDC != address(0));

        vm.prank(owner);
        trustSwapRouter.setUSDCAddress(newUSDC);

        assertEq(address(trustSwapRouter.usdcToken()), newUSDC);
    }

    function testFuzz_setTRUSTAddress_variousAddresses(address newTRUST) public {
        vm.assume(newTRUST != address(0));

        vm.prank(owner);
        trustSwapRouter.setTRUSTAddress(newTRUST);

        assertEq(address(trustSwapRouter.trustToken()), newTRUST);
    }

    function testFuzz_setAerodromeRouter_variousAddresses(address newRouter) public {
        vm.assume(newRouter != address(0));

        vm.prank(owner);
        trustSwapRouter.setAerodromeRouter(newRouter);

        assertEq(address(trustSwapRouter.aerodromeRouter()), newRouter);
    }

    function testFuzz_setPoolFactory_variousAddresses(address newFactory) public {
        vm.assume(newFactory != address(0));

        vm.prank(owner);
        trustSwapRouter.setPoolFactory(newFactory);

        assertEq(trustSwapRouter.poolFactory(), newFactory);
    }

    /* =================================================== */
    /*                   EDGE CASE TESTS                   */
    /* =================================================== */

    function test_swapToTrust_minimumAmount() public {
        uint256 amountIn = 1;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        usdcToken.mint(user, amountIn);

        vm.prank(user);
        uint256 amountOut = trustSwapRouter.swapToTrust(amountIn, 0);

        assertEq(amountOut, expectedOutput);
    }

    function test_swapToTrust_largeAmount() public {
        uint256 amountIn = 100_000_000e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        usdcToken.mint(user, amountIn);

        vm.prank(user);
        uint256 amountOut = trustSwapRouter.swapToTrust(amountIn, 0);

        assertEq(amountOut, expectedOutput);
    }

    function test_swapToTrust_exactMinAmountOut() public {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        vm.prank(user);
        uint256 amountOut = trustSwapRouter.swapToTrust(amountIn, expectedOutput);

        assertEq(amountOut, expectedOutput);
    }

    function test_setDefaultSwapDeadline_minimumValue() public {
        vm.prank(owner);
        trustSwapRouter.setDefaultSwapDeadline(1);

        assertEq(trustSwapRouter.defaultSwapDeadline(), 1);
    }

    function test_setDefaultSwapDeadline_maximumValue() public {
        uint256 maxValue = type(uint256).max;

        vm.prank(owner);
        trustSwapRouter.setDefaultSwapDeadline(maxValue);

        assertEq(trustSwapRouter.defaultSwapDeadline(), maxValue);
    }

    /* =================================================== */
    /*               STATE TRANSITION TESTS                */
    /* =================================================== */

    function test_stateTransition_updateAllAddresses() public {
        address newUSDC = makeAddr("newUSDC");
        address newTRUST = makeAddr("newTRUST");
        address newRouter = makeAddr("newRouter");
        address newFactory = makeAddr("newFactory");
        uint256 newDeadline = 1 hours;

        vm.startPrank(owner);
        trustSwapRouter.setUSDCAddress(newUSDC);
        trustSwapRouter.setTRUSTAddress(newTRUST);
        trustSwapRouter.setAerodromeRouter(newRouter);
        trustSwapRouter.setPoolFactory(newFactory);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);
        vm.stopPrank();

        assertEq(address(trustSwapRouter.usdcToken()), newUSDC);
        assertEq(address(trustSwapRouter.trustToken()), newTRUST);
        assertEq(address(trustSwapRouter.aerodromeRouter()), newRouter);
        assertEq(trustSwapRouter.poolFactory(), newFactory);
        assertEq(trustSwapRouter.defaultSwapDeadline(), newDeadline);
    }

    function test_stateTransition_ownershipTransferFlow() public {
        address newOwner = makeAddr("newOwner");
        address finalOwner = makeAddr("finalOwner");

        vm.prank(owner);
        trustSwapRouter.transferOwnership(newOwner);

        vm.prank(newOwner);
        trustSwapRouter.acceptOwnership();

        assertEq(trustSwapRouter.owner(), newOwner);

        vm.prank(newOwner);
        trustSwapRouter.transferOwnership(finalOwner);

        vm.prank(finalOwner);
        trustSwapRouter.acceptOwnership();

        assertEq(trustSwapRouter.owner(), finalOwner);
    }

    /* =================================================== */
    /*                  EVENT EMISSION TESTS               */
    /* =================================================== */

    function test_emitsUSDCAddressSet_onSetUSDCAddress() public {
        address newUSDC = makeAddr("newUSDC");

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.USDCAddressSet(newUSDC);

        vm.prank(owner);
        trustSwapRouter.setUSDCAddress(newUSDC);
    }

    function test_emitsTRUSTAddressSet_onSetTRUSTAddress() public {
        address newTRUST = makeAddr("newTRUST");

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.TRUSTAddressSet(newTRUST);

        vm.prank(owner);
        trustSwapRouter.setTRUSTAddress(newTRUST);
    }

    function test_emitsAerodromeRouterSet_onSetAerodromeRouter() public {
        address newRouter = makeAddr("newRouter");

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.AerodromeRouterSet(newRouter);

        vm.prank(owner);
        trustSwapRouter.setAerodromeRouter(newRouter);
    }

    function test_emitsPoolFactorySet_onSetPoolFactory() public {
        address newFactory = makeAddr("newFactory");

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.PoolFactorySet(newFactory);

        vm.prank(owner);
        trustSwapRouter.setPoolFactory(newFactory);
    }

    function test_emitsDefaultSwapDeadlineSet_onSetDefaultSwapDeadline() public {
        uint256 newDeadline = 1 hours;

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.DefaultSwapDeadlineSet(newDeadline);

        vm.prank(owner);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);
    }

    function test_emitsSwappedToTrust_onSwapToTrust() public {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.SwappedToTrust(user, amountIn, expectedOutput);

        vm.prank(user);
        trustSwapRouter.swapToTrust(amountIn, 0);
    }

    /* =================================================== */
    /*             INITIALIZATION EVENTS TESTS             */
    /* =================================================== */

    function test_initializeEmitsAllEvents() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        address newOwner = makeAddr("newOwner");
        address newUSDC = makeAddr("newUSDC");
        address newTRUST = makeAddr("newTRUST");
        address newAerodromeRouter = makeAddr("newAerodromeRouter");
        address newPoolFactory = makeAddr("newPoolFactory");
        uint256 newDeadline = 1 hours;

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.USDCAddressSet(newUSDC);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.TRUSTAddressSet(newTRUST);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.AerodromeRouterSet(newAerodromeRouter);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.PoolFactorySet(newPoolFactory);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.DefaultSwapDeadlineSet(newDeadline);

        newRouter.initialize(newOwner, newUSDC, newTRUST, newAerodromeRouter, newPoolFactory, newDeadline);
    }
}
