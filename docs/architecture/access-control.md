# Access Control Matrix

## Roles

- **Admin** -- OZ Ownable2Step, renounce disabled. Can pause, configure parameters, upgrade beacons, set MigrationRouter.
- **Guardian** -- Can pause immediately, force-unwind. Separate from admin for operational flexibility.
- **Keeper** -- Processes epochs, triggers emergency unwind. No admin privileges.
- **MigrationRouter** -- Authorized contract, set by Factory at deployment (updatable by admin). Calls depositCustom/withdrawCustom.
- **User** -- Any address. Deposits, withdrawals, sync redeem, migration (via MigrationRouter).

## Access Matrix

| Function | Contract | Who can call | Guard |
|----------|----------|-------------|-------|
| requestDeposit | Vault | anyone | whenNotPaused, minAmount |
| cancelDeposit | Vault | depositor (own pending) | before epoch settles |
| requestWithdrawal | Vault | shareholder | whenNotPaused, minAmount |
| syncRedeem | Vault | shareholder | minAmount, reentrancyLock (works when paused) |
| reclaimDeposit | Vault | depositor / guardian | after keeper timeout |
| processDepositEpoch | Vault | keeper | onlyKeeper, reentrancyLock |
| processWithdrawalEpoch | Vault | keeper | onlyKeeper, reentrancyLock |
| depositCustom | Vault | MigrationRouter | onlyMigrationRouter, reentrancyLock, whenNotPaused |
| withdrawCustom | Vault | MigrationRouter | onlyMigrationRouter, reentrancyLock, whenNotPaused, no pending withdrawal |
| pause | Vault | admin, guardian | onlyAdminOrGuardian |
| unpause | Vault | admin | onlyAdmin |
| setTolerance | Vault | admin | onlyAdmin, <= 100 bps ceiling |
| setMigrationRouter | Vault | admin | onlyAdmin |
| setMinDepositAmount | Vault | admin | onlyAdmin |
| setMinWithdrawalAmount | Vault | admin | onlyAdmin |
| setGuardian | Vault | admin | onlyAdmin |
| setKeeper | Vault | admin | onlyAdmin |
| forceUnwind | Vault | guardian | onlyGuardian |
| leverage | Strategy | vault | onlyVault |
| unwind | Strategy | vault | onlyVault |
| supplyAndBorrow | Strategy | vault | onlyVault |
| repayAndWithdraw | Strategy | vault | onlyVault |
| onFlashLoan | Strategy | FlashLoanRouter | onlyFlashLoanRouter |
| emergencyUnwind | Strategy | keeper, guardian | onlyKeeperOrGuardian |
| setFlashLoanRouter | Strategy | admin | onlyAdmin |
| getPosition | Strategy | anyone | -- (calls _forceAccrue internally) |
| executeFlashLoan | FlashLoanRouter | Strategy, MigrationRouter | transient storage (sets initiator + active flag) |
| onFlashLoanCallback | FlashLoanRouter | flash loan provider | transient storage validation (active flag set) |
| migrate | MigrationRouter | position owner or approved | user is owner or approved for shares |
| onFlashLoan | MigrationRouter | FlashLoanRouter | onlyFlashLoanRouter (transient storage validated) |
| deploy | Factory | admin | onlyAdmin, on-chain validation |
| setMigrationRouter | Factory | admin | onlyAdmin |
| registerFlashLoanRouter | Factory | admin | onlyAdmin |
| transferOwnership | Vault/Factory | admin | Ownable2Step (propose + accept) |
| renounceOwnership | Vault/Factory | -- | disabled (reverts) |
