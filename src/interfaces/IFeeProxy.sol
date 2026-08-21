// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/* =================================================== */
/*                       STRUCTS                       */
/* =================================================== */

/// @notice Per-affiliate fee configuration. Fixed-fee fields are denominated
///         in TRUST wei; bps fields are denominated in basis points where
///         `1 bps = 0.01%` (10_000 bps = 100%).
/// @dev    Bps fields are capped at {IFeeProxy.maxFeeBps} and fixed-fee fields
///         are capped at {IFeeProxy.maxFixedFee} at registration time and on
///         every subsequent {IFeeProxy.updateAffiliateFees} call. The
///         routing entry points additionally re-check the active caps at
///         execution time so a cap drop immediately blocks now-over-cap rows
///         until the affiliate updates the row down.
struct FeeConfig {
    /// @dev Bps applied to gross assets on deposit-side calls.
    uint256 depositBps;
    /// @dev Bps applied to gross assets on creation-side calls.
    uint256 creationBps;
    /// @dev Flat fee added to every deposit-side call (TRUST wei).
    uint256 depositFixedFee;
    /// @dev Flat fee added to every creation-side call (TRUST wei).
    uint256 creationFixedFee;
}

/// @notice Affiliate registry row. Stored append-only behind a TUP proxy.
/// @dev    Layout is part of the storage commitment from T2 onward; future
///         additions must append-only to the end of this struct. Mapping
///         values (`mapping(address => AffiliateConfig)`) allow safe struct
///         growth because each entry is hashed to its own slot region.
struct AffiliateConfig {
    /// @dev Per-affiliate fee parameters.
    FeeConfig fees;
    /// @dev Address that receives this affiliate's accrued fees. Set at
    ///      registration and updatable thereafter by the affiliate itself via
    ///      {IFeeProxy.updateFeeRecipient}; never zero for a registered row.
    address feeRecipient;
    /// @dev Unix timestamp at which the row was created.
    uint64 registeredAt;
    /// @dev Per-affiliate routing kill switch flipped by a pauser via
    ///      {IFeeProxy.pauseAffiliate}. While true, this affiliate row cannot
    ///      mediate new deposits or creations. The affiliate can still
    ///      rehabilitate its row via {IFeeProxy.updateAffiliateFees} and
    ///      {IFeeProxy.updateFeeRecipient} while paused, so routing can
    ///      resume immediately on admin unpause without an additional
    ///      coordination round. Redemptions against MultiVault are
    ///      unaffected (the proxy is not on that path). Reversible by an
    ///      admin via {IFeeProxy.unpauseAffiliate}.
    bool paused;
}

/// @notice Per-call front-run guard supplied by the caller. The configured
///         per-affiliate fee at execution time must not exceed these caps,
///         else the call reverts.
/// @dev    Affiliate fee config is mutable post-registration via
///         {IFeeProxy.updateAffiliateFees}, so this guard is the caller's
///         protection against a fee change (or front-run) between observing a
///         quote and execution: the configured fee at execution time is bounded
///         by these caller-supplied caps.
struct FeeGuard {
    /// @dev Maximum bps the caller is willing to pay on this call. Compared
    ///      against the relevant side's bps (deposit or creation) for the
    ///      target affiliate.
    uint256 maxFeeBps;
    /// @dev Maximum flat fee the caller is willing to pay on this call.
    uint256 maxFixedFee;
}

/// @notice Aggregate on-chain analytics for a registered affiliate. The
///         counters are storage-backed so builder dashboards can
///         read basic usage without a custom indexer.
/// @dev    Counts are per successful routing transaction through this proxy,
///         not per item inside a batch. `uniqueUsers` counts unique proxy-call
///         `msg.sender` wallets observed through the affiliate, not receivers.
struct AffiliateStats {
    /// @dev Successful routing transactions through this affiliate.
    uint256 txCount;
    /// @dev Unique proxy-call `msg.sender` wallets routed through this affiliate.
    uint256 uniqueUsers;
    /// @dev Sum of pre-affiliate-fee gross assets routed.
    uint256 totalGrossAssets;
    /// @dev Sum of affiliate fees paid.
    uint256 totalFees;
    /// @dev Sum of assets forwarded to MultiVault after affiliate fees.
    uint256 totalForwardedAssets;
    /// @dev Successful deposit-side routing transactions.
    uint256 depositCount;
    /// @dev Sum of pre-affiliate-fee deposit-side gross assets.
    uint256 depositGrossAssets;
    /// @dev Sum of deposit-side affiliate fees paid.
    uint256 depositFees;
    /// @dev Sum of deposit-side assets forwarded to MultiVault.
    uint256 depositForwardedAssets;
    /// @dev Successful creation-side routing transactions.
    uint256 creationCount;
    /// @dev Sum of pre-affiliate-fee creation-side gross assets.
    uint256 creationGrossAssets;
    /// @dev Sum of creation-side affiliate fees paid.
    uint256 creationFees;
    /// @dev Sum of creation-side assets forwarded to MultiVault.
    uint256 creationForwardedAssets;
}

/// @notice Per-affiliate, per-user on-chain analytics. This lets a builder
///         inspect a specific wallet's routed usage without enumerating all
///         users on-chain.
/// @dev    `txCount > 0` is the first-seen marker used to increment
///         {AffiliateStats.uniqueUsers}.
struct AffiliateUserStats {
    /// @dev Successful routing transactions by this user through the affiliate.
    uint256 txCount;
    /// @dev Sum of pre-affiliate-fee gross assets routed by this user.
    uint256 totalGrossAssets;
    /// @dev Sum of affiliate fees paid by this user.
    uint256 totalFees;
    /// @dev Sum of assets forwarded to MultiVault from this user's routes.
    uint256 totalForwardedAssets;
    /// @dev Successful deposit-side routing transactions by this user.
    uint256 depositCount;
    /// @dev Sum of pre-affiliate-fee deposit-side gross assets by this user.
    uint256 depositGrossAssets;
    /// @dev Sum of deposit-side affiliate fees paid by this user.
    uint256 depositFees;
    /// @dev Sum of deposit-side assets forwarded from this user's routes.
    uint256 depositForwardedAssets;
    /// @dev Successful creation-side routing transactions by this user.
    uint256 creationCount;
    /// @dev Sum of pre-affiliate-fee creation-side gross assets by this user.
    uint256 creationGrossAssets;
    /// @dev Sum of creation-side affiliate fees paid by this user.
    uint256 creationFees;
    /// @dev Sum of creation-side assets forwarded from this user's routes.
    uint256 creationForwardedAssets;
}

/// @title IFeeProxy
/// @author 0xIntuition
/// @notice External interface for the multi-tenant community fee proxy. The
///         proxy sits between community-side periphery callers and the core
///         {MultiVault} on the deposit and creation paths, applies a
///         per-affiliate fee, forwards the remaining value to MultiVault,
///         and refunds any excess `msg.value` with a pull-fallback ledger.
/// @dev    Redemptions are not proxied: users redeem directly
///         against {MultiVault} regardless of affiliate state, so no
///         affiliate can sit between a holder and their exit. A paused affiliate blocks new deposits and creations
///         through this proxy only; it does not affect a user's ability to
///         redeem.
///
///         Creation paths route through {MultiVault.createAtomsFor},
///         {MultiVault.createAtomsWithUris}, and
///         {MultiVault.createTriplesFor} using the {ApprovalTypes.CREATION}
///         bit, so the credited atom/triple creator and URI-context registrant
///         is the end user (`msg.sender` of the proxy call), not the proxy.
///
///         The protocol-level caps {maxFeeBps}, {maxFixedFee}, and
///         {registrationFee} are storage-backed and governable by admin
///         via {setMaxFeeBps}, {setMaxFixedFee}, {setRegistrationFee}. They
///         are not Solidity `constant`s, so the protocol can
///         tune fee headroom and registration-spam pricing over time
///         without an implementation upgrade.
///
///         V1 does not support third-party relayers or gas
///         sponsorship inside this proxy. Routing calls are user-submitted:
///         deposit receivers must approve this proxy for MultiVault DEPOSIT
///         routing, and delegated receivers (`receiver != msg.sender`) must
///         also approve `msg.sender`; creation attribution is bound to
///         `msg.sender`, who must approve this proxy for MultiVault CREATION
///         routing.
///
///         The implementation is expected to expose a SCW-safe `receive()`
///         that accepts ETH only from the configured {multiVault} or from
///         `address(this)` (for self-refund paths). Direct ETH sends from
///         other addresses revert with {FeeProxy_UnauthorizedEthSender}.
interface IFeeProxy {
    /* =================================================== */
    /*                       EVENTS                        */
    /* =================================================== */

    /// @notice Emitted when an affiliate row is created.
    /// @param affiliate The address that registered the row (also the
    ///        mapping key).
    /// @param feeRecipient The address that will receive this affiliate's
    ///        accrued fees.
    /// @param fees The fee configuration recorded for this affiliate.
    /// @param registrationFee The amount of TRUST forwarded to treasury as
    ///        the registration fee.
    event AffiliateRegistered(
        address indexed affiliate, address indexed feeRecipient, FeeConfig fees, uint256 registrationFee
    );

    /// @notice Emitted when a pauser pauses an affiliate row. The pause is
    ///         reversible via {unpauseAffiliate} by an admin.
    /// @param affiliate The address of the paused affiliate.
    event AffiliatePaused(address indexed affiliate);

    /// @notice Emitted when an admin reverses a per-affiliate pause via
    ///         {unpauseAffiliate}.
    /// @param affiliate The address of the unpaused affiliate.
    event AffiliateUnpaused(address indexed affiliate);

    /// @notice Emitted when an affiliate updates its own fee configuration
    ///         via {updateAffiliateFees}. Includes both the previous and the
    ///         current full {FeeConfig} so off-chain indexers can reconstruct
    ///         the diff without re-reading prior state.
    /// @param affiliate The affiliate whose row was updated.
    /// @param previous  The fee configuration immediately before the update.
    /// @param current   The fee configuration immediately after the update.
    event AffiliateFeesUpdated(address indexed affiliate, FeeConfig previous, FeeConfig current);

    /// @notice Emitted when an affiliate updates its own `feeRecipient` via
    ///         {updateFeeRecipient}.
    /// @param affiliate The affiliate whose row was updated.
    /// @param previous  The fee recipient immediately before the update.
    /// @param current   The fee recipient immediately after the update.
    event AffiliateFeeRecipientUpdated(address indexed affiliate, address indexed previous, address indexed current);

    /// @notice Emitted when the registration fee is forwarded to treasury.
    /// @param treasury The treasury destination that received the fee.
    /// @param amount The TRUST amount forwarded.
    event RegistrationFeeForwarded(address indexed treasury, uint256 amount);

    /// @notice Emitted when admin updates the protocol-level bps cap.
    /// @param previous The prior {maxFeeBps} value.
    /// @param current The new {maxFeeBps} value.
    event MaxFeeBpsUpdated(uint256 previous, uint256 current);

    /// @notice Emitted when admin updates the protocol-level fixed-fee
    ///         cap.
    /// @param previous The prior {maxFixedFee} value.
    /// @param current The new {maxFixedFee} value.
    event MaxFixedFeeUpdated(uint256 previous, uint256 current);

    /// @notice Emitted when admin updates the registration fee.
    /// @param previous The prior {registrationFee} value.
    /// @param current The new {registrationFee} value.
    event RegistrationFeeUpdated(uint256 previous, uint256 current);

    /// @notice Emitted on every {depositVia} call after fee deduction and
    ///         forwarding to MultiVault.
    /// @param user The end-user that initiated the call (`msg.sender`).
    /// @param affiliate The affiliate mediating the call.
    /// @param termId The MultiVault term ID deposited into.
    /// @param grossAssets Assets supplied by the user, pre-fee.
    /// @param fee Affiliate fee deducted before forwarding.
    /// @param forwardedAssets Assets actually forwarded to MultiVault.
    /// @param shares Shares minted by MultiVault to `receiver`.
    event DepositedVia(
        address indexed user,
        address indexed affiliate,
        bytes32 indexed termId,
        uint256 grossAssets,
        uint256 fee,
        uint256 forwardedAssets,
        uint256 shares
    );

    /// @notice Emitted once per {depositBatchVia} call as an aggregate
    ///         ledger entry. Per-vault `Deposited` events are emitted by
    ///         {MultiVault} itself.
    /// @param user The end-user that initiated the call.
    /// @param affiliate The affiliate mediating the batch.
    /// @param totalGrossAssets Sum of pre-fee assets supplied across the
    ///        batch.
    /// @param totalFee Sum of affiliate fees deducted across the batch.
    /// @param totalForwardedAssets Sum of assets forwarded to MultiVault.
    event DepositedBatchVia(
        address indexed user,
        address indexed affiliate,
        uint256 totalGrossAssets,
        uint256 totalFee,
        uint256 totalForwardedAssets
    );

    /// @notice Emitted once per {createAtomsVia} or {createAtomsWithUrisVia}
    ///         call as an aggregate ledger entry. Per-atom `AtomCreated` and
    ///         optional `AtomContextRegistered` events are emitted by
    ///         {MultiVault} itself.
    /// @param user The end-user credited as atom creator on MultiVault.
    /// @param affiliate The affiliate mediating the call.
    /// @param totalGrossAssets Sum of pre-fee creation assets.
    /// @param totalFee Sum of affiliate creation fees deducted.
    /// @param totalForwardedAssets Sum of assets forwarded to MultiVault.
    /// @param atomCount Number of atoms created in this call.
    event CreatedAtomsVia(
        address indexed user,
        address indexed affiliate,
        uint256 totalGrossAssets,
        uint256 totalFee,
        uint256 totalForwardedAssets,
        uint256 atomCount
    );

    /// @notice Emitted once per {createTriplesVia} call as an aggregate
    ///         ledger entry. Per-triple `TripleCreated` events are emitted
    ///         by {MultiVault} itself.
    /// @param user The end-user credited as triple creator on MultiVault.
    /// @param affiliate The affiliate mediating the call.
    /// @param totalGrossAssets Sum of pre-fee creation assets.
    /// @param totalFee Sum of affiliate creation fees deducted.
    /// @param totalForwardedAssets Sum of assets forwarded to MultiVault.
    /// @param tripleCount Number of triples created in this call.
    event CreatedTriplesVia(
        address indexed user,
        address indexed affiliate,
        uint256 totalGrossAssets,
        uint256 totalFee,
        uint256 totalForwardedAssets,
        uint256 tripleCount
    );

    /// @notice Emitted after a fee has been transferred to an affiliate's
    ///         `feeRecipient`. The transfer is a push at fee time, so there
    ///         is no claimable balance behind this event. Also emitted with
    ///         `amount == 0` on a fee-free route, where no transfer occurs.
    /// @param affiliate The affiliate the fee belongs to.
    /// @param user The end-user that paid the fee.
    /// @param amount The fee amount paid.
    event AffiliateFeePaid(address indexed affiliate, address indexed user, uint256 amount);

    /// @notice Emitted when a refund cannot be pushed to the user and is
    ///         instead credited to the pull-fallback ledger.
    /// @param user The address owed the refund.
    /// @param amount The amount credited to the ledger.
    event RefundCredited(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws their pull-fallback refund
    ///         balance via {claimRefund}.
    /// @param user The address that withdrew.
    /// @param amount The amount withdrawn.
    event RefundClaimed(address indexed user, uint256 amount);

    /* =================================================== */
    /*                       ERRORS                        */
    /* =================================================== */

    /// @notice Thrown when {registerAffiliate} is called with a `msg.value`
    ///         that does not exactly match {registrationFee}.
    /// @param sent The `msg.value` supplied by the caller.
    /// @param required The required {registrationFee} at call time.
    error FeeProxy_RegistrationFeeMismatch(uint256 sent, uint256 required);

    /// @notice Thrown when {registerAffiliate} is called by an address that
    ///         already has a registered row in the affiliate registry.
    /// @param affiliate The already-registered affiliate.
    error FeeProxy_AffiliateAlreadyRegistered(address affiliate);

    /// @notice Thrown when an entry point targets an affiliate that has
    ///         never been registered.
    /// @param affiliate The unregistered affiliate.
    error FeeProxy_AffiliateNotRegistered(address affiliate);

    /// @notice Thrown when an entry point targets an affiliate whose row
    ///         has been paused by admin.
    /// @param affiliate The paused affiliate.
    error FeeProxy_AffiliatePaused(address affiliate);

    /// @notice Thrown when {pauseAffiliate} is called for an affiliate row
    ///         that is already paused.
    /// @param affiliate The already-paused affiliate.
    error FeeProxy_AffiliateAlreadyPaused(address affiliate);

    /// @notice Thrown when {unpauseAffiliate} is called for an affiliate row
    ///         that is not currently paused.
    /// @param affiliate The affiliate whose row is not paused.
    error FeeProxy_AffiliateNotPaused(address affiliate);

    /// @notice Thrown when a configured bps exceeds the protocol-level cap.
    /// @param bps The configured bps value.
    /// @param cap The active {maxFeeBps} cap.
    error FeeProxy_BpsExceedsCap(uint256 bps, uint256 cap);

    /// @notice Thrown when a configured fixed fee exceeds the protocol-
    ///         level cap.
    /// @param fixedFee The configured fixed fee.
    /// @param cap The active {maxFixedFee} cap.
    error FeeProxy_FixedFeeExceedsCap(uint256 fixedFee, uint256 cap);

    /// @notice Thrown when the configured per-affiliate bps at call time
    ///         exceeds the caller's {FeeGuard.maxFeeBps}.
    /// @param configured The affiliate's configured bps.
    /// @param callerMax The caller's supplied cap.
    error FeeProxy_BpsExceedsCallerGuard(uint256 configured, uint256 callerMax);

    /// @notice Thrown when the configured per-affiliate fixed fee at call
    ///         time exceeds the caller's {FeeGuard.maxFixedFee}.
    /// @param configured The affiliate's configured fixed fee.
    /// @param callerMax The caller's supplied cap.
    error FeeProxy_FixedFeeExceedsCallerGuard(uint256 configured, uint256 callerMax);

    /// @notice Thrown when an address argument that must be non-zero is
    ///         supplied as `address(0)`.
    error FeeProxy_ZeroAddress();

    /// @notice Thrown when a delegated deposit route's caller is not
    ///         authorized to credit shares to the requested receiver.
    /// @dev    Only checks the caller-side approval. If `receiver` has not
    ///         approved this proxy for deposits, the route reverts with
    ///         {FeeProxy_ProxyNotApprovedForDeposit}.
    /// @param receiver The requested share receiver.
    /// @param caller The caller attempting to route the deposit.
    error FeeProxy_ReceiverNotApproved(address receiver, address caller);

    /// @notice Thrown when a deposit route's receiver has not approved this
    ///         proxy as a MultiVault DEPOSIT sender.
    /// @param receiver The requested share receiver.
    /// @param proxy The FeeProxy address that needs receiver approval.
    error FeeProxy_ProxyNotApprovedForDeposit(address receiver, address proxy);

    /// @notice Thrown when a creation route's caller has not approved this
    ///         proxy as a MultiVault CREATION sender.
    /// @param creator The caller that would be credited as creator.
    /// @param proxy The FeeProxy address that needs creator approval.
    error FeeProxy_ProxyNotApprovedForCreation(address creator, address proxy);

    /// @notice Thrown when an asset amount that must be non-zero is
    ///         supplied as `0`.
    error FeeProxy_ZeroValue();

    /// @notice Thrown when matched-length arrays have mismatched lengths.
    error FeeProxy_LengthMismatch();

    /// @notice Thrown when `msg.value` is less than the requested gross assets
    ///         (the fee is taken out of the gross, not added on top).
    /// @param supplied The `msg.value` supplied.
    /// @param required The gross assets required.
    error FeeProxy_InsufficientValue(uint256 supplied, uint256 required);

    /// @notice Thrown when the computed affiliate fee is greater than or equal
    ///         to the gross assets, leaving nothing to forward to MultiVault.
    /// @param fee The computed affiliate fee.
    /// @param gross The gross assets the fee was computed against.
    error FeeProxy_FeeExceedsGross(uint256 fee, uint256 gross);

    /// @notice Thrown when admin attempts to set {maxFeeBps} to a value
    ///         greater than 10_000 (100%).
    /// @param requested The requested value.
    error FeeProxy_MaxFeeBpsOutOfRange(uint256 requested);

    /// @notice Thrown when {claimRefundTo} is called with the FeeProxy itself
    ///         as the recipient. Routing a refund to `address(this)` would
    ///         clear the caller's `pendingRefund` ledger while leaving the
    ///         native value stuck in the contract with no owed balance behind
    ///         it, breaking refund-ledger conservation.
    error FeeProxy_RefundRecipientIsProxy();

    /// @notice Thrown when {claimRefund} is called by a user with no
    ///         pending refund balance.
    error FeeProxy_NoRefundOwed();

    /// @notice Thrown by the implementation's `receive()` when ETH is sent
    ///         from an address other than the configured {multiVault} or
    ///         from `address(this)`.
    /// @param sender The unauthorized sender.
    error FeeProxy_UnauthorizedEthSender(address sender);

    /* =================================================== */
    /*                  REGISTRY WRITES                    */
    /* =================================================== */

    /// @notice Permissionlessly registers `msg.sender` as an affiliate.
    ///         Charges {registrationFee} (forwarded to treasury), records
    ///         the fee configuration, and emits {AffiliateRegistered}.
    /// @dev    Reverts with {FeeProxy_RegistrationFeeMismatch} if
    ///         `msg.value != registrationFee()`. Reverts with
    ///         {FeeProxy_AffiliateAlreadyRegistered} if `msg.sender` is
    ///         already registered (rows are not overwritable). Reverts
    ///         with {FeeProxy_BpsExceedsCap} or
    ///         {FeeProxy_FixedFeeExceedsCap} if any field in `fees` is out
    ///         of bounds. Reverts with {FeeProxy_ZeroAddress} if
    ///         `feeRecipient == address(0)`.
    /// @param  fees Per-affiliate fee configuration to record.
    /// @param  feeRecipient Address that will receive this affiliate's
    ///         accrued fees.
    /// @return affiliate The newly registered affiliate address
    ///         (`msg.sender`).
    function registerAffiliate(FeeConfig calldata fees, address feeRecipient)
        external
        payable
        returns (address affiliate);

    /// @notice Pauses an affiliate row. Restricted to the pauser role.
    /// @dev    Reverts with {FeeProxy_AffiliateNotRegistered} if `affiliate`
    ///         has no row, and with {FeeProxy_AffiliateAlreadyPaused} if the
    ///         row is already paused. Pausing affects future {depositVia} /
    ///         {depositBatchVia} / {createAtomsVia} /
    ///         {createAtomsWithUrisVia} / {createTriplesVia} calls only; the
    ///         affiliate's own {updateAffiliateFees} and
    ///         {updateFeeRecipient} entry points remain callable so the
    ///         affiliate can fix the conditions that triggered the pause
    ///         before admin reverses it. User redemptions against
    ///         {MultiVault} are untouched. Reversible via {unpauseAffiliate}
    ///         by an admin.
    /// @param  affiliate The affiliate row to pause.
    function pauseAffiliate(address affiliate) external;

    /// @notice Reverses a per-affiliate pause set by {pauseAffiliate}.
    ///         Restricted to the admin role.
    /// @dev    Reverts with {FeeProxy_AffiliateNotRegistered} if `affiliate`
    ///         has no row, and with {FeeProxy_AffiliateNotPaused} if the row
    ///         is not currently paused. Does not validate the affiliate's
    ///         stored fees against the current protocol caps — if the caps
    ///         were lowered while the affiliate was paused, the routing
    ///         entry points will continue to revert with
    ///         {FeeProxy_BpsExceedsCap} or {FeeProxy_FixedFeeExceedsCap}
    ///         until the affiliate calls {updateAffiliateFees} to come back
    ///         under cap.
    /// @param  affiliate The affiliate row to unpause.
    function unpauseAffiliate(address affiliate) external;

    /// @notice Affiliate-owned update of its own {FeeConfig}. Reverts with
    ///         {FeeProxy_AffiliateNotRegistered} if `msg.sender` is not
    ///         registered. The new configuration must satisfy the active
    ///         {maxFeeBps} / {maxFixedFee} caps on both deposit and creation
    ///         sides; otherwise reverts with {FeeProxy_BpsExceedsCap} or
    ///         {FeeProxy_FixedFeeExceedsCap}.
    /// @dev    Callable while the row is per-affiliate paused and while the
    ///         contract is globally paused: row-paused affiliates need to
    ///         be able to rehabilitate their row so routing can resume
    ///         immediately on admin unpause, and globally-paused
    ///         affiliates need the same path after a cap drop. Emits
    ///         {AffiliateFeesUpdated} with both the previous and the
    ///         current configuration.
    /// @param  fees The new fee configuration for `msg.sender`.
    function updateAffiliateFees(FeeConfig calldata fees) external;

    /// @notice Affiliate-owned update of its own `feeRecipient`. Reverts
    ///         with {FeeProxy_ZeroAddress} if `recipient` is the zero
    ///         address and {FeeProxy_AffiliateNotRegistered} if `msg.sender`
    ///         is not registered.
    /// @dev    Same availability as {updateAffiliateFees}: callable while
    ///         the row is per-affiliate paused and while the contract is
    ///         globally paused. Emits {AffiliateFeeRecipientUpdated} with
    ///         both the previous and the current recipient.
    /// @param  recipient The new fee recipient for `msg.sender`.
    function updateFeeRecipient(address recipient) external;

    /// @notice Globally pauses the routing and registration entry points.
    ///         Restricted to the pauser role.
    /// @dev    While paused, {registerAffiliate}, {depositVia},
    ///         {depositBatchVia}, {createAtomsVia},
    ///         {createAtomsWithUrisVia}, and {createTriplesVia} revert.
    ///         {claimRefund}, {claimRefundTo}, the affiliate-owned update
    ///         entry points, admin cap setters, and the pause-control surface
    ///         continue to work so users can recover refunds and admins can
    ///         stage configuration during the incident. Reverses via
    ///         {unpause} by an admin.
    function pause() external;

    /// @notice Reverses the global pause set by {pause}. Restricted to the
    ///         admin role (a tighter role than {pause} itself
    ///         so an operational pauser cannot also unilaterally restart the
    ///         contract).
    function unpause() external;

    /* =================================================== */
    /*                  ROUTING WRITES                     */
    /* =================================================== */

    /// @notice Mediates a single-vault deposit through `affiliate`. Deducts
    ///         the per-affiliate deposit fee from `grossAssets`, forwards
    ///         `grossAssets - fee` to {MultiVault.deposit}, credits
    ///         `receiver` with the resulting shares, and refunds any excess
    ///         `msg.value` above `grossAssets` to `msg.sender` (push, with
    ///         pull fallback on failure).
    /// @dev    `minShares` is forwarded unchanged to {MultiVault.deposit} and is
    ///         therefore checked against the post-fee deposit (`grossAssets - fee`),
    ///         not the gross input — size `minShares` for the net amount actually
    ///         deposited. Reverts via the standard MultiVault paths if the post-fee
    ///         deposit cannot mint at least `minShares`. Reverts with
    ///         {FeeProxy_InsufficientValue} when `msg.value < grossAssets`, and with
    ///         {FeeProxy_FeeExceedsGross} when the affiliate fee >= `grossAssets`. Reverts with
    ///         {FeeProxy_ProxyNotApprovedForDeposit} when `receiver` has not approved
    ///         this proxy for MultiVault DEPOSIT routing. Reverts with
    ///         {FeeProxy_ReceiverNotApproved} when a delegated `receiver`
    ///         has not also approved `msg.sender`.
    /// @param  affiliate   The affiliate mediating the deposit.
    /// @param  receiver    The share receiver. Must approve this proxy for
    ///                     MultiVault DEPOSIT routing; when not `msg.sender`,
    ///                     must also approve `msg.sender`.
    /// @param  termId      The MultiVault term to deposit into.
    /// @param  curveId     The bonding curve to use.
    /// @param  grossAssets The pre-fee gross asset amount to deposit.
    /// @param  minShares   Minimum acceptable shares to be minted, post-fee.
    /// @param  feeGuard    Per-call front-run guard for the affiliate's
    ///                     configured fee at execution time.
    /// @return shares      Shares minted by MultiVault to `receiver`.
    function depositVia(
        address affiliate,
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 grossAssets,
        uint256 minShares,
        FeeGuard calldata feeGuard
    ) external payable returns (uint256 shares);

    /// @notice Mediates a multi-vault deposit batch through `affiliate`.
    ///         Behaves like {depositVia} applied across `termIds`, with
    ///         per-vault `assets` and `minShares` arrays. Forwards each
    ///         post-fee leg to {MultiVault.depositBatch} (or equivalent
    ///         routing) and refunds any excess `msg.value`.
    /// @dev    Reverts with {FeeProxy_LengthMismatch} if any of `termIds`,
    ///         `curveIds`, `assets`, `minShares` are of unequal length.
    ///         Reverts with {FeeProxy_ProxyNotApprovedForDeposit} when `receiver` has
    ///         not approved this proxy for MultiVault DEPOSIT routing.
    ///         Reverts with {FeeProxy_ReceiverNotApproved} when a delegated
    ///         `receiver` has not also approved `msg.sender`.
    /// @param  affiliate The affiliate mediating the batch.
    /// @param  receiver The share receiver. Must approve this proxy for
    ///                  MultiVault DEPOSIT routing; when not `msg.sender`,
    ///                  must also approve `msg.sender`.
    /// @param  termIds The MultiVault terms to deposit into.
    /// @param  curveIds The bonding curves to use per leg.
    /// @param  assets The pre-fee gross assets per leg.
    /// @param  minShares Per-leg minimum acceptable shares, post-fee.
    /// @param  feeGuard Per-call front-run guard, applied to every leg.
    /// @return shares Per-leg shares minted by MultiVault.
    function depositBatchVia(
        address affiliate,
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares,
        FeeGuard calldata feeGuard
    ) external payable returns (uint256[] memory shares);

    /// @notice Mediates atom creation through `affiliate`. Deducts the
    ///         per-affiliate creation fee, forwards the remaining assets
    ///         to {MultiVault.createAtomsFor} crediting `msg.sender` as
    ///         the atom creator, and refunds any excess `msg.value`.
    /// @dev    `msg.sender` must have granted this proxy MultiVault CREATION
    ///         approval; otherwise reverts with
    ///         {FeeProxy_ProxyNotApprovedForCreation}.
    /// @param  affiliate The affiliate mediating the creation.
    /// @param  atomDatas Per-atom data payloads.
    /// @param  assets Per-atom gross creation assets (pre-fee).
    /// @param  feeGuard Per-call front-run guard, applied to every atom.
    /// @return termIds The IDs of the newly created atoms.
    function createAtomsVia(
        address affiliate,
        bytes[] calldata atomDatas,
        uint256[] calldata assets,
        FeeGuard calldata feeGuard
    ) external payable returns (bytes32[] memory termIds);

    /// @notice URI-aware variant of {createAtomsVia}. Creation-time context
    ///         is emitted by MultiVault without affecting atom identity or
    ///         being written to contract storage.
    /// @dev    Routes through {MultiVault.createAtomsWithUris}, preserving
    ///         `msg.sender` as both atom creator and context registrant. Uses
    ///         the same CREATION approval, fee, and refund rules as
    ///         {createAtomsVia}. Reverts with {FeeProxy_LengthMismatch} when
    ///         `atomDatas`, `assets`, and `uris` are not aligned.
    /// @param  affiliate The affiliate mediating the creation.
    /// @param  atomDatas Per-atom data payloads.
    /// @param  assets Per-atom gross creation assets (pre-fee).
    /// @param  uris Per-atom lists of creation-time context pointers.
    /// @param  feeGuard Per-call front-run guard, applied to every atom.
    /// @return termIds The IDs of the newly created atoms.
    function createAtomsWithUrisVia(
        address affiliate,
        bytes[] calldata atomDatas,
        uint256[] calldata assets,
        bytes[][] calldata uris,
        FeeGuard calldata feeGuard
    ) external payable returns (bytes32[] memory termIds);

    /// @notice Mediates triple creation through `affiliate`. Deducts the
    ///         per-affiliate creation fee, forwards the remaining assets
    ///         to {MultiVault.createTriplesFor} crediting `msg.sender` as
    ///         the triple creator, and refunds any excess `msg.value`.
    /// @dev    Same approval requirements as {createAtomsVia}. Reverts
    ///         with {FeeProxy_LengthMismatch} if `subjectIds`,
    ///         `predicateIds`, `objectIds`, `assets` are of unequal
    ///         length.
    /// @param  affiliate The affiliate mediating the creation.
    /// @param  subjectIds Per-triple subject atom IDs.
    /// @param  predicateIds Per-triple predicate atom IDs.
    /// @param  objectIds Per-triple object atom IDs.
    /// @param  assets Per-triple gross creation assets (pre-fee).
    /// @param  feeGuard Per-call front-run guard, applied to every triple.
    /// @return termIds The IDs of the newly created triples.
    function createTriplesVia(
        address affiliate,
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets,
        FeeGuard calldata feeGuard
    ) external payable returns (bytes32[] memory termIds);

    /// @notice Withdraws the caller's full pending refund balance from the
    ///         pull-fallback ledger to `msg.sender`.
    /// @dev    Reverts with {FeeProxy_NoRefundOwed} if the caller has no
    ///         pending balance. Use {claimRefundTo} when `msg.sender` is a
    ///         smart-contract wallet whose `receive()` reverts; otherwise the
    ///         pull-fallback recovery path would revert in the same way as
    ///         the original push leg and the balance would stay stuck. Emits
    ///         {RefundClaimed} on success.
    /// @return amount The amount withdrawn to `msg.sender`.
    function claimRefund() external returns (uint256 amount);

    /// @notice Withdraws the caller's full pending refund balance from the
    ///         pull-fallback ledger to an arbitrary `recipient`.
    /// @dev    Recovery path for smart-contract wallets whose `receive()`
    ///         reverts on the original push refund. The ledger is keyed on
    ///         `msg.sender`, so only the address that holds the credited
    ///         balance can move it; `recipient` is the destination of the
    ///         actual native-token transfer.
    ///
    ///         Reverts with {FeeProxy_ZeroAddress} if `recipient` is the zero
    ///         address, and with {FeeProxy_NoRefundOwed} if the caller has
    ///         no pending balance. Emits {RefundClaimed} on success (the
    ///         `user` field of the event is `msg.sender`, not `recipient`,
    ///         so the ledger-side accounting is unambiguous).
    /// @param  recipient The address that receives the credited native tokens.
    /// @return amount    The amount withdrawn to `recipient`.
    function claimRefundTo(address payable recipient) external returns (uint256 amount);

    /* =================================================== */
    /*                  ADMIN CONFIG SETTERS               */
    /* =================================================== */

    /// @notice Updates the protocol-level cap on per-affiliate bps fields.
    /// @dev    Restricted to admin role. Reverts with
    ///         {FeeProxy_MaxFeeBpsOutOfRange} if `newMaxFeeBps > 10_000`.
    ///         Existing affiliate rows are not rewritten, but routing entry
    ///         points enforce the active cap at execution time, so a cap drop
    ///         blocks any now-over-cap side until the affiliate updates its
    ///         row. Emits {MaxFeeBpsUpdated}.
    /// @param  newMaxFeeBps The new cap, in bps (≤ 10_000).
    function setMaxFeeBps(uint256 newMaxFeeBps) external;

    /// @notice Updates the protocol-level cap on per-affiliate fixed-fee
    ///         fields.
    /// @dev    Restricted to admin role. Same execution-time cap semantics as
    ///         {setMaxFeeBps}. Emits {MaxFixedFeeUpdated}.
    /// @param  newMaxFixedFee The new fixed-fee cap, in TRUST wei.
    function setMaxFixedFee(uint256 newMaxFixedFee) external;

    /// @notice Updates the TRUST amount required by {registerAffiliate}.
    /// @dev    Restricted to admin role. Emits {RegistrationFeeUpdated}.
    /// @param  newRegistrationFee The new registration fee, in TRUST wei.
    function setRegistrationFee(uint256 newRegistrationFee) external;

    /* =================================================== */
    /*                       VIEWS                         */
    /* =================================================== */

    /// @notice Returns the full registry row for `affiliate`.
    /// @dev    For an unregistered affiliate, returns a zero-valued struct
    ///         (in particular `registeredAt == 0` and
    ///         `feeRecipient == address(0)`).
    /// @param  affiliate The affiliate address to look up.
    /// @return config The stored {AffiliateConfig}.
    function affiliateConfig(address affiliate) external view returns (AffiliateConfig memory config);

    /// @notice Returns true if `affiliate` has a registered row.
    /// @param  affiliate The affiliate address to check.
    function isAffiliateRegistered(address affiliate) external view returns (bool);

    /// @notice Returns true if `affiliate` is registered and not paused.
    ///         This is the condition every routing entry point checks.
    /// @param  affiliate The affiliate address to check.
    function isAffiliateActive(address affiliate) external view returns (bool);

    /// @notice Returns the effective deposit-side fee math for `affiliate`
    ///         applied to `grossAssets`.
    /// @param  affiliate The affiliate whose fee config is consulted.
    /// @param  grossAssets The pre-fee gross asset amount.
    /// @return fee The total affiliate fee that would be deducted.
    /// @return forwarded The amount that would be forwarded to MultiVault.
    function previewDepositFee(address affiliate, uint256 grossAssets)
        external
        view
        returns (uint256 fee, uint256 forwarded);

    /// @notice Returns the effective creation-side fee math for
    ///         `affiliate` applied to `grossAssets`.
    /// @param  affiliate The affiliate whose fee config is consulted.
    /// @param  grossAssets The pre-fee gross asset amount.
    /// @return fee The total affiliate fee that would be deducted.
    /// @return forwarded The amount that would be forwarded to MultiVault.
    function previewCreationFee(address affiliate, uint256 grossAssets)
        external
        view
        returns (uint256 fee, uint256 forwarded);

    /// @notice Returns aggregate on-chain analytics for `affiliate`.
    /// @param  affiliate The affiliate whose counters should be returned.
    /// @return stats The stored aggregate counters.
    function affiliateStats(address affiliate) external view returns (AffiliateStats memory stats);

    /// @notice Returns per-user on-chain analytics for a specific
    ///         affiliate/user pair.
    /// @param  affiliate The affiliate whose user counters should be returned.
    /// @param  user The routed caller wallet to inspect.
    /// @return stats The stored per-user counters.
    function affiliateUserStats(address affiliate, address user) external view returns (AffiliateUserStats memory stats);

    /// @notice Returns the pull-fallback refund balance owed to `user`.
    /// @param  user The user to look up.
    /// @return amount The amount owed and withdrawable via {claimRefund}.
    function pendingRefund(address user) external view returns (uint256 amount);

    /* =================================================== */
    /*                  CONFIG GETTERS                     */
    /* =================================================== */

    /// @notice Returns the current protocol-level cap on per-affiliate bps
    ///         fields. Storage-backed and governable via {setMaxFeeBps}.
    function maxFeeBps() external view returns (uint256);

    /// @notice Returns the current protocol-level cap on per-affiliate
    ///         fixed-fee fields (TRUST wei). Storage-backed and governable
    ///         via {setMaxFixedFee}.
    function maxFixedFee() external view returns (uint256);

    /// @notice Returns the current TRUST amount required to call
    ///         {registerAffiliate}. Storage-backed and governable via
    ///         {setRegistrationFee}.
    function registrationFee() external view returns (uint256);

    /// @notice Returns the {MultiVault} contract this proxy forwards to.
    function multiVault() external view returns (address);

    /// @notice Returns the treasury that receives the registration fee at
    ///         {registerAffiliate} time.
    function treasury() external view returns (address);
}
