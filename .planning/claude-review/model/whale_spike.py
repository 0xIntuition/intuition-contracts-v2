"""AV-2 / AV-4 / AV-5: a $50 user enters a 22.5k T3 atom while a 40k whale is passing through."""
from dynfee_model import *
E = 10**18; TERM = "t"
def gross_to_fill(c, target, mv):
    lo, hi = target, target * 2; start = c.vaultStake[TERM]
    def net_of(g): return g - mul_div(g, mv.protocolFeeBps, BPS) - mul_div(g, mv.entryFeeBps, BPS) - c._piecewise(start, g)
    while lo < hi:
        mid = (lo + hi) // 2
        if net_of(mid) < target: lo = mid + 1
        else: hi = mid
    return lo
for label, flags in (("current", {}), ("F: reroute to fulcrum", dict(reroute_to_fulcrum=True)),
                     ("A+B+C+F", dict(exclude_self_on_deposit=True, stake_weighted_kernel=True, predeposit_targeting=True, reroute_to_fulcrum=True))):
    c = Curve(DEPLOY_SEED, **flags); mv = MV(c, 125, 50, 75)
    for k in range(4): mv.deposit(TERM, f"C{k}", gross_to_fill(c, c.width(k), mv))
    mv.redeem(TERM, "C3", c.userStake[TERM]["C3"] // 2)                 # atom ≈ 22.5k, T3
    mv.deposit(TERM, "WHALE", 40_000 * E)                                # spike to T6
    net, fee = mv.deposit(TERM, "U", 2000 * E)                           # $50 user during the spike -> bucket T6
    before = {a: c.claimable(TERM, a) for a in ("C0", "C1", "C2", "C3", "U")}
    mv.redeem(TERM, "WHALE", c.userStake[TERM]["WHALE"])                 # whale leaves alone from its bucket
    got = {a: (c.claimable(TERM, a) - before[a]) / 1e18 for a in before}
    mv.deposit(TERM, "P", 2000 * E)                                      # a peer enters at T3
    gross = c.userStake[TERM]["U"]
    print(f"[{label}] atom back at {c.vaultStake[TERM]//E} (T{c.tier_of(c.vaultStake[TERM])}); whale exit fee split:",
          {k: round(v, 1) for k, v in got.items()}, f"| U bucket T{c.userTier[TERM]['U']} exit {c.wd_bps(c.userTier[TERM]['U'])/100}% vs peer {c.wd_bps(c.userTier[TERM]['P'])/100}%",
          f"| U real exit fee {c.quote_redeem_fee(TERM,'U',gross)/1e18:.2f} vs account-less preview {mul_div_up(gross, c.wd_bps(c.tier_of(c.vaultStake[TERM])), BPS)/1e18:.2f}")
