# Overview

Leveraged DeFi vault system that buys yield-bearing tokens (YBT) with leverage using flash loans and liquidity from Aave, Morpho, or Euler. One vault = one strategy (specific YBT + lending protocol pair). Entry and exit happen atomically in single transactions via flash loans. Users deposit base tokens, a keeper deploys capital with leverage, and users receive shares representing their proportional claim on the leveraged position. Supports per-user liquidity migration between compatible vaults without full unwind to base token.

## Key Decisions

- **Vault + Strategy split** -- Vault handles accounting (shares, epochs, NAV, pause, sync redeem); Strategy handles all lending/leverage logic via inheritance per protocol. No separate LendingAdapter contract. [d:contracts, d:adapter-ownership]
- **Base token = debt token** -- Users deposit and the vault borrows the same token. Simplifies NAV and migration. [d:base-debt-token]
- **Async epoch deposits, dual-path withdrawals** -- Deposits queued and processed by keeper (eliminates oracle arbitrage under leverage). Withdrawals: async keeper-batched OR sync permissionless redeem (user provides calldata). [d:accounting, d:withdrawal]
- **Separate epoch processing** -- processDepositEpoch and processWithdrawalEpoch are distinct (opposite token flows cannot combine). [d:epoch-separation]
- **Delta NAV pricing** -- Shares priced by measuring NAV before/after keeper deploys capital. Slippage falls on depositing cohort, not existing holders. [d:nav-snap]
- **Internal balance tracking** -- Strategy tracks collateral/debt internally (not via balanceOf). Neutralizes donation attacks. [d:internal-tracking]
- **Oracle-floor swap verification** -- All swaps checked: `received >= oracleValue(sent) * (1 - toleranceBps)`. Per-vault tolerance, hard ceiling 100 bps. [d:invariant, d:tolerance-params]
- **Sync permissionless redeem always available** -- Works even when paused. Users are never locked in. [d:sync-redeem, d:pause-exit]
- **Beacon proxy upgradeability** -- 1 Vault beacon + N Strategy beacons (per lending protocol) + N FlashLoanRouter beacons (per provider). [d:vault-beacon]
- **FlashLoanRouter per provider** -- Normalizes flash loan callbacks via EIP-1153 transient storage. Stores initiator address in transient storage, validates callback origin, forwards to initiator.onFlashLoan(). No persistent state beyond config. No token residual. Single flash loan at a time. [d:flash-callback, d:flr-invariants, d:flr-state]
- **Flash loan callback flow** -- Provider calls FlashLoanRouter.callback(), router validates via transient storage, calls initiator.onFlashLoan() where initiator is Strategy or MigrationRouter. [d:flash-callback]
- **MigrationRouter is stateless and immutable** -- Calls FlashLoanRouter directly (not via Strategy). Implements onFlashLoan(). Computes flash loan amount from source vault: shares/totalSupply * trackedDebt. Set by Factory; swappable via admin. [d:migration, d:migration-flash-source, d:migration-flash-amount]
- **depositCustom takes explicit debtAmount** -- MigrationRouter passes debt amount (knows flash loan size). withdrawCustom uses pro-rata from shares. [d:dc-signature]
- **No fees in core** -- Performance fees via wrapper later. [d:fees]
- **No rebalance** -- Only emergency unwind on drawdown. Simpler for MVP. [d:risk]
- **EIP-1153 transient storage reentrancy lock** -- Single slot on Vault, covers depositCustom/withdrawCustom/processEpoch/syncRedeem. [d:reentrancy-lock]
- **OZ Ownable2Step, renounce disabled** -- Two-step admin transfer, no accidental lockout. [d:admin-transfer]
- **Rounding favors vault** -- Round down on mint, round up on burn. [d:rounding]
- **Minimum deposit/withdrawal amounts** -- Admin-settable, anti-dust and rounding protection. Sufficient for first-depositor protection (no dead shares needed). [d:min-amounts, d:first-depositor]
- **Interest accrual before NAV snapshot** -- Strategy._forceAccrue() before navBefore in depositCustom, processEpoch, and syncRedeem. [d:accrue-before-snap]
- **Keeper timeout + user reclaim** -- If epoch not processed within timeout, users can reclaim deposits. [d:keeper-timeout]
