// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

// Import OpenZeppelin's Strings library
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CAIP10Lib
 * @author 0xIntuition
 * @notice A library for converting between Ethereum addresses and CAIP-10 strings.
 */
library CAIP10Lib {
    using Strings for uint256;

    // Constants
    string private constant CAIP_PREFIX = "caip10";
    string private constant NAMESPACE = "eip155";
    string private constant SEPARATOR = ":";
    string private constant ADDRESS_PREFIX = "0x";

    /**
     * @dev Converts an Ethereum address to its CAIP-10 string representation.
     * Example: 0x1234567890abcdef1234567890abcdef12345678 -> "CAIP10:eip155:1:0x1234567890abcdef1234567890abcdef12345678"
     * @param _address The Ethereum address to convert.
     * @return The CAIP-10 string.
     */
    function addressToCAIP10(address _address) internal view returns (string memory) {
        // Convert chainid to string
        string memory chainIdStr = block.chainid.toString();

        // Convert address to checksummed hex string using OpenZeppelin's Strings library
        string memory addressStr = Strings.toChecksumHexString(_address);

        // Concatenate namespace, chainid, and address with separators
        string memory part1 = string(abi.encodePacked(CAIP_PREFIX, SEPARATOR, NAMESPACE));
        string memory part2 = string(abi.encodePacked(SEPARATOR, chainIdStr));
        string memory part3 = string(abi.encodePacked(SEPARATOR, addressStr));
        return string(abi.encodePacked(part1, part2, part3));
    }

    /**
     * @dev Extracts the Ethereum address from a CAIP-10 string after verifying the ChainID.
     * @param _caip10 The CAIP-10 string.
     * @return The extracted Ethereum address.
     */
    function caip10ToAddress(string memory _caip10) internal view returns (address) {
        // Phase 1: Verify prefix
        uint256 currentIndex = verifyCAIPPrefix(_caip10);

        // Phase 2: Verify namespace
        currentIndex = verifyNamespace(_caip10, currentIndex);

        // Phase 3: Verify chainId
        currentIndex = verifyChainId(_caip10, currentIndex);

        // Phase 4: Extract address
        return extractAddress(_caip10, currentIndex);
    }

    function verifyCAIPPrefix(string memory _caip10) internal pure returns (uint256) {
        uint256 currentIndex = 0;
        string memory extractedCAIPPrefix = substring(_caip10, currentIndex, currentIndex + bytes(CAIP_PREFIX).length);
        require(Strings.equal(extractedCAIPPrefix, CAIP_PREFIX), "CAIP10: Invalid CAIP10 prefix");
        currentIndex += bytes(CAIP_PREFIX).length;

        return indexToNextSeparator(_caip10, currentIndex);
    }

    function verifyNamespace(string memory _caip10, uint256 currentIndex) internal pure returns (uint256) {
        string memory extractedNamespace = substring(_caip10, currentIndex, currentIndex + bytes(NAMESPACE).length);
        require(Strings.equal(extractedNamespace, NAMESPACE), "CAIP10: Invalid namespace");
        currentIndex += bytes(NAMESPACE).length;

        return indexToNextSeparator(_caip10, currentIndex);
    }

    function verifyChainId(string memory _caip10, uint256 currentIndex) internal view returns (uint256) {
        bytes memory caipBytes = bytes(_caip10);
        uint256 chainIdStart = currentIndex;
        uint256 chainIdEnd = currentIndex;

        while (chainIdEnd < caipBytes.length && caipBytes[chainIdEnd] != ":") {
            require(caipBytes[chainIdEnd] >= "0" && caipBytes[chainIdEnd] <= "9", "CAIP10: Invalid chainid character");
            chainIdEnd++;
        }

        require(chainIdEnd > chainIdStart, "CAIP10: Missing chainid");
        string memory chainIdStr = substring(_caip10, chainIdStart, chainIdEnd);
        uint256 chainIdInString = _parseUint(chainIdStr);
        require(chainIdInString == block.chainid, "CAIP10: ChainID mismatch");

        return indexToNextSeparator(_caip10, chainIdEnd);
    }

    function extractAddress(string memory _caip10, uint256 currentIndex) internal pure returns (address) {
        bytes memory caipBytes = bytes(_caip10);

        // Verify address prefix ("0x")
        string memory addressPrefix = substring(_caip10, currentIndex, currentIndex + bytes(ADDRESS_PREFIX).length);
        require(Strings.equal(addressPrefix, ADDRESS_PREFIX), "CAIP10: Invalid address prefix");
        currentIndex += bytes(ADDRESS_PREFIX).length;

        // Extract address
        require(caipBytes.length == currentIndex + 40, "CAIP10: Invalid address length");
        uint160 addr;
        for (uint256 i = 0; i < 20; ++i) {
            uint8 high = _fromHexChar(caipBytes[currentIndex++]);
            uint8 low = _fromHexChar(caipBytes[currentIndex++]);
            addr |= (uint160((high << 4) | low)) << uint160(8 * (19 - i));
        }

        return address(addr);
    }

    function indexToNextSeparator(string memory _caip10, uint256 _currentIndex) internal pure returns (uint256) {
        string memory extractedSeparator = substring(_caip10, _currentIndex, _currentIndex + bytes(SEPARATOR).length);
        require(Strings.equal(extractedSeparator, SEPARATOR), "CAIP10: Invalid separator");
        return _currentIndex + bytes(SEPARATOR).length;
    }

    /**
     * @dev Parses a substring of a string to a uint.
     * @param str The original string.
     * @param start The starting index of the substring.
     * @param end The ending index of the substring.
     * @return result The parsed uint.
     */
    function substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        require(start <= end && end <= strBytes.length, "CAIP10: Invalid substring range");
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; ++i) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }

    /**
     * @dev Parses a string to a uint.
     * @param str The string to parse.
     * @return result The parsed uint.
     */
    function _parseUint(string memory str) internal pure returns (uint256 result) {
        bytes memory b = bytes(str);
        require(b.length > 0, "CAIP10: Empty string");
        for (uint256 i = 0; i < b.length; ++i) {
            uint8 char = uint8(b[i]);
            require(char >= 0x30 && char <= 0x39, "CAIP10: Invalid uint character");
            result = result * 10 + (char - 0x30);
        }
    }

    /**
     * @dev Converts a single hexadecimal character to its integer value.
     * @param c The hexadecimal character.
     * @return The integer value of the hexadecimal character.
     */
    function _fromHexChar(bytes1 c) internal pure returns (uint8) {
        if (c >= 0x30 && c <= 0x39) {
            // '0' - '9'
            return uint8(c) - 0x30;
        } else if (c >= 0x61 && c <= 0x66) {
            // 'a' - 'f'
            return 10 + uint8(c) - 0x61;
        } else if (c >= 0x41 && c <= 0x46) {
            // 'A' - 'F'
            return 10 + uint8(c) - 0x41;
        } else {
            revert("CAIP10: Invalid hex character");
        }
    }
}
