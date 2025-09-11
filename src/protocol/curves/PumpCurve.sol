// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { BaseCurve } from "src/protocol/curves/BaseCurve.sol";

/**
 * @title  PumpCurve
 * @author 0xIntuition
 * @notice Implementation of Pump.fun's bonding curve mechanism adapted for TRUST tokens.
 *         This curve implements the mathematical formula used by Pump.fun:
 *         $y = 1,073,000,191 - \frac{32,190,005,730}{30 + x}$
 *         where:
 *         - $x$ represents the amount of TRUST tokens (assets) purchased
 *         - $y$ represents the number of project tokens (shares) obtained
 *
 * @notice This version uses internal scaling to accept up to 1 billion TRUST while
 *         preserving the original curve's price characteristics. External amounts
 *         are scaled down by 100,000x internally for calculations, then scaled back up.
 *
 * @notice Key characteristics (adapted for 18 decimals):
 *         - Maximum external TRUST: 1,000,000,000 (1 billion) with 18 decimals
 *         - Internal calculation range: 10,000 TRUST (original range)
 *         - Scaling factor: 100,000x
 *         - Token supply scaled proportionally to maintain price curve
 *
 * @dev This implementation adapts Pump.fun's pricing mechanism to work with the
 *      BaseCurve interface, treating TRUST as assets and project tokens as shares.
 *      Both TRUST and project tokens use 18 decimal precision.
 */
contract PumpCurve is BaseCurve {
    using FixedPointMathLib for uint256;

    /// @dev Scaling factor: maps 1 billion external to 10,000 internal (100,000x)
    uint256 public constant SCALING_FACTOR = 100_000;

    /// @dev Virtual token reserves constant (1,073,000,191 tokens with 18 decimals)
    uint256 public constant VIRTUAL_TOKEN_RESERVES = 1_073_000_191 * 1e18;

    /// @dev Virtual TRUST reserves constant for internal calculations (3,488 TRUST with 18 decimals)
    uint256 public constant VIRTUAL_TRUST_RESERVES_INTERNAL = 3488 * 1e18;

    /// @dev Numerator constant for the bonding curve formula (scaled for 18 decimals)
    uint256 public constant CURVE_NUMERATOR = 32_190_005_730 * 1e18 * 1e18;

    /// @dev Maximum number of tokens available through bonding curve (800M tokens, no external scaling)
    uint256 public constant MAX_SHARES = 800_000_000 * 1e18; // 800 million tokens

    /// @dev Maximum TRUST that can be invested (1 billion TRUST external)
    uint256 public constant MAX_ASSETS = 1_000_000_000 * 1e18; // 1 billion TRUST with 18 decimals

    /// @dev Maximum internal TRUST for calculations (10,000 TRUST)
    uint256 public constant MAX_ASSETS_INTERNAL = 10_000 * 1e18;

    /// @dev Tokens reserved for DEX liquidity (206.9M tokens)
    uint256 public constant RESERVED_TOKENS = 206_900_000 * 1e18; // 206.9 million tokens

    /// @dev Initial real token reserves (793.1M tokens)
    uint256 public constant INITIAL_REAL_TOKEN_RESERVES = 793_100_000 * 1e18; // 793.1 million tokens

    /// @notice Constructor for the Pump Curve.
    /// @param _name The name of the curve.
    constructor(string memory _name) BaseCurve(_name) { }

    /// @inheritdoc BaseCurve
    /// @notice Calculates tokens received for a given TRUST deposit using Pump.fun's formula.
    function previewDeposit(
        uint256 assets,
        uint256 totalAssets,
        uint256 /* totalShares */
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        // Ensure we don't exceed max assets
        require(totalAssets + assets <= MAX_ASSETS, "Exceeds max assets");

        // Scale down external amounts for internal calculation
        uint256 assetsInternal = _scaleDown(assets);
        uint256 totalAssetsInternal = _scaleDown(totalAssets);

        // If both scale to 0, handle minimum amounts
        if (assetsInternal == 0 && assets > 0) {
            assetsInternal = 1; // Minimum internal unit
        }

        // Calculate tokens for incremental purchase
        uint256 tokensBefore = _calculateTokensFromFormula(totalAssetsInternal);
        uint256 tokensAfter = _calculateTokensFromFormula(totalAssetsInternal + assetsInternal);

        // Get the difference (tokens decrease as TRUST increases)
        uint256 internalShares = tokensBefore > tokensAfter ? tokensBefore - tokensAfter : 0;

        // No scaling for tokens - return internal calculation directly
        return internalShares;
    }

    /// @inheritdoc BaseCurve
    /// @notice Calculates TRUST required to mint a specific number of tokens.
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
        require(totalShares + shares <= MAX_SHARES, "Exceeds max shares");

        // Scale down total assets for internal calculation
        uint256 totalAssetsInternal = _scaleDown(totalAssets);

        // Calculate the TRUST amount needed to reach the target token supply
        uint256 targetTokens = totalShares + shares;

        // Use inverse of the bonding curve formula to find required TRUST
        uint256 requiredTrustInternal = _calculateTrustFromTokens(VIRTUAL_TOKEN_RESERVES - targetTokens);

        uint256 trustNeededInternal =
            requiredTrustInternal > totalAssetsInternal ? requiredTrustInternal - totalAssetsInternal : 0;

        // Scale up the result
        return _scaleUp(trustNeededInternal);
    }

    /// @inheritdoc BaseCurve
    /// @notice Calculates tokens to burn for a given TRUST withdrawal.
    function previewWithdraw(
        uint256 assets,
        uint256 totalAssets,
        uint256 /* totalShares */
    )
        external
        pure
        override
        returns (uint256 shares)
    {
        require(assets <= totalAssets, "Insufficient assets");

        // Scale down for internal calculations
        uint256 assetsInternal = _scaleDown(assets);
        uint256 totalAssetsInternal = _scaleDown(totalAssets);

        // Handle minimum amounts
        if (assetsInternal == 0 && assets > 0) {
            assetsInternal = 1;
        }

        // Calculate how many tokens need to be burned to get the desired TRUST
        uint256 newTotalAssetsInternal = totalAssetsInternal > assetsInternal ? totalAssetsInternal - assetsInternal : 0;
        uint256 tokensAfter = _calculateTokensFromFormula(newTotalAssetsInternal);
        uint256 tokensBefore = _calculateTokensFromFormula(totalAssetsInternal);

        // Return the token difference (tokens increase when TRUST is withdrawn)
        return tokensAfter > tokensBefore ? tokensAfter - tokensBefore : 0;
    }

    /// @inheritdoc BaseCurve
    /// @notice Calculates TRUST received for redeeming a specific number of tokens.
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
        require(shares <= totalShares, "Insufficient shares");

        // Scale down total assets for internal calculation
        uint256 totalAssetsInternal = _scaleDown(totalAssets);

        // Calculate TRUST received for burning tokens
        uint256 newTotalShares = totalShares - shares;
        uint256 trustAfterInternal = _calculateTrustFromTokens(VIRTUAL_TOKEN_RESERVES - newTotalShares);

        uint256 assetsInternal = trustAfterInternal > totalAssetsInternal ? trustAfterInternal - totalAssetsInternal : 0;

        // Scale up the result
        return _scaleUp(assetsInternal);
    }

    /// @inheritdoc BaseCurve
    /// @notice Standard conversion function (uses bonding curve logic).
    function convertToShares(
        uint256 assets,
        uint256 totalAssets,
        uint256 totalShares
    )
        public
        view
        override
        returns (uint256 shares)
    {
        return this.previewDeposit(assets, totalAssets, totalShares);
    }

    /// @inheritdoc BaseCurve
    /// @notice Standard conversion function (uses bonding curve logic).
    function convertToAssets(
        uint256 shares,
        uint256 totalShares,
        uint256 totalAssets
    )
        public
        view
        override
        returns (uint256 assets)
    {
        return this.previewRedeem(shares, totalShares, totalAssets);
    }

    /// @inheritdoc BaseCurve
    /// @notice Returns the current price per token based on total supply.
    function currentPrice(uint256 totalShares) public pure override returns (uint256 sharePrice) {
        if (totalShares == 0) {
            // Initial price calculation
            return _calculateInitialPrice();
        }

        // Ensure we don't exceed virtual reserves
        if (totalShares >= VIRTUAL_TOKEN_RESERVES) {
            return 0;
        }

        // Calculate marginal price based on current supply
        uint256 remainingTokens = VIRTUAL_TOKEN_RESERVES - totalShares;
        uint256 currentTrustInternal = _calculateTrustFromTokens(remainingTokens);

        // Calculate price for next token (1 token with 18 decimals)
        uint256 nextRemainingTokens = remainingTokens > 1e18 ? remainingTokens - 1e18 : 0;
        uint256 nextTokenTrustInternal = _calculateTrustFromTokens(nextRemainingTokens);

        // Get the price difference and scale up
        uint256 internalPrice =
            nextTokenTrustInternal > currentTrustInternal ? nextTokenTrustInternal - currentTrustInternal : 0;

        // Scale up the price from internal to external
        return _scaleUp(internalPrice);
    }

    /// @inheritdoc BaseCurve
    function maxShares() external pure override returns (uint256) {
        return MAX_SHARES;
    }

    /// @inheritdoc BaseCurve
    function maxAssets() external pure override returns (uint256) {
        return MAX_ASSETS;
    }

    /// @notice Calculates bonding curve progress percentage.
    /// @param totalShares Current number of tokens in circulation.
    /// @return progress Percentage completion of the bonding curve (0-100).
    function bondingCurveProgress(uint256 totalShares) external pure returns (uint256 progress) {
        if (totalShares >= INITIAL_REAL_TOKEN_RESERVES) {
            return 100;
        }
        return (totalShares * 100) / INITIAL_REAL_TOKEN_RESERVES;
    }

    /// @notice Checks if the bonding curve is complete.
    /// @param totalShares Current number of tokens in circulation.
    /// @return complete True if all tokens have been sold through the curve.
    function isCurveComplete(uint256 totalShares) external pure returns (bool complete) {
        return totalShares >= INITIAL_REAL_TOKEN_RESERVES;
    }

    /// @dev Scales down external TRUST amount to internal range.
    /// @param externalAmount Amount in external scale (up to 1 billion).
    /// @return internalAmount Amount in internal scale (up to 10,000).
    function _scaleDown(uint256 externalAmount) internal pure returns (uint256 internalAmount) {
        return externalAmount / SCALING_FACTOR;
    }

    /// @dev Scales up internal TRUST amount to external range.
    /// @param internalAmount Amount in internal scale (up to 10,000).
    /// @return externalAmount Amount in external scale (up to 1 billion).
    function _scaleUp(uint256 internalAmount) internal pure returns (uint256 externalAmount) {
        return internalAmount * SCALING_FACTOR;
    }

    /// @dev Internal function implementing Pump.fun's bonding curve formula.
    /// @param trustAmount Amount of TRUST input (in internal scale).
    /// @return tokens Number of tokens calculated from the formula (in internal scale).
    function _calculateTokensFromFormula(uint256 trustAmount) internal pure returns (uint256 tokens) {
        // Cap at max internal assets to prevent overflow
        if (trustAmount > MAX_ASSETS_INTERNAL) {
            trustAmount = MAX_ASSETS_INTERNAL;
        }

        // y = 1,073,000,191 - 32,190,005,730/(30 + x)
        // Where x is TRUST amount and y is tokens
        uint256 denominator = VIRTUAL_TRUST_RESERVES_INTERNAL + trustAmount;

        // Prevent division by zero
        if (denominator == 0) {
            return VIRTUAL_TOKEN_RESERVES;
        }

        uint256 fraction = CURVE_NUMERATOR / denominator;

        if (VIRTUAL_TOKEN_RESERVES > fraction) {
            return VIRTUAL_TOKEN_RESERVES - fraction;
        }
        return 0;
    }

    /// @dev Internal function to calculate TRUST from remaining tokens (inverse formula).
    /// @param remainingTokens Number of tokens remaining in the curve (in internal scale).
    /// @return trustAmount TRUST amount corresponding to the token level (in internal scale).
    function _calculateTrustFromTokens(uint256 remainingTokens) internal pure returns (uint256 trustAmount) {
        // Solve for x: y = 1,073,000,191 - 32,190,005,730/(30 + x)
        // Rearranged: x = 32,190,005,730/(1,073,000,191 - y) - 30
        if (remainingTokens >= VIRTUAL_TOKEN_RESERVES) {
            return 0;
        }

        uint256 difference = VIRTUAL_TOKEN_RESERVES - remainingTokens;

        // Prevent division by zero
        if (difference == 0) {
            return MAX_ASSETS_INTERNAL;
        }

        uint256 quotient = CURVE_NUMERATOR / difference;

        return quotient > VIRTUAL_TRUST_RESERVES_INTERNAL ? quotient - VIRTUAL_TRUST_RESERVES_INTERNAL : 0;
    }

    /// @dev Calculates the initial price per token.
    /// @return price Initial price per token in TRUST (in external scale).
    function _calculateInitialPrice() internal pure returns (uint256 price) {
        // Calculate the derivative at x=0 to get initial price
        // d/dx[1,073,000,191 - 32,190,005,730/(30 + x)] = 32,190,005,730/(30 + x)²
        uint256 denominator = VIRTUAL_TRUST_RESERVES_INTERNAL * VIRTUAL_TRUST_RESERVES_INTERNAL;
        uint256 internalPrice = CURVE_NUMERATOR / denominator;
        // Scale up to external price
        return _scaleUp(internalPrice);
    }
}
