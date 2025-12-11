# Error Handling

Comprehensive guide to handling errors in Intuition Protocol V2 integrations.

## Table of Contents

- [Overview](#overview)
- [Error Types](#error-types)
- [Contract Errors](#contract-errors)
- [Error Detection](#error-detection)
- [Error Recovery](#error-recovery)
- [User-Friendly Messages](#user-friendly-messages)
- [Logging and Monitoring](#logging-and-monitoring)

## Overview

Robust error handling is critical for providing a good user experience. This guide covers:

- Understanding different error types
- Detecting and parsing contract errors
- Implementing recovery strategies
- Providing meaningful feedback to users

**Error Handling Principles**:
1. Catch errors early (validate before submitting)
2. Provide specific, actionable error messages
3. Implement automatic recovery where possible
4. Log errors for debugging and monitoring
5. Never expose raw error messages to end users

## Error Types

### RPC Errors

Errors from the RPC provider:

```typescript
class RPCError extends Error {
  constructor(
    message: string,
    public code: number,
    public data?: any
  ) {
    super(message);
    this.name = 'RPCError';
  }
}

// Common RPC error codes
const RPC_ERROR_CODES = {
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL_ERROR: -32603,
  RATE_LIMIT: 429,
  TIMEOUT: -32000,
};

function handleRPCError(error: any): never {
  if (error.code === RPC_ERROR_CODES.RATE_LIMIT) {
    throw new Error('Rate limit exceeded. Please try again in a moment.');
  }

  if (error.code === RPC_ERROR_CODES.TIMEOUT) {
    throw new Error('Request timed out. Please check your connection.');
  }

  throw new RPCError(error.message, error.code, error.data);
}
```

### Network Errors

Connection and network-related errors:

```typescript
class NetworkError extends Error {
  constructor(message: string, public originalError?: any) {
    super(message);
    this.name = 'NetworkError';
  }
}

async function fetchWithRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3
): Promise<T> {
  let lastError: Error;

  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error: any) {
      lastError = error;

      if (isNetworkError(error)) {
        const delay = Math.pow(2, i) * 1000;
        console.log(`Network error, retrying in ${delay}ms...`);
        await sleep(delay);
        continue;
      }

      throw error;
    }
  }

  throw new NetworkError('Network request failed after retries', lastError!);
}

function isNetworkError(error: any): boolean {
  return (
    error.code === 'NETWORK_ERROR' ||
    error.code === 'TIMEOUT' ||
    error.message.includes('network') ||
    error.message.includes('connection')
  );
}
```

### Validation Errors

Input validation failures:

```typescript
class ValidationError extends Error {
  constructor(
    message: string,
    public field: string,
    public value: any
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

function validateDepositParams(
  termId: string,
  curveId: number,
  assets: bigint
): void {
  if (!termId || !ethers.isHexString(termId, 32)) {
    throw new ValidationError(
      'Invalid term ID format',
      'termId',
      termId
    );
  }

  if (curveId < 0) {
    throw new ValidationError(
      'Curve ID must be non-negative',
      'curveId',
      curveId
    );
  }

  if (assets <= 0n) {
    throw new ValidationError(
      'Deposit amount must be greater than zero',
      'assets',
      assets.toString()
    );
  }
}
```

### Transaction Errors

Transaction execution failures:

```typescript
class TransactionError extends Error {
  constructor(
    message: string,
    public txHash?: string,
    public reason?: string
  ) {
    super(message);
    this.name = 'TransactionError';
  }
}

class InsufficientGasError extends TransactionError {
  constructor(required: bigint, provided: bigint) {
    super(
      `Insufficient gas: required ${required}, provided ${provided}`,
      undefined,
      'INSUFFICIENT_GAS'
    );
  }
}

class TransactionRevertedError extends TransactionError {
  constructor(reason: string, txHash: string) {
    super(`Transaction reverted: ${reason}`, txHash, reason);
  }
}
```

## Contract Errors

### MultiVault Errors

```typescript
// Extract from IMultiVault interface
const MULTIVAULT_ERRORS = {
  // General errors
  MultiVault_ZeroAddress: 'Invalid address: cannot be zero address',
  MultiVault_Paused: 'Protocol is currently paused',
  MultiVault_InvalidCurveId: 'Bonding curve ID is invalid',

  // Atom/Triple creation errors
  MultiVault_AtomAlreadyExists: 'Atom already exists',
  MultiVault_TripleAlreadyExists: 'Triple already exists',
  MultiVault_AtomNotFound: 'Atom does not exist',
  MultiVault_InvalidAtomData: 'Atom data exceeds maximum length',

  // Deposit errors
  MultiVault_InsufficientAssets: 'Insufficient assets for deposit',
  MultiVault_MinSharesError: 'Shares minted below minimum threshold',
  MultiVault_VaultNotFound: 'Vault does not exist',

  // Redemption errors
  MultiVault_InsufficientShares: 'Insufficient shares for redemption',
  MultiVault_MinAssetsError: 'Assets received below minimum threshold',
  MultiVault_NoSharesToBurn: 'No shares available to burn',

  // Fee errors
  MultiVault_InvalidFeeAmount: 'Fee amount exceeds maximum allowed',
};

function parseMultiVaultError(error: any): string {
  const errorName = extractErrorName(error);

  if (errorName && MULTIVAULT_ERRORS[errorName]) {
    return MULTIVAULT_ERRORS[errorName];
  }

  return error.message || 'Unknown MultiVault error';
}

function extractErrorName(error: any): string | null {
  try {
    if (error.data) {
      const iface = new ethers.Interface(MULTIVAULT_ABI);
      const decoded = iface.parseError(error.data);
      return decoded?.name || null;
    }
  } catch {
    // Failed to decode
  }

  // Try to extract from error message
  const match = error.message.match(/error (\w+)/);
  return match ? match[1] : null;
}
```

### TrustBonding Errors

```typescript
const TRUST_BONDING_ERRORS = {
  TrustBonding_InvalidEpoch: 'Invalid epoch number',
  TrustBonding_NoRewardsToClaim: 'No rewards available to claim',
  TrustBonding_RewardsAlreadyClaimedForEpoch: 'Rewards already claimed for this epoch',
  TrustBonding_NoClaimingDuringFirstEpoch: 'Cannot claim rewards during the first epoch',
  TrustBonding_InvalidUtilizationLowerBound: 'Utilization lower bound is invalid',
  TrustBonding_OnlyTimelock: 'Only timelock can call this function',
};

function parseTrustBondingError(error: any): string {
  const errorName = extractErrorName(error);

  if (errorName && TRUST_BONDING_ERRORS[errorName]) {
    return TRUST_BONDING_ERRORS[errorName];
  }

  return error.message || 'Unknown TrustBonding error';
}
```

### ERC20 Errors

```typescript
const ERC20_ERRORS = {
  'ERC20: insufficient allowance': 'Please approve the contract to spend your TRUST tokens',
  'ERC20: transfer amount exceeds balance': 'Insufficient TRUST balance',
  'ERC20: transfer to the zero address': 'Invalid recipient address',
};

function parseERC20Error(error: any): string {
  for (const [pattern, message] of Object.entries(ERC20_ERRORS)) {
    if (error.message.includes(pattern)) {
      return message;
    }
  }

  return 'Token transfer failed';
}
```

## Error Detection

### Pre-Transaction Validation

Catch errors before submitting transactions:

```typescript
async function validateDeposit(
  termId: string,
  curveId: number,
  assets: bigint,
  minShares: bigint
): Promise<void> {
  // 1. Validate inputs
  validateDepositParams(termId, curveId, assets);

  // 2. Check term exists
  const exists = await multiVault.isTermCreated(termId);
  if (!exists) {
    throw new ValidationError(
      'Term does not exist. Please create it first.',
      'termId',
      termId
    );
  }

  // 3. Check user balance
  const userAddress = await signer.getAddress();
  const balance = await trustToken.balanceOf(userAddress);

  if (balance < assets) {
    throw new InsufficientBalanceError(
      `Insufficient TRUST balance. Have: ${formatEther(balance)}, Need: ${formatEther(assets)}`,
      assets,
      balance
    );
  }

  // 4. Check allowance
  const allowance = await trustToken.allowance(userAddress, multiVault.address);

  if (allowance < assets) {
    throw new InsufficientAllowanceError(
      `Please approve ${multiVault.address} to spend ${formatEther(assets)} TRUST`,
      assets,
      allowance
    );
  }

  // 5. Simulate transaction
  try {
    await multiVault.deposit.staticCall(
      userAddress,
      termId,
      curveId,
      assets,
      minShares
    );
  } catch (error: any) {
    throw new TransactionError(
      `Transaction would fail: ${parseMultiVaultError(error)}`,
      undefined,
      parseMultiVaultError(error)
    );
  }
}

class InsufficientBalanceError extends Error {
  constructor(
    message: string,
    public required: bigint,
    public available: bigint
  ) {
    super(message);
    this.name = 'InsufficientBalanceError';
  }
}

class InsufficientAllowanceError extends Error {
  constructor(
    message: string,
    public required: bigint,
    public available: bigint
  ) {
    super(message);
    this.name = 'InsufficientAllowanceError';
  }
}
```

### Transaction Receipt Analysis

Detect failures from transaction receipts:

```typescript
async function analyzeTransactionReceipt(
  receipt: ethers.TransactionReceipt
): Promise<void> {
  if (!receipt) {
    throw new TransactionError('Transaction receipt not found');
  }

  if (receipt.status === 0) {
    // Transaction failed, try to get revert reason
    const reason = await getRevertReason(receipt.hash);
    throw new TransactionRevertedError(reason, receipt.hash);
  }

  // Check for expected events
  const events = parseEvents(receipt);

  if (events.length === 0) {
    console.warn('Warning: No events emitted by transaction');
  }
}

async function getRevertReason(txHash: string): Promise<string> {
  try {
    const tx = await provider.getTransaction(txHash);
    const code = await provider.call(tx!, tx!.blockNumber);

    // Decode revert reason
    const reason = ethers.toUtf8String('0x' + code.slice(138));
    return reason;
  } catch (error) {
    return 'Unknown revert reason';
  }
}
```

## Error Recovery

### Automatic Approval

Automatically request approval when needed:

```typescript
async function depositWithAutoApproval(
  termId: string,
  curveId: number,
  assets: bigint,
  minShares: bigint
): Promise<TransactionResult> {
  try {
    // Try deposit
    return await deposit(termId, curveId, assets, minShares);
  } catch (error: any) {
    if (error instanceof InsufficientAllowanceError) {
      console.log('Insufficient allowance, requesting approval...');

      // Request approval
      const approveTx = await trustToken.approve(
        multiVault.address,
        ethers.MaxUint256
      );
      await approveTx.wait();

      console.log('Approval granted, retrying deposit...');

      // Retry deposit
      return await deposit(termId, curveId, assets, minShares);
    }

    throw error;
  }
}
```

### Slippage Adjustment

Automatically adjust slippage on failure:

```typescript
async function depositWithSlippageRetry(
  termId: string,
  curveId: number,
  assets: bigint,
  initialSlippage: number = 50 // 0.5%
): Promise<TransactionResult> {
  let slippage = initialSlippage;

  while (slippage <= 500) { // Max 5% slippage
    try {
      const [expectedShares] = await multiVault.previewDeposit(
        termId,
        curveId,
        assets
      );

      const minShares = (expectedShares * BigInt(10000 - slippage)) / 10000n;

      return await deposit(termId, curveId, assets, minShares);
    } catch (error: any) {
      if (error.message.includes('MinSharesError')) {
        slippage += 50; // Increase by 0.5%
        console.log(`Slippage too low, retrying with ${slippage / 100}%...`);
        continue;
      }

      throw error;
    }
  }

  throw new Error('Transaction failed even with maximum slippage tolerance');
}
```

### Gas Price Adjustment

Retry with higher gas price:

```typescript
async function executeWithGasRetry(
  fn: () => Promise<ethers.TransactionResponse>,
  maxRetries: number = 3
): Promise<ethers.TransactionResponse> {
  let gasMultiplier = 1.0;

  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error: any) {
      if (error.code === 'REPLACEMENT_UNDERPRICED') {
        gasMultiplier += 0.2; // Increase by 20%
        console.log(`Increasing gas price by ${(gasMultiplier - 1) * 100}%...`);
        continue;
      }

      throw error;
    }
  }

  throw new Error('Transaction failed after gas price adjustments');
}
```

## User-Friendly Messages

### Error Message Mapping

Convert technical errors to user-friendly messages:

```typescript
interface ErrorContext {
  operation: string;
  termId?: string;
  amount?: bigint;
  userAddress?: string;
}

function getUserFriendlyMessage(error: any, context: ErrorContext): string {
  // Insufficient balance
  if (error instanceof InsufficientBalanceError) {
    return `You need ${formatEther(error.required)} TRUST, but only have ${formatEther(error.available)}. Please add more TRUST to your wallet.`;
  }

  // Insufficient allowance
  if (error instanceof InsufficientAllowanceError) {
    return `Please approve the Intuition Protocol to spend your TRUST tokens. Click "Approve" to continue.`;
  }

  // Slippage error
  if (error.message.includes('MinSharesError')) {
    return `The price moved unfavorably. Please try again with a higher slippage tolerance.`;
  }

  // Atom already exists
  if (error.message.includes('AtomAlreadyExists')) {
    return `This atom already exists. You can deposit into it instead.`;
  }

  // Atom not found
  if (error.message.includes('AtomNotFound')) {
    return `The atom you're trying to interact with doesn't exist. Please verify the atom ID.`;
  }

  // Triple already exists
  if (error.message.includes('TripleAlreadyExists')) {
    return `This relationship already exists. You can deposit into it instead.`;
  }

  // No rewards
  if (error.message.includes('NoRewardsToClaim')) {
    return `You don't have any rewards available to claim right now. Keep using the protocol to earn rewards!`;
  }

  // Already claimed
  if (error.message.includes('RewardsAlreadyClaimed')) {
    return `You've already claimed rewards for this period. Check back next epoch!`;
  }

  // Protocol paused
  if (error.message.includes('Paused')) {
    return `The protocol is temporarily paused. Please try again later.`;
  }

  // Network errors
  if (error instanceof NetworkError) {
    return `Connection issue detected. Please check your internet and try again.`;
  }

  // RPC errors
  if (error instanceof RPCError && error.code === 429) {
    return `Too many requests. Please wait a moment and try again.`;
  }

  // Generic transaction failure
  if (error instanceof TransactionRevertedError) {
    return `Transaction failed: ${error.reason}. Please try again or contact support.`;
  }

  // Fallback
  return `An unexpected error occurred during ${context.operation}. Please try again or contact support.`;
}
```

### Error UI Components

React component for displaying errors:

```typescript
interface ErrorDisplayProps {
  error: Error;
  context: ErrorContext;
  onRetry?: () => void;
  onDismiss?: () => void;
}

function ErrorDisplay({ error, context, onRetry, onDismiss }: ErrorDisplayProps) {
  const message = getUserFriendlyMessage(error, context);

  const canRetry =
    error instanceof NetworkError ||
    error.message.includes('MinSharesError') ||
    error instanceof RPCError;

  const needsApproval = error instanceof InsufficientAllowanceError;

  return (
    <div className="error-display">
      <div className="error-icon">⚠️</div>
      <div className="error-message">{message}</div>
      <div className="error-actions">
        {needsApproval && (
          <button onClick={handleApproval}>
            Approve TRUST
          </button>
        )}
        {canRetry && onRetry && (
          <button onClick={onRetry}>
            Try Again
          </button>
        )}
        {onDismiss && (
          <button onClick={onDismiss}>
            Dismiss
          </button>
        )}
      </div>
    </div>
  );
}
```

## Logging and Monitoring

### Structured Error Logging

```typescript
interface ErrorLog {
  timestamp: string;
  level: 'error' | 'warn' | 'info';
  error: {
    name: string;
    message: string;
    stack?: string;
  };
  context: {
    operation: string;
    user?: string;
    termId?: string;
    amount?: string;
  };
  metadata: {
    txHash?: string;
    blockNumber?: number;
    gasUsed?: string;
  };
}

class ErrorLogger {
  private logs: ErrorLog[] = [];

  log(
    error: Error,
    context: ErrorContext,
    metadata: Record<string, any> = {}
  ): void {
    const log: ErrorLog = {
      timestamp: new Date().toISOString(),
      level: this.getLogLevel(error),
      error: {
        name: error.name,
        message: error.message,
        stack: error.stack,
      },
      context: {
        operation: context.operation,
        user: context.userAddress,
        termId: context.termId,
        amount: context.amount?.toString(),
      },
      metadata,
    };

    this.logs.push(log);

    // Send to monitoring service
    this.sendToMonitoring(log);

    // Console output in development
    if (process.env.NODE_ENV === 'development') {
      console.error('[Error]', log);
    }
  }

  private getLogLevel(error: Error): 'error' | 'warn' | 'info' {
    if (error instanceof ValidationError) return 'warn';
    if (error instanceof NetworkError) return 'warn';
    return 'error';
  }

  private async sendToMonitoring(log: ErrorLog): Promise<void> {
    // Send to Sentry, DataDog, or other monitoring service
    // Implementation depends on your monitoring setup
  }

  getLogs(filter?: (log: ErrorLog) => boolean): ErrorLog[] {
    return filter ? this.logs.filter(filter) : this.logs;
  }
}

// Global error logger
const errorLogger = new ErrorLogger();

// Usage
try {
  await deposit(termId, curveId, assets, minShares);
} catch (error: any) {
  errorLogger.log(
    error,
    {
      operation: 'deposit',
      termId,
      amount: assets,
      userAddress: await signer.getAddress(),
    },
    {
      curveId,
      minShares: minShares.toString(),
    }
  );

  throw error;
}
```

### Error Metrics

Track error rates and types:

```typescript
class ErrorMetrics {
  private counts = new Map<string, number>();

  increment(errorType: string): void {
    const current = this.counts.get(errorType) || 0;
    this.counts.set(errorType, current + 1);
  }

  getMetrics(): Record<string, number> {
    return Object.fromEntries(this.counts);
  }

  reset(): void {
    this.counts.clear();
  }
}

const errorMetrics = new ErrorMetrics();

// Track errors
try {
  await deposit(termId, curveId, assets, minShares);
} catch (error: any) {
  errorMetrics.increment(error.name);
  throw error;
}

// Periodically report metrics
setInterval(() => {
  const metrics = errorMetrics.getMetrics();
  console.log('Error metrics:', metrics);
  // Send to analytics service
}, 60000); // Every minute
```

## Best Practices

1. **Validate Early**: Check inputs and preconditions before submitting transactions
2. **Specific Errors**: Use specific error types instead of generic Error
3. **User-Friendly**: Translate technical errors to actionable messages
4. **Retry Logic**: Implement automatic retries for transient errors
5. **Logging**: Log all errors with context for debugging
6. **Monitoring**: Track error rates and patterns
7. **Recovery**: Provide automated recovery where possible (e.g., auto-approval)
8. **Testing**: Test error paths thoroughly

## See Also

- [Transaction Flows](./transaction-flows.md) - Transaction execution patterns
- [SDK Design Patterns](./sdk-design-patterns.md) - SDK architecture
- [Reference: Errors](../reference/errors.md) - Complete error catalog
