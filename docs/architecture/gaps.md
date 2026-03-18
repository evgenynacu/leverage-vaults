# Gaps

> GENERATED FROM q-tree.md — do not edit, regenerate from q-tree.

All gaps below are spec expressibility limitations — the architecture decisions are fully specified in the q-tree, but the properties cannot be checked from the abstract test skeleton alone (they require implementation-level tests, mocks, or internal state access).

| # | Artifact | Gap description | Resolution |
|---|----------|----------------|------------|
| 1 | VaultSpec | Swap oracle-floor invariant (I5) cannot be checked from abstract spec | Integration test with actual swap |
| 2 | VaultSpec | Transient storage reentrancy lock (I14) cannot be verified from spec | Implementation test with reentrant callback |
| 3 | VaultSpec | FIFO ordering invariant (I17) needs internal queue inspection | Stateful fuzz test with queue getter |
| 4 | VaultSpec | processDeposits delta NAV postcondition needs Strategy integration | Integration test |
| 5 | VaultSpec | processRedeems distribution postcondition needs Strategy integration | Integration test |
| 6 | VaultSpec | redeemCustom pending redeem check needs queue inspection getter | Implementation test |
| 7 | VaultSpec | cancelDeposit refund postcondition needs token balance tracking | Implementation test |
| 8 | VaultSpec | cancelRedeem return shares postcondition needs balance tracking | Implementation test |
| 9 | VaultSpec | syncRedeem works when paused — needs full integration setup | Integration test |
| 10 | VaultSpec | depositCustom arithmetic NAV check — needs oracle + strategy setup | Integration test |
| 11 | VaultSpec | Rounding direction (I10) needs concrete amounts to verify | Implementation test |
| 12 | VaultSpec | Partial fill behavior needs multiple queued requests | Implementation test |
| 13 | StrategySpec | No internal tracking (I2) — design constraint, not observable | Code review |
| 14 | StrategySpec | Proportional exit preserves LTV (I3) — needs pre/post LTV from lending | Fork integration test |
| 15 | StrategySpec | Post-leverage LTV <= maxLTV (I4) — needs LTV from lending protocol | Fork integration test |
| 16 | StrategySpec | Position ownership (I5) — protocol-specific check | Fork integration test |
| 17 | StrategySpec | _forceAccrue before reads (I7) — internal implementation concern | Code review / internal unit test |
| 18 | StrategySpec | Swap oracle-floor postconditions for all swap paths | Fork integration test with swap |
| 19 | StrategySpec | depositCustom/redeemCustom lending state changes | Fork integration test |
| 20 | StrategySpec | Swap dust stays in Strategy (I11) | Implementation test |
| 21 | StrategySpec | getPosition calls _forceAccrue | Implementation test with lending protocol mock |
| 22 | FlashLoanRouterSpec | Zero token residual (I1) — needs ERC-20 balance check | Implementation test |
| 23 | FlashLoanRouterSpec | Spoofed callback reverts (I2) — needs spoofed callback | Implementation test |
| 24 | FlashLoanRouterSpec | Nesting guard (I3) — needs nested call attempt | Implementation test |
| 25 | FlashLoanRouterSpec | Zero fee (I4) — provider selection | Implementation / deployment test |
| 26 | FlashLoanRouterSpec | Callback routing to initiator (I5) — needs mock initiator | Implementation test with mock |
| 27 | MigrationRouterSpec | Same debt token check (I1) — needs baseToken from both strategies | Implementation test |
| 28 | MigrationRouterSpec | baseToken transfer ordering before redeemCustom (I7) | Implementation test with call tracing |
| 29 | MigrationRouterSpec | Flash loan amount = shares/totalSupply * actualDebt (I4) | Implementation test |
| 30 | MigrationRouterSpec | debtAmount to depositCustom = flash loan amount (I6) | Implementation test |
| 31 | MigrationRouterSpec | YBT conversion oracle-floor (I2) | Integration test |
| 32 | MigrationRouterSpec | Destination LTV after migration | Fork integration test |
| 33 | MigrationRouterSpec | Migration atomicity (src burned, dst minted, flash repaid) | Integration test |
| 34 | MigrationRouterSpec | Partial migration with specific share count | Integration test |
| 35 | FactorySpec | renounceOwnership disabled (I4) — OZ implementation-dependent | Implementation test |
| 36 | FactorySpec | Full deployment validation (oracle, market, token) | Fork integration test |
| 37 | FactorySpec | Same admin owns all beacons (I3) | Implementation test |
| 38 | FactorySpec | deploy returns valid (vault, strategy) addresses | Fork integration test |

## Consistency Check Findings

| # | Check | Finding |
|---|-------|---------|
| — | Multiplicity | No findings — per-vault tolerance is single-vault instance; per-protocol beacons use protocolId key |
| — | Stored vs parameter | swapRouter is caller-provided without registry validation — by design (oracle-floor check is the guard per [d:ybt-types]) |
| — | Name consistency | No mismatches found across all artifacts |
| — | Dependency completeness | IFlashLoanReceiver generated for callback pattern. External protocols (Aave, Morpho, Euler, DEX, Oracle) are implementation details per ADRs — no custom interfaces generated |
| — | Cross-flow parameter consistency | swapCalldata + swapRouter + flashLoanRouter present in all swap-performing flows. Oracle-floor check applied uniformly |

**No architectural gaps.** All 69 q-tree decisions are fully resolved and reflected in the artifacts. The gaps above are test infrastructure limitations that will be covered by implementation-level and fork integration tests.
