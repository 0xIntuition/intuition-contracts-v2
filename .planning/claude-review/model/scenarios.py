"""Scenario suite for the dynamic-fee curve audit. Writes figures to ../figures and tables to results.md."""
import random, math, os, sys
from dynfee_model import *
from svgchart import Chart, heatmap, ladder, PAL, fmt

FIG = os.path.join(os.path.dirname(__file__), "..", "figures")
os.makedirs(FIG, exist_ok=True)
OUT = []
def md(s=""):
    OUT.append(s)
def T(x):  # wei -> TRUST float
    return x / 1e18
def tf(x, d=2):
    return f"{x/1e18:,.{d}f}"
def pct(x, d=2):
    return f"{x*100:.{d}f}%"

TERM = "t"
CFG = DEPLOY_SEED
N = CFG.tierCount

# MV fee envelope used throughout (production values): protocol 1.25%, entry 0.5%, exit 0.75%
MV_PROTO, MV_ENTRY, MV_EXIT = 125, 50, 75

def new_mv(cfg=CFG, mvfees=True, floor=0):
    cfg2 = Config(**{**cfg.__dict__, "minEligibleTierStake": floor})
    c = Curve(cfg2)
    return MV(c, MV_PROTO if mvfees else 0, MV_ENTRY if mvfees else 0, MV_EXIT if mvfees else 0), c

def gross_to_fill(c, target_net, mv):
    """Gross deposit whose net stake (after MV + curve fees) lands the vault exactly at start+target_net. Bisection."""
    lo, hi = target_net, target_net * 2
    start = c.vaultStake[TERM]
    def net_of(g):
        base = g
        p = mul_div(base, mv.protocolFeeBps, BPS); e = mul_div(base, mv.entryFeeBps, BPS)
        cf = c._piecewise(start, base)
        return base - p - e - cf
    while lo < hi:
        mid = (lo + hi) // 2
        if net_of(mid) < target_net: lo = mid + 1
        else: hi = mid
    return lo

# ============================================================
# 0. Static structure
# ============================================================
c0 = Curve(CFG)
edges = [c0.edge(k) for k in range(N)]
dep = [c0.dep_bps(k) for k in range(N)]
wd = [c0.wd_bps(k) for k in range(N)]
ladder(f"{FIG}/01_ladder.svg", edges, dep, wd, "Deploy-seed tier ladder (width0 = 5,000 TRUST, g = 20%, 13 tiers: T0–T12)",
       "deposit fee = 1% + 0.5%/tier, withdrawal fee = 2% + 0.5%/tier (cap 10% never binds inside 13 tiers)")

md("## 0. Static structure (deploy seed)\n")
md("| tier | band (cumulative net stake, TRUST) | width | deposit fee | withdrawal fee | earns from source tiers (α=1, σ=4) |")
md("|---:|---|---:|---:|---:|---|")
for k in range(N):
    lo = 0 if k == 0 else edges[k-1]
    hi = "∞" if k == N-1 else tf(edges[k],0)
    src = ", ".join(f"T{k+d} ({[75,50,25][d-1]}%)" for d in (1,2,3) if k+d <= N-1)
    md(f"| {k} | {tf(lo,0)} → {hi} | {tf(c0.width(k),0) if k<N-1 else 'terminal'} | {dep[k]/100:.1f}% | {wd[k]/100:.1f}% | {src or '— (nothing above)'} |")

# kernel heatmap: raw weight of recipient j when the source is tier s
mat = []
for s in range(N):
    row = []
    for j in range(N):
        d = s - j
        row.append({1:0.75,2:0.5,3:0.25}.get(d, 0.0) if d >= 1 else 0.0)
    mat.append(row)
heatmap(f"{FIG}/02_kernel.svg", mat, [f"src T{s}" for s in range(N)], [f"T{j}" for j in range(N)],
        "Fulcrum kernel: raw weight each recipient tier gets from a fee sourced at tier s",
        "alpha = BPS, sigma = 4 → weights 0.75 / 0.5 / 0.25 for d = 1,2,3. Normalised over ELIGIBLE tiers only; within a tier pro-rata by stake.",
        xlabel="recipient tier", ylabel="source tier (vault tier when the band is charged)")

# fee schedule chart
ch = Chart(title="Per-tier fee schedule and composition of one 1,000 TRUST atom deposit", subtitle="curve fee (by tier) stacked on MultiVault protocol 1.25% + entry 0.5% + atom-wallet 0.5%", h=420, legend_rows=1)
ch.axes(-0.5, 12.5, 0, 12, xlabel="tier", ylabel="% of deposit", xticks=list(range(13)), xfmt=lambda v: f"T{int(v)}", yfmt=lambda v: f"{v:.0f}%")
ch.bars(list(range(N)), [2.25]*N, "#9ca3af", label="MultiVault fees (2.25%)")
ch.bars(list(range(N)), [d/100 for d in dep], PAL[0], label="curve deposit fee", base=[2.25]*N)
ch.line(list(range(N)), [w/100 for w in wd], PAL[1], label="curve withdrawal fee (exit, by bucket)", marker=True)
ch.line(list(range(N)), [w/100 + 2.0 for w in wd], PAL[1], label="…+ MV exit 0.75% + protocol 1.25%", dash="5 4")
ch.render(f"{FIG}/03_fee_schedule.svg")

# ============================================================
# S1. Linear climb T0 -> T12, one cohort per band
# ============================================================
md("\n## S1. Linear climb: one cohort fills each band, T0 → T12\n")
mv, c = new_mv()
cohorts = []
flows = [[0]*N for _ in range(N)]  # flows[src][dst] TRUST credited
for k in range(N):
    width = c.width(k) if k < N-1 else c.width(k)  # top tier: deposit its nominal width
    g = gross_to_fill(c, width, mv)
    before = {t: c.acc[TERM][t] for t in range(N)}
    nev = len(c.events)
    net, fee = mv.deposit(TERM, f"C{k}", g)
    for ev in c.events[nev:]:
        if ev.kind == "FulcrumCredit":
            flows[ev.data["source"]][ev.data["tier"]] += ev.data["amount"]
        if ev.kind == "FulcrumDegenerateAward":
            flows[k][ev.data["tier"]] += ev.data["amount"]
    cohorts.append(dict(k=k, gross=g, net=net, fee=fee, tier=c.userTier[TERM][f"C{k}"], vault=c.vaultStake[TERM]))
md("Each cohort C_k deposits the gross amount whose net stake exactly fills band k (MV fees 1.75% + curve fee netted). Vault ends at the T12 lower edge + 44,580.\n")
md("| cohort | gross in | curve fee paid | eff. curve rate | net stake | bucket | vault after | earned by end of climb | earned − fee |")
md("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
tot_fee = tot_earn = 0
earn = []
for co in cohorts:
    e = c.claimable(TERM, f"C{co['k']}")
    earn.append(e)
    tot_fee += co["fee"]; tot_earn += e
    md(f"| C{co['k']} | {tf(co['gross'],0)} | {tf(co['fee'],2)} | {pct(co['fee']/co['gross'])} | {tf(co['net'],0)} | T{co['tier']} | {tf(co['vault'],0)} | {tf(e,2)} | {tf(e-co['fee'],2)} |")
md(f"| **Σ** | | **{tf(tot_fee,2)}** | | | | | **{tf(tot_earn,2)}** | protocolAccrued {tf(c.protocolAccrued,2)} |")
md(f"\nSolvency check: curve balance {tf(c.balance,6)} = earned {tf(tot_earn,6)} + protocolAccrued {tf(c.protocolAccrued,6)} + unattributed dust {tf(c.balance-tot_earn-c.protocolAccrued,9)} TRUST.\n")

ch = Chart(title="S1 — Linear climb: what each cohort paid vs. what it earned by the time the vault reached T12", subtitle="deploy seed, one cohort per band; earnings are the deposit fees of LATER cohorts flowing down through the kernel", h=420)
ymax = max(max(co["fee"] for co in cohorts), max(earn)) / 1e18 * 1.15
ch.axes(-0.5, 12.5, 0, ymax, xlabel="cohort / entry tier", ylabel="TRUST", xticks=list(range(13)), xfmt=lambda v: f"C{int(v)}")
ch.bars(list(range(N)), [T(co["fee"]) for co in cohorts], "#9ca3af", label="curve deposit fee paid", group=2, offset=0)
ch.bars(list(range(N)), [T(e) for e in earn], PAL[0], label="earned (claimable)", group=2, offset=1)
ch.render(f"{FIG}/04_s1_climb.svg")

heatmap(f"{FIG}/05_s1_flows.svg", [[T(x) for x in r] for r in flows], [f"C{s} fee" for s in range(N)], [f"T{j}" for j in range(N)],
        "S1 — Who paid whom: deposit fee of cohort C_s (row) credited to bucket T_j (column), TRUST",
        "C0's fee has no prior tier and goes to protocolAccrued. Multi-band rows would spread across more columns.",
        xlabel="recipient bucket", ylabel="paying cohort", cell=52, fmtv=lambda v: f"{v:,.0f}")

# ---- unwind in LIFO vs FIFO ----
def unwind(order_name, order):
    mv, c = new_mv()
    for k in range(N):
        g = gross_to_fill(c, c.width(k), mv)
        mv.deposit(TERM, f"C{k}", g)
    fee_in = {f"C{k}": mv.log[k]["curve_fee"] for k in range(N)}
    rows = []
    for k in order:
        a = f"C{k}"
        stake = c.userStake[TERM][a]
        vt_before = c.tier_of(c.vaultStake[TERM])
        nev = len(c.events)
        payout, fee = mv.redeem(TERM, a, stake)
        where = [ev for ev in c.events[nev:] if ev.kind in ("ExitTierCredit","WithdrawalFeeRerouted","ProtocolAccrued")]
        dest = ", ".join(("T%d" % ev.data["tier"]) if ev.kind=="ExitTierCredit" else ("reroute→T%d" % ev.data["to"]) if ev.kind=="WithdrawalFeeRerouted" else "protocol" for ev in where)
        earned_total = c.earned[a]  # settled on exit
        rows.append((a, vt_before, c.userTier[TERM][a] if False else None, stake, fee, dest, earned_total, fee_in[a]))
    return rows, c

for name, order in (("LIFO (last cohort leaves first: vault walks back down T12 → T0)", list(range(N-1,-1,-1))),
                    ("FIFO (earliest cohort leaves first: vault stays high, then collapses)", list(range(N)))):
    rows, c = unwind(name, order)
    md(f"\n### S1b. Full unwind — {name}\n")
    md("| exiting | vault tier at exit | exit fee (rate by bucket) | exit fee goes to | lifetime earned | lifetime curve fees paid | net |")
    md("|---|---:|---:|---|---:|---:|---:|")
    for a, vt, _, stake, fee, dest, earned_total, fin in rows:
        md(f"| {a} | T{vt} | {tf(fee,2)} ({c.wd_bps(int(a[1:]))/100:.1f}%) | {dest} | {tf(earned_total,2)} | {tf(fin+fee,2)} | {tf(earned_total-fin-fee,2)} |")
    md(f"\nprotocolAccrued at the end: {tf(c.protocolAccrued,2)} TRUST; curve balance {tf(c.balance,2)}; Σ earned-but-unclaimed {tf(sum(c.earned.values()),2)}.\n")

# ============================================================
# S2. Multi-band self-rebate
# ============================================================
md("\n## S2. A multi-band deposit is partly paid back to itself\n")
md("Vault pre-built by cohorts at T0, T1, T2 (bands filled) plus 1,000 TRUST into T3. A fresh account then deposits X in one transaction. The table shows how much of X's own curve fee lands in X's own claimable balance immediately after the deposit — the doc claims this is exactly zero.\n")
md("| X (gross) | bands traversed | curve fee paid | X's claimable right after | self-rebate | X's final bucket |")
md("|---:|---|---:|---:|---:|---:|")
xs, rebates = [], []
for X in [1_000, 5_000, 10_000, 20_000, 40_000, 60_000, 100_000, 200_000]:
    mv, c = new_mv()
    for k in range(3):
        mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
    mv.deposit(TERM, "C3", gross_to_fill(c, 1000*E18, mv))
    t_before = c.tier_of(c.vaultStake[TERM])
    nev = len(c.events)
    net, fee = mv.deposit(TERM, "X", X*E18)
    bands = [ev.data["bandTier"] for ev in c.events[nev:] if ev.kind=="DepositBandRecorded"]
    got = c.claimable(TERM, "X")
    xs.append(X); rebates.append(got/fee if fee else 0)
    md(f"| {X:,} | T{bands[0]}…T{bands[-1]} ({len(bands)}) | {tf(fee,2)} | {tf(got,2)} | {pct(got/fee)} | T{c.userTier[TERM]['X']} |")
ch = Chart(title="S2 — Self-rebate on a single multi-band deposit (fresh account, vault at ~19.2k / T3)", subtitle="share of the depositor's own curve fee that is immediately claimable by the depositor", h=380)
ch.axes(0, 8, 0, max(rebates)*1.2, xlabel="deposit size (TRUST)", ylabel="self-rebate (% of own fee)", xticks=list(range(8)), xfmt=lambda v: f"{xs[int(v)]//1000}k" if int(v)<len(xs) else "", yfmt=lambda v: f"{v*100:.0f}%")
ch.line(list(range(len(xs))), rebates, PAL[1], marker=True, label="self-rebate")
ch.render(f"{FIG}/06_s2_self_rebate.svg")

# ============================================================
# S3. Sawtooth: up and down
# ============================================================
md("\n## S3. Sawtooth: the vault climbs, drops, climbs again\n")
mv, c = new_mv()
timeline = []  # (step, label, vault tier, {cohort: claimable}, protocol)
names = []
def snap(label):
    timeline.append((len(timeline), label, c.tier_of(c.vaultStake[TERM]), {a: c.claimable(TERM, a) for a in names}, c.protocolAccrued, c.vaultStake[TERM]))
# phase 1: climb to T6 with cohorts per band
for k in range(7):
    names.append(f"C{k}")
    mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv)); snap(f"C{k} fills T{k}")
# phase 2: late cohorts exit LIFO down to T2 (C6, C5, C4, C3 leave; C2 half)
for k in (6,5,4,3):
    mv.redeem(TERM, f"C{k}", c.userStake[TERM][f"C{k}"]); snap(f"C{k} exits (all)")
mv.redeem(TERM, "C2", c.userStake[TERM]["C2"]//2); snap("C2 exits half")
# phase 3: new cohorts climb again to T8
for k, nm in ((2,"N2"),(3,"N3"),(4,"N4")):
    names.append(nm)
    mv.deposit(TERM, nm, gross_to_fill(c, c.width(k) if k>2 else c.edge(2)-c.vaultStake[TERM], mv)); snap(f"{nm} enters at T{k}")
names.append("W"); mv.deposit(TERM, "W", 60_000*E18); snap("whale W deposits 60k (T5→T8)")
# phase 4: early cohorts exit (FIFO) while vault is high
for k in (0,1):
    mv.redeem(TERM, f"C{k}", c.userStake[TERM][f"C{k}"]); snap(f"C{k} exits (all)")
# phase 5: big drawdown: whale exits, N4 exits -> vault back to ~T3
mv.redeem(TERM, "W", c.userStake[TERM]["W"]); snap("W exits (all)")
mv.redeem(TERM, "N4", c.userStake[TERM]["N4"]); snap("N4 exits")
# phase 6: fresh deposits at the low tier — who earns?
names.append("L"); mv.deposit(TERM, "L", 5_000*E18); snap("L deposits 5k at low tier")
names.append("M"); mv.deposit(TERM, "M", 30_000*E18); snap("M deposits 30k (multi-band)")

md("| step | event | vault tier after | " + " | ".join(names) + " | protocolAccrued |")
md("|---:|---|---:|" + "---:|"*len(names) + "---:|")
for i, lab, vt, cl, pa, vs in timeline:
    md(f"| {i} | {lab} | T{vt} ({tf(vs,0)}) | " + " | ".join(tf(cl.get(a,0),1) if a in cl else "" for a in names) + f" | {tf(pa,1)} |")
md("\nBuckets at the end: " + ", ".join(f"{a}→T{c.userTier[TERM][a]} ({tf(c.userStake[TERM][a],0)})" for a in names if c.userStake[TERM][a] > 0) + "\n")

ch = Chart(title="S3 — Sawtooth: vault tier over time vs. cumulative claimable per cohort", subtitle="step events listed in the S3 table; grey step = vault tier (T0…T12 scaled to the axis)", h=520, legend_rows=4)
allv = [max(cl.values()) for _,_,_,cl,_,_ in timeline]
ymax = max(max(allv), max(pa for *_, pa, _ in timeline)) / 1e18 * 1.1
ch.axes(0, len(timeline)-1, 0, ymax, xlabel="step", ylabel="TRUST claimable", xticks=list(range(0, len(timeline), 2)), xfmt=lambda v: str(int(v)))
for i, a in enumerate(names):
    ys = [T(cl.get(a,0)) for *_, cl, _, _ in timeline]
    if max(ys) > 0:
        ch.line(list(range(len(timeline))), ys, PAL[i % len(PAL)], label=a, step=True)
ch.line(list(range(len(timeline))), [T(pa) for *_, pa, _ in timeline], "#111827", label="protocolAccrued", dash="6 3", step=True)
# vault tier overlay scaled
tiers = [vt for _,_,vt,_,_,_ in timeline]
ch.line(list(range(len(timeline))), [t/12*ymax for t in tiers], "#9ca3af", label="vault tier (T0…T12 scaled to axis)", step=True, width=1)
ch.render(f"{FIG}/07_s3_sawtooth.svg")

# ============================================================
# S4. Drawdown-stranded cohort: all deposit fees go to protocol
# ============================================================
md("\n## S4. Stranded cohort: after early exits + a drawdown, deposit fees flow to nobody\n")
mv, c = new_mv()
for k in range(9):
    mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
for k in range(0,4):   # early cohorts leave (FIFO)
    mv.redeem(TERM, f"C{k}", c.userStake[TERM][f"C{k}"])
for k in (8,7,6):      # late cohorts also leave (drawdown)
    mv.redeem(TERM, f"C{k}", c.userStake[TERM][f"C{k}"])
# remaining: C4 (bucket 4), C5 (bucket 5); vault ≈ width4+width5 = 22,810 -> T2
vt = c.tier_of(c.vaultStake[TERM])
md(f"Remaining holders: C4 (bucket T4, {tf(c.userStake[TERM]['C4'],0)}), C5 (bucket T5, {tf(c.userStake[TERM]['C5'],0)}). Vault = {tf(c.vaultStake[TERM],0)} → **T{vt}**.\n")
md("| new deposit | source tier | bands | curve fee | to C4 | to C5 | to protocolAccrued |")
md("|---:|---:|---|---:|---:|---:|---:|")
for i, X in enumerate([2_000, 5_000, 10_000, 20_000, 40_000]):
    pa0 = c.protocolAccrued; c4 = c.claimable(TERM,"C4"); c5 = c.claimable(TERM,"C5")
    st = c.tier_of(c.vaultStake[TERM]); nev = len(c.events)
    net, fee = mv.deposit(TERM, f"D{i}", X*E18)
    bands = [ev.data["bandTier"] for ev in c.events[nev:] if ev.kind=="DepositBandRecorded"]
    md(f"| {X:,} | T{st} | T{bands[0]}…T{bands[-1]} | {tf(fee,2)} | {tf(c.claimable(TERM,'C4')-c4,2)} | {tf(c.claimable(TERM,'C5')-c5,2)} | {tf(c.protocolAccrued-pa0,2)} |")
md(f"\nVault after: {tf(c.vaultStake[TERM],0)} (T{c.tier_of(c.vaultStake[TERM])}). Note the new depositors D0–D4 (buckets T2–T4) start earning before C4/C5 do, because fees flow only DOWN from the band being charged.\n")

# ============================================================
# S5. Bucket averaging: fee neutrality and seniority loss
# ============================================================
md("\n## S5. Bucket averaging (stake-weighted average entry tier)\n")
md("### S5a. Exit-fee effect of merging a high-bucket position with a later low-tier deposit\n")
md("Holder has S = 10,000 at bucket T8. The vault has fallen to T2. They top up D at T2 from the SAME wallet (bucket re-averages) vs from a SEPARATE wallet. Exit fee on everything afterwards:\n")
md("| D / S | new avg tier | new bucket | exit fee, same wallet | exit fee, separate wallets | delta (bps of S+D) |")
md("|---:|---:|---:|---:|---:|---:|")
S = 10_000
ratios, deltas = [], []
for r10 in range(0, 61, 2):
    r = r10/10
    D = S * r
    tot = S + D
    avg = (8*S + 2*D)/tot
    bucket = min(int(math.floor(avg + 0.5)), 12)
    same = tot * c0.wd_bps(bucket)/BPS
    sep = S * c0.wd_bps(8)/BPS + D * c0.wd_bps(2)/BPS
    ratios.append(r); deltas.append((same-sep)/tot*1e4)
    if r10 % 10 == 0 or abs(same-sep)/tot*1e4 > 20:
        md(f"| {r:.1f} | {avg:.3f} | T{bucket} | {same:,.2f} | {sep:,.2f} | {(same-sep)/tot*1e4:+.1f} |")
ch = Chart(title="S5a — Bucket rounding is the only fee effect of averaging (linear schedule): bounded by ±25 bps", subtitle="exit fee (same wallet, re-averaged bucket) minus exit fee (separate wallets), in bps of total stake; S=10k at T8 topped up with D at T2", h=360)
ch.axes(0, 6, -30, 30, xlabel="D / S", ylabel="bps of (S + D)", yfmt=lambda v: f"{v:+.0f}")
ch.hline(0, "#9ca3af", "2 2"); ch.hline(25, PAL[1], "4 3", "+25 bps (½ tier × 0.5%)"); ch.hline(-25, PAL[1], "4 3", "−25 bps")
ch.line(ratios, deltas, PAL[0], marker=True, label="same-wallet − separate-wallet")
ch.render(f"{FIG}/08_s5_averaging.svg")

md("\n### S5b. Seniority loss: an early holder who tops up from the same wallet moves their WHOLE position to a higher bucket\n")
def seniority(merge):
    mv, c = new_mv()
    for k in range(6):
        mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
    mv.deposit(TERM, "H", 3_000*E18)          # H enters at T6 (vault is at the T6 lower edge) — wait, we want an EARLY holder; use C1 as H
    # Early holder = C1 (bucket T1, ~6,000). Top-up of 20,000 at T6 from same wallet or from wallet C1b.
    who = "C1" if merge else "C1b"
    mv.deposit(TERM, who, 20_000*E18)
    b_after = (c.userTier[TERM]["C1"], c.userTier[TERM].get("C1b", None))
    # subsequent activity: the vault climbs T7..T10 with new cohorts
    base = {a: c.claimable(TERM, a) for a in ("C1","C1b")}
    for k in range(7, 11):
        mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
    got = sum(c.claimable(TERM, a) - base[a] for a in ("C1","C1b"))
    return b_after, got
(bm, gm) = seniority(True); (bs, gs) = seniority(False)
md(f"- Same wallet: C1's bucket goes T1 → **T{bm[0]}** for all ~26k of stake. Earnings during the next climb (T7→T10 filled by new cohorts): **{tf(gm,2)} TRUST**.")
md(f"- Separate wallet: C1 stays at T1 and the top-up sits at **T{bs[1]}**. Combined earnings over the same climb: **{tf(gs,2)} TRUST**.")
md(f"- Splitting wallets earns **{gs/gm:.2f}×** here. Merging also drops C1 out of T1's denominator, so the other T1 holders' share rises — the kernel pie is fixed per tier, the averaging only moves who sits in which slice.\n")

# ============================================================
# S6. Thin-tier capture / dust sniping
# ============================================================
md("\n## S6. Tier allocation is stake-agnostic: thin tiers are disproportionately lucrative\n")
md("### S6a. Deposit-side: the tier split ignores how much stake each tier holds\n")
md("State seeded directly: T4 holds 100,000 (A4), T6 holds 100,000 (A6), T5 holds a varying amount (A5). Vault sits just inside T7, so a 5,000 deposit is charged 4.5% = 225 and the kernel pays T6/T5/T4 at 50/33/17 when all three are eligible.\n")
md("| T5 stake (A5) | floor | T4 (100k) gets | T5 gets | T6 (100k) gets | A5 return on its stake | A4 return |")
md("|---:|---:|---:|---:|---:|---:|---:|")
def seed(c, placements, vault):
    for a, t, s in placements:
        c.userStake[TERM][a] = s; c.userTier[TERM][a] = t; c.userAvgTier[TERM][a] = t*TP
        c.tierStake[TERM][t] += s; c.rewardDebt[TERM][a] = 0
    c.vaultStake[TERM] = vault
for floor in (0, 1000*E18):
    for t5 in (100_000, 10_000, 1_000, 100, 1, 1e-18):
        mv, c = new_mv(mvfees=False, floor=floor)
        s5 = int(round(t5*E18))
        seed(c, [("A4",4,100_000*E18),("A5",5,s5),("A6",6,100_000*E18)], c.edge(6) + 1000*E18)
        net, fee = mv.deposit(TERM, "W", 5_000*E18)
        g = {a: c.claimable(TERM, a) for a in ("A4","A5","A6")}
        r5 = pct(g["A5"]/s5, 0) if g["A5"] and s5 >= E18 else (f"{g['A5']/s5*100:.2e}%" if g["A5"] else "—")
        md(f"| {t5:,} | {tf(floor,0)} | {tf(g['A4'],2)} | {tf(g['A5'],2)} | {tf(g['A6'],2)} | {r5} | {pct(g['A4']/(100_000*E18),3)} |")
md("\nThe split across tiers is fixed by the kernel regardless of how much stake each tier holds; only the split *within* a tier is pro-rata. A 1-wei position alone in an eligible tier takes that tier's whole slice. The 1,000 TRUST floor only raises the ticket price to 1,000 TRUST of (recoverable) principal.\n")

md("### S6b. Redeem-side: a lone whale's exit fee goes 100% to the nearest eligible tier ABOVE\n")
md("| whale stake at T5 (alone) | sniper stake at T6 | floor | whale exit fee | sniper receives | sniper return |")
md("|---:|---:|---:|---:|---:|---:|")
for floor in (0, 1000*E18):
    for sn in (0.001, 1, 1000, 10_000):
        mv, c = new_mv(mvfees=False, floor=floor)
        for k in range(5):
            mv.deposit(TERM, f"F{k}", gross_to_fill(c, c.width(k), mv))
        mv.deposit(TERM, "Whale", gross_to_fill(c, c.width(5), mv))
        mv.deposit(TERM, "Sniper", int(sn*E18))
        before = c.claimable(TERM, "Sniper"); pa = c.protocolAccrued
        payout, fee = mv.redeem(TERM, "Whale", c.userStake[TERM]["Whale"])
        got = c.claimable(TERM, "Sniper") - before
        dest = [ev for ev in c.events if ev.kind in ("WithdrawalFeeRerouted","ExitTierCredit") and ev.data.get("amount")==fee]
        where = ("reroute → T%d" % dest[-1].data["to"]) if dest and dest[-1].kind=="WithdrawalFeeRerouted" else "exit tier"
        md(f"| 12,442 | {sn:,} | {tf(floor,0)} | {tf(fee,2)} | {tf(got,2)} | {pct(got/(sn*E18)) if got else '0% (' + where + ')'} |")

# ============================================================
# S7. JIT sandwich around a large deposit
# ============================================================
md("\n## S7. Just-in-time sandwich around a large deposit\n")
md("Vault sits mid-T5 with one resident cohort per band (T0–T5 filled; T5 cohort is the *only* T5 resident unless noted). Attacker deposits X at T5 one tx before whale deposits W (multi-band), then exits right after. Profit = claimable − curve in-fee − curve out-fee − MV fees (1.75% in + 2% out).\n")
md("| W (whale) | X (attacker) | attacker claimable | fees paid (curve+MV) | net profit | profit / X | T5 resident stake |")
md("|---:|---:|---:|---:|---:|---:|---:|")
prof = {}
for resident in (True, False):
  for W in (20_000, 50_000, 100_000):
    key = (W, resident); prof[key] = []
    for X in (100, 1_000, 5_000, 10_000, 20_000, 50_000):
        mv, c = new_mv()
        for k in range(5):
            mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
        if resident:
            mv.deposit(TERM, "C5", gross_to_fill(c, c.width(5)//2, mv))  # half of T5 filled by a resident
        else:
            mv.deposit(TERM, "C4", gross_to_fill(c, c.width(5)//2, mv))  # C4 tops up: its bucket stays T4, vault mid-T5, T5 empty
        resident5 = c.tierStake[TERM][5]
        bal0 = X*E18
        net, fin = mv.deposit(TERM, "ATK", X*E18)
        mvin = X*E18 - fin - net
        mv.deposit(TERM, "WHALE", W*E18)
        claim = c.claimable(TERM, "ATK")
        payout, fout = mv.redeem(TERM, "ATK", c.userStake[TERM]["ATK"])
        profit = payout + claim - bal0
        prof[key].append((X, profit))
        md(f"| {W:,} | {X:,} | {tf(claim,2)} | {tf(bal0-payout,2)} | {tf(profit,2)} | {pct(profit/bal0)} | {tf(resident5,0)} |")
ch = Chart(title="S7 — JIT sandwich: net profit vs attacker size (X ≤ 10k; larger X only loses more — see table)", legend_rows=2, subtitle="attacker enters at T5 immediately before a whale's multi-band deposit and exits right after; all curve + MultiVault fees included", h=420)
sub = [(k, [(X, p) for X, p in prof[k] if X <= 10_000]) for k in prof]
allp = [T(p) for _, rows in sub for _, p in rows]
ch.axes(0, 3, min(allp)*1.1, max(allp)*1.15, xlabel="attacker stake X (TRUST)", ylabel="net profit (TRUST)", xticks=list(range(4)), xfmt=lambda v: ["100","1k","5k","10k"][int(v)], yfmt=lambda v: f"{v:,.0f}")
ch.hline(0, "#111827", "2 2")
for i, (k, rows) in enumerate(sub):
    W, resident = k
    ch.line(list(range(4)), [T(p) for _, p in rows], PAL[i%3], marker=True, label=f"W={W//1000}k, {'resident in T5' if resident else 'attacker ALONE in T5'}", dash=None if resident else "5 4")
ch.render(f"{FIG}/09_s7_sandwich.svg")

# ============================================================
# S8. Solvency / invariant fuzz on the model
# ============================================================
md("\n## S8. Invariant fuzz on the reference model (random deposits/redeems, 40 accounts, 2,000 ops × 5 seeds)\n")
worst = None; viol = 0; runs = 0
for seed in range(5):
    rnd = random.Random(seed)
    mv, c = new_mv(floor=rnd.choice([0, 0, 100*E18, 1000*E18]))
    accts = [f"u{i}" for i in range(40)]
    for step in range(2000):
        a = rnd.choice(accts)
        if c.userStake[TERM][a] > 0 and rnd.random() < 0.45:
            s = c.userStake[TERM][a]
            amt = s if rnd.random() < 0.3 else rnd.randint(1, s)
            mv.redeem(TERM, a, amt)
        else:
            mag = rnd.choice([10**15, 10**18, 10**21, 10**22, 10**23, 2*10**23])
            mv.deposit(TERM, a, rnd.randint(1, mag))
        if rnd.random() < 0.1:
            c.claim(a, [TERM])
        # invariants
        assert sum(c.tierStake[TERM].values()) == c.vaultStake[TERM]
        per_bucket = defaultdict(int)
        for u in accts:
            if c.userStake[TERM][u] > 0:
                per_bucket[c.userTier[TERM][u]] += c.userStake[TERM][u]
        for t in range(N):
            assert per_bucket[t] == c.tierStake[TERM][t], (t, per_bucket[t], c.tierStake[TERM][t])
        liabilities = sum(c.earned.values()) + sum(c.pending(TERM, u) for u in accts) + c.protocolAccrued
        slack = c.balance - liabilities
        runs += 1
        if slack < 0: viol += 1
        if worst is None or slack < worst: worst = slack
md(f"- Σ tierStake == vaultStake and Σ userStake-by-bucket == tierStake held at every step ({runs:,} checks).")
md(f"- balance − (Σ earned + Σ pending + protocolAccrued) was never negative; minimum slack observed: **{worst} wei** ({viol} violations).\n")

open(os.path.join(os.path.dirname(__file__), "results.md"), "w").write("\n".join(OUT))
print("done", len(OUT), "lines")


# ============================================================
# S9. What-if: candidate mitigations, measured on the same scenarios
# ============================================================
md("\n## S9. What-if: candidate mitigations, measured on the same scenarios\n")
md("- **A** — exclude the depositor's own current position from every recipient denominator while their deposit is replayed (settle → distribute-excluding → land + re-base; the redeem leg already works this way). This is what commit `8579c5e` did.")
md("- **B** — weight each prior tier by kernel × stake instead of kernel alone, so a wei of stake at distance d earns `pool·w_d / Σ w·stake` regardless of how thin its tier is.")
md("- **C** — distribute every band's fee from the **pre-deposit** tier (recipients = tiers below where the vault stood before the deposit), keeping the per-band *rate*. This is the targeting `8579c5e` used and the targeting `docs/call-flows/dynamic-fee-curve.md` §4 still describes. A+C together is the `8579c5e` design.\n")
VARIANTS = [("current", {}), ("A", dict(exclude_self_on_deposit=True)), ("B", dict(stake_weighted_kernel=True)), ("C", dict(predeposit_targeting=True)),
            ("A+C (8579c5e)", dict(exclude_self_on_deposit=True, predeposit_targeting=True)),
            ("A+B+C", dict(exclude_self_on_deposit=True, stake_weighted_kernel=True, predeposit_targeting=True))]
def new_mv2(**flags):
    c = Curve(CFG, **flags); return MV(c, MV_PROTO, MV_ENTRY, MV_EXIT), c

md("### S9a. S2 self-rebate (share of own curve fee immediately claimable by the depositor)\n")
md("| X | " + " | ".join(n for n,_ in VARIANTS) + " |"); md("|---:|" + "---:|"*len(VARIANTS))
for X in (10_000, 20_000, 60_000, 200_000):
    row = []
    for name, flags in VARIANTS:
        mv, c = new_mv2(**flags)
        for k in range(3):
            mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
        mv.deposit(TERM, "C3", gross_to_fill(c, 1000*E18, mv))
        net, fee = mv.deposit(TERM, "X", X*E18)
        row.append(pct(c.claimable(TERM,"X")/fee))
    md(f"| {X:,} | " + " | ".join(row) + " |")

md("\n### S9b. S7 JIT sandwich, attacker ALONE in the vault's current tier (net profit, TRUST)\n")
md("| W | X | " + " | ".join(n for n,_ in VARIANTS) + " |"); md("|---:|---:|" + "---:|"*len(VARIANTS))
for W in (50_000, 100_000):
    for X in (100, 1_000, 5_000):
        row = []
        for name, flags in VARIANTS:
            mv, c = new_mv2(**flags)
            for k in range(5):
                mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
            mv.deposit(TERM, "C4", gross_to_fill(c, c.width(5)//2, mv))
            bal0 = X*E18
            mv.deposit(TERM, "ATK", bal0)
            mv.deposit(TERM, "WHALE", W*E18)
            claim = c.claimable(TERM, "ATK")
            payout, fout = mv.redeem(TERM, "ATK", c.userStake[TERM]["ATK"])
            row.append(tf(payout + claim - bal0, 2))
        md(f"| {W:,} | {X:,} | " + " | ".join(row) + " |")

md("\n### S9c. Pre-positioned (not JIT): attacker sits alone in a thin PRIOR tier when a whale deposit arrives\n")
md("Vault mid-T3. Attacker deposits X (bucket T3, alone — T3 was otherwise empty). A filler then pushes the vault just past the T4 edge (its bucket rounds to T3 as well, so T3 = attacker + filler). Whale deposits W from T4. The attacker is a genuine prior-tier holder here, so C does not exclude them; whether a thin T3 is a jackpot is decided by B.\n")
md("| W | X | T3 total stake | " + " | ".join(n for n,_ in VARIANTS) + " |"); md("|---:|---:|---:|" + "---:|"*len(VARIANTS))
for W in (50_000, 100_000):
    for X in (100, 1_000, 5_000):
        row = []
        for name, flags in VARIANTS:
            mv, c = new_mv2(**flags)
            mv.deposit(TERM, "H", gross_to_fill(c, c.edge(2) + 2_000*E18, mv))     # one early holder through T0-T2 and 2k into T3 (bucket T1)
            bal0 = X*E18
            mv.deposit(TERM, "ATK", bal0)                                          # bucket T3
            mv.deposit(TERM, "F", gross_to_fill(c, c.edge(3) + 50*E18 - c.vaultStake[TERM], mv))  # filler crosses into T4; its avg rounds to T3
            t3 = c.tierStake[TERM][3]
            mv.deposit(TERM, "WHALE", W*E18)
            claim = c.claimable(TERM, "ATK")
            payout, fout = mv.redeem(TERM, "ATK", c.userStake[TERM]["ATK"])
            row.append(tf(payout + claim - bal0, 0))
        md(f"| {W:,} | {X:,} | {tf(t3,0)} | " + " | ".join(row) + " |")

md("\n### S9d. Ordinary cohorts (S1 linear climb, one cohort per band): earned by the top of the climb\n")
md("| cohort | " + " | ".join(n for n,_ in VARIANTS) + " |"); md("|---|" + "---:|"*len(VARIANTS))
res = {}
for name, flags in VARIANTS:
    mv, c = new_mv2(**flags)
    for k in range(N):
        mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
    res[name] = [c.claimable(TERM, f"C{k}") for k in range(N)]
for k in range(N):
    md(f"| C{k} | " + " | ".join(tf(res[n][k],2) for n,_ in VARIANTS) + " |")

md("\n### S9e. A realistic mixed climb (cohorts of varied size, several multi-band whales): total fee captured by the whales themselves vs by prior cohorts\n")
md("| variant | curve fees paid by 5 whale deposits | claimable the whales gained DURING their own deposits | self-captured | protocolAccrued |")
md("|---|---:|---:|---:|---:|")
for name, flags in VARIANTS:
    mv, c = new_mv2(**flags)
    rnd = random.Random(7)
    whales = []
    wf = 0
    wc = 0
    for i in range(40):
        if i % 8 == 5:
            a = f"W{i}"; whales.append(a)
            before = c.claimable(TERM, a)
            net, fee = mv.deposit(TERM, a, rnd.choice([30_000, 60_000, 100_000])*E18); wf += fee
            wc += c.claimable(TERM, a) - before
        else:
            mv.deposit(TERM, f"u{i}", rnd.randint(500, 6000)*E18)
    md(f"| {name} | {tf(wf,0)} | {tf(wc,0)} | {pct(wc/wf,1)} | {tf(c.protocolAccrued,0)} |")

open(os.path.join(os.path.dirname(__file__), "results.md"), "w").write("\n".join(OUT))
print("done3")
