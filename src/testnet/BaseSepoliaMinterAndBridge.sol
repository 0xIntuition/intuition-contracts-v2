// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { MetaERC20Dispatcher, FinalityState, IMetaERC20Hub } from "src/protocol/emissions/MetaERC20Dispatcher.sol";

interface IERC20 {
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract BaseSepoliaMinterAndBridge is MetaERC20Dispatcher, AccessControl {
    address public token;

    address public metaERC20Hub;

    constructor(address _owner, address _token, address _metaERC20Hub) {
        token = _token;
        metaERC20Hub = _metaERC20Hub;
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    receive() external payable { }

    function bridge(address to, uint32 domain, uint256 amount) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(metaERC20Hub, amount);

        uint256 GAS_CONSTANT = 100_000;
        IIGP igp = IIGP(IMetalayerRouter(IMetatoken(metaERC20Hub).metalayerRouter()).igp());

        uint256 gasLimit;
        try igp.quoteGasPayment(domain, GAS_CONSTANT + 125_000) returns (uint256 _gasLimit) {
            gasLimit = _gasLimit;
        } catch {
            gasLimit = 34_750_000_000_000;
        }
        require(msg.value >= gasLimit, "Not enough value sent");

        _bridgeTokens(metaERC20Hub, domain, bytes32(uint256(uint160(to))), amount, gasLimit, FinalityState.INSTANT);

        if (msg.value > gasLimit) {
            payable(msg.sender).transfer(msg.value - gasLimit);
        }
    }
}

interface IMetalayerRouter {
    function igp() external view returns (address);
}

interface IIGP {
    function quoteGasPayment(uint32 destinationDomain, uint256 gasLimit) external view returns (uint256);
}

interface IMetatoken {
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

    function metalayerRouter() external view returns (address);
}
