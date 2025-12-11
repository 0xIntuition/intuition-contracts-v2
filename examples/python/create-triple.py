"""
Create Triple Example - Python

Demonstrates creating a triple vault (Subject-Predicate-Object) using web3.py.

Usage:
    python create-triple.py
"""

from web3 import Web3
from eth_account import Account
import os

RPC_URL = "YOUR_INTUITION_RPC_URL"
MULTIVAULT_ADDRESS = "0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e"
WTRUST_ADDRESS = "0x81cFb09cb44f7184Ad934C09F82000701A4bF672"
PRIVATE_KEY = os.getenv("PRIVATE_KEY", "")

# Triple configuration - replace with actual atom IDs
SUBJECT_ID = bytes.fromhex("0000000000000000000000000000000000000000000000000000000000000001")
PREDICATE_ID = bytes.fromhex("0000000000000000000000000000000000000000000000000000000000000002")
OBJECT_ID = bytes.fromhex("0000000000000000000000000000000000000000000000000000000000000003")
DEPOSIT_AMOUNT = Web3.to_wei(20, 'ether')

MULTIVAULT_ABI = [
    {
        "inputs": [
            {"type": "bytes32[]", "name": "subjectIds"},
            {"type": "bytes32[]", "name": "predicateIds"},
            {"type": "bytes32[]", "name": "objectIds"},
            {"type": "uint256[]", "name": "assets"}
        ],
        "name": "createTriples",
        "outputs": [{"type": "bytes32[]", "name": ""}],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [
            {"type": "bytes32", "name": "subjectId"},
            {"type": "bytes32", "name": "predicateId"},
            {"type": "bytes32", "name": "objectId"}
        ],
        "name": "calculateTripleId",
        "outputs": [{"type": "bytes32", "name": ""}],
        "stateMutability": "pure",
        "type": "function"
    },
    {
        "inputs": [{"type": "bytes32", "name": "id"}],
        "name": "isTermCreated",
        "outputs": [{"type": "bool", "name": ""}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getTripleCost",
        "outputs": [{"type": "uint256", "name": ""}],
        "stateMutability": "view",
        "type": "function"
    }
]

ERC20_ABI = [
    {"inputs": [{"type": "address", "name": "spender"}, {"type": "uint256", "name": "amount"}], "name": "approve", "outputs": [{"type": "bool"}], "stateMutability": "nonpayable", "type": "function"},
    {"inputs": [{"type": "address", "name": "account"}], "name": "balanceOf", "outputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"}
]

def main() -> None:
    print("Creating Triple Vault\n")

    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(PRIVATE_KEY)

    multivault = w3.eth.contract(
        address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
        abi=MULTIVAULT_ABI
    )
    wtrust = w3.eth.contract(
        address=Web3.to_checksum_address(WTRUST_ADDRESS),
        abi=ERC20_ABI
    )

    # Verify atoms exist
    print("Verifying atoms exist...")
    for atom_id in [SUBJECT_ID, PREDICATE_ID, OBJECT_ID]:
        exists = multivault.functions.isTermCreated(atom_id).call()
        if not exists:
            raise Exception(f"Atom {atom_id.hex()} does not exist")
    print("✓ All atoms exist\n")

    # Calculate triple ID
    triple_id = multivault.functions.calculateTripleId(
        SUBJECT_ID, PREDICATE_ID, OBJECT_ID
    ).call()
    print(f"Triple ID: {triple_id.hex()}")

    # Check if triple exists
    if multivault.functions.isTermCreated(triple_id).call():
        print("⚠ Triple already exists")
        return

    # Get cost and approve
    triple_cost = multivault.functions.getTripleCost().call()
    total_amount = DEPOSIT_AMOUNT + triple_cost

    print(f"Total required: {Web3.from_wei(total_amount, 'ether')} WTRUST\n")

    # Approve WTRUST
    print("Approving WTRUST...")
    approve_tx = wtrust.functions.approve(
        multivault.address, total_amount
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 100000,
        'gasPrice': w3.eth.gas_price
    })
    signed = account.sign_transaction(approve_tx)
    w3.eth.send_raw_transaction(signed.rawTransaction)
    print("✓ Approved\n")

    # Create triple
    print("Creating triple...")
    create_tx = multivault.functions.createTriples(
        [SUBJECT_ID], [PREDICATE_ID], [OBJECT_ID], [DEPOSIT_AMOUNT]
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 500000,
        'gasPrice': w3.eth.gas_price,
        'value': 0
    })

    signed_create = account.sign_transaction(create_tx)
    tx_hash = w3.eth.send_raw_transaction(signed_create.rawTransaction)
    print(f"Tx: {tx_hash.hex()}")

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"✓ Confirmed in block {receipt['blockNumber']}")
    print(f"Triple ID: {triple_id.hex()}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)
