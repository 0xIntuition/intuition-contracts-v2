// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IAerodromeFactory } from "src/interfaces/external/aerodrome/IAerodromeFactory.sol";
import { IAerodromePool } from "src/interfaces/external/aerodrome/IAerodromePool.sol";
import { IAerodromeRouter } from "src/interfaces/external/aerodrome/IAerodromeRouter.sol";
import { ICLPool, ICLSwapCallback } from "src/interfaces/external/aerodrome/ICLPool.sol";
import { FinalityState, IMetaERC20Hub } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";
import { IWETH } from "src/interfaces/external/IWETH.sol";
import { ITrustSwapAndBridgeRouter } from "src/interfaces/ITrustSwapAndBridgeRouter.sol";

/**
 * @title TrustSwapAndBridgeRouter
 * @author 0xIntuition
 * @notice TrustSwapAndBridgeRouter facilitates swapping any token for TRUST on the Base network using the Aerodrome
 *         DEX and bridging them to Intuition mainnet via Metalayer.
 */
contract TrustSwapAndBridgeRouter is
    ITrustSwapAndBridgeRouter,
    Initializable,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    ICLSwapCallback
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Base mainnet Aerodrome CL USDC/TRUST pool address
    address public constant CL_USDC_TRUST_POOL = 0x17f707CF3EDBbd5d9251D4bCDF9Ad70a247D7B84;

    /// @notice Base mainnet USDC address
    address public constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /// @notice Base mainnet TRUST address
    address public constant TRUST_ADDRESS = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;

    /// @notice Base mainnet WETH address (canonical Base WETH)
    address public constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;

    /// @notice USDC token contract on Base
    IERC20 public constant usdcToken = IERC20(USDC_ADDRESS);

    /// @notice TRUST token contract on Base
    IERC20 public constant trustToken = IERC20(TRUST_ADDRESS);

    /// @notice WETH token contract on Base (canonical Base WETH)
    address public constant weth = WETH_ADDRESS;

    /// @notice Aerodrome Router contract on Base
    IAerodromeRouter public aerodromeRouter;

    /// @notice Aerodrome Pool Factory contract address on Base
    address public poolFactory;

    /// @notice Default deadline (in seconds) for swaps
    uint256 public defaultSwapDeadline;

    /// @notice MetaERC20Hub contract for cross-chain bridging
    IMetaERC20Hub public metaERC20Hub;

    /// @notice Recipient domain ID for bridging (Intuition mainnet)
    uint32 public recipientDomain;

    /// @notice Gas limit for bridge transactions
    uint256 public bridgeGasLimit;

    /// @notice Finality state for bridge transactions
    FinalityState public finalityState;

    /// @notice Minimum TRUST output threshold for route viability
    uint256 public minimumOutputThreshold;

    /// @notice Maximum slippage tolerance in basis points (10000 = 100%)
    uint256 public maxSlippageBps;

    uint160 internal constant MIN_SQRT_RATIO = 4_295_128_739;
    uint160 internal constant MAX_SQRT_RATIO = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;
    uint256 internal constant Q192 = 1 << 192;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function initialize(
        address _owner,
        address aerodromeRouterAddress,
        address poolFactoryAddress,
        address metaERC20HubAddress,
        uint32 _recipientDomain,
        uint256 _bridgeGasLimit,
        FinalityState _finalityState,
        uint256 _defaultSwapDeadline,
        uint256 _minimumOutputThreshold,
        uint256 _maxSlippageBps
    )
        external
        initializer
    {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        _setAerodromeRouter(aerodromeRouterAddress);
        _setPoolFactory(poolFactoryAddress);
        _setMetaERC20Hub(metaERC20HubAddress);
        _setRecipientDomain(_recipientDomain);
        _setBridgeGasLimit(_bridgeGasLimit);
        _setFinalityState(_finalityState);
        _setDefaultSwapDeadline(_defaultSwapDeadline);
        _setMinimumOutputThreshold(_minimumOutputThreshold);
        _setMaxSlippageBps(_maxSlippageBps);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setAerodromeRouter(address newRouter) external onlyOwner {
        _setAerodromeRouter(newRouter);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setPoolFactory(address newFactory) external onlyOwner {
        _setPoolFactory(newFactory);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setDefaultSwapDeadline(uint256 newDeadline) external onlyOwner {
        _setDefaultSwapDeadline(newDeadline);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setMetaERC20Hub(address newMetaERC20Hub) external onlyOwner {
        _setMetaERC20Hub(newMetaERC20Hub);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setRecipientDomain(uint32 newRecipientDomain) external onlyOwner {
        _setRecipientDomain(newRecipientDomain);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setBridgeGasLimit(uint256 newBridgeGasLimit) external onlyOwner {
        _setBridgeGasLimit(newBridgeGasLimit);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setFinalityState(FinalityState newFinalityState) external onlyOwner {
        _setFinalityState(newFinalityState);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setMinimumOutputThreshold(uint256 newThreshold) external onlyOwner {
        _setMinimumOutputThreshold(newThreshold);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setMaxSlippageBps(uint256 newMaxSlippageBps) external onlyOwner {
        _setMaxSlippageBps(newMaxSlippageBps);
    }

    /*//////////////////////////////////////////////////////////////
                        SWAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function swapAndBridge(
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    )
        external
        payable
        nonReentrant
        returns (uint256 amountOut, bytes32 transferId)
    {
        if (amountIn == 0) revert TrustSwapAndBridgeRouter_AmountInZero();

        usdcToken.safeTransferFrom(msg.sender, address(this), amountIn);

        return _executeSwapAndBridge(amountIn, minAmountOut, bytes32(uint256(uint160(recipient))));
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function swapAndBridgeWithPermit(
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        payable
        nonReentrant
        returns (uint256 amountOut, bytes32 transferId)
    {
        if (amountIn == 0) revert TrustSwapAndBridgeRouter_AmountInZero();
        if (deadline < block.timestamp) revert TrustSwapAndBridgeRouter_PermitExpired();

        try IERC20Permit(address(usdcToken)).permit(msg.sender, address(this), amountIn, deadline, v, r, s) { }
        catch {
            uint256 currentAllowance = usdcToken.allowance(msg.sender, address(this));
            if (currentAllowance < amountIn) {
                revert TrustSwapAndBridgeRouter_PermitFailed();
            }
        }

        usdcToken.safeTransferFrom(msg.sender, address(this), amountIn);

        return _executeSwapAndBridge(amountIn, minAmountOut, bytes32(uint256(uint160(recipient))));
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function swapAndBridgeWithETH(
        uint256 minAmountOut,
        address recipient
    )
        external
        payable
        nonReentrant
        returns (uint256 amountOut, bytes32 transferId)
    {
        if (msg.value == 0) revert TrustSwapAndBridgeRouter_InsufficientETH();

        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));

        uint256 estimatedTrustOut = _quoteSwapFromETH(msg.value);
        uint256 estimatedBridgeFee =
            metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, estimatedTrustOut);

        if (msg.value <= estimatedBridgeFee) {
            revert TrustSwapAndBridgeRouter_InsufficientETH();
        }
        uint256 ethAmountForSwap = msg.value - estimatedBridgeFee;

        return _executeSwapFromETHAndBridge(ethAmountForSwap, minAmountOut, recipientAddress);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function swapArbitraryTokenAndBridge(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    )
        external
        payable
        nonReentrant
        returns (uint256 amountOut, bytes32 transferId)
    {
        if (amountIn == 0) revert TrustSwapAndBridgeRouter_AmountInZero();
        if (tokenIn == address(0) || tokenIn == address(trustToken)) {
            revert TrustSwapAndBridgeRouter_InvalidToken();
        }

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));

        (IAerodromeRouter.Route[] memory routes, uint256 quotedOut) = _discoverRoute(tokenIn, amountIn);

        uint256 minOutFromMaxSlippage = maxSlippageBps >= 10_000 ? 0 : (quotedOut * (10_000 - maxSlippageBps)) / 10_000;

        if (minAmountOut == 0) {
            minAmountOut = minOutFromMaxSlippage;
        } else if (minAmountOut < minOutFromMaxSlippage) {
            revert TrustSwapAndBridgeRouter_OutputBelowThreshold();
        }

        return _executeArbitrarySwapAndBridge(tokenIn, amountIn, minAmountOut, routes, recipientAddress);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function quoteSwapToTrust(uint256 amountIn) external view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;

        return _quoteUSDCToTrustCL(amountIn);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function quoteSwapAndBridge(
        uint256 amountIn,
        address recipient
    )
        external
        view
        returns (uint256 amountOut, uint256 bridgeFee)
    {
        if (amountIn == 0) {
            return (0, 0);
        }

        amountOut = _quoteUSDCToTrustCL(amountIn);

        bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, bytes32(uint256(uint160(recipient))), amountOut);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function quoteSwapFromETHToTrust(uint256 amountIn) external view returns (uint256 amountOut) {
        return _quoteSwapFromETH(amountIn);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function quoteSwapAndBridgeWithETH(
        uint256 amountIn,
        address recipient
    )
        external
        view
        returns (uint256 amountOut, uint256 bridgeFee)
    {
        if (amountIn == 0) {
            return (0, 0);
        }

        amountOut = _quoteSwapFromETH(amountIn);
        bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, bytes32(uint256(uint160(recipient))), amountOut);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function quoteArbitraryTokenSwap(
        address tokenIn,
        uint256 amountIn
    )
        external
        view
        returns (uint256 amountOut, uint256 routeHops)
    {
        if (amountIn == 0) {
            return (0, 0);
        }
        if (tokenIn == address(0) || tokenIn == address(trustToken)) {
            revert TrustSwapAndBridgeRouter_InvalidToken();
        }

        (IAerodromeRouter.Route[] memory routes, uint256 quotedOut) = _discoverRoute(tokenIn, amountIn);
        return (quotedOut, routes.length);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to execute the swap and bridge after USDC has been transferred to this contract
     * @param amountIn Amount of USDC to swap
     * @param minAmountOut Minimum acceptable amount of TRUST to receive
     * @param recipientAddress Recipient address on the destination chain
     * @return amountOut Actual amount of TRUST received and bridged
     * @return transferId Unique cross-chain transfer ID from Metalayer
     */
    function _executeSwapAndBridge(
        uint256 amountIn,
        uint256 minAmountOut,
        bytes32 recipientAddress
    )
        internal
        returns (uint256 amountOut, bytes32 transferId)
    {
        amountOut = _swapUSDCToTrustCL(amountIn, minAmountOut);

        // Approve MetaERC20Hub to spend TRUST
        trustToken.safeIncreaseAllowance(address(metaERC20Hub), amountOut);

        // Get bridge fee quote
        uint256 bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, amountOut);

        // Verify sufficient ETH provided for bridge fee
        if (msg.value < bridgeFee) revert TrustSwapAndBridgeRouter_InsufficientBridgeFee();

        // Bridge TRUST to destination chain
        transferId = metaERC20Hub.transferRemote{ value: bridgeFee }(
            recipientDomain, recipientAddress, amountOut, bridgeGasLimit, finalityState
        );

        // Refund excess ETH if any
        if (msg.value > bridgeFee) {
            (bool success,) = msg.sender.call{ value: msg.value - bridgeFee }("");
            require(success, "ETH refund failed");
        }

        emit SwappedAndBridged(msg.sender, amountIn, amountOut, recipientAddress, transferId);
    }

    function _swapUSDCToTrustCL(uint256 amountIn, uint256 minAmountOut) internal returns (uint256 amountOut) {
        ICLPool pool = ICLPool(CL_USDC_TRUST_POOL);
        address token0 = pool.token0();
        address token1 = pool.token1();

        bool zeroForOne;
        if (token0 == address(usdcToken) && token1 == address(trustToken)) {
            zeroForOne = true;
        } else if (token0 == address(trustToken) && token1 == address(usdcToken)) {
            zeroForOne = false;
        } else {
            revert TrustSwapAndBridgeRouter_InvalidToken();
        }

        uint160 sqrtPriceLimitX96 = zeroForOne ? (MIN_SQRT_RATIO + 1) : (MAX_SQRT_RATIO - 1);

        (int256 amount0, int256 amount1) =
            pool.swap(address(this), zeroForOne, int256(amountIn), sqrtPriceLimitX96, bytes(""));

        if (amount1 <= 0 || amount0 >= 0) {
            revert TrustSwapAndBridgeRouter_NoViableRoute();
        }

        amountOut = uint256(-amount0);
        if (amountOut < minAmountOut) {
            revert TrustSwapAndBridgeRouter_OutputBelowThreshold();
        }
    }

    function _quoteUSDCToTrustCL(uint256 amountIn) internal view returns (uint256 amountOut) {
        ICLPool pool = ICLPool(CL_USDC_TRUST_POOL);
        address token0 = pool.token0();
        address token1 = pool.token1();
        if (token0 != address(usdcToken) && token1 != address(usdcToken)) {
            revert TrustSwapAndBridgeRouter_InvalidToken();
        }
        if (token0 != address(trustToken) && token1 != address(trustToken)) {
            revert TrustSwapAndBridgeRouter_InvalidToken();
        }

        (uint160 sqrtPriceX96,,,,,) = pool.slot0();
        uint256 priceX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        if (token0 == address(usdcToken)) {
            // price = token1/token0 (TRUST per USDC)
            return Math.mulDiv(amountIn, priceX192, Q192);
        }

        // price = token1/token0 (USDC per TRUST), amountOut(TRUST) = amountIn(USDC) * Q192 / priceX192
        return Math.mulDiv(amountIn, Q192, priceX192);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external override {
        if (msg.sender != CL_USDC_TRUST_POOL) {
            revert TrustSwapAndBridgeRouter_InvalidAddress();
        }

        if (amount0Delta > 0) {
            trustToken.safeTransfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            usdcToken.safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    /**
     * @dev Internal function to execute ETH→WETH→USDC→TRUST swap and bridge after ETH received
     * @param ethAmountForSwap Amount of ETH to use for swap (msg.value minus bridge fee estimate)
     * @param minAmountOut Minimum acceptable amount of TRUST to receive
     * @param recipientAddress Recipient address on the destination chain
     * @return amountOut Actual amount of TRUST received and bridged
     * @return transferId Unique cross-chain transfer ID from Metalayer
     */
    function _executeSwapFromETHAndBridge(
        uint256 ethAmountForSwap,
        uint256 minAmountOut,
        bytes32 recipientAddress
    )
        internal
        returns (uint256 amountOut, bytes32 transferId)
    {
        IWETH(weth).deposit{ value: ethAmountForSwap }();

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](2);
        routes[0] = IAerodromeRouter.Route({ from: weth, to: address(usdcToken), stable: false, factory: poolFactory });
        routes[1] = IAerodromeRouter.Route({
            from: address(usdcToken), to: address(trustToken), stable: false, factory: poolFactory
        });

        IWETH(weth).approve(address(aerodromeRouter), ethAmountForSwap);

        uint256 swapDeadline = block.timestamp + defaultSwapDeadline;

        uint256[] memory amounts = aerodromeRouter.swapExactTokensForTokens(
            ethAmountForSwap, minAmountOut, routes, address(this), swapDeadline
        );

        amountOut = amounts[amounts.length - 1];

        trustToken.safeIncreaseAllowance(address(metaERC20Hub), amountOut);

        uint256 bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, amountOut);

        uint256 ethRemaining = address(this).balance;
        if (ethRemaining < bridgeFee) revert TrustSwapAndBridgeRouter_InsufficientBridgeFee();

        transferId = metaERC20Hub.transferRemote{ value: bridgeFee }(
            recipientDomain, recipientAddress, amountOut, bridgeGasLimit, finalityState
        );

        if (ethRemaining > bridgeFee) {
            (bool success,) = msg.sender.call{ value: ethRemaining - bridgeFee }("");
            require(success, "ETH refund failed");
        }

        emit SwappedAndBridgedFromETH(msg.sender, ethAmountForSwap, amountOut, recipientAddress, transferId);
    }

    /**
     * @dev Discovers a viable route from `tokenIn` to TRUST (1-3 hops)
     */
    function _discoverRoute(
        address tokenIn,
        uint256 amountIn
    )
        internal
        view
        returns (IAerodromeRouter.Route[] memory routes, uint256 amountOut)
    {
        bool hasRoute;

        (routes, hasRoute) = _build1HopRoute(tokenIn);
        if (hasRoute) {
            amountOut = _quoteRoute(amountIn, routes);
            if (_isViableOutput(amountOut)) {
                return (routes, amountOut);
            }
        }

        (routes, hasRoute) = _build2HopRoute(tokenIn);
        if (hasRoute) {
            amountOut = _quoteRoute(amountIn, routes);
            if (_isViableOutput(amountOut)) {
                return (routes, amountOut);
            }
        }

        (routes, hasRoute) = _build3HopRoute(tokenIn);
        if (hasRoute) {
            amountOut = _quoteRoute(amountIn, routes);
            if (_isViableOutput(amountOut)) {
                return (routes, amountOut);
            }
        }

        revert TrustSwapAndBridgeRouter_NoViableRoute();
    }

    /**
     * @dev Returns true if a pool exists for the given pair and has liquidity
     */
    function _poolExistsAndHasLiquidity(address tokenA, address tokenB, bool stable) internal view returns (bool) {
        address pool = IAerodromeFactory(poolFactory).getPool(tokenA, tokenB, stable);
        if (pool == address(0)) {
            return false;
        }
        return _hasLiquidity(pool);
    }

    /**
     * @dev Checks if a pool has non-zero reserves
     */
    function _hasLiquidity(address pool) internal view returns (bool) {
        (uint256 reserve0, uint256 reserve1,) = IAerodromePool(pool).getReserves();
        return reserve0 > 0 && reserve1 > 0;
    }

    /**
     * @dev Determines whether the pool should be stable or volatile
     */
    function _determinePoolStability(address tokenA, address tokenB) internal view returns (bool stable, bool exists) {
        if (_poolExistsAndHasLiquidity(tokenA, tokenB, true)) {
            return (true, true);
        }
        if (_poolExistsAndHasLiquidity(tokenA, tokenB, false)) {
            return (false, true);
        }
        return (false, false);
    }

    /**
     * @dev Builds a 1-hop route (tokenIn → TRUST)
     */
    function _build1HopRoute(address tokenIn)
        internal
        view
        returns (IAerodromeRouter.Route[] memory routes, bool exists)
    {
        (bool stable, bool poolExists) = _determinePoolStability(tokenIn, address(trustToken));
        if (!poolExists) {
            return (routes, false);
        }

        routes = new IAerodromeRouter.Route[](1);
        routes[0] =
            IAerodromeRouter.Route({ from: tokenIn, to: address(trustToken), stable: stable, factory: poolFactory });

        return (routes, true);
    }

    /**
     * @dev Builds a 2-hop route (tokenIn → USDC → TRUST)
     */
    function _build2HopRoute(address tokenIn)
        internal
        view
        returns (IAerodromeRouter.Route[] memory routes, bool exists)
    {
        if (tokenIn == address(usdcToken)) {
            return (routes, false);
        }

        (bool stableA, bool poolAExists) = _determinePoolStability(tokenIn, address(usdcToken));
        if (!poolAExists) {
            return (routes, false);
        }

        (bool stableB, bool poolBExists) = _determinePoolStability(address(usdcToken), address(trustToken));
        if (!poolBExists) {
            return (routes, false);
        }

        routes = new IAerodromeRouter.Route[](2);
        routes[0] =
            IAerodromeRouter.Route({ from: tokenIn, to: address(usdcToken), stable: stableA, factory: poolFactory });
        routes[1] = IAerodromeRouter.Route({
            from: address(usdcToken), to: address(trustToken), stable: stableB, factory: poolFactory
        });

        return (routes, true);
    }

    /**
     * @dev Builds a 3-hop route (tokenIn → WETH → USDC → TRUST)
     */
    function _build3HopRoute(address tokenIn)
        internal
        view
        returns (IAerodromeRouter.Route[] memory routes, bool exists)
    {
        if (tokenIn == weth || tokenIn == address(usdcToken)) {
            return (routes, false);
        }

        (bool stableA, bool poolAExists) = _determinePoolStability(tokenIn, weth);
        if (!poolAExists) {
            return (routes, false);
        }

        (bool stableB, bool poolBExists) = _determinePoolStability(weth, address(usdcToken));
        if (!poolBExists) {
            return (routes, false);
        }

        (bool stableC, bool poolCExists) = _determinePoolStability(address(usdcToken), address(trustToken));
        if (!poolCExists) {
            return (routes, false);
        }

        routes = new IAerodromeRouter.Route[](3);
        routes[0] = IAerodromeRouter.Route({ from: tokenIn, to: weth, stable: stableA, factory: poolFactory });
        routes[1] =
            IAerodromeRouter.Route({ from: weth, to: address(usdcToken), stable: stableB, factory: poolFactory });
        routes[2] = IAerodromeRouter.Route({
            from: address(usdcToken), to: address(trustToken), stable: stableC, factory: poolFactory
        });

        return (routes, true);
    }

    /**
     * @dev Quotes output for a route
     */
    function _quoteRoute(
        uint256 amountIn,
        IAerodromeRouter.Route[] memory routes
    )
        internal
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0 || routes.length == 0) {
            return 0;
        }

        uint256[] memory amounts = aerodromeRouter.getAmountsOut(amountIn, routes);
        return amounts[amounts.length - 1];
    }

    /**
     * @dev Checks if a quoted output meets the minimum threshold
     */
    function _isViableOutput(uint256 amountOut) internal view returns (bool) {
        return amountOut >= minimumOutputThreshold && amountOut > 0;
    }

    /**
     * @dev Executes the swap and bridge for an arbitrary route
     */
    function _executeArbitrarySwapAndBridge(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        IAerodromeRouter.Route[] memory routes,
        bytes32 recipientAddress
    )
        internal
        returns (uint256 amountOut, bytes32 transferId)
    {
        IERC20(tokenIn).safeIncreaseAllowance(address(aerodromeRouter), amountIn);

        uint256 swapDeadline = block.timestamp + defaultSwapDeadline;

        uint256[] memory amounts =
            aerodromeRouter.swapExactTokensForTokens(amountIn, minAmountOut, routes, address(this), swapDeadline);

        amountOut = amounts[amounts.length - 1];

        trustToken.safeIncreaseAllowance(address(metaERC20Hub), amountOut);

        uint256 bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, amountOut);

        if (msg.value < bridgeFee) revert TrustSwapAndBridgeRouter_InsufficientBridgeFee();

        transferId = metaERC20Hub.transferRemote{ value: bridgeFee }(
            recipientDomain, recipientAddress, amountOut, bridgeGasLimit, finalityState
        );

        if (msg.value > bridgeFee) {
            (bool success,) = msg.sender.call{ value: msg.value - bridgeFee }("");
            require(success, "ETH refund failed");
        }

        emit SwappedArbitraryTokenAndBridged(
            msg.sender, tokenIn, amountIn, amountOut, routes.length, recipientAddress, transferId
        );
    }

    /// @dev Internal function to set the Aerodrome Router address
    function _setAerodromeRouter(address newRouter) internal {
        if (newRouter == address(0)) revert TrustSwapAndBridgeRouter_InvalidAddress();
        aerodromeRouter = IAerodromeRouter(newRouter);
        emit AerodromeRouterSet(newRouter);
    }

    /// @dev Internal function to set the Aerodrome Pool Factory address
    function _setPoolFactory(address newFactory) internal {
        if (newFactory == address(0)) revert TrustSwapAndBridgeRouter_InvalidAddress();
        poolFactory = newFactory;
        emit PoolFactorySet(newFactory);
    }

    /// @dev Internal function to set the default swap deadline
    function _setDefaultSwapDeadline(uint256 newDeadline) internal {
        if (newDeadline == 0) revert TrustSwapAndBridgeRouter_InvalidDeadline();
        defaultSwapDeadline = newDeadline;
        emit DefaultSwapDeadlineSet(newDeadline);
    }

    /// @dev Internal function to set the MetaERC20Hub address
    function _setMetaERC20Hub(address newMetaERC20Hub) internal {
        if (newMetaERC20Hub == address(0)) revert TrustSwapAndBridgeRouter_InvalidAddress();
        metaERC20Hub = IMetaERC20Hub(newMetaERC20Hub);
        emit MetaERC20HubSet(newMetaERC20Hub);
    }

    /// @dev Internal function to set the recipient domain
    function _setRecipientDomain(uint32 newRecipientDomain) internal {
        if (newRecipientDomain == 0) revert TrustSwapAndBridgeRouter_InvalidRecipientDomain();
        recipientDomain = newRecipientDomain;
        emit RecipientDomainSet(newRecipientDomain);
    }

    /// @dev Internal function to set the bridge gas limit
    function _setBridgeGasLimit(uint256 newBridgeGasLimit) internal {
        if (newBridgeGasLimit == 0) revert TrustSwapAndBridgeRouter_InvalidBridgeGasLimit();
        bridgeGasLimit = newBridgeGasLimit;
        emit BridgeGasLimitSet(newBridgeGasLimit);
    }

    /// @dev Internal function to set the finality state
    function _setFinalityState(FinalityState newFinalityState) internal {
        finalityState = newFinalityState;
        emit FinalityStateSet(newFinalityState);
    }

    /// @dev Internal function to set the minimum output threshold
    function _setMinimumOutputThreshold(uint256 newThreshold) internal {
        minimumOutputThreshold = newThreshold;
        emit MinimumOutputThresholdSet(newThreshold);
    }

    /// @dev Internal function to set the maximum slippage in basis points
    function _setMaxSlippageBps(uint256 newMaxSlippageBps) internal {
        maxSlippageBps = newMaxSlippageBps;
        emit MaxSlippageBpsSet(newMaxSlippageBps);
    }

    /**
     * @dev Internal function to quote ETH→WETH→USDC→TRUST swap
     * @param amountIn Amount of ETH to quote
     * @return amountOut Expected amount of TRUST out
     */
    function _quoteSwapFromETH(uint256 amountIn) internal view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](2);
        routes[0] = IAerodromeRouter.Route({ from: weth, to: address(usdcToken), stable: false, factory: poolFactory });
        routes[1] = IAerodromeRouter.Route({
            from: address(usdcToken), to: address(trustToken), stable: false, factory: poolFactory
        });

        uint256[] memory amounts = aerodromeRouter.getAmountsOut(amountIn, routes);
        return amounts[amounts.length - 1];
    }
}
