// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IAerodromeRouter } from "src/interfaces/external/aerodrome/IAerodromeRouter.sol";

/**
 * @title  ITrustSwapRouter
 * @author 0xIntuition
 * @notice Interface for the TrustSwapRouter contract which facilitates swapping USDC for TRUST tokens
 *         on the Base network using the Aerodrome DEX.
 */
interface ITrustSwapRouter {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Emitted when the USDC token address is updated
     * @param newUSDC The new USDC token address
     */
    event USDCAddressSet(address indexed newUSDC);

    /**
     * @notice Emitted when the TRUST token address is updated
     * @param newTRUST The new TRUST token address
     */
    event TRUSTAddressSet(address indexed newTRUST);

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

    /* =================================================== */
    /*                      FUNCTIONS                      */
    /* =================================================== */

    /**
     * @notice Initializes the TrustSwapRouter contract
     * @param owner Owner address for the Ownable2StepUpgradeable
     * @param usdcAddress Address of the USDC token contract
     * @param trustAddress Address of the TRUST token contract
     * @param aerodromeRouterAddress Address of the Aerodrome Router contract
     * @param poolFactoryAddress Address of the Aerodrome Pool Factory contract
     * @param defaultSwapDeadline Default deadline (in seconds) for swaps
     */
    function initialize(
        address owner,
        address usdcAddress,
        address trustAddress,
        address aerodromeRouterAddress,
        address poolFactoryAddress,
        uint256 defaultSwapDeadline
    )
        external;

    /**
     * @notice Updates the USDC token contract address
     * @param newUSDC Address of the new USDC token contract
     */
    function setUSDCAddress(address newUSDC) external;

    /**
     * @notice Updates the TRUST token contract address
     * @param newTRUST Address of the new TRUST token contract
     */
    function setTRUSTAddress(address newTRUST) external;

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
     * @notice Swaps `amountIn` USDC for TRUST tokens, sending them to the caller
     * @dev Caller must approve this contract to spend `amountIn` USDC first
     * @param amountIn Amount of USDC to swap
     * @param minAmountOut Minimum acceptable amount of TRUST to receive (slippage protection)
     * @return amountOut Actual amount of TRUST received
     */
    function swapToTrust(uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut);

    /**
     * @notice Swaps `amountIn` USDC for TRUST using EIP-2612 permit (approve + swap in one tx)
     * @dev If `permit()` fails, proceeds only if the caller already granted sufficient USDC allowance
     * @param amountIn Amount of USDC to swap
     * @param minAmountOut Minimum acceptable amount of TRUST to receive (slippage protection)
     * @param deadline Deadline for the permit signature
     * @param v ECDSA signature component
     * @param r ECDSA signature component
     * @param s ECDSA signature component
     * @return amountOut Amount of TRUST received
     */
    function swapToTrustWithPermit(
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (uint256 amountOut);

    /**
     * @notice Quotes expected TRUST out for `amountIn` USDC (USDC has 6 decimals)
     * @dev Assumes the USDC/TRUST pool is a volatile pool (stable=false)
     * @param amountIn Amount of USDC to quote
     * @return amountOut Expected amount of TRUST out
     */
    function quoteSwapToTrust(uint256 amountIn) external view returns (uint256 amountOut);

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
}
