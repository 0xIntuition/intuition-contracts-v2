// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ICLFactory } from "src/interfaces/external/aerodrome/ICLFactory.sol";
import { ICLQuoter } from "src/interfaces/external/aerodrome/ICLQuoter.sol";
import { ISlipstreamSwapRouter } from "src/interfaces/external/aerodrome/ISlipstreamSwapRouter.sol";
import { FinalityState, IMetaERC20Hub } from "src/interfaces/external/metalayer/IMetaERC20Hub.sol";
import { IWETH } from "src/interfaces/external/IWETH.sol";
import { ITrustSwapAndBridgeRouter, RouterConfig } from "src/interfaces/ITrustSwapAndBridgeRouter.sol";

/**
 * @title TrustSwapAndBridgeRouter
 * @author 0xIntuition
 * @notice Minimal router that validates pre-built Slipstream (CL) paths, delegates swaps to the
 *         Slipstream SwapRouter and bridges resulting TRUST to Intuition mainnet via Metalayer.
 */
contract TrustSwapAndBridgeRouter is
    ITrustSwapAndBridgeRouter,
    Initializable,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /* =================================================== */
    /*                      CONSTANTS                      */
    /* =================================================== */

    /// @notice Base mainnet TRUST address
    address public constant TRUST_ADDRESS = 0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3;

    /// @notice Base mainnet WETH address (canonical Base WETH)
    address public constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;

    /// @notice TRUST token contract on Base
    IERC20 public constant trustToken = IERC20(TRUST_ADDRESS);

    /// @dev Minimum packed path length: 1 hop = 20 (addr) + 3 (tickSpacing) + 20 (addr) = 43 bytes
    uint256 private constant MIN_PATH_LENGTH = 43;

    /// @dev Each additional hop adds 23 bytes (3 tickSpacing + 20 address)
    uint256 private constant HOP_SIZE = 23;

    /// @dev Size of an address in the packed path
    uint256 private constant ADDR_SIZE = 20;

    /* =================================================== */
    /*                   STATE VARIABLES                   */
    /* =================================================== */

    /// @notice The single allowlisted Slipstream SwapRouter
    address public slipstreamSwapRouter;

    /// @notice Slipstream CL Factory for pool existence verification
    ICLFactory public slipstreamFactory;

    /// @notice Slipstream CL Quoter for swap quotes
    address public slipstreamQuoter;

    /// @notice MetaERC20Hub contract for cross-chain bridging
    IMetaERC20Hub public metaERC20Hub;

    /// @notice Recipient domain ID for bridging (Intuition mainnet)
    uint32 public recipientDomain;

    /// @notice Gas limit for bridge transactions
    uint256 public bridgeGasLimit;

    /// @notice Finality state for bridge transactions
    FinalityState public finalityState;

    /* =================================================== */
    /*                     CONSTRUCTOR                     */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                     INITIALIZER                     */
    /* =================================================== */

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function initialize(address _owner, RouterConfig calldata config) external initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        _setSlipstreamSwapRouter(config.slipstreamSwapRouter);
        _setSlipstreamFactory(config.slipstreamFactory);
        _setSlipstreamQuoter(config.slipstreamQuoter);
        _setMetaERC20Hub(config.metaERC20Hub);
        _setRecipientDomain(config.recipientDomain);
        _setBridgeGasLimit(config.bridgeGasLimit);
        _setFinalityState(config.finalityState);
    }

    /* =================================================== */
    /*                   ADMIN FUNCTIONS                   */
    /* =================================================== */

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setSlipstreamSwapRouter(address newSlipstreamSwapRouter) external onlyOwner {
        _setSlipstreamSwapRouter(newSlipstreamSwapRouter);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setSlipstreamFactory(address newSlipstreamFactory) external onlyOwner {
        _setSlipstreamFactory(newSlipstreamFactory);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function setSlipstreamQuoter(address newSlipstreamQuoter) external onlyOwner {
        _setSlipstreamQuoter(newSlipstreamQuoter);
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

    /* =================================================== */
    /*                   SWAP FUNCTIONS                    */
    /* =================================================== */

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function swapAndBridgeWithETH(
        bytes calldata path,
        uint256 minTrustOut,
        address recipient
    )
        external
        payable
        nonReentrant
        returns (uint256 amountOut, bytes32 transferId)
    {
        if (_extractFirstToken(path) != WETH_ADDRESS) {
            revert TrustSwapAndBridgeRouter_PathDoesNotStartWithWETH();
        }
        if (_extractLastToken(path) != TRUST_ADDRESS) {
            revert TrustSwapAndBridgeRouter_PathDoesNotEndWithTRUST();
        }

        _validatePoolsExist(path);

        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));

        uint256 bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, minTrustOut);
        if (msg.value <= bridgeFee) {
            revert TrustSwapAndBridgeRouter_InsufficientETH();
        }

        uint256 swapEth = msg.value - bridgeFee;

        IWETH(WETH_ADDRESS).deposit{ value: swapEth }();

        IERC20(WETH_ADDRESS).safeIncreaseAllowance(slipstreamSwapRouter, swapEth);

        amountOut = ISlipstreamSwapRouter(slipstreamSwapRouter)
            .exactInput(
                ISlipstreamSwapRouter.ExactInputParams({
                    path: path,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: swapEth,
                    amountOutMinimum: minTrustOut
                })
            );

        transferId = _bridgeTrust(amountOut, recipientAddress, bridgeFee);

        emit SwappedAndBridgedFromETH(msg.sender, swapEth, amountOut, recipientAddress, transferId);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function swapAndBridgeWithERC20(
        address tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minTrustOut,
        address recipient
    )
        external
        payable
        nonReentrant
        returns (uint256 amountOut, bytes32 transferId)
    {
        if (amountIn == 0) revert TrustSwapAndBridgeRouter_AmountInZero();
        if (tokenIn == address(0) || tokenIn == TRUST_ADDRESS) {
            revert TrustSwapAndBridgeRouter_InvalidToken();
        }
        if (_extractFirstToken(path) != tokenIn) {
            revert TrustSwapAndBridgeRouter_PathDoesNotStartWithToken();
        }
        if (_extractLastToken(path) != TRUST_ADDRESS) {
            revert TrustSwapAndBridgeRouter_PathDoesNotEndWithTRUST();
        }

        _validatePoolsExist(path);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));

        uint256 bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, minTrustOut);
        if (msg.value < bridgeFee) {
            revert TrustSwapAndBridgeRouter_InsufficientBridgeFee();
        }

        IERC20(tokenIn).safeIncreaseAllowance(slipstreamSwapRouter, amountIn);

        amountOut = ISlipstreamSwapRouter(slipstreamSwapRouter)
            .exactInput(
                ISlipstreamSwapRouter.ExactInputParams({
                    path: path,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: minTrustOut
                })
            );

        transferId = _bridgeTrust(amountOut, recipientAddress, bridgeFee);

        uint256 refundAmount = msg.value - bridgeFee;
        _refundExcess(refundAmount);

        emit SwappedAndBridgedFromERC20(msg.sender, tokenIn, amountIn, amountOut, recipientAddress, transferId);
    }

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function quoteBridgeFee(uint256 trustAmount, address recipient) external view returns (uint256 bridgeFee) {
        bytes32 recipientAddress = bytes32(uint256(uint160(recipient)));
        bridgeFee = metaERC20Hub.quoteTransferRemote(recipientDomain, recipientAddress, trustAmount);
    }

    /// @inheritdoc ITrustSwapAndBridgeRouter
    function quoteExactInput(bytes calldata path, uint256 amountIn) external returns (uint256 amountOut) {
        if (slipstreamQuoter == address(0)) revert TrustSwapAndBridgeRouter_InvalidAddress();

        try ICLQuoter(slipstreamQuoter).quoteExactInput(path, amountIn) returns (
            uint256 quotedAmountOut, uint160[] memory, uint32[] memory, uint256
        ) {
            amountOut = quotedAmountOut;
        } catch {
            amountOut = 0;
        }
    }

    /* =================================================== */
    /*                 INTERNAL FUNCTIONS                  */
    /* =================================================== */

    /**
     * @dev Extracts the first token address from a packed Slipstream path.
     *      Path format: token0 (20 bytes) | tickSpacing (3 bytes) | token1 (20 bytes) | ...
     */
    function _extractFirstToken(bytes calldata path) internal pure returns (address token) {
        if (path.length < MIN_PATH_LENGTH) revert TrustSwapAndBridgeRouter_InvalidPath();
        assembly {
            token := shr(96, calldataload(path.offset))
        }
    }

    /**
     * @dev Extracts the last token address from a packed Slipstream path.
     *      The last 20 bytes of the path contain the final token address.
     */
    function _extractLastToken(bytes calldata path) internal pure returns (address token) {
        if (path.length < MIN_PATH_LENGTH) revert TrustSwapAndBridgeRouter_InvalidPath();
        assembly {
            token := shr(96, calldataload(add(path.offset, sub(path.length, 20))))
        }
    }

    /**
     * @dev Validates that all pools referenced in the packed path exist in the CL factory.
     *      Iterates hop-by-hop, extracting (tokenA, tickSpacing, tokenB) and checking
     *      ICLFactory.getPool(tokenA, tokenB, tickSpacing) != address(0).
     */
    function _validatePoolsExist(bytes calldata path) internal view {
        if (path.length < MIN_PATH_LENGTH) revert TrustSwapAndBridgeRouter_InvalidPath();
        if ((path.length - ADDR_SIZE) % HOP_SIZE != 0) revert TrustSwapAndBridgeRouter_InvalidPath();

        uint256 numHops = (path.length - ADDR_SIZE) / HOP_SIZE;
        uint256 offset = 0;

        for (uint256 i = 0; i < numHops; i++) {
            address tokenA;
            int24 tickSpacing;
            address tokenB;

            assembly {
                tokenA := shr(96, calldataload(add(path.offset, offset)))
                tickSpacing := signextend(2, shr(232, calldataload(add(path.offset, add(offset, 20)))))
                tokenB := shr(96, calldataload(add(path.offset, add(offset, 23))))
            }

            if (slipstreamFactory.getPool(tokenA, tokenB, tickSpacing) == address(0)) {
                revert TrustSwapAndBridgeRouter_PoolDoesNotExist();
            }

            offset += HOP_SIZE;
        }
    }

    function _bridgeTrust(
        uint256 amountOut,
        bytes32 recipientAddress,
        uint256 bridgeFee
    )
        internal
        returns (bytes32 transferId)
    {
        trustToken.safeIncreaseAllowance(address(metaERC20Hub), amountOut);

        transferId = metaERC20Hub.transferRemote{ value: bridgeFee }(
            recipientDomain, recipientAddress, amountOut, bridgeGasLimit, finalityState
        );
    }

    function _refundExcess(uint256 refundAmount) internal {
        if (refundAmount > 0) {
            (bool success,) = msg.sender.call{ value: refundAmount }("");
            require(success, "ETH refund failed");
        }
    }

    /* =================================================== */
    /*              INTERNAL ADMIN FUNCTIONS               */
    /* =================================================== */

    function _setSlipstreamSwapRouter(address newSlipstreamSwapRouter) internal {
        if (newSlipstreamSwapRouter == address(0)) revert TrustSwapAndBridgeRouter_InvalidAddress();
        slipstreamSwapRouter = newSlipstreamSwapRouter;
        emit SlipstreamSwapRouterSet(newSlipstreamSwapRouter);
    }

    function _setSlipstreamFactory(address newSlipstreamFactory) internal {
        if (newSlipstreamFactory == address(0)) revert TrustSwapAndBridgeRouter_InvalidAddress();
        slipstreamFactory = ICLFactory(newSlipstreamFactory);
        emit SlipstreamFactorySet(newSlipstreamFactory);
    }

    function _setSlipstreamQuoter(address newSlipstreamQuoter) internal {
        if (newSlipstreamQuoter == address(0)) revert TrustSwapAndBridgeRouter_InvalidAddress();
        slipstreamQuoter = newSlipstreamQuoter;
        emit SlipstreamQuoterSet(newSlipstreamQuoter);
    }

    function _setMetaERC20Hub(address newMetaERC20Hub) internal {
        if (newMetaERC20Hub == address(0)) revert TrustSwapAndBridgeRouter_InvalidAddress();
        metaERC20Hub = IMetaERC20Hub(newMetaERC20Hub);
        emit MetaERC20HubSet(newMetaERC20Hub);
    }

    function _setRecipientDomain(uint32 newRecipientDomain) internal {
        if (newRecipientDomain == 0) revert TrustSwapAndBridgeRouter_InvalidRecipientDomain();
        recipientDomain = newRecipientDomain;
        emit RecipientDomainSet(newRecipientDomain);
    }

    function _setBridgeGasLimit(uint256 newBridgeGasLimit) internal {
        if (newBridgeGasLimit == 0) revert TrustSwapAndBridgeRouter_InvalidBridgeGasLimit();
        bridgeGasLimit = newBridgeGasLimit;
        emit BridgeGasLimitSet(newBridgeGasLimit);
    }

    function _setFinalityState(FinalityState newFinalityState) internal {
        finalityState = newFinalityState;
        emit FinalityStateSet(newFinalityState);
    }
}
