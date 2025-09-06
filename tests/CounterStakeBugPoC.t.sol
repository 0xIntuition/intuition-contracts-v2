// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/src/Test.sol";
import { console } from "forge-std/src/console.sol";
import { MultiVault } from "../src/protocol/MultiVault.sol";
import { MultiVaultCore } from "../src/protocol/MultiVaultCore.sol";

contract CounterStakeBugPoCTest is Test {
    MultiVault public multiVault;

    bytes32 public tripleId;
    bytes32 public counterTripleId;

    string RPC_URL = "https://testnet.rpc.intuition.systems/http";

    function setUp() public {
        vm.createSelectFork(RPC_URL);

        // current contract
        multiVault = MultiVault(0x89889B6C003A76393742Ec64dB6Ed65437AAE991);

        // triple id from slack thread
        tripleId = hex"b93bd7ed3fdde4d15aa02d8b4eeb499ffabc14e153181203ed3d9457a1a5e9c3";

        counterTripleId = multiVault.getCounterIdFromTripleId(tripleId);

        console.log("Triple ID:", vm.toString(tripleId));
        console.log("Counter Triple ID:", vm.toString(counterTripleId));
    }

    function test_CounterStakeBugProof() public {
        bytes32 derivedCounterId = multiVault.getCounterIdFromTripleId(tripleId);
        bytes32 derivedTripleId = multiVault.getTripleIdFromCounterId(counterTripleId);

        console.log("\nMapping check (should be bidirectional):");
        console.log("  tripleId -> counterId:", vm.toString(derivedCounterId));
        console.log("  counterId -> tripleId:", vm.toString(derivedTripleId));
        console.log("  Expected tripleId:    ", vm.toString(tripleId));

        if (derivedTripleId == bytes32(0)) {
            console.log("\n Asymmetric mapping detected!");
        }

        assertEq(derivedTripleId, bytes32(0), "Bug confirmed: mapping returns zero");
    }
}
