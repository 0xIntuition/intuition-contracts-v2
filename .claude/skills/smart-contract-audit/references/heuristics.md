# Heuristics



Total items: 17

## (general)

### SOL-Heuristics-1: Is there any logic implemented multiple times?
- **Risk:** Inconsistent implementations of the same logic can introduce errors or vulnerabilities.
- **Fix:** Standardize the logic and make it as a separate function.

### SOL-Heuristics-2: Does the contract use any nested structures?
- **Risk:** If a variable of nested structure is deleted, only the top-level fields are reset by default values (zero) and the nested level fields are not reset.
- **Fix:** Always ensure that inner fields are deleted before the outer fields of the structure.

### SOL-Heuristics-3: Is there any unexpected behavior when `src==dst` (or `caller==receiver`)?
- **Risk:** Overlooking the possibility of a sender and a recipient (source and destination) being the same in smart contracts can lead to unintended problems.
- **Fix:** Ensure the protocol behaves as expected when `src==dst`.

### SOL-Heuristics-4: Is the NonReentrant modifier placed before every other modifier?
- **Risk:** The order of modifiers can influence the behavior of a function. Generally,  NonReentrant must come first than other modifiers.
- **Fix:** Reorder modifiers so that NonReentrant is placed before other modifiers.

### SOL-Heuristics-5: Does the `try/catch` block account for potential gas shortages?
- **Risk:** A `try/catch` block without adequate gas can fail, leading to unexpected behaviors.
- **Fix:** Ensure sufficient gas is supplied when using the `try/catch` block.
- **Refs:** 1 case(s)
  - https://forum.openzeppelin.com/t/a-brief-analysis-of-the-new-try-catch-functionality-in-solidity-0-6/2564

### SOL-Heuristics-6: Did you check the relevant EIP recommendations and security concerns?
- **Risk:** Incomplete or incorrect implementation of EIP recommendations can lead to vulnerabilities.
- **Fix:** Read the recommendations and security concerns and ensure all are implemented as per the official recommendations.

### SOL-Heuristics-7: Are there any off-by-one errors?
- **Risk:** Off-by-one errors are not rare. Is `<=` correct in this context or should `<` be used? Should a variable be set to the length of a list or the length - 1? Should an iteration start at 1 or 0?
- **Fix:** Review all usages of comparison operators for correctness.

### SOL-Heuristics-8: Are logical operators used correctly?
- **Risk:** Logical operators like `==`, `!=`, `&&`, `||`, `!` can be overlooked especially when the test coverage is not good.
- **Fix:** Review all usages of logical operators for correctness.

### SOL-Heuristics-9: What happens if the protocol's contracts are inputted as if they are normal actors?
- **Risk:** Supplying unexpected addresses can lead to unintended behaviors, especially if the address points to another contract inside the same protocol.
- **Fix:** Implement checks to validate receiver addresses and ensure the protocol behaves as expected.

### SOL-Heuristics-10: Are there rounding errors that can be amplified?
- **Risk:** While minor rounding errors can be inevitable in certain operations, they can pose significant issues if they can be magnified. Amplification can occur when a function is invoked multiple times strategically or under specific conditions.
- **Fix:** Conduct thorough tests to identify and understand potential rounding errors. Ensure that they cannot be amplified to a level that would be detrimental to the system or its users. In cases where significant rounding errors are detected, the implementation should be revised to minimize or eliminate them.
- **Refs:** 1 case(s)
  - https://github.com/OpenCoreCH/smart-contract-audits/blob/main/reports/c4/rigor.md#high-significant-rounding-errors-for-interest-calculation

### SOL-Heuristics-11: Is there any uninitialized state?
- **Risk:** Checking a variable against its default value might be used to detect initialization. If such defaults can also be valid state, it could lead to vulnerabilities.
- **Fix:** Avoid solely relying on default values to determine initialization status.

### SOL-Heuristics-12: Can functions be invoked multiple times with identical parameters?
- **Risk:** Functions that should be unique per parameters set might be callable multiple times, leading to potential issues.
- **Fix:** Ensure functions have measures to prevent repeated calls with identical or similar parameters, especially when these calls can produce adverse effects.

### SOL-Heuristics-13: Is the global state updated correctly?
- **Risk:** While working with a `memory` copy for optimization, developers might overlook updating the global state.
- **Fix:** Always ensure the global state mirrors changes made in `memory`. Consider tools or extensions that can highlight discrepancies.

### SOL-Heuristics-14: Is ETH/WETH handling implemented correctly?
- **Risk:** Contracts might have special logic for ETH, like wrapping to WETH. Assuming exclusivity between handling ETH and WETH without checks can introduce errors.
- **Fix:** Clearly differentiate the logic between ETH and WETH handling, ensuring no overlap or mutual exclusivity assumptions without validation.

### SOL-Heuristics-15: Does the protocol put any sensitive data on the blockchain?
- **Risk:** Data on the blockchain, including that marked 'private' in smart contracts, is visible to anyone who knows how to query the blockchain's state or analyze its transaction history. Private variables are not exempt from public inspection.
- **Fix:** Sensitive data should either be kept off-chain or encrypted before being stored on-chain. It's important to manage encryption keys securely and ensure that on-chain data does not expose private information even when encrypted, if the encryption method is weak or the keys are mishandled.

### SOL-Heuristics-16: Are there any code asymmetries?
- **Risk:** In many projects, there should be some symmetries for different functions. For instance, a `withdraw` function should (usually) undo all the state changes of a `deposit` function and a `delete` function should undo all the state changes of the corresponding `add` function. Asymmetries in these function pairs (e.g., forgetting to unset a field or to subtract from a value) can often lead to undesired behavior. Sometimes one side of a 'pair' is missing, like missing removing from a whitelist while there is a function to add to a whitelist.
- **Fix:** Review paired functions for symmetry and ensure they counteract each other's state changes appropriately.
- **Refs:** 1 case(s)
  - https://github.com/OpenCoreCH/smart-contract-auditing-heuristics#code-asymmetries

### SOL-Heuristics-17: Does calling a function multiple times with smaller amounts yield the same contract state as calling it once with the aggregate amount?
- **Risk:** Associative properties of certain financial operations suggest that performing the operation multiple times with smaller amounts should yield an equivalent outcome as performing it once with the aggregate amount. Variations might be indicative of potential issues such as rounding errors, unintended fee accumulations, or other inconsistencies.
- **Fix:** Implement tests to validate consistency. Where discrepancies exist, ensure they are intentional, minimal, and well-documented. If discrepancies are unintended, reevaluate the implementation to ensure precision and correctness.
