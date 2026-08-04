// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IMultiVault } from "src/interfaces/IMultiVault.sol";
import {
    AffiliateConfig,
    AffiliateStats,
    AffiliateUserStats,
    FeeConfig,
    FeeGuard,
    IFeeProxy
} from "src/interfaces/IFeeProxy.sol";

/**
 * @title  FeeProxy
 * @author 0xIntuition
 * @notice Multi-tenant community fee proxy. Sits between community-side
 *         periphery callers and the core {MultiVault} on the deposit and
 *         creation paths. Applies per-affiliate fee math, forwards the net
 *         assets to MultiVault, credits the end user as the on-chain creator
 *         on creation flows (via {MultiVault.createAtomsFor} /
 *         {MultiVault.createAtomsWithUris} /
 *         {MultiVault.createTriplesFor}), and refunds excess `msg.value` with
 *         a push-then-pull-fallback flow that is safe for smart-contract
 *         wallets.
 * @dev    Redemptions are not proxied; users redeem directly against
 *         {MultiVault} regardless of affiliate state. Two pause surfaces are
 *         available: per-affiliate {pauseAffiliate} (reversible via
 *         {unpauseAffiliate}) and global {pause} (reversible via {unpause}).
 *         Affiliates own their fee row post-registration via
 *         {updateAffiliateFees} and {updateFeeRecipient}; the routing entry
 *         points re-check the relevant side's cap at execution time, so
 *         lowering a protocol-level cap immediately blocks now-over-cap
 *         affiliates until they bring their row under the new cap. V1 is a
 *         user-submitted, no-sponsorship router: deposit receivers must
 *         approve this proxy on {MultiVault}, delegated receivers must also
 *         approve the caller, creation creators are bound to `msg.sender` and
 *         must approve this proxy, and per-affiliate analytics are stored
 *         on-chain for lightweight builder dashboards.
 */
contract FeeProxy is
    IFeeProxy,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /* =================================================== */
    /*                       ROLES                         */
    /* =================================================== */

    /// @notice Pauser role. Holders can pause individual affiliate rows via
    ///         {pauseAffiliate} and globally pause the routing /
    ///         registration surface via {pause}. The corresponding unpause
    ///         actions are gated on `DEFAULT_ADMIN_ROLE` instead, so an
    ///         operational pauser cannot unilaterally restart the contract
    ///         or rehabilitate an affiliate it just suspended.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /* =================================================== */
    /*                     CONSTANTS                       */
    /* =================================================== */

    /// @notice Basis-points denominator. `1 bps = 0.01%`, so `10_000` = 100%.
    uint256 public constant BPS_DIVISOR = 10_000;

    /* =================================================== */
    /*                       STATE                         */
    /* =================================================== */

    /// @inheritdoc IFeeProxy
    address public multiVault;

    /// @inheritdoc IFeeProxy
    address public treasury;

    /// @inheritdoc IFeeProxy
    uint256 public maxBps;

    /// @inheritdoc IFeeProxy
    uint256 public maxFixedFee;

    /// @inheritdoc IFeeProxy
    uint256 public registrationFee;

    /// @dev Affiliate registry. Exposed via {affiliateConfig} so the external
    ///      surface returns a typed `AffiliateConfig memory` rather than the
    ///      tuple a public-mapping getter would produce.
    mapping(address affiliate => AffiliateConfig config) internal _affiliateConfigs;

    /// @inheritdoc IFeeProxy
    mapping(address user => uint256 amount) public pendingRefund;

    /// @dev Aggregate affiliate analytics. Exposed via {affiliateStats} so the
    ///      external surface returns the typed struct instead of the tuple a
    ///      public mapping getter would produce.
    mapping(address affiliate => AffiliateStats stats) internal _affiliateStats;

    /// @dev Per-affiliate, per-user analytics. `txCount == 0` is the
    ///      first-seen marker used to increment
    ///      {_affiliateStats[affiliate].uniqueUsers}.
    mapping(address affiliate => mapping(address user => AffiliateUserStats stats)) internal _affiliateUserStats;

    /// @dev Reserved for future storage. Append-only.
    uint256[50] private __gap;

    /* =================================================== */
    /*                     CONSTRUCTOR                     */
    /* =================================================== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /* =================================================== */
    /*                     INITIALIZER                     */
    /* =================================================== */

    /// @notice Atomically initializes the proxy state.
    /// @param  multiVault_      The {MultiVault} this proxy forwards to.
    /// @param  treasury_        Treasury that receives the registration fee.
    /// @param  admin_           Admin (granted `DEFAULT_ADMIN_ROLE` and
    ///                          {PAUSER_ROLE}; grants / revokes role
    ///                          membership and is the only role that can
    ///                          {unpause} the contract or
    ///                          {unpauseAffiliate} a row).
    /// @param  maxBps_          Initial bps cap (must be ≤ {BPS_DIVISOR}).
    /// @param  maxFixedFee_     Initial fixed-fee cap (TRUST wei).
    /// @param  registrationFee_ Initial registration fee (TRUST wei).
    function initialize(
        address multiVault_,
        address treasury_,
        address admin_,
        uint256 maxBps_,
        uint256 maxFixedFee_,
        uint256 registrationFee_
    ) external initializer {
        if (multiVault_ == address(0) || treasury_ == address(0) || admin_ == address(0)) {
            revert FeeProxy_ZeroAddress();
        }
        if (maxBps_ > BPS_DIVISOR) revert FeeProxy_MaxBpsOutOfRange(maxBps_);

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);

        multiVault = multiVault_;
        treasury = treasury_;
        maxBps = maxBps_;
        maxFixedFee = maxFixedFee_;
        registrationFee = registrationFee_;
    }

    /* =================================================== */
    /*                  REGISTRY WRITES                    */
    /* =================================================== */

    /// @inheritdoc IFeeProxy
    function registerAffiliate(FeeConfig calldata fees, address feeRecipient)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (address affiliate)
    {
        if (feeRecipient == address(0)) revert FeeProxy_ZeroAddress();

        uint256 required = registrationFee;
        if (msg.value != required) revert FeeProxy_RegistrationFeeMismatch(msg.value, required);

        affiliate = msg.sender;
        AffiliateConfig storage row = _affiliateConfigs[affiliate];
        if (row.registeredAt != 0) revert FeeProxy_AffiliateAlreadyRegistered(affiliate);

        _assertFeesWithinCaps(fees);

        row.fees = fees;
        row.feeRecipient = feeRecipient;
        row.registeredAt = uint64(block.timestamp);

        if (required != 0) {
            Address.sendValue(payable(treasury), required);
            emit RegistrationFeeForwarded(treasury, required);
        }

        emit AffiliateRegistered(affiliate, feeRecipient, fees, required);
    }

    /// @inheritdoc IFeeProxy
    function pauseAffiliate(address affiliate) external onlyRole(PAUSER_ROLE) {
        AffiliateConfig storage row = _affiliateConfigs[affiliate];
        if (row.registeredAt == 0) revert FeeProxy_AffiliateNotRegistered(affiliate);
        if (row.paused) revert FeeProxy_AffiliateAlreadyPaused(affiliate);

        row.paused = true;

        emit AffiliatePaused(affiliate);
    }

    /// @inheritdoc IFeeProxy
    function unpauseAffiliate(address affiliate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AffiliateConfig storage row = _affiliateConfigs[affiliate];
        if (row.registeredAt == 0) revert FeeProxy_AffiliateNotRegistered(affiliate);
        if (!row.paused) revert FeeProxy_AffiliateNotPaused(affiliate);

        row.paused = false;

        emit AffiliateUnpaused(affiliate);
    }

    /// @inheritdoc IFeeProxy
    /// @dev Available to the affiliate regardless of its per-row pause state
    ///      and regardless of the global pause: the row-paused flag blocks
    ///      routing of user value, not the affiliate's ability to rehabilitate
    ///      its own row. This avoids a clunky admin sequence (unpause →
    ///      affiliate updates → re-pause if needed) for the common case of
    ///      bringing fees back under a freshly-lowered cap.
    function updateAffiliateFees(FeeConfig calldata fees) external {
        AffiliateConfig storage row = _affiliateConfigs[msg.sender];
        if (row.registeredAt == 0) revert FeeProxy_AffiliateNotRegistered(msg.sender);

        _assertFeesWithinCaps(fees);

        FeeConfig memory previous = row.fees;
        row.fees = fees;

        emit AffiliateFeesUpdated(msg.sender, previous, fees);
    }

    /// @inheritdoc IFeeProxy
    /// @dev Same availability as {updateAffiliateFees}: row-paused affiliates
    ///      can rotate the fee recipient without admin intervention, e.g.
    ///      after a key migration.
    function updateFeeRecipient(address recipient) external {
        if (recipient == address(0)) revert FeeProxy_ZeroAddress();

        AffiliateConfig storage row = _affiliateConfigs[msg.sender];
        if (row.registeredAt == 0) revert FeeProxy_AffiliateNotRegistered(msg.sender);

        address previous = row.feeRecipient;
        row.feeRecipient = recipient;

        emit AffiliateFeeRecipientUpdated(msg.sender, previous, recipient);
    }

    /* =================================================== */
    /*                  ROUTING WRITES                     */
    /* =================================================== */

    /// @inheritdoc IFeeProxy
    function depositVia(
        address affiliate,
        address receiver,
        bytes32 termId,
        uint256 curveId,
        uint256 grossAssets,
        uint256 minShares,
        FeeGuard calldata feeGuard
    ) external payable whenNotPaused nonReentrant returns (uint256 shares) {
        if (receiver == address(0)) revert FeeProxy_ZeroAddress();
        _assertDepositReceiverApproved(receiver);
        if (grossAssets == 0) revert FeeProxy_ZeroValue();
        if (msg.value < grossAssets) revert FeeProxy_InsufficientValue(msg.value, grossAssets);

        AffiliateConfig storage row = _requireActiveAffiliate(affiliate);
        _assertSideWithinCaps(row.fees.depositBps, row.fees.depositFixedFee);
        _assertFeeGuard(row.fees.depositBps, row.fees.depositFixedFee, feeGuard);

        uint256 fee = _calcFee(grossAssets, row.fees.depositBps, row.fees.depositFixedFee);
        if (fee >= grossAssets) revert FeeProxy_FeeExceedsGross(fee, grossAssets);
        uint256 forwarded = grossAssets - fee;

        _payAffiliate(row.feeRecipient, affiliate, msg.sender, fee);

        shares = IMultiVault(multiVault).deposit{ value: forwarded }(receiver, termId, curveId, minShares);

        _recordAffiliateStats(affiliate, msg.sender, grossAssets, fee, forwarded, false);
        _refundExcess(msg.sender, msg.value - grossAssets);

        emit DepositedVia(msg.sender, affiliate, termId, grossAssets, fee, forwarded, shares);
    }

    /// @inheritdoc IFeeProxy
    function depositBatchVia(
        address affiliate,
        address receiver,
        bytes32[] calldata termIds,
        uint256[] calldata curveIds,
        uint256[] calldata assets,
        uint256[] calldata minShares,
        FeeGuard calldata feeGuard
    ) external payable whenNotPaused nonReentrant returns (uint256[] memory shares) {
        if (receiver == address(0)) revert FeeProxy_ZeroAddress();
        _assertDepositReceiverApproved(receiver);
        if (
            termIds.length == 0 || termIds.length != curveIds.length || termIds.length != assets.length
                || termIds.length != minShares.length
        ) revert FeeProxy_LengthMismatch();

        RoutingFlow memory flow = _setupRoutingFlow(affiliate, assets, feeGuard, false);

        _payAffiliate(flow.feeRecipient, affiliate, msg.sender, flow.fee);

        shares = IMultiVault(multiVault).depositBatch{ value: flow.totalForwarded }(
            receiver, termIds, curveIds, flow.forwardedAssets, minShares
        );

        _recordAffiliateStats(affiliate, msg.sender, flow.totalGross, flow.fee, flow.totalForwarded, false);
        _refundExcess(msg.sender, msg.value - flow.totalGross);

        emit DepositedBatchVia(msg.sender, affiliate, flow.totalGross, flow.fee, flow.totalForwarded);
    }

    /// @inheritdoc IFeeProxy
    function createAtomsVia(
        address affiliate,
        bytes[] calldata atomDatas,
        uint256[] calldata assets,
        FeeGuard calldata feeGuard
    ) external payable whenNotPaused nonReentrant returns (bytes32[] memory termIds) {
        if (atomDatas.length == 0 || atomDatas.length != assets.length) {
            revert FeeProxy_LengthMismatch();
        }
        _assertCreatorApproved();

        RoutingFlow memory flow = _setupRoutingFlow(affiliate, assets, feeGuard, true);

        _payAffiliate(flow.feeRecipient, affiliate, msg.sender, flow.fee);

        termIds = IMultiVault(multiVault).createAtomsFor{ value: flow.totalForwarded }(
            msg.sender, atomDatas, flow.forwardedAssets
        );

        _recordAffiliateStats(affiliate, msg.sender, flow.totalGross, flow.fee, flow.totalForwarded, true);
        _refundExcess(msg.sender, msg.value - flow.totalGross);

        emit CreatedAtomsVia(msg.sender, affiliate, flow.totalGross, flow.fee, flow.totalForwarded, atomDatas.length);
    }

    /// @inheritdoc IFeeProxy
    function createAtomsWithUrisVia(
        address affiliate,
        bytes[] calldata atomDatas,
        uint256[] calldata assets,
        bytes[][] calldata uris,
        FeeGuard calldata feeGuard
    ) external payable whenNotPaused nonReentrant returns (bytes32[] memory termIds) {
        if (atomDatas.length == 0 || atomDatas.length != assets.length || atomDatas.length != uris.length) {
            revert FeeProxy_LengthMismatch();
        }
        _assertCreatorApproved();

        RoutingFlow memory flow = _setupRoutingFlow(affiliate, assets, feeGuard, true);

        _payAffiliate(flow.feeRecipient, affiliate, msg.sender, flow.fee);

        termIds = IMultiVault(multiVault).createAtomsWithUris{ value: flow.totalForwarded }(
            msg.sender, atomDatas, flow.forwardedAssets, uris
        );

        _recordAffiliateStats(affiliate, msg.sender, flow.totalGross, flow.fee, flow.totalForwarded, true);
        _refundExcess(msg.sender, msg.value - flow.totalGross);

        emit CreatedAtomsVia(msg.sender, affiliate, flow.totalGross, flow.fee, flow.totalForwarded, atomDatas.length);
    }

    /// @inheritdoc IFeeProxy
    function createTriplesVia(
        address affiliate,
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        uint256[] calldata assets,
        FeeGuard calldata feeGuard
    ) external payable whenNotPaused nonReentrant returns (bytes32[] memory termIds) {
        if (
            subjectIds.length == 0 || subjectIds.length != predicateIds.length || subjectIds.length != objectIds.length
                || subjectIds.length != assets.length
        ) revert FeeProxy_LengthMismatch();
        _assertCreatorApproved();

        RoutingFlow memory flow = _setupRoutingFlow(affiliate, assets, feeGuard, true);
        termIds = _executeCreateTriples(affiliate, subjectIds, predicateIds, objectIds, flow);
    }

    /// @dev Final-leg helper for {createTriplesVia}: pays the affiliate, forwards
    ///      the post-fee value to {MultiVault.createTriplesFor}, refunds any
    ///      excess `msg.value`, and emits {CreatedTriplesVia}. Kept private so the
    ///      five-array calldata frame stays out of the outer entry point's stack.
    function _executeCreateTriples(
        address affiliate,
        bytes32[] calldata subjectIds,
        bytes32[] calldata predicateIds,
        bytes32[] calldata objectIds,
        RoutingFlow memory flow
    ) private returns (bytes32[] memory termIds) {
        _payAffiliate(flow.feeRecipient, affiliate, msg.sender, flow.fee);

        termIds = IMultiVault(multiVault).createTriplesFor{ value: flow.totalForwarded }(
            msg.sender, subjectIds, predicateIds, objectIds, flow.forwardedAssets
        );

        _recordAffiliateStats(affiliate, msg.sender, flow.totalGross, flow.fee, flow.totalForwarded, true);
        _refundExcess(msg.sender, msg.value - flow.totalGross);

        emit CreatedTriplesVia(msg.sender, affiliate, flow.totalGross, flow.fee, flow.totalForwarded, subjectIds.length);
    }

    /// @inheritdoc IFeeProxy
    function claimRefund() external nonReentrant returns (uint256 amount) {
        return _claimRefundTo(payable(msg.sender));
    }

    /// @inheritdoc IFeeProxy
    function claimRefundTo(address payable recipient) external nonReentrant returns (uint256 amount) {
        if (recipient == address(0)) revert FeeProxy_ZeroAddress();
        // Routing a refund to the proxy itself would clear the caller's ledger entry while the native
        // value lands back in `receive()` with no owed balance behind it (unaccounted, stuck TRUST).
        if (recipient == address(this)) revert FeeProxy_RefundRecipientIsProxy();
        return _claimRefundTo(recipient);
    }

    /* =================================================== */
    /*                ADMIN CONFIG SETTERS                 */
    /* =================================================== */

    /// @inheritdoc IFeeProxy
    function setMaxBps(uint256 newMaxBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMaxBps > BPS_DIVISOR) revert FeeProxy_MaxBpsOutOfRange(newMaxBps);
        uint256 previous = maxBps;
        maxBps = newMaxBps;
        emit MaxBpsUpdated(previous, newMaxBps);
    }

    /// @inheritdoc IFeeProxy
    function setMaxFixedFee(uint256 newMaxFixedFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 previous = maxFixedFee;
        maxFixedFee = newMaxFixedFee;
        emit MaxFixedFeeUpdated(previous, newMaxFixedFee);
    }

    /// @inheritdoc IFeeProxy
    function setRegistrationFee(uint256 newRegistrationFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 previous = registrationFee;
        registrationFee = newRegistrationFee;
        emit RegistrationFeeUpdated(previous, newRegistrationFee);
    }

    /* =================================================== */
    /*                    GLOBAL PAUSE                     */
    /* =================================================== */

    /// @inheritdoc IFeeProxy
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc IFeeProxy
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /* =================================================== */
    /*                       VIEWS                         */
    /* =================================================== */

    /// @inheritdoc IFeeProxy
    function affiliateConfig(address affiliate) external view returns (AffiliateConfig memory config) {
        return _affiliateConfigs[affiliate];
    }

    /// @inheritdoc IFeeProxy
    function isAffiliateRegistered(address affiliate) external view returns (bool) {
        return _affiliateConfigs[affiliate].registeredAt != 0;
    }

    /// @inheritdoc IFeeProxy
    function isAffiliateActive(address affiliate) external view returns (bool) {
        AffiliateConfig storage row = _affiliateConfigs[affiliate];
        return row.registeredAt != 0 && !row.paused;
    }

    /// @inheritdoc IFeeProxy
    function previewDepositFee(address affiliate, uint256 grossAssets)
        external
        view
        returns (uint256 fee, uint256 forwarded)
    {
        FeeConfig storage cfg = _affiliateConfigs[affiliate].fees;
        fee = _calcFee(grossAssets, cfg.depositBps, cfg.depositFixedFee);
        forwarded = fee >= grossAssets ? 0 : grossAssets - fee;
    }

    /// @inheritdoc IFeeProxy
    function previewCreationFee(address affiliate, uint256 grossAssets)
        external
        view
        returns (uint256 fee, uint256 forwarded)
    {
        FeeConfig storage cfg = _affiliateConfigs[affiliate].fees;
        fee = _calcFee(grossAssets, cfg.creationBps, cfg.creationFixedFee);
        forwarded = fee >= grossAssets ? 0 : grossAssets - fee;
    }

    /// @inheritdoc IFeeProxy
    function affiliateStats(address affiliate) external view returns (AffiliateStats memory stats) {
        return _affiliateStats[affiliate];
    }

    /// @inheritdoc IFeeProxy
    function affiliateUserStats(address affiliate, address user)
        external
        view
        returns (AffiliateUserStats memory stats)
    {
        return _affiliateUserStats[affiliate][user];
    }

    /* =================================================== */
    /*                      RECEIVE                        */
    /* =================================================== */

    /// @notice Accepts native ETH only from the configured {multiVault} or
    ///         from this contract itself. Direct sends from arbitrary
    ///         addresses revert with {FeeProxy_UnauthorizedEthSender}.
    receive() external payable {
        if (msg.sender != multiVault && msg.sender != address(this)) {
            revert FeeProxy_UnauthorizedEthSender(msg.sender);
        }
    }

    /* =================================================== */
    /*                      INTERNAL                       */
    /* =================================================== */

    /// @dev Memory-only routing state for the multi-leg entry points.
    ///      Bundling these fields into one struct keeps the call-site stack
    ///      lean enough to compile without `via-ir`.
    struct RoutingFlow {
        uint256 totalGross;
        uint256 fee;
        uint256 totalForwarded;
        address feeRecipient;
        uint256[] forwardedAssets;
    }

    /// @dev Shared multi-leg routing setup: validates the affiliate, asserts
    ///      the caller {FeeGuard}, computes the aggregate fee on `assets`,
    ///      allocates the post-fee forwarded array, and returns the bundled
    ///      state. `useCreationFees` picks the creation-side fee fields when
    ///      true and the deposit-side fields when false.
    function _setupRoutingFlow(
        address affiliate,
        uint256[] calldata assets,
        FeeGuard calldata feeGuard,
        bool useCreationFees
    ) internal view returns (RoutingFlow memory flow) {
        AffiliateConfig storage row = _requireActiveAffiliate(affiliate);
        uint256 bps = useCreationFees ? row.fees.creationBps : row.fees.depositBps;
        uint256 fixedFee = useCreationFees ? row.fees.creationFixedFee : row.fees.depositFixedFee;
        _assertSideWithinCaps(bps, fixedFee);
        _assertFeeGuard(bps, fixedFee, feeGuard);

        // `_sum` rejects any zero per-leg, and the caller pre-validates a
        // nonzero array length, so `totalGross` is strictly positive here.
        uint256 totalGross = _sum(assets);
        if (msg.value < totalGross) revert FeeProxy_InsufficientValue(msg.value, totalGross);

        uint256 fee = _calcFee(totalGross, bps, fixedFee);
        if (fee >= totalGross) revert FeeProxy_FeeExceedsGross(fee, totalGross);

        flow.totalGross = totalGross;
        flow.fee = fee;
        flow.totalForwarded = totalGross - fee;
        flow.feeRecipient = row.feeRecipient;
        flow.forwardedAssets = _allocate(assets, flow.totalForwarded, totalGross);
    }

    /// @dev Workhorse for {claimRefund} / {claimRefundTo}. Debits
    ///      `pendingRefund[msg.sender]` and pushes the balance to `recipient`.
    ///      Kept `internal` so the two external entry points share one body
    ///      under a single reentrancy guard.
    function _claimRefundTo(address payable recipient) internal returns (uint256 amount) {
        amount = pendingRefund[msg.sender];
        if (amount == 0) revert FeeProxy_NoRefundOwed();
        pendingRefund[msg.sender] = 0;

        Address.sendValue(recipient, amount);

        emit RefundClaimed(msg.sender, amount);
    }

    /// @dev Records dashboard-friendly affiliate analytics after a successful
    ///      MultiVault call. Keep this after the routed external call so
    ///      reverted routes never inflate counters; refund push/fallback
    ///      outcome is intentionally tracked independently. A batch is counted
    ///      as one routed transaction because it consumed one proxy entry point.
    function _recordAffiliateStats(
        address affiliate,
        address user,
        uint256 grossAssets,
        uint256 fee,
        uint256 forwardedAssets,
        bool isCreation
    ) internal {
        AffiliateStats storage aggregate = _affiliateStats[affiliate];
        AffiliateUserStats storage userStats = _affiliateUserStats[affiliate][user];

        if (userStats.txCount == 0) {
            aggregate.uniqueUsers += 1;
        }

        aggregate.txCount += 1;
        aggregate.totalGrossAssets += grossAssets;
        aggregate.totalFees += fee;
        aggregate.totalForwardedAssets += forwardedAssets;

        userStats.txCount += 1;
        userStats.totalGrossAssets += grossAssets;
        userStats.totalFees += fee;
        userStats.totalForwardedAssets += forwardedAssets;

        if (isCreation) {
            aggregate.creationCount += 1;
            aggregate.creationGrossAssets += grossAssets;
            aggregate.creationFees += fee;
            aggregate.creationForwardedAssets += forwardedAssets;

            userStats.creationCount += 1;
            userStats.creationGrossAssets += grossAssets;
            userStats.creationFees += fee;
            userStats.creationForwardedAssets += forwardedAssets;
        } else {
            aggregate.depositCount += 1;
            aggregate.depositGrossAssets += grossAssets;
            aggregate.depositFees += fee;
            aggregate.depositForwardedAssets += forwardedAssets;

            userStats.depositCount += 1;
            userStats.depositGrossAssets += grossAssets;
            userStats.depositFees += fee;
            userStats.depositForwardedAssets += forwardedAssets;
        }
    }

    /// @dev Returns a storage pointer to an affiliate row that is registered
    ///      and not paused, reverting otherwise.
    function _requireActiveAffiliate(address affiliate) internal view returns (AffiliateConfig storage row) {
        row = _affiliateConfigs[affiliate];
        if (row.registeredAt == 0) revert FeeProxy_AffiliateNotRegistered(affiliate);
        if (row.paused) revert FeeProxy_AffiliatePaused(affiliate);
    }

    /// @dev Requires the receiver to approve this proxy for all deposits.
    ///      Delegated receivers must also approve the caller.
    function _assertDepositReceiverApproved(address receiver) internal view {
        IMultiVault multiVaultContract = IMultiVault(multiVault);

        if (!multiVaultContract.isApprovedToDeposit(address(this), receiver)) {
            revert FeeProxy_ProxyNotApprovedForDeposit(receiver, address(this));
        }

        if (receiver != msg.sender && !multiVaultContract.isApprovedToDeposit(msg.sender, receiver)) {
            revert FeeProxy_ReceiverNotApproved(receiver, msg.sender);
        }
    }

    /// @dev Requires the caller to approve this proxy for creation routes.
    function _assertCreatorApproved() internal view {
        IMultiVault multiVaultContract = IMultiVault(multiVault);

        if (!multiVaultContract.isApprovedToCreate(address(this), msg.sender)) {
            revert FeeProxy_ProxyNotApprovedForCreation(msg.sender, address(this));
        }
    }

    /// @dev Reverts if any field in `fees` exceeds the active protocol-level
    ///      caps {maxBps} / {maxFixedFee}. Used at registration and on every
    ///      {updateAffiliateFees} call.
    function _assertFeesWithinCaps(FeeConfig calldata fees) internal view {
        _assertSideWithinCaps(fees.depositBps, fees.depositFixedFee);
        _assertSideWithinCaps(fees.creationBps, fees.creationFixedFee);
    }

    /// @dev Reverts if a single side's `(bps, fixedFee)` pair exceeds the
    ///      active protocol-level caps. Used at execution time by the
    ///      routing entry points to enforce the current cap against the
    ///      side they actually consume (deposit vs. creation), so a
    ///      protocol-cap drop immediately blocks now-over-cap affiliates
    ///      without separately blocking the orthogonal side's flow.
    function _assertSideWithinCaps(uint256 bps, uint256 fixedFee) internal view {
        uint256 bpsCap = maxBps;
        uint256 fixedCap = maxFixedFee;
        if (bps > bpsCap) revert FeeProxy_BpsExceedsCap(bps, bpsCap);
        if (fixedFee > fixedCap) revert FeeProxy_FixedFeeExceedsCap(fixedFee, fixedCap);
    }

    /// @dev Reverts if the configured fee at execution time exceeds the
    ///      caller-supplied {FeeGuard} on either axis.
    function _assertFeeGuard(uint256 configuredBps, uint256 configuredFixed, FeeGuard calldata guard) internal pure {
        if (configuredBps > guard.maxFeeBps) {
            revert FeeProxy_BpsExceedsCallerGuard(configuredBps, guard.maxFeeBps);
        }
        if (configuredFixed > guard.maxFixedFee) {
            revert FeeProxy_FixedFeeExceedsCallerGuard(configuredFixed, guard.maxFixedFee);
        }
    }

    /// @dev Per-call fee math. Bps applied to `grossAssets`, plus the flat
    ///      fixed fee. Caller is responsible for any subsequent
    ///      `fee < grossAssets` invariant.
    function _calcFee(uint256 grossAssets, uint256 bps, uint256 fixedFee) internal pure returns (uint256) {
        return (grossAssets * bps) / BPS_DIVISOR + fixedFee;
    }

    /// @dev Pushes the accrued affiliate fee to `feeRecipient`. Reverts on
    ///      transfer failure (an affiliate that wires a bricked recipient is
    ///      responsible for migrating, not the protocol). Emits
    ///      {AffiliateFeeAccrued} at the credit point.
    function _payAffiliate(address feeRecipient, address affiliate, address user, uint256 amount) internal {
        if (amount == 0) {
            emit AffiliateFeeAccrued(affiliate, user, 0);
            return;
        }
        Address.sendValue(payable(feeRecipient), amount);
        emit AffiliateFeeAccrued(affiliate, user, amount);
    }

    /// @dev Pushes a refund to `user`. On push failure (e.g. an SCW with a
    ///      reverting receive) credits the pull-fallback ledger so the user
    ///      can recover via {claimRefund}.
    function _refundExcess(address user, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok,) = payable(user).call{ value: amount }("");
        if (!ok) {
            pendingRefund[user] += amount;
            emit RefundCredited(user, amount);
        }
    }

    /// @dev Sum an array of `uint256` values, rejecting any zero leg so the
    ///      proportional `_allocate` step cannot starve nonzero legs by
    ///      shipping the rounding dust to a zero-gross slot.
    function _sum(uint256[] calldata values) internal pure returns (uint256 total) {
        uint256 length = values.length;
        for (uint256 i = 0; i < length;) {
            if (values[i] == 0) revert FeeProxy_ZeroValue();
            total += values[i];
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Allocate `totalForwarded` across legs in proportion to their
    ///      pre-fee asset share, with the rounding dust assigned to the last
    ///      leg so the per-leg sum matches `totalForwarded` exactly. Caller
    ///      guarantees `totalGross > 0` and `assets.length > 0`.
    function _allocate(uint256[] calldata assets, uint256 totalForwarded, uint256 totalGross)
        internal
        pure
        returns (uint256[] memory forwardedAssets)
    {
        uint256 length = assets.length;
        forwardedAssets = new uint256[](length);
        uint256 last = length - 1;
        uint256 accumulated;
        for (uint256 i = 0; i < last;) {
            uint256 piece = (assets[i] * totalForwarded) / totalGross;
            forwardedAssets[i] = piece;
            accumulated += piece;
            unchecked {
                ++i;
            }
        }
        forwardedAssets[last] = totalForwarded - accumulated;
    }
}
