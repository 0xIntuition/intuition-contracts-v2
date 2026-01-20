// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @notice Enum representing the finality state options for cross-chain transfers via Metalayer
enum FinalityState {
    INSTANT,
    FINALIZED,
    ESPRESSO
}

interface IMetaERC20Hub {
    /// @notice Dispatches a MetaERC20 transfer to a remote domain
    /// @dev Constructs, validates, stores, and sends a cross-chain MetaERC20MessageStruct.
    ///      Amount is sent in source token units; destination will convert using sourceDecimals.
    /// @param _recipientDomain The Metalayer domain ID of the destination chain
    /// @param _recipientAddress The recipient address on the destination chain (bytes32 format)
    /// @param _amount The amount of tokens to transfer in local token units (no decimal scaling)
    /// @param _gasLimit The gas limit for the destination chain execution
    /// @param _finalityState The desired finality state for the transfer
    /// @return transferId A unique hash representing this cross-chain transfer
    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finalityState
    )
        external
        payable
        returns (bytes32 transferId);

    /**
     * @notice Quote the cost of a remote transfer without executing it
     * @param _recipientDomain The domain of the destination chain
     * @param _recipientAddress The recipient address on the destination chain (bytes32 format)
     * @param _amount The amount of tokens to transfer
     * @return The quoted cost in wei for the transfer
     */
    function quoteTransferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount
    )
        external
        view
        returns (uint256);
}
