// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

/**
 * @title  LinearCurve
 * @author 0xIntuition
 * @notice The price mechanism relies on fee accumulation rather than supply-based pricing.
 *         As fees are collected, they are distributed proportionally across all shareholders,
 *         creating gradual appreciation in share value. This provides a conservative
 *         incentivization model where early participants benefit from fee accumulation
 *         over time.
 *
 * @notice This implementation offers a low-volatility approach to value accrual,
 *         suitable for scenarios where predictable, steady returns are preferred
 *         over dynamic pricing mechanisms.
 */
contract LinearCurve is BaseCurve {
    using FixedPointMathLib for uint256;

    /// @dev Maximum number of shares that can be handled by the curve.
    uint256 public constant MAX_SHARES = type(uint256).max;

    /// @dev Maximum number of assets that can be handled by the curve.
    uint256 public constant MAX_ASSETS = type(uint256).max;

    /// @dev Represents one share in 18 decimal format
    uint256 public constant ONE_SHARE = 1e18;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the new Linear Curve.
    /// @param _name The name of the curve.
    function initialize(string calldata _name) external initializer {
        __BaseCurve_init(_name);
    }

    /// @inheritdoc BaseCurve
    function previewDeposit(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        _checkDepositBounds(assets, totalAssets, MAX_ASSETS);
        shares = _convertToShares(assets, totalAssets, totalShares);
        _checkDepositOut(shares, totalShares, MAX_SHARES);
    }

    /// @inheritdoc BaseCurve
    function previewMint(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        pure
        override
        returns (uint256 assets)
    {
        _checkMintBounds(shares, totalShares, MAX_SHARES);
        assets = totalShares == 0 ? shares : shares.mulDivUp(totalAssets, totalShares);
        _checkMintOut(assets, totalAssets, MAX_ASSETS);
    }

    /// @inheritdoc BaseCurve
    function previewWithdraw(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        _checkWithdraw(assets, totalAssets);
        shares = totalShares == 0 ? assets : assets.mulDivUp(totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function previewRedeem(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        pure
        override
        returns (uint256 assets)
    {
        _checkRedeem(shares, totalShares);
        assets = _convertToAssets(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        public
        pure
        override
        returns (uint256 shares)
    {
        _checkDepositBounds(assets, totalAssets, MAX_ASSETS);
        shares = _convertToShares(assets, totalAssets, totalShares);
        _checkDepositOut(shares, totalShares, MAX_SHARES);
    }

    /// @inheritdoc BaseCurve
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        public
        pure
        override
        returns (uint256 assets)
    {
        _checkRedeem(shares, totalShares);
        assets = _convertToAssets(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function currentPrice(
        uint256 totalShares,
        uint256 totalAssets
    )
        public
        pure
        override
        returns (uint256 sharePrice)
    {
        // Price of 1 whole share (1e18) under the linear curve
        return _convertToAssets(ONE_SHARE, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    function maxShares() external pure override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() external pure override returns (uint256) {
        return MAX_ASSETS;
    }

    /// @dev Internal function to convert assets to shares without checks.
    function _convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        internal
        pure
        returns (uint256 shares)
    {
        uint256 supply = totalShares;
        shares = supply == 0 ? assets : assets.mulDiv(supply, totalAssets);
    }

    /// @dev Internal function to convert shares to assets without checks.
    function _convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        internal
        pure
        returns (uint256 assets)
    {
        uint256 supply = totalShares;
        assets = supply == 0 ? shares : shares.mulDiv(totalAssets, supply);
    }
}
