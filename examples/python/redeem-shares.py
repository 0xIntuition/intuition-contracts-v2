"""
Redeem Shares Example - Python

Demonstrates redeeming vault shares for underlying assets using web3.py.

Usage:
    python redeem-shares.py
"""

from web3 import Web3
from eth_account import Account
import os

RPC_URL = "YOUR_INTUITION_RPC_URL"
MULTIVAULT_ADDRESS = "0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e"
PRIVATE_KEY = os.getenv("PRIVATE_KEY", "")

TERM_ID = bytes.fromhex("0000000000000000000000000000000000000000000000000000000000000001")
CURVE_ID = 1
SHARES_TO_REDEEM = Web3.to_wei(5, 'ether')
SLIPPAGE_BPS = 100  # 1%

MULTIVAULT_ABI = [
    {"inputs": [{"type": "address", "name": "receiver"}, {"type": "bytes32", "name": "termId"}, {"type": "uint256", "name": "curveId"}, {"type": "uint256", "name": "shares"}, {"type": "uint256", "name": "minAssets"}], "name": "redeem", "outputs": [{"type": "uint256"}], "stateMutability": "nonpayable", "type": "function"},
    {"inputs": [{"type": "bytes32", "name": "termId"}, {"type": "uint256", "name": "curveId"}, {"type": "uint256", "name": "shares"}], "name": "previewRedeem", "outputs": [{"type": "uint256", "name": "assetsAfterFees"}, {"type": "uint256", "name": "sharesUsed"}], "stateMutability": "view", "type": "function"},
    {"inputs": [{"type": "address", "name": "account"}, {"type": "bytes32", "name": "termId"}, {"type": "uint256", "name": "curveId"}], "name": "getShares", "outputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"}
]

def main() -> None:
    print("Redeeming Shares\n")

    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(PRIVATE_KEY)

    multivault = w3.eth.contract(address=Web3.to_checksum_address(MULTIVAULT_ADDRESS), abi=MULTIVAULT_ABI)

    # Get current shares
    current_shares = multivault.functions.getShares(account.address, TERM_ID, CURVE_ID).call()
    print(f"Current shares: {Web3.from_wei(current_shares, 'ether')}")

    if current_shares == 0:
        print("❌ No shares to redeem")
        return

    # Use all shares if redeeming more than available
    shares_to_redeem = min(SHARES_TO_REDEEM, current_shares)
    print(f"Redeeming: {Web3.from_wei(shares_to_redeem, 'ether')} shares\n")

    # Preview redemption
    expected_assets, shares_used = multivault.functions.previewRedeem(
        TERM_ID, CURVE_ID, shares_to_redeem
    ).call()

    min_assets = expected_assets * (10000 - SLIPPAGE_BPS) // 10000

    print(f"Expected assets: {Web3.from_wei(expected_assets, 'ether')} WTRUST")
    print(f"Min assets (1% slippage): {Web3.from_wei(min_assets, 'ether')} WTRUST\n")

    # Redeem
    redeem_tx = multivault.functions.redeem(
        account.address, TERM_ID, CURVE_ID, shares_to_redeem, min_assets
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 200000,
        'gasPrice': w3.eth.gas_price
    })

    signed_redeem = account.sign_transaction(redeem_tx)
    tx_hash = w3.eth.send_raw_transaction(signed_redeem.rawTransaction)
    print(f"Tx: {tx_hash.hex()}")

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"✓ Confirmed in block {receipt['blockNumber']}")

    # Get new shares
    new_shares = multivault.functions.getShares(account.address, TERM_ID, CURVE_ID).call()
    print(f"Remaining shares: {Web3.from_wei(new_shares, 'ether')}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)
