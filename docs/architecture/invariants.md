# Invariants

> GENERATED FROM q-tree.md — do not edit, regenerate from q-tree.

## Vault

- I1: totalSupply > 0 implies nav() > 0 (shares exist only if there is a position or idle balance)
- I2: Pending deposit funds excluded from totalAssets/NAV (idle, no yield, no risk)
- I3: Escrowed redeem shares held by vault contract (transferred at requestRedeem time, prevents double-exit via sync redeem)
- I4: toleranceBps <= 100 (hard ceiling, enforced on set and at deployment)
- I5: For any swap: amountReceived >= oracleValue(amountSent) * (10000 - toleranceBps) / 10000
- I6: depositCustom/redeemCustom callable only by migrationRouter address
- I7: processDeposits/processRedeems callable only by keeper
- I8: syncRedeem available regardless of pause state
- I9: New deposits, new redeem requests, and migrations blocked when paused; keeper and sync redeem exempt
- I10: Shares minted round down; assets returned on burn round down (favor vault)
- I11: All deposit/redeem amounts >= configured minimums (requestDeposit, requestRedeem, syncRedeem, depositCustom/redeemCustom share count)
- I12: depositCustom arithmetic NAV check: |actualNavDelta - expectedNavDelta| <= roundingToleranceBps, where expectedDelta = oracleValue(collateralAmount) - debtAmount
- I13: _forceAccrue() called before any position read (depositCustom, redeemCustom, processDeposits, processRedeems, syncRedeem, emergencyRedeem, migration flash loan amount)
- I14: Transient storage reentrancy lock active during depositCustom, redeemCustom, processDeposits, processRedeems, syncRedeem (mutual exclusion)
- I15: redeemCustom reverts if user has pending redeem requests
- I16: Cancel deposit/redeem only possible for requests not yet fully processed; partially filled requests can be cancelled (unfilled portion returned)
- I17: FIFO order enforced — keeper cannot cherry-pick or reorder requests
- I18: Partial fills allowed — processDeposits fills by amount, processRedeems fills by shares; last request may be partially filled with remainder staying in queue
- I19: Vault has NO emergency/force redeem function — emergency redeem lives on Strategy
- I20: Cancel is the only mechanism for unprocessed requests — no timeout, no reclaim, no reclaimDeposit, no reclaimRedeem
- I21: FlashLoanRouter parameter validated against Factory registry (factory.isRegisteredRouter) in processDeposits, processRedeems, syncRedeem

## Strategy

- I1: NAV = oracleValue(actualCollateral) - actualDebt, read from lending protocol after _forceAccrue()
- I2: No internal balance tracking — position always read from protocol
- I3: Proportional exit (via fraction) preserves LTV ratio for remaining users
- I4: Post-leverage LTV check on deposit and depositCustom — revert if LTV exceeds maxLTV
- I5: Strategy contract is the position owner in the lending protocol
- I6: Emergency redeem = full position unwind only (no partial rebalance); uses fraction = 1e18
- I7: _forceAccrue() called before every position read
- I8: fraction argument: Vault computes fraction = shares * 1e18 / totalSupply; Strategy applies amount = fraction * actualValue / 1e18
- I9: emergencyRedeem callable only by keeper or guardian directly (not through Vault)
- I10: maxLTV is admin-settable per-vault parameter
- I11: Swap calldata margin: caller builds calldata with slightly smaller amountIn; residual dust stays in Strategy
- I12: Strategy does NOT store FlashLoanRouter address — receives it as parameter per-call
- I13: emergencyRedeem validates flashLoanRouter against Factory registry (factory.isRegisteredRouter)

## FlashLoanRouter

- I1: No token residual — after callback completes, FlashLoanRouter holds zero tokens
- I2: Callback accepted only when active flag is set in transient storage (validates callback comes from active flash loan, prevents spoofed callbacks)
- I3: Single flash loan at a time — no nested flash loans through the same router (transient storage enforced)
- I4: Zero fee — only zero-fee flash loan providers used; no fee accounting needed
- I5: Initiator address resolved from transient storage — callback forwarded to correct initiator via onFlashLoan()
- I6: executeFlashLoan has open access — security relies on transient storage validation, not caller restriction

## MigrationRouter

- I1: Source and destination vaults must share the same debt token (base token)
- I2: YBT conversion verified via oracle-floor check (source oracle for outgoing, destination oracle for incoming)
- I3: Migration only by position owner or approved address
- I4: Flash loan amount = shares/totalSupply * actualDebt (computed from source vault's Strategy.getPosition() after _forceAccrue)
- I5: After migration: source shares burned, destination shares minted, flash loan fully repaid
- I6: debtAmount passed to depositCustom = flash loan amount (MigrationRouter knows the exact size)
- I7: MigrationRouter transfers baseToken to source Strategy before calling redeemCustom
- I8: Partial migration supported — user specifies share count
- I9: FlashLoanRouter validated against Factory registry (factory.isRegisteredRouter)

## Factory

- I1: Deployment reverts if: oracle unreachable, market invalid, toleranceBps > ceiling, baseToken != debt token in market
- I2: All validation runs on-chain in the deployment transaction
- I3: Same admin owns all beacons (Vault, Strategy)
- I4: Ownable2Step, renounce disabled
- I5: registeredRouters is admin-managed set of approved FlashLoanRouter addresses
- I6: isRegisteredRouter returns true only for admin-registered routers
