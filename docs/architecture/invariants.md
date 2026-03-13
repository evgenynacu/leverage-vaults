# Invariants

## Vault

- I1: totalSupply > 0 implies nav() > 0 (shares exist only if there is a position or idle balance)
- I2: Pending deposit funds excluded from totalAssets/NAV (idle, no yield, no risk)
- I3: Escrowed withdrawal shares held by vault contract (transferred at request time, prevents double-exit via sync redeem)
- I4: toleranceBps <= 100 (hard ceiling, enforced on set)
- I5: For any swap: amountReceived >= oracleValue(amountSent) * (10000 - toleranceBps) / 10000
- I6: depositCustom/withdrawCustom callable only by migrationRouter address
- I7: processDepositEpoch/processWithdrawalEpoch callable only by keeper
- I8: syncRedeem available regardless of pause state
- I9: New deposits and migrations blocked when paused
- I10: Shares minted round down; assets returned on burn round down (favor vault)
- I11: All deposit/withdrawal amounts >= configured minimums
- I12: depositCustom arithmetic NAV check: |actualNavDelta - expectedNavDelta| <= roundingToleranceBps, where expectedDelta = oracleValue(collateral) - debtAmount
- I13: _forceAccrue() called before any NAV snapshot (depositCustom, processEpoch, syncRedeem)
- I14: Transient storage reentrancy lock active during depositCustom, withdrawCustom, processEpoch, syncRedeem (mutual exclusion)
- I15: withdrawCustom reverts if user has pending withdrawal requests
- I16: Cancel deposit only possible before epoch processing starts

## Strategy

- I1: trackedCollateral and trackedDebt updated on every supply, borrow, repay, withdraw operation
- I2: NAV = oracleValue(trackedCollateral) - trackedDebt (internal accounting, ignores balanceOf)
- I3: Proportional exit preserves LTV ratio for remaining users
- I4: Post-operation LTV health check on migration depositCustom path -- revert if exceeds safety threshold
- I5: Strategy contract is the position owner in the lending protocol
- I6: Emergency unwind = full position unwind only (no partial rebalance)

## FlashLoanRouter

- I1: No token residual -- after callback completes, FlashLoanRouter holds zero tokens
- I2: Callback accepted only when active flag is set in transient storage (validates callback comes from active flash loan, prevents spoofed callbacks)
- I3: Single flash loan at a time -- no nested flash loans through the same router (transient storage enforced)
- I4: Flash loan fee passed through to caller (Strategy or MigrationRouter), not absorbed by router
- I5: Initiator address resolved from transient storage -- callback forwarded to correct initiator via onFlashLoan()

## MigrationRouter

- I1: Source and destination vaults must share the same debt token (base token)
- I2: YBT conversion verified via oracle-floor check (source oracle for outgoing, destination oracle for incoming)
- I3: Migration only by position owner or approved address
- I4: Flash loan amount = shares/totalSupply * trackedDebt (computed from source vault's Strategy.getTrackedPosition() and totalSupply())
- I5: After migration: source shares burned, destination shares minted, flash loan fully repaid

## Factory

- I1: Deployment reverts if: oracle unreachable, market invalid, toleranceBps > ceiling, baseToken != debt token in market
- I2: All validation runs on-chain in the deployment transaction
