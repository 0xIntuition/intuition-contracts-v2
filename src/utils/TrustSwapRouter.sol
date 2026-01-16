// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IAerodromeRouter } from "src/interfaces/external/aerodrome/IAerodromeRouter.sol";
import { ITrustSwapRouter } from "src/interfaces/ITrustSwapRouter.sol";

/**
 * @title TrustSwapRouter
 * @author 0xIntuition
 * @notice TrustSwapRouter facilitates swapping USDC for TRUST tokens on the Base network using the Aerodrome DEX.
 */
contract TrustSwapRouter is ITrustSwapRouter, Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice USDC token contract on Base
    IERC20 public usdcToken;

    /// @notice TRUST token contract on Base
    IERC20 public trustToken;

    /// @notice Aerodrome Router contract on Base
    IAerodromeRouter public aerodromeRouter;

    /// @notice Aerodrome Pool Factory contract address on Base
    address public poolFactory;

    /// @notice Default deadline (in seconds) for swaps
    uint256 public defaultSwapDeadline;

    /// THINGS TO USE FOR THE DEPLOY SCRIPT
    // // ===== Base token addresses =====
    // address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // address public constant TRUST = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;

    // // ===== Aerodrome V2 Router / Factory (Base) =====
    // address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    // address public constant POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    // IAerodromeRouter public constant router = IAerodromeRouter(AERODROME_ROUTER);
    // IERC20 public constant usdc = IERC20(USDC);

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

    /**
     * @notice Initializes the TrustSwapRouter contract
     * @param _owner Owner address for the Ownable2StepUpgradeable
     * @param usdcAddress Address of the USDC token contract
     * @param trustAddress Address of the TRUST token contract
     * @param aerodromeRouterAddress Address of the Aerodrome Router contract
     * @param poolFactoryAddress Address of the Aerodrome Pool Factory contract
     * @param _defaultSwapDeadline Default deadline (in seconds) for swaps
     */
    function initialize(
        address _owner,
        address usdcAddress,
        address trustAddress,
        address aerodromeRouterAddress,
        address poolFactoryAddress,
        uint256 _defaultSwapDeadline
    )
        external
        initializer
    {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        _setUSDCAddress(usdcAddress);
        _setTRUSTAddress(trustAddress);
        _setAerodromeRouter(aerodromeRouterAddress);
        _setPoolFactory(poolFactoryAddress);
        _setDefaultSwapDeadline(_defaultSwapDeadline);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the USDC token contract address
     * @param newUSDC Address of the new USDC token contract
     */
    function setUSDCAddress(address newUSDC) external onlyOwner {
        _setUSDCAddress(newUSDC);
    }

    /**
     * @notice Updates the TRUST token contract address
     * @param newTRUST Address of the new TRUST token contract
     */
    function setTRUSTAddress(address newTRUST) external onlyOwner {
        _setTRUSTAddress(newTRUST);
    }

    /**
     * @notice Updates the Aerodrome Router contract address
     * @param newRouter Address of the new Aerodrome Router contract
     */
    function setAerodromeRouter(address newRouter) external onlyOwner {
        _setAerodromeRouter(newRouter);
    }

    /**
     * @notice Updates the Aerodrome Pool Factory contract address
     * @param newFactory Address of the new Aerodrome Pool Factory contract
     */
    function setPoolFactory(address newFactory) external onlyOwner {
        _setPoolFactory(newFactory);
    }

    /**
     * @notice Updates the default swap deadline
     * @param newDeadline New default deadline (in seconds) for swaps
     */
    function setDefaultSwapDeadline(uint256 newDeadline) external onlyOwner {
        _setDefaultSwapDeadline(newDeadline);
    }

    /*//////////////////////////////////////////////////////////////
                        SWAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Swaps `amountIn` USDC for TRUST tokens, sending them to the caller
     * @dev Caller must approve this contract to spend `amountIn` USDC first.
     * @param amountIn Amount of USDC to swap
     * @param minAmountOut Minimum acceptable amount of TRUST to receive (slippage protection)
     * @return amountOut Actual amount of TRUST received
     */
    function swapToTrust(uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        if (amountIn == 0) revert TrustSwapRouter_AmountInZero();

        // Pull USDC from user
        usdcToken.safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve router to spend USDC using a safe pattern
        usdcToken.safeIncreaseAllowance(address(aerodromeRouter), amountIn);

        // Build the single-hop route
        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({
            from: address(usdcToken),
            to: address(trustToken),
            stable: false, // volatile pool
            factory: poolFactory
        });

        // Deadline for the swap: current time + defaultSwapDeadline
        uint256 deadline = block.timestamp + defaultSwapDeadline;

        uint256[] memory amounts =
            aerodromeRouter.swapExactTokensForTokens(amountIn, minAmountOut, routes, msg.sender, deadline);

        amountOut = amounts[amounts.length - 1];

        if (amountOut < minAmountOut) {
            revert TrustSwapRouter_InsufficientOutputAmount();
        }

        emit SwappedToTrust(msg.sender, amountIn, amountOut);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Quotes expected TRUST out for `amountIn` USDC (USDC has 6 decimals)
     * @dev Assumes the USDC/TRUST pool is a volatile pool (stable=false)
     * @param amountIn Amount of USDC to quote
     * @return amountOut Expected amount of TRUST out
     */
    function quoteSwapToTrust(uint256 amountIn) external view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({
            from: address(usdcToken),
            to: address(trustToken),
            stable: false, // TRUST/USDC is a volatile pool
            factory: poolFactory
        });

        uint256[] memory amounts = aerodromeRouter.getAmountsOut(amountIn, routes);
        return amounts[amounts.length - 1];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal function to set the USDC address
    function _setUSDCAddress(address newUSDC) internal {
        if (newUSDC == address(0)) revert TrustSwapRouter_InvalidAddress();
        usdcToken = IERC20(newUSDC);
        emit USDCAddressSet(newUSDC);
    }

    /// @dev Internal function to set the TRUST address
    function _setTRUSTAddress(address newTRUST) internal {
        if (newTRUST == address(0)) revert TrustSwapRouter_InvalidAddress();
        trustToken = IERC20(newTRUST);
        emit TRUSTAddressSet(newTRUST);
    }

    /// @dev Internal function to set the Aerodrome Router address
    function _setAerodromeRouter(address newRouter) internal {
        if (newRouter == address(0)) revert TrustSwapRouter_InvalidAddress();
        aerodromeRouter = IAerodromeRouter(newRouter);
        emit AerodromeRouterSet(newRouter);
    }

    /// @dev Internal function to set the Aerodrome Pool Factory address
    function _setPoolFactory(address newFactory) internal {
        if (newFactory == address(0)) revert TrustSwapRouter_InvalidAddress();
        poolFactory = newFactory;
        emit PoolFactorySet(newFactory);
    }

    /// @dev Internal function to set the default swap deadline
    function _setDefaultSwapDeadline(uint256 newDeadline) internal {
        if (newDeadline == 0) revert TrustSwapRouter_InvalidDeadline();
        defaultSwapDeadline = newDeadline;
        emit DefaultSwapDeadlineSet(newDeadline);
    }
}
