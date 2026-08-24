## 0. Static structure (deploy seed)

| tier | band (cumulative net stake, TRUST) | width | deposit fee | withdrawal fee | earns from source tiers (α=1, σ=4) |
|---:|---|---:|---:|---:|---|
| 0 | 0 → 5,000 | 5,000 | 1.0% | 2.0% | T1 (75%), T2 (50%), T3 (25%) |
| 1 | 5,000 → 11,000 | 6,000 | 1.5% | 2.5% | T2 (75%), T3 (50%), T4 (25%) |
| 2 | 11,000 → 18,200 | 7,200 | 2.0% | 3.0% | T3 (75%), T4 (50%), T5 (25%) |
| 3 | 18,200 → 26,840 | 8,640 | 2.5% | 3.5% | T4 (75%), T5 (50%), T6 (25%) |
| 4 | 26,840 → 37,208 | 10,368 | 3.0% | 4.0% | T5 (75%), T6 (50%), T7 (25%) |
| 5 | 37,208 → 49,650 | 12,442 | 3.5% | 4.5% | T6 (75%), T7 (50%), T8 (25%) |
| 6 | 49,650 → 64,580 | 14,930 | 4.0% | 5.0% | T7 (75%), T8 (50%), T9 (25%) |
| 7 | 64,580 → 82,495 | 17,916 | 4.5% | 5.5% | T8 (75%), T9 (50%), T10 (25%) |
| 8 | 82,495 → 103,995 | 21,499 | 5.0% | 6.0% | T9 (75%), T10 (50%), T11 (25%) |
| 9 | 103,995 → 129,793 | 25,799 | 5.5% | 6.5% | T10 (75%), T11 (50%), T12 (25%) |
| 10 | 129,793 → 160,752 | 30,959 | 6.0% | 7.0% | T11 (75%), T12 (50%) |
| 11 | 160,752 → 197,903 | 37,150 | 6.5% | 7.5% | T12 (75%) |
| 12 | 197,903 → ∞ | terminal | 7.0% | 8.0% | — (nothing above) |

## S1. Linear climb: one cohort fills each band, T0 → T12

Each cohort C_k deposits the gross amount whose net stake exactly fills band k (MV fees 1.75% + curve fee netted). Vault ends at the T12 lower edge + 44,580.

| cohort | gross in | curve fee paid | eff. curve rate | net stake | bucket | vault after | earned by end of climb | earned − fee |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| C0 | 5,142 | 51.88 | 1.01% | 5,000 | T0 | 5,000 | 191.44 | 139.57 |
| C1 | 6,202 | 93.59 | 1.51% | 6,000 | T1 | 11,000 | 220.25 | 126.66 |
| C2 | 7,481 | 150.30 | 2.01% | 7,200 | T2 | 18,200 | 299.21 | 148.91 |
| C3 | 9,024 | 226.42 | 2.51% | 8,640 | T3 | 26,840 | 423.25 | 196.83 |
| C4 | 10,886 | 327.57 | 3.01% | 10,368 | T4 | 37,208 | 585.76 | 258.19 |
| C5 | 13,132 | 460.83 | 3.51% | 12,442 | T5 | 49,650 | 797.34 | 336.52 |
| C6 | 15,842 | 635.14 | 4.01% | 14,930 | T6 | 64,580 | 1,071.34 | 436.20 |
| C7 | 19,112 | 861.81 | 4.51% | 17,916 | T7 | 82,495 | 1,424.53 | 562.72 |
| C8 | 23,058 | 1,155.02 | 5.01% | 21,499 | T8 | 103,995 | 1,877.94 | 722.92 |
| C9 | 27,818 | 1,532.60 | 5.51% | 25,799 | T9 | 129,793 | 2,457.10 | 924.50 |
| C10 | 33,563 | 2,016.92 | 6.01% | 30,959 | T10 | 160,752 | 2,457.95 | 441.03 |
| C11 | 40,495 | 2,635.99 | 6.51% | 37,150 | T11 | 197,903 | 1,709.94 | -926.05 |
| C12 | 48,855 | 3,419.87 | 7.00% | 44,581 | T12 | 242,483 | 0.00 | -3,419.87 |
| **Σ** | | **13,567.92** | | | | | **13,516.04** | protocolAccrued 51.88 |

Solvency check: curve balance 13,567.920320 = earned 13,516.044977 + protocolAccrued 51.875343 + unattributed dust 0.000000000 TRUST.


### S1b. Full unwind — LIFO (last cohort leaves first: vault walks back down T12 → T0)

| exiting | vault tier at exit | exit fee (rate by bucket) | exit fee goes to | lifetime earned | lifetime curve fees paid | net |
|---|---:|---:|---|---:|---:|---:|
| C12 | T12 | 3,566.44 (8.0%) | reroute→T11 | 0.00 | 6,986.31 | -6,986.31 |
| C11 | T12 | 2,786.28 (7.5%) | reroute→T10 | 5,276.38 | 5,422.27 | -145.89 |
| C10 | T11 | 2,167.11 (7.0%) | reroute→T9 | 5,244.23 | 4,184.03 | 1,060.21 |
| C9 | T10 | 1,676.93 (6.5%) | reroute→T8 | 4,624.21 | 3,209.53 | 1,414.68 |
| C8 | T9 | 1,289.95 (6.0%) | reroute→T7 | 3,554.86 | 2,444.96 | 1,109.90 |
| C7 | T8 | 985.37 (5.5%) | reroute→T6 | 2,714.47 | 1,847.18 | 867.29 |
| C6 | T7 | 746.50 (5.0%) | reroute→T5 | 2,056.72 | 1,381.64 | 675.08 |
| C5 | T6 | 559.87 (4.5%) | reroute→T4 | 1,543.84 | 1,020.70 | 523.14 |
| C4 | T5 | 414.72 (4.0%) | reroute→T3 | 1,145.63 | 742.29 | 403.34 |
| C3 | T4 | 302.40 (3.5%) | reroute→T2 | 837.97 | 528.82 | 309.15 |
| C2 | T3 | 216.00 (3.0%) | reroute→T1 | 601.61 | 366.30 | 235.31 |
| C1 | T2 | 150.00 (2.5%) | reroute→T0 | 436.25 | 243.59 | 192.66 |
| C0 | T1 | 100.00 (2.0%) | protocol | 341.44 | 151.88 | 189.57 |

protocolAccrued at the end: 151.88 TRUST; curve balance 28,529.49; Σ earned-but-unclaimed 28,377.61.


### S1b. Full unwind — FIFO (earliest cohort leaves first: vault stays high, then collapses)

| exiting | vault tier at exit | exit fee (rate by bucket) | exit fee goes to | lifetime earned | lifetime curve fees paid | net |
|---|---:|---:|---|---:|---:|---:|
| C0 | T12 | 100.00 (2.0%) | reroute→T1 | 191.44 | 151.88 | 39.57 |
| C1 | T12 | 150.00 (2.5%) | reroute→T2 | 320.25 | 243.59 | 76.66 |
| C2 | T12 | 216.00 (3.0%) | reroute→T3 | 449.21 | 366.30 | 82.91 |
| C3 | T12 | 302.40 (3.5%) | reroute→T4 | 639.25 | 528.82 | 110.43 |
| C4 | T12 | 414.72 (4.0%) | reroute→T5 | 888.16 | 742.29 | 145.87 |
| C5 | T12 | 559.87 (4.5%) | reroute→T6 | 1,212.06 | 1,020.70 | 191.37 |
| C6 | T11 | 746.50 (5.0%) | reroute→T7 | 1,631.21 | 1,381.64 | 249.57 |
| C7 | T11 | 985.37 (5.5%) | reroute→T8 | 2,171.02 | 1,847.18 | 323.84 |
| C8 | T10 | 1,289.95 (6.0%) | reroute→T9 | 2,863.31 | 2,444.96 | 418.35 |
| C9 | T10 | 1,676.93 (6.5%) | reroute→T10 | 3,747.05 | 3,209.53 | 537.52 |
| C10 | T9 | 2,167.11 (7.0%) | reroute→T11 | 4,134.88 | 4,184.03 | -49.14 |
| C11 | T7 | 2,786.28 (7.5%) | reroute→T12 | 3,877.04 | 5,422.27 | -1,545.23 |
| C12 | T5 | 3,566.44 (8.0%) | protocol | 2,786.28 | 6,986.31 | -4,200.03 |

protocolAccrued at the end: 3,618.32 TRUST; curve balance 28,529.49; Σ earned-but-unclaimed 24,911.17.


## S2. A multi-band deposit is partly paid back to itself

Vault pre-built by cohorts at T0, T1, T2 (bands filled) plus 1,000 TRUST into T3. A fresh account then deposits X in one transaction. The table shows how much of X's own curve fee lands in X's own claimable balance immediately after the deposit — the doc claims this is exactly zero.

| X (gross) | bands traversed | curve fee paid | X's claimable right after | self-rebate | X's final bucket |
|---:|---|---:|---:|---:|---:|
| 1,000 | T3…T3 (1) | 25.00 | 0.00 | 0.00% | T3 |
| 5,000 | T3…T3 (1) | 125.00 | 0.00 | 0.00% | T3 |
| 10,000 | T3…T4 (2) | 260.82 | 26.76 | 10.26% | T3 |
| 20,000 | T3…T5 (3) | 568.20 | 164.59 | 28.97% | T4 |
| 40,000 | T3…T6 (4) | 1,311.11 | 588.64 | 44.90% | T5 |
| 60,000 | T3…T7 (5) | 2,176.26 | 1,345.79 | 61.84% | T5 |
| 100,000 | T3…T9 (7) | 4,205.82 | 3,368.52 | 80.09% | T6 |
| 200,000 | T3…T12 (10) | 10,442.89 | 9,594.92 | 91.88% | T8 |

## S3. Sawtooth: the vault climbs, drops, climbs again

| step | event | vault tier after | C0 | C1 | C2 | C3 | C4 | C5 | C6 | N2 | N3 | N4 | W | L | M | protocolAccrued |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | C0 fills T0 | T1 (5,000) | 0.0 |  |  |  |  |  |  |  |  |  |  |  |  | 51.9 |
| 1 | C1 fills T1 | T2 (11,000) | 93.6 | 0.0 |  |  |  |  |  |  |  |  |  |  |  | 51.9 |
| 2 | C2 fills T2 | T3 (18,200) | 153.7 | 90.2 | 0.0 |  |  |  |  |  |  |  |  |  |  | 51.9 |
| 3 | C3 fills T3 | T4 (26,840) | 191.4 | 165.7 | 113.2 | 0.0 |  |  |  |  |  |  |  |  |  | 51.9 |
| 4 | C4 fills T4 | T5 (37,208) | 191.4 | 220.2 | 222.4 | 163.8 | 0.0 |  |  |  |  |  |  |  |  | 51.9 |
| 5 | C5 fills T5 | T6 (49,650) | 191.4 | 220.2 | 299.2 | 317.4 | 230.4 | 0.0 |  |  |  |  |  |  |  | 51.9 |
| 6 | C6 fills T6 | T7 (64,580) | 191.4 | 220.2 | 299.2 | 423.3 | 442.1 | 317.6 | 0.0 |  |  |  |  |  |  | 51.9 |
| 7 | C6 exits (all) | T6 (49,650) | 191.4 | 220.2 | 299.2 | 423.3 | 442.1 | 1,064.1 | 0.0 |  |  |  |  |  |  | 51.9 |
| 8 | C5 exits (all) | T5 (37,208) | 191.4 | 220.2 | 299.2 | 423.3 | 1,002.0 | 1,064.1 | 0.0 |  |  |  |  |  |  | 51.9 |
| 9 | C4 exits (all) | T4 (26,840) | 191.4 | 220.2 | 299.2 | 838.0 | 1,002.0 | 1,064.1 | 0.0 |  |  |  |  |  |  | 51.9 |
| 10 | C3 exits (all) | T3 (18,200) | 191.4 | 220.2 | 601.6 | 838.0 | 1,002.0 | 1,064.1 | 0.0 |  |  |  |  |  |  | 51.9 |
| 11 | C2 exits half | T2 (14,600) | 191.4 | 328.2 | 601.6 | 838.0 | 1,002.0 | 1,064.1 | 0.0 |  |  |  |  |  |  | 51.9 |
| 12 | N2 enters at T2 | T3 (18,200) | 221.5 | 373.3 | 601.6 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 0.0 |  |  |  |  |  | 51.9 |
| 13 | N3 enters at T3 | T4 (26,840) | 259.2 | 448.8 | 658.2 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 56.6 | 0.0 |  |  |  |  | 51.9 |
| 14 | N4 enters at T4 | T5 (37,208) | 259.2 | 503.4 | 712.8 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 111.2 | 163.8 | 0.0 |  |  |  | 51.9 |
| 15 | whale W deposits 60k (T5→T8) | T8 (93,601) | 259.2 | 503.4 | 751.6 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 150.0 | 425.1 | 660.5 | 1,557.9 |  |  | 51.9 |
| 16 | C0 exits (all) | T8 (88,601) | 259.2 | 603.4 | 751.6 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 150.0 | 425.1 | 660.5 | 1,557.9 |  |  | 51.9 |
| 17 | C1 exits (all) | T8 (82,601) | 259.2 | 603.4 | 826.6 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 225.0 | 425.1 | 660.5 | 1,557.9 |  |  | 51.9 |
| 18 | W exits (all) | T3 (26,208) | 259.2 | 603.4 | 826.6 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 225.0 | 425.1 | 3,480.1 | 1,557.9 |  |  | 51.9 |
| 19 | N4 exits | T2 (15,840) | 259.2 | 603.4 | 826.6 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 225.0 | 839.9 | 3,480.1 | 1,557.9 |  |  | 51.9 |
| 20 | L deposits 5k at low tier | T3 (20,640) | 259.2 | 603.4 | 850.5 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 248.9 | 839.9 | 3,480.1 | 1,557.9 | 15.7 |  | 101.2 |
| 21 | M deposits 30k (multi-band) | T5 (49,181) | 259.2 | 603.4 | 1,034.7 | 838.0 | 1,002.0 | 1,064.1 | 0.0 | 433.1 | 1,021.1 | 3,480.1 | 1,557.9 | 116.4 | 283.1 | 101.2 |

Buckets at the end: C2→T2 (3,600), N2→T2 (3,600), N3→T3 (8,640), L→T3 (4,800), M→T4 (28,542)


## S4. Stranded cohort: after early exits + a drawdown, deposit fees flow to nobody

Remaining holders: C4 (bucket T4, 10,368), C5 (bucket T5, 12,442). Vault = 22,810 → **T3**.

| new deposit | source tier | bands | curve fee | to C4 | to C5 | to protocolAccrued |
|---:|---:|---|---:|---:|---:|---:|
| 2,000 | T3 | T3…T3 | 50.00 | 0.00 | 0.00 | 50.00 |
| 5,000 | T3 | T3…T4 | 139.15 | 0.00 | 0.00 | 55.49 |
| 10,000 | T4 | T4…T5 | 310.26 | 18.12 | 0.00 | 0.00 |
| 20,000 | T5 | T5…T6 | 744.89 | 148.64 | 94.46 | 0.00 |
| 40,000 | T6 | T6…T8 | 1,836.81 | 100.40 | 239.07 | 0.00 |

Vault after: 95,381 (T8). Note the new depositors D0–D4 (buckets T2–T4) start earning before C4/C5 do, because fees flow only DOWN from the band being charged.


## S5. Bucket averaging (stake-weighted average entry tier)

### S5a. Exit-fee effect of merging a high-bucket position with a later low-tier deposit

Holder has S = 10,000 at bucket T8. The vault has fallen to T2. They top up D at T2 from the SAME wallet (bucket re-averages) vs from a SEPARATE wallet. Exit fee on everything afterwards:

| D / S | new avg tier | new bucket | exit fee, same wallet | exit fee, separate wallets | delta (bps of S+D) |
|---:|---:|---:|---:|---:|---:|
| 0.0 | 8.000 | T8 | 600.00 | 600.00 | +0.0 |
| 1.0 | 5.000 | T5 | 900.00 | 900.00 | +0.0 |
| 1.4 | 4.500 | T5 | 1,080.00 | 1,020.00 | +25.0 |
| 2.0 | 4.000 | T4 | 1,200.00 | 1,200.00 | +0.0 |
| 2.8 | 3.579 | T4 | 1,520.00 | 1,440.00 | +21.1 |
| 3.0 | 3.500 | T4 | 1,600.00 | 1,500.00 | +25.0 |
| 3.2 | 3.429 | T3 | 1,470.00 | 1,560.00 | -21.4 |
| 4.0 | 3.200 | T3 | 1,750.00 | 1,800.00 | -10.0 |
| 5.0 | 3.000 | T3 | 2,100.00 | 2,100.00 | +0.0 |
| 6.0 | 2.857 | T3 | 2,450.00 | 2,400.00 | +7.1 |

### S5b. Seniority loss: an early holder who tops up from the same wallet moves their WHOLE position to a higher bucket

- Same wallet: C1's bucket goes T1 → **T5** for all ~26k of stake. Earnings during the next climb (T7→T10 filled by new cohorts): **247.98 TRUST**.
- Separate wallet: C1 stays at T1 and the top-up sits at **T6**. Combined earnings over the same climb: **791.14 TRUST**.
- Splitting wallets earns **3.19×** here. Merging also drops C1 out of T1's denominator, so the other T1 holders' share rises — the kernel pie is fixed per tier, the averaging only moves who sits in which slice.


## S6. Tier allocation is stake-agnostic: thin tiers are disproportionately lucrative

### S6a. Deposit-side: the tier split ignores how much stake each tier holds

State seeded directly: T4 holds 100,000 (A4), T6 holds 100,000 (A6), T5 holds a varying amount (A5). Vault sits just inside T7, so a 5,000 deposit is charged 4.5% = 225 and the kernel pays T6/T5/T4 at 50/33/17 when all three are eligible.

| T5 stake (A5) | floor | T4 (100k) gets | T5 gets | T6 (100k) gets | A5 return on its stake | A4 return |
|---:|---:|---:|---:|---:|---:|---:|
| 100,000 | 0 | 37.50 | 75.00 | 112.50 | 0% | 0.037% |
| 10,000 | 0 | 37.50 | 75.00 | 112.50 | 1% | 0.037% |
| 1,000 | 0 | 37.50 | 75.00 | 112.50 | 8% | 0.037% |
| 100 | 0 | 37.50 | 75.00 | 112.50 | 75% | 0.037% |
| 1 | 0 | 37.50 | 75.00 | 112.50 | 7500% | 0.037% |
| 1e-18 | 0 | 37.50 | 75.00 | 112.50 | 7.50e+21% | 0.037% |
| 100,000 | 1,000 | 37.50 | 75.00 | 112.50 | 0% | 0.037% |
| 10,000 | 1,000 | 37.50 | 75.00 | 112.50 | 1% | 0.037% |
| 1,000 | 1,000 | 37.50 | 75.00 | 112.50 | 8% | 0.037% |
| 100 | 1,000 | 56.25 | 0.00 | 168.75 | — | 0.056% |
| 1 | 1,000 | 56.25 | 0.00 | 168.75 | — | 0.056% |
| 1e-18 | 1,000 | 56.25 | 0.00 | 168.75 | — | 0.056% |

The split across tiers is fixed by the kernel regardless of how much stake each tier holds; only the split *within* a tier is pro-rata. A 1-wei position alone in an eligible tier takes that tier's whole slice. The 1,000 TRUST floor only raises the ticket price to 1,000 TRUST of (recoverable) principal.

### S6b. Redeem-side: a lone whale's exit fee goes 100% to the nearest eligible tier ABOVE

| whale stake at T5 (alone) | sniper stake at T6 | floor | whale exit fee | sniper receives | sniper return |
|---:|---:|---:|---:|---:|---:|
| 12,442 | 0.001 | 0 | 559.87 | 559.87 | 55987200.00% |
| 12,442 | 1 | 0 | 559.87 | 559.87 | 55987.20% |
| 12,442 | 1,000 | 0 | 559.87 | 559.87 | 55.99% |
| 12,442 | 10,000 | 0 | 559.87 | 559.87 | 5.60% |
| 12,442 | 0.001 | 1,000 | 559.87 | 0.00 | 0% (reroute → T4) |
| 12,442 | 1 | 1,000 | 559.87 | 0.00 | 0% (reroute → T4) |
| 12,442 | 1,000 | 1,000 | 559.87 | 0.00 | 0% (reroute → T4) |
| 12,442 | 10,000 | 1,000 | 559.87 | 559.87 | 5.60% |

## S7. Just-in-time sandwich around a large deposit

Vault sits mid-T5 with one resident cohort per band (T0–T5 filled; T5 cohort is the *only* T5 resident unless noted). Attacker deposits X at T5 one tx before whale deposits W (multi-band), then exits right after. Profit = claimable − curve in-fee − curve out-fee − MV fees (1.75% in + 2% out).

| W (whale) | X (attacker) | attacker claimable | fees paid (curve+MV) | net profit | profit / X | T5 resident stake |
|---:|---:|---:|---:|---:|---:|---:|
| 20,000 | 100 | 2.06 | 11.41 | -9.35 | -9.35% | 6,221 |
| 20,000 | 1,000 | 21.97 | 114.09 | -92.12 | -9.21% | 6,221 |
| 20,000 | 5,000 | 137.72 | 570.44 | -432.72 | -8.65% | 6,221 |
| 20,000 | 10,000 | 253.07 | 1,157.49 | -904.41 | -9.04% | 6,221 |
| 20,000 | 20,000 | 487.51 | 2,439.52 | -1,952.02 | -9.76% | 6,221 |
| 20,000 | 50,000 | 1,538.83 | 6,551.81 | -5,012.98 | -10.03% | 6,221 |
| 50,000 | 100 | 8.87 | 11.41 | -2.54 | -2.54% | 6,221 |
| 50,000 | 1,000 | 83.05 | 114.09 | -31.04 | -3.10% | 6,221 |
| 50,000 | 5,000 | 342.57 | 570.44 | -227.87 | -4.56% | 6,221 |
| 50,000 | 10,000 | 497.58 | 1,157.49 | -659.90 | -6.60% | 6,221 |
| 50,000 | 20,000 | 1,004.20 | 2,439.52 | -1,435.32 | -7.18% | 6,221 |
| 50,000 | 50,000 | 2,148.49 | 6,551.81 | -4,403.32 | -8.81% | 6,221 |
| 100,000 | 100 | 12.58 | 11.41 | 1.17 | 1.17% | 6,221 |
| 100,000 | 1,000 | 113.75 | 114.09 | -0.33 | -0.03% | 6,221 |
| 100,000 | 5,000 | 414.61 | 570.44 | -155.82 | -3.12% | 6,221 |
| 100,000 | 10,000 | 535.93 | 1,157.49 | -621.56 | -6.22% | 6,221 |
| 100,000 | 20,000 | 1,419.89 | 2,439.52 | -1,019.63 | -5.10% | 6,221 |
| 100,000 | 50,000 | 2,544.41 | 6,551.81 | -4,007.40 | -8.01% | 6,221 |
| 20,000 | 100 | 4.12 | 11.41 | -7.29 | -7.29% | 0 |
| 20,000 | 1,000 | 43.94 | 114.09 | -70.15 | -7.01% | 0 |
| 20,000 | 5,000 | 280.69 | 570.44 | -289.75 | -5.79% | 0 |
| 20,000 | 10,000 | 431.27 | 1,157.49 | -726.21 | -7.26% | 0 |
| 20,000 | 20,000 | 798.38 | 2,439.52 | -1,641.15 | -8.21% | 0 |
| 20,000 | 50,000 | 2,237.14 | 6,551.81 | -4,314.67 | -8.63% | 0 |
| 50,000 | 100 | 434.34 | 11.41 | 422.93 | 422.93% | 0 |
| 50,000 | 1,000 | 493.08 | 114.09 | 378.99 | 37.90% | 0 |
| 50,000 | 5,000 | 754.33 | 570.44 | 183.89 | 3.68% | 0 |
| 50,000 | 10,000 | 836.62 | 1,157.49 | -320.87 | -3.21% | 0 |
| 50,000 | 20,000 | 1,408.54 | 2,439.52 | -1,030.98 | -5.15% | 0 |
| 50,000 | 50,000 | 2,847.52 | 6,551.81 | -3,704.29 | -7.41% | 0 |
| 100,000 | 100 | 680.14 | 11.41 | 668.73 | 668.73% | 0 |
| 100,000 | 1,000 | 724.30 | 114.09 | 610.21 | 61.02% | 0 |
| 100,000 | 5,000 | 920.68 | 570.44 | 350.24 | 7.00% | 0 |
| 100,000 | 10,000 | 900.18 | 1,157.49 | -257.30 | -2.57% | 0 |
| 100,000 | 20,000 | 1,825.68 | 2,439.52 | -613.84 | -3.07% | 0 |
| 100,000 | 50,000 | 3,244.33 | 6,551.81 | -3,307.48 | -6.61% | 0 |

## S8. Invariant fuzz on the reference model (random deposits/redeems, 40 accounts, 2,000 ops × 5 seeds)

- Σ tierStake == vaultStake and Σ userStake-by-bucket == tierStake held at every step (10,000 checks).
- balance − (Σ earned + Σ pending + protocolAccrued) was never negative; minimum slack observed: **0 wei** (0 violations).


## S9. What-if: candidate mitigations, measured on the same scenarios

- **A** — exclude the depositor's own current position from every recipient denominator while their deposit is replayed (settle → distribute-excluding → land + re-base; the redeem leg already works this way). This is what commit `8579c5e` did.
- **B** — weight each prior tier by kernel × stake instead of kernel alone, so a wei of stake at distance d earns `pool·w_d / Σ w·stake` regardless of how thin its tier is.
- **C** — distribute every band's fee from the **pre-deposit** tier (recipients = tiers below where the vault stood before the deposit), keeping the per-band *rate*. This is the targeting `8579c5e` used and the targeting `docs/call-flows/dynamic-fee-curve.md` §4 still describes. A+C together is the `8579c5e` design.

### S9a. S2 self-rebate (share of own curve fee immediately claimable by the depositor)

| X | current | A | B | C | A+C (8579c5e) | A+B+C |
|---:|---:|---:|---:|---:|---:|---:|
| 10,000 | 10.26% | 0.00% | 11.48% | 0.00% | 0.00% | 0.00% |
| 20,000 | 28.97% | 0.00% | 34.47% | 0.00% | 0.00% | 0.00% |
| 60,000 | 61.84% | 0.00% | 79.43% | 0.00% | 0.00% | 0.00% |
| 200,000 | 91.88% | 0.00% | 95.62% | 0.00% | 0.00% | 0.00% |

### S9b. S7 JIT sandwich, attacker ALONE in the vault's current tier (net profit, TRUST)

| W | X | current | A | B | C | A+C (8579c5e) | A+B+C |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 50,000 | 100 | 422.93 | 1,308.93 | -5.85 | -11.41 | -11.41 | -11.41 |
| 50,000 | 1,000 | 378.99 | 1,251.28 | -57.67 | -114.09 | -114.09 | -114.09 |
| 50,000 | 5,000 | 183.89 | 995.17 | -268.60 | -570.44 | -570.44 | -570.44 |
| 100,000 | 100 | 668.73 | 4,032.81 | -4.92 | -11.41 | -11.41 | -11.41 |
| 100,000 | 1,000 | 610.21 | 3,984.27 | -48.85 | -114.09 | -114.09 | -114.09 |
| 100,000 | 5,000 | 350.24 | 3,768.64 | -235.16 | -570.44 | -570.44 | -570.44 |

### S9c. Pre-positioned (not JIT): attacker sits alone in a thin PRIOR tier when a whale deposit arrives

Vault mid-T3. Attacker deposits X (bucket T3, alone — T3 was otherwise empty). A filler then pushes the vault just past the T4 edge (its bucket rounds to T3 as well, so T3 = attacker + filler). Whale deposits W from T4. The attacker is a genuine prior-tier holder here, so C does not exclude them; whether a thin T3 is a jackpot is decided by B.

| W | X | T3 total stake | current | A | B | C | A+C (8579c5e) | A+B+C |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 50,000 | 100 | 6,690 | -1 | 17 | -4 | 11 | 11 | 4 |
| 50,000 | 1,000 | 6,690 | -10 | 164 | -43 | 107 | 107 | 39 |
| 50,000 | 5,000 | 6,690 | -52 | 815 | -217 | 535 | 535 | 196 |
| 100,000 | 100 | 6,690 | -1 | 54 | -4 | 38 | 38 | 22 |
| 100,000 | 1,000 | 6,690 | -10 | 530 | -43 | 382 | 382 | 222 |
| 100,000 | 5,000 | 6,690 | -49 | 2,645 | -215 | 1,908 | 1,908 | 1,109 |

### S9d. Ordinary cohorts (S1 linear climb, one cohort per band): earned by the top of the climb

| cohort | current | A | B | C | A+C (8579c5e) | A+B+C |
|---|---:|---:|---:|---:|---:|---:|
| C0 | 191.44 | 191.44 | 176.59 | 191.44 | 191.44 | 176.59 |
| C1 | 220.25 | 220.25 | 209.44 | 220.25 | 220.25 | 209.44 |
| C2 | 299.21 | 299.21 | 288.23 | 299.21 | 299.21 | 288.23 |
| C3 | 423.25 | 423.25 | 408.84 | 423.25 | 423.25 | 408.84 |
| C4 | 585.76 | 585.76 | 566.96 | 585.76 | 585.76 | 566.96 |
| C5 | 797.34 | 797.34 | 772.95 | 797.34 | 797.34 | 772.95 |
| C6 | 1,071.34 | 1,071.34 | 1,039.85 | 1,071.34 | 1,071.34 | 1,039.85 |
| C7 | 1,424.53 | 1,424.53 | 1,384.04 | 1,424.53 | 1,424.53 | 1,384.04 |
| C8 | 1,877.94 | 1,877.94 | 1,826.09 | 1,877.94 | 1,877.94 | 1,826.09 |
| C9 | 2,457.10 | 2,457.10 | 2,391.11 | 2,457.10 | 2,457.10 | 2,391.11 |
| C10 | 2,457.95 | 2,457.95 | 2,538.23 | 2,457.95 | 2,457.95 | 2,538.23 |
| C11 | 1,709.94 | 1,709.94 | 1,913.71 | 1,709.94 | 1,709.94 | 1,913.71 |
| C12 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

### S9e. A realistic mixed climb (cohorts of varied size, several multi-band whales): total fee captured by the whales themselves vs by prior cohorts

| variant | curve fees paid by 5 whale deposits | claimable the whales gained DURING their own deposits | self-captured | protocolAccrued |
|---|---:|---:|---:|---:|
| current | 9,959 | 1,781 | 17.9% | 51 |
| A | 9,959 | 0 | 0.0% | 51 |
| B | 9,959 | 2,214 | 22.2% | 51 |
| C | 9,959 | 0 | 0.0% | 104 |
| A+C (8579c5e) | 9,959 | 0 | 0.0% | 104 |
| A+B+C | 9,959 | 0 | 0.0% | 104 |