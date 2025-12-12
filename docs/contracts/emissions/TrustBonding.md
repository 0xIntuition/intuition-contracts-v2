# TrustBonding

## Overview

The **TrustBonding** contract is the core rewards distribution system of the Intuition Protocol V2. It implements a sophisticated vote-escrowed token model (veTRUST) based on Curve Finance's veCRV mechanism, where users lock TRUST tokens to earn time-weighted voting power and receive epoch-based inflationary rewards. The contract introduces a novel utilization-based rewards model that adjusts user rewards based on their participation in the MultiVault ecosystem.

### Purpose and Role in Protocol

- **Staking Hub**: Primary venue for users to lock TRUST tokens and earn rewards
- **Vote Escrow System**: Implements time-weighted veTRUST voting power that decays linearly
- **Rewards Distributor**: Distributes epoch-based TRUST emissions to eligible participants
- **Utilization Incentivizer**: Rewards users who actively use the protocol (deposit into vaults)
- **Governance Weight**: Provides voting power for future protocol governance

### Key Responsibilities

1. **Lock Management**: Handle TRUST deposits with configurable lock durations
2. **veTRUST Calculation**: Compute time-decaying voting power for each user
3. **Rewards Distribution**: Distribute pro-rata emissions based on bonded balance
4. **Utilization Tracking**: Monitor user and system-wide vault utilization
5. **Claim Processing**: Process user reward claims with utilization adjustments

## Contract Information

- **Location**: `src/protocol/emissions/TrustBonding.sol`
- **Inherits**:
  - `ITrustBonding` (interface)
  - `PausableUpgradeable` (emergency pause functionality)
  - `VotingEscrow` (Curve-based vote escrow system)
- **Interface**: `ITrustBonding` (`src/interfaces/ITrustBonding.sol`)
- **Upgradeable**: Yes (UUPS proxy pattern)

### Network Deployments

#### Intuition Mainnet (L3)
- **Address**: `[To be deployed]`
- **Network**: Intuition Mainnet
- **TRUST Token**: Native token on Intuition L3
- **MultiVault**: Utilization data source

#### Intuition Testnet
- **Address**: `[To be deployed]`
- **Network**: Intuition Testnet

## Key Concepts

### Vote-Escrowed TRUST (veTRUST)

The contract distinguishes between **locked** and **bonded** (veTRUST):

**Locked TRUST**:
- Raw amount of TRUST deposited
- Does not decay over time
- Determines maximum possible voting power

**Bonded Balance (veTRUST)**:
- Time-weighted voting power
- Decays linearly until lock expires
- Used for reward distribution calculations

**veTRUST Formula** (from Curve Finance):
```
veTRUST = lockedAmount × (unlockTime - currentTime) / MAXTIME
```

Where:
- `lockedAmount`: Raw TRUST locked
- `unlockTime`: When lock expires
- `currentTime`: Current block timestamp
- `MAXTIME`: 2 years (maximum lock duration)

**Example**:
```
User locks: 1000 TRUST for 2 years
Initial veTRUST: 1000 (full amount)
After 1 year: 500 veTRUST (50% decay)
After 1.5 years: 250 veTRUST (75% decay)
At expiry: 0 veTRUST (100% decay)
```

### Utilization-Based Rewards Model

TrustBonding V2 introduces a **utilization-based rewards model** where rewards are adjusted based on vault usage:

**System Utilization**:
- Measures protocol-wide net deposits into MultiVault per epoch
- Determines how much of max emissions are actually released
- Formula: `systemUtilization = (netDepositsDelta) / (previousEpochClaimedRewards)`

**Personal Utilization**:
- Measures individual user's net deposits per epoch
- Determines user's percentage of eligible rewards they can claim
- Formula: `personalUtilization = (userNetDepositsDelta) / (userPreviousEpochClaimedRewards)`

**Utilization Bounds**:
- Each ratio has a configurable lower bound (floor)
- System floor: Minimum 40% (4000 basis points)
- Personal floor: Minimum 25% (2500 basis points)
- Maximum for both: 100% (10000 basis points)

**Rewards Calculation**:
```solidity
// Step 1: Calculate max epoch emissions (from CoreEmissionsController)
maxEmissions = getEmissionsAtEpoch(epoch)

// Step 2: Apply system utilization
actualEmissions = maxEmissions × systemUtilization / 10000

// Step 3: Calculate user's pro-rata share
userEligibleRewards = (userVeTRUST / totalVeTRUST) × actualEmissions

// Step 4: Apply personal utilization
userClaimableRewards = userEligibleRewards × personalUtilization / 10000
```

### Epoch-Based Reward System

**Reward Lifecycle**:

**Epoch N**:
- Users have locked TRUST, earning veTRUST
- System tracks total veTRUST supply
- Emissions minted and bridged from Base

**Epoch N+1**:
- Epoch N rewards become claimable
- Users call `claimRewards()` to claim epoch N
- Claims affected by epoch N utilization ratios

**Epoch N+2**:
- Epoch N claiming window closes
- Unclaimed epoch N rewards can be reclaimed
- Bridged back to Base for burning

**One-Time Claiming**:
- Users can only claim rewards for previous epoch
- If not claimed in epoch N+1, rewards are forfeited
- "Use it or lose it" model encourages active participation

### Lock Duration Mechanics

**Lock Rules**:
- Minimum: Configurable `MINTIME` (e.g., 2 weeks)
- Maximum: 2 years (`MAXTIME = 2 * 365 * 86400`)
- Lock times rounded down to nearest week
- Cannot create new lock if existing lock present

**Lock Operations**:
1. **Create Lock**: Lock TRUST for specified duration
2. **Increase Amount**: Add more TRUST to existing lock
3. **Increase Time**: Extend lock duration (cannot shorten)
4. **Increase Both**: Add TRUST and extend time simultaneously
5. **Withdraw**: Retrieve TRUST after lock expires

### Smart Contract Whitelist

To prevent tokenization of veTRUST:
- Only EOAs can lock by default
- Smart contracts must be whitelisted
- Admin can add/remove contracts from whitelist
- Prevents liquid veTRUST derivatives

## State Variables

### Constants

```solidity
uint256 public constant YEAR = 365 days;
```
Number of seconds in a year (365 days).

```solidity
uint256 public constant BASIS_POINTS_DIVISOR = 10_000;
```
Divisor for basis point calculations (10000 = 100%).

```solidity
uint256 public constant MINIMUM_SYSTEM_UTILIZATION_LOWER_BOUND = 4000;
```
Minimum system utilization floor: 40% (4000 basis points).

```solidity
uint256 public constant MINIMUM_PERSONAL_UTILIZATION_LOWER_BOUND = 2500;
```
Minimum personal utilization floor: 25% (2500 basis points).

```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```
Role identifier for addresses that can pause the contract.

### State Mappings

```solidity
mapping(uint256 epoch => uint256 totalClaimedRewards) public totalClaimedRewardsForEpoch;
```
Tracks total TRUST claimed by all users for each epoch.

```solidity
mapping(address user => mapping(uint256 epoch => uint256 claimedRewards)) public userClaimedRewardsForEpoch;
```
Tracks TRUST claimed by each user for each epoch. Non-zero indicates user claimed for that epoch.

```solidity
address public multiVault;
```
Address of MultiVault contract (source of utilization data).

```solidity
address public satelliteEmissionsController;
```
Address of SatelliteEmissionsController (source of TRUST for claims).

```solidity
uint256 public systemUtilizationLowerBound;
```
Current system utilization floor in basis points (minimum 4000).

```solidity
uint256 public personalUtilizationLowerBound;
```
Current personal utilization floor in basis points (minimum 2500).

```solidity
address public timelock;
```
Address of governance timelock that can update parameters.

### Inherited State (from VotingEscrow)

```solidity
address public token;
```
Address of TRUST token contract.

```solidity
uint256 public supply;
```
Total amount of TRUST currently locked in contract.

```solidity
mapping(address => LockedBalance) public locked;
```
User lock information:
```solidity
struct LockedBalance {
    int128 amount;  // Locked TRUST amount
    uint256 end;    // Lock expiration timestamp
}
```

```solidity
uint256 public epoch;
```
Global checkpoint epoch (different from emissions epoch).

```solidity
mapping(uint256 => Point) public point_history;
```
Historical voting power checkpoints:
```solidity
struct Point {
    int128 bias;    // Voting power at checkpoint
    int128 slope;   // Rate of decay (-dweight/dt)
    uint256 ts;     // Timestamp of checkpoint
    uint256 blk;    // Block number of checkpoint
}
```

```solidity
mapping(address => Point[1_000_000_000]) public user_point_history;
```
Per-user voting power history.

```solidity
mapping(address => uint256) public user_point_epoch;
```
Latest checkpoint index for each user.

```solidity
mapping(uint256 => int128) public slope_changes;
```
Tracks slope changes at future timestamps.

## Functions

### Initialization

#### `initialize`
```solidity
function initialize(
    address _owner,
    address _timelock,
    address _trustToken,
    uint256 _epochLength,
    address _satelliteEmissionsController,
    uint256 _systemUtilizationLowerBound,
    uint256 _personalUtilizationLowerBound
) external initializer
```
Initializes the TrustBonding contract.

**Parameters**:
- `_owner`: Contract admin (receives DEFAULT_ADMIN_ROLE and PAUSER_ROLE)
- `_timelock`: Governance timelock address
- `_trustToken`: TRUST token contract address
- `_epochLength`: Minimum lock time in seconds
- `_satelliteEmissionsController`: Emissions controller address
- `_systemUtilizationLowerBound`: Initial system utilization floor (≥ 4000)
- `_personalUtilizationLowerBound`: Initial personal utilization floor (≥ 2500)

**Reverts**:
- `TrustBonding_ZeroAddress` - Any address parameter is zero
- `TrustBonding_InvalidUtilizationLowerBound` - Bounds below minimum

---

### Read Functions (Epoch & Emissions)

#### `epochLength`
```solidity
function epochLength() public view returns (uint256)
```
Returns the length of each epoch in seconds.

**Returns**: Epoch duration (e.g., 604800 for weekly)

**Source**: Queries SatelliteEmissionsController

---

#### `epochsPerYear`
```solidity
function epochsPerYear() public view returns (uint256)
```
Returns the number of epochs per year.

**Returns**: Annual epoch count

**Calculation**: `YEAR / epochLength()`

---

#### `currentEpoch`
```solidity
function currentEpoch() public view returns (uint256)
```
Returns the current epoch number.

**Returns**: Current epoch (0-indexed)

---

#### `previousEpoch`
```solidity
function previousEpoch() public view returns (uint256)
```
Returns the previous epoch number.

**Returns**: Previous epoch (current - 1, or 0 if current is 0)

---

#### `epochTimestampEnd`
```solidity
function epochTimestampEnd(uint256 _epoch) public view returns (uint256)
```
Returns when a specific epoch ends.

**Parameters**:
- `_epoch`: Epoch number

**Returns**: Unix timestamp of epoch end

---

#### `epochAtTimestamp`
```solidity
function epochAtTimestamp(uint256 timestamp) public view returns (uint256)
```
Returns the epoch number for a given timestamp.

**Parameters**:
- `timestamp`: Unix timestamp

**Returns**: Epoch number containing timestamp

---

#### `emissionsForEpoch`
```solidity
function emissionsForEpoch(uint256 epoch) public view returns (uint256)
```
Returns actual emissions for an epoch (including system utilization adjustment).

**Parameters**:
- `epoch`: Epoch number

**Returns**: Actual emissions amount (max emissions × system utilization)

**Note**: For epochs < 2, returns max emissions (100% utilization)

---

### Read Functions (Balances & Supply)

#### `totalLocked`
```solidity
function totalLocked() public view returns (uint256)
```
Returns total raw TRUST currently locked.

**Returns**: Total locked TRUST (not veTRUST)

---

#### `totalBondedBalance`
```solidity
function totalBondedBalance() external view returns (uint256)
```
Returns current total veTRUST supply.

**Returns**: Total bonded balance (time-weighted)

---

#### `totalBondedBalanceAtEpochEnd`
```solidity
function totalBondedBalanceAtEpochEnd(uint256 epoch) public view returns (uint256)
```
Returns total veTRUST supply at the end of a specific epoch.

**Parameters**:
- `epoch`: Epoch number (must be ≤ current epoch)

**Returns**: Total veTRUST at epoch end

**Reverts**: `TrustBonding_InvalidEpoch` if epoch in future

---

#### `userBondedBalanceAtEpochEnd`
```solidity
function userBondedBalanceAtEpochEnd(address account, uint256 epoch) public view returns (uint256)
```
Returns user's veTRUST balance at the end of a specific epoch.

**Parameters**:
- `account`: User address
- `epoch`: Epoch number (must be ≤ current epoch)

**Returns**: User's veTRUST at epoch end

**Reverts**:
- `TrustBonding_ZeroAddress` - Account is zero address
- `TrustBonding_InvalidEpoch` - Epoch in future

---

### Read Functions (Rewards & Utilization)

#### `getUserInfo`
```solidity
function getUserInfo(address account) external view returns (UserInfo memory)
```
Returns comprehensive user information.

**Parameters**:
- `account`: User address

**Returns**: `UserInfo` struct:
```solidity
struct UserInfo {
    uint256 personalUtilization;    // Current personal utilization ratio
    uint256 eligibleRewards;        // Rewards after utilization adjustment
    uint256 maxRewards;             // Rewards before utilization adjustment
    uint256 lockedAmount;           // Raw TRUST locked
    uint256 lockEnd;                // Lock expiration timestamp
    uint256 bondedBalance;          // Current veTRUST
}
```

---

#### `getUserCurrentClaimableRewards`
```solidity
function getUserCurrentClaimableRewards(address account) external view returns (uint256)
```
Returns rewards user can claim right now (previous epoch).

**Parameters**:
- `account`: User address

**Returns**: Claimable reward amount

**Note**: Returns 0 if:
- Current epoch is 0
- User already claimed previous epoch
- User has no veTRUST in previous epoch

---

#### `getUserRewardsForEpoch`
```solidity
function getUserRewardsForEpoch(address account, uint256 epoch)
    external view
    returns (uint256 eligibleRewards, uint256 maxRewards)
```
Returns user's rewards for a specific epoch.

**Parameters**:
- `account`: User address
- `epoch`: Epoch to query

**Returns**:
- `eligibleRewards`: Rewards after personal utilization adjustment
- `maxRewards`: Raw pro-rata rewards before adjustment

---

#### `userEligibleRewardsForEpoch`
```solidity
function userEligibleRewardsForEpoch(address account, uint256 epoch) public view returns (uint256)
```
Returns user's raw eligible rewards (before utilization adjustment).

**Parameters**:
- `account`: User address
- `epoch`: Epoch number

**Returns**: Raw pro-rata reward amount

**Calculation**: `(userVeTRUST / totalVeTRUST) × emissionsForEpoch`

---

#### `hasClaimedRewardsForEpoch`
```solidity
function hasClaimedRewardsForEpoch(address account, uint256 epoch) public view returns (bool)
```
Checks if user has claimed rewards for a specific epoch.

**Parameters**:
- `account`: User address
- `epoch`: Epoch number

**Returns**: `true` if claimed, `false` otherwise

---

#### `getSystemUtilizationRatio`
```solidity
function getSystemUtilizationRatio(uint256 epoch) public view returns (uint256)
```
Returns system-wide utilization ratio for an epoch.

**Parameters**:
- `epoch`: Epoch number

**Returns**: Utilization ratio in basis points (e.g., 7500 = 75%)

**Range**: `[systemUtilizationLowerBound, 10000]`

---

#### `getPersonalUtilizationRatio`
```solidity
function getPersonalUtilizationRatio(address account, uint256 epoch) public view returns (uint256)
```
Returns user's personal utilization ratio for an epoch.

**Parameters**:
- `account`: User address
- `epoch`: Epoch number

**Returns**: Utilization ratio in basis points

**Range**: `[personalUtilizationLowerBound, 10000]`

---

#### `getUserApy`
```solidity
function getUserApy(address account) external view returns (uint256 currentApy, uint256 maxApy)
```
Returns user's current and maximum possible APY.

**Parameters**:
- `account`: User address

**Returns**:
- `currentApy`: APY with current utilization (basis points)
- `maxApy`: APY at 100% utilization (basis points)

**Calculation**:
```solidity
rewardsPerYear = currentEpochRewards × epochsPerYear
currentApy = (rewardsPerYear × personalUtilization) / lockedAmount
maxApy = (rewardsPerYear × 10000) / lockedAmount
```

---

#### `getSystemApy`
```solidity
function getSystemApy() external view returns (uint256 currentApy, uint256 maxApy)
```
Returns system-wide current and maximum APY.

**Returns**:
- `currentApy`: APY at current system utilization
- `maxApy`: APY at 100% system utilization

---

#### `getUnclaimedRewardsForEpoch`
```solidity
function getUnclaimedRewardsForEpoch(uint256 epoch) external view returns (uint256)
```
Returns unclaimed rewards for a specific epoch.

**Parameters**:
- `epoch`: Epoch number

**Returns**: Amount of unclaimed TRUST

**Note**: Only epochs ≥ 2 epochs old have reclaimable unclaimed rewards

**Used By**: SatelliteEmissionsController for bridging back to Base

---

### Lock Management Functions

#### `create_lock`
```solidity
function create_lock(uint256 _value, uint256 _unlock_time) external nonReentrant onlyUserOrWhitelist notUnlocked
```
Creates a new lock for the caller.

**Parameters**:
- `_value`: Amount of TRUST to lock
- `_unlock_time`: Unlock timestamp (rounded down to nearest week)

**Requirements**:
- Caller is EOA or whitelisted contract
- No existing lock
- `_value > 0`
- `MINTIME ≤ lockDuration ≤ MAXTIME`

**Emits**: `Deposit(provider, value, locktime, CREATE_LOCK_TYPE, ts)`

**Reverts**:
- "Withdraw old tokens first" - Existing lock present
- "Voting lock must be at least MINTIME"
- "Voting lock can be 2 years max"

---

#### `increase_amount`
```solidity
function increase_amount(uint256 _value) external nonReentrant onlyUserOrWhitelist notUnlocked
```
Adds more TRUST to existing lock without changing unlock time.

**Parameters**:
- `_value`: Additional TRUST to add

**Requirements**:
- Existing lock present
- Lock not expired
- `_value > 0`

**Emits**: `Deposit(provider, value, locktime, INCREASE_LOCK_AMOUNT, ts)`

---

#### `increase_unlock_time`
```solidity
function increase_unlock_time(uint256 _unlock_time) external nonReentrant onlyUserOrWhitelist notUnlocked
```
Extends lock duration without adding TRUST.

**Parameters**:
- `_unlock_time`: New unlock timestamp (must be > current unlock time)

**Requirements**:
- Existing lock present
- Lock not expired
- New time > current unlock time
- New time ≤ now + MAXTIME

**Emits**: `Deposit(provider, 0, locktime, INCREASE_UNLOCK_TIME, ts)`

---

#### `increase_amount_and_time`
```solidity
function increase_amount_and_time(uint256 _value, uint256 _unlock_time)
    external nonReentrant onlyUserOrWhitelist notUnlocked
```
Combines adding TRUST and extending lock duration.

**Parameters**:
- `_value`: Additional TRUST to add (can be 0)
- `_unlock_time`: New unlock timestamp (can be 0)

**Requirements**:
- At least one parameter must be non-zero
- Follows rules of `increase_amount` and `increase_unlock_time`

---

#### `withdraw`
```solidity
function withdraw() external nonReentrant
```
Withdraws all locked TRUST after lock expires.

**Requirements**:
- Lock expired (`block.timestamp ≥ lock.end`)
- OR global unlock enabled

**Emits**: `Withdraw(provider, value, ts)`

**Effects**:
- Sets lock to zero
- Reduces total supply
- Transfers TRUST to caller

---

#### `deposit_for`
```solidity
function deposit_for(address _addr, uint256 _value) external nonReentrant notUnlocked
```
Allows anyone to add TRUST to another user's existing lock.

**Parameters**:
- `_addr`: Address with existing lock
- `_value`: Amount to add

**Requirements**:
- Target address has active lock
- `_value > 0`

**Use Cases**:
- Grants/donations
- Third-party lock boosting
- Protocol incentives

---

### Reward Claiming

#### `claimRewards`
```solidity
function claimRewards(address recipient) external whenNotPaused nonReentrant
```
Claims rewards for the previous epoch.

**Parameters**:
- `recipient`: Address to receive TRUST rewards

**Requirements**:
- Current epoch > 0
- Not already claimed for previous epoch
- User has eligible rewards

**Flow**:
1. Calculate raw eligible rewards for previous epoch
2. Apply personal utilization ratio
3. Mark epoch as claimed for user
4. Transfer TRUST from SatelliteEmissionsController
5. Increment total claimed for epoch

**Emits**: `RewardsClaimed(user, recipient, amount)`

**Reverts**:
- `TrustBonding_NoClaimingDuringFirstEpoch` - Called in epoch 0
- `TrustBonding_NoRewardsToClaim` - No veTRUST or zero after utilization
- `TrustBonding_RewardsAlreadyClaimedForEpoch` - Already claimed
- `TrustBonding_ZeroAddress` - Recipient is zero

**Gas Optimization**: Claim for self to save on transfer gas

---

### Admin Functions

#### `pause`
```solidity
function pause() external onlyRole(PAUSER_ROLE)
```
Pauses the contract, preventing claims and locks.

**Access**: Requires `PAUSER_ROLE`

---

#### `unpause`
```solidity
function unpause() external onlyRole(DEFAULT_ADMIN_ROLE)
```
Unpauses the contract.

**Access**: Requires `DEFAULT_ADMIN_ROLE`

---

#### `setMultiVault`
```solidity
function setMultiVault(address _multiVault) external onlyTimelock
```
Updates MultiVault address (source of utilization data).

**Parameters**:
- `_multiVault`: New MultiVault address

**Access**: Only timelock

**Emits**: `MultiVaultSet(_multiVault)`

**Reverts**: `TrustBonding_ZeroAddress`

---

#### `setTimelock`
```solidity
function setTimelock(address _timelock) external onlyTimelock
```
Updates timelock address.

**Parameters**:
- `_timelock`: New timelock address

**Access**: Only current timelock

**Emits**: `TimelockSet(_timelock)`

---

#### `updateSatelliteEmissionsController`
```solidity
function updateSatelliteEmissionsController(address _satelliteEmissionsController) external onlyTimelock
```
Updates SatelliteEmissionsController address.

**Parameters**:
- `_satelliteEmissionsController`: New controller address

**Access**: Only timelock

**Emits**: `SatelliteEmissionsControllerSet(_satelliteEmissionsController)`

---

#### `updateSystemUtilizationLowerBound`
```solidity
function updateSystemUtilizationLowerBound(uint256 newLowerBound) external onlyTimelock
```
Updates the minimum system utilization ratio.

**Parameters**:
- `newLowerBound`: New floor in basis points (must be ≥ 4000 and ≤ 10000)

**Access**: Only timelock

**Emits**: `SystemUtilizationLowerBoundUpdated(newLowerBound)`

**Reverts**: `TrustBonding_InvalidUtilizationLowerBound`

---

#### `updatePersonalUtilizationLowerBound`
```solidity
function updatePersonalUtilizationLowerBound(uint256 newLowerBound) external onlyTimelock
```
Updates the minimum personal utilization ratio.

**Parameters**:
- `newLowerBound`: New floor in basis points (must be ≥ 2500 and ≤ 10000)

**Access**: Only timelock

**Emits**: `PersonalUtilizationLowerBoundUpdated(newLowerBound)`

---

### VotingEscrow Admin Functions (Inherited)

#### `add_to_whitelist`
```solidity
function add_to_whitelist(address addr) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Whitelists a smart contract to create locks.

---

#### `remove_from_whitelist`
```solidity
function remove_from_whitelist(address addr) external onlyRole(DEFAULT_ADMIN_ROLE)
```
Removes a contract from whitelist.

---

#### `unlock`
```solidity
function unlock() external onlyRole(DEFAULT_ADMIN_ROLE)
```
Global unlock - allows all users to withdraw regardless of lock time.

**Warning**: Irreversible emergency function

---

## Events

### `RewardsClaimed`
```solidity
event RewardsClaimed(address indexed user, address indexed recipient, uint256 amount)
```
Emitted when a user claims rewards.

---

### `TimelockSet`
```solidity
event TimelockSet(address indexed timelock)
```
Emitted when timelock address is updated.

---

### `MultiVaultSet`
```solidity
event MultiVaultSet(address indexed multiVault)
```
Emitted when MultiVault address is updated.

---

### `SatelliteEmissionsControllerSet`
```solidity
event SatelliteEmissionsControllerSet(address indexed satelliteEmissionsController)
```
Emitted when SatelliteEmissionsController is updated.

---

### `SystemUtilizationLowerBoundUpdated`
```solidity
event SystemUtilizationLowerBoundUpdated(uint256 newLowerBound)
```
Emitted when system utilization floor is changed.

---

### `PersonalUtilizationLowerBoundUpdated`
```solidity
event PersonalUtilizationLowerBoundUpdated(uint256 newLowerBound)
```
Emitted when personal utilization floor is changed.

---

## Errors

### `TrustBonding_ClaimableProtocolFeesExceedBalance`
Legacy error (unused in current implementation).

---

### `TrustBonding_InvalidEpoch`
Thrown when querying invalid epoch number.

---

### `TrustBonding_InvalidUtilizationLowerBound`
Thrown when utilization bound is out of valid range.

---

### `TrustBonding_InvalidStartTimestamp`
Legacy error (unused).

---

### `TrustBonding_NoClaimingDuringFirstEpoch`
Thrown when attempting to claim in epoch 0.

---

### `TrustBonding_NoRewardsToClaim`
Thrown when user has no eligible rewards.

---

### `TrustBonding_OnlyTimelock`
Thrown when non-timelock calls timelock-only function.

---

### `TrustBonding_RewardsAlreadyClaimedForEpoch`
Thrown when user attempts to claim same epoch twice.

---

### `TrustBonding_ZeroAddress`
Thrown when zero address provided.

---

## Access Control

### Roles

**`DEFAULT_ADMIN_ROLE`**:
- Unpause contract
- Whitelist contracts
- Global unlock (emergency)
- Grant/revoke roles

**`PAUSER_ROLE`**:
- Pause contract

**Timelock** (custom modifier):
- Update MultiVault
- Update SatelliteEmissionsController
- Update utilization bounds
- Update timelock address

---

## Usage Examples

### TypeScript (VIEM)

```typescript
import { createPublicClient, createWalletClient, http, parseEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { intuitionMainnet } from './chains';

const TRUST_BONDING_ADDRESS = '0x...';

const TRUST_BONDING_ABI = [
  // Lock management
  {
    name: 'create_lock',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_value', type: 'uint256' },
      { name: '_unlock_time', type: 'uint256' }
    ],
    outputs: [],
  },
  // Rewards
  {
    name: 'getUserCurrentClaimableRewards',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'claimRewards',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'recipient', type: 'address' }],
    outputs: [],
  },
  // Info
  {
    name: 'getUserInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'personalUtilization', type: 'uint256' },
          { name: 'eligibleRewards', type: 'uint256' },
          { name: 'maxRewards', type: 'uint256' },
          { name: 'lockedAmount', type: 'uint256' },
          { name: 'lockEnd', type: 'uint256' },
          { name: 'bondedBalance', type: 'uint256' },
        ],
      },
    ],
  },
] as const;

const publicClient = createPublicClient({
  chain: intuitionMainnet,
  transport: http(),
});

const account = privateKeyToAccount('0x...');
const walletClient = createWalletClient({
  account,
  chain: intuitionMainnet,
  transport: http(),
});

// Example 1: Create 2-year lock
async function createMaxLock(amount: bigint) {
  const twoYearsFromNow = BigInt(Math.floor(Date.now() / 1000) + 2 * 365 * 86400);

  const { request } = await publicClient.simulateContract({
    account,
    address: TRUST_BONDING_ADDRESS,
    abi: TRUST_BONDING_ABI,
    functionName: 'create_lock',
    args: [amount, twoYearsFromNow],
  });

  const hash = await walletClient.writeContract(request);
  console.log(`Lock created: ${hash}`);

  return publicClient.waitForTransactionReceipt({ hash });
}

// Example 2: Check user info
async function checkUserStatus(userAddress: `0x${string}`) {
  const info = await publicClient.readContract({
    address: TRUST_BONDING_ADDRESS,
    abi: TRUST_BONDING_ABI,
    functionName: 'getUserInfo',
    args: [userAddress],
  });

  console.log(`User ${userAddress}:`);
  console.log(`  Locked: ${info.lockedAmount} wei`);
  console.log(`  veTRUST: ${info.bondedBalance} wei`);
  console.log(`  Lock expires: ${new Date(Number(info.lockEnd) * 1000).toISOString()}`);
  console.log(`  Utilization: ${Number(info.personalUtilization) / 100}%`);
  console.log(`  Claimable: ${info.eligibleRewards} wei`);

  return info;
}

// Example 3: Claim rewards
async function claimMyRewards() {
  const claimable = await publicClient.readContract({
    address: TRUST_BONDING_ADDRESS,
    abi: TRUST_BONDING_ABI,
    functionName: 'getUserCurrentClaimableRewards',
    args: [account.address],
  });

  if (claimable === 0n) {
    console.log('No rewards to claim');
    return null;
  }

  console.log(`Claiming ${claimable} wei...`);

  const { request } = await publicClient.simulateContract({
    account,
    address: TRUST_BONDING_ADDRESS,
    abi: TRUST_BONDING_ABI,
    functionName: 'claimRewards',
    args: [account.address],
  });

  const hash = await walletClient.writeContract(request);
  return publicClient.waitForTransactionReceipt({ hash });
}

// Run examples
await createMaxLock(parseEther('1000'));
await checkUserStatus(account.address);
await claimMyRewards();
```

### Python (web3.py)

```python
from web3 import Web3
from eth_account import Account
import json
import time

w3 = Web3(Web3.HTTPProvider('https://rpc.intuit.network'))

TRUST_BONDING_ADDRESS = '0x...'

TRUST_BONDING_ABI = json.loads('''[
  {
    "name": "create_lock",
    "type": "function",
    "stateMutability": "nonpayable",
    "inputs": [
      {"name": "_value", "type": "uint256"},
      {"name": "_unlock_time", "type": "uint256"}
    ],
    "outputs": []
  },
  {
    "name": "getUserInfo",
    "type": "function",
    "stateMutability": "view",
    "inputs": [{"name": "account", "type": "address"}],
    "outputs": [
      {
        "type": "tuple",
        "components": [
          {"name": "personalUtilization", "type": "uint256"},
          {"name": "eligibleRewards", "type": "uint256"},
          {"name": "maxRewards", "type": "uint256"},
          {"name": "lockedAmount", "type": "uint256"},
          {"name": "lockEnd", "type": "uint256"},
          {"name": "bondedBalance", "type": "uint256"}
        ]
      }
    ]
  },
  {
    "name": "claimRewards",
    "type": "function",
    "stateMutability": "nonpayable",
    "inputs": [{"name": "recipient", "type": "address"}],
    "outputs": []
  }
]''')

bonding = w3.eth.contract(address=TRUST_BONDING_ADDRESS, abi=TRUST_BONDING_ABI)

# Example 1: Lock TRUST
def create_lock(amount_eth, duration_days, private_key):
    account = Account.from_key(private_key)

    unlock_time = int(time.time()) + (duration_days * 86400)
    # Round down to nearest week
    unlock_time = (unlock_time // (7 * 86400)) * (7 * 86400)

    amount_wei = w3.to_wei(amount_eth, 'ether')

    txn = bonding.functions.create_lock(amount_wei, unlock_time).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 500000,
        'gasPrice': w3.eth.gas_price,
    })

    signed = account.sign_transaction(txn)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)

    print(f"Lock created: {tx_hash.hex()}")
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    return receipt

# Example 2: Get user info
def get_user_info(user_address):
    info = bonding.functions.getUserInfo(user_address).call()

    print(f"\nUser: {user_address}")
    print(f"  Locked: {w3.from_wei(info[3], 'ether')} TRUST")
    print(f"  veTRUST: {w3.from_wei(info[5], 'ether')}")
    print(f"  Lock expires: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(info[4]))}")
    print(f"  Utilization: {info[0] / 100:.2f}%")
    print(f"  Claimable: {w3.from_wei(info[1], 'ether')} TRUST")

    return info

# Example 3: Claim rewards
def claim_rewards(recipient, private_key):
    account = Account.from_key(private_key)

    txn = bonding.functions.claimRewards(recipient).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 300000,
        'gasPrice': w3.eth.gas_price,
    })

    signed = account.sign_transaction(txn)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)

    print(f"Claiming rewards: {tx_hash.hex()}")
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    return receipt
```

### Solidity

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { ITrustBonding, UserInfo } from "src/interfaces/ITrustBonding.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title AutoCompounder
 * @notice Automatically claims and re-locks TrustBonding rewards
 */
contract AutoCompounder {
    ITrustBonding public immutable trustBonding;
    IERC20 public immutable trust;
    mapping(address => bool) public autoCompoundEnabled;

    event AutoCompounded(address indexed user, uint256 amount);

    constructor(address _trustBonding, address _trust) {
        trustBonding = ITrustBonding(_trustBonding);
        trust = IERC20(_trust);
    }

    function enableAutoCompound() external {
        autoCompoundEnabled[msg.sender] = true;
    }

    function disableAutoCompound() external {
        autoCompoundEnabled[msg.sender] = false;
    }

    /**
     * @notice Claims and re-locks rewards for a user
     */
    function claimAndCompound(address user) external {
        require(autoCompoundEnabled[user], "Auto-compound not enabled");

        uint256 claimable = trustBonding.getUserCurrentClaimableRewards(user);
        if (claimable == 0) return;

        // Claim to this contract
        trustBonding.claimRewards(address(this));

        // Approve and deposit back into user's lock
        trust.approve(address(trustBonding), claimable);
        trustBonding.deposit_for(user, claimable);

        emit AutoCompounded(user, claimable);
    }
}
```

---

## Integration Notes

### MultiVault Integration

TrustBonding depends on MultiVault for utilization data:

```solidity
// Query user's net deposits in epoch
int256 userUtilization = IMultiVault(multiVault).getUserUtilizationInEpoch(user, epoch);

// Query total net deposits in epoch
int256 totalUtilization = IMultiVault(multiVault).getTotalUtilizationForEpoch(epoch);
```

### Epoch Synchronization

Must maintain identical epoch schedules with emissions controllers:
- Same start timestamp
- Same epoch length
- Same reduction schedule

### Lock Time Rounding

All unlock times rounded down to nearest week:
```solidity
unlock_time = (unlock_time / WEEK) * WEEK
```

---

## Gas Considerations

| Operation | Estimated Gas |
|-----------|--------------|
| `create_lock` | ~350,000 |
| `increase_amount` | ~250,000 |
| `claimRewards` | ~200,000 |
| `withdraw` | ~180,000 |
| Read functions | Free (view) |

---

## Related Contracts

- **[SatelliteEmissionsController](./SatelliteEmissionsController.md)**: Provides TRUST for claims
- **[MultiVault](/docs/contracts/core/MultiVault.md)**: Provides utilization data
- **[CoreEmissionsController](./CoreEmissionsController.md)**: Shared epoch logic
- **[Trust](/docs/contracts/core/Trust.md)**: Token being locked

---

## See Also

- [Emissions System](/docs/concepts/emissions-system.md)
- [Vote Escrow Model](/docs/concepts/vote-escrow.md)
- [Utilization Mechanics](/docs/concepts/utilization.md)
- [Staking Guide](/docs/guides/staking-guide.md)
