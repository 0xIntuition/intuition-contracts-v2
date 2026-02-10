// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ICLFactory } from "src/interfaces/external/aerodrome/ICLFactory.sol";
import { FinalityState, IMetaERC20Hub } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";

/**
 * @title  ITrustSwapAndBridgeRouter
 * @author 0xIntuition
 * @notice Interface for the TrustSwapAndBridgeRouter contract which facilitates swapping any token for TRUST tokens
 *         on the Base network using pre-built Slipstream (CL) paths and bridging them to Intuition mainnet via
 * Metalayer.
 */

/// @notice Configuration struct for router initialization
struct RouterConfig {
    address slipstreamSwapRouter;
    address slipstreamFactory;
    address slipstreamQuoter;
    address metaERC20Hub;
    uint32 recipientDomain;
    uint256 bridgeGasLimit;
    FinalityState finalityState;
}

interface ITrustSwapAndBridgeRouter {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Emitted when a user swaps ETH for TRUST and bridges to destination chain
     * @param user The address of the user who performed the swap and bridge
     * @param ethSwapped The amount of ETH swapped (not including bridge fee)
     * @param trustOut The amount of TRUST tokens received and bridged
     * @param recipientAddress The recipient address on the destination chain
     * @param transferId The unique cross-chain transfer ID from Metalayer
     */
    event SwappedAndBridgedFromETH(
        address indexed user, uint256 ethSwapped, uint256 trustOut, bytes32 recipientAddress, bytes32 transferId
    );

    /**
     * @notice Emitted when an ERC20 token is swapped for TRUST and bridged
     * @param user The address of the user who performed the swap
     * @param tokenIn The input token address
     * @param amountIn The amount of input token swapped
     * @param trustOut The amount of TRUST received and bridged
     * @param recipientAddress The recipient address on the destination chain
     * @param transferId The unique cross-chain transfer ID from Metalayer
     */
    event SwappedAndBridgedFromERC20(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 trustOut,
        bytes32 recipientAddress,
        bytes32 transferId
    );

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
     * @notice Emitted when the Slipstream swap router is updated
     * @param newSlipstreamSwapRouter The new Slipstream SwapRouter address
     */
    event SlipstreamSwapRouterSet(address indexed newSlipstreamSwapRouter);

    /**
     * @notice Emitted when the Slipstream factory is updated
     * @param newSlipstreamFactory The new Slipstream CL Factory address
     */
    event SlipstreamFactorySet(address indexed newSlipstreamFactory);

    /**
     * @notice Emitted when the Slipstream quoter is updated
     * @param newSlipstreamQuoter The new Slipstream CL Quoter address
     */
    event SlipstreamQuoterSet(address indexed newSlipstreamQuoter);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    /// @dev Thrown when a zero address is provided where a valid address is required
    error TrustSwapAndBridgeRouter_InvalidAddress();

    /// @dev Thrown when attempting to swap with zero amount
    error TrustSwapAndBridgeRouter_AmountInZero();

    /// @dev Thrown when insufficient ETH is provided for bridge fees
    error TrustSwapAndBridgeRouter_InsufficientBridgeFee();

    /// @dev Thrown when an invalid recipient domain is provided
    error TrustSwapAndBridgeRouter_InvalidRecipientDomain();

    /// @dev Thrown when an invalid bridge gas limit is provided
    error TrustSwapAndBridgeRouter_InvalidBridgeGasLimit();

    /// @dev Thrown when insufficient ETH is provided for swap and bridge
    error TrustSwapAndBridgeRouter_InsufficientETH();

    /// @dev Thrown when input token address is invalid (zero address or TRUST)
    error TrustSwapAndBridgeRouter_InvalidToken();

    /// @dev Thrown when the packed path is malformed (too short or wrong length)
    error TrustSwapAndBridgeRouter_InvalidPath();

    /// @dev Thrown when the first token in the path is not WETH (for ETH swaps)
    error TrustSwapAndBridgeRouter_PathDoesNotStartWithWETH();

    /// @dev Thrown when the first token in the path does not match tokenIn (for ERC20 swaps)
    error TrustSwapAndBridgeRouter_PathDoesNotStartWithToken();

    /// @dev Thrown when the last token in the path is not TRUST
    error TrustSwapAndBridgeRouter_PathDoesNotEndWithTRUST();

    /// @dev Thrown when a pool referenced in the path does not exist in the CL factory
    error TrustSwapAndBridgeRouter_PoolDoesNotExist();

    /// @dev Thrown when route path[0] doesn't match tokenIn
    error TrustSwapAndBridgeRouter_TokenMismatch();

    /* =================================================== */
    /*                      FUNCTIONS                      */
    /* =================================================== */

    /**
     * @notice Initializes the TrustSwapAndBridgeRouter contract
     * @param owner Owner address for the Ownable2StepUpgradeable
     * @param config Router configuration struct containing all initialization parameters
     */
    function initialize(address owner, RouterConfig calldata config) external;

    /**
     * @notice Swaps ETH for TRUST using a pre-built Slipstream path and bridges to destination chain
     * @dev Wraps ETH to WETH, then calls Slipstream SwapRouter exactInput. Path must start with WETH and end with
     * TRUST.
     *      msg.value must include both swap amount and bridge fee.
     * @param path Packed Slipstream path (token0|tickSpacing|token1|...). Must start with WETH and end with TRUST.
     * @param minTrustOut Minimum acceptable TRUST output (slippage protection, enforced by SwapRouter)
     * @param recipient Recipient address on destination chain
     * @return amountOut Actual TRUST received and bridged
     * @return transferId Cross-chain transfer ID from Metalayer
     */
    function swapAndBridgeWithETH(
        bytes calldata path,
        uint256 minTrustOut,
        address recipient
    )
        external
        payable
        returns (uint256 amountOut, bytes32 transferId);

    /**
     * @notice Swaps any ERC20 for TRUST using a pre-built Slipstream path and bridges to destination chain
     * @dev Caller must approve this contract to spend amountIn of tokenIn. msg.value must cover bridge fee.
     * @param tokenIn Input token address (must match first token in path)
     * @param amountIn Amount of tokenIn to swap
     * @param path Packed Slipstream path (token0|tickSpacing|token1|...). Must start with tokenIn and end with TRUST.
     * @param minTrustOut Minimum acceptable TRUST output (slippage protection, enforced by SwapRouter)
     * @param recipient Recipient address on destination chain
     * @return amountOut Actual TRUST received and bridged
     * @return transferId Cross-chain transfer ID from Metalayer
     */
    function swapAndBridgeWithERC20(
        address tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minTrustOut,
        address recipient
    )
        external
        payable
        returns (uint256 amountOut, bytes32 transferId);

    /**
     * @notice Quotes the bridge fee for transferring TRUST to the destination chain
     * @param trustAmount The amount of TRUST to bridge (fee may be flat regardless of amount)
     * @param recipient The recipient address on the destination chain
     * @return bridgeFee The required bridge fee in ETH
     */
    function quoteBridgeFee(uint256 trustAmount, address recipient) external view returns (uint256 bridgeFee);

    /**
     * @notice Quotes expected output for a given Slipstream path and input amount
     * @dev Thin wrapper around Slipstream QuoterV2. Returns 0 on failure.
     * @param path Packed Slipstream path
     * @param amountIn Input amount for first token in path
     * @return amountOut Expected output amount
     */
    function quoteExactInput(bytes calldata path, uint256 amountIn) external returns (uint256 amountOut);

    /* =================================================== */
    /*                   ADMIN FUNCTIONS                   */
    /* =================================================== */

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
     * @notice Updates the Slipstream SwapRouter address
     * @param newSlipstreamSwapRouter Address of the new Slipstream SwapRouter
     */
    function setSlipstreamSwapRouter(address newSlipstreamSwapRouter) external;

    /**
     * @notice Updates the Slipstream CL Factory address
     * @param newSlipstreamFactory Address of the new Slipstream CL Factory
     */
    function setSlipstreamFactory(address newSlipstreamFactory) external;

    /**
     * @notice Updates the Slipstream CL Quoter address
     * @param newSlipstreamQuoter Address of the new Slipstream CL Quoter
     */
    function setSlipstreamQuoter(address newSlipstreamQuoter) external;

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /**
     * @notice Returns the TRUST token contract
     * @return The TRUST token contract
     */
    function trustToken() external view returns (IERC20);

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
     * @notice Returns the Slipstream SwapRouter address
     * @return The Slipstream SwapRouter address
     */
    function slipstreamSwapRouter() external view returns (address);

    /**
     * @notice Returns the Slipstream CL Factory
     * @return The Slipstream CL Factory contract
     */
    function slipstreamFactory() external view returns (ICLFactory);

    /**
     * @notice Returns the Slipstream CL Quoter address
     * @return The Slipstream CL Quoter address
     */
    function slipstreamQuoter() external view returns (address);
}
