# Token Flows

## Deposit (async epoch)

```mermaid
sequenceDiagram
    User->>Vault: requestDeposit(amount)
    Vault->>BaseToken: transferFrom(user, vault, amount)
    Note over Vault: funds idle, no shares yet
    Keeper->>Vault: processDepositEpoch(calldata, router)
    Vault->>Strategy: leverage(baseAmount, calldata, router)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    FlashLoanRouter->>FlashProvider: flash borrow baseToken
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
    Strategy->>DEX: swap baseToken -> YBT (via calldata)
    DEX-->>Strategy: YBT
    Strategy->>LendingProtocol: supply(YBT as collateral)
    Strategy->>LendingProtocol: borrow(baseToken)
    LendingProtocol-->>Strategy: baseToken (borrowed)
    Strategy->>FlashLoanRouter: repay flash loan + fee
    Vault-->>Users: mint shares (delta NAV)
```

baseToken: User -> Vault (idle) -> Strategy -> DEX (swap to YBT) -> LendingProtocol (collateral). LendingProtocol -> Strategy (borrow baseToken) -> FlashLoanRouter (repay).

## Async Withdrawal (keeper epoch)

```mermaid
sequenceDiagram
    User->>Vault: requestWithdrawal(shares)
    Vault->>Vault: escrow shares (transfer to vault)
    Keeper->>Vault: processWithdrawalEpoch(calldata, router)
    Vault->>Strategy: unwind(shares, totalSupply, calldata, router)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
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

LendingProtocol -> Strategy (withdraw YBT collateral) -> DEX (swap to baseToken) -> Vault -> Users.

## Sync Permissionless Redeem

```mermaid
sequenceDiagram
    User->>Vault: syncRedeem(shares, calldata, router)
    Vault->>Vault: burn shares from user wallet
    Vault->>Strategy: unwind(shares, totalSupply, calldata, router)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
    Strategy->>LendingProtocol: repay(pro-rata debt)
    Strategy->>LendingProtocol: withdraw(pro-rata collateral)
    LendingProtocol-->>Strategy: YBT
    Strategy->>DEX: swap YBT -> baseToken (via user calldata)
    DEX-->>Strategy: baseToken
    Strategy->>FlashLoanRouter: repay flash loan
    Strategy-->>Vault: remaining baseToken
    Vault-->>User: transfer baseToken
```

Same as async withdrawal but user-initiated with user-provided calldata. User pays gas + slippage. Always available even when paused.

## Sync Redeem (Idle Mode)

```mermaid
sequenceDiagram
    User->>Vault: syncRedeem(shares, emptyCalldata, address(0))
    Vault->>Vault: burn shares
    Vault-->>User: shares/totalSupply * idleBase
```

When position is fully unwound (zero collateral, zero debt), skip flash loan, return pro-rata idle base.

## Migration (cross-strategy)

```mermaid
sequenceDiagram
    User->>MigrationRouter: migrate(srcVault, dstVault, shares, flRouter, convCalldata, convRouter)
    MigrationRouter->>MigrationRouter: flashAmount = shares/totalSupply * srcStrategy.trackedDebt
    MigrationRouter->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>MigrationRouter: onFlashLoan(token, amount, fee, data)
    MigrationRouter->>VaultA: withdrawCustom(user, shares)
    VaultA->>StrategyA: repayAndWithdraw(shares, totalSupply)
    StrategyA->>LendingA: repay debt (from flash loan baseToken)
    StrategyA->>LendingA: withdraw collateral (YBT-A)
    StrategyA-->>VaultA: YBT-A
    VaultA-->>MigrationRouter: YBT-A + burns shares
    MigrationRouter->>DEX: swap YBT-A -> YBT-B (if different, via convCalldata)
    DEX-->>MigrationRouter: YBT-B
    MigrationRouter->>VaultB: depositCustom(user, collateralAmount, debtAmount)
    VaultB->>StrategyB: supplyAndBorrow(collateralAmount, debtAmount)
    StrategyB->>LendingB: supply(YBT-B as collateral)
    StrategyB->>LendingB: borrow(baseToken)
    LendingB-->>StrategyB: baseToken
    StrategyB-->>VaultB: baseToken (debt back to caller)
    VaultB-->>MigrationRouter: baseToken + mints shares to user
    MigrationRouter->>FlashLoanRouter: repay flash loan
```

Source: shares burned, collateral withdrawn, debt repaid. Destination: collateral supplied, debt borrowed, shares minted. Flash loan bridges the debt repayment. MigrationRouter calls FlashLoanRouter directly (not via Strategy).

## Cancel Pending Deposit

```mermaid
sequenceDiagram
    User->>Vault: cancelDeposit()
    Vault-->>User: transfer baseToken back
```

baseToken: Vault -> User. No shares were ever minted.

## Reclaim After Keeper Timeout

```mermaid
sequenceDiagram
    User->>Vault: reclaimDeposit()
    Note over Vault: verify timeout elapsed
    Vault-->>User: transfer baseToken back
    Note over Vault: epoch voided
```

baseToken: Vault -> User. Epoch voided after timeout.

## Force-Unwind

```mermaid
sequenceDiagram
    Guardian->>Vault: forceUnwind(calldata, router)
    Vault->>Strategy: emergencyUnwind(calldata, router)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, totalDebt, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
    Strategy->>LendingProtocol: repay(all debt)
    Strategy->>LendingProtocol: withdraw(all collateral)
    LendingProtocol-->>Strategy: all YBT
    Strategy->>DEX: swap all YBT -> baseToken
    DEX-->>Strategy: baseToken
    Strategy->>FlashLoanRouter: repay flash loan + fee
    Strategy-->>Vault: remaining baseToken -> idle
```

Full position unwind to idle base. After this, users exit via sync redeem idle mode.
