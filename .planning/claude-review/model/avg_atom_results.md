## A. The average atom under the deploy seed

Population: users draw 800–4,000 TRUST log-uniformly (≈ $20–$100 at 2.5¢), 10 % are 'enthusiasts' at 6k–12k. The atom grows to the middle of its stall band, then oscillates there for 80 more events (60 % exits when above the mid-point, deposits otherwise). 8 seeds per row. 'Yield' is lifetime curve earnings over gross deposit; 'net-positive' means earnings exceeded every fee the user paid (curve + MultiVault, in and out).

| variant | users | median curve fee in | curve fees → protocol | users earning >0 | frontier users earning >0 | frontier earnings from deposit fees (rest = peers' exit fees) | median yield (earned/gross) | frontier median yield | best single yield | users net-positive after all fees | sub-floor tier hits |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| deploy seed, atom stalls in **T3** | 52 | 2.6% | 3.1% | 89% | 89% | 37% | 3.28% | 3.15% | 56.0% | 29% | 0 |
| deploy seed, atom stalls in **T4** | 56 | 3.0% | 1.7% | 92% | 93% | 28% | 3.99% | 3.62% | 75.4% | 32% | 0 |

### A1. Parameter sweeps (current mechanism), atom stalls in T3 and T4

| variant | users | median curve fee in | curve fees → protocol | users earning >0 | frontier users earning >0 | frontier earnings from deposit fees (rest = peers' exit fees) | median yield (earned/gross) | frontier median yield | best single yield | users net-positive after all fees | sub-floor tier hits |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| atom ≈ 22k (T3 on the seed ladder) · width0 5,000 (seed) | 52 | 2.6% | 3.1% | 89% | 89% | 37% | 3.28% | 3.15% | 56.0% | 29% | 0 |
| atom ≈ 22k (T3 on the seed ladder) · width0 2,500 (atom sits in T5) | 52 | 3.6% | 2.1% | 89% | 92% | 45% | 4.08% | 3.86% | 72.0% | 29% | 0 |
| atom ≈ 22k (T3 on the seed ladder) · width0 1,000 (atom sits in T9) | 52 | 5.8% | 1.8% | 89% | 88% | 53% | 6.66% | 8.29% | 94.2% | 34% | 0 |
| atom ≈ 22k (T3 on the seed ladder) · growth 25 bps/tier | 52 | 1.8% | 3.8% | 89% | 91% | 33% | 2.65% | 2.73% | 43.3% | 28% | 0 |
| atom ≈ 22k (T3 on the seed ladder) · kernelSpread 8 | 52 | 2.6% | 3.1% | 89% | 89% | 33% | 3.12% | 2.95% | 69.2% | 29% | 0 |
| atom ≈ 22k (T3 on the seed ladder) · floor 500 | 52 | 2.6% | 3.1% | 89% | 89% | 37% | 3.28% | 3.15% | 56.0% | 29% | 0 |
| atom ≈ 22k (T3 on the seed ladder) · floor 1,000 | 52 | 2.6% | 4.3% | 89% | 89% | 37% | 3.27% | 3.15% | 52.2% | 29% | 10 |
| atom ≈ 32k (T4 on the seed ladder) · width0 5,000 (seed) | 56 | 3.0% | 1.7% | 92% | 93% | 28% | 3.99% | 3.62% | 75.4% | 32% | 0 |
| atom ≈ 32k (T4 on the seed ladder) · width0 2,500 (atom sits in T7) | 56 | 4.4% | 0.7% | 92% | 99% | 64% | 5.25% | 9.57% | 88.3% | 34% | 0 |
| atom ≈ 32k (T4 on the seed ladder) · width0 1,000 (atom sits in T11) | 57 | 6.3% | 1.2% | 95% | 99% | 70% | 6.57% | 11.82% | 110.0% | 33% | 0 |
| atom ≈ 32k (T4 on the seed ladder) · growth 25 bps/tier | 56 | 2.0% | 3.7% | 90% | 89% | 21% | 2.77% | 2.48% | 44.7% | 25% | 0 |
| atom ≈ 32k (T4 on the seed ladder) · kernelSpread 8 | 56 | 3.0% | 1.7% | 92% | 93% | 23% | 3.79% | 3.31% | 74.7% | 32% | 0 |
| atom ≈ 32k (T4 on the seed ladder) · floor 500 | 56 | 3.0% | 1.7% | 92% | 93% | 28% | 3.99% | 3.62% | 75.4% | 32% | 0 |
| atom ≈ 32k (T4 on the seed ladder) · floor 1,000 | 56 | 3.0% | 2.1% | 92% | 93% | 28% | 3.96% | 3.64% | 60.8% | 32% | 10 |

### A2. Mechanism variants, deploy-seed parameters

A = depositor excluded · B = stake-weighted kernel · C = pre-deposit targeting · D = the source tier is itself a recipient (needs A + C) · E = no curve fee on same-band stake (fee only on the crossing portion) · F = lone-exiter slice to the fulcrum fallback instead of nearest-above.

| variant | users | median curve fee in | curve fees → protocol | users earning >0 | frontier users earning >0 | frontier earnings from deposit fees (rest = peers' exit fees) | median yield (earned/gross) | frontier median yield | best single yield | users net-positive after all fees | sub-floor tier hits |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| T3 · current | 52 | 2.6% | 3.1% | 89% | 89% | 37% | 3.28% | 3.15% | 56.0% | 29% | 0 |
| T3 · A+C (8579c5e) | 52 | 2.6% | 5.0% | 82% | 86% | 33% | 3.08% | 2.84% | 67.2% | 28% | 0 |
| T3 · A+B+C | 52 | 2.6% | 5.0% | 82% | 86% | 37% | 3.12% | 3.33% | 58.2% | 29% | 0 |
| T3 · A+B+C+F | 52 | 2.6% | 5.6% | 82% | 86% | 37% | 3.07% | 3.34% | 57.1% | 29% | 0 |
| T3 · A+C+D (source tier earns) | 52 | 2.6% | 0.5% | 92% | 95% | 47% | 3.80% | 3.90% | 38.5% | 34% | 0 |
| T3 · A+B+C+D | 52 | 2.6% | 0.5% | 92% | 95% | 54% | 4.33% | 4.79% | 28.5% | 35% | 0 |
| T3 · E (crossing-only fee) | 52 | 0.0% | 1.8% | 87% | 85% | 22% | 2.20% | 2.42% | 26.6% | 33% | 0 |
| T3 · A+B+C+E | 52 | 0.0% | 3.2% | 80% | 82% | 20% | 2.06% | 2.38% | 27.3% | 32% | 0 |
| T4 · current | 56 | 3.0% | 1.7% | 92% | 93% | 28% | 3.99% | 3.62% | 75.4% | 32% | 0 |
| T4 · A+C (8579c5e) | 56 | 3.0% | 3.7% | 84% | 85% | 20% | 3.71% | 3.26% | 81.8% | 31% | 0 |
| T4 · A+B+C | 56 | 3.0% | 3.7% | 84% | 85% | 26% | 3.80% | 3.55% | 63.2% | 31% | 0 |
| T4 · A+B+C+F | 56 | 3.0% | 3.8% | 84% | 85% | 26% | 3.73% | 3.06% | 62.0% | 32% | 0 |
| T4 · A+C+D (source tier earns) | 56 | 3.0% | 0.3% | 94% | 96% | 42% | 4.45% | 4.17% | 57.5% | 35% | 0 |
| T4 · A+B+C+D | 56 | 3.0% | 0.3% | 94% | 96% | 52% | 4.90% | 5.24% | 35.2% | 36% | 0 |
| T4 · E (crossing-only fee) | 55 | 0.0% | 1.7% | 92% | 93% | 13% | 2.48% | 3.02% | 42.6% | 34% | 0 |
| T4 · A+B+C+E | 55 | 0.0% | 3.5% | 87% | 91% | 9% | 2.39% | 2.88% | 38.4% | 33% | 0 |
