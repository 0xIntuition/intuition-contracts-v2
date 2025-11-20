// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { VotingEscrow, Point, LockedBalance } from "src/external/curve/VotingEscrow.sol";

/// @dev Harness exposing internal functions + some test-only setters.
contract VotingEscrowHarness is VotingEscrow {
    function initialize(address admin, address tokenAddress, uint256 minTime) external initializer {
        __VotingEscrow_init(admin, tokenAddress, minTime);
    }

    // --------- Exposed internal helpers ---------

    function exposed_find_timestamp_epoch(uint256 ts, uint256 maxEpoch) external view returns (uint256) {
        return _find_timestamp_epoch(ts, maxEpoch);
    }

    function exposed_find_user_timestamp_epoch(address addr, uint256 ts) external view returns (uint256) {
        return _find_user_timestamp_epoch(addr, ts);
    }

    function exposed_balanceOf(address addr, uint256 t) external view returns (uint256) {
        return _balanceOf(addr, t);
    }

    function exposed_totalSupplyAtT(uint256 t) external view returns (uint256) {
        return _totalSupply(t);
    }

    // --------- Test-only mutation helpers (not used in prod) ---------

    function h_setPointHistory(uint256 idx, int128 bias, int128 slope, uint256 ts, uint256 blk) external {
        point_history[idx] = Point({ bias: bias, slope: slope, ts: ts, blk: blk });
    }

    function h_setUserPoint(address addr, uint256 idx, int128 bias, int128 slope, uint256 ts, uint256 blk) external {
        user_point_history[addr][idx] = Point({ bias: bias, slope: slope, ts: ts, blk: blk });
    }

    function h_setEpoch(uint256 e) external {
        epoch = e;
    }

    function h_setUserEpoch(address addr, uint256 e) external {
        user_point_epoch[addr] = e;
    }

    function h_getEpoch() external view returns (uint256) {
        return epoch;
    }
}
