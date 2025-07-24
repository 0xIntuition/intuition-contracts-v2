// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal interface for the bonding contract (ve‑style lock)
interface TrustBonding {
    function create_lock_for(address _addr, uint256 _value, uint256 _unlock_time) external;
    function deposit_for(address _addr, uint256 _value) external;
    function locked(address _addr) external view returns (int128 amount, uint256 end);
}

/**
 *
 * @title  TrustVestedMerkleDistributor
 * @notice Distributes TRUST tokens according to a merkle‑root allocation.  Users may:
 *         • claim vested tokens linearly after receiving an initial TGE tranche;
 *         • claim & immediately bond the vested portion via the TrustBonding contract;
 *         • execute a one‑time “rage‑quit” to receive a larger immediate tranche while
 *           forfeiting the remainder back to the protocol treasury.
 *
 * @dev    The contract is largely inspired by Uniswap's MerkleDistributor. Naming has been
 *         generalized for the TRUST token and bonding flow.
 *
 */
contract TrustVestedMerkleDistributor is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant FEE_DENOMINATOR = 10_000; // 100% expressed in BPS
    uint256 public constant MAX_FEE_IN_BPS = 1_000; // 10%

    /*//////////////////////////////////////////////////////////////
                                   ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroValueProvided();
    error NoTokensToClaim();
    error InvalidMerkleProof();
    error InvalidFeeInBPS();
    error VestingAlreadyStarted();
    error VestingStartInThePast();
    error AlreadyRageQuit();
    error AlreadyClaimed();
    error InvalidPercentageBPS();
    error InvalidUnlockTime();
    error ClaimClosed();
    error ClaimOngoing();
    error InvalidClaimEnd();
    error ZeroAddress();
    error VestingEndInThePast();
    error CannotShortenClaimWindow();
    error LateInitialClaim();

    /*//////////////////////////////////////////////////////////////
                                   EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claimed(address indexed account, uint256 amount, uint256 fee);
    event ClaimedAndBonded(address indexed account, uint256 amount, uint256 fee, uint256 unlockTime);
    event RageQuit(address indexed account, uint256 amountClaimed, uint256 amountForfeited, uint256 fee);
    event RageQuitAndBonded(
        address indexed account, uint256 amountClaimed, uint256 amountForfeited, uint256 fee, uint256 unlockTime
    );
    event TrustBondingUpdated(address bonding);
    event ProtocolTreasuryUpdated(address protocolTreasury);
    event FeeInBPSUpdated(uint256 feeInBPS);
    event VestingStartTimestampSet(uint256 vestingStartTimestamp);
    event ClaimEndSet(uint256 claimEndTimestamp);

    /*//////////////////////////////////////////////////////////////
                                  STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC20 public trust; // TRUST token
    TrustBonding public trustBonding; // Bonding (ve‑locking) contract

    address public protocolTreasury; // Protocol treasury

    bytes32 public merkleRoot; // Merkle root committing <user,address,amount>

    uint256 public feeInBPS; // Protocol fee on every claim
    uint256 public vestingStartTimestamp; // Timestamp at which vesting begins / TGE
    uint256 public vestingDuration; // Linear vesting period in seconds
    uint256 public claimEndTimestamp; // Timestamp at which claiming ends

    uint256 public tgeBPS; // Immediate unlock % (e.g. 5_000 = 50%)
    uint256 public rageQuitBPS; // Immediate unlock % for rage‑quit (e.g. 6_500 = 65%)

    struct UserClaim {
        uint256 lastClaimTimestamp; // Last successful claim
        uint256 amountClaimed; // Cumulative amount claimed (incl. RageQuit)
        bool rageQuit; // True after user executes rage‑quit
    }

    struct VestingParams {
        address owner; // Owner of the vesting contract
        address trust; // TRUST token address
        address trustBonding; // Bonding contract (ve‑lock) address
        address protocolTreasury; // Treasury to collect fees & forfeited tokens
        uint256 feeInBPS; // Fee charged on every transfer (max 10%)
        uint256 vestingStartTimestamp; // Timestamp when TGE happens **in the future**
        uint256 vestingDuration; // Linear vesting duration (seconds)
        uint256 claimEndTimestamp; // Timestamp at which claiming ends
        uint256 tgeBPS; // Portion unlocked immediately at TGE (<= 10_000)
        uint256 rageQuitBPS; // Portion unlocked on rage‑quit (must be > tgeBPS)
        bytes32 merkleRoot; // Merkle root committing claims
    }

    mapping(address => UserClaim) public userClaims;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALISATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the contract with the provided parameters.
     * @param vestingParams Struct containing all initialization parameters for this contract.
     */
    function initialize(VestingParams calldata vestingParams) external initializer {
        /* ---------------------- sanity checks ---------------------- */
        if (vestingParams.owner == address(0)) revert ZeroAddress();
        if (vestingParams.trust == address(0)) revert ZeroAddress();
        if (vestingParams.trustBonding == address(0)) revert ZeroAddress();
        if (vestingParams.protocolTreasury == address(0)) revert ZeroAddress();

        if (vestingParams.feeInBPS > MAX_FEE_IN_BPS) revert InvalidFeeInBPS();
        if (vestingParams.merkleRoot == bytes32(0)) revert ZeroValueProvided();
        if (vestingParams.vestingStartTimestamp == 0) revert ZeroValueProvided();
        if (vestingParams.vestingStartTimestamp <= block.timestamp) revert VestingStartInThePast();
        if (vestingParams.vestingDuration == 0) revert ZeroValueProvided();
        if (vestingParams.claimEndTimestamp <= vestingParams.vestingStartTimestamp + vestingParams.vestingDuration) {
            revert InvalidClaimEnd();
        }
        if (vestingParams.tgeBPS == 0 || vestingParams.tgeBPS >= FEE_DENOMINATOR) revert InvalidPercentageBPS();
        if (vestingParams.rageQuitBPS <= vestingParams.tgeBPS || vestingParams.rageQuitBPS >= FEE_DENOMINATOR) {
            revert InvalidPercentageBPS();
        }

        /* --------------------- initialize OZ ---------------------- */
        __Ownable_init(vestingParams.owner);
        __Pausable_init();
        __ReentrancyGuard_init();

        /* ----------------------- assignment ----------------------- */
        trust = IERC20(vestingParams.trust);
        trustBonding = TrustBonding(vestingParams.trustBonding);
        protocolTreasury = vestingParams.protocolTreasury;
        feeInBPS = vestingParams.feeInBPS;
        merkleRoot = vestingParams.merkleRoot;
        vestingStartTimestamp = vestingParams.vestingStartTimestamp;
        vestingDuration = vestingParams.vestingDuration;
        claimEndTimestamp = vestingParams.claimEndTimestamp;
        tgeBPS = vestingParams.tgeBPS;
        rageQuitBPS = vestingParams.rageQuitBPS;

        /* ------------------- approvals ---------------------------- */
        trust.forceApprove(vestingParams.trustBonding, type(uint256).max);

        emit VestingStartTimestampSet(vestingParams.vestingStartTimestamp);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev    Calculates the unclaimed vested amount for `user` given their merkle allocation `total`
     *         and current block‑timestamp.
     */
    function _getUnclaimedVestedAmount(address user, uint256 total) internal view returns (uint256) {
        UserClaim storage uc = userClaims[user];

        // amount immediately unlocked at TGE
        uint256 immediate = (total * tgeBPS) / FEE_DENOMINATOR;

        // before vesting begins – user can take only the immediate tranche (tgeBPS)
        if (block.timestamp < vestingStartTimestamp) {
            if (uc.amountClaimed >= immediate) return 0; // already took it
            return immediate - uc.amountClaimed; // what’s left
        }

        // users must claim the immediate allocation before vesting starts
        if (block.timestamp >= vestingStartTimestamp && uc.amountClaimed == 0) revert LateInitialClaim();

        // after vesting begins – user can take the remainder of the vested amount
        if (uc.rageQuit) return 0; // rage‑quitters forfeit remainder
        if (uc.amountClaimed >= total) return 0; // fully claimed already
        if (block.timestamp > claimEndTimestamp) revert ClaimClosed(); // claiming is closed

        // ----- linear vesting of the remainder ----- //
        uint256 elapsed = block.timestamp - vestingStartTimestamp;
        if (elapsed > vestingDuration) elapsed = vestingDuration;
        uint256 vestedLinear = ((total - immediate) * elapsed) / vestingDuration;

        uint256 totalVested = immediate + vestedLinear; // total vested amount at current block.timestamp
        if (totalVested > total) totalVested = total; // slab‑safety

        // ----- subtract what the user has already claimed ----- //
        uint256 unclaimed = totalVested - uc.amountClaimed;
        return unclaimed;
    }

    /**
     * @dev    Validates the merkle proof for (`user`,`amount`).  Reverts if invalid.
     */
    function _verifyProof(address user, uint256 amount, bytes32[] calldata proof) internal view {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroValueProvided();
        if (merkleRoot == bytes32(0)) revert ZeroValueProvided();

        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidMerkleProof();
    }

    /**
     * @dev    Applies protocol fee to `value` and returns (net, fee).
     */
    function _applyFee(uint256 value) internal view returns (uint256 net, uint256 fee) {
        fee = (value * feeInBPS) / FEE_DENOMINATOR;
        net = value - fee;
    }

    /*//////////////////////////////////////////////////////////////
                               USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Claim vested tokens, transferring them directly to the caller.
     */
    function claim(uint256 amount, bytes32[] calldata proof) external whenNotPaused nonReentrant {
        address user = msg.sender;
        _verifyProof(user, amount, proof);
        uint256 claimable = _getUnclaimedVestedAmount(user, amount);
        if (claimable == 0) revert NoTokensToClaim();

        (uint256 net, uint256 fee) = _applyFee(claimable);

        // --- state updates --- //
        UserClaim storage uc = userClaims[user];
        uc.lastClaimTimestamp = block.timestamp;
        uc.amountClaimed += claimable;

        // --- effects --- //
        if (fee > 0) trust.safeTransfer(protocolTreasury, fee);
        trust.safeTransfer(user, net);

        emit Claimed(user, net, fee);
    }

    /**
     * @notice Claim vested tokens and create a bond (ve‑lock) in a single transaction.
     * @param unlockTime  Timestamp at which the lock should expire (must be > now)
     */
    function claimAndBond(uint256 amount, uint256 unlockTime, bytes32[] calldata proof)
        external
        whenNotPaused
        nonReentrant
    {
        if (unlockTime <= block.timestamp) revert InvalidUnlockTime();
        address user = msg.sender;
        _verifyProof(user, amount, proof);
        uint256 claimable = _getUnclaimedVestedAmount(user, amount);
        if (claimable == 0) revert NoTokensToClaim();

        (uint256 net, uint256 fee) = _applyFee(claimable);

        // --- state updates --- //
        UserClaim storage uc = userClaims[user];
        uc.lastClaimTimestamp = block.timestamp;
        uc.amountClaimed += claimable;

        // --- fee transfer --- //
        if (fee > 0) trust.safeTransfer(protocolTreasury, fee);

        // --- bond --- //
        (int128 bondedAmount,) = trustBonding.locked(user);

        if (bondedAmount > 0) {
            // if user already has a bond, deposit the newly claimed amount into it
            trustBonding.deposit_for(user, net);
        } else {
            // if user does not have a bond, create a new bond for them
            trustBonding.create_lock_for(user, net, unlockTime);
        }

        emit ClaimedAndBonded(user, net, fee, unlockTime);
    }

    /**
     * @notice One‑time rage‑quit: claim `rageQuitBPS` immediately, forfeiting the remainder.
     *         Can only be executed if the user has NOT claimed before.
     */
    function rageQuit(uint256 amount, bytes32[] calldata proof) external whenNotPaused nonReentrant {
        address user = msg.sender;
        _verifyProof(user, amount, proof);

        UserClaim storage uc = userClaims[user];
        if (uc.rageQuit) revert AlreadyRageQuit();
        if (uc.amountClaimed != 0) revert AlreadyClaimed(); // ensures first action is rage‑quit

        uint256 toUser = (amount * rageQuitBPS) / FEE_DENOMINATOR;
        uint256 forfeited = amount - toUser;

        (uint256 net, uint256 fee) = _applyFee(toUser);

        // --- mark state --- //
        uc.rageQuit = true;
        uc.amountClaimed = amount; // treat as fully claimed
        uc.lastClaimTimestamp = block.timestamp;

        // --- transfers --- //
        if (fee > 0) trust.safeTransfer(protocolTreasury, fee); // fee from user share
        if (forfeited > 0) trust.safeTransfer(protocolTreasury, forfeited); // full forfeited share
        trust.safeTransfer(user, net);

        emit RageQuit(user, net, forfeited, fee);
    }

    function rageQuitAndBond(uint256 amount, uint256 unlockTime, bytes32[] calldata proof)
        external
        whenNotPaused
        nonReentrant
    {
        if (unlockTime <= block.timestamp) revert InvalidUnlockTime();
        address user = msg.sender;
        _verifyProof(user, amount, proof);

        UserClaim storage uc = userClaims[user];
        if (uc.rageQuit) revert AlreadyRageQuit();
        if (uc.amountClaimed != 0) revert AlreadyClaimed(); // ensures first action is rage‑quit

        uint256 toUser = (amount * rageQuitBPS) / FEE_DENOMINATOR;
        uint256 forfeited = amount - toUser;

        (uint256 net, uint256 fee) = _applyFee(toUser);

        // --- mark state --- //
        uc.rageQuit = true;
        uc.amountClaimed = amount; // treat as fully claimed
        uc.lastClaimTimestamp = block.timestamp;

        // --- transfers --- //
        if (fee > 0) trust.safeTransfer(protocolTreasury, fee); // fee from user share
        if (forfeited > 0) trust.safeTransfer(protocolTreasury, forfeited); // full forfeited share

        // --- bond --- //
        (int128 bondedAmount,) = trustBonding.locked(user);

        if (bondedAmount > 0) {
            // if user already has a bond, deposit the newly claimed amount into it
            trustBonding.deposit_for(user, net);
        } else {
            // if user does not have a bond, create a new bond for them
            trustBonding.create_lock_for(user, net, unlockTime);
        }

        emit RageQuitAndBonded(user, net, forfeited, fee, unlockTime);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function getClaimableAmount(address user, uint256 amount) external view returns (uint256) {
        return _getUnclaimedVestedAmount(user, amount);
    }

    /*//////////////////////////////////////////////////////////////
                             ADMINISTRATIVE
    //////////////////////////////////////////////////////////////*/

    function setTrustBonding(address _trustBonding) external onlyOwner {
        if (_trustBonding == address(0)) revert ZeroAddress();
        address old = address(trustBonding);
        trust.forceApprove(old, 0);
        trust.forceApprove(_trustBonding, type(uint256).max);
        trustBonding = TrustBonding(_trustBonding);
        emit TrustBondingUpdated(_trustBonding);
    }

    function setProtocolTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        protocolTreasury = _treasury;
        emit ProtocolTreasuryUpdated(_treasury);
    }

    function setFeeInBPS(uint256 _feeInBPS) external onlyOwner {
        if (_feeInBPS > MAX_FEE_IN_BPS) revert InvalidFeeInBPS();
        feeInBPS = _feeInBPS;
        emit FeeInBPSUpdated(_feeInBPS);
    }

    /**
     * @notice Start timestamp may be pushed **forward** until vesting actually begins.
     */
    function setVestingStartTimestamp(uint256 _newStart) external onlyOwner {
        if (_newStart == 0) revert ZeroValueProvided();
        if (vestingStartTimestamp > 0 && block.timestamp >= vestingStartTimestamp) revert VestingAlreadyStarted();
        if (_newStart <= block.timestamp) revert VestingStartInThePast();
        vestingStartTimestamp = _newStart;
        emit VestingStartTimestampSet(_newStart);
    }

    function setClaimEndTimestamp(uint256 _newEnd) external onlyOwner {
        uint256 minEnd = vestingStartTimestamp + vestingDuration;
        if (_newEnd <= minEnd) revert InvalidClaimEnd();
        if (_newEnd <= block.timestamp) revert VestingEndInThePast();
        if (_newEnd < claimEndTimestamp && block.timestamp >= vestingStartTimestamp) revert CannotShortenClaimWindow();
        if (block.timestamp > claimEndTimestamp) revert ClaimClosed();

        claimEndTimestamp = _newEnd;
        emit ClaimEndSet(_newEnd);
    }

    /**
     * @notice Rescue tokens mistakenly sent / withdraw undistributed tokens.
     */
    function withdrawTokens(address _token, uint256 _amount, address _recipient) external onlyOwner {
        if (_token == address(0)) revert ZeroAddress();
        if (_recipient == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroValueProvided();
        if (_token == address(trust) && block.timestamp <= claimEndTimestamp) revert ClaimOngoing();
        IERC20(_token).safeTransfer(_recipient, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 PAUSING
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
