"""
Claim Rewards Example - Python

Demonstrates claiming TRUST token rewards from TrustBonding using web3.py.

Usage:
    python claim-rewards.py
"""

from web3 import Web3
from eth_account import Account
import os

RPC_URL = "YOUR_INTUITION_RPC_URL"
TRUST_BONDING_ADDRESS = "0x635bBD1367B66E7B16a21D6E5A63C812fFC00617"
PRIVATE_KEY = os.getenv("PRIVATE_KEY", "")

TRUST_BONDING_ABI = [
    {"inputs": [], "name": "currentEpoch", "outputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"},
    {"inputs": [], "name": "previousEpoch", "outputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"},
    {"inputs": [{"type": "address", "name": "account"}], "name": "getUserCurrentClaimableRewards", "outputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"},
    {"inputs": [{"type": "address", "name": "account"}], "name": "getUserApy", "outputs": [{"type": "uint256", "name": "currentApy"}, {"type": "uint256", "name": "maxApy"}], "stateMutability": "view", "type": "function"},
    {"inputs": [{"type": "address", "name": "account"}], "name": "getUserInfo", "outputs": [{"type": "tuple", "components": [{"type": "uint256", "name": "personalUtilization"}, {"type": "uint256", "name": "eligibleRewards"}, {"type": "uint256", "name": "maxRewards"}, {"type": "uint256", "name": "lockedAmount"}, {"type": "uint256", "name": "lockEnd"}, {"type": "uint256", "name": "bondedBalance"}]}], "stateMutability": "view", "type": "function"},
    {"inputs": [{"type": "address", "name": "recipient"}], "name": "claimRewards", "outputs": [], "stateMutability": "nonpayable", "type": "function"}
]

def main() -> None:
    print("Claiming TRUST Rewards\n")

    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(PRIVATE_KEY)

    trust_bonding = w3.eth.contract(
        address=Web3.to_checksum_address(TRUST_BONDING_ADDRESS),
        abi=TRUST_BONDING_ABI
    )

    # Get epoch info
    current_epoch = trust_bonding.functions.currentEpoch().call()
    previous_epoch = trust_bonding.functions.previousEpoch().call()

    print(f"Current Epoch: {current_epoch}")
    print(f"Previous Epoch: {previous_epoch} (claimable)\n")

    # Get user info
    user_info = trust_bonding.functions.getUserInfo(account.address).call()
    bonded_balance = user_info[5]  # bondedBalance
    eligible_rewards = user_info[1]  # eligibleRewards

    print(f"Bonded Balance: {Web3.from_wei(bonded_balance, 'ether')} veWTRUST")
    print(f"Eligible Rewards: {Web3.from_wei(eligible_rewards, 'ether')} WTRUST\n")

    if bonded_balance == 0:
        print("⚠ No bonded balance. Lock TRUST tokens first to earn rewards.")
        return

    # Get claimable rewards
    claimable = trust_bonding.functions.getUserCurrentClaimableRewards(account.address).call()
    print(f"Claimable Rewards: {Web3.from_wei(claimable, 'ether')} WTRUST\n")

    if claimable == 0:
        print("⚠ No rewards to claim at this time")
        return

    # Get APY
    current_apy, max_apy = trust_bonding.functions.getUserApy(account.address).call()
    print(f"Your APY: {current_apy / 100:.2f}% (max: {max_apy / 100:.2f}%)\n")

    # Claim rewards
    print("Claiming rewards...")
    claim_tx = trust_bonding.functions.claimRewards(account.address).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 150000,
        'gasPrice': w3.eth.gas_price
    })

    signed_claim = account.sign_transaction(claim_tx)
    tx_hash = w3.eth.send_raw_transaction(signed_claim.rawTransaction)
    print(f"Tx: {tx_hash.hex()}")

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"✓ Confirmed in block {receipt['blockNumber']}")
    print(f"✓ Claimed {Web3.from_wei(claimable, 'ether')} WTRUST")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)
