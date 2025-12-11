"""
Deposit into Vault Example - Python

Demonstrates depositing assets into an existing vault using web3.py.

Usage:
    python deposit-vault.py
"""

from web3 import Web3
from eth_account import Account
import os

RPC_URL = "YOUR_INTUITION_RPC_URL"
MULTIVAULT_ADDRESS = "0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e"
WTRUST_ADDRESS = "0x81cFb09cb44f7184Ad934C09F82000701A4bF672"
PRIVATE_KEY = os.getenv("PRIVATE_KEY", "")

TERM_ID = bytes.fromhex("0000000000000000000000000000000000000000000000000000000000000001")
CURVE_ID = 1
DEPOSIT_AMOUNT = Web3.to_wei(5, 'ether')
SLIPPAGE_BPS = 100  # 1%

MULTIVAULT_ABI = [
    {"inputs": [{"type": "address", "name": "receiver"}, {"type": "bytes32", "name": "termId"}, {"type": "uint256", "name": "curveId"}, {"type": "uint256", "name": "minShares"}], "name": "deposit", "outputs": [{"type": "uint256"}], "stateMutability": "payable", "type": "function"},
    {"inputs": [{"type": "bytes32", "name": "termId"}, {"type": "uint256", "name": "curveId"}, {"type": "uint256", "name": "assets"}], "name": "previewDeposit", "outputs": [{"type": "uint256", "name": "shares"}, {"type": "uint256", "name": "assetsAfterFees"}], "stateMutability": "view", "type": "function"},
    {"inputs": [{"type": "bytes32", "name": "id"}], "name": "isTermCreated", "outputs": [{"type": "bool"}], "stateMutability": "view", "type": "function"},
    {"inputs": [{"type": "address", "name": "account"}, {"type": "bytes32", "name": "termId"}, {"type": "uint256", "name": "curveId"}], "name": "getShares", "outputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"}
]

ERC20_ABI = [
    {"inputs": [{"type": "address", "name": "spender"}, {"type": "uint256", "name": "amount"}], "name": "approve", "outputs": [{"type": "bool"}], "stateMutability": "nonpayable", "type": "function"}
]

def main() -> None:
    print("Depositing into Vault\n")

    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(PRIVATE_KEY)

    multivault = w3.eth.contract(address=Web3.to_checksum_address(MULTIVAULT_ADDRESS), abi=MULTIVAULT_ABI)
    wtrust = w3.eth.contract(address=Web3.to_checksum_address(WTRUST_ADDRESS), abi=ERC20_ABI)

    # Verify vault exists
    if not multivault.functions.isTermCreated(TERM_ID).call():
        raise Exception("Vault does not exist")

    # Get current shares
    current_shares = multivault.functions.getShares(account.address, TERM_ID, CURVE_ID).call()
    print(f"Current shares: {Web3.from_wei(current_shares, 'ether')}\n")

    # Preview deposit
    expected_shares, assets_after_fees = multivault.functions.previewDeposit(
        TERM_ID, CURVE_ID, DEPOSIT_AMOUNT
    ).call()

    min_shares = expected_shares * (10000 - SLIPPAGE_BPS) // 10000

    print(f"Depositing: {Web3.from_wei(DEPOSIT_AMOUNT, 'ether')} WTRUST")
    print(f"Expected shares: {Web3.from_wei(expected_shares, 'ether')}")
    print(f"Min shares (1% slippage): {Web3.from_wei(min_shares, 'ether')}\n")

    # Approve
    approve_tx = wtrust.functions.approve(multivault.address, DEPOSIT_AMOUNT).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 100000,
        'gasPrice': w3.eth.gas_price
    })
    signed = account.sign_transaction(approve_tx)
    w3.eth.send_raw_transaction(signed.rawTransaction)
    print("✓ Approved\n")

    # Deposit
    deposit_tx = multivault.functions.deposit(
        account.address, TERM_ID, CURVE_ID, min_shares
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 200000,
        'gasPrice': w3.eth.gas_price,
        'value': 0
    })

    signed_deposit = account.sign_transaction(deposit_tx)
    tx_hash = w3.eth.send_raw_transaction(signed_deposit.rawTransaction)
    print(f"Tx: {tx_hash.hex()}")

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"✓ Confirmed in block {receipt['blockNumber']}")

    # Get new shares
    new_shares = multivault.functions.getShares(account.address, TERM_ID, CURVE_ID).call()
    shares_added = new_shares - current_shares
    print(f"Shares added: {Web3.from_wei(shares_added, 'ether')}")
    print(f"Total shares: {Web3.from_wei(new_shares, 'ether')}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)
