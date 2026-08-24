"""Population simulation: an atom full of $20-$100 users that stalls at T3 or T4. Who pays, who earns, how often."""
import random, os, statistics as st
from dynfee_model import *
from svgchart import Chart, PAL

FIG = os.path.join(os.path.dirname(__file__), "..", "figures")
OUT = []
def md(s=""): OUT.append(s)
def T(x): return x / 1e18
def pct(x, d=1): return f"{x*100:.{d}f}%"
TERM = "atom"
MV_PROTO, MV_ENTRY, MV_EXIT = 125, 50, 75

# ---- user population: $20-$100 at a reference price; log-uniform in TRUST, 10% "enthusiasts" 3x-6x bigger
def draw_user(rnd, lo, hi):
    import math
    if rnd.random() < 0.10:
        return int(rnd.uniform(hi*1.5, hi*3) * E18)
    return int(math.exp(rnd.uniform(math.log(lo), math.log(hi))) * E18)

def run_atom(cfg, flags, stall_tier, seed, lo=800, hi=4000, churn=0.35, stall_rounds=80, mvfees=True, stall_level=None):
    rnd = random.Random(seed)
    c = Curve(cfg, **flags); mv = MV(c, MV_PROTO if mvfees else 0, MV_ENTRY if mvfees else 0, MV_EXIT if mvfees else 0)
    users = {}   # name -> dict(gross, fee_curve, fee_mv, exited, payout)
    n = 0
    target = stall_level if stall_level else (c.edge(stall_tier - 1) + c.edge(stall_tier)) // 2   # middle of the stall band
    from_dep = {}; from_exit = {}
    c.subfloor_hits = 0
    def new_deposit():
        nonlocal n
        nm = f"u{n}"; n += 1
        g = draw_user(rnd, lo, hi)
        snap = {u: c.claimable(TERM, u) for u in users}
        net, fee = mv.deposit(TERM, nm, g)
        for u in snap: from_dep[u] = from_dep.get(u, 0) + c.claimable(TERM, u) - snap[u]
        users[nm] = dict(gross=g, net=net, fee_curve=fee, fee_mv=g - net - fee, exited=False, payout=0, exit_fee=0, order=n, bucket=c.userTier[TERM][nm])
    def exit_one():
        live = [u for u, d in users.items() if not d["exited"]]
        if len(live) < 3: return False
        u = rnd.choice(live)
        s = c.userStake[TERM][u]
        snap = {v: c.claimable(TERM, v) for v in users if v != u}
        pay, fee = mv.redeem(TERM, u, s)
        for v in snap: from_exit[v] = from_exit.get(v, 0) + c.claimable(TERM, v) - snap[v]
        users[u].update(exited=True, payout=pay, exit_fee=fee); return True
    # phase 1: growth to the stall level
    while c.vaultStake[TERM] < target:
        new_deposit()
        if rnd.random() < churn * 0.3: exit_one()
    n_growth = n
    # phase 2: stall — keep the vault oscillating around target
    for _ in range(stall_rounds):
        if c.vaultStake[TERM] > target and rnd.random() < 0.6:
            exit_one()
        else:
            new_deposit()
    # settle everyone (claim) to get lifetime earned
    res = []
    for u, d in users.items():
        earned = c.claimable(TERM, u)
        fees = d["fee_curve"] + d["fee_mv"] + d["exit_fee"]
        res.append(dict(name=u, order=d["order"], gross=d["gross"], bucket=d["bucket"], earned=earned, fee_curve=d["fee_curve"],
                        fee_all=fees, exited=d["exited"], live_stake=c.userStake[TERM][u], from_dep=from_dep.get(u,0), from_exit=from_exit.get(u,0)))
    tot_curve = sum(r["fee_curve"] for r in res) + sum(d["exit_fee"] for d in users.values())
    return res, c, tot_curve, n_growth

def summarize(cfg, flags, stall_tier, seeds=8, **kw):
    if "stall_level" in kw and kw["stall_level"]:
        stall_tier = Curve(cfg).tier_of(kw["stall_level"])
    agg = dict(users=0, earn_any=0, frontier_users=0, frontier_earn_any=0, yield_med=[], yield_frontier=[], proto_share=[], top_yield=[],
               fee_in=[], curve_fee_share=[], net_pos=0, fr_dep=0, fr_exit=0, subfloor=0, stall_tier=[])
    for sd in range(seeds):
        res, c, tot_curve, ng = run_atom(cfg, flags, stall_tier, sd, **kw)
        agg["users"] += len(res)
        agg["earn_any"] += sum(1 for r in res if r["earned"] > 0)
        yields = [r["earned"] / r["gross"] for r in res]
        agg["yield_med"].append(st.median(yields))
        agg["top_yield"].append(max(yields))
        fr = [r for r in res if r["bucket"] == stall_tier]
        agg["frontier_users"] += len(fr)
        agg["frontier_earn_any"] += sum(1 for r in fr if r["earned"] > 0)
        if fr: agg["yield_frontier"].append(st.median(r["earned"]/r["gross"] for r in fr))
        agg["proto_share"].append(c.protocolAccrued / tot_curve if tot_curve else 0)
        agg["fr_dep"] += sum(r["from_dep"] for r in fr); agg["fr_exit"] += sum(r["from_exit"] for r in fr)
        agg["subfloor"] += c.subfloor_hits
        agg["stall_tier"].append(c.tier_of(c.vaultStake[TERM]))
        agg["fee_in"].append(st.median(r["fee_curve"]/r["gross"] for r in res))
        agg["net_pos"] += sum(1 for r in res if r["earned"] > r["fee_all"])
    return dict(users=agg["users"]/seeds,
                p_earn=agg["earn_any"]/agg["users"],
                p_frontier_earn=(agg["frontier_earn_any"]/agg["frontier_users"]) if agg["frontier_users"] else 0,
                frontier_frac=agg["frontier_users"]/agg["users"],
                y_med=st.mean(agg["yield_med"]), y_frontier=st.mean(agg["yield_frontier"]) if agg["yield_frontier"] else 0,
                top=st.mean(agg["top_yield"]), proto=st.mean(agg["proto_share"]), fee_in=st.mean(agg["fee_in"]),
                p_netpos=agg["net_pos"]/agg["users"],
                fr_dep_share=(agg["fr_dep"]/(agg["fr_dep"]+agg["fr_exit"])) if (agg["fr_dep"]+agg["fr_exit"]) else 0,
                subfloor=agg["subfloor"]/seeds, stall_tier=st.mode(agg["stall_tier"]))

def row(label, r):
    return f"| {label} | {r['users']:.0f} | {pct(r['fee_in'])} | {pct(r['proto'])} | {pct(r['p_earn'],0)} | {pct(r['p_frontier_earn'],0)} | {pct(r['fr_dep_share'],0)} | {pct(r['y_med'],2)} | {pct(r['y_frontier'],2)} | {pct(r['top'],1)} | {pct(r['p_netpos'],0)} | {r['subfloor']:.0f} |"
HDR = ("| variant | users | median curve fee in | curve fees → protocol | users earning >0 | frontier users earning >0 | frontier earnings from deposit fees (rest = peers' exit fees) | median yield (earned/gross) | frontier median yield | best single yield | users net-positive after all fees | sub-floor tier hits |\n"
       "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")

md("## A. The average atom under the deploy seed\n")
md("Population: users draw 800–4,000 TRUST log-uniformly (≈ $20–$100 at 2.5¢), 10 % are 'enthusiasts' at 6k–12k. The atom grows to the middle of its stall band, then oscillates there for 80 more events (60 % exits when above the mid-point, deposits otherwise). 8 seeds per row. 'Yield' is lifetime curve earnings over gross deposit; 'net-positive' means earnings exceeded every fee the user paid (curve + MultiVault, in and out).\n")
md(HDR)
for stall in (3, 4):
    r = summarize(DEPLOY_SEED, {}, stall)
    md(row(f"deploy seed, atom stalls in **T{stall}**", r))
    # distribution figure data for T3 & T4 at seed 0
md("")

# ---- per-user scatter for one run: earned vs order of entry (T3 stall)
res, c, tot, ng = run_atom(DEPLOY_SEED, {}, 3, 0)
ch = Chart(title="One T3-stalled atom, deploy seed: what each user earned vs. when they entered", subtitle=f"{len(res)} users; vertical line = the atom reached its stall level; colour = bucket. Earnings are front-loaded and lumpy; late entrants earn little.", h=420, legend_rows=1)
ymax = max(T(r["earned"]) for r in res) * 1.1 or 1
ch.axes(0, len(res), 0, ymax, xlabel="entry order", ylabel="lifetime curve earnings (TRUST)", yfmt=lambda v: f"{v:,.0f}", xfmt=lambda v: f"{int(v)}")
ch.vline(ng, "#9ca3af", "4 3", "stall level reached")
for b in range(5):
    pts = [(r["order"], T(r["earned"])) for r in res if r["bucket"] == b]
    if pts:
        for x, y in pts:
            ch.parts.append(f"<circle cx='{ch.X(x):.1f}' cy='{ch.Y(y):.1f}' r='4' fill='{PAL[b]}' opacity='0.85'/>")
        ch._legend(f"bucket T{b}", PAL[b])
ch.render(f"{FIG}/10_avg_atom_scatter.svg")

md("### A1. Parameter sweeps (current mechanism), atom stalls in T3 and T4\n")
md(HDR)
def cfgv(**kw): return Config(**{**DEPLOY_SEED.__dict__, **kw})
for stall, level in ((3, 22_520*E18), (4, 32_024*E18)):
    for label, cfg in (("width0 5,000 (seed)", DEPLOY_SEED), ("width0 2,500 (atom sits in T%d)", cfgv(width0=2500*E18)), ("width0 1,000 (atom sits in T%d)", cfgv(width0=1000*E18)),
                       ("growth 25 bps/tier", cfgv(depositGrowthBps=25, withdrawalGrowthBps=25)),
                       ("kernelSpread 8", cfgv(kernelSpread=8*E18)), ("floor 500", cfgv(minEligibleTierStake=500*E18)), ("floor 1,000", cfgv(minEligibleTierStake=1000*E18))):
        r = summarize(cfg, {}, stall, stall_level=level)
        md(row(f"atom ≈ {level//E18//1000}k (T{stall} on the seed ladder) · " + (label % r['stall_tier'] if '%d' in label else label), r))
md("")
md("### A2. Mechanism variants, deploy-seed parameters\n")
md("A = depositor excluded · B = stake-weighted kernel · C = pre-deposit targeting · D = the source tier is itself a recipient (needs A + C) · E = no curve fee on same-band stake (fee only on the crossing portion) · F = lone-exiter slice to the fulcrum fallback instead of nearest-above.\n")
md(HDR)
VARS = [("current", {}), ("A+C (8579c5e)", dict(exclude_self_on_deposit=True, predeposit_targeting=True)),
        ("A+B+C", dict(exclude_self_on_deposit=True, stake_weighted_kernel=True, predeposit_targeting=True)),
        ("A+B+C+F", dict(exclude_self_on_deposit=True, stake_weighted_kernel=True, predeposit_targeting=True, reroute_to_fulcrum=True)),
        ("A+C+D (source tier earns)", dict(exclude_self_on_deposit=True, predeposit_targeting=True, include_source_tier=True)),
        ("A+B+C+D", dict(exclude_self_on_deposit=True, stake_weighted_kernel=True, predeposit_targeting=True, include_source_tier=True)),
        ("E (crossing-only fee)", dict(crossing_only_fee=True)),
        ("A+B+C+E", dict(exclude_self_on_deposit=True, stake_weighted_kernel=True, predeposit_targeting=True, crossing_only_fee=True))]
for stall in (3, 4):
    for label, fl in VARS:
        md(row(f"T{stall} · {label}", summarize(DEPLOY_SEED, fl, stall)))
md("")

# ---- figure: P(earn) and frontier P(earn) per variant at T3
labels, p_all, p_fr, ymed = [], [], [], []
for label, fl in VARS:
    r = summarize(DEPLOY_SEED, fl, 3)
    labels.append(label); p_all.append(r["p_earn"]); p_fr.append(r["p_frontier_earn"]); ymed.append(r["y_med"])
ch = Chart(title="T3-stalled atom: share of users who ever earn anything, by mechanism variant", subtitle="deploy-seed parameters; frontier = users bucketed at the stall tier", h=400, legend_rows=1, ml=60)
ch.axes(-0.5, len(labels)-0.5, 0, 1.05, xticks=list(range(len(labels))), xfmt=lambda v: ["cur","A+C","A+B+C","A+B+C+F","A+C+D","A+B+C+D","E","A+B+C+E"][int(v)], yfmt=lambda v: f"{v*100:.0f}%", ylabel="share of users")
ch.bars(list(range(len(labels))), p_all, PAL[0], label="all users earning > 0", group=2, offset=0)
ch.bars(list(range(len(labels))), p_fr, PAL[1], label="frontier (T3) users earning > 0", group=2, offset=1)
ch.render(f"{FIG}/11_avg_atom_variants.svg")

open(os.path.join(os.path.dirname(__file__), "avg_atom_results.md"), "w").write("\n".join(OUT))
print("done")
