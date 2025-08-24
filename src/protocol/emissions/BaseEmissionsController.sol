// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import {
    MetaERC20Dispatcher,
    FinalityState,
    IMetaERC20Hub,
    IIGP,
    IMetalayerRouter
} from "src/protocol/emissions/MetaERC20Dispatcher.sol";

interface ITrustToken {
    function mint(address to, uint256 amount) external;
}

/**
 * @title  BaseEmissionsController
 * @author 0xIntuition
 * @notice Controls the release of TRUST tokens by sending mint requests to the TRUST token.
 */
contract BaseEmissionsController is AccessControlUpgradeable, ReentrancyGuardUpgradeable, MetaERC20Dispatcher {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Access control role for controllers who can mint tokens
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /// @notice Initial supply of TRUST tokens (1 billion)
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;

    /// @notice Number of seconds in a year
    uint256 public constant ONE_YEAR = 365 days;

    /// @notice Number of weeks in a year
    uint256 public constant WEEKS_PER_YEAR = 52;

    /// @notice Basis points divisor
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    /// @notice Maximum possible annual emission of Trust tokens (7.5% of initial supply)
    uint256 public constant MAX_POSSIBLE_ANNUAL_EMISSION = (INITIAL_SUPPLY * 750) / BASIS_POINTS_DIVISOR; // 75M tokens

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Trust token contract address
    address public trustToken;

    // @notice MetaLayer Hub for the Trust token.
    address public metaERC20Hub;

    /// @notice Recipient domain for bridging Trust tokens to the satellite chain
    uint32 public recipientDomain;

    /// @notice Address of the emissions controller on the satellite chain
    address public satelliteEmissionsController;

    /// @notice Tracks the start of the current annual period
    uint256 public annualPeriodStartTime;

    /// @notice Tracks the amount minted in the current annual period
    uint256 public annualMintedAmount;

    /// @notice Start time of the current epoch
    uint256 public epochStartTime;

    /// @notice Amount minted in the current epoch
    uint256 public epochMintedAmount;

    /// @notice Maximum annual emission of Trust tokens
    uint256 public maxAnnualEmission;

    /// @notice Maximum emission per epoch in basis points of max annual emission
    uint256 public maxEmissionPerEpochBasisPoints;

    /// @notice Reduction percentage per year in basis points of max annual emission
    uint256 public annualReductionBasisPoints;

    /// @notice Epoch duration in TrustBonding
    uint256 public epochDuration;

    /// @dev Gap for upgrade safety
    uint256[50] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when the maximum annual emission is changed
     * @param newMaxAnnualEmission New maximum annual emission
     */
    event MaxAnnualEmissionChanged(uint256 indexed newMaxAnnualEmission);

    /**
     * @notice Event emitted when the maximum emission per epoch is changed
     * @param newMaxEmissionPerEpochBasisPoints New maximum emission per epoch in basis points
     */
    event MaxEmissionPerEpochBasisPointsChanged(uint256 indexed newMaxEmissionPerEpochBasisPoints);

    /**
     * @notice Event emitted when the annual reduction basis points is changed
     * @param newAnnualReductionBasisPoints New annual reduction basis points
     */
    event AnnualReductionBasisPointsChanged(uint256 indexed newAnnualReductionBasisPoints);

    /**
     * @notice Event emitted when Trust tokens are minted
     * @param to Address that received the minted Trust tokens
     * @param amount Amount of Trust tokens minted
     */
    event TrustMinted(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error BaseEmissionsController_ZeroAddress();
    error BaseEmissionsController_InvalidMaxAnnualEmission();
    error BaseEmissionsController_InvalidMaxEmissionPerEpochBasisPoints();
    error BaseEmissionsController_InvalidAnnualReductionBasisPoints();
    error BaseEmissionsController_InvalidStartTimestamp();
    error BaseEmissionsController_InvalidEpochDuration();
    error BaseEmissionsController_InsufficientGasPayment();
    error BaseEmissionsController_AnnualMintingLimitExceeded();

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                                 INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Reinitializes the Trust contract
     * @param _admin Admin address (multisig)
     * @param _minter Initial minter address
     * @param _metaERC20Hub Address of the TRUST token contract
     * @param _trustToken Address of the TRUST token contract
     * @param _maxAnnualEmission Maximum annual emission of Trust tokens
     * @param _maxEmissionPerEpochBasisPoints Maximum emission per epoch
     * @param _annualReductionBasisPoints Annual reduction basis points
     * @param _startTimestamp Start timestamp for the epoch and annual period tracking
     * @param _epochDuration Duration of each epoch in seconds
     */
    function initialize(
        address _admin,
        address _minter,
        address _trustToken,
        address _metaERC20Hub,
        address _satelliteEmissionsController,
        uint32 _recipientDomain,
        uint256 _maxAnnualEmission,
        uint256 _maxEmissionPerEpochBasisPoints,
        uint256 _annualReductionBasisPoints,
        uint256 _startTimestamp,
        uint256 _epochDuration
    )
        external
        initializer
    {
        if (_admin == address(0) || _minter == address(0) || _trustToken == address(0)) {
            revert BaseEmissionsController_ZeroAddress();
        }

        if (_maxAnnualEmission > MAX_POSSIBLE_ANNUAL_EMISSION) {
            revert BaseEmissionsController_InvalidMaxAnnualEmission();
        }

        if (_maxEmissionPerEpochBasisPoints > BASIS_POINTS_DIVISOR) {
            revert BaseEmissionsController_InvalidMaxEmissionPerEpochBasisPoints();
        }

        if (_annualReductionBasisPoints >= BASIS_POINTS_DIVISOR) {
            revert BaseEmissionsController_InvalidAnnualReductionBasisPoints();
        }

        if (_startTimestamp < block.timestamp) {
            revert BaseEmissionsController_InvalidStartTimestamp();
        }

        if (_epochDuration == 0) {
            revert BaseEmissionsController_InvalidEpochDuration();
        }

        // Initialize the AccessControl and ReentrancyGuard contracts
        __AccessControl_init();
        __ReentrancyGuard_init();

        // Assign the roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(CONTROLLER_ROLE, _minter);

        // Set the Trust token contract address
        trustToken = _trustToken;

        // Bridging configurations
        metaERC20Hub = _metaERC20Hub;
        satelliteEmissionsController = _satelliteEmissionsController;
        recipientDomain = _recipientDomain;

        // Initialize annual minting variables
        annualPeriodStartTime = _startTimestamp;
        maxAnnualEmission = _maxAnnualEmission;

        // Initialize epoch variables
        epochStartTime = _startTimestamp;
        maxEmissionPerEpochBasisPoints = _maxEmissionPerEpochBasisPoints;

        // Initialize emission reduction variables
        annualReductionBasisPoints = _annualReductionBasisPoints;

        // Set the epoch duration
        epochDuration = _epochDuration;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total mintable amount for the current annual period
     * @return Total mintable amount for the current annual period after subtracting the
     *         amount already minted in the current annual period
     */
    function getTotalMintableForCurrentAnnualPeriod() external view returns (uint256) {
        uint256 currentTime = block.timestamp;

        if (currentTime >= annualPeriodStartTime + ONE_YEAR) {
            return 0;
        }

        uint256 annualMaxMintAmount = maxAnnualEmission;
        uint256 mintableAmount = annualMaxMintAmount - annualMintedAmount;

        return mintableAmount;
    }

    /**
     * @notice Returns the total mintable amount for the current epoch
     * @return Total mintable amount for the current epoch after subtracting the
     *         amount already minted in the current epoch
     */
    function getTotalMintableForCurrentEpoch() external view returns (uint256) {
        uint256 epochEndTime = epochStartTime + epochDuration;
        uint256 currentTime = block.timestamp;

        if (currentTime >= epochEndTime) {
            return 0;
        }

        uint256 epochMaxMintAmount = getMaxMintAmountPerEpoch();
        uint256 mintableAmount = epochMaxMintAmount - epochMintedAmount;

        return mintableAmount;
    }

    /**
     * @notice Returns the maximum mint amount per epoch in Trust tokens for the current epoch
     * @return Maximum mint amount per epoch in Trust tokens
     */
    function getMaxMintAmountPerEpoch() public view returns (uint256) {
        uint256 epochMaxMintAmount = (maxAnnualEmission * maxEmissionPerEpochBasisPoints) / BASIS_POINTS_DIVISOR;
        return epochMaxMintAmount;
    }

    /**
     * @notice Returns the annual emission reduction amount in Trust tokens for the current year
     * @return Trust token emission reduction amount
     */
    function getAnnualReductionAmount() public view returns (uint256) {
        uint256 reductionAmount = (maxAnnualEmission * annualReductionBasisPoints) / BASIS_POINTS_DIVISOR;
        return reductionAmount;
    }

    /**
     * @notice Returns the maximum weekly mint amount for the current annual period
     * @return Maximum weekly mint amount in Trust tokens
     */
    function getMaxWeeklyMintAmount() public view returns (uint256) {
        return maxAnnualEmission / WEEKS_PER_YEAR;
    }

    /**
     * @notice Returns the new max annual emission after applying reduction
     * @return New max annual emission after reduction
     */
    function getNewMaxAnnualEmissionAfterReduction() public view returns (uint256) {
        uint256 reductionAmount = getAnnualReductionAmount();
        return maxAnnualEmission - reductionAmount;
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the maximum emission per epoch in basis points of max annual emission
     * @param newMaxEmissionPerEpochBasisPoints New maximum emission per epoch in basis points
     */
    function setMaxEmissionPerEpochBasisPoints(uint256 newMaxEmissionPerEpochBasisPoints)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newMaxEmissionPerEpochBasisPoints > BASIS_POINTS_DIVISOR) {
            revert BaseEmissionsController_InvalidMaxEmissionPerEpochBasisPoints();
        }

        maxEmissionPerEpochBasisPoints = newMaxEmissionPerEpochBasisPoints;

        emit MaxEmissionPerEpochBasisPointsChanged(newMaxEmissionPerEpochBasisPoints);
    }

    /**
     * @notice Sets the annual reduction percentage in basis points of max annual emission
     * @param newAnnualReductionBasisPoints New annual reduction percentage
     */
    function setAnnualReductionBasisPoints(uint256 newAnnualReductionBasisPoints)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newAnnualReductionBasisPoints >= BASIS_POINTS_DIVISOR) {
            revert BaseEmissionsController_InvalidAnnualReductionBasisPoints();
        }

        annualReductionBasisPoints = newAnnualReductionBasisPoints;

        emit AnnualReductionBasisPointsChanged(newAnnualReductionBasisPoints);
    }

    /*//////////////////////////////////////////////////////////////
                             MINTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint new energy tokens to an address
     */
    function mint() external payable nonReentrant onlyRole(CONTROLLER_ROLE) {
        uint256 epochMaxMintAmount = _updateMinting();
        ITrustToken(trustToken).mint(address(this), epochMaxMintAmount);

        IIGP igp = IIGP(IMetalayerRouter(IMetaERC20Hub(metaERC20Hub).metalayerRouter()).igp());
        uint256 gasLimit = igp.quoteGasPayment(recipientDomain, GAS_CONSTANT + 125_000);

        if (msg.value < gasLimit) {
            revert BaseEmissionsController_InsufficientGasPayment();
        }

        _bridgeTokens(
            metaERC20Hub,
            recipientDomain,
            bytes32(uint256(uint160(satelliteEmissionsController))),
            epochMaxMintAmount,
            gasLimit,
            FinalityState.INSTANT
        );

        if (msg.value > gasLimit) {
            payable(msg.sender).transfer(msg.value - gasLimit);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to update annual and epoch minting amounts
     */
    function _updateMinting() internal returns (uint256) {
        // Adjust maxAnnualEmission annually
        if (block.timestamp >= annualPeriodStartTime + ONE_YEAR) {
            // Reduce maxAnnualEmission by annualReductionBasisPoints (percentage of current amount)
            uint256 reductionAmount = getAnnualReductionAmount();
            maxAnnualEmission -= reductionAmount;

            // Emit an event for the change in maxAnnualEmission
            emit MaxAnnualEmissionChanged(maxAnnualEmission);

            // Reset the annual minted amount
            annualMintedAmount = 0;

            // Update the annual period start time to the exact anniversary
            annualPeriodStartTime += ONE_YEAR;
        }

        // Calculate maximum emission per epoch
        uint256 epochMaxMintAmount = getMaxMintAmountPerEpoch();

        // Ensure that the annual minted amount plus the new amount does not exceed the maximum
        if (annualMintedAmount + epochMaxMintAmount > maxAnnualEmission) {
            revert BaseEmissionsController_AnnualMintingLimitExceeded();
        }

        // Update the annual minted amount
        annualMintedAmount += epochMaxMintAmount;

        // Epoch minting logic
        if (block.timestamp >= epochStartTime + epochDuration) {
            epochStartTime = block.timestamp;
            epochMintedAmount = 0;
        }

        // Update the epoch minted amount
        epochMintedAmount += epochMaxMintAmount;

        return epochMaxMintAmount;
    }
}
