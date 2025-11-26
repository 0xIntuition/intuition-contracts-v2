// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IGovernanceWrapper } from "src/interfaces/IGovernanceWrapper.sol";
import { IVotesERC20V1 } from "src/interfaces/external/decent/IVotesERC20V1.sol";
import { VotingEscrow } from "src/external/curve/VotingEscrow.sol";

/**
 * @title GovernanceWrapper
 * @author 0xIntuition
 * @notice A wrapper contract around TrustBonding to conform to the IVotesERC20V1 interface
 */
contract GovernanceWrapper is Initializable, OwnableUpgradeable, IVotesERC20V1, IGovernanceWrapper {
    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The TrustBonding contract that this GovernanceWrapper interacts with
    VotingEscrow public trustBonding;

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
    function initialize(address _owner) external initializer {
        if (_owner == address(0)) {
            revert GovernanceWrapper_InvalidAddress();
        }
        __Ownable_init(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGovernanceWrapper
    function setTrustBonding(address _trustBonding) external onlyOwner {
        if (_trustBonding == address(0)) {
            revert GovernanceWrapper_InvalidAddress();
        }
        trustBonding = VotingEscrow(_trustBonding);
    }

    /*//////////////////////////////////////////////////////////////
                           IERC20VotesV1 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotesERC20V1
    function initialize(
        Metadata calldata metadata_,
        Allocation[] calldata allocations_,
        address owner_,
        bool locked_,
        uint256 maxTotalSupply_
    )
        external
    {
        revert GovernanceWrapper_CannotInitializeVotesERC20V1();
    }

    /// @inheritdoc IVotesERC20V1
    function CLOCK_MODE() external pure returns (string memory clockMode) {
        return "mode=timestamp";
    }

    /// @inheritdoc IVotesERC20V1
    function clock() external view returns (uint48 clock) {
        return uint48(block.timestamp);
    }

    /// @inheritdoc IVotesERC20V1
    function locked() external view returns (bool isLocked) {
        return true;
    }

    /// @inheritdoc IVotesERC20V1
    function mintingRenounced() external view returns (bool isMintingRenounced) {
        return true;
    }

    /// @inheritdoc IVotesERC20V1
    function maxTotalSupply() external view returns (uint256 maxTotalSupply) {
        return trustBonding.totalSupply();
    }

    /// @inheritdoc IVotesERC20V1
    function getUnlockTime() external view returns (uint48 unlockTime) {
        return 0;
    }

    /// @inheritdoc IVotesERC20V1
    function lock(bool locked_) external {
        revert GovernanceWrapper_CannotChangeLockStatus();
    }

    /// @inheritdoc IVotesERC20V1
    function renounceMinting() external {
        revert GovernanceWrapper_CannotRenounceMinting();
    }

    /// @inheritdoc IVotesERC20V1
    function setMaxTotalSupply(uint256 newMaxTotalSupply_) external {
        revert GovernanceWrapper_CannotOverrideMaxTotalSupply();
    }

    /// @inheritdoc IVotesERC20V1
    function mint(address to_, uint256 amount_) external {
        revert GovernanceWrapper_MintingIsNotAllowed();
    }

    /// @inheritdoc IVotesERC20V1
    function burn(uint256 amount_) external {
        revert GovernanceWrapper_BurningIsNotAllowed();
    }
}
