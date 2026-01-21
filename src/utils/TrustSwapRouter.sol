// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IAerodromeRouter } from "src/interfaces/external/aerodrome/IAerodromeRouter.sol";
import { FinalityState, IMetaERC20Hub } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";
import { IWETH } from "src/interfaces/external/IWETH.sol";
import { ITrustSwapRouter } from "src/interfaces/ITrustSwapRouter.sol";

/**
 * @title TrustSwapRouter
 * @author 0xIntuition
 * @notice TrustSwapRouter facilitates swapping USDC for TRUST tokens on the Base network using the Aerodrome DEX
 *         and bridging them to Intuition mainnet via Metalayer.
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

    /// @notice WETH token contract on Base (canonical Base WETH)
    address public immutable weth;

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

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        weth = 0x4200000000000000000000000000000000000006; // Base canonical WETH
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustSwapRouter
    function initialize(
        address _owner,
        address usdcAddress,
        address trustAddress,
        address aerodromeRouterAddress,
        address poolFactoryAddress,
        address metaERC20HubAddress,
        uint32 _recipientDomain,
        uint256 _bridgeGasLimit,
        FinalityState _finalityState,
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
        _setMetaERC20Hub(metaERC20HubAddress);
        _setRecipientDomain(_recipientDomain);
        _setBridgeGasLimit(_bridgeGasLimit);
        _setFinalityState(_finalityState);
        _setDefaultSwapDeadline(_defaultSwapDeadline);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustSwapRouter
    function setUSDCAddress(address newUSDC) external onlyOwner {
        _setUSDCAddress(newUSDC);
    }

    /// @inheritdoc ITrustSwapRouter
    function setTRUSTAddress(address newTRUST) external onlyOwner {
        _setTRUSTAddress(newTRUST);
    }

    /// @inheritdoc ITrustSwapRouter
    function setAerodromeRouter(address newRouter) external onlyOwner {
        _setAerodromeRouter(newRouter);
    }

    /// @inheritdoc ITrustSwapRouter
    function setPoolFactory(address newFactory) external onlyOwner {
        _setPoolFactory(newFactory);
    }

    /// @inheritdoc ITrustSwapRouter
    function setDefaultSwapDeadline(uint256 newDeadline) external onlyOwner {
        _setDefaultSwapDeadline(newDeadline);
    }

    /// @inheritdoc ITrustSwapRouter
    function setMetaERC20Hub(address newMetaERC20Hub) external onlyOwner {
        _setMetaERC20Hub(newMetaERC20Hub);
    }

    /// @inheritdoc ITrustSwapRouter
    function setRecipientDomain(uint32 newRecipientDomain) external onlyOwner {
        _setRecipientDomain(newRecipientDomain);
    }

    /// @inheritdoc ITrustSwapRouter
    function setBridgeGasLimit(uint256 newBridgeGasLimit) external onlyOwner {
        _setBridgeGasLimit(newBridgeGasLimit);
    }

    /// @inheritdoc ITrustSwapRouter
    function setFinalityState(FinalityState newFinalityState) external onlyOwner {
        _setFinalityState(newFinalityState);
    }

    /*//////////////////////////////////////////////////////////////
                        SWAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustSwapRouter
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
        if (amountIn == 0) revert TrustSwapRouter_AmountInZero();

        usdcToken.safeTransferFrom(msg.sender, address(this), amountIn);

        return _executeSwapAndBridge(amountIn, minAmountOut, bytes32(uint256(uint160(recipient))));
    }

    /// @inheritdoc ITrustSwapRouter
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
        if (amountIn == 0) revert TrustSwapRouter_AmountInZero();
        if (deadline < block.timestamp) revert TrustSwapRouter_PermitExpired();

        try IERC20Permit(address(usdcToken)).permit(msg.sender, address(this), amountIn, deadline, v, r, s) { }
        catch {
            uint256 currentAllowance = usdcToken.allowance(msg.sender, address(this));
            if (currentAllowance < amountIn) {
                revert TrustSwapRouter_PermitFailed();
            }
        }

        usdcToken.safeTransferFrom(msg.sender, address(this), amountIn);

        return _executeSwapAndBridge(amountIn, minAmountOut, bytes32(uint256(uint160(recipient))));
    }

    /// @inheritdoc ITrustSwapRouter
    function swapAndBridgeWithETH(
        uint256 minAmountOut,
        address recipient
    )
        external
        payable
        nonReentrant
        returns (uint256 amountOut, bytes32 transferId)
    {
        if (msg.value == 0) revert TrustSwapRouter_InsufficientETH();

        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));

        uint256 estimatedTrustOut = _quoteSwapFromETH(msg.value);
        uint256 estimatedBridgeFee =
            metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, estimatedTrustOut);

        if (msg.value <= estimatedBridgeFee) {
            revert TrustSwapRouter_InsufficientETH();
        }
        uint256 ethAmountForSwap = msg.value - estimatedBridgeFee;

        return _executeSwapFromETHAndBridge(ethAmountForSwap, minAmountOut, recipientAddress);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITrustSwapRouter
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

    /// @inheritdoc ITrustSwapRouter
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

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({
            from: address(usdcToken), to: address(trustToken), stable: false, factory: poolFactory
        });

        uint256[] memory amounts = aerodromeRouter.getAmountsOut(amountIn, routes);
        amountOut = amounts[amounts.length - 1];

        bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, bytes32(uint256(uint160(recipient))), amountOut);
    }

    /// @inheritdoc ITrustSwapRouter
    function quoteSwapFromETHToTrust(uint256 amountIn) external view returns (uint256 amountOut) {
        return _quoteSwapFromETH(amountIn);
    }

    /// @inheritdoc ITrustSwapRouter
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
        uint256 swapDeadline = block.timestamp + defaultSwapDeadline;

        // Execute swap and receive TRUST to this contract
        uint256[] memory amounts =
            aerodromeRouter.swapExactTokensForTokens(amountIn, minAmountOut, routes, address(this), swapDeadline);

        amountOut = amounts[amounts.length - 1];

        // Approve MetaERC20Hub to spend TRUST
        trustToken.safeIncreaseAllowance(address(metaERC20Hub), amountOut);

        // Get bridge fee quote
        uint256 bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, amountOut);

        // Verify sufficient ETH provided for bridge fee
        if (msg.value < bridgeFee) revert TrustSwapRouter_InsufficientBridgeFee();

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
        if (ethRemaining < bridgeFee) revert TrustSwapRouter_InsufficientBridgeFee();

        transferId = metaERC20Hub.transferRemote{ value: bridgeFee }(
            recipientDomain, recipientAddress, amountOut, bridgeGasLimit, finalityState
        );

        if (ethRemaining > bridgeFee) {
            (bool success,) = msg.sender.call{ value: ethRemaining - bridgeFee }("");
            require(success, "ETH refund failed");
        }

        emit SwappedAndBridgedFromETH(msg.sender, ethAmountForSwap, amountOut, recipientAddress, transferId);
    }

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

    /// @dev Internal function to set the MetaERC20Hub address
    function _setMetaERC20Hub(address newMetaERC20Hub) internal {
        if (newMetaERC20Hub == address(0)) revert TrustSwapRouter_InvalidAddress();
        metaERC20Hub = IMetaERC20Hub(newMetaERC20Hub);
        emit MetaERC20HubSet(newMetaERC20Hub);
    }

    /// @dev Internal function to set the recipient domain
    function _setRecipientDomain(uint32 newRecipientDomain) internal {
        if (newRecipientDomain == 0) revert TrustSwapRouter_InvalidRecipientDomain();
        recipientDomain = newRecipientDomain;
        emit RecipientDomainSet(newRecipientDomain);
    }

    /// @dev Internal function to set the bridge gas limit
    function _setBridgeGasLimit(uint256 newBridgeGasLimit) internal {
        if (newBridgeGasLimit == 0) revert TrustSwapRouter_InvalidBridgeGasLimit();
        bridgeGasLimit = newBridgeGasLimit;
        emit BridgeGasLimitSet(newBridgeGasLimit);
    }

    /// @dev Internal function to set the finality state
    function _setFinalityState(FinalityState newFinalityState) internal {
        finalityState = newFinalityState;
        emit FinalityStateSet(newFinalityState);
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
