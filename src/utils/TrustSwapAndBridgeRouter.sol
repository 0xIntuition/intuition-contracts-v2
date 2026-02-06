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
import { ICLFactory } from "src/interfaces/external/aerodrome/ICLFactory.sol";
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

    /// @notice Primary Aerodrome CL factory (Base)
    address internal constant CL_FACTORY_PRIMARY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;

    /// @notice Secondary Aerodrome CL factory (Base)
    address internal constant CL_FACTORY_SECONDARY = 0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a;

    /// @notice Aerodrome V2 Router address on Base
    address internal constant V2_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;

    /// @notice Aerodrome V2 Factory address on Base
    address internal constant V2_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

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

    /// @notice Minimum sqrt price ratio (Uniswap V3 bounds)
    uint160 internal constant MIN_SQRT_RATIO = 4_295_128_739;

    /// @notice Maximum sqrt price ratio (Uniswap V3 bounds)
    uint160 internal constant MAX_SQRT_RATIO = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;

    /// @notice Fixed-point scaling for price math (Q96)
    uint256 internal constant Q96 = 1 << 96;
    /// @notice Fixed-point scaling for price math (Q192)
    uint256 internal constant Q192 = 1 << 192;

    /// @notice Pool type enum for hybrid routing
    enum PoolType {
        CL,
        V2_VOLATILE,
        V2_STABLE
    }

    /// @notice Extended route candidate for hybrid CL/V2 routing
    struct HybridRouteCandidate {
        address[] pools;
        address[] path;
        PoolType[] poolTypes;
        uint256 amountOut;
    }

    /// @notice Pool address authorized to call swap callback for the current swap
    address private swapCallbackPool;

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

    // Aerodrome V2 admin setters removed.

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

        uint256 bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, 0);
        if (msg.value <= bridgeFee) {
            revert TrustSwapAndBridgeRouter_InsufficientETH();
        }
        uint256 ethAmountForSwap = msg.value - bridgeFee;

        IWETH(weth).deposit{ value: ethAmountForSwap }();

        (amountOut, transferId,) =
            _swapTokenAndBridge(weth, ethAmountForSwap, minAmountOut, recipientAddress, bridgeFee);

        emit SwappedAndBridgedFromETH(msg.sender, ethAmountForSwap, amountOut, recipientAddress, transferId);
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

        uint256 routeHops;
        (amountOut, transferId, routeHops) =
            _swapTokenAndBridge(tokenIn, amountIn, minAmountOut, recipientAddress, msg.value);

        emit SwappedArbitraryTokenAndBridged(
            msg.sender, tokenIn, amountIn, amountOut, routeHops, recipientAddress, transferId
        );
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
        bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, bytes32(uint256(uint160(recipient))), 0);
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

        HybridRouteCandidate memory route = _discoverHybridRoute(tokenIn, amountIn);
        return (route.amountOut, route.pools.length == 0 ? 0 : route.path.length - 1);
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
        amountOut = _swapExactInputCL(CL_USDC_TRUST_POOL, address(usdcToken), address(trustToken), amountIn);
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

        (uint160 sqrtPriceX96,,,,, bool unlocked) = pool.slot0();
        if (!unlocked || sqrtPriceX96 == 0) {
            return 0;
        }
        if (sqrtPriceX96 <= MIN_SQRT_RATIO + 1 || sqrtPriceX96 >= MAX_SQRT_RATIO - 1) {
            return 0;
        }

        if (token0 == address(usdcToken)) {
            // amountOut = amountIn * (sqrtP^2 / Q192)
            return _quoteFromSqrtPrice(amountIn, sqrtPriceX96, true);
        }

        // amountOut = amountIn * (Q192 / sqrtP^2)
        return _quoteFromSqrtPrice(amountIn, sqrtPriceX96, false);
    }

    function _swapExactInputCL(
        address poolAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        internal
        returns (uint256 amountOut)
    {
        ICLPool pool = ICLPool(poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();
        bool zeroForOne;
        if (token0 == tokenIn && token1 == tokenOut) {
            zeroForOne = true;
        } else if (token1 == tokenIn && token0 == tokenOut) {
            zeroForOne = false;
        } else {
            revert TrustSwapAndBridgeRouter_InvalidToken();
        }

        uint160 sqrtPriceLimitX96 = zeroForOne ? (MIN_SQRT_RATIO + 1) : (MAX_SQRT_RATIO - 1);
        swapCallbackPool = poolAddress;

        (int256 amount0, int256 amount1) =
            pool.swap(address(this), zeroForOne, int256(amountIn), sqrtPriceLimitX96, bytes(""));

        swapCallbackPool = address(0);

        if (zeroForOne) {
            if (amount1 >= 0) revert TrustSwapAndBridgeRouter_NoViableRoute();
            amountOut = uint256(-amount1);
        } else {
            if (amount0 >= 0) revert TrustSwapAndBridgeRouter_NoViableRoute();
            amountOut = uint256(-amount0);
        }
    }

    function _quoteCLPool(
        address poolAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        internal
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) return 0;

        ICLPool pool = ICLPool(poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();
        if (!((token0 == tokenIn && token1 == tokenOut) || (token1 == tokenIn && token0 == tokenOut))) {
            return 0;
        }

        (uint160 sqrtPriceX96,,,,, bool unlocked) = pool.slot0();
        if (!unlocked || sqrtPriceX96 == 0) {
            return 0;
        }
        if (sqrtPriceX96 <= MIN_SQRT_RATIO + 1 || sqrtPriceX96 >= MAX_SQRT_RATIO - 1) {
            return 0;
        }
        if (token0 == tokenIn) {
            return _quoteFromSqrtPrice(amountIn, sqrtPriceX96, true);
        }

        return _quoteFromSqrtPrice(amountIn, sqrtPriceX96, false);
    }

    function _quoteFromSqrtPrice(
        uint256 amountIn,
        uint160 sqrtPriceX96,
        bool token0IsIn
    )
        internal
        pure
        returns (uint256 amountOut)
    {
        if (token0IsIn) {
            uint256 tmp = Math.mulDiv(amountIn, uint256(sqrtPriceX96), Q96);
            return Math.mulDiv(tmp, uint256(sqrtPriceX96), Q96);
        }

        uint256 tmp = Math.mulDiv(amountIn, Q96, uint256(sqrtPriceX96));
        return Math.mulDiv(tmp, Q96, uint256(sqrtPriceX96));
    }

    function _clFactories() internal pure returns (address[] memory factories) {
        factories = new address[](2);
        factories[0] = CL_FACTORY_PRIMARY;
        factories[1] = CL_FACTORY_SECONDARY;
    }

    function _findBestPool(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        internal
        view
        returns (address bestPool, uint256 bestOut)
    {
        address[] memory factories = _clFactories();
        for (uint256 i = 0; i < factories.length; i++) {
            int24[] memory tickSpacings = ICLFactory(factories[i]).tickSpacings();
            for (uint256 j = 0; j < tickSpacings.length; j++) {
                address pool = ICLFactory(factories[i]).getPool(tokenIn, tokenOut, tickSpacings[j]);
                if (pool == address(0)) continue;
                uint256 out = _quoteCLPool(pool, tokenIn, tokenOut, amountIn);
                if (out > bestOut) {
                    bestOut = out;
                    bestPool = pool;
                }
            }
        }
    }

    /**
     * @dev Quotes output amount for a V2 pool swap using the router
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @param stable Whether the pool is stable
     * @return amountOut Expected output amount
     */
    function _quoteV2Pool(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bool stable
    )
        internal
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) return 0;

        address poolAddress = IAerodromeFactory(V2_FACTORY).getPool(tokenIn, tokenOut, stable);
        if (poolAddress == address(0)) return 0;

        IAerodromePool pool = IAerodromePool(poolAddress);
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        if (reserve0 == 0 || reserve1 == 0) return 0;

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({ from: tokenIn, to: tokenOut, stable: stable, factory: V2_FACTORY });

        try IAerodromeRouter(V2_ROUTER).getAmountsOut(amountIn, routes) returns (uint256[] memory amounts) {
            if (amounts.length >= 2) {
                amountOut = amounts[1];
            }
        } catch {
            amountOut = 0;
        }
    }

    /**
     * @dev Finds the best V2 pool for a token pair (checks both stable and volatile)
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @return bestPool Best V2 pool address
     * @return isStable Whether the best pool is stable
     * @return bestOut Best quote amount out
     */
    function _findBestV2Pool(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        internal
        view
        returns (address bestPool, bool isStable, uint256 bestOut)
    {
        address volatilePool = IAerodromeFactory(V2_FACTORY).getPool(tokenIn, tokenOut, false);
        if (volatilePool != address(0)) {
            uint256 volatileOut = _quoteV2Pool(tokenIn, tokenOut, amountIn, false);
            if (volatileOut > bestOut) {
                bestOut = volatileOut;
                bestPool = volatilePool;
                isStable = false;
            }
        }

        address stablePool = IAerodromeFactory(V2_FACTORY).getPool(tokenIn, tokenOut, true);
        if (stablePool != address(0)) {
            uint256 stableOut = _quoteV2Pool(tokenIn, tokenOut, amountIn, true);
            if (stableOut > bestOut) {
                bestOut = stableOut;
                bestPool = stablePool;
                isStable = true;
            }
        }
    }

    /**
     * @dev Finds the best pool (CL or V2) for a token pair
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @return bestPool Best pool address
     * @return poolType Type of the best pool
     * @return isStable If V2, whether stable (ignored for CL)
     * @return bestOut Best quote amount out
     */
    function _findBestHybridPool(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        internal
        view
        returns (address bestPool, PoolType poolType, bool isStable, uint256 bestOut)
    {
        (address clPool, uint256 clOut) = _findBestPool(tokenIn, tokenOut, amountIn);
        if (clOut > bestOut) {
            bestOut = clOut;
            bestPool = clPool;
            poolType = PoolType.CL;
        }

        (address v2Pool, bool v2IsStable, uint256 v2Out) = _findBestV2Pool(tokenIn, tokenOut, amountIn);
        if (v2Out > bestOut) {
            bestOut = v2Out;
            bestPool = v2Pool;
            isStable = v2IsStable;
            poolType = v2IsStable ? PoolType.V2_STABLE : PoolType.V2_VOLATILE;
        }
    }

    /**
     * @dev Discovers the best hybrid route (CL/V2) from tokenIn to TRUST
     * @param tokenIn Input token address
     * @param amountIn Amount of input token
     * @return route The best hybrid route candidate
     */
    function _discoverHybridRoute(
        address tokenIn,
        uint256 amountIn
    )
        internal
        view
        returns (HybridRouteCandidate memory route)
    {
        HybridRouteCandidate memory direct = _bestDirectHybridRoute(tokenIn, amountIn);
        HybridRouteCandidate memory twoHop = _bestTwoHopHybridRoute(tokenIn, amountIn);
        HybridRouteCandidate memory threeHop = _bestThreeHopHybridRoute(tokenIn, amountIn);

        if (direct.amountOut >= twoHop.amountOut && direct.amountOut >= threeHop.amountOut && direct.amountOut > 0) {
            return direct;
        }

        if (twoHop.amountOut >= threeHop.amountOut && twoHop.amountOut > 0) {
            return twoHop;
        }

        if (threeHop.amountOut > 0) {
            return threeHop;
        }

        revert TrustSwapAndBridgeRouter_NoViableRoute();
    }

    function _bestDirectHybridRoute(
        address tokenIn,
        uint256 amountIn
    )
        internal
        view
        returns (HybridRouteCandidate memory route)
    {
        (address pool, PoolType poolType,, uint256 out) = _findBestHybridPool(tokenIn, address(trustToken), amountIn);

        if (out == 0) {
            return route;
        }

        route.pools = new address[](1);
        route.pools[0] = pool;
        route.path = new address[](2);
        route.path[0] = tokenIn;
        route.path[1] = address(trustToken);
        route.poolTypes = new PoolType[](1);
        route.poolTypes[0] = poolType;
        route.amountOut = out;
    }

    function _bestTwoHopHybridRoute(
        address tokenIn,
        uint256 amountIn
    )
        internal
        view
        returns (HybridRouteCandidate memory route)
    {
        (address pool1, PoolType type1,, uint256 outToUsdc) = _findBestHybridPool(tokenIn, address(usdcToken), amountIn);
        if (pool1 == address(0) || outToUsdc == 0) {
            return route;
        }

        (address pool2, PoolType type2,, uint256 outToTrust) =
            _findBestHybridPool(address(usdcToken), address(trustToken), outToUsdc);
        if (pool2 == address(0) || outToTrust == 0) {
            return route;
        }

        route.pools = new address[](2);
        route.pools[0] = pool1;
        route.pools[1] = pool2;
        route.path = new address[](3);
        route.path[0] = tokenIn;
        route.path[1] = address(usdcToken);
        route.path[2] = address(trustToken);
        route.poolTypes = new PoolType[](2);
        route.poolTypes[0] = type1;
        route.poolTypes[1] = type2;
        route.amountOut = outToTrust;
    }

    function _bestThreeHopHybridRoute(
        address tokenIn,
        uint256 amountIn
    )
        internal
        view
        returns (HybridRouteCandidate memory route)
    {
        (address pool1, PoolType type1,, uint256 outToWeth) = _findBestHybridPool(tokenIn, weth, amountIn);
        if (pool1 == address(0) || outToWeth == 0) {
            return route;
        }

        (address pool2, PoolType type2,, uint256 outToUsdc) = _findBestHybridPool(weth, address(usdcToken), outToWeth);
        if (pool2 == address(0) || outToUsdc == 0) {
            return route;
        }

        (address pool3, PoolType type3,, uint256 outToTrust) =
            _findBestHybridPool(address(usdcToken), address(trustToken), outToUsdc);
        if (pool3 == address(0) || outToTrust == 0) {
            return route;
        }

        route.pools = new address[](3);
        route.pools[0] = pool1;
        route.pools[1] = pool2;
        route.pools[2] = pool3;
        route.path = new address[](4);
        route.path[0] = tokenIn;
        route.path[1] = weth;
        route.path[2] = address(usdcToken);
        route.path[3] = address(trustToken);
        route.poolTypes = new PoolType[](3);
        route.poolTypes[0] = type1;
        route.poolTypes[1] = type2;
        route.poolTypes[2] = type3;
        route.amountOut = outToTrust;
    }

    /**
     * @dev Shared internal function for swapping any token to TRUST and bridging
     * @param tokenIn Address of token to swap (must already be in contract)
     * @param amountIn Amount of tokenIn to swap
     * @param minAmountOut Minimum acceptable TRUST output
     * @param recipientAddress Recipient address on destination chain (bytes32 encoded)
     * @param availableEthForBridge ETH available for bridge fee
     * @return amountOut Actual TRUST received
     * @return transferId Bridge transfer ID
     * @return routeHops Number of swap hops used
     */
    function _swapTokenAndBridge(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes32 recipientAddress,
        uint256 availableEthForBridge
    )
        internal
        returns (uint256 amountOut, bytes32 transferId, uint256 routeHops)
    {
        HybridRouteCandidate memory route = _discoverHybridRoute(tokenIn, amountIn);

        routeHops = route.pools.length;
        amountOut = _executeHybridSwapPath(amountIn, route);

        if (amountOut < minAmountOut) {
            revert TrustSwapAndBridgeRouter_OutputBelowThreshold();
        }

        trustToken.safeIncreaseAllowance(address(metaERC20Hub), amountOut);

        uint256 bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, amountOut);

        if (availableEthForBridge < bridgeFee) revert TrustSwapAndBridgeRouter_InsufficientBridgeFee();

        transferId = metaERC20Hub.transferRemote{ value: bridgeFee }(
            recipientDomain, recipientAddress, amountOut, bridgeGasLimit, finalityState
        );

        uint256 ethRemaining = address(this).balance;
        if (ethRemaining > 0) {
            (bool success,) = msg.sender.call{ value: ethRemaining }("");
            require(success, "ETH refund failed");
        }
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external override {
        if (msg.sender != swapCallbackPool) {
            revert TrustSwapAndBridgeRouter_InvalidAddress();
        }

        if (amount0Delta > 0) {
            IERC20(ICLPool(msg.sender).token0()).safeTransfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(ICLPool(msg.sender).token1()).safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    /**
     * @dev Executes a V2 swap through the Aerodrome router
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @param stable Whether the pool is stable
     * @return amountOut Actual output amount
     */
    function _swapExactInputV2(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bool stable
    )
        internal
        returns (uint256 amountOut)
    {
        IERC20(tokenIn).safeIncreaseAllowance(V2_ROUTER, amountIn);

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({ from: tokenIn, to: tokenOut, stable: stable, factory: V2_FACTORY });

        uint256[] memory amounts = IAerodromeRouter(V2_ROUTER)
            .swapExactTokensForTokens(amountIn, 0, routes, address(this), block.timestamp + defaultSwapDeadline);

        amountOut = amounts[amounts.length - 1];
    }

    // Legacy _executeSwapFromETHAndBridge and Aerodrome V2 route discovery/execution removed.
    // ETH path now uses shared _swapTokenAndBridge after wrapping ETH to WETH.

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
     * @dev Internal function to quote ETH→WETH→USDC→TRUST swap using hybrid routing
     * @param amountIn Amount of ETH to quote
     * @return amountOut Expected amount of TRUST out
     */
    function _quoteSwapFromETH(uint256 amountIn) internal view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;

        HybridRouteCandidate memory direct = _bestDirectHybridRoute(weth, amountIn);
        HybridRouteCandidate memory twoHop = _bestTwoHopHybridRoute(weth, amountIn);
        HybridRouteCandidate memory threeHop = _bestThreeHopHybridRoute(weth, amountIn);

        uint256 best = direct.amountOut;
        if (twoHop.amountOut > best) best = twoHop.amountOut;
        if (threeHop.amountOut > best) best = threeHop.amountOut;
        return best;
    }

    /**
     * @dev Executes a hybrid swap path (supports both CL and V2 pools)
     * @param amountIn Amount of input token
     * @param route The hybrid route to execute
     * @return amountOut Final output amount
     */
    function _executeHybridSwapPath(
        uint256 amountIn,
        HybridRouteCandidate memory route
    )
        internal
        returns (uint256 amountOut)
    {
        uint256 hopAmount = amountIn;

        for (uint256 i = 0; i < route.pools.length; i++) {
            if (route.poolTypes[i] == PoolType.CL) {
                hopAmount = _swapExactInputCL(route.pools[i], route.path[i], route.path[i + 1], hopAmount);
            } else {
                bool stable = route.poolTypes[i] == PoolType.V2_STABLE;
                hopAmount = _swapExactInputV2(route.path[i], route.path[i + 1], hopAmount, stable);
            }
        }

        return hopAmount;
    }
}
