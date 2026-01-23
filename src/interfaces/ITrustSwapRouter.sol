// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IAerodromeRouter } from "src/interfaces/external/aerodrome/IAerodromeRouter.sol";
import { FinalityState, IMetaERC20Hub } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";

/**
 * @title  ITrustSwapRouter
 * @author 0xIntuition
 * @notice Interface for the TrustSwapRouter contract which facilitates swapping USDC for TRUST tokens
 *         on the Base network using the Aerodrome DEX and bridging them to Intuition mainnet via Metalayer.
 */
interface ITrustSwapRouter {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Emitted when the Aerodrome Router address is updated
     * @param newRouter The new Aerodrome Router address
     */
    event AerodromeRouterSet(address indexed newRouter);

    /**
     * @notice Emitted when the Pool Factory address is updated
     * @param newFactory The new Pool Factory address
     */
    event PoolFactorySet(address indexed newFactory);

    /**
     * @notice Emitted when a user swaps USDC for TRUST tokens
     * @param user The address of the user who performed the swap
     * @param amountIn The amount of USDC swapped
     * @param amountOut The amount of TRUST tokens received
     */
    event SwappedToTrust(address indexed user, uint256 amountIn, uint256 amountOut);

    /**
     * @notice Emitted when the default swap deadline is updated
     * @param newDeadline The new default swap deadline in seconds
     */
    event DefaultSwapDeadlineSet(uint256 newDeadline);

    /**
     * @notice Emitted when the MetaERC20Hub address is updated
     * @param newMetaERC20Hub The new MetaERC20Hub address
     */
    event MetaERC20HubSet(address indexed newMetaERC20Hub);

    /**
     * @notice Emitted when the recipient domain is updated
     * @param newRecipientDomain The new recipient domain ID
     */
    event RecipientDomainSet(uint32 newRecipientDomain);

    /**
     * @notice Emitted when the bridge gas limit is updated
     * @param newBridgeGasLimit The new bridge gas limit
     */
    event BridgeGasLimitSet(uint256 newBridgeGasLimit);

    /**
     * @notice Emitted when the finality state is updated
     * @param newFinalityState The new finality state for bridging
     */
    event FinalityStateSet(FinalityState newFinalityState);

    /**
     * @notice Emitted when a user swaps USDC for TRUST and bridges to destination chain
     * @param user The address of the user who performed the swap and bridge
     * @param amountIn The amount of USDC swapped
     * @param amountOut The amount of TRUST tokens received and bridged
     * @param recipientAddress The recipient address on the destination chain
     * @param transferId The unique cross-chain transfer ID from Metalayer
     */
    event SwappedAndBridged(
        address indexed user, uint256 amountIn, uint256 amountOut, bytes32 recipientAddress, bytes32 transferId
    );

    /**
     * @notice Emitted when a user swaps ETH for TRUST and bridges to destination chain
     * @param user The address of the user who performed the swap and bridge
     * @param ethAmountIn The amount of ETH swapped (not including bridge fee)
     * @param amountOut The amount of TRUST tokens received and bridged
     * @param recipientAddress The recipient address on the destination chain
     * @param transferId The unique cross-chain transfer ID from Metalayer
     */
    event SwappedAndBridgedFromETH(
        address indexed user, uint256 ethAmountIn, uint256 amountOut, bytes32 recipientAddress, bytes32 transferId
    );

    /**
     * @notice Emitted when an arbitrary token is swapped for TRUST and bridged
     * @param user The address of the user who performed the swap
     * @param tokenIn The input token address
     * @param amountIn The amount of input token swapped
     * @param amountOut The amount of TRUST received and bridged
     * @param routeHops Number of hops used (1, 2, or 3)
     * @param recipientAddress The recipient address on the destination chain
     * @param transferId The unique cross-chain transfer ID from Metalayer
     */
    event SwappedArbitraryTokenAndBridged(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint256 routeHops,
        bytes32 recipientAddress,
        bytes32 transferId
    );

    /**
     * @notice Emitted when minimum output threshold is updated
     * @param newThreshold The new minimum output threshold
     */
    event MinimumOutputThresholdSet(uint256 newThreshold);

    /**
     * @notice Emitted when maximum slippage is updated
     * @param newMaxSlippageBps The new maximum slippage in basis points
     */
    event MaxSlippageBpsSet(uint256 newMaxSlippageBps);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    /// @dev Thrown when a zero address is provided where a valid address is required
    error TrustSwapRouter_InvalidAddress();

    /// @dev Thrown when attempting to swap with zero amount
    error TrustSwapRouter_AmountInZero();

    /// @dev Thrown when an invalid deadline (zero) is provided
    error TrustSwapRouter_InvalidDeadline();

    /// @dev Thrown when the permit signature has expired
    error TrustSwapRouter_PermitExpired();

    /// @dev Thrown when the permit call fails
    error TrustSwapRouter_PermitFailed();

    /// @dev Thrown when insufficient ETH is provided for bridge fees
    error TrustSwapRouter_InsufficientBridgeFee();

    /// @dev Thrown when an invalid recipient domain is provided
    error TrustSwapRouter_InvalidRecipientDomain();

    /// @dev Thrown when an invalid bridge gas limit is provided
    error TrustSwapRouter_InvalidBridgeGasLimit();

    /// @dev Thrown when insufficient ETH is provided for swap and bridge
    error TrustSwapRouter_InsufficientETH();

    /// @dev Thrown when no viable route exists from input token to TRUST
    error TrustSwapRouter_NoViableRoute();

    /// @dev Thrown when input token address is invalid
    error TrustSwapRouter_InvalidToken();

    /// @dev Thrown when route output doesn't meet minimum threshold
    error TrustSwapRouter_OutputBelowThreshold();

    /* =================================================== */
    /*                      FUNCTIONS                      */
    /* =================================================== */

    /**
     * @notice Initializes the TrustSwapRouter contract
     * @param owner Owner address for the Ownable2StepUpgradeable
     * @param aerodromeRouterAddress Address of the Aerodrome Router contract
     * @param poolFactoryAddress Address of the Aerodrome Pool Factory contract
     * @param metaERC20HubAddress Address of the MetaERC20Hub contract for bridging
     * @param recipientDomain Domain ID of the destination chain (Intuition mainnet)
     * @param bridgeGasLimit Gas limit for bridge transactions
     * @param finalityState Desired finality state for bridge transactions
     * @param defaultSwapDeadline Default deadline (in seconds) for swaps
     * @param minimumOutputThreshold Minimum TRUST output threshold for route viability (in TRUST wei, 18 decimals)
     * @param maxSlippageBps Maximum slippage tolerance in basis points (10000 = 100%)
     */
    function initialize(
        address owner,
        address aerodromeRouterAddress,
        address poolFactoryAddress,
        address metaERC20HubAddress,
        uint32 recipientDomain,
        uint256 bridgeGasLimit,
        FinalityState finalityState,
        uint256 defaultSwapDeadline,
        uint256 minimumOutputThreshold,
        uint256 maxSlippageBps
    )
        external;

    /**
     * @notice Updates the Aerodrome Router contract address
     * @param newRouter Address of the new Aerodrome Router contract
     */
    function setAerodromeRouter(address newRouter) external;

    /**
     * @notice Updates the Aerodrome Pool Factory contract address
     * @param newFactory Address of the new Aerodrome Pool Factory contract
     */
    function setPoolFactory(address newFactory) external;

    /**
     * @notice Updates the default swap deadline
     * @param newDeadline New default deadline (in seconds) for swaps
     */
    function setDefaultSwapDeadline(uint256 newDeadline) external;

    /**
     * @notice Updates the MetaERC20Hub contract address
     * @param newMetaERC20Hub Address of the new MetaERC20Hub contract
     */
    function setMetaERC20Hub(address newMetaERC20Hub) external;

    /**
     * @notice Updates the recipient domain for bridging
     * @param newRecipientDomain New recipient domain ID
     */
    function setRecipientDomain(uint32 newRecipientDomain) external;

    /**
     * @notice Updates the bridge gas limit
     * @param newBridgeGasLimit New bridge gas limit
     */
    function setBridgeGasLimit(uint256 newBridgeGasLimit) external;

    /**
     * @notice Updates the finality state for bridging
     * @param newFinalityState New finality state
     */
    function setFinalityState(FinalityState newFinalityState) external;

    /**
     * @notice Updates the minimum output threshold for route viability
     * @param newThreshold New threshold in TRUST wei (18 decimals)
     */
    function setMinimumOutputThreshold(uint256 newThreshold) external;

    /**
     * @notice Updates the maximum slippage tolerance
     * @param newMaxSlippageBps New max slippage in basis points (10000 = 100%)
     */
    function setMaxSlippageBps(uint256 newMaxSlippageBps) external;

    /**
     * @notice Swaps `amountIn` USDC for TRUST tokens and bridges them to the destination chain
     * @dev Caller must approve this contract to spend `amountIn` USDC first and provide sufficient ETH for bridge fees
     * @param amountIn Amount of USDC to swap
     * @param minAmountOut Minimum acceptable amount of TRUST to receive (slippage protection)
     * @param recipient Recipient address on the destination chain
     * @return amountOut Actual amount of TRUST received and bridged
     * @return transferId Unique cross-chain transfer ID from Metalayer
     */
    function swapAndBridge(
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    )
        external
        payable
        returns (uint256 amountOut, bytes32 transferId);

    /**
     * @notice Swaps `amountIn` USDC for TRUST using EIP-2612 permit and bridges to destination chain
     * @dev If `permit()` fails, proceeds only if the caller already granted sufficient USDC allowance
     * @param amountIn Amount of USDC to swap
     * @param minAmountOut Minimum acceptable amount of TRUST to receive (slippage protection)
     * @param recipient Recipient address on the destination chain
     * @param deadline Deadline for the permit signature
     * @param v ECDSA signature component
     * @param r ECDSA signature component
     * @param s ECDSA signature component
     * @return amountOut Amount of TRUST received and bridged
     * @return transferId Unique cross-chain transfer ID from Metalayer
     */
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
        returns (uint256 amountOut, bytes32 transferId);

    /**
     * @notice Quotes expected TRUST out for `amountIn` USDC (USDC has 6 decimals)
     * @dev Assumes the USDC/TRUST pool is a volatile pool (stable=false)
     * @param amountIn Amount of USDC to quote
     * @return amountOut Expected amount of TRUST out
     */
    function quoteSwapToTrust(uint256 amountIn) external view returns (uint256 amountOut);

    /**
     * @notice Quotes the total cost (swap + bridge) for swapping and bridging USDC to TRUST
     * @param amountIn Amount of USDC to swap
     * @param recipient Recipient address on the destination chain
     * @return amountOut Expected amount of TRUST tokens to receive
     * @return bridgeFee Bridge fee in wei required for the transaction
     */
    function quoteSwapAndBridge(
        uint256 amountIn,
        address recipient
    )
        external
        view
        returns (uint256 amountOut, uint256 bridgeFee);

    /**
     * @notice Swaps ETH for TRUST tokens via WETH→USDC→TRUST route and bridges to destination chain
     * @dev User sends total ETH needed: some for swap, rest for bridge fee
     *      Contract estimates bridge fee, uses remainder for swap, refunds any excess
     * @param minAmountOut Minimum acceptable amount of TRUST to receive (slippage protection)
     * @param recipient Recipient address on the destination chain
     * @return amountOut Actual amount of TRUST received and bridged
     * @return transferId Unique cross-chain transfer ID from Metalayer
     */
    function swapAndBridgeWithETH(
        uint256 minAmountOut,
        address recipient
    )
        external
        payable
        returns (uint256 amountOut, bytes32 transferId);

    /**
     * @notice Quotes expected TRUST out for `amountIn` ETH (via WETH→USDC→TRUST)
     * @param amountIn Amount of ETH to quote (in wei)
     * @return amountOut Expected amount of TRUST out
     */
    function quoteSwapFromETHToTrust(uint256 amountIn) external view returns (uint256 amountOut);

    /**
     * @notice Quotes the total cost (swap + bridge) for swapping and bridging ETH to TRUST
     * @param amountIn Amount of ETH to use for swap (excludes bridge fee)
     * @param recipient Recipient address on the destination chain
     * @return amountOut Expected amount of TRUST tokens to receive
     * @return bridgeFee Bridge fee in wei required for the transaction
     */
    function quoteSwapAndBridgeWithETH(
        uint256 amountIn,
        address recipient
    )
        external
        view
        returns (uint256 amountOut, uint256 bridgeFee);

    /**
     * @notice Swaps arbitrary ERC20 token for TRUST and bridges to destination chain
     * @dev Automatically discovers best route (1-3 hops) or reverts if no viable route exists
     * @param tokenIn Address of input token (must be ERC20)
     * @param amountIn Amount of input token to swap
     * @param minAmountOut Minimum acceptable amount of TRUST to receive (slippage protection)
     * @param recipient Recipient address on the destination chain
     * @return amountOut Actual amount of TRUST received and bridged
     * @return transferId Unique cross-chain transfer ID from Metalayer
     */
    function swapArbitraryTokenAndBridge(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    )
        external
        payable
        returns (uint256 amountOut, bytes32 transferId);

    /**
     * @notice Quotes expected TRUST out for arbitrary token input
     * @dev Discovers optimal route and returns quote, reverts if no viable route
     * @param tokenIn Address of input token
     * @param amountIn Amount of input token
     * @return amountOut Expected amount of TRUST out
     * @return routeHops Number of hops in the discovered route (1, 2, or 3)
     */
    function quoteArbitraryTokenSwap(
        address tokenIn,
        uint256 amountIn
    )
        external
        view
        returns (uint256 amountOut, uint256 routeHops);

    /**
     * @notice Returns the USDC token contract
     * @return The USDC token contract
     */
    function usdcToken() external view returns (IERC20);

    /**
     * @notice Returns the TRUST token contract
     * @return The TRUST token contract
     */
    function trustToken() external view returns (IERC20);

    /**
     * @notice Returns the Aerodrome Router contract
     * @return The Aerodrome Router contract
     */
    function aerodromeRouter() external view returns (IAerodromeRouter);

    /**
     * @notice Returns the Aerodrome Pool Factory contract address
     * @return The Pool Factory address
     */
    function poolFactory() external view returns (address);

    /**
     * @notice Returns the default deadline (in seconds) for swaps
     * @return The default swap deadline
     */
    function defaultSwapDeadline() external view returns (uint256);

    /**
     * @notice Returns the MetaERC20Hub contract
     * @return The MetaERC20Hub contract
     */
    function metaERC20Hub() external view returns (IMetaERC20Hub);

    /**
     * @notice Returns the recipient domain ID for bridging
     * @return The recipient domain ID
     */
    function recipientDomain() external view returns (uint32);

    /**
     * @notice Returns the bridge gas limit
     * @return The bridge gas limit
     */
    function bridgeGasLimit() external view returns (uint256);

    /**
     * @notice Returns the finality state for bridging
     * @return The finality state
     */
    function finalityState() external view returns (FinalityState);

    /**
     * @notice Returns the WETH token address
     * @return The WETH token address
     */
    function weth() external view returns (address);

    /**
     * @notice Returns the minimum output threshold for route viability
     * @return The minimum output threshold in TRUST wei (18 decimals)
     */
    function minimumOutputThreshold() external view returns (uint256);

    /**
     * @notice Returns the maximum slippage tolerance
     * @return The maximum slippage in basis points (10000 = 100%)
     */
    function maxSlippageBps() external view returns (uint256);
}
