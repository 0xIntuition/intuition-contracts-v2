// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { TrustSwapRouter } from "src/utils/TrustSwapRouter.sol";
import { ITrustSwapRouter } from "src/interfaces/ITrustSwapRouter.sol";
import { IAerodromeRouter } from "src/interfaces/external/aerodrome/IAerodromeRouter.sol";
import { FinalityState, IMetaERC20Hub } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    bool public initialized;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function initialize(string memory _name, string memory _symbol, uint8 _decimals) external {
        require(!initialized, "MockERC20: already initialized");
        initialized = true;
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

/// @dev Mock ERC20 with EIP-2612 permit support for testing
contract MockERC20Permit {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    bool public initialized;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(_name)),
                keccak256(bytes("2")),
                block.chainid,
                address(this)
            )
        );
    }

    function initialize(string memory _name, string memory _symbol, uint8 _decimals) external {
        require(!initialized, "MockERC20Permit: already initialized");
        initialized = true;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(_name)),
                keccak256(bytes("2")),
                block.chainid,
                address(this)
            )
        );
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
        if (msg.sender != from) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function permit(
        address permitOwner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        require(deadline >= block.timestamp, "MockERC20Permit: EXPIRED");

        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, permitOwner, spender, value, nonces[permitOwner]++, deadline));

        bytes32 hash = MessageHashUtils.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        address recoveredAddress = ecrecover(hash, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == permitOwner, "MockERC20Permit: INVALID_SIGNATURE");

        allowance[permitOwner][spender] = value;
    }
}

contract MockWETH is MockERC20 {
    constructor() MockERC20("Wrapped Ether", "WETH", 18) { }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    function withdraw(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        deposit();
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
        IAerodromeRouter.Route[] calldata routes
    )
        external
        view
        returns (uint256[] memory amounts)
    {
        uint256 routeLength = routes.length + 1;
        amounts = new uint256[](routeLength);
        amounts[0] = amountIn;
        for (uint256 i = 1; i < routeLength; i++) {
            amounts[i] = amounts[i - 1] * outputMultiplier;
        }
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

        uint256 routeLength = routes.length + 1;
        amounts = new uint256[](routeLength);
        amounts[0] = amountIn;
        for (uint256 i = 1; i < routeLength; i++) {
            amounts[i] = amounts[i - 1] * outputMultiplier;
        }

        uint256 finalAmount = amounts[routeLength - 1];
        require(finalAmount >= amountOutMin, "MockAerodromeRouter: insufficient output");

        MockERC20(routes[0].from).burn(msg.sender, amountIn);
        if (routes.length == 1) {
            MockERC20(routes[0].to).mint(to, finalAmount);
        } else {
            MockERC20(routes[routes.length - 1].to).mint(to, finalAmount);
        }

        return amounts;
    }
}

contract MockMetaERC20Hub {
    uint256 public constant BRIDGE_FEE = 0.001 ether;
    uint256 public transferRemoteCallCount;
    bytes32 public lastTransferId;

    struct TransferCall {
        address caller;
        uint32 recipientDomain;
        bytes32 recipientAddress;
        uint256 amount;
        uint256 gasLimit;
        uint256 msgValue;
    }

    TransferCall public lastTransferCall;

    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState
    )
        external
        payable
        returns (bytes32 transferId)
    {
        transferRemoteCallCount++;
        transferId = keccak256(abi.encodePacked(block.timestamp, transferRemoteCallCount));
        lastTransferId = transferId;

        lastTransferCall = TransferCall({
            caller: msg.sender,
            recipientDomain: _recipientDomain,
            recipientAddress: _recipientAddress,
            amount: _amount,
            gasLimit: _gasLimit,
            msgValue: msg.value
        });

        MockERC20(msg.sender).burn(msg.sender, _amount);

        return transferId;
    }

    function quoteTransferRemote(uint32, bytes32, uint256) external pure returns (uint256) {
        return BRIDGE_FEE;
    }
}

contract TrustSwapRouterTest is Test {
    TrustSwapRouter public trustSwapRouter;
    TrustSwapRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;

    MockERC20 public usdcToken;
    MockERC20 public trustToken;
    MockAerodromeRouter public aerodromeRouter;
    MockMetaERC20Hub public metaERC20Hub;
    address public poolFactory;

    address public owner;
    address public user;
    address public alice;
    address public bob;

    address public constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_MAINNET_TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
    address payable public constant BASE_MAINNET_WETH = payable(0x4200000000000000000000000000000000000006);

    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant TRUST_DECIMALS = 18;
    uint32 public constant RECIPIENT_DOMAIN = 1155;
    uint256 public constant BRIDGE_GAS_LIMIT = 100_000;
    FinalityState public constant FINALITY_STATE = FinalityState.INSTANT;
    uint256 public constant MINIMUM_OUTPUT_THRESHOLD = 0;
    uint256 public constant MAX_SLIPPAGE_BPS = 10_000;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        poolFactory = makeAddr("poolFactory");

        MockERC20 usdcTemplate = new MockERC20("USD Coin", "USDC", uint8(USDC_DECIMALS));
        MockERC20 trustTemplate = new MockERC20("Trust Token", "TRUST", uint8(TRUST_DECIMALS));
        MockWETH wethTemplate = new MockWETH();

        vm.etch(BASE_MAINNET_USDC, address(usdcTemplate).code);
        vm.etch(BASE_MAINNET_TRUST, address(trustTemplate).code);
        vm.etch(BASE_MAINNET_WETH, address(wethTemplate).code);

        usdcToken = MockERC20(BASE_MAINNET_USDC);
        trustToken = MockERC20(BASE_MAINNET_TRUST);

        usdcToken.initialize("USD Coin", "USDC", uint8(USDC_DECIMALS));
        trustToken.initialize("Trust Token", "TRUST", uint8(TRUST_DECIMALS));
        MockWETH(BASE_MAINNET_WETH).initialize("Wrapped Ether", "WETH", 18);
        aerodromeRouter = new MockAerodromeRouter();
        metaERC20Hub = new MockMetaERC20Hub();

        trustSwapRouterImplementation = new TrustSwapRouter();

        bytes memory initData = abi.encodeWithSelector(
            TrustSwapRouter.initialize.selector,
            owner,
            address(aerodromeRouter),
            poolFactory,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
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
            address(aerodromeRouter),
            poolFactory,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );
    }

    function test_initialize_revertsOnZeroAerodromeRouter() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        newRouter.initialize(
            owner,
            address(0),
            poolFactory,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );
    }

    function test_initialize_revertsOnZeroPoolFactory() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidAddress.selector));
        newRouter.initialize(
            owner,
            address(aerodromeRouter),
            address(0),
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );
    }

    function test_initialize_revertsOnZeroDeadline() public {
        TrustSwapRouter newImplementation = new TrustSwapRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapRouter newRouter = TrustSwapRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_InvalidDeadline.selector));
        newRouter.initialize(
            owner,
            address(aerodromeRouter),
            poolFactory,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            0,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );
    }

    function test_initialize_revertsOnDoubleInitialization() public {
        vm.expectRevert();
        trustSwapRouter.initialize(
            owner,
            address(aerodromeRouter),
            poolFactory,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );
    }

    /* =================================================== */
    /*                 ADMIN FUNCTION TESTS                */
    /* =================================================== */

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

        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) =
            trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, minAmountOut, user);

        assertEq(amountOut, expectedOutput);
        assertEq(usdcToken.balanceOf(user), userUsdcBalanceBefore - amountIn);
    }

    function test_swapToTrust_revertsOnZeroAmountIn() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_AmountInZero.selector));
        trustSwapRouter.swapAndBridge(0, 0, user);
    }

    function test_swapToTrust_revertsOnInsufficientOutputAmount() public {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();
        uint256 minAmountOut = expectedOutput + 1;

        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert();
        trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, minAmountOut, user);
    }

    function test_swapToTrust_multipleUsersSequential() public {
        uint256 aliceAmountIn = 100e6;
        uint256 bobAmountIn = 200e6;
        uint256 outputMultiplier = aerodromeRouter.outputMultiplier();

        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);

        vm.prank(alice);
        (uint256 aliceAmountOut,) =
            trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(aliceAmountIn, 0, alice);

        vm.prank(bob);
        (uint256 bobAmountOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(bobAmountIn, 0, bob);

        assertEq(aliceAmountOut, aliceAmountIn * outputMultiplier);
        assertEq(bobAmountOut, bobAmountIn * outputMultiplier);
    }

    function test_swapToTrust_usesCorrectDeadline() public {
        uint256 amountIn = 100e6;

        vm.warp(1000);
        vm.deal(user, 1 ether);

        vm.prank(user);
        trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
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

        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 actualOutput,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);

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
        vm.deal(user, 1 ether);

        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        vm.prank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);

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
        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);

        assertEq(amountOut, expectedOutput);
    }

    function test_swapToTrust_largeAmount() public {
        uint256 amountIn = 100_000_000e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        usdcToken.mint(user, amountIn);
        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);

        assertEq(amountOut, expectedOutput);
    }

    function test_swapToTrust_exactMinAmountOut() public {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) =
            trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, expectedOutput, user);

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
        address newRouter = makeAddr("newRouter");
        address newFactory = makeAddr("newFactory");
        uint256 newDeadline = 1 hours;

        vm.startPrank(owner);
        trustSwapRouter.setAerodromeRouter(newRouter);
        trustSwapRouter.setPoolFactory(newFactory);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);
        vm.stopPrank();

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

        vm.deal(user, 1 ether);

        vm.prank(user);
        trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
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
        address newAerodromeRouter = makeAddr("newAerodromeRouter");
        address newPoolFactory = makeAddr("newPoolFactory");
        address newMetaERC20Hub = makeAddr("newMetaERC20Hub");
        uint32 newRecipientDomain = 9999;
        uint256 newBridgeGasLimit = 200_000;
        FinalityState newFinalityState = FinalityState.FINALIZED;
        uint256 newDeadline = 1 hours;
        uint256 newMinimumOutputThreshold = 123;
        uint256 newMaxSlippageBps = 9500;

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.AerodromeRouterSet(newAerodromeRouter);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.PoolFactorySet(newPoolFactory);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.MetaERC20HubSet(newMetaERC20Hub);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.RecipientDomainSet(newRecipientDomain);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.BridgeGasLimitSet(newBridgeGasLimit);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.FinalityStateSet(newFinalityState);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.DefaultSwapDeadlineSet(newDeadline);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.MinimumOutputThresholdSet(newMinimumOutputThreshold);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapRouter.MaxSlippageBpsSet(newMaxSlippageBps);

        newRouter.initialize(
            newOwner,
            newAerodromeRouter,
            newPoolFactory,
            newMetaERC20Hub,
            newRecipientDomain,
            newBridgeGasLimit,
            newFinalityState,
            newDeadline,
            newMinimumOutputThreshold,
            newMaxSlippageBps
        );
    }
}

/// @title TrustSwapRouterPermitTest
/// @notice Tests for EIP-2612 permit functionality
contract TrustSwapRouterPermitTest is Test {
    TrustSwapRouter public trustSwapRouter;
    TrustSwapRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;

    MockERC20Permit public usdcToken;
    MockERC20 public trustToken;
    MockAerodromeRouter public aerodromeRouter;
    MockMetaERC20Hub public metaERC20Hub;
    address public poolFactory;

    address public owner;
    uint256 public userPrivateKey;
    address public user;

    address public constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_MAINNET_TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;

    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant TRUST_DECIMALS = 18;
    uint32 public constant RECIPIENT_DOMAIN = 1155;
    uint256 public constant BRIDGE_GAS_LIMIT = 100_000;
    FinalityState public constant FINALITY_STATE = FinalityState.INSTANT;
    uint256 public constant MINIMUM_OUTPUT_THRESHOLD = 0;
    uint256 public constant MAX_SLIPPAGE_BPS = 10_000;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        owner = makeAddr("owner");
        userPrivateKey = 0xA11CE;
        user = vm.addr(userPrivateKey);
        poolFactory = makeAddr("poolFactory");

        MockERC20Permit usdcTemplate = new MockERC20Permit("USD Coin", "USDC", uint8(USDC_DECIMALS));
        MockERC20 trustTemplate = new MockERC20("Trust Token", "TRUST", uint8(TRUST_DECIMALS));

        vm.etch(BASE_MAINNET_USDC, address(usdcTemplate).code);
        vm.etch(BASE_MAINNET_TRUST, address(trustTemplate).code);

        usdcToken = MockERC20Permit(BASE_MAINNET_USDC);
        trustToken = MockERC20(BASE_MAINNET_TRUST);

        usdcToken.initialize("USD Coin", "USDC", uint8(USDC_DECIMALS));
        trustToken.initialize("Trust Token", "TRUST", uint8(TRUST_DECIMALS));
        aerodromeRouter = new MockAerodromeRouter();
        metaERC20Hub = new MockMetaERC20Hub();

        trustSwapRouterImplementation = new TrustSwapRouter();

        bytes memory initData = abi.encodeWithSelector(
            TrustSwapRouter.initialize.selector,
            owner,
            address(aerodromeRouter),
            poolFactory,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );

        trustSwapRouterProxy = new TransparentUpgradeableProxy(address(trustSwapRouterImplementation), owner, initData);
        trustSwapRouter = TrustSwapRouter(address(trustSwapRouterProxy));

        usdcToken.mint(user, 1_000_000e6);

        vm.label(address(trustSwapRouter), "TrustSwapRouter");
        vm.label(address(usdcToken), "USDC");
        vm.label(address(trustToken), "TRUST");
        vm.label(address(aerodromeRouter), "AerodromeRouter");
        vm.label(user, "user");
    }

    function _getPermitSignature(
        uint256 privateKey,
        address permitOwner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, permitOwner, spender, value, nonce, deadline));

        bytes32 hash = MessageHashUtils.toTypedDataHash(usdcToken.DOMAIN_SEPARATOR(), structHash);

        (v, r, s) = vm.sign(privateKey, hash);
    }

    /* =================================================== */
    /*              PERMIT SWAP FUNCTION TESTS             */
    /* =================================================== */

    function test_swapToTrustWithPermit_successful() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        uint256 userUsdcBalanceBefore = usdcToken.balanceOf(user);

        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );

        assertEq(amountOut, expectedOutput);
        assertEq(usdcToken.balanceOf(user), userUsdcBalanceBefore - amountIn);
    }

    function test_swapToTrustWithPermit_revertsOnZeroAmountIn() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), 0, 0, deadline);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_AmountInZero.selector));
        trustSwapRouter.swapAndBridgeWithPermit(0, 0, user, deadline, v, r, s);
    }

    function test_swapToTrustWithPermit_revertsOnExpiredDeadline() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp - 1;

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_PermitExpired.selector));
        trustSwapRouter.swapAndBridgeWithPermit(amountIn, 0, user, deadline, v, r, s);
    }

    function test_swapToTrustWithPermit_revertsOnInvalidSignature() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;

        uint256 wrongPrivateKey = 0xBAD;
        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(wrongPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ITrustSwapRouter.TrustSwapRouter_PermitFailed.selector));
        trustSwapRouter.swapAndBridgeWithPermit(amountIn, 0, user, deadline, v, r, s);
    }

    function test_swapToTrustWithPermit_succeedsWithExistingAllowance() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        vm.prank(user);
        usdcToken.approve(address(trustSwapRouter), amountIn);

        uint256 wrongPrivateKey = 0xBAD;
        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(wrongPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );

        assertEq(amountOut, expectedOutput);
    }

    function test_swapToTrustWithPermit_revertsOnInsufficientOutput() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();
        uint256 minAmountOut = expectedOutput + 1;

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert();
        trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, minAmountOut, user, deadline, v, r, s
        );
    }

    function test_swapToTrustWithPermit_incrementsNonce() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;

        assertEq(usdcToken.nonces(user), 0);

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        vm.deal(user, 1 ether);

        vm.prank(user);
        trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );

        assertEq(usdcToken.nonces(user), 1);
    }

    function test_swapToTrustWithPermit_multipleSwapsWithCorrectNonces() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v1, bytes32 r1, bytes32 s1) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        vm.deal(user, 2 ether);

        vm.prank(user);
        trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v1, r1, s1
        );

        (uint8 v2, bytes32 r2, bytes32 s2) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), amountIn, 1, deadline);

        vm.prank(user);
        trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v2, r2, s2
        );

        assertEq(usdcToken.nonces(user), 2);
    }

    function testFuzz_swapToTrustWithPermit_variousAmounts(uint256 amountIn) public {
        amountIn = bound(amountIn, 1, 1_000_000e6);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        usdcToken.mint(user, amountIn);
        vm.deal(user, 1 ether);

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        vm.prank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );

        assertEq(amountOut, expectedOutput);
    }

    function testFuzz_swapToTrustWithPermit_variousDeadlines(uint256 deadlineOffset) public {
        deadlineOffset = bound(deadlineOffset, 1, 365 days);
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + deadlineOffset;
        uint256 expectedOutput = amountIn * aerodromeRouter.outputMultiplier();

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignature(userPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline);

        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );

        assertEq(amountOut, expectedOutput);
    }
}

/// @title TrustSwapRouterForkTest
/// @notice Fork tests against Base mainnet for real-world swap testing
contract TrustSwapRouterForkTest is Test {
    TrustSwapRouter public trustSwapRouter;
    TrustSwapRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;

    address public constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_MAINNET_TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
    address public constant BASE_MAINNET_AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant BASE_MAINNET_POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    IERC20 public usdc;
    IERC20 public trust;
    MockMetaERC20Hub public metaERC20Hub;

    address public owner;
    uint256 public userPrivateKey;
    address public user;

    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;
    uint32 public constant RECIPIENT_DOMAIN = 1155;
    uint256 public constant BRIDGE_GAS_LIMIT = 100_000;
    FinalityState public constant FINALITY_STATE = FinalityState.INSTANT;
    uint256 public constant MINIMUM_OUTPUT_THRESHOLD = 0;
    uint256 public constant MAX_SLIPPAGE_BPS = 10_000;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 public baseFork;

    function setUp() public {
        vm.createSelectFork("base");

        owner = makeAddr("owner");
        userPrivateKey = 0xA11CE;
        user = vm.addr(userPrivateKey);

        usdc = IERC20(BASE_MAINNET_USDC);
        trust = IERC20(BASE_MAINNET_TRUST);
        metaERC20Hub = new MockMetaERC20Hub();

        trustSwapRouterImplementation = new TrustSwapRouter();

        bytes memory initData = abi.encodeWithSelector(
            TrustSwapRouter.initialize.selector,
            owner,
            BASE_MAINNET_AERODROME_ROUTER,
            BASE_MAINNET_POOL_FACTORY,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );

        trustSwapRouterProxy = new TransparentUpgradeableProxy(address(trustSwapRouterImplementation), owner, initData);
        trustSwapRouter = TrustSwapRouter(address(trustSwapRouterProxy));

        deal(address(usdc), user, 10_000e6);

        vm.prank(user);
        usdc.approve(address(trustSwapRouter), type(uint256).max);

        vm.label(address(trustSwapRouter), "TrustSwapRouter");
        vm.label(BASE_MAINNET_USDC, "USDC");
        vm.label(BASE_MAINNET_TRUST, "TRUST");
        vm.label(BASE_MAINNET_AERODROME_ROUTER, "AerodromeRouter");
        vm.label(user, "user");
    }

    /* =================================================== */
    /*                FORK TEST: QUOTE                     */
    /* =================================================== */

    function test_fork_quoteSwapToTrust_returnsNonZeroForValidAmount() public view {
        uint256 amountIn = 100e6;

        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);

        console2.log("Quote for 100 USDC:");
        console2.log("  USDC in:", amountIn);
        console2.log("  TRUST out:", quotedOutput);
        console2.log("  Rate (TRUST per USDC):", quotedOutput / amountIn);

        assertGt(quotedOutput, 0, "Quote should return non-zero output");
    }

    function test_fork_quoteSwapToTrust_scalesWithInput() public view {
        uint256 smallAmount = 10e6;
        uint256 largeAmount = 1000e6;

        uint256 smallQuote = trustSwapRouter.quoteSwapToTrust(smallAmount);
        uint256 largeQuote = trustSwapRouter.quoteSwapToTrust(largeAmount);

        console2.log("Quote comparison:");
        console2.log("  10 USDC -> TRUST:", smallQuote);
        console2.log("  1000 USDC -> TRUST:", largeQuote);

        assertGt(largeQuote, smallQuote, "Larger input should yield larger output");
    }

    /* =================================================== */
    /*                FORK TEST: SWAP                      */
    /* =================================================== */

    function test_fork_swapToTrust_executesSuccessfully() public {
        uint256 amountIn = 100e6;

        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);
        uint256 minAmountOut = (quotedOutput * 95) / 100;

        uint256 userUsdcBefore = usdc.balanceOf(user);
        uint256 userTrustBefore = trust.balanceOf(user);

        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) =
            trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, minAmountOut, user);

        uint256 userUsdcAfter = usdc.balanceOf(user);
        uint256 userTrustAfter = trust.balanceOf(user);

        console2.log("Swap executed:");
        console2.log("  USDC spent:", userUsdcBefore - userUsdcAfter);
        console2.log("  TRUST received:", userTrustAfter - userTrustBefore);
        console2.log("  Quoted:", quotedOutput);
        console2.log("  Actual:", amountOut);

        assertEq(userUsdcBefore - userUsdcAfter, amountIn, "Should spend exact USDC amount");
        assertGe(amountOut, minAmountOut, "Should receive at least minAmountOut");
        assertEq(userTrustAfter - userTrustBefore, amountOut, "Trust balance should increase by amountOut");
    }

    function test_fork_swapToTrust_multipleSwapsWork() public {
        uint256 amountIn = 50e6;

        vm.deal(user, 2 ether);

        vm.prank(user);
        (uint256 firstSwapOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);

        vm.prank(user);
        (uint256 secondSwapOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);

        console2.log("Multiple swaps:");
        console2.log("  First swap (50 USDC):", firstSwapOut);
        console2.log("  Second swap (50 USDC):", secondSwapOut);

        assertGt(firstSwapOut, 0, "First swap should return tokens");
        assertGt(secondSwapOut, 0, "Second swap should return tokens");
    }

    /* =================================================== */
    /*            FORK TEST: PERMIT SWAP                   */
    /* =================================================== */

    function test_fork_swapToTrustWithPermit_executesSuccessfully() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 domainSeparator = _getUSDCDomainSeparator();
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignatureForUSDC(
            userPrivateKey, user, address(trustSwapRouter), amountIn, 0, deadline, domainSeparator
        );

        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);
        uint256 minAmountOut = (quotedOutput * 95) / 100;

        uint256 userUsdcBefore = usdc.balanceOf(user);
        uint256 userTrustBefore = trust.balanceOf(user);

        vm.deal(user, 1 ether);

        vm.prank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, minAmountOut, user, deadline, v, r, s
        );

        console2.log("Permit swap executed:");
        console2.log("  USDC spent:", userUsdcBefore - usdc.balanceOf(user));
        console2.log("  TRUST received:", trust.balanceOf(user) - userTrustBefore);
        console2.log("  Amount out:", amountOut);

        assertGe(amountOut, minAmountOut, "Should receive at least minAmountOut");
    }

    /* =================================================== */
    /*                 HELPER FUNCTIONS                    */
    /* =================================================== */

    function _getUSDCDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("USD Coin")),
                keccak256(bytes("2")),
                block.chainid,
                BASE_MAINNET_USDC
            )
        );
    }

    function _getPermitSignatureForUSDC(
        uint256 privateKey,
        address permitOwner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        bytes32 domainSeparator
    )
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, permitOwner, spender, value, nonce, deadline));

        bytes32 hash = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);

        (v, r, s) = vm.sign(privateKey, hash);
    }
}
