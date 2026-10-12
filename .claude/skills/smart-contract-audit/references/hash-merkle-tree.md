# Hash / Merkle Tree



Total items: 5

## (general)

### SOL-HMT-1: Is the Merkle tree vulnerable to front-running attacks?
- **Risk:** When using a merkle tree, the new proof is calculated at a certain time and there exists a period of time between when the proof is generated and the proof is published.
- **Fix:** Ensure that front-running the merkle proof setting does not affect the protocol.

### SOL-HMT-2: Does the claim method validate `msg.sender`?
- **Risk:** Validation of `msg.sender` is critical in the use of Merkle tree.
- **Fix:** Ensure that the `msg.sender` is actually the same address included in the leave.

### SOL-HMT-3: What is the result when passing a zero hash to the Merkle tree functions?
- **Risk:** Passing the zero hash can lead to unintended behaviors or vulnerabilities if not properly handled.
- **Fix:** Implement checks to handle zero hash values appropriately and prevent potential misuse.

### SOL-HMT-4: What occurs if the same proof is duplicated within the Merkle tree?
- **Risk:** Duplicate proofs within a Merkle tree can lead to double-spending or other vulnerabilities.
- **Fix:** Ensure the Merkle tree construction and verification process detects and prevents the use of duplicate proofs.

### SOL-HMT-5: Are the leaves of the Merkle tree hashed with the claimable address included?
- **Risk:** Not including claimable addresses when hashing leaves can let an attacker to claim.
- **Fix:** Ensure that the Merkle tree construction includes the hashing of claimable addresses within the leaves.
