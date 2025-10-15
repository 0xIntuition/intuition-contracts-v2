// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IBaseCurve } from "src/interfaces/IBaseCurve.sol";

/**
 * @title  BaseCurve
 * @author 0xIntuition
 * @notice Abstract contract for a bonding curve. Defines the interface for converting assets to shares and vice versa.
 * @dev This contract is designed to be inherited by other bonding curve contracts, providing a common interface for
 *      converting between assets and shares.
 * @dev These curves handle the pure mathematical relationship for share price. Pool ratio adjustments (such as
 *      accommodating for the effect of fees, supply burn, airdrops, etc) are handled by the MultiVault instead
 *      of the curves themselves.
 */
abstract contract BaseCurve is IBaseCurve, Initializable {
    /* =================================================== */
    /*                  STATE VARIABLES                    */
    /* =================================================== */

    /// @notice The name of the curve
    string public name;
    
    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */
    error BaseCurve_EmptyStringNotAllowed();
    error BaseCurve_AssetsExceedTotalAssets();
    error BaseCurve_SharesExceedTotalShares();
    error BaseCurve_AssetsOverflowMax();
    error BaseCurve_SharesOverflowMax();

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                    INITIALIZER                      */
    /* =================================================== */

    /// @notice Initialize the curve with a unique name
    /// @param _name Unique name for the curve
    function __BaseCurve_init(string memory _name) internal onlyInitializing {
        if (bytes(_name).length == 0) {
            revert BaseCurve_EmptyStringNotAllowed();
        }

        name = _name;

        emit CurveNameSet(_name);
    }

    /// @notice The maximum number of shares that this curve can handle without overflowing.
    /// @dev Checked by the MultiVault before transacting
    function maxShares() external view virtual returns (uint256);

    /// @notice The maximum number of assets that this curve can handle without overflowing.
    /// @dev Checked by the MultiVault before transacting
    function maxAssets() external view virtual returns (uint256);

    /// @notice Preview how many shares would be minted for a deposit of assets
    ///
    /// @param assets Quantity of assets to deposit
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @return shares The number of shares that would be minted
    function previewDeposit(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        view
        virtual
        returns (uint256 shares);

    /// @notice Preview how many assets would be required to mint a specific amount of shares
    ///
    /// @param shares Quantity of shares to mint
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @return assets The number of assets that would be required to mint the shares
    function previewMint(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        virtual
        returns (uint256 assets);

    /// @notice Preview how many shares would be redeemed for a withdrawal of assets
    ///
    /// @param assets Quantity of assets to withdraw
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @return shares The number of shares that would need to be redeemed
    function previewWithdraw(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        view
        virtual
        returns (uint256 shares);

    /// @notice Preview how many assets would be returned for burning a specific amount of shares
    ///
    /// @param shares Quantity of shares to burn
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @return assets The number of assets that would be returned
    function previewRedeem(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        virtual
        returns (uint256 assets);

    /// @notice Convert assets to shares at a specific point on the curve
    ///
    /// @param assets Quantity of assets to convert to shares
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @return shares The number of shares equivalent to the given assets
    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        view
        virtual
        returns (uint256 shares);

    /// @notice Convert shares to assets at a specific point on the curve
    ///
    /// @param shares Quantity of shares to convert to assets
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @return assets The number of assets equivalent to the given shares
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        virtual
        returns (uint256 assets);

    /// @notice Get the current price of a share
    ///
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @return sharePrice The current price of a share, scaled by 1e18
    function currentPrice(uint256 totalShares, uint256 totalAssets) public view virtual returns (uint256 sharePrice);

    /* =================================================== */
    /*                  INTERNAL FUNCTIONS                 */
    /* =================================================== */

    // previewWithdraw(): assets <= totalAssets
    function _checkWithdraw(uint256 assets, uint256 totalAssets) internal pure {
        if (assets > totalAssets) revert BaseCurve_AssetsExceedTotalAssets();
    }

    // previewRedeem()/convertToAssets(): shares <= totalShares
    function _checkRedeem(uint256 shares, uint256 totalShares) internal pure {
        if (shares > totalShares) revert BaseCurve_SharesExceedTotalShares();
    }

    // previewDeposit()/convertToShares(): assets + totalAssets <= maxAssets
    function _checkDepositBounds(uint256 assets, uint256 totalAssets, uint256 maxAssets) internal pure {
        // Use subtraction to avoid potential overflow on (assets + totalAssets)
        if (assets > maxAssets - totalAssets) revert BaseCurve_AssetsOverflowMax();
    }

    // previewDeposit()/convertToShares(): (sharesOut) + totalShares <= maxShares
    function _checkDepositOut(uint256 sharesOut, uint256 totalShares, uint256 maxShares) internal pure {
        if (sharesOut > maxShares - totalShares) revert BaseCurve_SharesOverflowMax();
    }

    // previewMint(): shares + totalShares <= maxShares
    function _checkMintBounds(uint256 shares, uint256 totalShares, uint256 maxShares) internal pure {
        if (shares > maxShares - totalShares) revert BaseCurve_SharesOverflowMax();
    }

    // previewMint(): (assetsOut) + totalAssets <= maxAssets
    function _checkMintOut(uint256 assetsOut, uint256 totalAssets, uint256 maxAssets) internal pure {
        if (assetsOut > maxAssets - totalAssets) revert BaseCurve_AssetsOverflowMax();
    }
}
