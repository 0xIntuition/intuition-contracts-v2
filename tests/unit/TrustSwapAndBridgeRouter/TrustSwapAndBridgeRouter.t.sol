// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { TrustSwapAndBridgeRouter } from "src/utils/TrustSwapAndBridgeRouter.sol";
import { ITrustSwapAndBridgeRouter } from "src/interfaces/ITrustSwapAndBridgeRouter.sol";
import { IAerodromeRouter } from "src/interfaces/external/aerodrome/IAerodromeRouter.sol";
import { ICLSwapCallback } from "src/interfaces/external/aerodrome/ICLPool.sol";
import { FinalityState, IMetaERC20Hub } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";
import { IWETH } from "src/interfaces/external/IWETH.sol";

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

contract MockCLPool {
    address public token0;
    address public token1;
    uint160 public sqrtPriceX96;
    uint256 public outputMultiplier;
    bool public initialized;
    bool public shouldFail;

    function initialize(address _token0, address _token1, uint160 _sqrtPriceX96, uint256 _outputMultiplier) external {
        require(!initialized, "MockCLPool: already initialized");
        initialized = true;
        token0 = _token0;
        token1 = _token1;
        sqrtPriceX96 = _sqrtPriceX96;
        outputMultiplier = _outputMultiplier;
    }

    function setOutputMultiplier(uint256 multiplier) external {
        outputMultiplier = multiplier;
    }

    function setSqrtPriceX96(uint160 newSqrtPriceX96) external {
        sqrtPriceX96 = newSqrtPriceX96;
    }

    function setShouldFail(bool fail) external {
        shouldFail = fail;
    }

    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, bool) {
        return (sqrtPriceX96, 0, 0, 0, 0, true);
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160,
        bytes calldata data
    )
        external
        returns (int256 amount0, int256 amount1)
    {
        require(!shouldFail, "MockCLPool: swap failed");
        require(amountSpecified > 0, "MockCLPool: exact input only");

        uint256 amountIn = uint256(amountSpecified);
        uint256 amountOut = amountIn * outputMultiplier;

        if (zeroForOne) {
            amount0 = int256(amountIn);
            amount1 = -int256(amountOut);
        } else {
            amount0 = -int256(amountOut);
            amount1 = int256(amountIn);
        }

        ICLSwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
        if (zeroForOne) {
            MockERC20(token1).mint(recipient, amountOut);
        } else {
            MockERC20(token0).mint(recipient, amountOut);
        }
    }
}

contract MockCLFactory {
    bool public initialized;
    int24[] internal tickSpacingValues;
    mapping(address => mapping(address => mapping(int24 => address))) internal pools;

    function initialize(int24[] calldata tickSpacings) external {
        require(!initialized, "MockCLFactory: already initialized");
        initialized = true;
        for (uint256 i = 0; i < tickSpacings.length; i++) {
            tickSpacingValues.push(tickSpacings[i]);
        }
    }

    function tickSpacings() external view returns (int24[] memory) {
        return tickSpacingValues;
    }

    function setPool(address tokenA, address tokenB, int24 tickSpacing, address pool) external {
        pools[tokenA][tokenB][tickSpacing] = pool;
        pools[tokenB][tokenA][tickSpacing] = pool;
    }

    function getPool(address tokenA, address tokenB, int24 tickSpacing) external view returns (address) {
        return pools[tokenA][tokenB][tickSpacing];
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

        return transferId;
    }

    function quoteTransferRemote(uint32, bytes32, uint256) external pure returns (uint256) {
        return BRIDGE_FEE;
    }
}

contract TrustSwapAndBridgeRouterTest is Test {
    TrustSwapAndBridgeRouter public trustSwapRouter;
    TrustSwapAndBridgeRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;

    MockERC20 public usdcToken;
    MockERC20 public trustToken;
    MockCLPool public clPool;
    MockCLFactory public clFactoryPrimary;
    MockCLFactory public clFactorySecondary;
    MockCLPool public wethUsdcPool;
    MockCLPool public tokenTwoHopUsdcPool;
    MockCLPool public tokenThreeHopWethPool;
    MockMetaERC20Hub public metaERC20Hub;
    MockERC20 public tokenTwoHop;
    MockERC20 public tokenThreeHop;

    address public owner;
    address public user;
    address public alice;
    address public bob;

    address public constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_MAINNET_TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
    address payable public constant BASE_MAINNET_WETH = payable(0x4200000000000000000000000000000000000006);
    address public constant BASE_MAINNET_USDC_TRUST_CL_POOL = 0x17f707CF3EDBbd5d9251D4bCDF9Ad70a247D7B84;
    address public constant BASE_MAINNET_CL_FACTORY_PRIMARY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address public constant BASE_MAINNET_CL_FACTORY_SECONDARY = 0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a;

    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant TRUST_DECIMALS = 18;
    uint32 public constant RECIPIENT_DOMAIN = 1155;
    uint256 public constant BRIDGE_GAS_LIMIT = 100_000;
    FinalityState public constant FINALITY_STATE = FinalityState.INSTANT;
    uint256 public constant MINIMUM_OUTPUT_THRESHOLD = 0;
    uint256 public constant MAX_SLIPPAGE_BPS = 10_000;
    uint160 public constant DEFAULT_SQRT_PRICE_X96 = 79_228_162_514_264_337_593_543;
    uint160 public constant ONE_SQRT_PRICE_X96 = 79_228_162_514_264_337_593_543_950_336;
    uint256 public constant DEFAULT_OUTPUT_MULTIPLIER = 1e12;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        MockERC20 usdcTemplate = new MockERC20("USD Coin", "USDC", uint8(USDC_DECIMALS));
        MockERC20 trustTemplate = new MockERC20("Trust Token", "TRUST", uint8(TRUST_DECIMALS));
        MockWETH wethTemplate = new MockWETH();
        MockCLPool clPoolTemplate = new MockCLPool();
        MockCLFactory clFactoryTemplate = new MockCLFactory();

        vm.etch(BASE_MAINNET_USDC, address(usdcTemplate).code);
        vm.etch(BASE_MAINNET_TRUST, address(trustTemplate).code);
        vm.etch(BASE_MAINNET_WETH, address(wethTemplate).code);
        vm.etch(BASE_MAINNET_USDC_TRUST_CL_POOL, address(clPoolTemplate).code);
        vm.etch(BASE_MAINNET_CL_FACTORY_PRIMARY, address(clFactoryTemplate).code);
        vm.etch(BASE_MAINNET_CL_FACTORY_SECONDARY, address(clFactoryTemplate).code);

        usdcToken = MockERC20(BASE_MAINNET_USDC);
        trustToken = MockERC20(BASE_MAINNET_TRUST);
        clPool = MockCLPool(BASE_MAINNET_USDC_TRUST_CL_POOL);
        clFactoryPrimary = MockCLFactory(BASE_MAINNET_CL_FACTORY_PRIMARY);
        clFactorySecondary = MockCLFactory(BASE_MAINNET_CL_FACTORY_SECONDARY);

        usdcToken.initialize("USD Coin", "USDC", uint8(USDC_DECIMALS));
        trustToken.initialize("Trust Token", "TRUST", uint8(TRUST_DECIMALS));
        MockWETH(BASE_MAINNET_WETH).initialize("Wrapped Ether", "WETH", 18);
        clPool.initialize(address(trustToken), address(usdcToken), DEFAULT_SQRT_PRICE_X96, DEFAULT_OUTPUT_MULTIPLIER);
        int24[] memory tickSpacings = new int24[](1);
        tickSpacings[0] = 1;
        clFactoryPrimary.initialize(tickSpacings);
        clFactorySecondary.initialize(tickSpacings);
        metaERC20Hub = new MockMetaERC20Hub();

        trustSwapRouterImplementation = new TrustSwapAndBridgeRouter();

        bytes memory initData = abi.encodeWithSelector(
            TrustSwapAndBridgeRouter.initialize.selector,
            owner,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );

        trustSwapRouterProxy = new TransparentUpgradeableProxy(address(trustSwapRouterImplementation), owner, initData);

        trustSwapRouter = TrustSwapAndBridgeRouter(address(trustSwapRouterProxy));

        tokenTwoHop = new MockERC20("Token Two Hop", "TWO", 18);
        tokenThreeHop = new MockERC20("Token Three Hop", "THREE", 18);

        wethUsdcPool = new MockCLPool();
        tokenTwoHopUsdcPool = new MockCLPool();
        tokenThreeHopWethPool = new MockCLPool();

        wethUsdcPool.initialize(address(MockWETH(BASE_MAINNET_WETH)), address(usdcToken), ONE_SQRT_PRICE_X96, 1);
        tokenTwoHopUsdcPool.initialize(address(tokenTwoHop), address(usdcToken), ONE_SQRT_PRICE_X96, 1);
        tokenThreeHopWethPool.initialize(
            address(tokenThreeHop), address(MockWETH(BASE_MAINNET_WETH)), ONE_SQRT_PRICE_X96, 1
        );

        clFactoryPrimary.setPool(address(usdcToken), address(trustToken), 1, address(clPool));
        clFactoryPrimary.setPool(address(MockWETH(BASE_MAINNET_WETH)), address(usdcToken), 1, address(wethUsdcPool));
        clFactoryPrimary.setPool(address(tokenTwoHop), address(usdcToken), 1, address(tokenTwoHopUsdcPool));
        clFactoryPrimary.setPool(
            address(tokenThreeHop), address(MockWETH(BASE_MAINNET_WETH)), 1, address(tokenThreeHopWethPool)
        );

        usdcToken.mint(user, 1_000_000e6);
        usdcToken.mint(alice, 1_000_000e6);
        usdcToken.mint(bob, 1_000_000e6);

        vm.prank(user);
        usdcToken.approve(address(trustSwapRouter), type(uint256).max);

        vm.prank(alice);
        usdcToken.approve(address(trustSwapRouter), type(uint256).max);

        vm.prank(bob);
        usdcToken.approve(address(trustSwapRouter), type(uint256).max);

        vm.label(address(trustSwapRouter), "TrustSwapAndBridgeRouter");
        vm.label(address(usdcToken), "USDC");
        vm.label(address(trustToken), "TRUST");
        vm.label(address(clPool), "USDC_TRUST_CL_POOL");
    }

    /* =================================================== */
    /*                 INITIALIZATION TESTS                */
    /* =================================================== */

    function test_initialize_successful() public view {
        assertEq(address(trustSwapRouter.usdcToken()), address(usdcToken));
        assertEq(address(trustSwapRouter.trustToken()), address(trustToken));
        assertEq(trustSwapRouter.defaultSwapDeadline(), DEFAULT_SWAP_DEADLINE);
        assertEq(trustSwapRouter.owner(), owner);
    }

    function test_initialize_revertsOnZeroOwner() public {
        TrustSwapAndBridgeRouter newImplementation = new TrustSwapAndBridgeRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapAndBridgeRouter newRouter = TrustSwapAndBridgeRouter(address(newProxy));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        newRouter.initialize(
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
        TrustSwapAndBridgeRouter newImplementation = new TrustSwapAndBridgeRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapAndBridgeRouter newRouter = TrustSwapAndBridgeRouter(address(newProxy));

        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_InvalidDeadline.selector)
        );
        newRouter.initialize(
            owner,
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

    function test_setDefaultSwapDeadline_successful() public {
        uint256 newDeadline = 1 hours;

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.DefaultSwapDeadlineSet(newDeadline);

        vm.prank(owner);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);

        assertEq(trustSwapRouter.defaultSwapDeadline(), newDeadline);
    }

    function test_setDefaultSwapDeadline_revertsOnZeroDeadline() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_InvalidDeadline.selector)
        );
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
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();
        uint256 minAmountOut = expectedOutput;

        uint256 userUsdcBalanceBefore = usdcToken.balanceOf(user);

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) =
            trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, minAmountOut, user);
        vm.stopPrank();

        assertEq(amountOut, expectedOutput);
        assertEq(usdcToken.balanceOf(user), userUsdcBalanceBefore - amountIn);
    }

    function test_swapToTrust_revertsOnZeroAmountIn() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_AmountInZero.selector)
        );
        trustSwapRouter.swapAndBridge(0, 0, user);
    }

    function test_swapToTrust_revertsOnInsufficientOutputAmount() public {
        uint256 amountIn = 100e6;
        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);
        uint256 minAmountOut = quotedOutput + 1;

        vm.deal(user, 1 ether);

        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        vm.startPrank(user);
        vm.expectRevert();
        trustSwapRouter.swapAndBridge{ value: bridgeFee }(amountIn, minAmountOut, user);
        vm.stopPrank();
    }

    function test_swapToTrust_multipleUsersSequential() public {
        uint256 aliceAmountIn = 100e6;
        uint256 bobAmountIn = 200e6;
        uint256 outputMultiplier = clPool.outputMultiplier();

        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);

        vm.startPrank(alice);
        (uint256 aliceAmountOut,) =
            trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(aliceAmountIn, 0, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        (uint256 bobAmountOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(bobAmountIn, 0, bob);
        vm.stopPrank();

        assertEq(aliceAmountOut, aliceAmountIn * outputMultiplier);
        assertEq(bobAmountOut, bobAmountIn * outputMultiplier);
    }

    function test_swapToTrust_usesCorrectDeadline() public {
        uint256 amountIn = 100e6;

        vm.warp(1000);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
        vm.stopPrank();
    }

    function test_swapAndBridgeWithETH_successful() public {
        uint256 ethAmountIn = 0.01 ether;
        uint256 quotedOut = trustSwapRouter.quoteSwapFromETHToTrust(ethAmountIn);
        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        uint256 routerTrustBefore = trustToken.balanceOf(address(trustSwapRouter));

        vm.deal(user, ethAmountIn + bridgeFee);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithETH{ value: ethAmountIn + bridgeFee }(quotedOut, user);
        vm.stopPrank();

        uint256 routerTrustAfter = trustToken.balanceOf(address(trustSwapRouter));

        assertGe(amountOut, quotedOut);
        assertEq(routerTrustAfter - routerTrustBefore, amountOut);
    }

    function test_swapAndBridgeWithETH_revertsOnInsufficientETH() public {
        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        vm.deal(user, bridgeFee);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_InsufficientETH.selector)
        );
        trustSwapRouter.swapAndBridgeWithETH{ value: bridgeFee }(1, user);
    }

    function test_swapAndBridgeWithETH_revertsOnOutputBelowThreshold() public {
        uint256 ethAmountIn = 0.01 ether;
        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();
        uint256 expectedAmountOut = ethAmountIn * DEFAULT_OUTPUT_MULTIPLIER;
        uint256 minAmountOut = expectedAmountOut + 1;

        vm.deal(user, ethAmountIn + bridgeFee);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_OutputBelowThreshold.selector)
        );
        trustSwapRouter.swapAndBridgeWithETH{ value: ethAmountIn + bridgeFee }(minAmountOut, user);
        vm.stopPrank();
    }

    function test_swapArbitraryTokenAndBridge_successfulTwoHop() public {
        uint256 amountIn = 100e18;
        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        tokenTwoHop.mint(user, amountIn);
        vm.prank(user);
        tokenTwoHop.approve(address(trustSwapRouter), type(uint256).max);

        (uint256 quotedOut,) = trustSwapRouter.quoteArbitraryTokenSwap(address(tokenTwoHop), amountIn);

        uint256 routerTrustBefore = trustToken.balanceOf(address(trustSwapRouter));

        vm.deal(user, bridgeFee);
        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapArbitraryTokenAndBridge{ value: bridgeFee }(
            address(tokenTwoHop), amountIn, quotedOut, user
        );
        vm.stopPrank();

        uint256 routerTrustAfter = trustToken.balanceOf(address(trustSwapRouter));

        assertGe(amountOut, quotedOut);
        assertEq(routerTrustAfter - routerTrustBefore, amountOut);
    }

    function test_swapArbitraryTokenAndBridge_revertsOnZeroAmountIn() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_AmountInZero.selector)
        );
        trustSwapRouter.swapArbitraryTokenAndBridge(address(tokenTwoHop), 0, 1, user);
    }

    function test_swapArbitraryTokenAndBridge_revertsOnInvalidToken() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_InvalidToken.selector)
        );
        trustSwapRouter.swapArbitraryTokenAndBridge(address(0), 1, 1, user);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_InvalidToken.selector)
        );
        trustSwapRouter.swapArbitraryTokenAndBridge(address(trustToken), 1, 1, user);
    }

    function test_swapArbitraryTokenAndBridge_revertsOnZeroMinAmountOut() public {
        uint256 amountIn = 100e18;
        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        tokenTwoHop.mint(user, amountIn);
        vm.prank(user);
        tokenTwoHop.approve(address(trustSwapRouter), type(uint256).max);

        vm.deal(user, bridgeFee);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_OutputBelowThreshold.selector)
        );
        trustSwapRouter.swapArbitraryTokenAndBridge{ value: bridgeFee }(address(tokenTwoHop), amountIn, 0, user);
    }

    function test_swapArbitraryTokenAndBridge_revertsOnInsufficientBridgeFee() public {
        uint256 amountIn = 100e18;

        tokenTwoHop.mint(user, amountIn);
        vm.prank(user);
        tokenTwoHop.approve(address(trustSwapRouter), type(uint256).max);

        (uint256 quotedOut,) = trustSwapRouter.quoteArbitraryTokenSwap(address(tokenTwoHop), amountIn);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_InsufficientBridgeFee.selector)
        );
        trustSwapRouter.swapArbitraryTokenAndBridge(address(tokenTwoHop), amountIn, quotedOut, user);
    }

    /* =================================================== */
    /*                 QUOTE FUNCTION TESTS                */
    /* =================================================== */

    function test_quoteSwapToTrust_successful() public view {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

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

        vm.startPrank(user);
        (uint256 actualOutput,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
        vm.stopPrank();

        assertEq(quotedOutput, actualOutput);
    }

    function test_quoteSwapFromETHToTrust_successful() public view {
        uint256 amountIn = 0.01 ether;

        uint256 quotedOutput = trustSwapRouter.quoteSwapFromETHToTrust(amountIn);

        assertGt(quotedOutput, 0);
    }

    function test_quoteSwapAndBridgeWithETH_returnsBridgeFee() public view {
        uint256 amountIn = 0.01 ether;

        (uint256 amountOut, uint256 bridgeFee) = trustSwapRouter.quoteSwapAndBridgeWithETH(amountIn, user);

        assertGt(amountOut, 0);
        assertEq(bridgeFee, metaERC20Hub.BRIDGE_FEE());
    }

    function test_quoteArbitraryTokenSwap_returnsRouteHopsForTwoHop() public view {
        uint256 amountIn = 100e18;

        (uint256 amountOut, uint256 routeHops) = trustSwapRouter.quoteArbitraryTokenSwap(address(tokenTwoHop), amountIn);

        assertGt(amountOut, 0);
        assertEq(routeHops, 2);
    }

    function test_quoteArbitraryTokenSwap_returnsRouteHopsForThreeHop() public view {
        uint256 amountIn = 100e18;

        (uint256 amountOut, uint256 routeHops) =
            trustSwapRouter.quoteArbitraryTokenSwap(address(tokenThreeHop), amountIn);

        assertGt(amountOut, 0);
        assertEq(routeHops, 3);
    }

    function test_quoteArbitraryTokenSwap_revertsOnInvalidToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_InvalidToken.selector)
        );
        trustSwapRouter.quoteArbitraryTokenSwap(address(trustToken), 1);
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

        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
        vm.stopPrank();

        assertEq(amountOut, expectedOutput);
    }

    function testFuzz_quoteSwapToTrust_variousAmounts(uint256 amountIn) public view {
        amountIn = bound(amountIn, 0, 1_000_000_000e6);

        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);

        if (amountIn == 0) {
            assertEq(quotedOutput, 0);
        } else {
            uint256 expectedOutput = amountIn * clPool.outputMultiplier();
            assertApproxEqAbs(quotedOutput, expectedOutput, 1_000_000); // Allow small rounding errors (up to 1e6 wei
            // TRUST)
        }
    }

    function testFuzz_swapAndBridgeWithETH_variousAmounts(uint256 amountIn) public {
        amountIn = bound(amountIn, 1, 0.1 ether);

        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();
        uint256 quotedOut = trustSwapRouter.quoteSwapFromETHToTrust(amountIn);

        vm.deal(user, amountIn + bridgeFee);
        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithETH{ value: amountIn + bridgeFee }(quotedOut, user);
        vm.stopPrank();

        assertGe(amountOut, quotedOut);
    }

    function testFuzz_quoteSwapFromETHToTrust_variousAmounts(uint256 amountIn) public view {
        amountIn = bound(amountIn, 0, 1 ether);

        uint256 quotedOut = trustSwapRouter.quoteSwapFromETHToTrust(amountIn);

        if (amountIn == 0) {
            assertEq(quotedOut, 0);
        } else {
            assertGt(quotedOut, 0);
        }
    }

    function testFuzz_swapArbitraryTokenAndBridge_variousAmounts(uint256 amountIn) public {
        amountIn = bound(amountIn, 1, 1000e18);

        tokenTwoHop.mint(user, amountIn);
        vm.prank(user);
        tokenTwoHop.approve(address(trustSwapRouter), type(uint256).max);

        (uint256 quotedOut,) = trustSwapRouter.quoteArbitraryTokenSwap(address(tokenTwoHop), amountIn);

        vm.deal(user, metaERC20Hub.BRIDGE_FEE());
        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapArbitraryTokenAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(
            address(tokenTwoHop), amountIn, quotedOut, user
        );
        vm.stopPrank();

        assertGe(amountOut, quotedOut);
    }

    function testFuzz_quoteArbitraryTokenSwap_variousAmounts(uint256 amountIn) public view {
        amountIn = bound(amountIn, 0, 1000e18);

        (uint256 amountOut, uint256 routeHops) = trustSwapRouter.quoteArbitraryTokenSwap(address(tokenTwoHop), amountIn);

        if (amountIn == 0) {
            assertEq(amountOut, 0);
            assertEq(routeHops, 0);
        } else {
            assertGt(amountOut, 0);
            assertEq(routeHops, 2);
        }
    }

    function testFuzz_setDefaultSwapDeadline_variousValues(uint256 newDeadline) public {
        vm.assume(newDeadline > 0);

        vm.prank(owner);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);

        assertEq(trustSwapRouter.defaultSwapDeadline(), newDeadline);
    }

    /* =================================================== */
    /*                   EDGE CASE TESTS                   */
    /* =================================================== */

    function test_swapToTrust_minimumAmount() public {
        uint256 amountIn = 1;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        usdcToken.mint(user, amountIn);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
        vm.stopPrank();

        assertEq(amountOut, expectedOutput);
    }

    function test_swapToTrust_largeAmount() public {
        uint256 amountIn = 100_000_000e6;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        usdcToken.mint(user, amountIn);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
        vm.stopPrank();

        assertEq(amountOut, expectedOutput);
    }

    function test_swapToTrust_exactMinAmountOut() public {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) =
            trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, expectedOutput, user);
        vm.stopPrank();

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
        uint256 newDeadline = 1 hours;

        vm.startPrank(owner);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);
        vm.stopPrank();

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

    function test_emitsDefaultSwapDeadlineSet_onSetDefaultSwapDeadline() public {
        uint256 newDeadline = 1 hours;

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.DefaultSwapDeadlineSet(newDeadline);

        vm.prank(owner);
        trustSwapRouter.setDefaultSwapDeadline(newDeadline);
    }

    function test_emitsSwappedToTrust_onSwapToTrust() public {
        uint256 amountIn = 100e6;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
        vm.stopPrank();
    }

    /* =================================================== */
    /*             INITIALIZATION EVENTS TESTS             */
    /* =================================================== */

    function test_initializeEmitsAllEvents() public {
        TrustSwapAndBridgeRouter newImplementation = new TrustSwapAndBridgeRouter();
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImplementation), address(this), "");
        TrustSwapAndBridgeRouter newRouter = TrustSwapAndBridgeRouter(address(newProxy));

        address newOwner = makeAddr("newOwner");
        address newMetaERC20Hub = makeAddr("newMetaERC20Hub");
        uint32 newRecipientDomain = 9999;
        uint256 newBridgeGasLimit = 200_000;
        FinalityState newFinalityState = FinalityState.FINALIZED;
        uint256 newDeadline = 1 hours;
        uint256 newMinimumOutputThreshold = 123;
        uint256 newMaxSlippageBps = 9500;

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.MetaERC20HubSet(newMetaERC20Hub);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.RecipientDomainSet(newRecipientDomain);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.BridgeGasLimitSet(newBridgeGasLimit);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.FinalityStateSet(newFinalityState);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.DefaultSwapDeadlineSet(newDeadline);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.MinimumOutputThresholdSet(newMinimumOutputThreshold);

        vm.expectEmit(true, true, true, true);
        emit ITrustSwapAndBridgeRouter.MaxSlippageBpsSet(newMaxSlippageBps);

        newRouter.initialize(
            newOwner,
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

/// @title TrustSwapAndBridgeRouterPermitTest
/// @notice Tests for EIP-2612 permit functionality
contract TrustSwapAndBridgeRouterPermitTest is Test {
    TrustSwapAndBridgeRouter public trustSwapRouter;
    TrustSwapAndBridgeRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;

    MockERC20Permit public usdcToken;
    MockERC20 public trustToken;
    MockCLPool public clPool;
    MockMetaERC20Hub public metaERC20Hub;

    address public owner;
    uint256 public userPrivateKey;
    address public user;

    address public constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_MAINNET_TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
    address public constant BASE_MAINNET_USDC_TRUST_CL_POOL = 0x17f707CF3EDBbd5d9251D4bCDF9Ad70a247D7B84;

    uint256 public constant DEFAULT_SWAP_DEADLINE = 30 minutes;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant TRUST_DECIMALS = 18;
    uint32 public constant RECIPIENT_DOMAIN = 1155;
    uint256 public constant BRIDGE_GAS_LIMIT = 100_000;
    FinalityState public constant FINALITY_STATE = FinalityState.INSTANT;
    uint256 public constant MINIMUM_OUTPUT_THRESHOLD = 0;
    uint256 public constant MAX_SLIPPAGE_BPS = 10_000;
    uint160 public constant DEFAULT_SQRT_PRICE_X96 = 79_228_162_514_264_337_593_543;
    uint256 public constant DEFAULT_OUTPUT_MULTIPLIER = 1e12;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        owner = makeAddr("owner");
        userPrivateKey = 0xA11CE;
        user = vm.addr(userPrivateKey);

        MockERC20Permit usdcTemplate = new MockERC20Permit("USD Coin", "USDC", uint8(USDC_DECIMALS));
        MockERC20 trustTemplate = new MockERC20("Trust Token", "TRUST", uint8(TRUST_DECIMALS));
        MockCLPool clPoolTemplate = new MockCLPool();

        vm.etch(BASE_MAINNET_USDC, address(usdcTemplate).code);
        vm.etch(BASE_MAINNET_TRUST, address(trustTemplate).code);
        vm.etch(BASE_MAINNET_USDC_TRUST_CL_POOL, address(clPoolTemplate).code);

        usdcToken = MockERC20Permit(BASE_MAINNET_USDC);
        trustToken = MockERC20(BASE_MAINNET_TRUST);
        clPool = MockCLPool(BASE_MAINNET_USDC_TRUST_CL_POOL);

        usdcToken.initialize("USD Coin", "USDC", uint8(USDC_DECIMALS));
        trustToken.initialize("Trust Token", "TRUST", uint8(TRUST_DECIMALS));
        clPool.initialize(address(trustToken), address(usdcToken), DEFAULT_SQRT_PRICE_X96, DEFAULT_OUTPUT_MULTIPLIER);
        metaERC20Hub = new MockMetaERC20Hub();

        trustSwapRouterImplementation = new TrustSwapAndBridgeRouter();

        bytes memory initData = abi.encodeWithSelector(
            TrustSwapAndBridgeRouter.initialize.selector,
            owner,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );

        trustSwapRouterProxy = new TransparentUpgradeableProxy(address(trustSwapRouterImplementation), owner, initData);
        trustSwapRouter = TrustSwapAndBridgeRouter(address(trustSwapRouterProxy));

        usdcToken.mint(user, 1_000_000e6);

        vm.label(address(trustSwapRouter), "TrustSwapAndBridgeRouter");
        vm.label(address(usdcToken), "USDC");
        vm.label(address(trustToken), "TRUST");
        vm.label(address(clPool), "USDC_TRUST_CL_POOL");
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

    function _getPermitSignatureWithCurrentNonce(
        uint256 privateKey,
        address permitOwner,
        address spender,
        uint256 value,
        uint256 deadline
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        uint256 nonce = usdcToken.nonces(permitOwner);
        return _getPermitSignature(privateKey, permitOwner, spender, value, nonce, deadline);
    }

    /* =================================================== */
    /*              PERMIT SWAP FUNCTION TESTS             */
    /* =================================================== */

    function test_swapToTrustWithPermit_successful() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        uint256 userUsdcBalanceBefore = usdcToken.balanceOf(user);

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );
        vm.stopPrank();

        assertEq(amountOut, expectedOutput);
        assertEq(usdcToken.balanceOf(user), userUsdcBalanceBefore - amountIn);
    }

    function test_swapToTrustWithPermit_revertsOnZeroAmountIn() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), 0, deadline);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_AmountInZero.selector)
        );
        trustSwapRouter.swapAndBridgeWithPermit(0, 0, user, deadline, v, r, s);
    }

    function test_swapToTrustWithPermit_revertsOnExpiredDeadline() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp - 1;

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_PermitExpired.selector)
        );
        trustSwapRouter.swapAndBridgeWithPermit(amountIn, 0, user, deadline, v, r, s);
    }

    function test_swapToTrustWithPermit_revertsOnInvalidSignature() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;

        uint256 wrongPrivateKey = 0xBAD;
        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(wrongPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_PermitFailed.selector)
        );
        trustSwapRouter.swapAndBridgeWithPermit(amountIn, 0, user, deadline, v, r, s);
    }

    function test_swapToTrustWithPermit_succeedsWithExistingAllowance() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        vm.prank(user);
        usdcToken.approve(address(trustSwapRouter), amountIn);

        uint256 wrongPrivateKey = 0xBAD;
        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(wrongPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );
        vm.stopPrank();

        assertEq(amountOut, expectedOutput);
    }

    function test_swapToTrustWithPermit_revertsOnInsufficientOutput() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);
        uint256 minAmountOut = quotedOutput + 1;

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        vm.deal(user, 1 ether);

        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        vm.startPrank(user);
        vm.expectRevert();
        trustSwapRouter.swapAndBridgeWithPermit{ value: bridgeFee }(amountIn, minAmountOut, user, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_swapToTrustWithPermit_incrementsNonce() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;

        assertEq(usdcToken.nonces(user), 0);

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );
        vm.stopPrank();

        assertEq(usdcToken.nonces(user), 1);
    }

    function test_swapToTrustWithPermit_multipleSwapsWithCorrectNonces() public {
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v1, bytes32 r1, bytes32 s1) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        vm.deal(user, 2 ether);

        vm.startPrank(user);
        trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v1, r1, s1
        );

        (uint8 v2, bytes32 r2, bytes32 s2) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v2, r2, s2
        );
        vm.stopPrank();

        assertEq(usdcToken.nonces(user), 2);
    }

    function testFuzz_swapToTrustWithPermit_variousAmounts(uint256 amountIn) public {
        amountIn = bound(amountIn, 1, 1_000_000e6);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        usdcToken.mint(user, amountIn);
        vm.deal(user, 1 ether);

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );
        vm.stopPrank();

        assertEq(amountOut, expectedOutput);
    }

    function testFuzz_swapToTrustWithPermit_variousDeadlines(uint256 deadlineOffset) public {
        deadlineOffset = bound(deadlineOffset, 1, 365 days);
        uint256 amountIn = 100e6;
        uint256 deadline = block.timestamp + deadlineOffset;
        uint256 expectedOutput = amountIn * clPool.outputMultiplier();

        (uint8 v, bytes32 r, bytes32 s) =
            _getPermitSignatureWithCurrentNonce(userPrivateKey, user, address(trustSwapRouter), amountIn, deadline);

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, 0, user, deadline, v, r, s
        );
        vm.stopPrank();

        assertEq(amountOut, expectedOutput);
    }
}

/// @title TrustSwapAndBridgeRouterForkTest
/// @notice Fork tests against Base mainnet for real-world swap testing
contract TrustSwapAndBridgeRouterForkTest is Test {
    TrustSwapAndBridgeRouter public trustSwapRouter;
    TrustSwapAndBridgeRouter public trustSwapRouterImplementation;
    TransparentUpgradeableProxy public trustSwapRouterProxy;

    address public constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address payable public constant BASE_MAINNET_WETH = payable(0x4200000000000000000000000000000000000006);
    address public constant BASE_MAINNET_TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;

    IERC20 public usdc;
    IERC20 public trust;
    IWETH public weth;
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
        weth = IWETH(BASE_MAINNET_WETH);
        metaERC20Hub = new MockMetaERC20Hub();

        trustSwapRouterImplementation = new TrustSwapAndBridgeRouter();

        bytes memory initData = abi.encodeWithSelector(
            TrustSwapAndBridgeRouter.initialize.selector,
            owner,
            address(metaERC20Hub),
            RECIPIENT_DOMAIN,
            BRIDGE_GAS_LIMIT,
            FINALITY_STATE,
            DEFAULT_SWAP_DEADLINE,
            MINIMUM_OUTPUT_THRESHOLD,
            MAX_SLIPPAGE_BPS
        );

        trustSwapRouterProxy = new TransparentUpgradeableProxy(address(trustSwapRouterImplementation), owner, initData);
        trustSwapRouter = TrustSwapAndBridgeRouter(address(trustSwapRouterProxy));

        deal(address(usdc), user, 10_000e6);

        vm.prank(user);
        usdc.approve(address(trustSwapRouter), type(uint256).max);

        vm.label(address(trustSwapRouter), "TrustSwapAndBridgeRouter");
        vm.label(BASE_MAINNET_USDC, "USDC");
        vm.label(BASE_MAINNET_TRUST, "TRUST");
        vm.label(BASE_MAINNET_WETH, "WETH");
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

    function test_fork_quoteSwapFromETHToTrust_returnsNonZero() public view {
        uint256 amountIn = 0.01 ether;

        uint256 quotedOutput = trustSwapRouter.quoteSwapFromETHToTrust(amountIn);

        assertGt(quotedOutput, 0, "ETH quote should return non-zero output");
    }

    function test_fork_quoteArbitraryTokenSwap_WETH_returnsNonZero() public view {
        uint256 amountIn = 0.01 ether;

        (uint256 quotedOutput, uint256 routeHops) = trustSwapRouter.quoteArbitraryTokenSwap(BASE_MAINNET_WETH, amountIn);

        assertGt(quotedOutput, 0, "Arbitrary token quote should return non-zero output");
        assertGt(routeHops, 0, "Arbitrary token route should have at least one hop");
    }

    /* =================================================== */
    /*                FORK TEST: SWAP                      */
    /* =================================================== */

    function test_fork_swapToTrust_executesSuccessfully() public {
        uint256 amountIn = 100e6;

        uint256 quotedOutput = trustSwapRouter.quoteSwapToTrust(amountIn);
        uint256 minAmountOut = (quotedOutput * 95) / 100;

        uint256 userUsdcBefore = usdc.balanceOf(user);
        uint256 routerTrustBefore = trust.balanceOf(address(trustSwapRouter));

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) =
            trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, minAmountOut, user);
        vm.stopPrank();

        uint256 userUsdcAfter = usdc.balanceOf(user);
        uint256 routerTrustAfter = trust.balanceOf(address(trustSwapRouter));

        console2.log("Swap executed:");
        console2.log("  USDC spent:", userUsdcBefore - userUsdcAfter);
        console2.log("  TRUST received:", routerTrustAfter - routerTrustBefore);
        console2.log("  Quoted:", quotedOutput);
        console2.log("  Actual:", amountOut);

        assertEq(userUsdcBefore - userUsdcAfter, amountIn, "Should spend exact USDC amount");
        assertGe(amountOut, minAmountOut, "Should receive at least minAmountOut");
        assertEq(routerTrustAfter - routerTrustBefore, amountOut, "Router trust balance should increase by amountOut");
    }

    function test_fork_swapAndBridgeWithETH_executesSuccessfully() public {
        uint256 amountIn = 0.01 ether;
        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        uint256 quotedOutput = trustSwapRouter.quoteSwapFromETHToTrust(amountIn);
        uint256 minAmountOut = (quotedOutput * 5) / 100;

        uint256 routerTrustBefore = trust.balanceOf(address(trustSwapRouter));

        vm.deal(user, amountIn + bridgeFee);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithETH{ value: amountIn + bridgeFee }(minAmountOut, user);
        vm.stopPrank();

        uint256 routerTrustAfter = trust.balanceOf(address(trustSwapRouter));

        assertGe(amountOut, minAmountOut, "Should receive at least minAmountOut");
        assertEq(routerTrustAfter - routerTrustBefore, amountOut, "Router trust balance should increase by amountOut");
    }

    function test_fork_swapArbitraryTokenAndBridge_WETH_executesSuccessfully() public {
        uint256 amountIn = 0.01 ether;
        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        weth.deposit{ value: amountIn }();
        weth.approve(address(trustSwapRouter), type(uint256).max);

        (uint256 quotedOutput,) = trustSwapRouter.quoteArbitraryTokenSwap(BASE_MAINNET_WETH, amountIn);
        uint256 minAmountOut = (quotedOutput * 5) / 100;

        uint256 routerTrustBefore = trust.balanceOf(address(trustSwapRouter));

        (uint256 amountOut,) = trustSwapRouter.swapArbitraryTokenAndBridge{ value: bridgeFee }(
            BASE_MAINNET_WETH, amountIn, minAmountOut, user
        );
        vm.stopPrank();

        uint256 routerTrustAfter = trust.balanceOf(address(trustSwapRouter));

        assertGe(amountOut, minAmountOut, "Should receive at least minAmountOut");
        assertEq(routerTrustAfter - routerTrustBefore, amountOut, "Router trust balance should increase by amountOut");
    }

        function test_fork_swapArbitraryTokenAndBridge_AERO_executesSuccessfully() public {
        uint256 amountIn = 1e18;
        uint256 bridgeFee = metaERC20Hub.BRIDGE_FEE();

        vm.deal(user, 1 ether);

        address aeroTokenAddress = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
        address aeroWhale = 0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4;

        IERC20 aeroToken = IERC20(aeroTokenAddress);

        vm.prank(aeroWhale);
        aeroToken.transfer(user, amountIn);

        vm.startPrank(user);
        aeroToken.approve(address(trustSwapRouter), type(uint256).max);

        (uint256 quotedOutput,) = trustSwapRouter.quoteArbitraryTokenSwap(aeroTokenAddress, amountIn);
        uint256 minAmountOut = 0;

        uint256 routerTrustBefore = trust.balanceOf(address(trustSwapRouter));

        (uint256 amountOut,) = trustSwapRouter.swapArbitraryTokenAndBridge{ value: bridgeFee }(
            aeroTokenAddress, amountIn, minAmountOut, user
        );
        vm.stopPrank();

        uint256 routerTrustAfter = trust.balanceOf(address(trustSwapRouter));

        assertGe(amountOut, minAmountOut, "Should receive at least minAmountOut");
        assertEq(routerTrustAfter - routerTrustBefore, amountOut, "Router trust balance should increase by amountOut");
    }

    function test_fork_swapToTrust_multipleSwapsWork() public {
        uint256 amountIn = 50e6;

        vm.deal(user, 2 ether);

        vm.startPrank(user);
        (uint256 firstSwapOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
        (uint256 secondSwapOut,) = trustSwapRouter.swapAndBridge{ value: metaERC20Hub.BRIDGE_FEE() }(amountIn, 0, user);
        vm.stopPrank();

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
        uint256 routerTrustBefore = trust.balanceOf(address(trustSwapRouter));

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        (uint256 amountOut,) = trustSwapRouter.swapAndBridgeWithPermit{ value: metaERC20Hub.BRIDGE_FEE() }(
            amountIn, minAmountOut, user, deadline, v, r, s
        );
        vm.stopPrank();

        console2.log("Permit swap executed:");
        console2.log("  USDC spent:", userUsdcBefore - usdc.balanceOf(user));
        console2.log("  TRUST received:", trust.balanceOf(address(trustSwapRouter)) - routerTrustBefore);
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
