// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Test, console} from "forge-std/Test.sol";

import {CAIP10Lib} from "src/libraries/CAIP10.sol";

/**
 * @title CAIP10Helper
 * @dev A helper contract to expose CAIP10Lib's functions for testing.
 */
contract CAIP10Helper {
    /**
     * @notice Converts an Ethereum address to its CAIP-10 string representation.
     * @param user The Ethereum address to convert.
     * @return The CAIP-10 string.
     */
    function getCAIP10(address user) external view returns (string memory) {
        return CAIP10Lib.addressToCAIP10(user);
    }

    /**
     * @notice Extracts the Ethereum address from a CAIP-10 string after verifying the ChainID.
     * @param caip10 The CAIP-10 string.
     * @return The extracted Ethereum address.
     */
    function getAddressFromCAIP10(string calldata caip10) external view returns (address) {
        return CAIP10Lib.caip10ToAddress(caip10);
    }
}

/**
 * @title CAIP10Test
 * @notice A suite of unit tests for the CAIP10 library using Forge.
 */
contract CAIP10Test is Test {
    CAIP10Helper helper;

    using Strings for uint256;

    /**
     * @notice Setup function
     *         This function runs before each test to ensure a fresh state.
     */
    function setUp() external {
        helper = new CAIP10Helper();
    }

    /**
     * @notice Test Case 1: Valid conversion of address to CAIP10 and back.
     *         Ensures that converting an address to a CAIP-10 string and then back
     *         yields the original address.
     */
    function test_ValidConversion() external view {
        address testAddress = 0x1234567890AbcdEF1234567890aBcdef12345678; // Must be checksummed to be stored as an address
        string memory chainIdStr = uint256(block.chainid).toString();
        string memory expectedCAIP10 = string(
            abi.encodePacked(
                "caip10:eip155:",
                chainIdStr,
                ":0x1234567890AbcdEF1234567890aBcdef12345678" // A string, so can be stored without checksum
            )
        );
        string memory caip10 = helper.getCAIP10(testAddress);
        assertEq(caip10, expectedCAIP10, "CAIP10 string mismatch");

        address extractedAddress = helper.getAddressFromCAIP10(caip10);
        assertEq(extractedAddress, testAddress, "Extracted address mismatch");
    }

    /**
     * @notice Test Case 2: Valid conversion with different chainid.
     *         Verifies that the library correctly handles different `chainid` values.
     */
    function test_ValidConversionDifferentChainId() external {
        // Save the original chainid to restore later
        uint256 originalChainId = block.chainid;

        // Set a different chainid (e.g., 8453 for Base)
        uint256 newChainId = 8453;
        vm.chainId(newChainId);

        address testAddress = 0x1234567890AbcdEF1234567890aBcdef12345678;
        string memory expectedCAIP10 = string(
            abi.encodePacked("caip10:eip155:", newChainId.toString(), ":0x1234567890AbcdEF1234567890aBcdef12345678")
        );
        string memory caip10 = helper.getCAIP10(testAddress);
        assertEq(caip10, expectedCAIP10, "CAIP10 string mismatch for different chainid");

        address extractedAddress = helper.getAddressFromCAIP10(caip10);
        assertEq(extractedAddress, testAddress, "Extracted address mismatch for different chainid");

        // Reset chainid to original value
        vm.chainId(originalChainId);
    }

    /**
     * @notice Test Case 3: Invalid namespace.
     *         Attempts to parse a CAIP-10 string with an incorrect namespace and expects a revert.
     */
    function test_InvalidNamespace() external {
        string memory invalidCAIP10 = "caip10:invalid:1:0x1234567890abcdef1234567890abcdef12345678";
        vm.expectRevert(bytes("CAIP10: Invalid namespace"));
        helper.getAddressFromCAIP10(invalidCAIP10);
    }

    /**
     * @notice Test Case 4: Mismatched chainid.
     *         Provides a CAIP-10 string with a `chainid` that does not match `block.chainid` and expects a revert.
     */
    function test_ChainIdMismatch() external {
        // Save the original chainid to restore later
        uint256 originalChainId = block.chainid;

        // Set chainid to 1 (e.g., Ethereum Mainnet)
        uint256 expectedChainId = 1;
        vm.chainId(expectedChainId);

        // Create CAIP10 string with mismatched chainid (e.g., 999)
        string memory invalidCAIP10 = "caip10:eip155:999:0x1234567890abcdef1234567890abcdef12345678";

        vm.expectRevert(bytes("CAIP10: ChainID mismatch"));
        helper.getAddressFromCAIP10(invalidCAIP10);

        // Reset chainid to original value
        vm.chainId(originalChainId);
    }

    /**
     * @notice Test Case 5: Malformed address.
     *         Provides a CAIP-10 string with an improperly formatted address and expects a revert.
     */
    function test_MalformedAddress() external {
        vm.chainId(1);
        string memory malformedCAIP10 = "caip10:eip155:1:0x12345"; // Address too short
        vm.expectRevert(bytes("CAIP10: Invalid address length"));
        helper.getAddressFromCAIP10(malformedCAIP10);
    }

    /**
     * @notice Test Case 6: Address with leading zeros.
     *         Ensures that addresses with leading zeros are correctly handled.
     */
    function test_LeadingZerosAddress() external view {
        address testAddress = 0x0000000000000000000000000000000000000000;
        string memory chainIdStr = uint256(block.chainid).toString();
        string memory expectedCAIP10 =
            string(abi.encodePacked("caip10:eip155:", chainIdStr, ":0x0000000000000000000000000000000000000000"));
        string memory caip10 = helper.getCAIP10(testAddress);
        assertEq(caip10, expectedCAIP10, "CAIP10 string mismatch for leading zeros address");

        address extractedAddress = helper.getAddressFromCAIP10(caip10);
        assertEq(extractedAddress, testAddress, "Extracted address mismatch for leading zeros address");
    }

    /**
     * @notice Test Case 7: Maximum chainid.
     *         Tests the library's ability to handle very large `chainid` values.
     */
    function test_MaximumChainId() external {
        // Save the original chainid to restore later
        uint256 originalChainId = block.chainid;

        // Set a very large chainid (e.g., 999999)
        uint256 maxChainId = 999999;
        vm.chainId(maxChainId);

        address testAddress = 0x1234567890AbcdEF1234567890aBcdef12345678;
        string memory expectedCAIP10 = string(
            abi.encodePacked("caip10:eip155:", maxChainId.toString(), ":0x1234567890AbcdEF1234567890aBcdef12345678")
        );
        string memory caip10 = helper.getCAIP10(testAddress);
        assertEq(caip10, expectedCAIP10, "CAIP10 string mismatch for maximum chainid");

        address extractedAddress = helper.getAddressFromCAIP10(caip10);
        assertEq(extractedAddress, testAddress, "Extracted address mismatch for maximum chainid");

        // Reset chainid to original value
        vm.chainId(originalChainId);
    }

    function test_InvalidPrefix() external {
        // bad prefix: "CAIP10" instead of "caip10"
        string memory s = "CAIP10:eip155:1:0x1234567890abcdef1234567890abcdef12345678";
        vm.expectRevert(bytes("CAIP10: Invalid CAIP10 prefix"));
        helper.getAddressFromCAIP10(s);
    }

    function test_MissingSeparatorAfterPrefix() external {
        // missing ':' after 'caip10'
        string memory s = "caip10eip155:1:0x1234567890abcdef1234567890abcdef12345678";
        vm.expectRevert(bytes("CAIP10: Invalid separator"));
        helper.getAddressFromCAIP10(s);
    }

    function test_MissingSeparatorAfterNamespace() external {
        // missing ':' after 'eip155'
        string memory s = "caip10:eip1551:0x1234567890abcdef1234567890abcdef12345678";
        vm.expectRevert(bytes("CAIP10: Invalid separator"));
        helper.getAddressFromCAIP10(s);
    }

    function test_ChainIdContainsNonDigit() external {
        string memory s = "caip10:eip155:1a:0x1234567890abcdef1234567890abcdef12345678";
        vm.expectRevert(bytes("CAIP10: Invalid chainid character"));
        helper.getAddressFromCAIP10(s);
    }

    function test_MissingChainId() external {
        // two colons in a row -> empty chain id
        string memory s = "caip10:eip155::0x1234567890abcdef1234567890abcdef12345678";
        vm.expectRevert(bytes("CAIP10: Missing chainid"));
        helper.getAddressFromCAIP10(s);
    }

    function test_MissingSeparatorAfterChainId() external {
        string memory s = "caip10:eip155:1-0x1234567890abcdef1234567890abcdef12345678";
        vm.expectRevert(bytes("CAIP10: Invalid chainid character"));
        helper.getAddressFromCAIP10(s);
    }

    function test_InvalidAddressPrefix() external {
        string memory chain = uint256(block.chainid).toString();
        // address part must start with "0x", but we use "0X"
        string memory s =
            string(abi.encodePacked("caip10:eip155:", chain, ":0X1234567890abcdef1234567890abcdef12345678"));
        vm.expectRevert(bytes("CAIP10: Invalid address prefix"));
        helper.getAddressFromCAIP10(s);
    }

    function test_AddressTooLong() external {
        string memory chain = uint256(block.chainid).toString();
        // 42 hex bytes (84 chars) after 0x -> too long by 2 hex chars
        string memory s =
            string(abi.encodePacked("caip10:eip155:", chain, ":0x1234567890abcdef1234567890abcdef12345678aa"));
        vm.expectRevert(bytes("CAIP10: Invalid address length"));
        helper.getAddressFromCAIP10(s);
    }

    function test_InvalidHexCharacterInAddress_lowercase() external {
        string memory chain = uint256(block.chainid).toString();
        // include 'g' (invalid hex)
        string memory s =
            string(abi.encodePacked("caip10:eip155:", chain, ":0x1234567890abcdef1234567890abcdef1234567g"));
        vm.expectRevert(bytes("CAIP10: Invalid hex character"));
        helper.getAddressFromCAIP10(s);
    }

    function test_InvalidHexCharacterInAddress_uppercase() external {
        string memory chain = uint256(block.chainid).toString();
        // include 'G' (invalid hex)
        string memory s =
            string(abi.encodePacked("caip10:eip155:", chain, ":0x1234567890abcdef1234567890abcdef1234567G"));
        vm.expectRevert(bytes("CAIP10: Invalid hex character"));
        helper.getAddressFromCAIP10(s);
    }

    function testFuzz_RoundTrip(address who) external view {
        string memory caip = helper.getCAIP10(who);
        address out = helper.getAddressFromCAIP10(caip);
        assertEq(out, who, "round-trip mismatch");
    }
}
