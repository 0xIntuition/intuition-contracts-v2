enum FinalityState {
    INSTANT,
    FINALIZED,
    ESPRESSO
}

interface IMetaERC20Hub {
    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finalityState
    ) payable external;

    function metalayerRouter() external view returns (address);
}

interface IMetalayerRouter {
    function igp() external view returns (address);
}

interface IIGP {
    function quoteGasPayment(uint32 destinationDomain, uint256 gasLimit) external view returns (uint256);
}