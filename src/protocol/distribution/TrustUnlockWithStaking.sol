// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// OpenZeppelin Imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Vesting Labs Imports
import { Errors } from "src/external/vesting-labs/libraries/Errors.sol";
import { ITypes } from "src/external/vesting-labs/interfaces/ITypes.sol";
import { NativeTokenVestingManager } from "src/external/vesting-labs/NativeTokenVestingManager.sol";
import { TokenVestingLib } from "src/external/vesting-labs/libraries/TokenVestingLib.sol";

// Intuition Imports
import { ITrustUnlockWithStaking } from "src/interfaces/ITrustUnlockWithStaking.sol";
import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { WrappedTrust } from "src/WrappedTrust.sol";

interface IDistributionRegistry {
    function trustToken() external view returns (address payable);

    function trustBonding() external view returns (address);

    function multiVault() external view returns (address payable);
}

/**
 * @title  TrustUnlockWithStaking
 * @author 0xIntuition
 * @notice Manages tokens that that are in a lockup period but are eligible for staking rewards.
 */
contract TrustUnlockWithStaking is ITrustUnlockWithStaking,NativeTokenVestingManager {
    using TokenVestingLib for TokenVestingLib.Vesting;

    bytes32 public constant ADMIN_VESTING_ID = bytes32(uint256(1));

    address public immutable REGISTRY;

    /// @notice Amount of native tokens bonded to the TrustBonding.
    uint256 public bondedAmount;


    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    error ZeroAddress();
    error InvalidMsgValue();
    error TrustUnlockWithStaking_InsufficientUnlockedTokens();

    /**
	 * @notice Initialize the native token vesting manager
     * @param registry_ - Address of the distribution registry
	 * @param fee_ - Fee amount for this contract
	 * @param feeCollector_ - Address of the fee collector
	 * @param fundingType_ - Type of funding for this contract (Full or Partial)
	 */
	constructor(
        address registry_,
		uint256 fee_,
		address feeCollector_,
		ITypes.FundingType fundingType_
	) NativeTokenVestingManager(fee_, feeCollector_, fundingType_) {
        if (registry_ == address(0)) {
            revert ZeroAddress();
        }
        REGISTRY = registry_;
	}

    /* =================================================== */
    /*                     MODIFIERS                       */
    /* =================================================== */
    modifier onlyNonLockedTokens(uint256 amount) {
        {
            (, uint256 vestedAmount, uint256 total) = this._getCurrentVestedAmount(ADMIN_VESTING_ID);
            if (address(this).balance < amount + total - vestedAmount) {
                revert TrustUnlockWithStaking_InsufficientUnlockedTokens();
            }
        }
        _;
    }

    /// @dev We require msg.value to be non-zero to prevent accidental calls that send native tokens.
    /// We only want to maintain interface compatibility with MultiVault's createAtoms function. 
    modifier restrictMsgValue() {
        if (msg.value != 0) {
            revert InvalidMsgValue();
        }
        _;
    }

    /* =================================================== */
    /*                      GETTERS                        */
    /* =================================================== */
    function trustToken() external view returns (address payable) {
        return _trustToken();
    }

    /// @notice Address of the TrustBonding contract
    function trustBonding() external view returns (address) {
        return _trustBonding();
    }

    /// @notice Address of the MultiVault contract
    function multiVault() external view returns (address payable) {
        return _multiVault();
    }

    /* =================================================== */
    /*                  TRUST BONDING                      */
    /* =================================================== */

    function create_lock(uint256 amount, uint256 unlockTime) external onlyVestingRecipient(ADMIN_VESTING_ID) {
        bondedAmount += amount;
        _wrapTrustTokens(amount);
        TrustBonding(_trustBonding()).create_lock(amount, unlockTime);
        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Increase the amount locked in an existing bonding lock
     * @param amount The amount of Trust tokens to add to the lock
     */
    function increase_amount(uint256 amount) external onlyVestingRecipient(ADMIN_VESTING_ID) {
        bondedAmount += amount;
        _wrapTrustTokens(amount);
        TrustBonding(_trustBonding()).increase_amount(amount);
        emit BondedAmountUpdated(bondedAmount);
    }

    /**
     * @notice Increase the unlock time of an existing bonding lock
     * @param newUnlockTime The new unlock time for the existing bonding lock
     * @dev The `newUnlockTime` gets rounded down to the nearest whole week
     */
    function increase_unlock_time(uint256 newUnlockTime) external onlyVestingRecipient(ADMIN_VESTING_ID) {
        TrustBonding(_trustBonding()).increase_unlock_time(newUnlockTime);
    }

    /// @notice Claim unlocked tokens back from TrustBonding to this contract
    function withdraw() external onlyVestingRecipient(ADMIN_VESTING_ID) {
        bondedAmount = 0;
        TrustBonding(_trustBonding()).withdraw();
        _unwrapTrustTokens(IERC20(_trustToken()).balanceOf(address(this)));
        emit BondedAmountUpdated(bondedAmount);
    }

    /* =================================================== */
    /*                    MULTIVAULT                       */
    /* =================================================== */
    /**
     * @notice Creates new atoms in the MultiVault contract
     * @param atoms An array of bytes containing the data for each atom to be created
     * @param assets The amount of Trust tokens to use for creating each atom
     * @return atomIds An array of IDs for the newly created atoms
     */
    function createAtoms(
        bytes[] calldata atoms,
        uint256[] calldata assets
    )
        external
        payable
        restrictMsgValue()
        onlyVestingRecipient(ADMIN_VESTING_ID)
        onlyNonLockedTokens(_sum(assets))
        returns (bytes32[] memory atomIds)
    {   
        atomIds = IMultiVault(_multiVault()).createAtoms{ value: _sum(assets) }(atoms, assets);
    }

    /**
     * @notice Creates new triples in the MultiVault contract
     * @param subjectIds An array of subject IDs for the triples
     * @param predicateIds An array of predicate IDs for the triples
     * @param objectIds An array of object IDs for the triples
     * @param assets The amount of Trust tokens to use for creating each triple
     * @return tripleIds An array of IDs for the newly created triples
     */
    function createTriples(
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets
    )
        external
        payable
        restrictMsgValue()
        onlyVestingRecipient(ADMIN_VESTING_ID)
        onlyNonLockedTokens(_sum(assets))
        returns (bytes32[] memory tripleIds)
    {
        tripleIds =
            IMultiVault(_multiVault()).createTriples{ value: _sum(assets) }(subjectIds, predicateIds, objectIds, assets);
    }

    function deposit(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 assets,
        uint256 minShares
    )
        external
        payable
        restrictMsgValue()
        onlyVestingRecipient(ADMIN_VESTING_ID)
        onlyNonLockedTokens(assets)
        returns (uint256 shares)
    {
        shares = IMultiVault(_multiVault()).deposit{ value: assets }(receiver, termId, curveId, minShares);
    }

    /**
     * @notice Batch deposits Trust tokens into the MultiVault contract and receives shares in return
     * @param receiver The address that will receive the shares
     * @param termIds An array of term IDs to deposit into
     * @param curveIds An array of bonding curve IDs to use for the deposits
     * @param assets An array of assets of Trust tokens to deposit for each term
     * @param minShares An array of minimum shares to receive in return for each deposit
     * @return shares An array of shares received in return for each deposit
     */
    function depositBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares
    )
        external
        payable
        restrictMsgValue()
        onlyVestingRecipient(ADMIN_VESTING_ID)
        onlyNonLockedTokens(_sum(assets))
        returns (uint256[] memory shares)
    {
        shares = IMultiVault(_multiVault()).depositBatch{ value: _sum(assets) }(receiver, termIds, curveIds, assets, minShares);
    }

    /**
     * @notice Redeems shares from the MultiVault contract and receives Trust tokens in return
     * @param receiver The address that will receive the withdrawn Trust tokens
     * @param termId The ID of the term to redeem from
     * @param curveId The ID of the bonding curve to use for the redemption
     * @param shares The number of shares to redeem
     * @param minAssets The minimum amount of Trust tokens to receive in return for the redemption
     * @return assets The amount of Trust tokens received in return for the redemption
     */
    function redeem(
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 shares,
        uint256 minAssets
    )
        external
        onlyVestingRecipient(ADMIN_VESTING_ID)
        returns (uint256 assets)
    {
        assets = IMultiVault(_multiVault()).redeem(receiver, termId, curveId, shares, minAssets);
    }

    /**
     * @notice Batch redeems shares from the MultiVault contract and receives Trust tokens in return
     * @param receiver The address that will receive the withdrawn Trust tokens
     * @param termIds An array of term IDs to redeem from
     * @param curveIds An array of bonding curve IDs to use for the redemptions
     * @param shares An array of numbers of shares to redeem
     * @param minAssets An array of minimum amounts of Trust tokens to receive in return for the redemptions
     * @return assets An array of amounts of Trust tokens received in return for the redemptions
     */
    function redeemBatch(
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata shares,
        uint256[] calldata minAssets
    )
        external
        onlyVestingRecipient(ADMIN_VESTING_ID)
        returns (uint256[] memory assets)
    {
        assets = IMultiVault(_multiVault()).redeemBatch(receiver, termIds, curveIds, shares, minAssets);
    }
    
    /* =================================================== */
    /*                     INTERNAL                        */
    /* =================================================== */
    function _trustToken() internal view returns (address payable) {
        return IDistributionRegistry(REGISTRY).trustToken();
    }

    /// @notice Address of the TrustBonding contract
    function _trustBonding() internal view returns (address) {
        return IDistributionRegistry(REGISTRY).trustBonding();
    }

    /// @notice Address of the MultiVault contract
    function _multiVault() internal view returns (address payable) {
        return IDistributionRegistry(REGISTRY).multiVault();
    }

    function _wrapTrustTokens(uint256 amount) internal {
        address payable _t = _trustToken();
        WrappedTrust(_t).deposit{ value: amount }();
        WrappedTrust(_t).approve(_trustBonding(), amount);
    }

    function _unwrapTrustTokens(uint256 amount) internal {
        WrappedTrust(_trustToken()).withdraw(amount);
    }

    /**
	 * @notice Get funding information for a vesting
	 * @param _vestingId - Identifier of the vesting
	 */
	function _getCurrentVestedAmount(
		bytes32 _vestingId
	)
		external
		view
		returns (uint256 vested, uint256 claimable, uint256 total)
	{
		TokenVestingLib.Vesting storage vesting = vestingById[_vestingId];
		if (vesting.recipient == address(0)) revert Errors.EmptyVesting();

        vested = vesting.calculateVestedAmount(uint32(block.timestamp));

		// Calculate claimable amount (vested - already claimed)
		claimable = vested > vesting.claimedAmount
			? vested - vesting.claimedAmount
			: 0;

        // Calculate total amount available at end of vesting.
        total =
			vesting.initialUnlock +
			vesting.cliffAmount +
			vesting.linearVestAmount;

		return (claimable, vested, total);
	}

    function _sum(uint256[] memory values) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < values.length; i++) {
            total += values[i];
        }
        return total;
    }
}