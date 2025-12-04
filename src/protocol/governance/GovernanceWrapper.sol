// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { IGovernanceWrapper } from "src/interfaces/IGovernanceWrapper.sol";
import { ITrustBonding } from "src/interfaces/ITrustBonding.sol";
import { VotesERC20V1 } from "src/external/decent/VotesERC20V1.sol";
import { VotingEscrow } from "src/external/curve/VotingEscrow.sol";

/**
 * @title GovernanceWrapper
 * @author 0xIntuition
 * @notice A wrapper contract around TrustBonding to conform to the IVotesERC20V1 interface
 */
contract GovernanceWrapper is IGovernanceWrapper, VotesERC20V1 {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The TrustBonding contract that this GovernanceWrapper interacts with
    VotingEscrow public trustBonding;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGovernanceWrapper
    function setTrustBonding(address _trustBonding) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTrustBonding(_trustBonding);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to set the TrustBonding contract address
     * @param _trustBonding The address of the TrustBonding contract
     */
    function _setTrustBonding(address _trustBonding) internal {
        if (_trustBonding == address(0)) {
            revert GovernanceWrapper_InvalidAddress();
        }
        trustBonding = VotingEscrow(_trustBonding);
        emit TrustBondingSet(_trustBonding);
    }

    /*//////////////////////////////////////////////////////////////
                        VotesERC20V1 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function totalSupply() public view override returns (uint256) {
        // veTRUST total voting power
        return trustBonding.totalSupply();
    }

    function balanceOf(address account) public view override returns (uint256) {
        // current veTRUST voting power
        return trustBonding.balanceOf(account);
    }

    /* --------- IVotes views => delegate to TrustBonding / VotingEscrow --------- */

    function getVotes(address account) public view override returns (uint256) {
        return trustBonding.balanceOf(account);
    }

    function getPastVotes(address account, uint256 timepoint) public view override returns (uint256) {
        // timepoint is timestamp because CLOCK_MODE() = "mode=timestamp"
        return trustBonding.balanceOfAtT(account, timepoint);
    }

    function getPastTotalSupply(uint256 timepoint) public view override returns (uint256) {
        return trustBonding.totalSupplyAtT(timepoint);
    }

    function mint(address, uint256) public override {
        revert MintingDisabled();
    }

    function burn(uint256) public override {
        revert GovernanceWrapper_BurningDisabled();
    }

    // optional but recommended: nuke real transfers/minting
    function _update(address from, address to, uint256 value)
        internal
        override
        // override(ERC20Upgradeable, ERC20VotesUpgradeable)

    {
        // you can be stricter if you want, but this keeps the token effectively “shadow-only”
        if (from != address(0) || to != address(0) || value != 0) {
            revert IsLocked(); // already defined in the interface
        }
    }

    /// Debugging trials

    function governanceToken() external view returns (address) {
        return address(this);
    }

    function token() external view returns (address) {
        return address(this);
    }
}
