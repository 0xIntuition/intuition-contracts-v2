# Centralization Risk



Total items: 7

## (general)

### SOL-CR-1: What happens to the user accounting in special conditions?
- **Risk:** Users must be allowed to manage their existing positions in all protocol status. For example, users must be able to repay the debt even when the protocol is paused or the protocol should not accrue debts when it is paused.
- **Fix:** Ensure user positions are protected in special/emergent protocol situations.

### SOL-CR-2: Is there a pause mechanism?
- **Risk:** Some functionalities must work even when the whole protocol is paused. For example, users must be able to withdraw (or repay) assets even while the protocol is paused.
- **Fix:** Review the pause mechanism thoroughly to ensure that it only affects intended functions and can't be abused by a malicious operator.

### SOL-CR-3: Is there a functionality for the admin to withdraw from the protocol?
- **Risk:** Some protocols are written to allow admin pull any amount of assets from the pool. This is a red flag and MUST be disallowed. The best practice is to track the protocol fee and only allow access to that amount.
- **Fix:** Ensure the admin can not steal user funds. Track the protocol earning separately.

### SOL-CR-4: Can the admin change critical protocol property immediately?
- **Risk:** Changes in the critical protocol properties MUST go through a cooling period to allow users react on the changes.
- **Fix:** Implement a timelock for the critical property changes and emit proper events.

### SOL-CR-5: Is there any admin setter function missing events?
- **Risk:** Events are often used to monitor the protocol status. Without emission of events, users might be affected due to ignorance of the changes.
- **Fix:** Emit proper events on critical configuration changes.

### SOL-CR-6: How is the ownership/privilege transferred??
- **Risk:** Critical privileges MUST be transferred via a two-step process and the protocol MUST behave as expected before/during/after transfer.
- **Fix:** Use two-step process for transferring critical privileges and ensure the protocol works properly before/during/after the transfer.

### SOL-CR-7: Is there a proper validation in privileged setter functions?
- **Risk:** The validation on the protocol configuration values is often overlooked assuming the admin is trusted. But it is always recommended clarifying the range of each configuration value and validate in setter functions. (e.g. protocol fee should be limited)
- **Fix:** Ensure the protocol level properties are properly validated in the documented range.
