// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title IGovernanceWrapper
 * @author 0xIntuition
 * @notice Interface for the Intuition's GovernanceWrapper contract
 */
interface IGovernanceWrapper {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /**
     * @notice Emitted when the TrustBonding contract address is set
     * @param trustBonding The address of the new TrustBonding contract
     */
    event TrustBondingSet(address indexed trustBonding);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error GovernanceWrapper_InvalidAddress();

    error GovernanceWrapper_CannotInitializeVotesERC20V1();

    error GovernanceWrapper_CannotChangeLockStatus();

    error GovernanceWrapper_CannotRenounceMinting();

    error GovernanceWrapper_CannotOverrideMaxTotalSupply();

    error GovernanceWrapper_MintingIsNotAllowed();

    error GovernanceWrapper_BurningIsNotAllowed();

    /* =================================================== */
    /*                     FUNCTIONS                       */
    /* =================================================== */

    /**
     * @notice Initializes the GovernanceWrapper contract
     * @param _owner The initial owner of the GovernanceWrapper contract
     * @param _trustBonding The address of the TrustBonding contract
     */
    function initialize(address _owner, address _trustBonding) external;

    /**
     * @notice Sets the TrustBonding contract address
     * @param _trustBonding The address of the new TrustBonding contract
     */
    function setTrustBonding(address _trustBonding) external;
}
