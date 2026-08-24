"""
Bit-exact Python reference model of DynamicFeeFlatPriceCurve (src/protocol/curves/DynamicFeeFlatPriceCurve.sol).

Every arithmetic step mirrors the Solidity: floor division for fullMulDiv/mulDiv, ceil for mulDivUp,
solady rpow rounding for the geometric tier edges. Used to replay deposit/redeem lifecycles and to
cross-check against the on-chain contract (see scenarios.t.sol in the same folder).
"""
from dataclasses import dataclass, field
from collections import defaultdict

BPS = 10_000
ACC = 10**18
TP = 10**18   # TIER_PRECISION
WAD = 10**18
E18 = 10**18


def mul_div(a, b, d):
    return (a * b) // d


def mul_div_up(a, b, d):
    return -((-(a * b)) // d)


def rpow(x, y, b):
    """solady FixedPointMathLib.rpow (round-half-up at each step)."""
    z = b if y == 0 else 0
    if x:
        z = x if (y & 1) else b
        half = b >> 1
        y >>= 1
        while y:
            xx = x * x
            xx_round = xx + half
            x = xx_round // b
            if y & 1:
                zx = z * x
                zx_round = zx + half
                z = zx_round // b
            y >>= 1
    return z


@dataclass
class Config:
    width0: int
    tierCount: int
    growthGBps: int
    depositBaseBps: int
    depositGrowthBps: int
    depositCapBps: int
    fulcrumAlpha: int
    kernelSpread: int
    withdrawalBaseBps: int
    withdrawalGrowthBps: int
    withdrawalCapBps: int
    withdrawalToFulcrumTiersBps: int = 0
    depositToPriorTierBps: int = 0
    minEligibleTierStake: int = 0


DEPLOY_SEED = Config(5000 * E18, 13, 2000, 100, 50, 1000, 10_000, 4 * E18, 200, 50, 1000)
REFERENCE = Config(1000 * E18, 13, 5000, 100, 50, 1000, 10_000, 4 * E18, 200, 50, 1000)


@dataclass
class Event:
    kind: str
    data: dict


class Curve:
    def __init__(self, cfg: Config, exclude_self_on_deposit=False, stake_weighted_kernel=False, predeposit_targeting=False,
                 include_source_tier=False, crossing_only_fee=False, reroute_to_fulcrum=False):
        self.cfg = cfg
        self.include_source_tier = include_source_tier   # what-if D: the source tier itself is a recipient (kernel d=0, weight 1.0)
        self.crossing_only_fee = crossing_only_fee       # what-if E: no curve fee on the portion landing in the pre-deposit band
        self.reroute_to_fulcrum = reroute_to_fulcrum     # what-if F: lone-exiter slice goes to the fulcrum fallback, not nearest-above
        self.predeposit_targeting = predeposit_targeting         # what-if fix C (original 8579c5e targeting)
        self.exclude_self_on_deposit = exclude_self_on_deposit   # what-if fix A
        self.stake_weighted_kernel = stake_weighted_kernel       # what-if fix B
        self.override = {}  # tier -> (dep, wd)
        self.vaultStake = defaultdict(int)
        self.tierStake = defaultdict(lambda: defaultdict(int))
        self.acc = defaultdict(lambda: defaultdict(int))
        self.userStake = defaultdict(lambda: defaultdict(int))
        self.userTier = defaultdict(lambda: defaultdict(int))
        self.userAvgTier = defaultdict(lambda: defaultdict(int))
        self.rewardDebt = defaultdict(lambda: defaultdict(int))
        self.earned = defaultdict(int)
        self.protocolAccrued = 0
        self.balance = 0  # native balance held by the curve
        self.events = []

    # ---------------- tier math ----------------
    def edge(self, k):
        g = self.cfg.growthGBps
        if g == 0:
            return self.cfg.width0 * (k + 1)
        ratio = mul_div(BPS + g, WAD, BPS)
        pw = rpow(ratio, k + 1, WAD)
        gwad = mul_div(g, WAD, BPS)
        return mul_div(self.cfg.width0, pw - WAD, gwad)

    def width(self, k):
        return self.edge(0) if k == 0 else self.edge(k) - self.edge(k - 1)

    def tier_of(self, assets):
        if assets == 0:
            return 0
        for k in range(self.cfg.tierCount):
            if assets < self.edge(k):
                return k
        return self.cfg.tierCount - 1

    def dep_bps(self, tier):
        cap = self.cfg.depositCapBps
        if tier in self.override:
            return min(self.override[tier][0], cap)
        return min(self.cfg.depositBaseBps + tier * self.cfg.depositGrowthBps, cap)

    def wd_bps(self, tier):
        cap = self.cfg.withdrawalCapBps
        if tier in self.override:
            return min(self.override[tier][1], cap)
        return min(self.cfg.withdrawalBaseBps + tier * self.cfg.withdrawalGrowthBps, cap)

    def round_tier(self, avg):
        r = (avg + TP // 2) // TP
        return min(r, self.cfg.tierCount - 1)

    # ---------------- quotes ----------------
    def quote_deposit_fee(self, term, base):
        return self._piecewise(self.vaultStake[term], base)

    def _piecewise(self, start, base):
        fee = 0
        remaining = base
        cursor = start
        tier = self.tier_of(start)
        top = self.cfg.tierCount - 1
        first = tier
        while remaining > 0:
            rate = 0 if (self.crossing_only_fee and tier == first) else self.dep_bps(tier)
            chunk = remaining
            if tier < top:
                room_net = self.edge(tier) - cursor
                room_gross = mul_div_up(room_net, BPS, BPS - rate)
                if room_gross < chunk:
                    chunk = room_gross
            cf = mul_div_up(chunk, rate, BPS)
            fee += cf
            remaining -= chunk
            cursor += chunk - cf
            tier += 1
        return fee

    def quote_redeem_fee(self, term, account, gross):
        tier = self.userTier[term][account] if self.userStake[term][account] > 0 else self.tier_of(self.vaultStake[term])
        return mul_div_up(gross, self.wd_bps(tier), BPS)

    # ---------------- eligibility ----------------
    subfloor_hits = 0
    def eligible(self, stake):
        if 0 < stake < self.cfg.minEligibleTierStake:
            self.subfloor_hits += 1
        return stake > 0 and stake >= self.cfg.minEligibleTierStake

    # ---------------- record deposit ----------------
    def record_deposit(self, term, account, net, fee):
        self.balance += fee
        start = self.vaultStake[term]
        source = self.tier_of(start)
        if net == 0:
            self._pay_deposit_fee(term, fee, source)
        else:
            self._replay(term, account, start, net, fee)
            self.vaultStake[term] = start + net
        self.events.append(Event("DepositRecorded", dict(term=term, account=account, net=net, fee=fee,
                                                         source=source, tier=self.userTier[term][account],
                                                         avg=self.userAvgTier[term][account])))

    def _walk(self, start, net, tier, top):
        bands = []
        total_w = 0
        remaining = net
        cursor = start
        first = tier
        while remaining > 0:
            chunk = remaining
            if tier < top:
                room = self.edge(tier) - cursor
                if room < chunk:
                    chunk = room
            bands.append(chunk)
            total_w += mul_div(chunk, 0 if (self.crossing_only_fee and tier == first) else self.dep_bps(tier), BPS)
            remaining -= chunk
            cursor += chunk
            tier += 1
        return bands, total_w

    def _replay(self, term, account, start, net, fee):
        source = self.tier_of(start)
        top = self.cfg.tierCount - 1
        if source == top or start + net <= self.edge(source):
            self._apply_band(term, account, source, net, fee)
            return
        bands, total_w = self._walk(start, net, source, top)
        assigned = 0
        for i, bs in enumerate(bands):
            bt = source + i
            bf = 0
            if i + 1 == len(bands):
                bf = fee - assigned
            elif total_w > 0:
                bf = mul_div(fee, mul_div(bs, self.dep_bps(bt), BPS), total_w)
                assigned += bf
            self._apply_band(term, account, bt, bs, bf, source if self.predeposit_targeting else bt)

    def _apply_band(self, term, account, bt, bs, bf, dist_tier=None):
        if dist_tier is None:
            dist_tier = bt
        old_stake = self.userStake[term][account]
        old_tier = self.userTier[term][account]
        if self.exclude_self_on_deposit:
            # what-if fix A: settle first, distribute with the depositor's current position excluded, then land + re-base
            if old_stake > 0:
                self._settle(term, account)
            self._pay_deposit_fee(term, bf, dist_tier, old_tier, old_stake)
        else:
            self._pay_deposit_fee(term, bf, dist_tier)
            if old_stake > 0:
                self._settle(term, account)
        new_stake = old_stake + bs
        if old_stake == 0:
            new_avg = bt * TP
        else:
            new_avg = mul_div(self.userAvgTier[term][account], old_stake, new_stake) + mul_div(bt * TP, bs, new_stake)
        new_tier = self.round_tier(new_avg)
        if new_tier != old_tier:
            if old_stake > 0:
                self.tierStake[term][old_tier] -= old_stake
            self.tierStake[term][new_tier] += new_stake
        else:
            self.tierStake[term][new_tier] += bs
        self.userStake[term][account] = new_stake
        self.userAvgTier[term][account] = new_avg
        self.userTier[term][account] = new_tier
        self.rewardDebt[term][account] = mul_div(new_stake, self.acc[term][new_tier], ACC)
        self.events.append(Event("DepositBandRecorded", dict(term=term, account=account, bandTier=bt, bandStake=bs, bandFee=bf)))

    def _pay_deposit_fee(self, term, fee, tier, excl_tier=0, excl_stake=0):
        if fee == 0:
            return
        to_prior = mul_div(fee, self.cfg.depositToPriorTierBps, BPS)
        to_fulcrum = fee - to_prior
        if to_prior > 0:
            rt, rs = self._nearest_eligible_prior(term, tier)
            if rs > 0:
                self.acc[term][rt] += mul_div(to_prior, ACC, rs)
            else:
                to_fulcrum += to_prior
        self._pay_fulcrum(term, to_fulcrum, tier, excl_tier, excl_stake)

    def _tri(self, dist, sigma):
        ratio = mul_div(dist, TP, sigma)
        return TP - ratio if ratio < TP else 0

    @staticmethod
    def _fdist(d, dstar):
        dp = d * TP
        return dp - dstar if dp > dstar else dstar - dp

    def _pay_fulcrum(self, term, pool, tier, excl_tier, excl_stake):
        if pool == 0:
            return
        span = tier
        d0 = 0 if self.include_source_tier else 1
        if span == 0 and not self.include_source_tier:
            self.protocolAccrued += pool
            self.events.append(Event("ProtocolAccrued", dict(amount=pool, why="span0")))
            return
        dstar = mul_div((BPS - self.cfg.fulcrumAlpha) * span, TP, BPS)
        weights = [0] * (span + 1)
        stakes = [0] * (span + 1)
        sigma = self.cfg.kernelSpread
        sum_w = 0
        for d in range(d0, span + 1):
            t = span - d
            rs = self.tierStake[term][t]
            if t == excl_tier:
                rs -= excl_stake
            if not self.eligible(rs):
                rs = 0
            stakes[d - 1] = rs
            if rs > 0:
                w = self._tri(self._fdist(d, dstar), sigma)
                if self.stake_weighted_kernel:
                    w = w * rs // TP   # what-if fix B: weight = kernel × stake (each wei of stake earns pool·w_d / Σ w·s)
                weights[d - 1] = w
                sum_w += w
        if sum_w == 0:
            # award nearest or protocol
            best_tier, best_stake, best_dist = 0, 0, None
            for d in range(d0, span + 1):
                rs = stakes[d - 1]
                if rs > 0:
                    dist = self._fdist(d, dstar)
                    if best_dist is None or dist < best_dist:
                        best_dist, best_tier, best_stake = dist, span - d, rs
            if best_stake > 0:
                self.acc[term][best_tier] += mul_div(pool, ACC, best_stake)
                self.events.append(Event("FulcrumDegenerateAward", dict(tier=best_tier, amount=pool)))
            else:
                self.protocolAccrued += pool
                self.events.append(Event("ProtocolAccrued", dict(amount=pool, why="noEligiblePrior")))
            return
        assigned = 0
        for d in range(d0, span + 1):
            w = weights[d - 1]
            if w > 0:
                share = mul_div(pool, w, sum_w)
                if share > 0:
                    self.acc[term][span - d] += mul_div(share, ACC, stakes[d - 1])
                    assigned += share
                    self.events.append(Event("FulcrumCredit", dict(source=tier, tier=span - d, amount=share, w=w, sumW=sum_w)))
        un = pool - assigned
        if un > 0:
            self.protocolAccrued += un
            self.events.append(Event("ProtocolAccrued", dict(amount=un, why="remainder")))

    def _nearest_eligible_prior(self, term, tier):
        for k in range(tier - 1, -1, -1):
            s = self.tierStake[term][k]
            if self.eligible(s):
                return k, s
        return 0, 0

    def _nearest_eligible(self, term, frm):
        for k in range(frm + 1, self.cfg.tierCount):
            s = self.tierStake[term][k]
            if self.eligible(s):
                return k, s
        for k in range(frm - 1, -1, -1):
            s = self.tierStake[term][k]
            if self.eligible(s):
                return k, s
        return 0, 0

    # ---------------- record redeem ----------------
    def record_redeem(self, term, account, withdrawn, fee):
        self.balance += fee
        tier = self.tier_of(self.vaultStake[term])
        exit_tier = self.userTier[term][account]
        self._settle(term, account)
        self.userStake[term][account] -= withdrawn
        self.tierStake[term][exit_tier] -= withdrawn
        residual = self.userStake[term][account]
        to_fulcrum = mul_div(fee, self.cfg.withdrawalToFulcrumTiersBps, BPS)
        to_exit = fee - to_fulcrum
        undistributed = 0
        denom = self.tierStake[term][exit_tier] - residual
        if to_exit > 0:
            if self.eligible(denom):
                self.acc[term][exit_tier] += mul_div(to_exit, ACC, denom)
                self.events.append(Event("ExitTierCredit", dict(tier=exit_tier, amount=to_exit, denom=denom)))
            elif denom == 0:
                rt, rs = (0, 0) if self.reroute_to_fulcrum else self._nearest_eligible(term, exit_tier)
                if rs > 0:
                    self.acc[term][rt] += mul_div(to_exit, ACC, rs)
                    self.events.append(Event("WithdrawalFeeRerouted", dict(exitTier=exit_tier, to=rt, amount=to_exit)))
                else:
                    undistributed += to_exit
            else:
                self.protocolAccrued += to_exit
                self.events.append(Event("ProtocolAccrued", dict(amount=to_exit, why="subFloorExitCohort")))
        self._pay_fulcrum(term, to_fulcrum + undistributed, tier, exit_tier, residual)
        self.rewardDebt[term][account] = mul_div(residual, self.acc[term][exit_tier], ACC)
        self.vaultStake[term] -= withdrawn
        self.events.append(Event("RedeemRecorded", dict(term=term, account=account, withdrawn=withdrawn, fee=fee, exitTier=exit_tier)))

    # ---------------- settle / claim ----------------
    def _settle(self, term, account):
        t = self.userTier[term][account]
        accumulated = mul_div(self.userStake[term][account], self.acc[term][t], ACC)
        debt = self.rewardDebt[term][account]
        if accumulated > debt:
            self.earned[account] += accumulated - debt
        self.rewardDebt[term][account] = accumulated

    def pending(self, term, account):
        s = self.userStake[term][account]
        if s == 0:
            return 0
        a = mul_div(s, self.acc[term][self.userTier[term][account]], ACC)
        d = self.rewardDebt[term][account]
        return a - d if a > d else 0

    def claimable(self, term, account):
        return self.earned[account] + self.pending(term, account)

    def claim(self, account, terms):
        for t in terms:
            if self.userStake[t][account] > 0:
                self._settle(t, account)
        amt = self.earned[account]
        self.earned[account] = 0
        self.balance -= amt
        return amt


# ---------------- MultiVault-side wrapper ----------------
@dataclass
class MV:
    """Minimal MultiVault fee envelope around the curve: protocol/entry/exit fees (bps on the base), at par pricing."""
    curve: Curve
    protocolFeeBps: int = 0
    entryFeeBps: int = 0
    exitFeeBps: int = 0
    log: list = field(default_factory=list)

    def deposit(self, term, account, assets):
        c = self.curve
        base = assets  # assetsAfterMinSharesCost (ignoring the one-off min-share seed)
        protocol = mul_div(base, self.protocolFeeBps, BPS)
        entry = mul_div(base, self.entryFeeBps, BPS)
        after_mv = base - protocol - entry
        curve_fee = c.quote_deposit_fee(term, base)
        net = after_mv - curve_fee
        c.record_deposit(term, account, net, curve_fee)
        self.log.append(dict(op="deposit", account=account, assets=assets, protocol=protocol, entry=entry,
                             curve_fee=curve_fee, net=net))
        return net, curve_fee

    def redeem(self, term, account, shares):
        c = self.curve
        assets = shares  # 1:1
        protocol = mul_div(assets, self.protocolFeeBps, BPS)
        exit_ = mul_div(assets, self.exitFeeBps, BPS)
        curve_fee = c.quote_redeem_fee(term, account, assets)
        payout = assets - protocol - exit_ - curve_fee
        c.record_redeem(term, account, shares, curve_fee)
        self.log.append(dict(op="redeem", account=account, shares=shares, protocol=protocol, exit=exit_,
                             curve_fee=curve_fee, payout=payout))
        return payout, curve_fee


def trust(x):
    return f"{x / 1e18:,.6f}"
