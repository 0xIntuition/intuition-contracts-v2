// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/**
 * @title  IBaseCurve
 * @author 0xIntuition
 * @notice Interface for bonding curves in the Intuition protocol.
 *         All curves must implement these functions to be compatible with the protocol.
 */
interface IBaseCurve {
    /* =================================================== */
    /*                      EVENTS                         */
    /* =================================================== */

    /// @notice Emitted when the curve name is set
    /// @param name The unique name of the curve
    event CurveNameSet(string name);

    /* =================================================== */
    /*                      ERRORS                         */
    /* =================================================== */

    error BaseCurve_EmptyStringNotAllowed();
    error BaseCurve_AssetsExceedTotalAssets();
    error BaseCurve_SharesExceedTotalShares();
    error BaseCurve_AssetsOverflowMax();
    error BaseCurve_SharesOverflowMax();
    error BaseCurve_DomainExceeded();
    error BaseCurve_FeeHooksNotSupported();

    /* =================================================== */
    /*                    FUNCTIONS                       */
    /* =================================================== */

    /// @notice Get the name of the curve
    /// @return name The name of the curve
    function name() external view returns (string memory);

    /// @notice Get the maximum number of shares the curve can handle
    /// @return The maximum number of shares
    function maxShares() external view returns (uint256);

    /// @notice Get the maximum number of assets the curve can handle
    /// @return The maximum number of assets
    function maxAssets() external view returns (uint256);

    /// @notice Preview how many shares would be minted for a deposit of assets
    /// @param assets Quantity of assets to deposit
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @return shares The number of shares that would be minted
    function previewDeposit(uint256 assets, uint256 totalAssets, uint256 totalShares)
        external
        view
        returns (uint256 shares);

    /// @notice Preview how many assets would be returned for burning a specific amount of shares
    /// @param shares Quantity of shares to burn
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @return assets The number of assets that would be returned
    function previewRedeem(uint256 shares, uint256 totalShares, uint256 totalAssets)
        external
        view
        returns (uint256 assets);

    /// @notice Preview how many shares would be redeemed for a withdrawal of assets
    /// @param assets Quantity of assets to withdraw
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @return shares The number of shares that would need to be redeemed
    function previewWithdraw(uint256 assets, uint256 totalAssets, uint256 totalShares)
        external
        view
        returns (uint256 shares);

    /// @notice Preview how many assets would be required to mint a specific amount of shares
    /// @param shares Quantity of shares to mint
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @return assets The number of assets that would be required to mint the shares
    function previewMint(uint256 shares, uint256 totalShares, uint256 totalAssets)
        external
        view
        returns (uint256 assets);

    /// @notice Convert assets to shares at a specific point on the curve
    /// @param assets Quantity of assets to convert to shares
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @return shares The number of shares equivalent to the given assets
    function convertToShares(uint256 assets, uint256 totalAssets, uint256 totalShares)
        external
        view
        returns (uint256 shares);

    /// @notice Convert shares to assets at a specific point on the curve
    /// @param shares Quantity of shares to convert to assets
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @return assets The number of assets equivalent to the given shares
    function convertToAssets(uint256 shares, uint256 totalShares, uint256 totalAssets)
        external
        view
        returns (uint256 assets);

    /// @notice Get the current price of a share
    /// @param totalShares Total quantity of shares already awarded by the curve
    /// @param totalAssets Total quantity of assets already staked into the curve
    /// @return sharePrice The current price of a share, scaled by 1e18
    function currentPrice(uint256 totalShares, uint256 totalAssets) external view returns (uint256 sharePrice);

    /* =================================================== */
    /*                     FEE HOOKS                       */
    /* =================================================== */

    /// @notice Whether this curve charges a curve-level fee on deposits. When true, the MultiVault
    ///         quotes {quoteDepositFee} during deposit calculation (netting the fee from the amount
    ///         staked) and calls {recordDeposit} after its own state writes; when false, the deposit
    ///         hook surface is never called.
    /// @return True if the curve implements the deposit fee hook
    function hasDepositFeeHook() external view returns (bool);

    /// @notice Whether this curve charges a curve-level fee on redemptions. When true, the MultiVault
    ///         quotes {quoteRedeemFee} during redeem calculation (netting the fee from the payout)
    ///         and calls {recordRedeem} after its own state writes; when false, the redeem hook
    ///         surface is never called.
    /// @return True if the curve implements the redeem fee hook
    function hasRedeemFeeHook() external view returns (bool);

    /// @notice Quote the curve-level fee for a deposit. Layered on top of the MultiVault's own fees,
    ///         which are computed first and are never reduced by this fee — it only reduces the
    ///         depositor's net staked amount.
    /// @param termId The term (atom or triple) being deposited into
    /// @param baseAssets The deposit base the fee is quoted on (post-min-shares cost, pre-MultiVault-fees)
    /// @return fee The curve-level deposit fee, in assets
    function quoteDepositFee(bytes32 termId, uint256 baseAssets) external view returns (uint256 fee);

    /// @notice Quote the curve-level fee for a redemption. Layered on top of the MultiVault's own
    ///         fees, which are computed alongside and are never reduced by this fee — it only
    ///         reduces the redeemer's net payout.
    /// @param termId The term (atom or triple) being redeemed from
    /// @param account The redeeming account (address(0) on account-less preview paths)
    /// @param grossAssets The gross asset value of the redeemed shares the fee is quoted on
    /// @return fee The curve-level redeem fee, in assets
    function quoteRedeemFee(bytes32 termId, address account, uint256 grossAssets) external view returns (uint256 fee);

    /// @notice Record a deposit on the curve's own ledger and receive the quoted deposit fee as
    ///         `msg.value`. Called by the MultiVault after all of its vault-state writes, and only
    ///         on curves whose {hasDepositFeeHook} is true — on those curves it is called on every
    ///         deposit path, even when the quoted fee is zero, so the curve ledger stays in
    ///         lockstep with vault shares.
    /// @dev    The term-creation paths are the one exception. `createAtoms`,
    ///         `createAtomsFor`, `createTriples` and `createTriplesFor` mint the creator's shares on
    ///         `bondingCurveConfig.defaultCurveId` without resolving or dispatching this hook, so a
    ///         hook-bearing curve would receive no ledger entry for a created position and the
    ///         holder's first redemption would underflow inside the curve with no recovery path.
    ///         A hook-bearing curve therefore must not be set as `defaultCurveId`. The deployed
    ///         configuration keeps `defaultCurveId == 1` (`LinearCurve`, hookless, 1:1); hook curves
    ///         are reachable only through `deposit` / `redeem` on an explicit non-default `curveId`.
    /// @param termId The term (atom or triple) deposited into
    /// @param account The account the shares were minted to
    /// @param shares The number of shares minted to `account`
    function recordDeposit(bytes32 termId, address account, uint256 shares) external payable;

    /// @notice Record a redemption on the curve's own ledger and receive the quoted redeem fee as
    ///         `msg.value`. Called by the MultiVault after the shares are burned and vault totals
    ///         lowered (and before the receiver payout), and only on curves whose
    ///         {hasRedeemFeeHook} is true — but on those curves it is always called, even when the
    ///         quoted fee is zero, so the curve ledger stays in lockstep with vault shares.
    /// @param termId The term (atom or triple) redeemed from
    /// @param account The account whose shares were burned
    /// @param shares The number of shares burned from `account`
    function recordRedeem(bytes32 termId, address account, uint256 shares) external payable;
}
