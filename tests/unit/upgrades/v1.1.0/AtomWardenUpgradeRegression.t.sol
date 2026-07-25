// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { MultiVault } from "src/protocol/MultiVault.sol";
import { TrustBonding } from "src/protocol/emissions/TrustBonding.sol";
import { AtomWarden } from "src/protocol/wallet/AtomWarden.sol";
import { AtomWallet } from "src/protocol/wallet/AtomWallet.sol";
import { AtomWalletFactory } from "src/protocol/wallet/AtomWalletFactory.sol";
import { IAtomWarden } from "src/interfaces/IAtomWarden.sol";

/// @title  AtomWarden v1.1.0 Upgrade Regression
/// @notice Fork-based regression for the consolidated `reinitialize()` quorum bootstrap
///         and `MultiVault.computeAtomWalletAddr` determinism across the AtomWarden +
///         AtomWallet beacon upgrade. Lives separately from `CoreMainnetUpgradeRegression`
///         so the AtomWarden surface (storage, role-hooks, signed claims) can be exercised
///         independently of the broader core unison upgrade.
/// @dev    Uses the same intuition-mainnet fork pin as the core regression so post-upgrade
///         calldata semantics line up. Part of the v1.1.0 pre-audit upgrade-regression set
///         under `tests/unit/upgrades/v1.1.0/` (mirrors the v1.0.2 grouping of
///         `CoreMainnetUpgradeRegression`).
/// @custom:upgrade v1.1.0
contract AtomWardenUpgradeRegressionTest is Test {
    bytes32 internal constant EIP1967_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant CLAIM_AUTHORIZATION_TYPEHASH = keccak256(
        "ClaimAuthorization(address claimant,bytes32 atomId,uint8 claimType,uint256 nonce,uint48 validAfter,uint48 validUntil)"
    );

    address internal constant UPGRADES_TIMELOCK = 0x321e5d4b20158648dFd1f360A79CAFc97190bAd1;
    address internal constant ADMIN_SAFE = 0xbeA18ab4c83a12be25f8AA8A10D8747A07Cdc6eb;

    address internal constant MULTIVAULT_PROXY = 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e;
    address internal constant TRUST_BONDING_PROXY = 0x635bBD1367B66E7B16a21D6E5A63C812fFC00617;
    address internal constant ATOM_WARDEN_PROXY = 0x98C9BCecf318d0D1409Bf81Ea3551b629fAEC165;
    address internal constant ATOM_WARDEN_PROXY_ADMIN = 0xf548dbDd7a18Ee9d91106b3b6967770b504aeE2A;
    address internal constant ATOM_WALLET_BEACON = 0xC23cD55CF924b3FE4b97deAA0EAF222a5082A1FF;
    address internal constant ATOM_WALLET_FACTORY = 0x33827373a7D1c7C78a01094071C2f6CE74253B9B;

    uint256 internal constant INTUITION_FORK_BLOCK = 3_270_618;
    uint256 internal constant BASE_BLOCK_NUMBER = 43_451_628;

    AtomWarden internal atomWarden;
    AtomWalletFactory internal atomWalletFactory;
    MultiVault internal multiVault;

    function setUp() external {
        vm.createSelectFork("intuition", INTUITION_FORK_BLOCK);
        // Match the core regression's block-number alignment — veTRUST checkpoints store
        // Base L2 block numbers and treat unrolled values as "future", which breaks reads
        // executed against the live state without this roll.
        vm.roll(BASE_BLOCK_NUMBER);
        // Some downstream views in MultiVault need epoch >= 1 to avoid the bootstrap branch.
        TrustBonding trustBonding = TrustBonding(payable(TRUST_BONDING_PROXY));
        if (trustBonding.currentEpoch() == 0) {
            vm.warp(trustBonding.epochTimestampEnd(0) + 1);
        }

        atomWarden = AtomWarden(payable(ATOM_WARDEN_PROXY));
        atomWalletFactory = AtomWalletFactory(ATOM_WALLET_FACTORY);
        multiVault = MultiVault(payable(MULTIVAULT_PROXY));
    }

    /*//////////////////////////////////////////////////////////////
                    REINITIALIZE QUORUM BOOTSTRAP
    //////////////////////////////////////////////////////////////*/

    /// @dev Reinitialize values used by every test in this file. Mirrors the
    ///      IntuitionDeployAndSetup operational defaults so the post-upgrade state
    ///      is realistic and the assertions below are intent-revealing.
    uint256 internal constant REINIT_CLAIM_WINDOW = 7 days;
    uint256 internal constant REINIT_MIN_FEE_THRESHOLD = 0.25 ether;
    uint256 internal constant REINIT_SIGNATURE_THRESHOLD = 1;
    uint48 internal constant REINIT_MAX_VALID_AFTER = uint48(1 hours);
    uint48 internal constant REINIT_MAX_VALID_UNTIL = uint48(2 days);
    /// @dev Armed (nonzero) in this suite so the regression exercises live cap accounting
    ///      on the fork; production defaults may ship with the cap disabled instead.
    uint256 internal constant REINIT_MAX_CLAIMS_PER_WINDOW = 100;
    uint256 internal constant REINIT_CLAIM_CAP_WINDOW = 1 days;

    /// @dev Contract-own storage slot indices (OZ parents use ERC-7201 namespaced storage,
    ///      so AtomWarden's own variables start at slot 0). The four cap slots are the
    ///      v1.1.0 tail append — verified against `forge inspect AtomWarden storageLayout`.
    uint256 internal constant MAX_CLAIMS_PER_WINDOW_SLOT = 7;
    uint256 internal constant CLAIM_CAP_WINDOW_SLOT = 8;
    uint256 internal constant CURRENT_CLAIM_WINDOW_ID_SLOT = 9;
    uint256 internal constant CLAIMS_IN_WINDOW_SLOT = 10;

    function test_reinitialize_bootstrapsQuorumStateAndPreservesMultiVault() external {
        address preMultiVault = atomWarden.multiVault();

        _upgradeAtomWardenAndReinitialize();

        // Address-bearing slot survives the implementation switch — `multiVault` was set
        // by the v1 init and the consolidated v2 reinit does NOT overwrite it.
        assertEq(atomWarden.multiVault(), preMultiVault, "multiVault must persist across reinit");

        // Reinitialize now sets the operational config atomically from its args; the
        // sentinel-default era is gone. Admin can still rotate via the regular setters.
        assertEq(atomWarden.claimWindow(), REINIT_CLAIM_WINDOW, "claimWindow must match reinit arg");
        assertEq(atomWarden.minFeeThreshold(), REINIT_MIN_FEE_THRESHOLD, "minFeeThreshold must match reinit arg");

        // Quorum state: threshold from arg / signerCount=0 immediately after reinit. No
        // SIGNER_ROLE grants pre-existed on-chain, so the role-hook overrides have nothing
        // to count yet.
        assertEq(
            atomWarden.signatureThreshold(), REINIT_SIGNATURE_THRESHOLD, "signatureThreshold must match reinit arg"
        );
        assertEq(atomWarden.signerCount(), 0, "signerCount must start at 0");

        // Time-window caps land atomically with the reinit args.
        assertEq(atomWarden.maxValidAfter(), REINIT_MAX_VALID_AFTER, "maxValidAfter must match reinit arg");
        assertEq(atomWarden.maxValidUntil(), REINIT_MAX_VALID_UNTIL, "maxValidUntil must match reinit arg");

        // Authorized-claim cap config lands atomically with the reinit args; window
        // accounting starts anchored at the current window with a zero count.
        assertEq(atomWarden.maxClaimsPerWindow(), REINIT_MAX_CLAIMS_PER_WINDOW, "maxClaimsPerWindow must match arg");
        assertEq(atomWarden.claimCapWindow(), REINIT_CLAIM_CAP_WINDOW, "claimCapWindow must match reinit arg");
        assertEq(
            atomWarden.currentClaimWindowId(),
            block.timestamp / REINIT_CLAIM_CAP_WINDOW,
            "currentClaimWindowId must anchor to the live window"
        );
        assertEq(atomWarden.claimsInWindow(), 0, "claimsInWindow must start at 0");

        // Slot-level triangulation for the four appended cap slots: the raw storage the
        // auto-getters resolve must be the tail slots, proving the append did not shift
        // or collide with any pre-upgrade variable.
        assertEq(
            uint256(vm.load(ATOM_WARDEN_PROXY, bytes32(MAX_CLAIMS_PER_WINDOW_SLOT))),
            REINIT_MAX_CLAIMS_PER_WINDOW,
            "slot 7 must hold maxClaimsPerWindow"
        );
        assertEq(
            uint256(vm.load(ATOM_WARDEN_PROXY, bytes32(CLAIM_CAP_WINDOW_SLOT))),
            REINIT_CLAIM_CAP_WINDOW,
            "slot 8 must hold claimCapWindow"
        );
        assertEq(
            uint256(vm.load(ATOM_WARDEN_PROXY, bytes32(CURRENT_CLAIM_WINDOW_ID_SLOT))),
            block.timestamp / REINIT_CLAIM_CAP_WINDOW,
            "slot 9 must hold currentClaimWindowId"
        );
        assertEq(
            uint256(vm.load(ATOM_WARDEN_PROXY, bytes32(CLAIMS_IN_WINDOW_SLOT))), 0, "slot 10 must hold claimsInWindow"
        );

        // Pausable state is bootstrapped to unpaused.
        assertFalse(atomWarden.paused(), "Pausable must initialize as unpaused");

        // Admin from MultiVault.generalConfig is bootstrapped into DEFAULT_ADMIN_ROLE +
        // OPERATOR_ROLE; this matches the existing reinitialize semantics.
        assertTrue(
            atomWarden.hasRole(atomWarden.DEFAULT_ADMIN_ROLE(), ADMIN_SAFE),
            "DEFAULT_ADMIN_ROLE must be bootstrapped from MultiVault.generalConfig.admin"
        );
        assertTrue(atomWarden.hasRole(atomWarden.OPERATOR_ROLE(), ADMIN_SAFE), "OPERATOR_ROLE must be bootstrapped");
    }

    function test_reinitialize_signerCountIncrementsOnPostUpgradeGrant() external {
        _upgradeAtomWardenAndReinitialize();

        // Pre-grant baseline.
        assertEq(atomWarden.signerCount(), 0);

        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        address newSigner = vm.addr(0x1A11CE);

        vm.startPrank(ADMIN_SAFE);
        atomWarden.grantRole(signerRole, newSigner);
        vm.stopPrank();

        assertEq(atomWarden.signerCount(), 1, "role-hook must increment signerCount on first post-upgrade grant");

        // Idempotency: re-granting must NOT double-count.
        vm.startPrank(ADMIN_SAFE);
        atomWarden.grantRole(signerRole, newSigner);
        vm.stopPrank();
        assertEq(atomWarden.signerCount(), 1, "re-grant of an existing SIGNER_ROLE holder must not change signerCount");
    }

    function test_reinitialize_singleSignerClaimStillWorks() external {
        // End-to-end smoke: after the upgrade + reinit, an admin grant + a 1-of-1 signed
        // bundle must successfully claim an unclaimed atom wallet. Proves that EIP-712
        // domain wiring, the new `_verifyQuorum` path, and the role-hook signer count
        // line up under live state.
        _upgradeAtomWardenAndReinitialize();

        uint256 signerKey = 0xC1A19;
        address signerAddr = vm.addr(signerKey);
        bytes32 signerRole = atomWarden.SIGNER_ROLE();
        vm.startPrank(ADMIN_SAFE);
        atomWarden.grantRole(signerRole, signerAddr);
        vm.stopPrank();

        address claimant = makeAddr("regression-claimant");
        bytes32 atomId = _createAtom(claimant, "regression-claim-atom");
        atomWalletFactory.deployAtomWallet(atomId);

        IAtomWarden.ClaimAuthorization memory authorization = IAtomWarden.ClaimAuthorization({
            claimant: claimant,
            atomId: atomId,
            claimType: 1,
            nonce: atomWarden.claimNonces(claimant),
            validAfter: uint48(block.timestamp - 1),
            validUntil: uint48(block.timestamp + 1 days)
        });

        bytes memory bundle = _signAuthorization(authorization, signerKey);

        vm.prank(claimant);
        atomWarden.claimWithAuthorization(authorization, bundle);

        AtomWallet wallet = AtomWallet(payable(multiVault.computeAtomWalletAddr(atomId)));
        assertTrue(wallet.isClaimed(), "wallet should be marked claimed after quorum=1 signed claim");
        assertEq(wallet.owner(), claimant, "wallet owner must equal claimant");
        assertEq(atomWarden.claimNonces(claimant), authorization.nonce + 1, "nonce must increment by 1");
        assertEq(atomWarden.claimsInWindow(), 1, "authorized claim must consume one unit of the window budget");
    }

    /*//////////////////////////////////////////////////////////////
                  WALLET-ADDRESS DETERMINISM ACROSS UPGRADE
    //////////////////////////////////////////////////////////////*/

    function test_upgrade_preservesComputeAtomWalletAddr() external {
        // Capture deterministic wallet addresses for atoms in two states: one already
        // deployed (CREATE2 collision risk) and one not yet deployed (salt derivation
        // risk). Both must survive the AtomWarden upgrade unchanged.
        address creator1 = makeAddr("warden-determinism-1");
        address creator2 = makeAddr("warden-determinism-2");

        bytes32 atomId1 = _createAtom(creator1, "warden-determinism-atom-1");
        bytes32 atomId2 = _createAtom(creator2, "warden-determinism-atom-2");

        address preComputed1 = multiVault.computeAtomWalletAddr(atomId1);
        address preComputed2 = multiVault.computeAtomWalletAddr(atomId2);

        // Deploy one wallet pre-upgrade so we can also detect bytecode/CREATE2 drift.
        atomWalletFactory.deployAtomWallet(atomId1);

        _upgradeAtomWardenAndReinitialize();

        address postComputed1 = multiVault.computeAtomWalletAddr(atomId1);
        address postComputed2 = multiVault.computeAtomWalletAddr(atomId2);

        assertEq(preComputed1, postComputed1, "deployed atom wallet address must not shift across upgrade");
        assertEq(preComputed2, postComputed2, "undeployed atom wallet address must not shift across upgrade");

        // Deploying the second wallet post-upgrade must land on the predicted address.
        address deployed2 = atomWalletFactory.deployAtomWallet(atomId2);
        assertEq(deployed2, postComputed2, "post-upgrade deployment address must match prediction");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _upgradeAtomWardenAndReinitialize() internal {
        AtomWarden newImpl = new AtomWarden();
        // Optional but realistic: also point the AtomWallet beacon at a fresh impl, since
        // the production rollout bumps both. Determinism asserts cover this surface.
        AtomWallet newWalletImpl = new AtomWallet();

        // Step 1 (proxy admin): bare upgrade only.
        vm.startPrank(UPGRADES_TIMELOCK);
        ProxyAdmin(ATOM_WARDEN_PROXY_ADMIN)
            .upgradeAndCall(ITransparentUpgradeableProxy(payable(ATOM_WARDEN_PROXY)), address(newImpl), bytes(""));
        UpgradeableBeacon(ATOM_WALLET_BEACON).upgradeTo(address(newWalletImpl));
        vm.stopPrank();

        // Step 2 (MultiVault admin): reinitialize directly against the proxy. The
        // `reinitialize` gate requires `msg.sender == MultiVault.generalConfig.admin`,
        // which is `ADMIN_SAFE` on the fork.
        vm.prank(ADMIN_SAFE);
        atomWarden.reinitialize(
            REINIT_CLAIM_WINDOW,
            REINIT_MIN_FEE_THRESHOLD,
            REINIT_SIGNATURE_THRESHOLD,
            REINIT_MAX_VALID_AFTER,
            REINIT_MAX_VALID_UNTIL,
            REINIT_MAX_CLAIMS_PER_WINDOW,
            REINIT_CLAIM_CAP_WINDOW
        );

        // Sanity: implementation slot now points at the freshly-deployed contract.
        assertEq(_implementationOf(ATOM_WARDEN_PROXY), address(newImpl));
    }

    function _implementationOf(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, EIP1967_IMPLEMENTATION_SLOT))));
    }

    function _createAtom(address user, string memory atomLabel) internal returns (bytes32 atomId) {
        uint256 atomCost = multiVault.getAtomCost();
        vm.deal(user, user.balance + atomCost + 10 ether);

        bytes[] memory data = new bytes[](1);
        data[0] = bytes(atomLabel);
        uint256[] memory assets = new uint256[](1);
        assets[0] = atomCost;

        vm.prank(user);
        atomId = multiVault.createAtoms{ value: atomCost }(data, assets)[0];
    }

    function _signAuthorization(IAtomWarden.ClaimAuthorization memory authorization, uint256 privateKey)
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_AUTHORIZATION_TYPEHASH,
                authorization.claimant,
                authorization.atomId,
                authorization.claimType,
                authorization.nonce,
                authorization.validAfter,
                authorization.validUntil
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("AtomWarden")),
                keccak256(bytes("2")),
                block.chainid,
                address(atomWarden)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
