# Q-Tree: Leveraged YBT Vaults

> Goal: Leveraged DeFi vault that buys YBT (yield-bearing tokens) with leverage using liquidity from Aave/Morpho/Euler (extensible). Entry/exit via flash loan in a single transaction. One vault = one strategy, but many vaults can be created with different YBT and lending protocols. Support liquidity migration between compatible strategies without full unwind to base token (e.g., PT-sUSDe/USDe → sUSDe/USDe).
>
> Resolved: 69 | Suggested: 0 | Open: 0

Markers: ✓ confirmed | → suggested | ? open | ~ auto | ✗ removed

## Tree

- ✓ Leveraged YBT Vault Architecture
  - ✓ Contract decomposition → Vault (accounting) + Strategy (abstract + inheritance, orchestrates leverage) + MigrationRouter + Factory + FlashLoanRouter (per provider, interface adapters) [d:contracts]
    - ✓ Concrete contracts → Vault, Strategy, MigrationRouter, Factory, FlashLoanRouter [d:contract-list]
    - ✓ Leverage orchestration → Strategy orchestrates everything, vault only accounting [d:orchestration]
    - ✓ Adapter ownership → No separate LendingAdapter, inline in Strategy via inheritance [d:adapter-ownership]
  - ✓ Leverage mechanism → Flash loan single-tx: borrow, buy YBT, supply, borrow to repay [d:leverage-flow]
    - ✓ Base token = debt token → Always the same token, vault deposits and borrows same asset [d:base-debt-token]
  - ✓ Share accounting and NAV → Async epochs, keeper provides calldata, shares auto-sent [d:accounting]
    - ✓ NAV snapshot timing → Delta NAV post-leverage, fair to existing holders [d:nav-snap]
    - ✓ Pending deposits treatment → Idle in vault, no shares, no yield [d:idle-funds]
    - ✓ Cancel pending deposit → Yes, before epoch settles [d:cancel]
    - ✓ Keeper liveness fallback → Timeout + user self-serve reclaim [d:keeper-timeout]
    - ✓ Epoch queue separation → Separate processEpoch calls for deposits vs withdrawals [d:epoch-separation]
  - ✓ YBT acquisition abstraction → Keeper provides calldata+router, contracts verify no losses [d:ybt-types]
  - ✓ Cross-strategy migration → Atomic collateral swap, per-user, via MigrationRouter [d:migration]
    - ✓ Migration authorization → Position owner or approved address initiates [d:migration-auth]
    - ✓ Destination vault intake → depositCustom: accepts collateral, supplies, borrows debt back to caller, mints shares via delta NAV [d:migration-deposit]
      - ✓ depositCustom/withdrawCustom access → Only MigrationRouter, set by factory [d:dc-access]
      - ✓ depositCustom signature → Needs explicit debtAmount param; withdrawCustom uses pro-rata from shares [d:dc-signature]
      - ✓ Oracle protection for sync delta NAV [d:dc-oracle]
        - ✓ Arithmetic NAV validation → expectedDelta = oracleValue(collateral) - debt, revert on deviation [d:arith-nav]
        - ✓ Interest accrual before position read → must have, Strategy._forceAccrue() before ANY position read [d:accrue-before-snap]
      - ✓ Reentrancy protection [d:dc-reentrancy]
        - ✓ Transient storage lock → Vault-level EIP-1153, covers depositCustom/withdrawCustom/processEpoch/syncRedeem [d:reentrancy-lock]
    - ✓ Migration granularity → Per-user opt-in [d:migration-scope]
    - ✓ MigrationRouter upgrade path → Immutable, Factory.setMigrationRouter updates for new vaults [d:migration-router-upgrade]
    - ✓ Migration flash loan source → MigrationRouter calls FlashLoanRouter directly, not via Strategy [d:migration-flash-source]
    - ✓ Migration flash loan amount → Computed from source vault: shares/totalSupply * actualDebt (after _forceAccrue) [d:migration-flash-amount]
  - ✓ Withdrawal flow → Dual path: async epochs (keeper batched) + sync permissionless redeem (user calldata) [d:withdrawal]
    - ✓ Async withdrawal → Async epoch, proportional, keeper batches [d:wd-async]
    - ✓ Who provides unwind calldata → Keeper for async; user for sync redeem [d:wd-calldata]
    - ✓ Partial withdrawal support → Share-denominated partial, pro-rata unwind [d:wd-partial]
    - ✗ Share timelock → Not needed, depositCustom restricted to MigrationRouter [d:wd-timelock]
    - ✓ Sync permissionless redeem → User provides calldata, pays own gas/slippage, always available [d:sync-redeem]
  - ✓ Fee model → No fees, can add performance fee later via wrapper [d:fees]
  - ✓ Emergency / pause mechanics → Guardian + admin, simplified by sync redeem [d:emergency]
    - ✓ Pause scope → Deposits and migrations stopped; keeper exempt; sync redeem always works [d:pause-scope]
    - ✓ Who can pause → Guardian + admin (governance via OZ timelock later) [d:pause-auth]
    - ✓ User recourse when paused → Sync permissionless redeem (always available) + guardian force-unwind [d:pause-exit]
    - ✓ Force-unwind without keeper → Guardian provides calldata, no delay needed [d:force-unwind]
    - ✓ Force-unwind delays → Not needed, sync redeem + async redeemRequest provide exit paths [d:force-unwind-delays]
  - ✓ Swap/loss verification → Oracle-derived floor check on all swaps [d:verification]
    - ✓ "No losses" invariant → received >= oracleValue * (1 - toleranceBps) [d:invariant]
    - ✓ Tolerance configuration → Per-vault, ceiling 100 bps, different oracles/slippage per pair [d:tolerance-params]
    - ✓ Oracle scope → Reuse NAV oracle for swap floor check [d:oracle-scope]
    - ✓ Migration swap verification → MigrationRouter verifies YBT conversion output [d:migration-verify]
  - ✓ LTV and liquidation risk management → Emergency unwind only, no rebalance [d:risk]
  - ✓ Protocol extensibility [d:extensibility]
    - ✓ Adding new lending protocols → New Strategy subclass + beacon + factory registration [d:new-protocol]
    - ✓ Adding new flash loan providers → New FlashLoanRouter + admin registers in Factory, keeper picks per-call [d:new-flashloan]
    - ✓ FlashLoanRouter invariants → No token residual, callback validated via transient storage, single at a time [d:flr-invariants]
    - ✓ FlashLoanRouter state → Transient storage for callback validation, no persistent state beyond config [d:flr-state]
    - ✓ Flash loan callback flow → Provider → FlashLoanRouter → initiator.onFlashLoan() (Strategy or MigrationRouter) [d:flash-callback]
    - ✓ Vault upgradeability → Beacon proxy, same pattern as Strategy [d:vault-beacon]
  - ✓ Access control details [d:access-details]
    - ✓ Admin transfer/renounce → OZ Ownable2Step, renounce disabled [d:admin-transfer]
  - ✓ Sync redeem idle mode → Skip flash loan, return shares/totalSupply * idleBase [d:sync-idle]
  - ✓ Partial migration → Yes, user specifies share count [d:partial-migration]
  - ✓ Factory deployment validation → Oracle reachable, market valid, tolerance <= ceiling, token match [d:factory-validation]
  - ✗ Donation attack protection → Internal tracking removed; delta NAV + min deposit + reentrancy sufficient [d:internal-tracking]
  - ✓ Rounding direction → Round down mint, round up burn (favor vault) [d:rounding]
  - ✓ Minimum amounts → Admin-settable min for deposit and withdrawal, anti-dust + rounding protection [d:min-amounts]
  - ✓ First-depositor protection → Minimum deposit sufficient, dead shares not needed [d:first-depositor]
  - ✓ Naming convention → deposit/redeem terminology throughout Vault and Strategy [d:naming]
  - ✓ Strategy fraction argument → Strategy receives fraction (of 1e18) instead of shares/totalSupply [d:fraction-arg]
  - ✓ Flash loan providers → only zero-fee providers (Balancer, Morpho, etc.) [d:flash-fee]
  - ✓ Swap calldata margin → Caller builds calldata with margin, oracle-floor check validates output [d:swap-margin]
  - ✓ Partial epoch processing → Amount-based, FIFO, partial fills of last request [d:partial-epoch]
  - ✗ Per-user timeout → Removed, cancel covers all scenarios [d:per-user-timeout]
  - ✓ Emergency redeem entry point → Keeper and guardian call Strategy.emergencyRedeem directly, no Vault wrapper [d:keeper-emergency]
  - ✓ Max leverage ratio → Strategy.deposit checks post-leverage LTV, per-vault param, admin-settable [d:max-ltv]
  - ✓ FlashLoanRouter per-provider callbacks → Implementation detail, architecture defines normalized interface only [d:flr-callbacks]
  - ✓ Oracle interface → Implementation detail (ADR DT-002 covers OracleRouter + IPriceFeed) [d:oracle-interface]
  - ✓ FlashLoanRouter selection → Keeper picks per-call from Factory registry, not stored on Strategy [d:flr-selection]
  - ✓ FlashLoanRouter.executeFlashLoan access → Open (anyone can call), transient storage callback validation sufficient [d:flr-access]
  - ✓ Beacon ownership → Same admin as Factory, single owner for all beacons [d:beacon-owner]
  - ✓ redeemCustom token flow → MigrationRouter transfers baseToken to Strategy before calling redeemCustom [d:redeem-custom-flow]

## Details

### [d:contracts] Contract Decomposition
- Vault — accounting only: ERC20 shares, epoch queue, NAV calculation, pause logic, sync redeem.
- Strategy — abstract base + inheritance per lending protocol (AaveStrategy, MorphoStrategy, EulerStrategy). Handles everything strategy-specific: leverage, unwind, emergency unwind, supply, borrow, repay, withdraw. Orchestrates flash loan flow internally.
- MigrationRouter — stateless, orchestrates cross-vault migration. Set by factory.
- Factory — deploys vault + strategy pairs. Registry. Sets MigrationRouter.
- FlashLoanRouter — possibly one per flash loan provider (Aave, Balancer, Morpho). Just normalizes to a common callback interface. Strategy calls the appropriate one.
- No separate LendingAdapter — lending logic is inline in Strategy via inheritance. May extract later if contract size becomes an issue.

### [d:contract-list] Concrete Contracts
- Vault: user-facing, accounting, epochs, NAV, pause, sync redeem
- Strategy (abstract): leverage orchestration, flash loan callback, swap execution, lending protocol calls
  - AaveStrategy extends Strategy
  - MorphoStrategy extends Strategy
  - EulerStrategy extends Strategy
- FlashLoanRouter: per-provider interface adapter (normalizes flash loan callback)
- MigrationRouter: stateless cross-vault migration orchestrator
- Factory: deployment, registry, configuration

### [d:orchestration] Leverage Orchestration
- Strategy orchestrates everything — keeper calls vault.processEpoch(calldata), vault calls strategy.leverage(calldata), Strategy internally: takes flash loan via FlashLoanRouter → swaps base→YBT → supplies to lending → borrows → repays flash loan.
- Vault only knows: "call strategy with this calldata, then measure NAV delta."
- Strategy is self-contained — knows lending protocol, swap routing, flash loan sourcing.

### [d:adapter-ownership] No Separate LendingAdapter
- Lending logic (supply, borrow, repay, withdraw) lives directly in Strategy via inheritance.
- Each Strategy implementation knows its lending protocol's interface.
- Strategy contract is the position owner in the lending protocol.
- Simpler architecture, fewer contracts, fewer cross-contract calls.
- Trade-off: Strategy is a larger contract. Acceptable for now — extract if bytecode limit approached.

### [d:base-debt-token] Base Token = Debt Token
- Base token (what users deposit) and debt token (what is borrowed from lending protocol) are always the same token.
- Example: user deposits USDC, vault borrows USDC from Aave to buy YBT. Flash loan repaid in USDC.
- This constraint simplifies migration (same debt token requirement already assumed) and NAV calculation.

### [d:leverage-flow] Flash Loan Leverage Mechanism
- Flash loan single-tx — borrow full amount via flash loan, buy YBT, supply as collateral, borrow from lending protocol to repay flash loan. One atomic transaction.
- Unwind is the reverse — flash loan repays debt, withdraw collateral, sell YBT, repay flash loan.
- Flash loan sourcing handled by Strategy via FlashLoanRouter.

### [d:accounting] Share Accounting and NAV Model
- Async epoch-based — user requests deposit, keeper executes leverage with calldata at epoch boundary, shares minted post-leverage at realized NAV. Eliminates oracle arbitrage.
- Keeper provides swap calldata (routing, slippage) — contracts don't need to know swap paths.
- Shares auto-sent to depositors after keeper processes epoch — no claim step needed.
- Key advantage: leverage amplifies oracle error, so async with realized prices is safer than sync with oracle prices.

### [d:nav-snap] NAV Snapshot Timing
- Delta NAV post-leverage — measure NAV before keeper deploys, then after. New shares = deposit amount / (NAV_after - NAV_before) normalized.
- Fair to existing holders: slippage and swap costs fall on the depositing cohort, not existing shareholders.

### [d:idle-funds] Treatment of Pending Deposits
- Idle in vault — no yield, no risk. totalAssets() excludes pending queue.
- No shares issued until keeper processes epoch — depositors bear no vault risk while waiting.

### [d:cancel] Cancellation of Pending Requests
- Cancel before epoch settles — user withdraws pending request before keeper starts processing. Zero-cost, clean revert.
- After processEpoch() starts, cancellation impossible — funds in flight.

### [d:epoch-separation] Epoch Queue Separation
- Deposits and withdrawals require separate processEpoch calls — cannot be batched together.
- processDeposits() and processRedeems() are distinct functions.
- Reason: deposit leverages up (flash loan → buy YBT → supply → borrow), withdrawal unwinds (opposite direction). Opposite token flows cannot be combined.

### [d:keeper-timeout] Keeper Liveness Fallback
- User can cancel any unprocessed request at any time via cancelDeposit/cancelRedeem.
- No timeout or reclaim mechanism needed — cancel is always available for unprocessed requests.
- No permissionless settle — too risky (MEV/sandwich without keeper routing optimization).
- Note: with sync permissionless redeem, keeper liveness is less critical for exits (only affects deposits).

### [d:ybt-types] YBT Types and Acquisition
- Keeper provides calldata and router address for YBT acquisition.
- Contracts verify no losses — check that received YBT value matches expected value within tolerance.
- This keeps vault agnostic to YBT type (Pendle PT, ERC4626, LST) — keeper handles routing complexity off-chain.

### [d:migration] Cross-Strategy Migration
- Per-user opt-in migration via MigrationRouter + atomic flash loan transaction.
- Flow: user calls MigrationRouter → flash loan → router calls withdrawCustom on vault A (repay debt, withdraw collateral) → convert YBT if needed → router calls depositCustom on vault B (supply collateral, borrow debt back) → repay flash loan.
- Compatibility: migration between vaults with related YBT (e.g., PT-sUSDe → sUSDe) avoids full unwind to base token.
- Constraint: source and destination vaults must share the same debt token.
- MigrationRouter is set by factory — same router for all vaults.

### [d:migration-auth] Migration Authorization
- Position owner (shareholder) initiates migration, or an approved address on their behalf.
- No governance gate — user has sovereignty over their own position.

### [d:migration-deposit] Destination Vault Intake — depositCustom
- depositCustom: restricted to MigrationRouter only.
- Vault calls strategy to supply collateral to lending protocol, borrow debt token, send debt back to MigrationRouter.
- Mints shares immediately based on delta NAV (sync, within migration context).
- withdrawCustom: inverse — MigrationRouter provides debt token, strategy repays debt, withdraws collateral, sends to router, vault burns shares pro-rata (shares/totalSupply * totalCollateral).
- Precondition: withdrawCustom reverts if user has pending withdrawal requests.

### [d:dc-signature] depositCustom/withdrawCustom Signatures
- depositCustom(address user, uint256 collateralAmount, uint256 debtAmount) — MigrationRouter passes explicit debt amount (knows flash loan size). Strategy supplies collateral, borrows debtAmount, sends debt back to caller.
- withdrawCustom(address user, uint256 shares) — no debtAmount needed. Strategy computes pro-rata: shares/totalSupply * trackedDebt for repay, shares/totalSupply * trackedCollateral for withdraw.
- Arithmetic NAV validation for depositCustom: expectedDelta = oracleValue(collateralAmount) - debtAmount.

### [d:dc-access] depositCustom/withdrawCustom Access Control
- Only callable by MigrationRouter contract, set by factory at deployment.
- Users interact via MigrationRouter (permissionless for users, restricted at vault level).
- Eliminates need for share timelock, reduces oracle arbitrage surface, simplifies reentrancy model.

### [d:dc-oracle] Oracle Protection for Sync Delta NAV
- Arithmetic NAV validation + interest accrual before snapshot.
- No separate circuit breaker needed — restricted caller (MigrationRouter) + arithmetic check covers the risk.

### [d:arith-nav] Arithmetic NAV Validation for depositCustom
- After strategy executes supply+borrow, compute expectedDelta = oracleValue(collateralSupplied) - debtBorrowed.
- Compare to actual navAfter - navBefore. Revert if deviation > roundingToleranceBps (e.g., 5-10 bps).
- Strictly stronger and cheaper than circuit breaker — we know exactly what went in and came out.
- Catches: oracle manipulation between snapshots, unexpected protocol fees, accounting bugs.

### [d:accrue-before-snap] Interest Accrual Before Position Read
- Must have — lazy accrual in lending protocols means position reads can return stale data (missing accrued interest on debt/collateral).
- Strategy calls _forceAccrue() before ANY read of position from lending protocol.
- Each Strategy subclass implements protocol-specific accrual (Aave forceUpdateReserves, Morpho accrueInterest, Euler touch).
- Applies to ALL flows that read position: processDepositEpoch, processWithdrawalEpoch, syncRedeem, depositCustom, withdrawCustom, emergencyUnwind, forceUnwind, and any NAV/position query used for migration flash loan amount computation.
- Without _forceAccrue: delta NAV could include interest that accrued during the tx (belongs to existing holders, not new depositors). Pro-rata calculations could use stale debt amounts.

### [d:dc-reentrancy] Reentrancy Protection
- EIP-1153 transient storage lock on Vault + CEI ordering.

### [d:reentrancy-lock] Transient Storage Lock Scope
- Single EIP-1153 transient storage slot on Vault.
- Set at entry of depositCustom/withdrawCustom/processEpoch/syncRedeem. Mutual exclusion group.
- CEI ordering within each function.
- Lock on Vault only (not Strategy) — Strategy called by Vault, so Vault lock covers entire call tree.
- Consistent with FlashLoanRouter (also uses EIP-1153). Cheaper than OZ ReentrancyGuard.

### [d:migration-router-upgrade] MigrationRouter Upgrade Path
- MigrationRouter is immutable (no beacon proxy, no upgradeability).
- Factory stores current MigrationRouter address. Admin calls Factory.setMigrationRouter(newRouter) to update.
- New vaults deployed after the update use the new router. Existing vaults keep the old router address (set at deployment).
- To update existing vaults: admin calls vault.setMigrationRouter() (or similar admin function).
- Simple approach — MigrationRouter is stateless, so swapping it is low-risk.

### [d:migration-scope] Migration Granularity
- Per-user — each user migrates individually when they choose via MigrationRouter.
- User's shares in vault A are burned (withdrawCustom returns collateral + accepts debt repayment), then deposited into vault B (depositCustom).

### [d:withdrawal] Withdrawal Flow
- Dual path:
  - Async epoch (keeper batched) — cheaper, keeper optimizes routing, batches multiple users.
  - Sync permissionless redeem — user provides calldata, pays own gas/slippage, always available.
- User chooses: wait for epoch (cheaper) or exit immediately (more expensive).

### [d:wd-async] Async Withdrawal
- Async epoch — user requests withdrawal specifying shares. Keeper batches all withdrawal requests, unwinds proportional position with optimal calldata, distributes base tokens pro-rata.
- Proportional fairness: all withdrawers in same epoch share the same execution price/slippage.
- Shares escrowed (transferred to vault) at request time — prevents double-exit via simultaneous sync redeem.

### [d:wd-calldata] Unwind Calldata Provider
- Async: keeper provides unwind calldata, contracts verify no-loss invariant.
- Sync redeem: user provides calldata, same oracle-floor check applies.

### [d:wd-partial] Partial Withdrawal
- Share-denominated — user specifies shares to withdraw (both async and sync paths).
- Avoids oracle dependency at request time.
- Post-unwind LTV health check (though proportional exit preserves LTV).

### [d:wd-timelock] Share Timelock
- Not needed — depositCustom restricted to MigrationRouter, no standalone sync minting possible.
- Epoch-minted shares already have natural delay.

### [d:sync-redeem] Sync Permissionless Redeem
- User calls syncRedeem(shares, calldata) — burns shares from wallet, unwinds proportional position using provided calldata.
- Pro-rata: user gets shares/totalSupply proportion of collateral and debt. No oracle needed for split.
- User's calldata executes: flash loan to repay proportional debt → withdraw proportional collateral → sell YBT → repay flash loan → send base token to user.
- Oracle-floor check applies to the swap (same invariant as keeper path).
- Always available — works even when vault is paused. Users are never locked in.
- LTV safe: proportional exit preserves LTV ratio for remaining users.
- Reentrancy: covered by vault-level EIP-1153 lock.
- _forceAccrue before reading position balances (same as depositCustom/processEpoch).
- Does not affect pending deposit requests — user must cancel those separately for full exit.
- No conflict with escrowed async withdrawal shares — those are already transferred to vault, not in user's wallet.
- Trade-off: user pays own gas + may get worse execution than keeper-batched path.
- Benefit: eliminates keeper dependency for exits, users self-serve.

### [d:fees] Fee Model
- No fees in the core vault contract.
- Performance fees can be added later via a wrapper contract around the vault.
- Simplifies core vault logic and NAV calculation (no fee crystallization to worry about).

### [d:emergency] Emergency / Pause Mechanics
- Guardian + admin roles for emergency actions. No governance in scope for now.
- Governance can be layered on top later via OZ TimelockController as admin.
- Simplified by sync redeem: users can always exit, even when paused. No fund lockup.

### [d:pause-scope] Pause Scope
- When paused: new deposits blocked, new async withdrawal requests blocked, migrations blocked.
- Keeper exempt — can still process already-queued epochs and trigger emergency unwind.
- Sync permissionless redeem always works — even when paused. Users are never trapped.

### [d:pause-auth] Who Can Pause
- Guardian pauses immediately in emergencies.
- Admin can also pause.
- Governance out of scope for now — can add OZ TimelockController as admin later.

### [d:pause-exit] User Recourse When Paused
- Sync permissionless redeem — always available, user provides calldata to exit.
- Guardian force-unwind — guardian provides calldata to unwind entire position if needed.
- No complex escalation tiers needed — sync redeem eliminates the "trapped funds" problem.

### [d:force-unwind] Force-Unwind Without Keeper
- Guardian provides calldata — same interface as keeper. Oracle-floor check protects against bad calldata.
- Only needed for full vault unwind (e.g., protocol compromise). Individual users can always sync redeem.
- No delay needed — sync redeem is always available as alternative exit. Guardian force-unwind is for full vault shutdown.

### [d:force-unwind-delays] Force-Unwind Delays
- Not needed — with sync permissionless redeem always available, users are never trapped.
- Exit paths: (1) sync redeem with own calldata, (2) async redeemRequest processed by keeper.
- Guardian force-unwind is only for full vault shutdown, not user rescue. No escalation tiers needed.

### [d:verification] Swap/Loss Verification
- Oracle-derived floor check on all swaps (deposit epoch, withdrawal epoch, sync redeem, migration).
- Per-vault tolerance parameter — different oracles and realistic slippage vary by pair.

### [d:invariant] "No Losses" Invariant Definition
- Concrete: `amountReceived >= oracleValue(amountSent) * (10000 - toleranceBps) / 10000`
- oracleValue() converts between tokens using vault's oracle (same as NAV).
- Catches: bad keeper/user calldata, sandwich attacks, manipulated pools.
- Applied uniformly: keeper epoch path, sync redeem path, migration path.

### [d:tolerance-params] Tolerance Configuration
- Per-vault — different trading pairs have different realistic slippage (stablecoin swap vs PT-ETH).
- Admin-settable with hard ceiling of 100 bps (1%) to prevent misconfiguration.
- Keeper/user optimizes routing off-chain within this bound.

### [d:oracle-scope] Oracle Scope for Verification
- Reuse same oracle vault uses for NAV calculation.
- Oracle used only as safety floor ("did we get at least this much?"), NOT for pricing shares (delta NAV handles that).
- Even if oracle slightly stale, doesn't affect share pricing — only swap minimum threshold.

### [d:migration-verify] Migration Swap Verification
- Same YBT on both sides: no swap needed, no verification.
- Different YBT (e.g., PT-sUSDe → sUSDe): MigrationRouter converts mid-flight, applies oracle-floor check.
- Uses source vault oracle for outgoing YBT, destination vault oracle for incoming.

### [d:risk] Liquidation Risk and LTV Management
- No rebalance — only emergency unwind. Keeper triggers emergency unwind on drawdown or dangerously low health factor.
- Emergency unwind = full position unwind (same as force-unwind flow). No partial LTV adjustment.
- Guardian role as last-resort — can pause and force-unwind if keeper fails.
- Hard limits at entry — vault enforces max leverage ratio.
- Post-operation LTV health check on migration — reverts if remaining LTV exceeds safety threshold.
- Sync redeem preserves LTV (proportional exit), so no LTV risk from individual exits.
- Rationale: rebalance adds complexity (partial unwind/re-leverage paths), and emergency unwind is simpler + sufficient for MVP.

### [d:extensibility] Protocol Extensibility
- Existing architecture supports clean extensibility via Strategy inheritance + beacon proxy + factory.

### [d:new-protocol] Adding New Lending Protocols
- Process: write new Strategy subclass → deploy new beacon → register in Factory → Factory deploys vault+strategy pairs.
- No Vault changes needed (Vault is protocol-agnostic).
- No existing vault upgrades needed (new protocol = new deployments only).
- Beacon upgrade for bug fixes — admin upgrades beacon, all vaults of that type update atomically.

### [d:new-flashloan] Adding New Flash Loan Providers
- Process: write new FlashLoanRouter → deploy → admin registers in Factory registry.
- Keeper picks which registered FlashLoanRouter to use per-call (parameter in processDeposits/processRedeems/syncRedeem).
- Strategy does NOT store a FlashLoanRouter address — validated against Factory registry at call time.
- Flexibility: keeper chooses provider with best liquidity. If one provider is down, switch to another without admin action.
- Beacon proxy for FlashLoanRouter — upgrade fixes bugs across all instances.

### [d:vault-beacon] Vault Upgradeability
- Vault deployed as beacon proxy — same pattern as Strategy.
- One Vault beacon shared by all vaults. Admin upgrades beacon → all vault proxies update atomically.
- Allows bug fixes and feature additions without user migration.
- Total beacons: 1 Vault + N Strategy (one per lending protocol) + N FlashLoanRouter (one per provider).

### [d:admin-transfer] Admin Transfer and Renounce
- OZ Ownable2Step — two-step transfer (propose + accept) prevents accidental transfer to wrong address.
- Renounce disabled — admin role cannot be renounced. Prevents accidental lockout.
- Admin can transfer to a multisig or TimelockController when governance is added later.

### [d:access-details] Access Control Details
- Admin: Ownable2Step, non-renounceable. Can pause, set tolerance, upgrade beacons, set MigrationRouter.
- Guardian: can pause immediately. Separate from admin for operational flexibility.
- Keeper: processes epochs, triggers emergency unwind. No admin privileges.

### [d:sync-idle] Sync Redeem Idle Mode
- When position is fully unwound (zero collateral, zero debt, only idle base remains):
  - Skip flash loan entirely — no debt to repay, no collateral to withdraw.
  - Return shares/totalSupply * idleBase directly to user.
  - Same syncRedeem function, just a conditional path: if no position, simple pro-rata of idle balance.
- Triggered after guardian force-unwind converts entire position to base.

### [d:partial-migration] Partial Migration
- User can migrate a subset of shares — specifies share count to MigrationRouter.
- Keeps a position in both source and destination vaults.
- withdrawCustom burns only the specified shares, withdraws proportional collateral/debt.
- depositCustom on destination mints new shares for the migrated portion.

### [d:factory-validation] Factory Deployment Validation
- On-chain validation during vault+strategy deployment. Factory reverts if any check fails.
- Checks: oracle reachable (returns valid price), lending market valid (exists, accepts collateral), toleranceBps <= 100 bps ceiling, base token matches debt token in lending market.
- Catches misconfigurations at deploy time rather than at first user deposit.
- No off-chain trust — all validation runs in the deployment transaction.

### [d:internal-tracking] Donation Attack Protection (Internal Tracking Removed)
- REMOVED: internal balance tracking was originally proposed but is unnecessary.
- Delta NAV pricing makes donation non-exploitable: donation before navBefore inflates both navBefore and navAfter equally → delta unchanged. Donation between navBefore/navAfter prevented by reentrancy lock.
- Sync redeem donation: attacker donates to inflate NAV, then redeems. Net gain = donation * (shares/totalSupply - 1) → negative. Attacker loses money.
- NAV now reads actual position from lending protocol (after _forceAccrue): oracleValue(actualCollateral) - actualDebt.
- Benefits: simpler architecture, interest automatically reflected in NAV, no sync issues.
- Protections sufficient without internal tracking: delta NAV + minimum deposit + reentrancy lock + _forceAccrue.

### [d:rounding] Rounding Direction Policy
- Round down on share minting — depositor gets fewer shares (vault keeps dust).
- Round up on share burning — withdrawer gets fewer assets (vault keeps dust).
- Consistent "favor vault" policy protects existing holders from rounding-based value extraction.
- Applies to: processDepositEpoch (mint), processWithdrawalEpoch (burn/distribute), syncRedeem (burn/distribute), depositCustom (mint), withdrawCustom (burn).

### [d:min-amounts] Minimum Deposit and Withdrawal Amounts
- Admin-settable minimum for both deposits and withdrawals.
- Anti-dust griefing: prevents tiny operations that cost keeper gas to process in epoch batches.
- Rounding protection: extremely small amounts can round to 0 shares or 0 assets.
- Applies to: deposit requests, async withdrawal requests, sync redeem.
- depositCustom/withdrawCustom (migration) — minimum applies to the share count being migrated.

### [d:first-depositor] First-Depositor Protection
- Classic ERC4626 donation attack does NOT apply: delta NAV prices each deposit cohort independently. Donation inflates navBefore and navAfter equally → delta unchanged.
- Remaining risk: rounding precision in pro-rata calculations (sync redeem, async withdrawal) when totalSupply is very small.
- Minimum deposit is sufficient: with 18-decimal shares, even 1 unit of base token creates ~1e18 shares — more than enough precision.
- Dead shares not needed: if totalSupply returns to 0 (all withdraw), next "first" deposit is safe under delta NAV (independently priced).
- No virtual shares, no dead shares, no special first-deposit logic — minimum deposit covers the risk.

### [d:flr-invariants] FlashLoanRouter Invariants
- No token residual — after callback completes, FlashLoanRouter holds zero tokens. All borrowed forwarded to initiator, all repayment sent back to provider.
- Callback only from active provider — validated via transient storage flag set before initiating flash loan. Prevents spoofed callbacks.
- Single flash loan at a time — transient storage ensures no nested flash loans through the same router.
- Zero fee — only zero-fee flash loan providers are used. No fee accounting needed.

### [d:flr-state] FlashLoanRouter State
- No persistent state beyond configuration (which flash loan provider to use).
- Transient storage (EIP-1153) during flash loan execution: initiator address (who to call back) + active flag (reentrancy/validation).
- Stateless between transactions — nothing to migrate, nothing to corrupt.

### [d:flash-callback] Flash Loan Callback Flow
- Two callers use FlashLoanRouter: Strategy (for leverage/unwind/emergency) and MigrationRouter (for migration).
- Flow: Initiator calls FlashLoanRouter.executeFlashLoan() → FlashLoanRouter stores initiator in transient storage → calls provider (Aave/Balancer/etc.) → provider calls FlashLoanRouter.callback() → FlashLoanRouter validates callback origin → calls initiator.onFlashLoan() → initiator executes logic → returns → FlashLoanRouter repays provider.
- Initiator address resolved from transient storage — FlashLoanRouter doesn't need to know who called it in advance.

### [d:migration-flash-source] Migration Flash Loan Source
- MigrationRouter calls FlashLoanRouter directly — not through Strategy.
- MigrationRouter implements onFlashLoan() callback, same interface as Strategy.
- Which FlashLoanRouter: MigrationRouter can use any registered FlashLoanRouter. Could be configured per-call or use a default.

### [d:migration-flash-amount] Migration Flash Loan Amount
- Computed from source vault's actual position (after _forceAccrue): shares/totalSupply * actualDebt.
- MigrationRouter reads source vault's Strategy.getPosition() (which calls _forceAccrue internally) and totalSupply() to calculate.
- This is the exact debt amount that needs to be repaid to withdraw the proportional collateral.
- Flash loan amount = this debt amount (borrowed to repay source vault's debt, then re-borrowed from destination vault to repay flash loan).

### [d:naming] Naming Convention
- Consistent deposit/redeem terminology throughout Vault and Strategy.
- Vault: requestDeposit/requestRedeem (async), syncRedeem (sync), processDeposits/processRedeems (keeper), depositCustom/redeemCustom (migration).
- Strategy: deposit/redeem (epoch leverage/unwind), depositCustom/redeemCustom (migration supply+borrow / repay+withdraw), emergencyRedeem (full unwind, called directly by keeper/guardian).
- Rationale: unified language makes flows easier to follow. "Withdrawal" replaced by "redeem" everywhere.

### [d:fraction-arg] Strategy Fraction Argument
- Strategy receives fraction (scaled to 1e18) instead of raw shares/totalSupply pair.
- Vault computes fraction = shares * 1e18 / totalSupply, passes to Strategy.
- Strategy applies fraction to actual position: amount = fraction * actualDebt / 1e18 (same for collateral).
- Separation of concerns: Vault owns share accounting, Strategy only knows "what portion of the position to process".
- fraction = 1e18 means full position (used in emergencyRedeem).

### [d:flash-fee] Flash Loan Providers — Zero Fee Only
- Only zero-fee flash loan providers are used (Balancer, Morpho, Aave with 0-fee markets, etc.).
- Rationale: leverage/unwind happens on every deposit and withdrawal epoch. Non-zero fee would make entry/exit prohibitively expensive at scale.
- Factory validation or FlashLoanRouter registration should verify zero-fee property.
- Simplifies calldata construction: no need to account for flash loan fee in swap amounts.

### [d:swap-margin] Swap Calldata Margin
- Caller (keeper/user/guardian) constructs DEX swap calldata off-chain for a slightly smaller amountIn than expected on-chain amount.
- Reason: on-chain amount may differ due to interest accrual between calldata construction and execution, rounding in pro-rata calculations.
- Oracle-floor check still validates: amountReceived >= oracleValue(amountSent) * (1 - toleranceBps).
- Residual dust (difference between actual amount and swap amountIn) stays in Strategy. Accumulates over time.
- Affected flows: processDeposits (base→YBT), processRedeems (YBT→base), syncRedeem (YBT→base), emergencyRedeem (YBT→base), migration YBT conversion.

### [d:partial-epoch] Partial Epoch Processing
- Amount-based: processDeposits(amount, ...) and processRedeems(shares, ...).
- Keeper specifies exact volume to deploy/unwind. Contract iterates FIFO from head, filling requests until amount/shares exhausted.
- Last request may be partially filled — remainder stays in queue for next call. Partial fill amount tracked per request.
- FIFO order mandatory — keeper cannot cherry-pick or reorder requests. Prevents censorship and unfair execution.
- Different batches may get different execution prices — acceptable trade-off, same as requests arriving in different blocks.
- Use case: large request exceeds available DEX liquidity, keeper processes a portion now and the rest later.
- amount/shares in function args must match the swap calldata (keeper builds calldata for that exact volume).

### [d:per-user-timeout] Per-User Timeout (REMOVED)
- REMOVED: cancel covers all scenarios. User can cancel any unprocessed request at any time.
- With partial epoch processing (FIFO, amount-based), there is no "in flight" state for unprocessed requests. Either a request is processed (fully or partially) or it isn't.
- No timeout needed — if keeper ignores a request, user just cancels it.

### [d:keeper-emergency] Emergency Redeem Entry Point
- Keeper and guardian both call Strategy.emergencyRedeem() directly — not through Vault.
- Vault doesn't need a forceRedeem wrapper. Emergency unwind is a Strategy concern (position management).
- Strategy.emergencyRedeem uses fraction = 1e18 (full position unwind).
- NAV automatically reflects unwound position (reads actual from lending protocol).
- Access: onlyKeeperOrGuardian modifier on Strategy.

### [d:max-ltv] Max Leverage Ratio Enforcement
- Strategy.deposit() checks post-leverage LTV against maxLTV parameter after building position.
- Per-vault parameter, set by admin (via Strategy or Factory at deployment).
- Reverts if post-leverage LTV exceeds limit — prevents dangerously leveraged positions.
- Also checked on depositCustom (migration) — ensures migrated positions respect destination vault's limit.

### [d:flr-callbacks] FlashLoanRouter Per-Provider Callbacks
- Implementation detail — each FlashLoanRouter subclass handles its provider's specific callback signature.
- Architecture only defines: FlashLoanRouter exposes executeFlashLoan() and normalizes all provider callbacks into initiator.onFlashLoan(token, amount, fee, data).
- Provider-side signatures (Aave executeOperation, Balancer receiveFlashLoan, Morpho onMorphoFlashLoan) are implementation concerns.

### [d:oracle-interface] Oracle Interface
- Implementation detail covered by ADR DT-002: OracleRouter with pluggable IPriceFeed adapters.
- Architecture scope: oracleValue() converts between tokens using vault's configured oracle. Used for NAV and swap floor checks.
- Specific interface (Chainlink AggregatorV3, custom feeds) decided in ADR phase, not architecture.

### [d:flr-selection] FlashLoanRouter Selection
- Strategy does NOT store a FlashLoanRouter address. Keeper provides it as a parameter per-call.
- Validated against Factory registry: factory.isRegisteredRouter(router) — reverts if not registered.
- Rationale: multiple FlashLoanRouter implementations exist (per provider). Liquidity varies, providers can go down. Keeper needs flexibility to pick best provider per-call without admin intervention.
- Security: only admin-registered routers accepted. Keeper cannot pass a fake router.
- Affected functions: processDeposits, processRedeems pass router to Strategy. syncRedeem: user provides router (also validated). MigrationRouter: uses router parameter from caller.

### [d:flr-access] FlashLoanRouter.executeFlashLoan Access
- Open access — anyone can call executeFlashLoan().
- Security relies on transient storage callback validation, not caller restriction.
- Rationale: FlashLoanRouter is stateless, holds no funds between txs. The callback validates origin. Restricting callers adds complexity without security benefit.
- Both Strategy and MigrationRouter call it — and future initiators could too without needing registration.

### [d:beacon-owner] Beacon Ownership
- Same admin as Factory owns all beacon contracts (Vault beacon, Strategy beacons, FlashLoanRouter beacons).
- Single admin simplifies governance — one multisig/timelock controls all upgrades.
- Admin can transfer beacon ownership independently if needed (e.g., separate upgrade governance later).

### [d:redeem-custom-flow] redeemCustom Token Flow
- MigrationRouter transfers flash-loaned baseToken to Strategy before calling Vault.redeemCustom().
- Strategy uses this baseToken to repay proportional debt in lending protocol.
- Strategy then withdraws proportional collateral (YBT) and sends it back to MigrationRouter.
- Vault burns user's shares.
- Flow: MigrationRouter → transfer baseToken → Strategy | Vault.redeemCustom() → Strategy repays debt + withdraws collateral → YBT sent to MigrationRouter.
