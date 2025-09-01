// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";


/// @title IMetatokenSender Interface
/// @notice Interface for contracts that can send metatokens across domains
/// @dev Not recommended for production use - this is a convenience interface only
interface IMetatokenSender {
    /// @notice Sends metatoken from the sender to the recipient on a specified domain
    /// @dev The caller must first SEND (transfer) the metatoken balance to this contract before calling this function
    /// @param to The address to send metatoken to on the destination domain  
    /// @param domain The destination domain ID
    /// @param amount The amount of metatoken to send
    function sendMetatoken(address to, uint32 domain, uint256 amount) payable external;
}

/// @title IMetatoken Interface
/// @notice Interface for metatoken contracts (both hub and spoke)
interface IMetatoken {
    /// @notice Finality states for cross-chain transfers
    enum FinalityState {
        INSTANT,
        FINALIZED
    }

    /// @notice Transfers tokens to a remote domain
    /// @param _recipientDomain The destination domain ID
    /// @param _recipientAddress The recipient address as bytes32
    /// @param _amount The amount to transfer
    /// @param _gasLimit The gas limit for the destination transaction
    /// @param _finalityState The finality requirement for the transfer
    /// @return transferId The unique identifier for this transfer
    function transferRemote(
        uint32 _recipientDomain,
        bytes32 _recipientAddress,
        uint256 _amount,
        uint256 _gasLimit,
        FinalityState _finalityState
    ) external payable returns (bytes32 transferId);

    /// @notice Returns the metalayer router address
    /// @return The address of the metalayer router
    function metalayerRouter() external view returns (address);
}

/// @title IMetaTokenHub Interface
/// @notice Interface for metatoken hub contracts
interface IMetaTokenHub {
    /// @notice Returns the underlying token address for this hub
    /// @return The address of the underlying ERC20 token
    function token() external view returns (address);
}

/// @title IIGP Interface  
/// @notice Interface for the Interchain Gas Paymaster
interface IIGP {
    /// @notice Quotes the gas payment required for a cross-chain transaction
    /// @param destinationDomain The destination domain ID
    /// @param gasLimit The gas limit for the destination transaction
    /// @return The amount of ETH required for gas payment
    function quoteGasPayment(uint32 destinationDomain, uint256 gasLimit) external view returns (uint256);
}

/// @title IMetalayerRouter Interface
/// @notice Interface for the metalayer router
interface IMetalayerRouter {
    /// @notice Returns the IGP address used by this router
    /// @return The address of the Interchain Gas Paymaster
    function igp() external view returns (address);
}

/// @title MetatokenHubSpender - Hub Token Sender Implementation
/// @notice Handles sending metatokens from hub contracts
/// @dev This contract is deployed by MTSendHelper when dealing with hub tokens
contract MetatokenHubSpender is IMetatokenSender {
    /// @notice The hub token contract address
    address public immutable hubToken;
    
    /// @notice The hub contract address
    address public immutable hub;

    /// @notice Creates a new hub spender for the specified hub and token
    /// @param _hubToken The address of the hub token contract
    /// @param _hub The address of the hub contract
    constructor(address _hubToken, address _hub) {
        hubToken = _hubToken;
        hub = _hub;
    }

    /// @notice Sends metatokens from a hub to a destination domain
    /// @dev The caller must have already sent tokens to this contract
    /// @param to The recipient address on the destination domain
    /// @param domain The destination domain ID
    /// @param amount The amount of tokens to send
    function sendMetatoken(address to, uint32 domain, uint256 amount) payable external {
        // Approve the hub to spend the tokens
        IERC20(hubToken).approve(hub, amount);
        // Execute the cross-chain transfer
        IMetatoken(hub).transferRemote{value: msg.value}(domain, bytes32(uint256(uint160(to))), amount, 100_000, IMetatoken.FinalityState.INSTANT);
    }
}

/// @title MetatokenSpokeSender - Spoke Token Sender Implementation  
/// @notice Handles sending metatokens from spoke contracts
/// @dev This contract is deployed by MTSendHelper when dealing with spoke tokens
contract MetatokenSpokeSender is IMetatokenSender {
    /// @notice The spoke token contract address
    address public immutable spoke;

    /// @notice Creates a new spoke sender for the specified spoke token
    /// @param _spoke The address of the spoke token contract
    constructor(address _spoke) {
        spoke = _spoke;
    }

    /// @notice Sends metatokens from a spoke to a destination domain
    /// @dev The caller must have already sent tokens to this contract
    /// @param to The recipient address on the destination domain
    /// @param domain The destination domain ID
    /// @param amount The amount of tokens to send
    function sendMetatoken(address to, uint32 domain, uint256 amount) payable external {
        // Execute the cross-chain transfer directly on the spoke
        IMetatoken(spoke).transferRemote{value: msg.value}(domain, bytes32(uint256(uint160(to))), amount, 100_000, IMetatoken.FinalityState.INSTANT);
    }
}

/// @title MTSendHelper - Metatoken Send Convenience Contract
/// @notice A convenience contract that simplifies sending metatokens across domains with automatic gas calculation and refunding
/// @dev This contract is NOT recommended for production use. It's designed to unify the interface between hub and spoke tokens.
///      The contract automatically detects whether the token is a hub or spoke and deploys the appropriate sender contract.
/// @author Constellation Network
contract MTSendHelper {
    /// @notice The hub or spoke token contract address
    address public immutable hubOrSpoke;
    
    /// @notice The actual token address (for hubs, this is different from hubOrSpoke; for spokes, it's the same)
    address public immutable hubOrSpokeToken;
    
    /// @notice The internal sender contract that handles the actual token transfers
    IMetatokenSender public immutable sender;
    
    /// @notice The Interchain Gas Paymaster for calculating gas costs
    IIGP public immutable igp;
   

    /// @notice Creates a new MTSendHelper instance for the given hub or spoke token
    /// @dev Automatically detects whether the token is a hub or spoke by checking for the token() function
    /// @param _hubOrSpoke The address of the hub or spoke token contract
    constructor(address _hubOrSpoke) {
       // If the address implements the token() function, then it is a hub. Else, it is a spoke.
       // Check if the token() function selector reverts to determine hub vs spoke
       (bool success, bytes memory data) = _hubOrSpoke.call(abi.encodeWithSelector(IMetaTokenHub.token.selector));
       if (success) {
        // This is a hub - get the actual token address and deploy hub spender
        hubOrSpoke = _hubOrSpoke;
        hubOrSpokeToken = IMetaTokenHub(hubOrSpoke).token();
        sender = new MetatokenHubSpender(hubOrSpokeToken, hubOrSpoke);
       } else {
        // This is a spoke - the token address is the same as the spoke address
        hubOrSpoke = _hubOrSpoke;
        hubOrSpokeToken = _hubOrSpoke;
        sender = new MetatokenSpokeSender(hubOrSpoke);
       }
       // Initialize the IGP for gas calculations
       igp = IIGP(IMetalayerRouter(IMetatoken(hubOrSpoke).metalayerRouter()).igp());
    }

    /// @notice Sends metatokens to a recipient on a specified domain with automatic gas calculation and refunding
    /// @dev This is a convenience function that handles gas calculation and refunding automatically.
    ///      The caller must first approve this contract to spend the specified amount of tokens.
    ///      Any excess ETH sent will be refunded to the caller.
    /// @param to The recipient address on the destination domain
    /// @param domain The destination domain ID (e.g., 421614 for Arbitrum Sepolia, 84532 for Base Sepolia)
    /// @param amount The amount of tokens to send
    function sendMetatoken(address to, uint32 domain, uint256 amount) payable external {
        // Transfer tokens from user directly to the sender contract
        IERC20(hubOrSpokeToken).transferFrom(msg.sender, address(sender), amount);
        
        // Calculate the correct gas limit for the transfer (base gas + additional for cross-chain)
        uint256 gasLimit = igp.quoteGasPayment(domain, 100_000 + 125_000);
        require(msg.value >= gasLimit, "Not enough value sent");
        
        // Execute the cross-chain transfer
        sender.sendMetatoken{value: gasLimit}(to, domain, amount);
        
        // Refund any excess ETH to the caller
        if (msg.value > gasLimit) {
            payable(msg.sender).transfer(msg.value - gasLimit);
        }
    }
}