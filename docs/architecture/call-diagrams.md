# Call Sequence Diagrams

## requestDeposit

```mermaid
sequenceDiagram
    User->>Vault: requestDeposit(amount)
    note right of Vault: POST: amount >= minDepositAmount
    note right of Vault: POST: vault not paused
    Vault->>BaseToken: transferFrom(user, vault, amount)
    note right of BaseToken: POST: vault idle balance += amount
    Vault->>Vault: add to depositQueue[user][epoch]
    note right of Vault: POST: user's pending deposit recorded in current epoch
    note right of Vault: POST: totalAssets/NAV unchanged (idle excluded)
```

## cancelDeposit

```mermaid
sequenceDiagram
    User->>Vault: cancelDeposit()
    note right of Vault: POST: current epoch not yet processing
    Vault->>Vault: remove from depositQueue[user][epoch]
    Vault->>BaseToken: transfer(user, amount)
    note right of Vault: POST: user's pending deposit = 0
    note right of Vault: POST: idle balance -= amount
```

## processDepositEpoch

```mermaid
sequenceDiagram
    Keeper->>Vault: processDepositEpoch(calldata, router)
    note right of Vault: POST: caller is keeper, reentrancy lock acquired
    Vault->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Vault->>Vault: navBefore = nav() (reads actual position from protocol)
    Vault->>Strategy: leverage(totalPending, calldata, router)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, amount, data)
    note right of FlashLoanRouter: POST: initiator = Strategy in transient storage, active flag set
    FlashLoanRouter->>FlashProvider: flash borrow
    FlashProvider->>FlashLoanRouter: onFlashLoanCallback
    note right of FlashLoanRouter: POST: callback validated via transient storage
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
    Strategy->>DEX: swap baseToken -> YBT (via calldata)
    note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
    Strategy->>LendingProtocol: supply(YBT)
    Strategy->>LendingProtocol: borrow(baseToken)
    Strategy-->>FlashLoanRouter: repay flash loan
    note right of FlashLoanRouter: POST: zero token residual, active flag cleared
    Vault->>Strategy: _forceAccrue()
    Vault->>Vault: navAfter = nav() (reads actual position from protocol)
    note right of Vault: POST: navAfter > navBefore
    Vault->>Vault: mint shares to depositors pro-rata (round down)
    note right of Vault: POST: each depositor shares = depositAmount / (navDelta per unit)
    Vault->>Vault: advance deposit epoch
    note right of Vault: POST: depositQueue for processed epoch cleared
```

## requestWithdrawal

```mermaid
sequenceDiagram
    User->>Vault: requestWithdrawal(shares)
    note right of Vault: POST: shares >= minWithdrawalAmount
    note right of Vault: POST: vault not paused
    Vault->>Vault: transfer shares from user to vault (escrow)
    note right of Vault: POST: user balance -= shares, vault holds escrowed shares
    Vault->>Vault: add to withdrawalQueue[user][epoch]
    note right of Vault: POST: user cannot syncRedeem escrowed shares (not in wallet)
```

## processWithdrawalEpoch

```mermaid
sequenceDiagram
    Keeper->>Vault: processWithdrawalEpoch(calldata, router)
    note right of Vault: POST: caller is keeper, reentrancy lock acquired
    Vault->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Vault->>Strategy: unwind(totalShares, totalSupply, calldata, router)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, amount, data)
    note right of FlashLoanRouter: POST: initiator = Strategy, active flag set
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
    Strategy->>LendingProtocol: repay(proportional debt)
    Strategy->>LendingProtocol: withdraw(proportional collateral)
    Strategy->>DEX: swap YBT -> baseToken (via calldata)
    note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
    Strategy-->>FlashLoanRouter: repay flash loan
    note right of FlashLoanRouter: POST: zero token residual
    Strategy-->>Vault: remaining baseToken
    Vault->>Vault: burn escrowed shares (round up on assets = fewer assets out)
    note right of Vault: POST: escrowed shares burned, totalSupply decreased
    Vault->>Vault: distribute baseToken pro-rata to withdrawers
    note right of Vault: POST: each withdrawer receives proportional base token
    Vault->>Vault: advance withdrawal epoch
```

## syncRedeem

```mermaid
sequenceDiagram
    User->>Vault: syncRedeem(shares, calldata, router)
    note right of Vault: POST: shares >= minWithdrawalAmount
    note right of Vault: POST: reentrancy lock acquired
    Vault->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Vault->>Vault: burn shares from user wallet
    note right of Vault: POST: user balance -= shares, totalSupply -= shares
    alt position exists (collateral > 0)
        Vault->>Strategy: unwind(shares, totalSupplyBefore, calldata, router)
        Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, proRataDebt, data)
        note right of FlashLoanRouter: POST: initiator = Strategy, active flag set
        FlashProvider-->>FlashLoanRouter: baseToken
        FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
        Strategy->>LendingProtocol: repay(pro-rata debt)
        Strategy->>LendingProtocol: withdraw(pro-rata collateral)
        Strategy->>DEX: swap YBT -> baseToken
        note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
        Strategy-->>FlashLoanRouter: repay flash loan
        note right of FlashLoanRouter: POST: zero token residual
        Strategy-->>Vault: remaining baseToken
    else idle mode (no position)
        Vault->>Vault: compute shares/totalSupplyBefore * idleBase
    end
    Vault-->>User: transfer baseToken
    note right of Vault: POST: user received base token, LTV preserved for remaining holders
```

## depositCustom (migration intake)

```mermaid
sequenceDiagram
    MigrationRouter->>Vault: depositCustom(user, collateralAmount, debtAmount)
    note right of Vault: POST: caller is migrationRouter
    note right of Vault: POST: vault not paused
    note right of Vault: POST: reentrancy lock acquired
    Vault->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Vault->>Vault: navBefore = nav() (reads actual position from protocol)
    Vault->>Strategy: supplyAndBorrow(collateralAmount, debtAmount)
    Strategy->>LendingProtocol: supply(collateral)
    Strategy->>LendingProtocol: borrow(debtAmount)
    Strategy-->>MigrationRouter: baseToken (debt)
    note right of Strategy: POST: LTV within safety threshold
    Vault->>Strategy: _forceAccrue()
    Vault->>Vault: navAfter = nav() (reads actual position from protocol)
    Vault->>Vault: expectedDelta = oracleValue(collateralAmount) - debtAmount
    note right of Vault: POST: |navAfter - navBefore - expectedDelta| <= roundingToleranceBps
    Vault->>Vault: mint shares to user (round down)
    note right of Vault: POST: shares minted based on delta NAV
```

## withdrawCustom (migration source)

```mermaid
sequenceDiagram
    MigrationRouter->>Vault: withdrawCustom(user, shares)
    note right of Vault: POST: caller is migrationRouter
    note right of Vault: POST: user has no pending withdrawal requests
    note right of Vault: POST: reentrancy lock acquired
    Vault->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Vault->>Vault: burn shares from user (round up = fewer assets out)
    note right of Vault: POST: user balance -= shares
    Vault->>Strategy: repayAndWithdraw(shares, totalSupplyBefore)
    Strategy->>Strategy: read actual position from protocol
    Strategy->>Strategy: proRataDebt = shares/totalSupply * actualDebt
    Strategy->>Strategy: proRataCollateral = shares/totalSupply * actualCollateral
    Strategy->>LendingProtocol: repay(proRataDebt)
    Strategy->>LendingProtocol: withdraw(proRataCollateral)
    Strategy-->>MigrationRouter: YBT collateral
    note right of Vault: POST: shares burned, proportional position unwound
```

## migrate (full flow)

```mermaid
sequenceDiagram
    User->>MigrationRouter: migrate(src, dst, shares, flRouter, convCalldata, convRouter)
    note right of MigrationRouter: POST: user is owner or approved for shares
    MigrationRouter->>StrategyA: getPosition() (calls _forceAccrue internally)
    note right of MigrationRouter: POST: actualDebt retrieved after accrual
    MigrationRouter->>MigrationRouter: flashAmount = shares/totalSupply * actualDebt
    MigrationRouter->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    note right of FlashLoanRouter: POST: initiator = MigrationRouter, active flag set
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>MigrationRouter: onFlashLoan(token, amount, fee, data)
    MigrationRouter->>VaultA: withdrawCustom(user, shares)
    note right of VaultA: POST: shares burned, YBT-A returned to MigrationRouter
    alt different YBT
        MigrationRouter->>DEX: swap YBT-A -> YBT-B (via convCalldata)
        note right of MigrationRouter: POST: received >= oracle floor (src oracle for out, dst oracle for in)
    end
    MigrationRouter->>VaultB: depositCustom(user, collateral, debtAmount)
    note right of VaultB: POST: shares minted to user, debt sent to MigrationRouter
    MigrationRouter->>FlashLoanRouter: repay flash loan + fee
    note right of FlashLoanRouter: POST: zero token residual, active flag cleared
    note right of MigrationRouter: POST: user has position in dst vault, src position closed
```

## forceUnwind

```mermaid
sequenceDiagram
    Guardian->>Vault: forceUnwind(calldata, router)
    note right of Vault: POST: caller is guardian
    Vault->>Strategy: emergencyUnwind(calldata, router)
    Strategy->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, totalDebt, data)
    note right of FlashLoanRouter: POST: initiator = Strategy, active flag set
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
    Strategy->>LendingProtocol: repay(all debt)
    Strategy->>LendingProtocol: withdraw(all collateral)
    Strategy->>DEX: swap all YBT -> baseToken
    note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
    Strategy-->>FlashLoanRouter: repay flash loan
    note right of FlashLoanRouter: POST: zero token residual
    Strategy-->>Vault: remaining baseToken (now idle)
    note right of Vault: POST: position fully unwound, only idle base remains
    note right of Vault: POST: syncRedeem enters idle mode
```

## emergencyUnwind (keeper path)

```mermaid
sequenceDiagram
    Keeper->>Strategy: emergencyUnwind(calldata, router)
    note right of Strategy: POST: caller is keeper or guardian
    Strategy->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, totalDebt, data)
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, fee, data)
    Strategy->>LendingProtocol: repay(all debt)
    Strategy->>LendingProtocol: withdraw(all collateral)
    Strategy->>DEX: swap all YBT -> baseToken
    note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
    Strategy-->>FlashLoanRouter: repay flash loan
    Strategy-->>Vault: remaining baseToken (now idle)
    note right of Strategy: POST: actual position = (0, 0)
```

## reclaimDeposit

```mermaid
sequenceDiagram
    User->>Vault: reclaimDeposit()
    note right of Vault: POST: keeper timeout elapsed for user's epoch
    Vault->>Vault: remove from depositQueue, void epoch
    Vault->>BaseToken: transfer(user, pendingAmount)
    note right of Vault: POST: user's pending deposit returned, epoch voided
```

## pause

```mermaid
sequenceDiagram
    AdminOrGuardian->>Vault: pause()
    note right of Vault: POST: deposits blocked
    note right of Vault: POST: new withdrawal requests blocked
    note right of Vault: POST: migrations blocked
    note right of Vault: POST: keeper can still process queued epochs
    note right of Vault: POST: syncRedeem still works
```

## unpause

```mermaid
sequenceDiagram
    Admin->>Vault: unpause()
    note right of Vault: POST: caller is admin (not guardian)
    note right of Vault: POST: all operations resumed
```

## setTolerance

```mermaid
sequenceDiagram
    Admin->>Vault: setTolerance(newToleranceBps)
    note right of Vault: POST: caller is admin
    note right of Vault: POST: newToleranceBps <= 100
    Vault->>Vault: toleranceBps = newToleranceBps
    note right of Vault: POST: all future swaps use new tolerance
```

## Factory deploy

```mermaid
sequenceDiagram
    Admin->>Factory: deploy(beacon, baseToken, ybt, market, oracle, tolerance, minDep, minWd)
    note right of Factory: POST: caller is admin
    Factory->>Factory: validate oracle reachable
    Factory->>Factory: validate lending market valid
    Factory->>Factory: validate tolerance <= ceiling
    Factory->>Factory: validate baseToken matches debt token in market
    note right of Factory: POST: all validations pass or revert
    Factory->>Factory: deploy Vault proxy (beacon)
    Factory->>Factory: deploy Strategy proxy (beacon)
    Factory->>Factory: configure vault <-> strategy link
    Factory->>Factory: set migrationRouter on vault
    Factory->>Factory: register in registry
    note right of Factory: POST: vault + strategy pair deployed and registered
```
