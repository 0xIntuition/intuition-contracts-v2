# Signature



Total items: 5

## (general)

### SOL-Signature-1: Are signatures guarded against replay attacks?
- **Risk:** Lacking protection mechanisms like `nonce` and `block.chainid` can make signatures vulnerable to replay attacks. Also, EIP-712 provides a standard for creating typed and structured data to be signed, ensuring better security and user experience.
- **Fix:** Implement a `nonce` system and incorporate `block.chainid` in your signature scheme. Ensure adherence to EIP-712 for all signatures.

### SOL-Signature-2: Are signatures protected against malleability issues?
- **Risk:** Signature malleability can be exploited by attackers to produce valid signatures without the private key. Using outdated versions of libraries can introduce known vulnerabilities.
- **Fix:** Avoid using `ecrecover()` for signature verification. Instead, utilize the OpenZeppelin's latest version of ECDSA to ensure signatures are safe from malleability issues.

### SOL-Signature-3: Does the returned public key from the signature verification match the expected public key?
- **Risk:** Mismatched public keys can indicate an incorrect or malicious signer, potentially leading to unauthorized actions.
- **Fix:** Implement rigorous checks to ensure the public key derived from a signature matches the expected signer's public key.

### SOL-Signature-4: Is the signature originating from the appropriate entity?
- **Risk:** If signatures aren't properly checked, malicious actors might exploit them, leading to unauthorized transactions or actions.
- **Fix:** Ensure strict verification mechanisms are in place to confirm that signatures originate from the expected entities.

### SOL-Signature-5: If the signature has a deadline, is it still valid?
- **Risk:** Signatures with expiration dates that aren't checked can be reused maliciously after they should no longer be valid.
- **Fix:** Always check the expiration date of signatures and ensure they're not accepted past their valid period.
