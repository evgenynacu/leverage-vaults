# Call Sequence Diagrams

> GENERATED FROM q-tree.md — do not edit, regenerate from q-tree.

## requestDeposit

```mermaid
sequenceDiagram
    User->>Vault: requestDeposit(amount)
    note right of Vault: POST: amount >= minDepositAmount
    note right of Vault: POST: vault not paused
    Vault->>BaseToken: transferFrom(user, vault, amount)
    note right of BaseToken: POST: vault idle balance += amount
    Vault->>Vault: create FIFO request (user, amount, filledAmount=0)
    note right of Vault: POST: request appended to depositQueue tail
    note right of Vault: POST: returns requestId
    note right of Vault: POST: totalAssets unchanged (idle excluded from NAV)
```

## cancelDeposit

```mermaid
sequenceDiagram
    User->>Vault: cancelDeposit(requestId)
    note right of Vault: POST: msg.sender == request.owner
    note right of Vault: POST: request not yet fully processed
    Vault->>Vault: compute refund = amount - filledAmount
    Vault->>Vault: remove/invalidate request in queue
    Vault->>BaseToken: transfer(user, refund)
    note right of Vault: POST: user's unfilled deposit amount returned
    note right of Vault: POST: idle balance -= refund
```

## requestRedeem

```mermaid
sequenceDiagram
    User->>Vault: requestRedeem(shares)
    note right of Vault: POST: shares >= minRedeemShares
    note right of Vault: POST: vault not paused
    Vault->>Vault: transfer shares from user to vault (escrow)
    note right of Vault: POST: user balance -= shares, vault holds escrowed shares
    Vault->>Vault: create FIFO request (user, shares, filledShares=0)
    note right of Vault: POST: request appended to redeemQueue tail
    note right of Vault: POST: returns requestId
    note right of Vault: POST: user cannot syncRedeem escrowed shares (not in wallet)
```

## cancelRedeem

```mermaid
sequenceDiagram
    User->>Vault: cancelRedeem(requestId)
    note right of Vault: POST: msg.sender == request.owner
    note right of Vault: POST: request not yet fully processed
    Vault->>Vault: compute refund = shares - filledShares
    Vault->>Vault: remove/invalidate request in queue
    Vault->>Vault: transfer escrowed shares (refund) back to user
    note right of Vault: POST: user's unfilled shares returned to wallet
```

## processDeposits

```mermaid
sequenceDiagram
    Keeper->>Vault: processDeposits(amount, swapCalldata, swapRouter, flashLoanRouter)
    note right of Vault: POST: caller is keeper, reentrancy lock acquired
    note right of Vault: POST: factory.isRegisteredRouter(flashLoanRouter) == true
    Vault->>Vault: navBefore = totalAssets()
    note right of Vault: POST: _forceAccrue called inside totalAssets()
    Vault->>Vault: iterate FIFO from head, fill requests until amount exhausted
    note right of Vault: POST: last request may be partially filled, remainder stays in queue
    Vault->>Strategy: deposit(amount, swapCalldata, swapRouter, flashLoanRouter)
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    note right of FlashLoanRouter: POST: initiator = Strategy in transient storage, active flag set
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, 0, data)
    Strategy->>DEX: swap baseToken -> YBT (via swapCalldata)
    note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
    Strategy->>LendingProtocol: supply(YBT)
    Strategy->>LendingProtocol: borrow(baseToken)
    Strategy-->>FlashLoanRouter: repay flash loan (zero fee)
    note right of FlashLoanRouter: POST: zero token residual, active flag cleared
    note right of Strategy: POST: post-leverage LTV <= maxLTV
    Vault->>Vault: navAfter = totalAssets()
    note right of Vault: POST: _forceAccrue called inside totalAssets()
    note right of Vault: POST: navAfter > navBefore
    Vault->>Vault: mint shares to depositors pro-rata (round down)
    note right of Vault: POST: each depositor shares = depositAmount / (navDelta per unit)
    Vault->>Vault: advance FIFO head, update partial fill on last request
```

## processRedeems

```mermaid
sequenceDiagram
    Keeper->>Vault: processRedeems(shares, swapCalldata, swapRouter, flashLoanRouter)
    note right of Vault: POST: caller is keeper, reentrancy lock acquired
    note right of Vault: POST: factory.isRegisteredRouter(flashLoanRouter) == true
    Vault->>Vault: iterate FIFO from head, consume requests until shares exhausted
    note right of Vault: POST: last request may be partially filled
    Vault->>Vault: fraction = shares * 1e18 / totalSupply
    Vault->>Strategy: redeem(fraction, swapCalldata, swapRouter, flashLoanRouter)
    Strategy->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, proRataDebt, data)
    note right of FlashLoanRouter: POST: initiator = Strategy, active flag set
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, 0, data)
    Strategy->>LendingProtocol: repay(proportional debt)
    Strategy->>LendingProtocol: withdraw(proportional collateral)
    Strategy->>DEX: swap YBT -> baseToken (via swapCalldata)
    note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
    Strategy-->>FlashLoanRouter: repay flash loan
    note right of FlashLoanRouter: POST: zero token residual
    Strategy-->>Vault: remaining baseToken
    Vault->>Vault: burn escrowed shares (round up on assets = fewer assets out)
    note right of Vault: POST: escrowed shares burned, totalSupply decreased
    Vault->>Vault: distribute baseToken pro-rata to redeemers
    note right of Vault: POST: each redeemer receives proportional baseToken
    Vault->>Vault: advance FIFO head, update partial fill on last request
```

## syncRedeem

```mermaid
sequenceDiagram
    User->>Vault: syncRedeem(shares, swapCalldata, swapRouter, flashLoanRouter)
    note right of Vault: POST: shares >= minRedeemShares, reentrancy lock acquired
    note right of Vault: POST: always available even when paused
    note right of Vault: POST: factory.isRegisteredRouter(flashLoanRouter) == true
    Vault->>Vault: fraction = shares * 1e18 / totalSupply
    Vault->>Vault: burn shares from user wallet
    note right of Vault: POST: user balance -= shares, totalSupply -= shares
    alt position exists (collateral > 0)
        Vault->>Strategy: syncRedeem(fraction, swapCalldata, swapRouter, flashLoanRouter)
        Strategy->>Strategy: _forceAccrue()
        note right of Strategy: POST: lending protocol interest accrued
        Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, proRataDebt, data)
        note right of FlashLoanRouter: POST: initiator = Strategy, active flag set
        FlashProvider-->>FlashLoanRouter: baseToken
        FlashLoanRouter->>Strategy: onFlashLoan(token, amount, 0, data)
        Strategy->>LendingProtocol: repay(pro-rata debt)
        Strategy->>LendingProtocol: withdraw(pro-rata collateral)
        Strategy->>DEX: swap YBT -> baseToken
        note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
        Strategy-->>FlashLoanRouter: repay flash loan
        note right of FlashLoanRouter: POST: zero token residual
        Strategy-->>Vault: remaining baseToken
    else idle mode (no position)
        Vault->>Vault: compute fraction * idleBase / 1e18
    end
    Vault-->>User: transfer baseToken
    note right of Vault: POST: user received baseToken, LTV preserved for remaining holders
```

## depositCustom (migration intake)

```mermaid
sequenceDiagram
    MigrationRouter->>Vault: depositCustom(user, collateralAmount, debtAmount)
    note right of Vault: POST: caller is migrationRouter
    note right of Vault: POST: vault not paused, reentrancy lock acquired
    Vault->>Vault: navBefore = totalAssets()
    note right of Vault: POST: _forceAccrue called inside totalAssets()
    Vault->>Strategy: depositCustom(collateralAmount, debtAmount)
    note right of Strategy: POST: collateral (YBT) already at Strategy (transferred by MigrationRouter)
    Strategy->>LendingProtocol: supply(collateral)
    Strategy->>LendingProtocol: borrow(debtAmount)
    Strategy-->>MigrationRouter: baseToken (debtAmount) via Vault
    note right of Strategy: POST: post-leverage LTV <= maxLTV
    Vault->>Vault: navAfter = totalAssets()
    note right of Vault: POST: _forceAccrue called inside totalAssets()
    Vault->>Vault: expectedDelta = oracleValue(collateralAmount) - debtAmount
    note right of Vault: POST: |navAfter - navBefore - expectedDelta| <= roundingToleranceBps
    Vault->>Vault: mint shares to user (round down)
    note right of Vault: POST: shares minted based on delta NAV
    note right of Vault: POST: returns sharesMinted
```

## redeemCustom (migration source)

```mermaid
sequenceDiagram
    MigrationRouter->>Strategy: transfer baseToken (for debt repayment)
    note right of Strategy: POST: Strategy holds baseToken from MigrationRouter
    MigrationRouter->>Vault: redeemCustom(user, shares)
    note right of Vault: POST: caller is migrationRouter
    note right of Vault: POST: user has no pending redeem requests
    note right of Vault: POST: vault not paused, reentrancy lock acquired
    Vault->>Vault: fraction = shares * 1e18 / totalSupply
    Vault->>Vault: burn shares from user (round up = fewer assets out)
    note right of Vault: POST: user balance -= shares
    Vault->>Strategy: redeemCustom(fraction)
    Strategy->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Strategy->>Strategy: proRataDebt = fraction * actualDebt / 1e18
    Strategy->>Strategy: proRataCollateral = fraction * actualCollateral / 1e18
    Strategy->>LendingProtocol: repay(proRataDebt) using transferred baseToken
    Strategy->>LendingProtocol: withdraw(proRataCollateral)
    Strategy-->>MigrationRouter: YBT collateral via Vault
    note right of Vault: POST: shares burned, proportional position unwound
    note right of Vault: POST: returns collateralOut
```

## migrate (full flow)

```mermaid
sequenceDiagram
    User->>MigrationRouter: migrate(srcVault, dstVault, shares, swapCalldata, swapRouter, flashLoanRouter)
    note right of MigrationRouter: POST: user is owner or approved for shares
    note right of MigrationRouter: POST: factory.isRegisteredRouter(flashLoanRouter) == true
    MigrationRouter->>StrategyA: getPosition()
    note right of StrategyA: POST: _forceAccrue called internally, returns (collateral, debt)
    MigrationRouter->>SrcVault: totalSupply()
    MigrationRouter->>MigrationRouter: flashAmount = shares * actualDebt / totalSupply
    MigrationRouter->>FlashLoanRouter: executeFlashLoan(baseToken, flashAmount, data)
    note right of FlashLoanRouter: POST: initiator = MigrationRouter, active flag set
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>MigrationRouter: onFlashLoan(token, flashAmount, 0, data)
    MigrationRouter->>StrategyA: transfer baseToken
    MigrationRouter->>VaultA: redeemCustom(user, shares)
    note right of VaultA: POST: shares burned, YBT sent to MigrationRouter
    alt different YBT
        MigrationRouter->>DEX: swap YBT-A -> YBT-B (via swapCalldata)
        note right of MigrationRouter: POST: received >= oracle floor (src oracle for out, dst oracle for in)
    end
    MigrationRouter->>StrategyB: transfer YBT-B (collateral)
    MigrationRouter->>VaultB: depositCustom(user, collateralAmount, flashAmount)
    note right of VaultB: POST: shares minted to user, baseToken sent to MigrationRouter
    note right of VaultB: POST: post-leverage LTV <= maxLTV
    MigrationRouter-->>FlashLoanRouter: repay flash loan (zero fee)
    note right of FlashLoanRouter: POST: zero token residual, active flag cleared
    note right of MigrationRouter: POST: user has position in dst vault, src position closed
```

## emergencyRedeem

```mermaid
sequenceDiagram
    Keeper/Guardian->>Strategy: emergencyRedeem(swapCalldata, swapRouter, flashLoanRouter)
    note right of Strategy: POST: caller is keeper or guardian (onlyKeeperOrGuardian)
    note right of Strategy: POST: factory.isRegisteredRouter(flashLoanRouter) == true
    note right of Strategy: POST: fraction = 1e18 (full position)
    Strategy->>Strategy: _forceAccrue()
    note right of Strategy: POST: lending protocol interest accrued
    Strategy->>FlashLoanRouter: executeFlashLoan(baseToken, totalDebt, data)
    note right of FlashLoanRouter: POST: initiator = Strategy, active flag set
    FlashProvider-->>FlashLoanRouter: baseToken
    FlashLoanRouter->>Strategy: onFlashLoan(token, amount, 0, data)
    Strategy->>LendingProtocol: repay(all debt)
    Strategy->>LendingProtocol: withdraw(all collateral)
    Strategy->>DEX: swap all YBT -> baseToken
    note right of Strategy: POST: received >= oracleValue(sent) * (1 - toleranceBps)
    Strategy-->>FlashLoanRouter: repay flash loan
    note right of FlashLoanRouter: POST: zero token residual
    Strategy-->>Strategy: remaining baseToken held as idle
    note right of Strategy: POST: position = (0, 0)
    note right of Strategy: POST: syncRedeem enters idle mode, NAV = idle base only
```

## FlashLoanRouter.executeFlashLoan

```mermaid
sequenceDiagram
    Initiator->>FlashLoanRouter: executeFlashLoan(token, amount, data)
    note right of FlashLoanRouter: POST: open access, anyone can call
    FlashLoanRouter->>FlashLoanRouter: store msg.sender as initiator (transient storage)
    FlashLoanRouter->>FlashLoanRouter: set active flag (transient storage)
    note right of FlashLoanRouter: POST: no nested flash loan possible (active flag)
    FlashLoanRouter->>Provider: flashLoan(token, amount)
    Provider-->>FlashLoanRouter: callback with tokens
    note right of FlashLoanRouter: POST: callback validated via active flag
    FlashLoanRouter->>Initiator: onFlashLoan(token, amount, 0, data)
    note right of Initiator: POST: initiator executes logic (Strategy or MigrationRouter)
    Initiator-->>FlashLoanRouter: return
    FlashLoanRouter->>Provider: repay(token, amount)
    note right of FlashLoanRouter: POST: zero fee (only zero-fee providers)
    FlashLoanRouter->>FlashLoanRouter: clear transient storage
    note right of FlashLoanRouter: POST: zero token residual in FlashLoanRouter
```

## pause

```mermaid
sequenceDiagram
    AdminOrGuardian->>Vault: pause()
    note right of Vault: POST: caller is admin or guardian
    note right of Vault: POST: deposits blocked (requestDeposit reverts)
    note right of Vault: POST: new redeem requests blocked (requestRedeem reverts)
    note right of Vault: POST: migrations blocked (depositCustom/redeemCustom revert)
    note right of Vault: POST: keeper can still process queued epochs
    note right of Vault: POST: syncRedeem still works (always available)
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
    note right of Vault: POST: newToleranceBps <= toleranceCeiling (100 bps)
    Vault->>Vault: toleranceBps = newToleranceBps
    note right of Vault: POST: all future swaps use new tolerance
```

## setMaxLTV

```mermaid
sequenceDiagram
    Admin->>Strategy: setMaxLTV(newMaxLTV)
    note right of Strategy: POST: caller is admin
    Strategy->>Strategy: maxLTV = newMaxLTV
    note right of Strategy: POST: future deposit/depositCustom use new max LTV
```

## setGuardian

```mermaid
sequenceDiagram
    Admin->>Vault: setGuardian(newGuardian)
    note right of Vault: POST: caller is admin
    Vault->>Vault: guardian = newGuardian
    note right of Vault: POST: new guardian can pause
```

## setKeeper

```mermaid
sequenceDiagram
    Admin->>Vault: setKeeper(newKeeper)
    note right of Vault: POST: caller is admin
    Vault->>Vault: keeper = newKeeper
    note right of Vault: POST: new keeper processes epochs
```

## Factory.deploy

```mermaid
sequenceDiagram
    Admin->>Factory: deploy(protocolId, baseToken, ybt, oracle, tolerance, maxLTV, minDep, minRed, lendingConfig)
    note right of Factory: POST: caller is admin
    Factory->>Factory: validate oracle reachable (returns valid price)
    Factory->>Factory: validate lending market valid (exists, accepts collateral)
    Factory->>Factory: validate tolerance <= toleranceCeiling (100 bps)
    Factory->>Factory: validate baseToken matches debt token in lending market
    note right of Factory: POST: all validations pass or revert
    Factory->>Factory: deploy Vault beacon proxy
    Factory->>Factory: deploy Strategy beacon proxy (protocol-specific beacon)
    Factory->>Factory: configure vault <-> strategy link, set factory on both
    Factory->>Factory: set migrationRouter on vault
    Factory->>Factory: set oracle, tolerance, minAmounts on vault
    Factory->>Factory: set maxLTV on strategy
    Factory->>Factory: register in registry
    note right of Factory: POST: returns (vault, strategy) addresses
```

## Factory.registerRouter / deregisterRouter

```mermaid
sequenceDiagram
    Admin->>Factory: registerRouter(router)
    note right of Factory: POST: caller is admin
    note right of Factory: POST: isRegisteredRouter(router) == true
```

```mermaid
sequenceDiagram
    Admin->>Factory: deregisterRouter(router)
    note right of Factory: POST: caller is admin
    note right of Factory: POST: isRegisteredRouter(router) == false
```

## Factory.setMigrationRouter

```mermaid
sequenceDiagram
    Admin->>Factory: setMigrationRouter(newMigrationRouter)
    note right of Factory: POST: caller is admin
    note right of Factory: POST: new deployments use newMigrationRouter
    note right of Factory: POST: existing vaults unaffected (keep old router)
```
