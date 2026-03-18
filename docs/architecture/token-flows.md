# Token Flows

> GENERATED FROM q-tree.md — do not edit, regenerate from q-tree.

## Deposit (async epoch)

```mermaid
sequenceDiagram
    User->>Vault: requestDeposit(amount)
    Vault->>BaseToken: transferFrom(user, vault, amount)
    Note over Vault: funds idle in FIFO queue, no shares yet
    Keeper->>Vault: processDeposits(amount, calldata, swapRouter, flashLoanRouter)
    Vault->>Strategy: deposit(amount, calldata, swapRouter, flashLoanRouter)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    FlashLoanRouter->>FlashProvider: flash borrow baseToken
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, 0, data)
    Strategy->>DEX: swap baseToken -> YBT (via calldata)
    DEX-->>Strategy: YBT
    Strategy->>LendingProtocol: supply(YBT as collateral)
    Strategy->>LendingProtocol: borrow(baseToken)
    LendingProtocol-->>Strategy: baseToken (borrowed)
    Strategy->>FlashLoanRouter: repay flash loan (zero fee)
    Note over Strategy: POST: post-leverage LTV <= maxLTV
    Vault-->>Users: mint shares (delta NAV, round down)
```

baseToken: User -> Vault (idle) -> Strategy -> DEX (swap to YBT) -> LendingProtocol (collateral). LendingProtocol -> Strategy (borrow baseToken) -> FlashLoanRouter (repay). Keeper specifies amount in base token; contract iterates FIFO from head, filling requests until amount exhausted. Last request may be partially filled. FlashLoanRouter validated against Factory registry.

## Async Redeem (keeper epoch)

```mermaid
sequenceDiagram
    User->>Vault: requestRedeem(shares)
    Vault->>Vault: escrow shares (transfer to vault)
    Keeper->>Vault: processRedeems(shares, calldata, swapRouter, flashLoanRouter)
    Vault->>Strategy: redeem(fraction, calldata, swapRouter, flashLoanRouter)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, 0, data)
    Strategy->>LendingProtocol: repay(proportional debt)
    Strategy->>LendingProtocol: withdraw(proportional collateral)
    LendingProtocol-->>Strategy: YBT
    Strategy->>DEX: swap YBT -> baseToken (via calldata)
    DEX-->>Strategy: baseToken
    Strategy->>FlashLoanRouter: repay flash loan
    Strategy-->>Vault: remaining baseToken
    Vault->>Vault: burn escrowed shares
    Vault-->>Users: distribute baseToken pro-rata
```

LendingProtocol -> Strategy (withdraw YBT collateral) -> DEX (swap to baseToken) -> Vault -> Users. Keeper specifies shares to unwind; contract iterates FIFO from head consuming requests until shares exhausted. FlashLoanRouter provided by keeper per-call, validated against Factory registry.

## Sync Permissionless Redeem

```mermaid
sequenceDiagram
    User->>Vault: syncRedeem(shares, calldata, swapRouter, flashLoanRouter)
    Vault->>Vault: burn shares from user wallet
    Vault->>Strategy: syncRedeem(fraction, calldata, swapRouter, flashLoanRouter)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, 0, data)
    Strategy->>LendingProtocol: repay(pro-rata debt)
    Strategy->>LendingProtocol: withdraw(pro-rata collateral)
    LendingProtocol-->>Strategy: YBT
    Strategy->>DEX: swap YBT -> baseToken (via user calldata)
    DEX-->>Strategy: baseToken
    Strategy->>FlashLoanRouter: repay flash loan
    Strategy-->>Vault: remaining baseToken
    Vault-->>User: transfer baseToken
```

Same as async redeem but user-initiated with user-provided calldata. Vault computes fraction = shares * 1e18 / totalSupply. User pays gas + slippage. Always available even when paused. User provides flashLoanRouter, validated against Factory registry.

## Sync Redeem (Idle Mode)

```mermaid
sequenceDiagram
    User->>Vault: syncRedeem(shares, emptyCalldata, address(0), address(0))
    Vault->>Vault: burn shares
    Vault-->>User: shares/totalSupply * idleBase
```

When position is fully unwound (zero collateral, zero debt), skip flash loan, return pro-rata idle base.

## Migration (cross-strategy)

```mermaid
sequenceDiagram
    User->>MigrationRouter: migrate(srcVault, dstVault, shares, flashLoanRouter, swapCalldata, swapRouter)
    MigrationRouter->>MigrationRouter: flashAmount = shares/totalSupply * actualDebt (after _forceAccrue)
    MigrationRouter->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>MigrationRouter: onFlashLoan(token, amount, 0, data)
    MigrationRouter->>StrategyA: transfer baseToken (for debt repayment)
    MigrationRouter->>VaultA: redeemCustom(user, shares)
    VaultA->>StrategyA: redeemCustom(fraction)
    StrategyA->>LendingA: repay debt (using transferred baseToken)
    StrategyA->>LendingA: withdraw collateral (YBT-A)
    StrategyA-->>MigrationRouter: YBT-A
    VaultA->>VaultA: burn user shares
    MigrationRouter->>DEX: swap YBT-A -> YBT-B (if different, via swapCalldata)
    DEX-->>MigrationRouter: YBT-B
    MigrationRouter->>StrategyB: transfer YBT-B (collateral for deposit)
    MigrationRouter->>VaultB: depositCustom(user, collateralAmount, flashAmount)
    VaultB->>StrategyB: depositCustom(collateralAmount, flashAmount)
    StrategyB->>LendingB: supply(YBT-B as collateral)
    StrategyB->>LendingB: borrow(baseToken, flashAmount)
    LendingB-->>StrategyB: baseToken
    StrategyB-->>MigrationRouter: baseToken (debt back to caller)
    VaultB->>VaultB: mint shares to user (delta NAV)
    MigrationRouter->>FlashLoanRouter: repay flash loan
```

Source: MigrationRouter transfers baseToken to Strategy before redeemCustom. Shares burned, collateral withdrawn, debt repaid. Destination: collateral supplied, debt borrowed (debtAmount = flashAmount), shares minted. Flash loan bridges the debt repayment. MigrationRouter calls FlashLoanRouter directly (not via Strategy). debtAmount passed to depositCustom is the flash loan amount. Caller provides flashLoanRouter, validated against Factory registry.

## Cancel Pending Deposit

```mermaid
sequenceDiagram
    User->>Vault: cancelDeposit(requestId)
    Vault-->>User: transfer baseToken back (unfilled portion)
```

baseToken: Vault -> User. No shares were ever minted for the unfilled portion. Cancel is the only mechanism for unprocessed requests — no reclaim, no timeout.

## Cancel Pending Redeem

```mermaid
sequenceDiagram
    User->>Vault: cancelRedeem(requestId)
    Vault-->>User: transfer escrowed shares back (unfilled portion)
```

Escrowed shares: Vault -> User. Cancel is the only mechanism for unprocessed requests — no reclaim, no timeout.

## Emergency Redeem

```mermaid
sequenceDiagram
    Keeper/Guardian->>Strategy: emergencyRedeem(swapCalldata, swapRouter, flashLoanRouter)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, totalDebt, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, 0, data)
    Strategy->>LendingProtocol: repay(all debt)
    Strategy->>LendingProtocol: withdraw(all collateral)
    LendingProtocol-->>Strategy: all YBT
    Strategy->>DEX: swap all YBT -> baseToken
    DEX-->>Strategy: baseToken
    Strategy->>FlashLoanRouter: repay flash loan (zero fee)
    Strategy-->>Strategy: remaining baseToken held as idle
```

Full position unwind to idle base. Keeper or guardian calls Strategy.emergencyRedeem() directly (not through Vault). Uses fraction = 1e18 (full position). After this, users exit via sync redeem idle mode. FlashLoanRouter provided per-call, validated against Factory registry by Strategy.
