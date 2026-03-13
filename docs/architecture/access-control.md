# Access Control Matrix

## Roles

- **Admin** — OZ Ownable2Step, renounce disabled. Can pause, configure parameters, upgrade beacons, set MigrationRouter. Same admin owns all beacons (Vault, Strategy, FlashLoanRouter).
- **Guardian** — Can pause immediately, call Strategy.emergencyRedeem directly. Separate from admin for operational flexibility.
- **Keeper** — Processes epochs, can call Strategy.emergencyRedeem directly. No admin privileges.
- **MigrationRouter** — Authorized contract, set by Factory at deployment (updatable by admin). Calls depositCustom/redeemCustom on Vault.
- **User** — Any address. Deposits, redeems, sync redeem, migration (via MigrationRouter).

## Access Matrix

| Function | Contract | Who can call | Guard |
|----------|----------|-------------|-------|
| requestDeposit | Vault | anyone | whenNotPaused, minAmount |
| cancelDeposit | Vault | request owner | request not yet processed |
| requestRedeem | Vault | shareholder | whenNotPaused, minAmount |
| cancelRedeem | Vault | request owner | request not yet processed |
| syncRedeem | Vault | shareholder | minAmount, reentrancyLock (works when paused) |
| reclaimDeposit | Vault | request owner / guardian | per-user timeout elapsed |
| reclaimRedeem | Vault | request owner / guardian | per-user timeout elapsed |
| processDeposits | Vault | keeper | onlyKeeper, reentrancyLock |
| processRedeems | Vault | keeper | onlyKeeper, reentrancyLock |
| depositCustom | Vault | MigrationRouter | onlyMigrationRouter, reentrancyLock, whenNotPaused |
| redeemCustom | Vault | MigrationRouter | onlyMigrationRouter, reentrancyLock, whenNotPaused, no pending redeem |
| pause | Vault | admin, guardian | onlyAdminOrGuardian |
| unpause | Vault | admin | onlyAdmin |
| setTolerance | Vault | admin | onlyAdmin, <= 100 bps ceiling |
| setMigrationRouter | Vault | admin | onlyAdmin |
| setMinDepositAmount | Vault | admin | onlyAdmin |
| setMinRedeemAmount | Vault | admin | onlyAdmin |
| setGuardian | Vault | admin | onlyAdmin |
| setKeeper | Vault | admin | onlyAdmin |
| deposit | Strategy | vault | onlyVault |
| redeem | Strategy | vault | onlyVault |
| depositCustom | Strategy | vault | onlyVault |
| redeemCustom | Strategy | vault | onlyVault |
| emergencyRedeem | Strategy | keeper, guardian | onlyKeeperOrGuardian (called directly, not through Vault) |
| onFlashLoan | Strategy | FlashLoanRouter | onlyFlashLoanRouter |
| setFlashLoanRouter | Strategy | admin | onlyAdmin |
| setMaxLTV | Strategy | admin | onlyAdmin |
| getPosition | Strategy | anyone | — (calls _forceAccrue internally) |
| executeFlashLoan | FlashLoanRouter | anyone | open access, transient storage (sets initiator + active flag) |
| onFlashLoanCallback | FlashLoanRouter | flash loan provider | transient storage validation (active flag set) |
| migrate | MigrationRouter | position owner or approved | user is owner or approved for shares |
| onFlashLoan | MigrationRouter | FlashLoanRouter | onlyFlashLoanRouter (transient storage validated) |
| deploy | Factory | admin | onlyAdmin, on-chain validation |
| setMigrationRouter | Factory | admin | onlyAdmin |
| registerFlashLoanRouter | Factory | admin | onlyAdmin |
| transferOwnership | Vault/Strategy/Factory | admin | Ownable2Step (propose + accept) |
| renounceOwnership | Vault/Strategy/Factory | — | disabled (reverts) |
