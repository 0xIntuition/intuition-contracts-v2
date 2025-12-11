"""
Create Atom Example

Demonstrates how to create an atom vault with an initial deposit using web3.py.

Prerequisites:
- Python 3.8+
- web3.py: pip install web3
- WTRUST tokens for deposit
- Private key with ETH for gas

Usage:
    python create-atom.py
"""

from web3 import Web3
from eth_account import Account
from typing import List, Tuple
import os

# ============================================================================
# Configuration
# ============================================================================

RPC_URL = "YOUR_INTUITION_RPC_URL"
MULTIVAULT_ADDRESS = "0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e"
WTRUST_ADDRESS = "0x81cFb09cb44f7184Ad934C09F82000701A4bF672"

# Your private key (NEVER commit this!)
PRIVATE_KEY = os.getenv("PRIVATE_KEY", "")

# Atom configuration
ATOM_DATA = b"My First Atom"  # Atom metadata as bytes
DEPOSIT_AMOUNT = Web3.to_wei(10, 'ether')  # 10 WTRUST

# ============================================================================
# Contract ABIs (minimal required functions)
# ============================================================================

MULTIVAULT_ABI = [
    {
        "inputs": [
            {"type": "bytes[]", "name": "atomDatas"},
            {"type": "uint256[]", "name": "assets"}
        ],
        "name": "createAtoms",
        "outputs": [{"type": "bytes32[]", "name": ""}],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [{"type": "bytes", "name": "data"}],
        "name": "calculateAtomId",
        "outputs": [{"type": "bytes32", "name": "id"}],
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
        "name": "getAtomCost",
        "outputs": [{"type": "uint256", "name": ""}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "name": "creator", "type": "address"},
            {"indexed": True, "name": "termId", "type": "bytes32"},
            {"indexed": False, "name": "atomData", "type": "bytes"},
            {"indexed": False, "name": "atomWallet", "type": "address"}
        ],
        "name": "AtomCreated",
        "type": "event"
    }
]

ERC20_ABI = [
    {
        "inputs": [
            {"type": "address", "name": "spender"},
            {"type": "uint256", "name": "amount"}
        ],
        "name": "approve",
        "outputs": [{"type": "bool", "name": ""}],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"type": "address", "name": "owner"},
            {"type": "address", "name": "spender"}
        ],
        "name": "allowance",
        "outputs": [{"type": "uint256", "name": ""}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"type": "address", "name": "account"}],
        "name": "balanceOf",
        "outputs": [{"type": "uint256", "name": ""}],
        "stateMutability": "view",
        "type": "function"
    }
]

# ============================================================================
# Main Function
# ============================================================================

def main() -> None:
    """Create an atom vault with initial deposit."""

    print("=" * 80)
    print("Creating Atom Vault on Intuition Protocol")
    print("=" * 80)
    print()

    # ------------------------------------------------------------------------
    # Step 1: Setup Web3 Connection
    # ------------------------------------------------------------------------
    print("Step 1: Connecting to Intuition network...")

    w3 = Web3(Web3.HTTPProvider(RPC_URL))

    if not w3.is_connected():
        raise Exception("Failed to connect to Intuition network")

    # Setup account from private key
    account = Account.from_key(PRIVATE_KEY)
    print(f"✓ Connected with address: {account.address}")
    print()

    # Check ETH balance
    eth_balance = w3.eth.get_balance(account.address)
    print(f"ETH Balance: {Web3.from_wei(eth_balance, 'ether')} ETH")
    print()

    # ------------------------------------------------------------------------
    # Step 2: Initialize Contract Instances
    # ------------------------------------------------------------------------
    print("Step 2: Initializing contract instances...")

    multivault = w3.eth.contract(
        address=Web3.to_checksum_address(MULTIVAULT_ADDRESS),
        abi=MULTIVAULT_ABI
    )

    wtrust = w3.eth.contract(
        address=Web3.to_checksum_address(WTRUST_ADDRESS),
        abi=ERC20_ABI
    )

    print(f"✓ MultiVault: {MULTIVAULT_ADDRESS}")
    print(f"✓ WTRUST: {WTRUST_ADDRESS}")
    print()

    # ------------------------------------------------------------------------
    # Step 3: Check WTRUST Balance and Get Atom Cost
    # ------------------------------------------------------------------------
    print("Step 3: Checking WTRUST balance and atom creation cost...")

    wtrust_balance = wtrust.functions.balanceOf(account.address).call()
    print(f"WTRUST Balance: {Web3.from_wei(wtrust_balance, 'ether')} WTRUST")

    atom_cost = multivault.functions.getAtomCost().call()
    print(f"Atom Creation Cost: {Web3.from_wei(atom_cost, 'ether')} WTRUST")

    total_required = DEPOSIT_AMOUNT + atom_cost
    print(f"Total Required: {Web3.from_wei(total_required, 'ether')} WTRUST")

    if wtrust_balance < total_required:
        raise Exception(
            f"Insufficient WTRUST balance. "
            f"Need {Web3.from_wei(total_required, 'ether')} "
            f"but have {Web3.from_wei(wtrust_balance, 'ether')}"
        )

    print("✓ Sufficient balance confirmed")
    print()

    # ------------------------------------------------------------------------
    # Step 4: Calculate Atom ID and Check Existence
    # ------------------------------------------------------------------------
    print("Step 4: Calculating atom ID and checking if it exists...")

    # Calculate what the atom ID will be
    atom_id = multivault.functions.calculateAtomId(ATOM_DATA).call()
    print(f"Atom ID: {atom_id.hex()}")

    # Check if this atom already exists
    atom_exists = multivault.functions.isTermCreated(atom_id).call()
    if atom_exists:
        print("⚠ Warning: This atom already exists!")
        return

    print("✓ Atom does not exist yet, safe to create")
    print()

    # ------------------------------------------------------------------------
    # Step 5: Approve WTRUST Spending
    # ------------------------------------------------------------------------
    print("Step 5: Approving WTRUST spending...")

    current_allowance = wtrust.functions.allowance(
        account.address,
        multivault.address
    ).call()

    print(f"Current allowance: {Web3.from_wei(current_allowance, 'ether')} WTRUST")

    if current_allowance < total_required:
        print("Approving WTRUST tokens...")

        # Build approval transaction
        approve_tx = wtrust.functions.approve(
            multivault.address,
            total_required
        ).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 100000,
            'gasPrice': w3.eth.gas_price,
        })

        # Sign and send
        signed_approve = account.sign_transaction(approve_tx)
        approve_hash = w3.eth.send_raw_transaction(signed_approve.rawTransaction)

        print(f"Approval tx submitted: {approve_hash.hex()}")

        # Wait for confirmation
        approve_receipt = w3.eth.wait_for_transaction_receipt(approve_hash)
        print(f"✓ Approval confirmed in block {approve_receipt['blockNumber']}")
    else:
        print("✓ Sufficient allowance already exists")

    print()

    # ------------------------------------------------------------------------
    # Step 6: Create Atom
    # ------------------------------------------------------------------------
    print("Step 6: Creating atom vault...")
    print(f"Atom data: \"{ATOM_DATA.decode('utf-8')}\"")
    print(f"Initial deposit: {Web3.from_wei(DEPOSIT_AMOUNT, 'ether')} WTRUST")
    print()

    # Build create atom transaction
    create_tx = multivault.functions.createAtoms(
        [ATOM_DATA],  # atomDatas array
        [DEPOSIT_AMOUNT]  # assets array
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 400000,
        'gasPrice': w3.eth.gas_price,
        'value': 0,  # No ETH value for WTRUST deposits
    })

    # Sign and send
    signed_create = account.sign_transaction(create_tx)
    create_hash = w3.eth.send_raw_transaction(signed_create.rawTransaction)

    print(f"Transaction submitted: {create_hash.hex()}")
    print("Waiting for confirmation...")

    # Wait for transaction to be mined
    receipt = w3.eth.wait_for_transaction_receipt(create_hash)
    print(f"✓ Transaction confirmed in block {receipt['blockNumber']}")
    print(f"Gas used: {receipt['gasUsed']}")
    print()

    # ------------------------------------------------------------------------
    # Step 7: Parse Events
    # ------------------------------------------------------------------------
    print("Step 7: Parsing transaction events...")

    # Get AtomCreated event
    atom_created_event = multivault.events.AtomCreated().process_receipt(receipt)

    if atom_created_event:
        event = atom_created_event[0]
        print("AtomCreated Event:")
        print(f"  Creator: {event['args']['creator']}")
        print(f"  Atom ID: {event['args']['termId'].hex()}")
        print(f"  Atom Data: \"{event['args']['atomData'].decode('utf-8')}\"")
        print(f"  Atom Wallet: {event['args']['atomWallet']}")
        print()

    # ------------------------------------------------------------------------
    # Success!
    # ------------------------------------------------------------------------
    print("=" * 80)
    print("✓ Atom creation successful!")
    print(f"Atom ID: {atom_id.hex()}")
    print(f"View on explorer: https://explorer.intuit.network/tx/{create_hash.hex()}")
    print("=" * 80)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print()
        print("=" * 80)
        print("❌ Error creating atom:")
        print("=" * 80)
        print(f"Message: {str(error)}")
        print()
        exit(1)

# ============================================================================
# Example Output
# ============================================================================

"""
================================================================================
Creating Atom Vault on Intuition Protocol
================================================================================

Step 1: Connecting to Intuition network...
✓ Connected with address: 0x1234567890123456789012345678901234567890
ETH Balance: 0.5 ETH

Step 2: Initializing contract instances...
✓ MultiVault: 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
✓ WTRUST: 0x81cFb09cb44f7184Ad934C09F82000701A4bF672

Step 3: Checking WTRUST balance and atom creation cost...
WTRUST Balance: 100.0 WTRUST
Atom Creation Cost: 0.1 WTRUST
Total Required: 10.1 WTRUST
✓ Sufficient balance confirmed

Step 4: Calculating atom ID and checking if it exists...
Atom ID: 0x8f3e4d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e
✓ Atom does not exist yet, safe to create

Step 5: Approving WTRUST spending...
Current allowance: 0.0 WTRUST
Approving WTRUST tokens...
Approval tx submitted: 0xabc123...
✓ Approval confirmed in block 12345

Step 6: Creating atom vault...
Atom data: "My First Atom"
Initial deposit: 10.0 WTRUST

Transaction submitted: 0xdef456...
Waiting for confirmation...
✓ Transaction confirmed in block 12346
Gas used: 325432

Step 7: Parsing transaction events...
AtomCreated Event:
  Creator: 0x1234567890123456789012345678901234567890
  Atom ID: 0x8f3e4d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e
  Atom Data: "My First Atom"
  Atom Wallet: 0x9876543210987654321098765432109876543210

================================================================================
✓ Atom creation successful!
Atom ID: 0x8f3e4d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e
View on explorer: https://explorer.intuit.network/tx/0xdef456...
================================================================================
"""
