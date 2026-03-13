# Risk Mitigation Map

| Risk | Source | Mitigation from q-tree | Status |
|------|--------|----------------------|--------|
| Reentrancy via flash loan callback | general: flash loan re-entry | EIP-1153 transient storage lock on Vault, covers depositCustom/withdrawCustom/processEpoch/syncRedeem + CEI ordering [d:reentrancy-lock] | COVERED |
| Flash loan callback spoofing | general: spoofed callback injection | FlashLoanRouter validates callback via transient storage (active flag + stored initiator). Only accepts callbacks during active flash loan [d:flr-invariants, d:flash-callback] | COVERED |
| Nested flash loan attack | general: reentrancy via flash loan nesting | FlashLoanRouter transient storage ensures single flash loan at a time, no nesting [d:flr-invariants] | COVERED |
| Flash loan fee absorption | general: unexpected cost not passed through | FlashLoanRouter passes fee through to caller (Strategy/MigrationRouter), not absorbed [d:flr-invariants] | COVERED |
| Donation attack / balance manipulation | general: ERC4626 donation | Internal balance tracking (trackedCollateral/trackedDebt), not balanceOf. Direct transfers don't affect NAV [d:internal-tracking] | COVERED |
| First depositor share inflation | general: vault share inflation | Delta NAV prices each deposit independently; internal tracking ignores donations; minimum deposit ensures precision with 18-decimal shares [d:first-depositor] | COVERED |
| Oracle manipulation / staleness | general: oracle-dependent pricing | Oracle used only as safety floor for swaps, not for share pricing (delta NAV handles pricing). Swap check: received >= oracleValue * (1 - tolerance) [d:oracle-scope, d:invariant] | COVERED |
| Oracle manipulation between NAV snapshots (depositCustom) | general: sandwich NAV snapshots | Arithmetic NAV validation: expectedDelta = oracleValue(collateral) - debt, revert on deviation [d:arith-nav] | COVERED |
| Interest accrual NAV inflation | general: lazy interest accrual | _forceAccrue() before every NAV snapshot (depositCustom, processEpoch, syncRedeem) [d:accrue-before-snap] | COVERED |
| Sandwich / MEV on swaps | general: DEX swap exploitation | Oracle-floor check on all swaps, per-vault toleranceBps with 100 bps hard ceiling [d:invariant, d:tolerance-params] | COVERED |
| Bad keeper calldata (malicious routing) | general: privileged calldata injection | Same oracle-floor swap verification applies to keeper path [d:verification] | COVERED |
| Bad user calldata (sync redeem) | general: user-provided calldata | Oracle-floor check applies uniformly to user-provided calldata [d:wd-calldata] | COVERED |
| Keeper liveness failure (deposits stuck) | general: centralized operator dependency | Timeout + user self-serve reclaimDeposit; guardian can also trigger reclaim [d:keeper-timeout] | COVERED |
| Keeper liveness failure (withdrawals stuck) | general: centralized operator dependency | Sync permissionless redeem always available as alternative exit [d:sync-redeem] | COVERED |
| Fund lockup when paused | general: pause traps user funds | Sync redeem works even when paused; users never locked in [d:pause-scope, d:pause-exit] | COVERED |
| Liquidation from LTV drift | general: leveraged position risk | Emergency unwind only (full unwind, no partial rebalance); keeper/guardian trigger; max leverage at entry [d:risk] | COVERED |
| LTV degradation from partial exit | general: non-proportional withdrawal | Pro-rata exit preserves LTV ratio for remaining holders [d:wd-partial, d:sync-redeem] | COVERED |
| Migration LTV violation | general: cross-vault position change | Post-operation LTV health check on depositCustom, revert if exceeds threshold [d:risk] | COVERED |
| Migration YBT conversion loss | general: cross-asset swap risk | MigrationRouter applies oracle-floor check using source oracle for outgoing, destination oracle for incoming [d:migration-verify] | COVERED |
| Migration flash loan amount mismatch | general: incorrect debt computation | Flash loan amount computed from source vault: shares/totalSupply * trackedDebt via getTrackedPosition() [d:migration-flash-amount] | COVERED |
| Double-exit (async + sync simultaneously) | general: share double-spend | Shares escrowed (transferred to vault) at async request time, not in user wallet for sync redeem [d:wd-async] | COVERED |
| withdrawCustom with pending async withdrawal | general: conflicting withdrawal states | withdrawCustom reverts if user has pending withdrawal requests [d:migration-deposit] | COVERED |
| Rounding-based value extraction | general: share/asset rounding | Round down on mint, round up on burn (favor vault); minimum amounts prevent dust [d:rounding, d:min-amounts] | COVERED |
| Dust griefing (tiny deposits/withdrawals) | general: gas griefing | Admin-settable minimum deposit and withdrawal amounts [d:min-amounts] | COVERED |
| Admin key compromise | general: privileged role abuse | OZ Ownable2Step (two-step transfer); renounce disabled; separate guardian role; governance via TimelockController later [d:admin-transfer, d:access-details] | COVERED |
| Accidental admin transfer | general: operational error | Ownable2Step requires propose + accept [d:admin-transfer] | COVERED |
| Factory misconfiguration | general: deployment parameter error | On-chain validation: oracle reachable, market valid, tolerance <= ceiling, token match [d:factory-validation] | COVERED |
| Flash loan provider unavailability | general: external dependency | Strategy can switch FlashLoanRouter via admin; multiple providers supported [d:new-flashloan] | COVERED |
| MigrationRouter upgrade breaks existing vaults | general: upgrade compatibility | MigrationRouter is stateless and immutable; new router for new vaults; existing vaults updated explicitly by admin [d:migration-router-upgrade] | COVERED |
