# Overview

> GENERATED FROM q-tree.md — do not edit, regenerate from q-tree.

Leveraged YBT (yield-bearing token) vault system for EVM. Users deposit a base token (e.g., USDC); a keeper deploys capital with leverage via flash loans — borrowing the base token from a lending protocol (Aave v3 / Morpho Blue / Euler v2), swapping to YBT, and supplying YBT as collateral. Entry and exit happen in single atomic transactions. One vault = one strategy (one YBT + one lending protocol), deployed via a factory. A stateless MigrationRouter enables per-user cross-vault migration without full unwind to base token.

## Key Decisions

- **Vault + Strategy split** — Vault handles accounting (shares, epochs, NAV, pause, sync redeem); Strategy handles all lending/leverage logic via inheritance per protocol. No separate LendingAdapter contract. [d:contracts, d:adapter-ownership]
- **Base token = debt token** — Users deposit and the vault borrows the same token. Simplifies NAV and migration. [d:base-debt-token]
- **Async epoch deposits, dual-path redeems** — Deposits queued and processed by keeper (eliminates oracle arbitrage under leverage). Redeems: async keeper-batched OR sync permissionless (user provides calldata). [d:accounting, d:withdrawal]
- **Partial epoch processing (amount-based)** — processDeposits(amount, swapCalldata, swapRouter, flashLoanRouter) specifies base token amount to deploy; processRedeems(shares, swapCalldata, swapRouter, flashLoanRouter) specifies shares to unwind. Contract iterates FIFO from head, filling requests until amount/shares exhausted. Last request may be partially filled — remainder stays in queue. [d:partial-epoch]
- **Cancel is the only mechanism for unprocessed requests** — cancelDeposit/cancelRedeem. No timeout, no reclaim, no reclaimDeposit/reclaimRedeem. [d:per-user-timeout, d:keeper-timeout]
- **Separate epoch processing** — processDeposits and processRedeems are distinct (opposite token flows cannot combine). [d:epoch-separation]
- **Delta NAV pricing** — Shares priced by measuring NAV before/after keeper deploys capital. Slippage falls on depositing cohort, not existing holders. [d:nav-snap]
- **No internal balance tracking** — Strategy reads actual position from lending protocol (after _forceAccrue). Delta NAV + minimum deposit + reentrancy lock mitigate donation attacks. [d:internal-tracking]
- **_forceAccrue before ALL position reads** — Every flow that reads position calls _forceAccrue() first. [d:accrue-before-snap]
- **Fraction argument** — Strategy receives fraction (scaled to 1e18) instead of (shares, totalSupply). Vault computes fraction = shares * 1e18 / totalSupply. fraction = 1e18 means full position (emergencyRedeem). [d:fraction-arg]
- **Naming: deposit/redeem everywhere** — requestDeposit/requestRedeem (async), syncRedeem (sync), processDeposits/processRedeems (keeper), depositCustom/redeemCustom (migration). Strategy: deposit/redeem (epoch), depositCustom/redeemCustom (migration), emergencyRedeem (full unwind). [d:naming]
- **Emergency redeem on Strategy, not Vault** — Keeper and guardian call Strategy.emergencyRedeem() directly. Vault has NO forceRedeem. [d:keeper-emergency]
- **Max LTV enforcement** — Strategy.deposit checks post-leverage LTV against maxLTV on deposit and depositCustom. [d:max-ltv]
- **Oracle-floor swap verification** — All swaps checked: received >= oracleValue(sent) * (1 - toleranceBps). Per-vault tolerance, hard ceiling 100 bps. [d:invariant, d:tolerance-params]
- **Only zero-fee flash loan providers** — Non-zero fee would make entry/exit prohibitively expensive. [d:flash-fee]
- **Sync permissionless redeem always available** — Works even when paused. Users are never locked in. [d:sync-redeem, d:pause-exit]
- **Beacon proxy upgradeability** — 1 Vault beacon + N Strategy beacons (per protocol). Same admin as Factory owns all beacons. [d:vault-beacon, d:beacon-owner]
- **FlashLoanRouter selection per-call** — Strategy does NOT store a FlashLoanRouter address. Keeper provides it as parameter in processDeposits/processRedeems; user provides it in syncRedeem; caller provides it in migrate. Validated against Factory admin-managed registry (factory.isRegisteredRouter). Allows keeper to pick best provider per-call without admin intervention. [d:flr-selection]
- **Factory manages FlashLoanRouter registry** — Admin registers/deregisters approved FlashLoanRouters via Factory.registerRouter/deregisterRouter. All entry points validate the provided router against this registry. [d:flr-selection, d:new-flashloan]
- **FlashLoanRouter open access** — Anyone can call executeFlashLoan(). Security relies on transient storage callback validation. [d:flr-access]
- **FlashLoanRouter per provider** — Normalizes flash loan callbacks via EIP-1153 transient storage. No persistent state beyond config. No token residual. Single flash loan at a time. [d:flash-callback, d:flr-invariants, d:flr-state]
- **MigrationRouter is stateless and immutable** — Calls FlashLoanRouter directly (not via Strategy). Flash loan amount = shares/totalSupply * actualDebt (after _forceAccrue). Caller provides flashLoanRouter. [d:migration, d:migration-flash-source, d:migration-flash-amount]
- **redeemCustom token flow** — MigrationRouter transfers baseToken to Strategy before calling redeemCustom. [d:redeem-custom-flow]
- **depositCustom takes explicit debtAmount** — depositCustom(address user, uint256 collateralAmount, uint256 debtAmount). redeemCustom takes (address user, uint256 shares) — Vault computes fraction. [d:dc-signature]
- **No fees in core** — Performance fees via wrapper later. [d:fees]
- **No rebalance** — Only emergency unwind on drawdown. Simpler for MVP. [d:risk]
- **EIP-1153 transient storage reentrancy lock** — Single slot on Vault, mutual exclusion for depositCustom/redeemCustom/processDeposits/processRedeems/syncRedeem. [d:reentrancy-lock]
- **OZ Ownable2Step, renounce disabled** — Two-step admin transfer, no accidental lockout. [d:admin-transfer]
- **Rounding favors vault** — Round down on mint, round up on burn. [d:rounding]
- **Minimum deposit/redeem amounts** — Admin-settable, anti-dust and rounding protection. Sufficient for first-depositor protection (no dead shares needed). [d:min-amounts, d:first-depositor]
- **Swap calldata margin** — Caller builds calldata with slightly smaller amountIn; residual dust stays in Strategy. [d:swap-margin]
