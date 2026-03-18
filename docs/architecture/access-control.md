# Access Control Matrix

> GENERATED FROM q-tree.md — do not edit, regenerate from q-tree.

## Roles

- **Admin** — OZ Ownable2Step, renounce disabled. Can pause, configure parameters, upgrade beacons, set MigrationRouter. Same admin owns all beacons (Vault, Strategy, FlashLoanRouter) [d:beacon-owner].
- **Guardian** — Can pause immediately, call Strategy.emergencyRedeem directly. Separate from admin for operational flexibility.
- **Keeper** — Processes epochs, can call Strategy.emergencyRedeem directly. No admin privileges. Provides FlashLoanRouter per-call.
- **MigrationRouter** — Authorized contract, set by Factory at deployment (updatable by admin). Calls depositCustom/redeemCustom on Vault.
- **User** — Any address. Deposits, redeems, sync redeem, migration (via MigrationRouter). Provides FlashLoanRouter for syncRedeem.

## Access Matrix

| Function | Contract | Who can call | Guard |
|----------|----------|-------------|-------|
| requestDeposit | Vault | anyone | whenNotPaused, minAmount |
| cancelDeposit | Vault | request owner | request not yet fully processed |
| requestRedeem | Vault | shareholder | whenNotPaused, minAmount |
| cancelRedeem | Vault | request owner | request not yet fully processed |
| syncRedeem | Vault | shareholder | minAmount, reentrancyLock, isRegisteredRouter (works when paused) |
| processDeposits | Vault | keeper | onlyKeeper, reentrancyLock, isRegisteredRouter |
| processRedeems | Vault | keeper | onlyKeeper, reentrancyLock, isRegisteredRouter |
| depositCustom | Vault | MigrationRouter | onlyMigrationRouter, reentrancyLock, whenNotPaused |
| redeemCustom | Vault | MigrationRouter | onlyMigrationRouter, reentrancyLock, whenNotPaused, no pending redeem |
| pause | Vault | guardian, admin | onlyGuardianOrAdmin |
| unpause | Vault | admin | onlyAdmin |
| setTolerance | Vault | admin | onlyAdmin, <= toleranceCeiling (100 bps) |
| setMigrationRouter | Vault | admin | onlyAdmin |
| setMinDeposit | Vault | admin | onlyAdmin |
| setMinRedeem | Vault | admin | onlyAdmin |
| setGuardian | Vault | admin | onlyAdmin |
| setKeeper | Vault | admin | onlyAdmin |
| deposit | Strategy | vault | onlyVault |
| redeem | Strategy | vault | onlyVault |
| syncRedeem | Strategy | vault | onlyVault |
| depositCustom | Strategy | vault | onlyVault |
| redeemCustom | Strategy | vault | onlyVault |
| emergencyRedeem | Strategy | keeper, guardian | onlyKeeperOrGuardian, isRegisteredRouter (called directly, not through Vault) |
| onFlashLoan | Strategy | FlashLoanRouter | validates caller is the FlashLoanRouter that was called |
| setMaxLTV | Strategy | admin | onlyAdmin |
| getPosition | Strategy | anyone | — (calls _forceAccrue internally) |
| executeFlashLoan | FlashLoanRouter | anyone | open access, transient storage (sets initiator + active flag) |
| provider callback | FlashLoanRouter | flash loan provider | transient storage validation (active flag set) |
| migrate | MigrationRouter | position owner or approved | user is owner or approved for shares, isRegisteredRouter (via Factory) |
| onFlashLoan | MigrationRouter | FlashLoanRouter | validates via transient storage |
| deploy | Factory | admin | onlyAdmin, on-chain validation |
| setMigrationRouter | Factory | admin | onlyAdmin |
| registerRouter | Factory | admin | onlyAdmin |
| deregisterRouter | Factory | admin | onlyAdmin |
| isRegisteredRouter | Factory | anyone | — (view) |
| transferOwnership | Vault/Strategy/Factory | admin | Ownable2Step (propose + accept) |
| renounceOwnership | Vault/Strategy/Factory | — | disabled (reverts) |

## FlashLoanRouter Validation

FlashLoanRouter is NOT stored on Strategy. It is provided as a parameter per-call and validated against the Factory registry:

| Entry point | Who provides flashLoanRouter | Where validated |
|-------------|------------------------------|-----------------|
| processDeposits | keeper | Vault checks factory.isRegisteredRouter() |
| processRedeems | keeper | Vault checks factory.isRegisteredRouter() |
| syncRedeem | user | Vault checks factory.isRegisteredRouter() |
| emergencyRedeem | keeper/guardian | Strategy checks factory.isRegisteredRouter() |
| migrate | user/caller | MigrationRouter checks factory.isRegisteredRouter() |

## Pause Behavior

| Action | When Paused |
|--------|-------------|
| requestDeposit | BLOCKED |
| requestRedeem | BLOCKED |
| cancelDeposit | ALLOWED |
| cancelRedeem | ALLOWED |
| syncRedeem | ALLOWED (always available, users never trapped) |
| processDeposits | ALLOWED (keeper exempt, processes already-queued) |
| processRedeems | ALLOWED (keeper exempt, processes already-queued) |
| depositCustom | BLOCKED (migration blocked) |
| redeemCustom | BLOCKED (migration blocked) |
| emergencyRedeem | ALLOWED (Strategy-level, keeper/guardian) |
| migrate | BLOCKED (calls depositCustom/redeemCustom) |

## Functions that do NOT exist

- **reclaimDeposit** — removed, cancel covers all scenarios
- **reclaimRedeem** — removed, cancel covers all scenarios
- **forceRedeem (on Vault)** — does not exist; emergency redeem lives on Strategy only
