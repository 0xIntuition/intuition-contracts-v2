/**
 * getSwapPath.ts — Finds the optimal Slipstream (CL) path for swapping any token to TRUST on Base.
 *
 * Routing logic:
 *   - USDC → TRUST: direct swap, picks best tick spacing by quote
 *   - WETH → TRUST: tries WETH→USDC→TRUST (two-hop) AND WETH→TRUST (direct), picks best
 *   - Other → TRUST: tries tokenIn→USDC→TRUST and tokenIn→WETH→USDC→TRUST, picks best
 *
 * Usage:
 *   bun src/utils/getSwapPath.ts <tokenInAddress> <amountInRawUnits>
 *
 * Examples:
 *   bun src/utils/getSwapPath.ts 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 10000000          # 10 USDC
 *   bun src/utils/getSwapPath.ts 0x4200000000000000000000000000000000000006 10000000000000000 # 0.01 ETH
 *   bun src/utils/getSwapPath.ts 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb 10000000          # 10 DAI
 *
 * Environment:
 *   Reads BASE_RPC_URL or falls back to Alchemy with API_KEY_ALCHEMY.
 *   Bun auto-loads .env so the foundry .env works out of the box.
 */

import { BigNumber, Contract, constants, providers, utils } from "ethers";

// ============ Base Mainnet Addresses ============

const TRUST = "0x6cd905dF2Ed214b22e0d48FF17CD4200C1C6d8A3";
const WETH = "0x4200000000000000000000000000000000000006";
const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

const CL_FACTORY = "0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a";
const CL_QUOTER = "0x3d4C22254F86f64B7eC90ab8F7aeC1FBFD271c6C";

const TICK_SPACINGS = [1, 10, 50, 100, 200, 2000];

const TOKEN_LABELS: Record<string, string> = {
    [TRUST.toLowerCase()]: "TRUST",
    [WETH.toLowerCase()]: "WETH",
    [USDC.toLowerCase()]: "USDC",
};

// ============ ABIs (minimal) ============

const FACTORY_ABI = ["function getPool(address, address, int24) view returns (address)"];
const QUOTER_ABI = [
    "function quoteExactInput(bytes path, uint256 amountIn) returns (uint256 amountOut, uint160[], uint32[], uint256)",
];

// ============ Setup ============

function getRpcUrl(): string {
    if (process.env.BASE_RPC_URL) return process.env.BASE_RPC_URL;
    if (process.env.API_KEY_ALCHEMY)
        return `https://base-mainnet.g.alchemy.com/v2/${process.env.API_KEY_ALCHEMY}`;
    throw new Error("Set BASE_RPC_URL or API_KEY_ALCHEMY in your environment / .env file");
}

const provider = new providers.JsonRpcProvider(getRpcUrl());
const factory = new Contract(CL_FACTORY, FACTORY_ABI, provider);
const quoter = new Contract(CL_QUOTER, QUOTER_ABI, provider);

// ============ Helpers ============

function eq(a: string, b: string): boolean {
    return a.toLowerCase() === b.toLowerCase();
}

function label(address: string): string {
    return TOKEN_LABELS[address.toLowerCase()] ?? address.slice(0, 10) + "...";
}

function encodePath(tokens: string[], tickSpacings: number[]): string {
    const types: string[] = [];
    const values: (string | number)[] = [];
    for (let i = 0; i < tokens.length; i++) {
        types.push("address");
        values.push(tokens[i]);
        if (i < tickSpacings.length) {
            types.push("int24");
            values.push(tickSpacings[i]);
        }
    }
    return utils.solidityPack(types, values);
}

// ============ Pool Discovery ============

interface PoolInfo {
    tickSpacing: number;
    pool: string;
}

async function findExistingPools(tokenA: string, tokenB: string): Promise<PoolInfo[]> {
    const results = await Promise.all(
        TICK_SPACINGS.map(async (ts) => {
            try {
                const pool: string = await factory.getPool(tokenA, tokenB, ts);
                return { tickSpacing: ts, pool };
            } catch {
                return { tickSpacing: ts, pool: constants.AddressZero };
            }
        }),
    );
    return results.filter((r) => r.pool !== constants.AddressZero);
}

// ============ Quoting ============

interface QuotedRoute {
    path: string;
    tokens: string[];
    tickSpacings: number[];
    quote: BigNumber;
}

async function quoteRoute(
    tokens: string[],
    tickSpacings: number[],
    amountIn: BigNumber,
): Promise<QuotedRoute | null> {
    const path = encodePath(tokens, tickSpacings);
    try {
        const result = await quoter.callStatic.quoteExactInput(path, amountIn);
        const quote = result.amountOut as BigNumber;
        if (quote.gt(0)) return { path, tokens, tickSpacings, quote };
    } catch {
        // Pool has no liquidity or path is invalid
    }
    return null;
}

// ============ Route Finding ============

async function findBestRoute(tokenIn: string, amountIn: BigNumber): Promise<QuotedRoute> {
    if (eq(tokenIn, TRUST)) throw new Error("Cannot swap TRUST to TRUST");

    const candidates: Promise<QuotedRoute | null>[] = [];

    if (eq(tokenIn, USDC)) {
        // USDC → TRUST: direct, try every tick spacing
        const pools = await findExistingPools(USDC, TRUST);
        console.log(`  Found ${pools.length} USDC/TRUST pool(s): ts=[${pools.map((p) => p.tickSpacing).join(", ")}]`);
        for (const p of pools) {
            candidates.push(quoteRoute([USDC, TRUST], [p.tickSpacing], amountIn));
        }
    } else if (eq(tokenIn, WETH)) {
        // WETH → TRUST: try two-hop via USDC and direct
        const wethUsdcPools = await findExistingPools(WETH, USDC);
        const usdcTrustPools = await findExistingPools(USDC, TRUST);
        const wethTrustPools = await findExistingPools(WETH, TRUST);

        console.log(`  Found ${wethUsdcPools.length} WETH/USDC pool(s): ts=[${wethUsdcPools.map((p) => p.tickSpacing).join(", ")}]`);
        console.log(`  Found ${usdcTrustPools.length} USDC/TRUST pool(s): ts=[${usdcTrustPools.map((p) => p.tickSpacing).join(", ")}]`);
        console.log(`  Found ${wethTrustPools.length} WETH/TRUST pool(s): ts=[${wethTrustPools.map((p) => p.tickSpacing).join(", ")}]`);

        // Two-hop: WETH → USDC → TRUST
        for (const wu of wethUsdcPools) {
            for (const ut of usdcTrustPools) {
                candidates.push(quoteRoute([WETH, USDC, TRUST], [wu.tickSpacing, ut.tickSpacing], amountIn));
            }
        }
        // Direct: WETH → TRUST
        for (const wt of wethTrustPools) {
            candidates.push(quoteRoute([WETH, TRUST], [wt.tickSpacing], amountIn));
        }
    } else {
        // Arbitrary token: try via USDC and via WETH→USDC
        const tokenUsdcPools = await findExistingPools(tokenIn, USDC);
        const tokenWethPools = await findExistingPools(tokenIn, WETH);
        const usdcTrustPools = await findExistingPools(USDC, TRUST);
        const wethUsdcPools = await findExistingPools(WETH, USDC);

        console.log(`  Found ${tokenUsdcPools.length} ${label(tokenIn)}/USDC pool(s): ts=[${tokenUsdcPools.map((p) => p.tickSpacing).join(", ")}]`);
        console.log(`  Found ${tokenWethPools.length} ${label(tokenIn)}/WETH pool(s): ts=[${tokenWethPools.map((p) => p.tickSpacing).join(", ")}]`);

        // Route A: tokenIn → USDC → TRUST
        for (const tu of tokenUsdcPools) {
            for (const ut of usdcTrustPools) {
                candidates.push(quoteRoute([tokenIn, USDC, TRUST], [tu.tickSpacing, ut.tickSpacing], amountIn));
            }
        }

        // Route B: tokenIn → WETH → USDC → TRUST
        for (const tw of tokenWethPools) {
            for (const wu of wethUsdcPools) {
                for (const ut of usdcTrustPools) {
                    candidates.push(
                        quoteRoute(
                            [tokenIn, WETH, USDC, TRUST],
                            [tw.tickSpacing, wu.tickSpacing, ut.tickSpacing],
                            amountIn,
                        ),
                    );
                }
            }
        }
    }

    console.log(`  Quoting ${candidates.length} candidate route(s)...\n`);

    const results = (await Promise.all(candidates)).filter((r): r is QuotedRoute => r !== null);

    if (results.length === 0) {
        throw new Error(`No viable route found for ${label(tokenIn)} → TRUST`);
    }

    // Sort descending by quote
    results.sort((a, b) => (b.quote.gt(a.quote) ? 1 : b.quote.lt(a.quote) ? -1 : 0));

    // Print all viable routes
    for (let i = 0; i < results.length; i++) {
        const r = results[i];
        const hops = r.tokens
            .map((t, j) => {
                const tag = label(t);
                return j < r.tickSpacings.length ? `${tag} --(ts:${r.tickSpacings[j]})--> ` : tag;
            })
            .join("");
        const marker = i === 0 ? " <-- BEST" : "";
        console.log(`  [${i + 1}] ${hops}  =>  ${utils.formatUnits(r.quote, 18)} TRUST${marker}`);
    }

    return results[0];
}

// ============ CLI ============

async function main() {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.log("Usage:  bun src/utils/getSwapPath.ts <tokenIn> <amountInRaw>\n");
        console.log("Examples:");
        console.log(`  bun src/utils/getSwapPath.ts ${USDC} 10000000          # 10 USDC`);
        console.log(`  bun src/utils/getSwapPath.ts ${WETH} 10000000000000000  # 0.01 ETH`);
        process.exit(1);
    }

    const [tokenIn, amountInRaw] = args;
    const amountIn = BigNumber.from(amountInRaw);

    console.log(`\nFinding best route: ${label(tokenIn)} → TRUST`);
    console.log(`Amount in: ${amountIn.toString()}\n`);

    const best = await findBestRoute(tokenIn, amountIn);

    console.log(`\n========== RESULT ==========`);
    console.log(`Encoded path: ${best.path}`);
    console.log(`Expected out: ${utils.formatUnits(best.quote, 18)} TRUST`);
    console.log(`============================\n`);
}

main().catch((err) => {
    console.error("Error:", err.message);
    process.exit(1);
});
