// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {IMultiVault} from "src/interfaces/IMultiVault.sol";
import {MultiVault} from "src/MultiVault.sol";

import {MultiVaultBase} from "test/MultiVaultBase.sol";

abstract contract MultiVaultHelpers is MultiVaultBase {
    using FixedPointMathLib for uint256;

    function getAdmin() public view returns (address admin) {
        (admin,,,,,,,,,,) = multiVault.generalConfig();
    }

    function getProtocolMultisig() public view returns (address protocolMultisig) {
        (, protocolMultisig,,,,,,,,,) = multiVault.generalConfig();
    }

    function getFeeDenominator() public view returns (uint256 feeDenominator) {
        (,, feeDenominator,,,,,,,,) = multiVault.generalConfig();
    }

    function getProtocolTrust() public view returns (address trust) {
        (,,, trust,,,,,,,) = multiVault.generalConfig();
    }

    function getProtocolTrustBonding() public view returns (address trustBonding) {
        (,,,, trustBonding,,,,,,) = multiVault.generalConfig();
    }

    function getMinDeposit() public view returns (uint256 minDeposit) {
        (,,,,, minDeposit,,,,,) = multiVault.generalConfig();
    }

    function getMinShare() public view returns (uint256 minShare) {
        (,,,,,, minShare,,,,) = multiVault.generalConfig();
    }

    function getAtomUriMaxLength() public view returns (uint256 atomDataMaxLength) {
        (,,,,,,, atomDataMaxLength,,,) = multiVault.generalConfig();
    }

    function getDecimalPrecision() public view returns (uint256 decimalPrecision) {
        (,,,,,,,, decimalPrecision,,) = multiVault.generalConfig();
    }

    function getEntryFee() public view returns (uint256 entryFee) {
        (entryFee,,) = multiVault.vaultFees();
    }

    function getExitFee() public view returns (uint256 exitFee) {
        (, exitFee,) = multiVault.vaultFees();
    }

    function getProtocolFee() public view returns (uint256 protocolFee) {
        (,, protocolFee) = multiVault.vaultFees();
    }

    function getProtocolFeeAmount(uint256 _assets) public view returns (uint256 protocolFee) {
        protocolFee = multiVault.protocolFeeAmount(_assets);
    }

    function getAtomWalletInitialDepositAmount() public view virtual returns (uint256 atomWalletInitialDepositAmount) {
        (atomWalletInitialDepositAmount,) = multiVault.atomConfig();
    }

    function getAtomCreationProtocolFee() public view returns (uint256 atomCreationProtocolFee) {
        (, atomCreationProtocolFee) = multiVault.atomConfig();
    }

    function getTripleCreationProtocolFee() public view returns (uint256 tripleCreationProtocolFee) {
        (tripleCreationProtocolFee,,) = multiVault.tripleConfig();
    }

    function getTotalAtomDepositsOnTripleCreation() public view returns (uint256 totalAtomDepositsOnTripleCreation) {
        (, totalAtomDepositsOnTripleCreation,) = multiVault.tripleConfig();
    }

    function getAtomDepositFraction() public view returns (uint256 atomDepositFractionForTriple) {
        (,, atomDepositFractionForTriple) = multiVault.tripleConfig();
    }

    function getAtomWalletAddr(bytes32 id) public view returns (address) {
        return multiVault.computeAtomWalletAddr(id);
    }

    function convertToShares(uint256 assets, bytes32 id) public view returns (uint256) {
        return multiVault.convertToShares(assets, id, 1);
    }

    function convertToAssets(uint256 shares, bytes32 id) public view returns (uint256) {
        return multiVault.convertToAssets(shares, id, 1);
    }

    function getSharesInVault(bytes32 vaultId, address user) public view returns (uint256) {
        (uint256 shares,) = multiVault.getVaultStateForUser(vaultId, 1, user);
        return shares;
    }

    function checkDepositIntoVault(uint256 amount, bytes32 id, uint256 totalAssetsBefore, uint256 totalSharesBefore)
        public
        payable
    {
        uint256 atomDepositFraction = atomDepositFractionAmount(amount, id);
        uint256 userAssetsAfterAtomDepositFraction = amount - atomDepositFraction;

        uint256 totalAssetsDeltaExpected = userAssetsAfterAtomDepositFraction;

        uint256 entryFee;

        if (totalSharesBefore == getMinShare()) {
            entryFee = 0;
        } else {
            entryFee = entryFeeAmount(userAssetsAfterAtomDepositFraction);
        }

        uint256 userAssetsAfterTotalFees = userAssetsAfterAtomDepositFraction - entryFee;

        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;

        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        uint256 totalSharesDeltaExpected = multiVault.convertToShares(userAssetsAfterTotalFees, id, 1);

        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkAtomDepositIntoVaultOnTripleVaultCreation(
        uint256 proportionalAmount,
        uint256 staticAmount,
        bytes32 id,
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public payable {
        uint256 totalAssetsDeltaExpected = proportionalAmount + staticAmount;
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;

        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        uint256 entryFee = entryFeeAmount(proportionalAmount);
        uint256 userAssetsAfterEntryFee = proportionalAmount - entryFee;

        uint256 totalSharesDeltaExpected = userAssetsAfterEntryFee.mulDiv(totalSharesBefore, totalAssetsBefore);
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;

        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkDepositOnAtomVaultCreation(
        bytes32 id,
        uint256 value, // msg.value
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public view {
        uint256 ghostShares = getMinShare();
        uint256 sharesForAtomWallet = getAtomWalletInitialDepositAmount();
        uint256 userDeposit = value - getAtomCost();
        uint256 assets = userDeposit - getProtocolFeeAmount(userDeposit);
        uint256 sharesForDepositor = assets;

        // calculate expected total assets delta
        uint256 totalAssetsDeltaExpected = sharesForDepositor + ghostShares + sharesForAtomWallet;
        // calculate expected total shares delta
        uint256 totalSharesDeltaExpected = sharesForDepositor + ghostShares + sharesForAtomWallet;

        // vault's total assets should have gone up
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;
        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        // vault's total shares should have gone up
        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkDepositOnTripleVaultCreation(
        bytes32 id,
        uint256 value,
        uint256 totalAssetsBefore,
        uint256 totalSharesBefore
    ) public view {
        // calculate expected total assets delta
        uint256 userDeposit = value - getTripleCost();
        uint256 protocolDepositFee = protocolFeeAmount(userDeposit, id);
        uint256 userDepositAfterprotocolFee = userDeposit - protocolDepositFee;
        uint256 atomDepositFraction = atomDepositFractionAmount(userDepositAfterprotocolFee, id);

        uint256 ghostShares = getMinShare();

        uint256 totalAssetsDeltaExpected = userDepositAfterprotocolFee - atomDepositFraction + ghostShares;

        // calculate expected total shares delta
        uint256 sharesForDepositor = userDepositAfterprotocolFee - atomDepositFraction;
        uint256 totalSharesDeltaExpected = sharesForDepositor + ghostShares;

        // vault's total assets should have gone up
        uint256 totalAssetsDeltaGot = vaultTotalAssets(id) - totalAssetsBefore;

        uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalAssetsDeltaExpected, totalAssetsDeltaGot);

        // vault's total shares should have gone up
        // uint256 totalSharesDeltaGot = vaultTotalShares(id) - totalSharesBefore;
        assertEq(totalSharesDeltaExpected, totalSharesDeltaGot);
    }

    function checkProtocolMultisigBalanceOnVaultCreation(
        bytes32, /* id */
        uint256 userDeposit,
        uint256 protocolMultisigBalanceBefore
    ) public view {
        // calculate expected protocol multisig balance delta
        uint256 protocolMultisigBalanceDeltaExpected = getAtomCreationProtocolFee() + getProtocolFeeAmount(userDeposit);

        uint256 protocolMultisigBalanceDeltaGot = address(getProtocolMultisig()).balance - protocolMultisigBalanceBefore;

        assertEq(protocolMultisigBalanceDeltaExpected, protocolMultisigBalanceDeltaGot);
    }

    function checkProtocolMultisigBalanceOnVaultBatchCreation(
        uint256[] memory ids,
        uint256 valuePerAtom,
        uint256 protocolMultisigBalanceBefore
    ) public view {
        uint256 length = ids.length;
        uint256 protocolFee;

        for (uint256 i = 0; i < length; i++) {
            // calculate expected protocol multisig balance delta
            protocolFee += getProtocolFeeAmount(valuePerAtom);
        }

        uint256 protocolMultisigBalanceDeltaExpected = getAtomCreationProtocolFee() * length + protocolFee;

        // protocol multisig's balance should have gone up
        uint256 protocolMultisigBalanceDeltaGot = address(getProtocolMultisig()).balance - protocolMultisigBalanceBefore;

        assertEq(protocolMultisigBalanceDeltaExpected, protocolMultisigBalanceDeltaGot);
    }

    function checkProtocolMultisigBalance(bytes32, /* id */ uint256 assets, uint256 protocolMultisigBalanceBefore)
        public
        view
    {
        // calculate expected protocol multisig balance delta
        uint256 protocolMultisigBalanceDeltaExpected = getProtocolFeeAmount(assets);

        // protocol multisig's balance should have gone up
        uint256 protocolMultisigBalanceDeltaGot = address(getProtocolMultisig()).balance - protocolMultisigBalanceBefore;

        assertEq(protocolMultisigBalanceDeltaExpected, protocolMultisigBalanceDeltaGot);
    }

    function getAtomCost() public view virtual returns (uint256 atomCost) {
        atomCost = multiVault.getAtomCost();
    }

    function getTripleCost() public view virtual returns (uint256 tripleCost) {
        tripleCost = multiVault.getTripleCost();
    }

    // These methods are duplicated in other test base classes - why?
    function vaultTotalAssets(bytes32 id) public view returns (uint256 totalAssets) {
        (totalAssets,) = multiVault.getVaultTotals(id, 1);
    }

    function vaultTotalShares(bytes32 id) public view returns (uint256 totalShares) {
        (, totalShares) = multiVault.getVaultTotals(id, 1);
    }

    function getCounterIdFromTriple(bytes32 id) public view returns (bytes32 counterId) {
        counterId = multiVault.getCounterIdFromTriple(id);
    }

    function vaultBalanceOf(bytes32 id, address account) public view returns (uint256 shares) {
        (shares,) = multiVault.getVaultStateForUser(id, 1, account);
    }

    function getVaultStateForUser(bytes32 id, address account) public view returns (uint256 shares, uint256 assets) {
        (shares, assets) = multiVault.getVaultStateForUser(id, 1, account);
    }

    function entryFeeAmount(uint256 assets) public view returns (uint256 feeAmount) {
        return multiVault.entryFeeAmount(assets);
    }

    function previewDeposit(uint256 assets, bytes32 id) public view returns (uint256 shares) {
        return multiVault.previewDeposit(assets, id, 1);
    }

    function previewRedeem(uint256 shares, bytes32 id) public view returns (uint256 assets) {
        return multiVault.previewRedeem(shares, id, 1);
    }

    function atomDepositFractionAmount(uint256 assets, bytes32 id) public view returns (uint256) {
        return multiVault.atomDepositFractionAmount(assets, id);
    }

    function protocolFeeAmount(uint256 assets, bytes32 /* id */ ) public view returns (uint256) {
        return multiVault.protocolFeeAmount(assets);
    }

    function currentSharePrice(bytes32 id) public view returns (uint256) {
        return multiVault.currentSharePrice(id, 1);
    }

    function _toLowerCaseAddress(address _address) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes20 addrBytes = bytes20(_address);
        bytes memory str = new bytes(42);

        str[0] = "0";
        str[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(addrBytes[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(addrBytes[i] & 0x0f)];
        }

        return string(str);
    }
}
