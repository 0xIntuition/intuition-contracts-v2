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
        return _find_user_timestamp_epoch(addr, ts, user_point_epoch[addr]);
    }

    function exposed_balanceOf(address addr, uint256 t) external view returns (uint256) {
        return _balanceOf(addr, t);
    }

    function exposed_totalSupplyAtT(uint256 t) external view returns (uint256) {
        return _totalSupply(t);
    }

    function exposed_blockTimeForBlock(uint256 _block) external view returns (uint256) {
        require(_block <= block.number, "block in the future");

        uint256 _epoch = epoch;
        if (_epoch == 0) {
            return 0;
        }

        if (_block < point_history[0].blk) {
            return 0;
        }

        uint256 target_epoch = _find_block_epoch(_block, _epoch);
        Point memory point = point_history[target_epoch];

        uint256 dt = 0;
        if (target_epoch < _epoch) {
            Point memory point_next = point_history[target_epoch + 1];
            if (point.blk != point_next.blk) {
                dt = ((_block - point.blk) * (point_next.ts - point.ts)) / (point_next.blk - point.blk);
            }
        } else {
            if (point.blk != block.number) {
                dt = ((_block - point.blk) * (block.timestamp - point.ts)) / (block.number - point.blk);
            }
        }

        return point.ts + dt;
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
