# Gaps

> GENERATED FROM q-tree.md — do not edit, regenerate from q-tree.

All gaps below are spec expressibility limitations — the architecture decisions are fully specified in the q-tree, but the properties cannot be checked from the abstract test skeleton alone (they require implementation-level tests, mocks, or internal state access).

| # | Artifact | Gap description | Resolution |
|---|----------|----------------|------------|
| 1 | VaultSpec | Swap oracle-floor invariant (I5) cannot be checked statically | Integration test with actual swap |
| 2 | VaultSpec | Transient storage reentrancy lock (I14) cannot be verified from spec | Implementation test with reentrant callback |
| 3 | VaultSpec | FIFO ordering invariant (I17) needs internal queue inspection | Stateful fuzz test with queue getter |
| 4 | VaultSpec | processDeposits delta NAV postcondition needs Strategy integration | Integration test |
| 5 | VaultSpec | processRedeems distribution postcondition needs Strategy integration | Integration test |
| 6 | VaultSpec | redeemCustom pending redeem check needs queue inspection getter | Implementation test |
| 7 | VaultSpec | Deposit/Redeem request state transitions need requestId from event | Implementation test with event parsing |
| 8 | VaultSpec | Position state transitions (Empty/Active/Unwound) need Strategy interaction | Integration test |
| 9 | StrategySpec | No internal tracking (I2) — implementation concern, not observable from spec | Code review |
| 10 | StrategySpec | Proportional exit preserves LTV (I3) — needs pre/post LTV from lending protocol | Fork integration test |
| 11 | StrategySpec | Post-leverage LTV <= maxLTV (I4) — needs LTV from lending protocol | Fork integration test |
| 12 | StrategySpec | Position ownership (I5) — protocol-specific check | Fork integration test |
| 13 | StrategySpec | _forceAccrue before reads (I7) — internal implementation concern | Code review / internal unit test |
| 14 | StrategySpec | Swap oracle-floor postconditions for deposit/redeem/syncRedeem | Fork integration test with swap |
| 15 | StrategySpec | depositCustom lending state changes — needs protocol state observation | Fork integration test |
| 16 | StrategySpec | redeemCustom lending state + YBT transfer — needs protocol state observation | Fork integration test |
| 17 | FlashLoanRouterSpec | Transient storage nesting guard (I3) — needs nested call attempt | Implementation test |
| 18 | FlashLoanRouterSpec | Zero fee (I4) — implementation enforces provider selection | Implementation / deployment validation test |
| 19 | FlashLoanRouterSpec | Callback routing to initiator (I5) — needs mock initiator | Implementation test with mock |
| 20 | FlashLoanRouterSpec | Callback validation via active flag (I2) — needs spoofed callback | Implementation test |
| 21 | MigrationRouterSpec | Same debt token check (I1) — needs baseToken from both strategies | Implementation test |
| 22 | MigrationRouterSpec | baseToken transfer ordering (I7) — needs call tracing | Implementation test |
| 23 | MigrationRouterSpec | Flash loan repayment (I5) — covered by FlashLoanRouter invariant I1 | Cross-contract invariant |
| 24 | MigrationRouterSpec | Destination LTV after migration — needs strategy LTV read | Fork integration test |
| 25 | MigrationRouterSpec | YBT conversion oracle-floor — needs swap observation | Integration test |
| 26 | MigrationRouterSpec | Flash loan amount computation (I4) — needs internal observation | Implementation test |
| 27 | MigrationRouterSpec | debtAmount to depositCustom = flash loan amount (I6) | Implementation test |
| 28 | FactorySpec | renounceOwnership disabled (I4) — needs calling and expecting revert | Implementation test |
| 29 | FactorySpec | Full deployment validation — needs valid oracle, market, token setup | Fork integration test |
| 30 | FactorySpec | Same admin owns all beacons (I3) — needs checking beacon ownership | Implementation test |

**No architectural gaps.** All 69 q-tree decisions are fully resolved and reflected in the artifacts. The gaps above are test infrastructure limitations that will be covered by implementation-level and fork integration tests.
