// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";

import { IUniswapV3Factory } from "src/interfaces/external/uniswapv3/IUniswapV3Factory.sol";
import { INonfungiblePositionManager } from "src/interfaces/external/uniswapv3/INonfungiblePositionManager.sol";
import { ISwapRouter02 } from "src/interfaces/external/uniswapv3/ISwapRouter02.sol";
import { IQuoterV2 } from "src/interfaces/external/uniswapv3/IQuoterV2.sol";
import { IUniswapV3Pool } from "src/interfaces/external/uniswapv3/IUniswapV3Pool.sol";

abstract contract UniswapV3SetupBase is Script {
    /* =================================================== */
    /*                  DEPLOYED ADDRESSES                 */
    /* =================================================== */

    address public constant V3_FACTORY = 0x3C1a5B48C1422D2260DC07b87Edb5a187a95bFe8;
    address public constant NFPM = 0xc6Ec0Ee7795b46A58D78Df323672c3d70bd9C524;
    address public constant SWAP_ROUTER_02 = 0x0334BBdE746c9f938ba903f22af5B02A58310C4A;
    address public constant QUOTER_V2 = 0x77548B0521e71Aafb2E3FCb62b2066bF999c7345;

    /* =================================================== */
    /*                    FEE TIERS                        */
    /* =================================================== */

    uint24 public constant FEE_TIER_LOW = 500; // 0.05%
    uint24 public constant FEE_TIER_MEDIUM = 3000; // 0.3%
    uint24 public constant FEE_TIER_HIGH = 10_000; // 1%

    int24 public constant TICK_SPACING_LOW = 10; // corresponds to 0.05% fee tier
    int24 public constant TICK_SPACING_MEDIUM = 60; // corresponds to 0.3% fee tier
    int24 public constant TICK_SPACING_HIGH = 200; // corresponds to 1% fee tier

    /* =================================================== */
    /*                  MATH CONSTANTS                     */
    /* =================================================== */

    uint256 internal constant Q96 = 2 ** 96; // for UQ96.96 fixed point numbers
    uint256 internal constant Q192 = 2 ** 192; // for UQ192.64 fixed point numbers

    int24 internal constant MIN_TICK = -887_272; // min tick as per UniswapV3 specs
    int24 internal constant MAX_TICK = 887_272; // max tick as per UniswapV3 specs

    /* =================================================== */
    /*                   STATE VARS                        */
    /* =================================================== */

    address internal broadcaster;

    IUniswapV3Factory public factory;
    INonfungiblePositionManager public nfpm;
    ISwapRouter02 public swapRouter;
    IQuoterV2 public quoter;

    /* =================================================== */
    /*                   TOKEN ADDRESSES                   */
    /* =================================================== */

    /// @notice Wrapped TRUST (WTRUST) - wrapper for native TRUST token
    /// @dev TRUST is the native token on this chain. Use WTRUST for pool operations.
    address public wtrustToken;
    address public usdcToken;
    address public wethToken;

    /* =================================================== */
    /*                   POOL ADDRESSES                    */
    /* =================================================== */

    /// @notice WTRUST/USDC pool
    address public wtrustUsdcPool;
    /// @notice WTRUST/WETH pool
    address public wtrustWethPool;
    address public wethUsdcPool;

    /* =================================================== */
    /*                     ERRORS                          */
    /* =================================================== */

    error UnsupportedChainId();

    /* =================================================== */
    /*                   CONSTRUCTOR                       */
    /* =================================================== */

    constructor() {
        uint256 deployerKey = vm.envOr("DEPLOYER_KEY", uint256(0));
        if (deployerKey != 0) {
            broadcaster = vm.rememberKey(deployerKey);
        } else {
            broadcaster = vm.envOr("DEPLOYER_ADDRESS", address(0));
            if (broadcaster == address(0)) {
                revert("Must set DEPLOYER_KEY or DEPLOYER_ADDRESS");
            }
        }
    }

    /* =================================================== */
    /*                    MODIFIERS                        */
    /* =================================================== */

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        console2.log("Broadcasting from:", broadcaster);
        _;
        vm.stopBroadcast();
    }

    /* =================================================== */
    /*                     SETUP                           */
    /* =================================================== */

    function setUp() public virtual {
        console2.log("=== Uniswap V3 Setup ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Broadcaster:", broadcaster);

        factory = IUniswapV3Factory(V3_FACTORY);
        nfpm = INonfungiblePositionManager(NFPM);
        swapRouter = ISwapRouter02(SWAP_ROUTER_02);
        quoter = IQuoterV2(QUOTER_V2);

        _loadTokenAddresses();
        _loadPoolAddresses();
    }

    /* =================================================== */
    /*                 INTERNAL FUNCTIONS                  */
    /* =================================================== */

    function _loadTokenAddresses() internal virtual {
        // WTRUST = Wrapped TRUST (native token wrapper, like WETH for ETH)
        wtrustToken = vm.envOr("WTRUST_TOKEN", address(0));
        usdcToken = vm.envOr("USDC_TOKEN", address(0));
        wethToken = vm.envOr("WETH_TOKEN", address(0));
    }

    function _loadPoolAddresses() internal virtual {
        wtrustUsdcPool = vm.envOr("WTRUST_USDC_POOL", address(0));
        wtrustWethPool = vm.envOr("WTRUST_WETH_POOL", address(0));
        wethUsdcPool = vm.envOr("WETH_USDC_POOL", address(0));
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "Identical tokens");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Zero address");
    }

    function _nearestUsableTick(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 remainder = tick % tickSpacing;
        if (remainder == 0) return tick;
        if (tick < 0) {
            return tick - remainder - tickSpacing;
        }
        return tick - remainder;
    }

    function _getTickAtSqrtPrice(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        uint256 sqrtRatioX96 = uint256(sqrtPriceX96);
        uint256 sqrtRatioX128 = sqrtRatioX96 << 32;
        int256 log2 = _log2(sqrtRatioX128);
        tick = int24((log2 * 255_738_958_999_603_826_347_141) >> 128);
    }

    function _log2(uint256 x) internal pure returns (int256 result) {
        require(x > 0, "Log of zero");
        uint256 msb = 0;
        uint256 xc = x;
        if (xc >= 0x100000000000000000000000000000000) {
            xc >>= 128;
            msb += 128;
        }
        if (xc >= 0x10000000000000000) {
            xc >>= 64;
            msb += 64;
        }
        if (xc >= 0x100000000) {
            xc >>= 32;
            msb += 32;
        }
        if (xc >= 0x10000) {
            xc >>= 16;
            msb += 16;
        }
        if (xc >= 0x100) {
            xc >>= 8;
            msb += 8;
        }
        if (xc >= 0x10) {
            xc >>= 4;
            msb += 4;
        }
        if (xc >= 0x4) {
            xc >>= 2;
            msb += 2;
        }
        if (xc >= 0x2) {
            msb += 1;
        }
        result = int256(msb) - 128;
        result = result << 64;
        uint256 y = x >> (msb - 127);
        if (y != 0x80000000000000000000000000000000) {
            uint256 z = y;
            uint256 w = 0x8000000000000000;
            for (uint256 i = 0; i < 63; i++) {
                z = (z * z) >> 127;
                if (z >= 0x100000000000000000000000000000000) {
                    z >>= 1;
                    w |= (0x4000000000000000 >> i);
                }
            }
            result += int256(w);
        }
    }

    /* =================================================== */
    /*                   LOGGING HELPERS                   */
    /* =================================================== */

    function info(string memory label, address addr) internal pure {
        console2.log(string.concat(label, ":"), addr);
    }

    function info(string memory label, uint256 value) internal pure {
        console2.log(string.concat(label, ":"), value);
    }

    function info(string memory label, int256 value) internal pure {
        console2.log(string.concat(label, ":"), value);
    }

    function infoLine() internal pure {
        console2.log("-------------------------------------------------------------------");
    }
}
