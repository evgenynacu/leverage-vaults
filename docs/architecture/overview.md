# Overview

Leveraged YBT (yield-bearing token) vault system. Users deposit a base token (e.g., USDC); a keeper deploys capital with leverage via flash loans — borrowing the base token from a lending protocol (Aave v3 / Morpho / Euler v2), swapping to YBT, and supplying YBT as collateral. Entry and exit happen in single atomic transactions. One vault = one strategy (one YBT + one lending protocol), deployed via a factory. A MigrationRouter enables per-user cross-vault migration without full unwind to base token.

## Key Decisions

- **Vault + Strategy split** — Vault handles accounting (shares, epochs, NAV, pause, sync redeem); Strategy handles all lending/leverage logic via inheritance per protocol. No separate LendingAdapter contract. [d:contracts, d:adapter-ownership]
- **Base token = debt token** — Users deposit and the vault borrows the same token. Simplifies NAV and migration. [d:base-debt-token]
- **Async epoch deposits, dual-path redeems** — Deposits queued and processed by keeper (eliminates oracle arbitrage under leverage). Redeems: async keeper-batched OR sync permissionless (user provides calldata). [d:accounting, d:withdrawal]
- **Partial epoch processing** — Keeper processes N requests from FIFO head per call, including partial fills of large requests. FIFO order mandatory — no cherry-picking. [d:partial-epoch]
- **Per-user timeout** — Each request stores its own submission timestamp. Reclaimable independently after timeout, not tied to epoch. Reclaimed requests create gaps in FIFO queue — keeper skips them. [d:per-user-timeout]
- **Separate epoch processing** — processDeposits and processRedeems are distinct (opposite token flows cannot combine). [d:epoch-separation]
- **Delta NAV pricing** — Shares priced by measuring NAV before/after keeper deploys capital. Slippage falls on depositing cohort, not existing holders. [d:nav-snap]
- **No internal balance tracking** — Strategy reads actual position from lending protocol (after _forceAccrue). Delta NAV + minimum deposit + reentrancy lock mitigate donation attacks. [d:internal-tracking]
- **_forceAccrue before ALL position reads** — Every flow that reads position calls _forceAccrue() first: processDeposits, processRedeems, syncRedeem, depositCustom, redeemCustom, emergencyRedeem, migration flash loan amount computation. [d:accrue-before-snap]
- **Fraction argument** — Strategy receives `fraction` (scaled to 1e18) instead of `(shares, totalSupply)`. Vault computes `fraction = shares * 1e18 / totalSupply`. Strategy applies `amount = fraction * actualValue / 1e18`. fraction = 1e18 means full position (emergencyRedeem). [d:fraction-arg]
- **Naming: deposit/redeem everywhere** — "Withdrawal" replaced by "redeem" throughout Vault and Strategy. Vault: requestDeposit/requestRedeem (async), syncRedeem (sync), processDeposits/processRedeems (keeper), depositCustom/redeemCustom (migration). Strategy: deposit/redeem (epoch), depositCustom/redeemCustom (migration), emergencyRedeem (full unwind, called directly by keeper/guardian on Strategy). [d:naming]
- **Emergency redeem on Strategy, not Vault** — Keeper and guardian call Strategy.emergencyRedeem() directly. Vault has no forceRedeem or emergency function. Emergency unwind is a Strategy concern (position management). [d:keeper-emergency]
- **Max LTV enforcement** — Strategy.deposit checks post-leverage LTV against maxLTV, an admin-settable per-vault parameter. Also checked on depositCustom (migration). [d:max-ltv]
- **Oracle-floor swap verification** — All swaps checked: `received >= oracleValue(sent) * (1 - toleranceBps)`. Per-vault tolerance, hard ceiling 100 bps. [d:invariant, d:tolerance-params]
- **Only zero-fee flash loan providers** — Balancer, Morpho, Aave with 0-fee markets, etc. Non-zero fee would make entry/exit prohibitively expensive. Simplifies calldata construction. [d:flash-fee]
- **Sync permissionless redeem always available** — Works even when paused. Users are never locked in. [d:sync-redeem, d:pause-exit]
- **Beacon proxy upgradeability** — 1 Vault beacon + N Strategy beacons (per lending protocol) + N FlashLoanRouter beacons (per provider). Same admin as Factory owns all beacons. [d:vault-beacon, d:beacon-owner]
- **FlashLoanRouter open access** — Anyone can call executeFlashLoan(). Security relies on transient storage callback validation, not caller restriction. [d:flr-access]
- **FlashLoanRouter per provider** — Normalizes flash loan callbacks via EIP-1153 transient storage (initiator address + active flag). No persistent state beyond config. No token residual. Single flash loan at a time. Both Strategy and MigrationRouter implement onFlashLoan() callback. [d:flash-callback, d:flr-invariants, d:flr-state]
- **MigrationRouter is stateless and immutable** — Calls FlashLoanRouter directly (not via Strategy). Flash loan amount = shares/totalSupply * actualDebt (after _forceAccrue). [d:migration, d:migration-flash-source, d:migration-flash-amount]
- **redeemCustom token flow** — MigrationRouter transfers flash-loaned baseToken to Strategy before calling Vault.redeemCustom(). Strategy uses it to repay debt, withdraws collateral (YBT) and sends to MigrationRouter. [d:redeem-custom-flow]
- **depositCustom takes explicit debtAmount** — `depositCustom(address user, uint256 collateralAmount, uint256 debtAmount)` — MigrationRouter knows flash loan size. redeemCustom takes `(address user, uint256 shares)` — Strategy computes pro-rata internally from fraction. [d:dc-signature]
- **No fees in core** — Performance fees via wrapper later. [d:fees]
- **No rebalance** — Only emergency unwind on drawdown. Simpler for MVP. [d:risk]
- **EIP-1153 transient storage reentrancy lock** — Single slot on Vault, covers depositCustom/redeemCustom/processDeposits/processRedeems/syncRedeem. [d:reentrancy-lock]
- **OZ Ownable2Step, renounce disabled** — Two-step admin transfer, no accidental lockout. [d:admin-transfer]
- **Rounding favors vault** — Round down on mint, round up on burn. [d:rounding]
- **Minimum deposit/redeem amounts** — Admin-settable, anti-dust and rounding protection. Sufficient for first-depositor protection (no dead shares needed). [d:min-amounts, d:first-depositor]
