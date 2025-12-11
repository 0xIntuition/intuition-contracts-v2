// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/**
 * @title CustomCurve
 * @notice Example implementation of a custom bonding curve for Intuition Protocol
 * @dev Implements IBaseCurve interface with a custom pricing mechanism
 *
 * This example demonstrates:
 * - Custom pricing logic (exponential curve)
 * - Parameter validation
 * - Safe math operations
 * - ERC4626-style conversions
 *
 * Curve formula: price = basePrice * (1 + growthRate * totalShares)
 *
 * @author 0xIntuition
 *
 * Usage:
 *   1. Deploy CustomCurve with desired parameters
 *   2. Register with BondingCurveRegistry
 *   3. Vaults can now use this curve ID
 *
 * Example:
 *   CustomCurve curve = new CustomCurve(
 *       "ExponentialCurve",
 *       1e18,      // basePrice: 1 WTRUST
 *       1e15,      // growthRate: 0.1% per share
 *       1e30,      // maxShares: 1 trillion
 *       1e36       // maxAssets: 1 million trillion
 *   );
 */

import "src/interfaces/IBaseCurve.sol";

contract CustomCurve is IBaseCurve {
    /* =================================================== */
    /*                    CONSTANTS                        */
    /* =================================================== */

    /// @notice Scaling factor for calculations (1e18)
    uint256 private constant SCALE = 1e18;

    /* =================================================== */
    /*                    IMMUTABLES                       */
    /* =================================================== */

    /// @notice Name of this curve
    string private immutable _name;

    /// @notice Base price per share (scaled by 1e18)
    uint256 private immutable basePrice;

    /// @notice Growth rate per share (scaled by 1e18)
    /// @dev Example: 1e15 = 0.1% growth per share
    uint256 private immutable growthRate;

    /// @notice Maximum shares this curve can handle
    uint256 private immutable _maxShares;

    /// @notice Maximum assets this curve can handle
    uint256 private immutable _maxAssets;

    /* =================================================== */
    /*                    CONSTRUCTOR                      */
    /* =================================================== */

    /**
     * @notice Initializes the custom curve with parameters
     * @param curveName Name identifier for this curve
     * @param _basePrice Initial price per share (scaled by 1e18)
     * @param _growthRate Growth rate per share (scaled by 1e18)
     * @param maxSharesLimit Maximum shares allowed
     * @param maxAssetsLimit Maximum assets allowed
     */
    constructor(
        string memory curveName,
        uint256 _basePrice,
        uint256 _growthRate,
        uint256 maxSharesLimit,
        uint256 maxAssetsLimit
    ) {
        if (bytes(curveName).length == 0) revert BaseCurve_EmptyStringNotAllowed();
        if (_basePrice == 0) revert BaseCurve_AssetsOverflowMax();
        if (maxSharesLimit == 0) revert BaseCurve_SharesOverflowMax();
        if (maxAssetsLimit == 0) revert BaseCurve_AssetsOverflowMax();

        _name = curveName;
        basePrice = _basePrice;
        growthRate = _growthRate;
        _maxShares = maxSharesLimit;
        _maxAssets = maxAssetsLimit;

        emit CurveNameSet(curveName);
    }

    /* =================================================== */
    /*                   VIEW FUNCTIONS                    */
    /* =================================================== */

    /// @inheritdoc IBaseCurve
    function name() external view override returns (string memory) {
        return _name;
    }

    /// @inheritdoc IBaseCurve
    function maxShares() external view override returns (uint256) {
        return _maxShares;
    }

    /// @inheritdoc IBaseCurve
    function maxAssets() external view override returns (uint256) {
        return _maxAssets;
    }

    /// @inheritdoc IBaseCurve
    function currentPrice(
        uint256 totalShares,
        uint256 /* totalAssets */
    )
        external
        view
        override
        returns (uint256 sharePrice)
    {
        // Price formula: basePrice * (1 + growthRate * totalShares)
        // This creates an exponential curve where price increases with supply
        return basePrice + (basePrice * growthRate * totalShares) / SCALE;
    }

    /* =================================================== */
    /*                 CONVERSION FUNCTIONS                */
    /* =================================================== */

    /// @inheritdoc IBaseCurve
    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        // Standard ERC4626 conversion
        if (totalShares == 0 || totalAssets == 0) {
            return assets;
        }
        return (assets * totalShares) / totalAssets;
    }

    /// @inheritdoc IBaseCurve
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        pure
        override
        returns (uint256 assets)
    {
        // Standard ERC4626 conversion
        if (totalShares == 0) {
            return shares;
        }
        return (shares * totalAssets) / totalShares;
    }

    /* =================================================== */
    /*                 PREVIEW FUNCTIONS                   */
    /* =================================================== */

    /// @inheritdoc IBaseCurve
    function previewDeposit(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        view
        override
        returns (uint256 shares)
    {
        // Validate inputs
        if (totalAssets + assets > _maxAssets) revert BaseCurve_AssetsOverflowMax();

        // Calculate shares using custom curve formula
        // For exponential curve: shares = assets / currentPrice
        uint256 price = basePrice + (basePrice * growthRate * totalShares) / SCALE;
        shares = (assets * SCALE) / price;

        // Validate output
        if (totalShares + shares > _maxShares) revert BaseCurve_SharesOverflowMax();

        return shares;
    }

    /// @inheritdoc IBaseCurve
    function previewMint(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        override
        returns (uint256 assets)
    {
        // Validate inputs
        if (totalShares + shares > _maxShares) revert BaseCurve_SharesOverflowMax();

        // Calculate required assets for desired shares
        uint256 price = basePrice + (basePrice * growthRate * totalShares) / SCALE;
        assets = (shares * price) / SCALE;

        // Validate output
        if (totalAssets + assets > _maxAssets) revert BaseCurve_AssetsOverflowMax();

        return assets;
    }

    /// @inheritdoc IBaseCurve
    function previewWithdraw(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        external
        view
        override
        returns (uint256 shares)
    {
        // Validate inputs
        if (assets > totalAssets) revert BaseCurve_AssetsExceedTotalAssets();

        // Calculate shares needed to withdraw desired assets
        // This is the inverse of previewMint
        uint256 price = basePrice + (basePrice * growthRate * totalShares) / SCALE;
        shares = (assets * SCALE) / price;

        // Validate output
        if (shares > totalShares) revert BaseCurve_SharesExceedTotalShares();

        return shares;
    }

    /// @inheritdoc IBaseCurve
    function previewRedeem(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        external
        view
        override
        returns (uint256 assets)
    {
        // Validate inputs
        if (shares > totalShares) revert BaseCurve_SharesExceedTotalShares();

        // Calculate assets returned for burning shares
        // Using current price at totalShares level
        uint256 price = basePrice + (basePrice * growthRate * totalShares) / SCALE;
        assets = (shares * price) / SCALE;

        // Validate output
        if (assets > totalAssets) revert BaseCurve_AssetsExceedTotalAssets();

        return assets;
    }
}

/**
 * @dev Example deployment and usage:
 *
 * 1. Deploy the curve:
 *    ```solidity
 *    CustomCurve exponentialCurve = new CustomCurve(
 *        "Exponential Growth Curve v1",
 *        1 ether,              // Base price: 1 WTRUST per share
 *        0.001 ether,          // Growth rate: 0.1% per share
 *        1_000_000 ether,      // Max 1M shares
 *        10_000_000 ether      // Max 10M assets
 *    );
 *    ```
 *
 * 2. Register with BondingCurveRegistry (requires admin):
 *    ```solidity
 *    BondingCurveRegistry registry = BondingCurveRegistry(registryAddress);
 *    registry.addCurve(address(exponentialCurve));
 *    ```
 *
 * 3. Create atom using this curve:
 *    ```solidity
 *    MultiVault vault = MultiVault(vaultAddress);
 *    uint256 customCurveId = 5; // ID assigned by registry
 *
 *    bytes[] memory atomDatas = new bytes[](1);
 *    atomDatas[0] = "My Custom Curve Atom";
 *
 *    uint256[] memory assets = new uint256[](1);
 *    assets[0] = 10 ether;
 *
 *    bytes32[] memory atomIds = vault.createAtoms(atomDatas, assets);
 *
 *    // Now deposit using the custom curve
 *    vault.deposit(msg.sender, atomIds[0], customCurveId, 0);
 *    ```
 *
 * 4. Query price at different supply levels:
 *    ```solidity
 *    uint256 priceAt0 = exponentialCurve.currentPrice(0, 0);
 *    // Returns: 1 ether (base price)
 *
 *    uint256 priceAt1000 = exponentialCurve.currentPrice(1000 ether, 0);
 *    // Returns: ~1.1 ether (base + 0.1% * 1000)
 *
 *    uint256 priceAt10000 = exponentialCurve.currentPrice(10000 ether, 0);
 *    // Returns: ~2 ether (base + 0.1% * 10000)
 *    ```
 */
