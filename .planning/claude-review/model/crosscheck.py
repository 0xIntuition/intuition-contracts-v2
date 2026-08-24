from dynfee_model import *
import re

c = Curve(DEPLOY_SEED)
TERM = "term"
U = list(range(6))

def dep(u, assets):
    fee = c.quote_deposit_fee(TERM, assets)
    c.record_deposit(TERM, u, assets - fee, fee)
    print("OP dep", u, assets, fee)

def red(u, shares):
    fee = c.quote_redeem_fee(TERM, u, shares)
    c.record_redeem(TERM, u, shares, fee)
    print("OP red", u, shares, fee)

dep(0, 3000*E18); dep(1, 4000*E18); dep(2, 12_000*E18); dep(0, 20_000*E18)
red(1, 2000*E18); dep(3, 50_000*E18); red(2, c.userStake[TERM][2]); dep(4, 10**15)
red(0, c.userStake[TERM][0] // 2); dep(1, 100_000*E18); red(3, c.userStake[TERM][3])
dep(5, 300_000*E18); dep(2, 7_777*E18); red(5, c.userStake[TERM][5] // 3)

lines = []
lines.append(f"vaultStake {c.vaultStake[TERM]}")
for t in range(13):
    lines.append(f"tier {t} {c.tierStake[TERM][t]} {c.acc[TERM][t]}")
for u in U:
    lines.append(f"user {u} {c.userStake[TERM][u]} {c.userTier[TERM][u]}")
    lines.append(f"userx {u} {c.userAvgTier[TERM][u]} {c.rewardDebt[TERM][u]}")
    lines.append(f"usery {u} {c.earned[u]} {c.pending(TERM, u)}")
lines.append(f"protocolAccrued {c.protocolAccrued}")
lines.append(f"balance {c.balance}")

onchain = [l.strip() for l in open("onchain_dump.txt") if not l.startswith("[") and not l.strip().startswith("OP")]
mism = 0
for a, b in zip(onchain, lines):
    if a != b:
        mism += 1
        print("MISMATCH\n  chain:", a, "\n  model:", b)
print("lines compared:", len(lines), "mismatches:", mism)
