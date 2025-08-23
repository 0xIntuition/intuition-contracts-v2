// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20Upgradeable } from "@openzeppelinV4/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelinV4/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TrustToken is Initializable, ERC20Upgradeable {
    error NotAllowedToMint();
    error ExceedsMinterCap();
    error ExceedsTotalSupply();

    uint256 public constant MAX_SUPPLY = 1e9 * 1e18; // 1 billion tokens, assuming 18 decimal places
    address public constant MINTER_A = 0xBc01aB3839bE8933f6B93163d129a823684f4CDF;
    address public constant MINTER_B = 0xA4Df56842887cF52C9ad59C97Ec0C058e96Af533;
    uint256 public totalMinted;

    mapping(address => uint256) public minterAmountMinted;

    function init() public initializer {
        __ERC20_init("TRUST", "TRUST");
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == MINTER_A || msg.sender == MINTER_B, "Not authorized to mint");
        uint256 minterCap = (msg.sender == MINTER_A) ? (MAX_SUPPLY * 49 / 100) : (MAX_SUPPLY * 51 / 100);
        require(totalMinted + amount <= MAX_SUPPLY, "Max supply exceeded");
        require(minterAmountMinted[msg.sender] + amount <= minterCap, "Minting cap exceeded for minter");
        totalMinted += amount;
        minterAmountMinted[msg.sender] += amount;
        _mint(to, amount);
    }
}
