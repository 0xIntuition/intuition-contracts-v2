// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { TrustToken } from "src/legacy/TrustToken.sol";

contract LegacyTrustTokenTest is Test {
    /* =================================================== */
    /*                     VARIABLES                       */
    /* =================================================== */

    TrustToken internal token;

    struct Users {
        address alice;
        address bob;
        address other;
    }

    Users internal users;

    // Standard ERC20 event for minting checks
    event Transfer(address indexed from, address indexed to, uint256 value);

    /* =================================================== */
    /*                       SETUP                         */
    /* =================================================== */

    function setUp() public {
        users.alice = makeAddr("alice");
        users.bob = makeAddr("bob");
        users.other = makeAddr("other");

        token = new TrustToken();
        token.init(); // initialize once per test
    }

    /* =================================================== */
    /*                     METADATA                        */
    /* =================================================== */

    function test_metadata_and_decimals() public {
        assertEq(token.name(), "TRUST");
        assertEq(token.symbol(), "TRUST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.totalMinted(), 0);
    }

    function test_init_Revert_AlreadyInitialized() public {
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        token.init();
    }

    /* =================================================== */
    /*                     AUTH + CAPS                     */
    /* =================================================== */

    function test_mint_Revert_Unauthorized() public {
        vm.prank(users.other);
        vm.expectRevert(bytes("Not authorized to mint"));
        token.mint(users.alice, 1);
    }

    function test_mint_MinterA_UpToCap_ThenExceed_Revert() public {
        address minterA = token.MINTER_A();
        uint256 capA = token.MAX_SUPPLY() * 49 / 100;

        // mint exactly to cap
        vm.prank(minterA);
        vm.expectEmit(address(token));
        emit Transfer(address(0), users.alice, capA);
        token.mint(users.alice, capA);

        assertEq(token.totalMinted(), capA);
        assertEq(token.minterAmountMinted(minterA), capA);
        assertEq(token.balanceOf(users.alice), capA);
        assertEq(token.totalSupply(), capA);

        // exceed personal cap
        vm.prank(minterA);
        vm.expectRevert(bytes("Minting cap exceeded for minter"));
        token.mint(users.alice, 1);
    }

    function test_mint_MinterB_UpToCap_ThenExceed_Revert() public {
        address minterB = token.MINTER_B();
        uint256 capB = token.MAX_SUPPLY() * 51 / 100;

        vm.prank(minterB);
        vm.expectEmit(address(token));
        emit Transfer(address(0), users.bob, capB);
        token.mint(users.bob, capB);

        assertEq(token.totalMinted(), capB);
        assertEq(token.minterAmountMinted(minterB), capB);
        assertEq(token.balanceOf(users.bob), capB);
        assertEq(token.totalSupply(), capB);

        vm.prank(minterB);
        vm.expectRevert(bytes("Minting cap exceeded for minter"));
        token.mint(users.bob, 1);
    }

    function test_mint_TotalSupplyExceeded_Revert_AfterBothCaps() public {
        address minterA = token.MINTER_A();
        address minterB = token.MINTER_B();
        uint256 capA = token.MAX_SUPPLY() * 49 / 100;
        uint256 capB = token.MAX_SUPPLY() * 51 / 100;

        // Fill to 100% (49% + 51%)
        vm.prank(minterA);
        token.mint(users.alice, capA);

        vm.prank(minterB);
        token.mint(users.bob, capB);

        assertEq(token.totalMinted(), token.MAX_SUPPLY());
        assertEq(token.totalSupply(), token.MAX_SUPPLY());

        // Any further mint by anyone should hit total cap first
        vm.prank(minterB);
        vm.expectRevert(bytes("Max supply exceeded"));
        token.mint(users.bob, 1);
    }

    function test_mint_TracksPerMinterAndTotal() public {
        address minterA = token.MINTER_A();
        address minterB = token.MINTER_B();

        // small chunks to check accounting
        vm.prank(minterA);
        token.mint(users.alice, 10 ether);

        vm.prank(minterB);
        token.mint(users.bob, 20 ether);

        assertEq(token.minterAmountMinted(minterA), 10 ether);
        assertEq(token.minterAmountMinted(minterB), 20 ether);
        assertEq(token.totalMinted(), 30 ether);
        assertEq(token.totalSupply(), 30 ether);
        assertEq(token.balanceOf(users.alice), 10 ether);
        assertEq(token.balanceOf(users.bob), 20 ether);
    }

    /* =================================================== */
    /*                 OZ INTERNAL GUARDS                  */
    /* =================================================== */

    function test_mint_Revert_ToZeroAddress() public {
        address minterA = token.MINTER_A();
        vm.prank(minterA);
        vm.expectRevert(bytes("ERC20: mint to the zero address"));
        token.mint(address(0), 1 ether);
    }
}
