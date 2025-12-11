"""
Event Indexer Example - Python

Demonstrates indexing and monitoring Intuition Protocol events using web3.py.

Features:
- Query historical events
- Real-time event monitoring
- Event parsing and storage
- Filtering by user/term

Usage:
    python event-indexer.py
"""

from web3 import Web3
from typing import List, Dict, Any
import time

RPC_URL = "YOUR_INTUITION_RPC_URL"
WS_RPC_URL = "YOUR_INTUITION_WS_RPC_URL"  # WebSocket for real-time
MULTIVAULT_ADDRESS = "0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e"

# Event signatures
ATOM_CREATED_TOPIC = Web3.keccak(text="AtomCreated(address,bytes32,bytes,address)").hex()
TRIPLE_CREATED_TOPIC = Web3.keccak(text="TripleCreated(address,bytes32,bytes32,bytes32,bytes32)").hex()
DEPOSITED_TOPIC = Web3.keccak(text="Deposited(address,address,bytes32,uint256,uint256,uint256,uint256,uint256,uint8)").hex()
REDEEMED_TOPIC = Web3.keccak(text="Redeemed(address,address,bytes32,uint256,uint256,uint256,uint256,uint256,uint8)").hex()

def query_historical_events(w3: Web3, from_block: int, to_block: int) -> Dict[str, List]:
    """Query historical events from a block range."""

    print(f"Querying blocks {from_block} to {to_block}...\n")

    multivault_address = Web3.to_checksum_address(MULTIVAULT_ADDRESS)
    events = {
        'atoms_created': [],
        'triples_created': [],
        'deposits': [],
        'redemptions': []
    }

    # Query AtomCreated events
    atom_filter = {
        'fromBlock': from_block,
        'toBlock': to_block,
        'address': multivault_address,
        'topics': [ATOM_CREATED_TOPIC]
    }
    atom_logs = w3.eth.get_logs(atom_filter)
    events['atoms_created'] = atom_logs
    print(f"Found {len(atom_logs)} AtomCreated events")

    # Query TripleCreated events
    triple_filter = {
        'fromBlock': from_block,
        'toBlock': to_block,
        'address': multivault_address,
        'topics': [TRIPLE_CREATED_TOPIC]
    }
    triple_logs = w3.eth.get_logs(triple_filter)
    events['triples_created'] = triple_logs
    print(f"Found {len(triple_logs)} TripleCreated events")

    # Query Deposited events
    deposit_filter = {
        'fromBlock': from_block,
        'toBlock': to_block,
        'address': multivault_address,
        'topics': [DEPOSITED_TOPIC]
    }
    deposit_logs = w3.eth.get_logs(deposit_filter)
    events['deposits'] = deposit_logs
    print(f"Found {len(deposit_logs)} Deposited events")

    # Query Redeemed events
    redeem_filter = {
        'fromBlock': from_block,
        'toBlock': to_block,
        'address': multivault_address,
        'topics': [REDEEMED_TOPIC]
    }
    redeem_logs = w3.eth.get_logs(redeem_filter)
    events['redemptions'] = redeem_logs
    print(f"Found {len(redeem_logs)} Redeemed events\n")

    return events

def query_user_events(w3: Web3, user_address: str, from_block: int, to_block: int) -> Dict[str, List]:
    """Query events for a specific user."""

    print(f"Querying events for user: {user_address}\n")

    multivault_address = Web3.to_checksum_address(MULTIVAULT_ADDRESS)
    user_topic = '0x' + user_address[2:].zfill(64)  # Pad address to 32 bytes

    events = {
        'atoms_created': [],
        'deposits': [],
        'redemptions': []
    }

    # Query user's created atoms
    atom_filter = {
        'fromBlock': from_block,
        'toBlock': to_block,
        'address': multivault_address,
        'topics': [ATOM_CREATED_TOPIC, user_topic]  # Filter by creator
    }
    atom_logs = w3.eth.get_logs(atom_filter)
    events['atoms_created'] = atom_logs
    print(f"User created {len(atom_logs)} atoms")

    # Query user's deposits (as sender)
    deposit_filter = {
        'fromBlock': from_block,
        'toBlock': to_block,
        'address': multivault_address,
        'topics': [DEPOSITED_TOPIC, user_topic]  # Filter by sender
    }
    deposit_logs = w3.eth.get_logs(deposit_filter)
    events['deposits'] = deposit_logs
    print(f"User made {len(deposit_logs)} deposits")

    # Query user's redemptions (as sender)
    redeem_filter = {
        'fromBlock': from_block,
        'toBlock': to_block,
        'address': multivault_address,
        'topics': [REDEEMED_TOPIC, user_topic]  # Filter by sender
    }
    redeem_logs = w3.eth.get_logs(redeem_filter)
    events['redemptions'] = redeem_logs
    print(f"User made {len(redeem_logs)} redemptions\n")

    return events

def monitor_real_time_events(ws_url: str) -> None:
    """Monitor events in real-time using WebSocket."""

    print("Connecting to WebSocket for real-time monitoring...")
    print("Press Ctrl+C to stop\n")

    w3 = Web3(Web3.WebsocketProvider(ws_url))

    # Create filter for all MultiVault events
    event_filter = w3.eth.filter({
        'address': Web3.to_checksum_address(MULTIVAULT_ADDRESS)
    })

    try:
        while True:
            # Get new entries
            new_entries = event_filter.get_new_entries()

            for event in new_entries:
                topic = event['topics'][0].hex()

                if topic == ATOM_CREATED_TOPIC:
                    print(f"🔵 AtomCreated")
                    print(f"   Block: {event['blockNumber']}")
                    print(f"   Tx: {event['transactionHash'].hex()}")

                elif topic == TRIPLE_CREATED_TOPIC:
                    print(f"🟢 TripleCreated")
                    print(f"   Block: {event['blockNumber']}")
                    print(f"   Tx: {event['transactionHash'].hex()}")

                elif topic == DEPOSITED_TOPIC:
                    print(f"🟡 Deposited")
                    print(f"   Block: {event['blockNumber']}")
                    print(f"   Tx: {event['transactionHash'].hex()}")

                elif topic == REDEEMED_TOPIC:
                    print(f"🔴 Redeemed")
                    print(f"   Block: {event['blockNumber']}")
                    print(f"   Tx: {event['transactionHash'].hex()}")

                print()

            # Small delay to avoid hammering the node
            time.sleep(2)

    except KeyboardInterrupt:
        print("\nStopping event monitor...")

def main() -> None:
    """Main indexer function."""

    print("=" * 60)
    print("Intuition Protocol Event Indexer")
    print("=" * 60)
    print()

    # Mode selection
    mode = input("Select mode (1=historical, 2=user, 3=realtime): ")

    if mode == '1':
        # Historical query
        w3 = Web3(Web3.HTTPProvider(RPC_URL))
        current_block = w3.eth.block_number
        from_block = current_block - 1000

        events = query_historical_events(w3, from_block, current_block)

        # Display first atom created if any
        if events['atoms_created']:
            first_atom = events['atoms_created'][0]
            print("First AtomCreated event:")
            print(f"  Block: {first_atom['blockNumber']}")
            print(f"  Tx: {first_atom['transactionHash'].hex()}")

    elif mode == '2':
        # User-specific query
        user_address = input("Enter user address: ")
        w3 = Web3(Web3.HTTPProvider(RPC_URL))
        current_block = w3.eth.block_number
        from_block = current_block - 1000

        events = query_user_events(w3, user_address, from_block, current_block)

    elif mode == '3':
        # Real-time monitoring
        if not WS_RPC_URL:
            print("❌ WebSocket RPC URL not configured")
            return

        monitor_real_time_events(WS_RPC_URL)

    else:
        print("Invalid mode selected")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)

"""
Example Output:

================================================================
Intuition Protocol Event Indexer
================================================================

Select mode (1=historical, 2=user, 3=realtime): 1
Querying blocks 12000 to 13000...

Found 45 AtomCreated events
Found 23 TripleCreated events
Found 156 Deposited events
Found 89 Redeemed events

First AtomCreated event:
  Block: 12045
  Tx: 0xabc123def456...
"""
