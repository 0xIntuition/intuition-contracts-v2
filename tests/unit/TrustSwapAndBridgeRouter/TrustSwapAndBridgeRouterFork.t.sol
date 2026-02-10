// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { TrustSwapAndBridgeRouter } from "src/utils/TrustSwapAndBridgeRouter.sol";
import { ITrustSwapAndBridgeRouter, RouterConfig } from "src/interfaces/ITrustSwapAndBridgeRouter.sol";
import { ICLFactory } from "src/interfaces/external/aerodrome/ICLFactory.sol";
import { ICLQuoter } from "src/interfaces/external/aerodrome/ICLQuoter.sol";
import { FinalityState, IMetaERC20Hub } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";

/**
 * @title TrustSwapAndBridgeRouterFork
 * @notice Fork integration tests against real Aerodrome Slipstream pools on Base mainnet.
 *         MetaERC20Hub bridge calls are mocked via vm.mockCall since the hub's domain config
 *         is not controllable in a fork environment.
 */
contract TrustSwapAndBridgeRouterFork is Test {
    /* =================================================== */
    /*                   BASE ADDRESSES                    */
    /* =================================================== */

    address public constant TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;

    address public constant CL_SWAP_ROUTER = 0xcbBb8035cAc7D4B3Ca7aBb74cF7BdF900215Ce0D;
    address public constant CL_FACTORY = 0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a;
    address public constant CL_QUOTER = 0x3d4C22254F86f64B7eC90ab8F7aeC1FBFD271c6C;
    address public constant META_ERC20_HUB = 0xE12aaF1529Ae21899029a9b51cca2F2Bc2cfC421;

    uint256 public constant FORK_BLOCK = 41_970_000;

    uint32 public constant RECIPIENT_DOMAIN = 1155;
    uint256 public constant BRIDGE_GAS_LIMIT = 100_000;
    uint256 public constant MOCK_BRIDGE_FEE = 0.001 ether;
    bytes32 public constant MOCK_TRANSFER_ID = keccak256("mock-transfer-id");

    /* =================================================== */
    /*                   TICK SPACINGS                     */
    /* =================================================== */

    int24 public constant TS_WETH_USDC = 50;
    int24 public constant TS_USDC_TRUST = 1;
    int24 public constant TS_DAI_USDC = 1;

    /* =================================================== */
    /*                   TEST STATE                        */
    /* =================================================== */

    TrustSwapAndBridgeRouter public router;
    address public owner = address(0xABCD);
    address public user = address(0xBEEF);
    address public recipient = address(0xCAFE);
    address public proxyAdmin = address(0xAD);

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);

        // Deploy router implementation + proxy
        TrustSwapAndBridgeRouter implementation = new TrustSwapAndBridgeRouter();

        RouterConfig memory config = RouterConfig({
            slipstreamSwapRouter: CL_SWAP_ROUTER,
            slipstreamFactory: CL_FACTORY,
            slipstreamQuoter: CL_QUOTER,
            metaERC20Hub: META_ERC20_HUB,
            recipientDomain: RECIPIENT_DOMAIN,
            bridgeGasLimit: BRIDGE_GAS_LIMIT,
            finalityState: FinalityState.INSTANT
        });

        bytes memory initData = abi.encodeWithSelector(TrustSwapAndBridgeRouter.initialize.selector, owner, config);

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(implementation), proxyAdmin, initData);

        router = TrustSwapAndBridgeRouter(payable(address(proxy)));

        // Mock MetaERC20Hub.quoteTransferRemote → returns MOCK_BRIDGE_FEE
        vm.mockCall(
            META_ERC20_HUB,
            abi.encodeWithSelector(IMetaERC20Hub.quoteTransferRemote.selector),
            abi.encode(MOCK_BRIDGE_FEE)
        );

        // Mock MetaERC20Hub.transferRemote → returns MOCK_TRANSFER_ID
        vm.mockCall(
            META_ERC20_HUB, abi.encodeWithSelector(IMetaERC20Hub.transferRemote.selector), abi.encode(MOCK_TRANSFER_ID)
        );

        // Fund user
        vm.deal(user, 100 ether);
    }

    /* =================================================== */
    /*           TEST 1: ETH → WETH → USDC → TRUST        */
    /* =================================================== */

    function test_fork_swapETHToTrustViaUSDC() external {
        bytes memory path = abi.encodePacked(WETH, TS_WETH_USDC, USDC, TS_USDC_TRUST, TRUST);

        uint256 swapEth = 0.01 ether;
        uint256 totalValue = swapEth + MOCK_BRIDGE_FEE;

        uint256 userEthBefore = user.balance;
        uint256 routerTrustBefore = IERC20(TRUST).balanceOf(address(router));

        vm.prank(user);
        (uint256 amountOut, bytes32 transferId) = router.swapAndBridgeWithETH{ value: totalValue }(path, 0, recipient);

        assertGt(amountOut, 0, "Should receive TRUST from swap");
        assertEq(transferId, MOCK_TRANSFER_ID, "Transfer ID should match mock");
        assertEq(user.balance, userEthBefore - totalValue, "User should spend exact ETH");

        // TRUST remains in router since bridge is mocked (mock doesn't pull tokens)
        uint256 routerTrustAfter = IERC20(TRUST).balanceOf(address(router));
        assertEq(routerTrustAfter - routerTrustBefore, amountOut, "Router should hold swapped TRUST");

        console2.log("ETH -> USDC -> TRUST: swapped %d wei ETH for %d TRUST", swapEth, amountOut);
    }

    function test_fork_swapETHToTrustViaUSDC_withMinOutput() external {
        bytes memory path = abi.encodePacked(WETH, TS_WETH_USDC, USDC, TS_USDC_TRUST, TRUST);

        uint256 swapEth = 0.01 ether;
        uint256 totalValue = swapEth + MOCK_BRIDGE_FEE;

        // First get a quote to know expected output
        (uint256 expectedOut,,,) = ICLQuoter(CL_QUOTER).quoteExactInput(path, swapEth);
        assertGt(expectedOut, 0, "Quote should return non-zero");

        // Use 99% of expected as minOutput (1% slippage tolerance)
        uint256 minTrustOut = (expectedOut * 99) / 100;

        vm.prank(user);
        (uint256 amountOut,) = router.swapAndBridgeWithETH{ value: totalValue }(path, minTrustOut, recipient);

        assertGe(amountOut, minTrustOut, "Output should meet minimum");

        console2.log("ETH -> USDC -> TRUST: quoted", expectedOut, "got", amountOut);
    }

    /* =================================================== */
    /*             TEST 2: USDC → TRUST DIRECT             */
    /* =================================================== */

    function test_fork_swapUSDCToTrustDirect() external {
        bytes memory path = abi.encodePacked(USDC, TS_USDC_TRUST, TRUST);

        uint256 amountIn = 10e6; // 10 USDC
        deal(USDC, user, amountIn);

        uint256 userUsdcBefore = IERC20(USDC).balanceOf(user);
        assertEq(userUsdcBefore, amountIn, "User should have USDC");

        vm.startPrank(user);
        IERC20(USDC).approve(address(router), amountIn);

        (uint256 amountOut, bytes32 transferId) =
            router.swapAndBridgeWithERC20{ value: MOCK_BRIDGE_FEE }(USDC, amountIn, path, 0, recipient);
        vm.stopPrank();

        assertGt(amountOut, 0, "Should receive TRUST from swap");
        assertEq(transferId, MOCK_TRANSFER_ID, "Transfer ID should match mock");
        assertEq(IERC20(USDC).balanceOf(user), 0, "User USDC should be spent");

        uint256 routerTrust = IERC20(TRUST).balanceOf(address(router));
        assertEq(routerTrust, amountOut, "Router should hold swapped TRUST");

        console2.log("USDC -> TRUST: swapped %d USDC for %d TRUST", amountIn, amountOut);
    }

    function test_fork_swapUSDCToTrustDirect_withMinOutput() external {
        bytes memory path = abi.encodePacked(USDC, TS_USDC_TRUST, TRUST);

        uint256 amountIn = 10e6; // 10 USDC
        deal(USDC, user, amountIn);

        // Get quote first
        (uint256 expectedOut,,,) = ICLQuoter(CL_QUOTER).quoteExactInput(path, amountIn);
        assertGt(expectedOut, 0, "Quote should return non-zero");

        uint256 minTrustOut = (expectedOut * 99) / 100;

        vm.startPrank(user);
        IERC20(USDC).approve(address(router), amountIn);

        (uint256 amountOut,) =
            router.swapAndBridgeWithERC20{ value: MOCK_BRIDGE_FEE }(USDC, amountIn, path, minTrustOut, recipient);
        vm.stopPrank();

        assertGe(amountOut, minTrustOut, "Output should meet minimum");

        console2.log("USDC -> TRUST: quoted", expectedOut, "got", amountOut);
    }

    /* =================================================== */
    /*        TEST 3: DAI → USDC → TRUST (TWO-HOP)        */
    /* =================================================== */

    function test_fork_swapDAIToTrustViaUSDC() external {
        bytes memory path = abi.encodePacked(DAI, TS_DAI_USDC, USDC, TS_USDC_TRUST, TRUST);

        uint256 amountIn = 10e18; // 10 DAI
        deal(DAI, user, amountIn);

        vm.startPrank(user);
        IERC20(DAI).approve(address(router), amountIn);

        (uint256 amountOut, bytes32 transferId) =
            router.swapAndBridgeWithERC20{ value: MOCK_BRIDGE_FEE }(DAI, amountIn, path, 0, recipient);
        vm.stopPrank();

        assertGt(amountOut, 0, "Should receive TRUST from swap");
        assertEq(transferId, MOCK_TRANSFER_ID, "Transfer ID should match mock");
        assertEq(IERC20(DAI).balanceOf(user), 0, "User DAI should be spent");

        uint256 routerTrust = IERC20(TRUST).balanceOf(address(router));
        assertEq(routerTrust, amountOut, "Router should hold swapped TRUST");

        console2.log("DAI -> USDC -> TRUST: swapped %d DAI for %d TRUST", amountIn, amountOut);
    }

    function test_fork_swapDAIToTrustViaUSDC_withMinOutput() external {
        bytes memory path = abi.encodePacked(DAI, TS_DAI_USDC, USDC, TS_USDC_TRUST, TRUST);

        uint256 amountIn = 10e18; // 10 DAI
        deal(DAI, user, amountIn);

        (uint256 expectedOut,,,) = ICLQuoter(CL_QUOTER).quoteExactInput(path, amountIn);
        assertGt(expectedOut, 0, "Quote should return non-zero");

        uint256 minTrustOut = (expectedOut * 99) / 100;

        vm.startPrank(user);
        IERC20(DAI).approve(address(router), amountIn);

        (uint256 amountOut,) =
            router.swapAndBridgeWithERC20{ value: MOCK_BRIDGE_FEE }(DAI, amountIn, path, minTrustOut, recipient);
        vm.stopPrank();

        assertGe(amountOut, minTrustOut, "Output should meet minimum");

        console2.log("DAI -> USDC -> TRUST: quoted", expectedOut, "got", amountOut);
    }

    /* =================================================== */
    /*              QUOTE FUNCTIONS (FORK)                 */
    /* =================================================== */

    function test_fork_quoteExactInput_singleHop() external {
        bytes memory path = abi.encodePacked(USDC, TS_USDC_TRUST, TRUST);

        uint256 quotedAmount = router.quoteExactInput(path, 10e6);
        assertGt(quotedAmount, 0, "Quote should return non-zero for valid path");

        console2.log("QuoteExactInput: 10 USDC ->", quotedAmount, "TRUST");
    }

    function test_fork_quoteExactInput_multiHop() external {
        bytes memory path = abi.encodePacked(WETH, TS_WETH_USDC, USDC, TS_USDC_TRUST, TRUST);

        uint256 quotedAmount = router.quoteExactInput(path, 0.01 ether);
        assertGt(quotedAmount, 0, "Quote should return non-zero for valid multi-hop path");

        console2.log("QuoteExactInput: 0.01 ETH ->", quotedAmount, "TRUST");
    }

    function test_fork_quoteBridgeFee() external view {
        uint256 fee = router.quoteBridgeFee(1e18, recipient);
        assertEq(fee, MOCK_BRIDGE_FEE, "Bridge fee should match mock");
    }

    /* =================================================== */
    /*              EXCESS ETH REFUND (FORK)               */
    /* =================================================== */

    function test_fork_excessETHRefundOnERC20Swap() external {
        bytes memory path = abi.encodePacked(USDC, TS_USDC_TRUST, TRUST);

        uint256 amountIn = 1e6; // 1 USDC
        deal(USDC, user, amountIn);

        uint256 excessEth = 0.5 ether;
        uint256 totalValue = MOCK_BRIDGE_FEE + excessEth;

        uint256 userEthBefore = user.balance;

        vm.startPrank(user);
        IERC20(USDC).approve(address(router), amountIn);
        router.swapAndBridgeWithERC20{ value: totalValue }(USDC, amountIn, path, 0, recipient);
        vm.stopPrank();

        uint256 userEthAfter = user.balance;
        assertEq(userEthAfter, userEthBefore - MOCK_BRIDGE_FEE, "Only bridge fee should be deducted");
    }

    /* =================================================== */
    /*                POOL VALIDATION (FORK)               */
    /* =================================================== */

    function test_fork_revertsOnNonExistentPool() external {
        // Use tick spacing 10 which has no USDC/TRUST pool
        bytes memory badPath = abi.encodePacked(USDC, int24(10), TRUST);

        deal(USDC, user, 1e6);

        vm.startPrank(user);
        IERC20(USDC).approve(address(router), 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(ITrustSwapAndBridgeRouter.TrustSwapAndBridgeRouter_PoolDoesNotExist.selector)
        );
        router.swapAndBridgeWithERC20{ value: MOCK_BRIDGE_FEE }(USDC, 1e6, badPath, 0, recipient);
        vm.stopPrank();
    }
}
