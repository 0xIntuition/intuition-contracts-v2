// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IGovernanceWrapper } from "src/interfaces/IGovernanceWrapper.sol";
import { VotesERC20, ERC20Upgradeable, IERC20Upgradeable } from "src/external/decent/VotesERC20.sol";
import { VotingEscrow } from "src/external/curve/VotingEscrow.sol";

/**
 * @title  GovernanceWrapper
 * @author 0xIntuition
 * @notice GovernanceWrapper is a “token-like” wrapper around TrustBonding. It exposes the voting power
 *         of TrustBonding via standard VotesERC20-compatible interface, allowing it to be used in governance systems.
 * @dev    Key features:
 *         - Reads vote power from VotingEscrow (TrustBonding), including both current and historical balances
 *         - Uses block.number-based clock mode for compatibility with onchain governance systems
 *         - Delegations are overridden to set msg.sender as their own delegate
 *         - Disables transfers, approvals, minting, burning, and permit functionality to ensure it is non-transferable
 */
contract GovernanceWrapper is IGovernanceWrapper, VotesERC20 {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice TrustBonding contract (casted as VotingEscrow to expose the necessary methods)
    VotingEscrow public trustBonding;

    /// @notice Mapping of account to its delegate
    mapping(address account => address delegate) internal _delegates;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

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

    /// @inheritdoc IGovernanceWrapper
    function initialize(address owner_, address trustBonding_) external initializer {
        if (owner_ == address(0)) revert GovernanceWrapper_InvalidAddress();
        _transferOwnership(owner_);
        _setTrustBonding(trustBonding_);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGovernanceWrapper
    function setTrustBonding(address _trustBonding) external onlyOwner {
        _setTrustBonding(_trustBonding);
    }

    /// @dev Internal function to set the TrustBonding contract address
    function _setTrustBonding(address _trustBonding) internal {
        if (_trustBonding == address(0)) revert GovernanceWrapper_InvalidAddress();
        trustBonding = VotingEscrow(_trustBonding);
        emit TrustBondingSet(_trustBonding);
    }

    /*//////////////////////////////////////////////////////////////
                    ERC20 OVERRIDES TO DISABLE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Overrides ERC20 `transfer` to always revert
    function transfer(address, uint256) public virtual override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        revert GovernanceWrapper_TransfersDisabled();
    }

    /// @dev Overrides ERC20 `transferFrom` to always revert
    function transferFrom(
        address,
        address,
        uint256
    )
        public
        virtual
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        revert GovernanceWrapper_TransfersDisabled();
    }

    /// @dev Overrides ERC20 `approve` to always revert
    function approve(address, uint256) public virtual override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        revert GovernanceWrapper_ApprovalsDisabled();
    }

    /// @dev Overrides internal `_transfer` to always revert
    function _transfer(address, address, uint256) internal virtual override {
        revert GovernanceWrapper_TransfersDisabled();
    }

    /// @dev Overrides internal `_mint` to always revert
    function _mint(address, uint256) internal virtual override {
        revert GovernanceWrapper_MintingDisabled();
    }

    /// @dev Overrides internal `_burn` to always revert
    function _burn(address, uint256) internal virtual override {
        revert GovernanceWrapper_BurningDisabled();
    }

    /// @dev Overrides internal `_approve` to always revert
    function _approve(address, address, uint256) internal virtual override {
        revert GovernanceWrapper_ApprovalsDisabled();
    }

    /// @dev Overrides internal `_delegate` to always revert
    function permit(address, address, uint256, uint256, uint8, bytes32, bytes32) public virtual override {
        revert GovernanceWrapper_PermitDisabled();
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 VIEW OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice ERC20 `name` override to match TrustBonding
    function name() public view override returns (string memory) {
        string memory tokenName = trustBonding.name();
        return string.concat("Gov ", tokenName);
    }

    /// @notice ERC20 `symbol` override to match TrustBonding
    function symbol() public view override returns (string memory) {
        string memory tokenSymbol = trustBonding.symbol();
        return string.concat("gov-", tokenSymbol);
    }

    /// @notice ERC20 `decimals` override to match TrustBonding
    function decimals() public view override returns (uint8) {
        return trustBonding.decimals();
    }

    /**
     * @notice ERC20 `totalSupply` override to match TrustBonding
     * @dev Represents the current total voting power in the system
     * @return The total supply
     */
    function totalSupply() public view virtual override(ERC20Upgradeable, IERC20Upgradeable) returns (uint256) {
        return trustBonding.totalSupply();
    }

    /**
     * @notice ERC20 `balanceOf` override to match TrustBonding
     * @dev Represents the current voting power of `account`
     * @param account The address of the account to get the balance for
     * @return The balance of the account
     */
    function balanceOf(address account)
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (uint256)
    {
        return trustBonding.balanceOf(account);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC6372 CLOCK OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Overrides to use blocknumber clock mode
     * @return The current block number as uint48
     */
    function clock() public view virtual returns (uint48) {
        return uint48(block.number);
    }

    /**
     * @notice Indicates that this contract uses blocknumber clock mode
     * @return A string indicating blocknumber mode
     */
    function CLOCK_MODE() public pure virtual returns (string memory) {
        return "mode=blocknumber";
    }

    /*//////////////////////////////////////////////////////////////
                        VotesERC20 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current voting power for `account`
     * @param account The address of the account to get the voting power for
     * @return The current voting power of the account
     */
    function getVotes(address account) public view virtual override returns (uint256) {
        return trustBonding.balanceOf(account);
    }

    /**
     * @notice Returns the past voting power for `account` at a specific block number
     * @param account The address of the account to get the voting power for
     * @param blockNumber The block number to get the voting power at
     * @return The voting power of the account at the specified block number
     */
    function getPastVotes(address account, uint256 blockNumber) public view override returns (uint256) {
        return trustBonding.balanceOfAt(account, blockNumber);
    }

    /**
     * @notice Returns the past total supply at a specific block number
     * @param blockNumber The block number to get the total supply at
     * @return The total supply at the specified block number
     */
    function getPastTotalSupply(uint256 blockNumber) public view override returns (uint256) {
        return trustBonding.totalSupplyAt(blockNumber);
    }

    /*//////////////////////////////////////////////////////////////
                          DELEGATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the delegatee for `account`
     * @param account The address of the account to get the delegatee for
     * @return The address of the delegatee
     */
    function delegates(address account) public view virtual override returns (address) {
        return _delegates[account];
    }

    /**
     * @notice Sets `msg.sender` as their own delegate
     * @dev The provided address parameter is ignored
     */
    function delegate(address) public virtual override {
        address oldDelegate = _delegates[msg.sender];
        _delegates[msg.sender] = msg.sender;
        emit DelegateChanged(msg.sender, oldDelegate, msg.sender);
    }

    /**
     * @notice Delegation by signature is disabled and always reverts
     */
    function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32) public virtual override {
        revert GovernanceWrapper_DelegationBySigDisabled();
    }
}
