# Low Level

Vulnerabilities inherent in low-level codebases, such as contracts crafted in Huff, bytecode, and sections of inline assembly code.

Total items: 5

## (general)

### SOL-LL-1: Is there validation on the size of the input data?
- **Risk:** In low-level, data size is not checked by default and it can affect the unintended memory locations.
- **Fix:** Validate that inputs do not exceed the size of it's expected type and either revert or clean the unused bits depending on your use case before using that value.
- **Refs:** 1 case(s)
  - https://github.com/AmadiMichael/LowLevelVulnerabilities?tab=readme-ov-file#validate-all-input-bit-size

### SOL-LL-2: What happens if there is no matching function signature?
- **Risk:** It is expected to revert if there is no matching function signature in the contract. Overlooking this can let the execution continue into other parts of the unintended bytecode.
- **Fix:** Ensure that the code reverts after comparing all supported function signatures, fallback etc and not matching any.
- **Refs:** 1 case(s)
  - https://github.com/AmadiMichael/LowLevelVulnerabilities?tab=readme-ov-file#end-execution-after-function-dispatching

### SOL-LL-3: Is it checked if the target address of a call has the code?
- **Risk:** Calling an address without code is always successful.
- **Fix:** Ensure that addresses being called, static-called or delegate-called have code deployed.
- **Refs:** 1 case(s)
  - https://github.com/AmadiMichael/LowLevelVulnerabilities?tab=readme-ov-file#ensure-that-addresses-being-called-static-called-or-delegate-called-have-code-deployed-to-them

### SOL-LL-4: Is there a check on the return data size when calling precompiled code?
- **Risk:** When calling precompiled code, the call is still successful on error or ”failure”. A failed precompile call simply has a return data size of 0.
- **Fix:** Check the return data size not the success of the call to determine if it failed.
- **Refs:** 1 case(s)
  - https://github.com/AmadiMichael/LowLevelVulnerabilities?tab=readme-ov-file#when-calling-precompiles-check-the-returndatasize-not-the-success-of-the-call-to-determine-if-it-failed

### SOL-LL-5: Is there a non-zero check for the denominator?
- **Risk:** At the evm level and in yul/inline assembly, when dividing or modulo'ing by 0, It does not revert with Panic(18) as solidity would do, its result 0. If this behavior is not desired it should be checked. Basically, x / 0 = 0 and x % 0 = 0.
- **Fix:** Check if the denominator is zero before division.
- **Refs:** 1 case(s)
  - https://github.com/AmadiMichael/LowLevelVulnerabilities?tab=readme-ov-file#when-dividing-or-moduloin-check-that-the-denominator-is-not-0
