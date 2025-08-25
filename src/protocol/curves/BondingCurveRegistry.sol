// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";
import { IBondingCurveRegistry } from "src/interfaces/IBondingCurveRegistry.sol";

/**
 * @title  BondingCurveRegistry
 * @author 0xIntuition
 * @notice Registry contract for the Intuition protocol Bonding Curves. Routes access to the curves
 *         associated with atoms & triples.  Does not maintain any economic state -- this merely
 *         performs computations based on the provided economic state.
 * @notice An administrator may add new bonding curves to this registry, including those submitted
 *         by community members, once they are verified to be safe, and conform to the BaseCurve
 *         interface.  The MultiVault supports a growing registry of curves, with each curve
 *         supplying a new "vault" for each term (atom or triple).
 * @dev    The registry is responsible for interacting with the curves, to fetch the mathematical
 *         computations given the provided economic state and the desired curve implementation.
 *         You can think of the registry as a concierge the MultiVault uses to access various
 *         economic incentive patterns.
 */
contract BondingCurveRegistry is IBondingCurveRegistry, Ownable2Step {
    /* =================================================== */
    /*                      ERRORS                         */
    /* =================================================== */

    error BondingCurveRegistry_ZeroAddress();
    error BondingCurveRegistry_CurveAlreadyExists();
    error BondingCurveRegistry_EmptyCurveName();
    error BondingCurveRegistry_CurveNameNotUnique();

    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice Quantity of known curves, used to assign IDs
    uint256 public count;

    /// @notice Mapping of curve IDs to curve addresses, used for lookup
    mapping(uint256 => address) public curveAddresses;

    /// @notice Mapping of curve addresses to curve IDs, for reverse lookup
    mapping(address => uint256) public curveIds;

    /// @notice Mapping of the registered curve names, used to enforce uniqueness
    mapping(string => bool) public registeredCurveNames;

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /// @notice Constructor for the BondingCurveRegistry contract
    /// @param _admin Address who may add curves to the registry
    constructor(address _admin) Ownable(_admin) { }

    /* =================================================== */
    /*              ACCESS-RESTRICTED FUNCTIONS            */
    /* =================================================== */

    /// @notice Add a new bonding curve to the registry
    /// @param bondingCurve Address of the new bonding curve
    function addBondingCurve(address bondingCurve) external onlyOwner {
        if (bondingCurve == address(0)) {
            revert BondingCurveRegistry_ZeroAddress();
        }

        // Ensure curve is not already registered
        if (curveIds[bondingCurve] != 0) {
            revert BondingCurveRegistry_CurveAlreadyExists();
        }

        string memory curveName = IBaseCurve(bondingCurve).name();

        // Ensure the curve name is not empty
        if (bytes(curveName).length == 0) {
            revert BondingCurveRegistry_EmptyCurveName();
        }

        // Enforce curve name uniqueness
        if (registeredCurveNames[curveName]) {
            revert BondingCurveRegistry_CurveNameNotUnique();
        }

        // 0 is reserved to safeguard against uninitialized values
        ++count;

        // Add the curve to the registry, keeping track of its address and ID in separate tables
        curveAddresses[count] = bondingCurve;
        curveIds[bondingCurve] = count;

        // Mark the curve name as registered
        registeredCurveNames[curveName] = true;

        emit BondingCurveAdded(count, bondingCurve, curveName);
    }

    /* =================================================== */
    /*                VIEW FUNCTIONS                       */
    /* =================================================== */

    /// @notice Preview how many shares would be minted for a deposit of assets
    /// @param assets Quantity of assets to deposit
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param id Curve ID to use for the calculation
    /// @return shares The number of shares that would be minted
    function previewDeposit(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares,
        uint256 id
    )
        external
        view
        returns (uint256 shares)
    {
        return IBaseCurve(curveAddresses[id]).previewDeposit(assets, totalAssets, totalShares);
    }

    /// @notice Preview how many assets would be returned for burning a specific amount of shares
    /// @param shares Quantity of shares to burn
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param id Curve ID to use for the calculation
    /// @return assets The number of assets that would be returned
    function previewRedeem(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets,
        uint256 id
    )
        external
        view
        returns (uint256 assets)
    {
        return IBaseCurve(curveAddresses[id]).previewRedeem(shares, totalShares, totalAssets);
    }

    /// @notice Preview how many shares would be redeemed for a withdrawal of assets
    /// @param assets Quantity of assets to withdraw
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param id Curve ID to use for the calculation
    /// @return shares The number of shares that would need to be redeemed
    function previewWithdraw(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares,
        uint256 id
    )
        external
        view
        returns (uint256 shares)
    {
        return IBaseCurve(curveAddresses[id]).previewWithdraw(assets, totalAssets, totalShares);
    }

    /// @notice Preview how many assets would be required to mint a specific amount of shares
    /// @param shares Quantity of shares to mint
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param id Curve ID to use for the calculation
    /// @return assets The number of assets that would be required to mint the shares
    function previewMint(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets,
        uint256 id
    )
        external
        view
        returns (uint256 assets)
    {
        return IBaseCurve(curveAddresses[id]).previewMint(shares, totalShares, totalAssets);
    }

    /// @notice Convert assets to shares at a specific point on the curve
    /// @param assets Quantity of assets to convert to shares
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param id Curve ID to use for the calculation
    /// @return shares The number of shares equivalent to the given assets
    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares,
        uint256 id
    )
        external
        view
        returns (uint256 shares)
    {
        return IBaseCurve(curveAddresses[id]).convertToShares(assets, totalAssets, totalShares);
    }

    /// @notice Convert shares to assets at a specific point on the curve
    /// @param shares Quantity of shares to convert to assets
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param id Curve ID to use for the calculation
    /// @return assets The number of assets equivalent to the given shares
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets,
        uint256 id
    )
        external
        view
        returns (uint256 assets)
    {
        return IBaseCurve(curveAddresses[id]).convertToAssets(shares, totalShares, totalAssets);
    }

    /// @notice Get the current price of a share
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param id Curve ID to use for the calculation
    /// @return sharePrice The current price of a share
    function currentPrice(uint256 totalShares, uint256 id) external view returns (uint256 sharePrice) {
        return IBaseCurve(curveAddresses[id]).currentPrice(totalShares);
    }

    /// @notice Get the name of a curve
    /// @param id Curve ID to query
    /// @return name The name of the curve
    function getCurveName(uint256 id) external view returns (string memory name) {
        return IBaseCurve(curveAddresses[id]).name();
    }

    /// @notice Get the maximum number of shares a curve can handle.  Curves compute this ceiling based on their
    /// constructor arguments, to avoid overflow.
    /// @param id Curve ID to query
    /// @return maxShares The maximum number of shares
    function getCurveMaxShares(uint256 id) external view returns (uint256 maxShares) {
        return IBaseCurve(curveAddresses[id]).maxShares();
    }

    /// @notice Get the maximum number of assets a curve can handle.  Curves compute this ceiling based on their
    /// constructor arguments, to avoid overflow.
    /// @param id Curve ID to query
    /// @return maxAssets The maximum number of assets
    function getCurveMaxAssets(uint256 id) external view returns (uint256 maxAssets) {
        return IBaseCurve(curveAddresses[id]).maxAssets();
    }
}
