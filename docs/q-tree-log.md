# Q-Tree Session Log

Goal: Leveraged DeFi vault — buy YBT with leverage via Aave/Morpho/Euler, flash loan entry/exit, one vault per strategy, cross-strategy migration.
Started: 2026-03-11

---

## Round 1

### Presented
Decomposing: "Leveraged YBT Vault Architecture"
1. → Contract decomposition? → Vault + LendingAdapter + FlashLoanRouter + Factory
2. → Leverage mechanism? → Flash loan single-tx
3. ? Share accounting and NAV? — sync ERC4626 / async epochs / hybrid
4. → YBT acquisition abstraction? → Pluggable SwapAdapter per YBT type
5. → Cross-strategy migration? → Atomic collateral swap via MigrationRouter
6. ? LTV and liquidation risk management? — keeper rebalance / on-chain automation
7. → Protocol extensibility? → ILendingAdapter interface + beacon proxy

### User response
1 deferred (need more info), 2 ok, 3 async epochs (keeper provides calldata, shares auto-sent), 4 keeper provides calldata+router contracts verify no losses, 5 yes but need to define deposit/withdraw flows, 6 keeper monitors + guardian last-resort, 7 deferred

### Recorded
1. ? Contract decomposition → deferred
2. ✓ Leverage mechanism → flash loan single-tx
3. ✓ Share accounting → async epochs, keeper calldata, shares auto-sent
4. ✓ YBT acquisition → keeper calldata+router, contracts verify no losses
5. ✓ Cross-strategy migration → atomic collateral swap, flows TBD
6. ✓ LTV risk → keeper monitors + guardian last-resort
7. ? Protocol extensibility → deferred
Auto-closed: none

### Check
3 WARNINGs: oracle strategy undefined, keeper trust concentration, migration scalability for large positions.
3 INFOs: no circuit breaker, irreversible auto-send, flash loan provider selection.
Sensitive: async epoch model affects nearly all other decisions; "verify no losses" mechanism is load-bearing for security.

---

## Round 2

### Presented
Decomposing: "Async epochs" + "Cross-strategy migration"
1. → NAV snapshot timing? → Post-leverage, at realized values
2. → Pending deposits treatment? → Idle in vault, no yield, no risk
3. → Cancel pending deposit? → Yes, before epoch settles
4. → Keeper liveness fallback? → Timeout + user self-serve reclaim
5. → Migration authorization? → Governance proposes, keeper executes
6. → Destination vault intake? → Standard deposit flow, no special path
7. ? Migration granularity? — whole vault / per-user opt-in

### User response
1 delta NAV post-leverage (fair to existing holders), 2 yes idle no shares no yield, 3 ok, 4 ok, 5 override: owner of position or approved address (no governance), 6 asked for clarification

### Discussion
Agent explained destination vault intake options: standard flow (epoch queue) vs special migration path.
User proposed third option: depositCustom — permissionless function that accepts collateral, supplies to lending, borrows debt back to caller, mints shares via delta NAV. No trust needed between vaults.
Agent analyzed: clever but creates sync entry path bypassing async safety. Security concerns: oracle manipulation, reentrancy, collateral validation. User confirmed direction.

### Recorded
1. ✓ NAV snapshot → delta NAV post-leverage
2. ✓ Pending deposits → idle, no shares, no yield
3. ✓ Cancel pending → yes, before epoch settles
4. ✓ Keeper timeout → timeout + user reclaim
5. ✓ Migration auth → position owner or approved address
6. ✓ Destination intake → depositCustom (permissionless, sync delta NAV)
7. ✓ Migration granularity → per-user
Auto-closed: none (parent has open security sub-questions)

### Check
2 BLOCKERs: depositCustom bypasses async safety (oracle arbitrage), reentrancy from debt callback.
4 WARNINGs: per-user migration LTV impact, donation attack variant, collateral validation gap, interest accrual gaming.
2 INFOs: needs redeemCustom on source vault (hidden prereq), keeper liveness during cascade migrations.
Sensitive: depositCustom is most architecturally impactful — creates parallel sync entry path.

---

## Round 3

### Presented
Decomposing: "depositCustom security" + "Withdrawal flow"
1. → Oracle protection for sync delta NAV? → Circuit breaker + arithmetic NAV validation
2. → Reentrancy from debt callback? → EIP-1153 transient lock + CEI ordering
3. → depositCustom access control? → Permissionless with full guard stack
4. → Async or sync withdrawal? → Async epoch, mirrors deposit model
5. → Who provides unwind calldata? → Keeper, same as deposit
6. → Partial withdrawal support? → Share-denominated partial, pro-rata unwind
7. → Share timelock for depositCustom shares? → Timelock only for depositCustom-minted shares

### User response
1-3 postponed (need more context), 4 async epoch proportional, 5 ok, 6 ok (didn't fully get), 7 didn't understand why needed

### Discussion
Agent explained #6: partial withdrawal = user specifies shares (not dollars), keeper unwinds proportional position. Same as "proportional" from #4.
Agent explained #7: without timelock, depositCustom shares can be deposited+withdrawn in same tx = oracle arbitrage. But user asked: wouldn't it be simpler to restrict depositCustom/withdrawCustom to MigrationRouter only? Agent agreed — restricting access eliminates timelock need, reduces oracle surface, simplifies reentrancy. User confirmed.

### Recorded
1. ? Oracle protection → deferred (simpler with restricted access)
2. ? Reentrancy → deferred (simpler with known caller)
3. ✓ depositCustom/withdrawCustom access → only MigrationRouter, set by factory
4. ✓ Async withdrawal → async epochs, proportional
5. ✓ Unwind calldata → keeper provides
6. ✓ Partial withdrawal → share-denominated, pro-rata
7. ✗ Share timelock → not needed (depositCustom restricted to MigrationRouter)
Auto-closed: ✓ Withdrawal flow (all children resolved)

### Check
Pending (Round 3 check deferred to next round due to discussion-driven changes).

---

## Round 4

### Presented
Decomposing: "Fee model" + "Emergency/pause"
1. → Where are fees charged? → Performance fee on yield only
2. → How are fees collected? → Mint shares to fee recipient (dilution)
3. → Fee on migration? → No fee, migration is position transfer
4. → Pause scope? → Deposits, withdrawals, migrations stopped; keeper exempt
5. → Who can pause? → Guardian immediate + governance timelock
6. → User recourse when paused? → Emergency withdrawal after delay, then force-unwind
7. → Force-unwind without keeper? → Simplified on-chain path + permissionless escalation

### User response
1-3: no fees at all, can add performance fee via wrapper later. 4 ok. 5 override: guardian + admin, no governance (can add OZ timelock later). 6 ok. 7 deferred.

### Recorded
1. ✓ Fees → none, add via wrapper later
2. ✗ Fee collection → N/A
3. ✗ Fee on migration → N/A
4. ✓ Pause scope → deposits/withdrawals/migrations stopped, keeper exempt
5. ✓ Pause auth → guardian + admin (governance via OZ timelock later)
6. ✓ User recourse → emergency withdrawal after delay, then force-unwind
7. ? Force-unwind → deferred
Auto-closed: ✓ Fee model (no fees)

### Check
Previous BLOCKERs resolved by MigrationRouter restriction.
WARNINGs: "verify no losses" still undefined, migration assumes same debt token, withdrawCustom share burning spec.
INFOs: pending withdrawal + migration race condition (fix: revert if pending requests).
No new blockers.

---

## Round 5

### Presented
Decomposing: "Contract decomposition" + "Swap verification"
1. → Concrete contracts? → Vault, LendingAdapter, FlashLoanRouter, MigrationRouter, Factory
2. → Leverage orchestration location? → FlashLoanRouter, not vault
3. → Adapter ownership? → Own adapter instance per vault
4. → "No losses" invariant? → received >= oracleValue * (1 - toleranceBps)
5. → Tolerance configuration? → Per-vault admin parameter with hard ceiling
6. → Oracle scope for verification? → Reuse NAV oracle, floor check only
7. → Migration swap verification? → MigrationRouter verifies YBT conversion output

### User response
1 override: Vault (accounting) + Strategy (abstract + inheritance, orchestrates leverage/lending) + MigrationRouter + Factory + FlashLoanRouter (per provider, interface adapters). No separate LendingAdapter.
2 asked for deeper analysis. Agent presented 4 options (A: Strategy orchestrates, B: FlashLoanRouter, C: Vault, D: Strategy w/o router). User chose A.
3 override: no separate LendingAdapter, inline in Strategy via inheritance.
4 ok. 5 asked "tolerance of what?" — agent explained (max slippage vs oracle price). User: per-vault. 6 asked to expand — agent explained NAV oracle reused as safety floor. User: ok. 7 ok.

### Discussion
Agent explained tolerance = max acceptable slippage relative to oracle price on swaps.
Agent explained oracle scope = same oracle used for NAV, but only as floor check for swaps, not for share pricing.
Agent presented 4 options for orchestration with pros/cons. User chose Strategy orchestrates (option A).

### Recorded
1. ✓ Contracts → Vault + Strategy (abstract+inheritance) + MigrationRouter + Factory + FlashLoanRouter
2. ✓ Orchestration → Strategy orchestrates everything, vault only accounting
3. ✓ No LendingAdapter → inline in Strategy
4. ✓ No losses invariant → oracle-derived floor
5. ✓ Tolerance → per-vault (different oracles/slippage per pair)
6. ✓ Oracle scope → reuse NAV oracle for swap floor
7. ✓ Migration verification → MigrationRouter verifies
Auto-closed: ✓ Contract decomposition, ✓ Swap verification

### Check
Pending (inline below).

---

## Round 6

### Presented
Decomposing: all remaining open questions (oracle protection, reentrancy, force-unwind, extensibility)
1. → Arithmetic NAV validation? → expectedDelta = oracleValue(collateral) - debt, revert on deviation
2. → Interest accrual before snapshot? → Strategy._forceAccrue() before navBefore
3. → Reentrancy lock scope? → Vault-level EIP-1153
4. → Guardian unwind? → Guardian provides calldata, same interface as keeper
5. → Permissionless escalation? → Anyone calls forceUnwind after extended delay
6. → Adding new lending protocols? → New Strategy subclass + beacon + factory
7. → Adding new flash loan providers? → New FlashLoanRouter + admin registers

### User response
1 asked for explanation. 2 asked for explanation. 3 asked for explanation. 4 ok. 5 proposed bigger change: sync permissionless redeem available ALWAYS (not just when paused). User provides calldata for proportional exit. 6 ok. 7 ok.

### Discussion
Agent explained #1 (sanity check: expected delta matches actual delta), #2 (lazy interest accrual inflates deltaNAV), #3 (EIP-1153 mutual exclusion flag).
For #5: user proposed any user can redeem at any time with own calldata. Agent analyzed: proportional exit preserves LTV (safe for remaining users), no oracle needed for split (pure pro-rata), oracle only for swap floor check. This makes async withdrawal optional (gas optimization, not required path). Fundamentally changes emergency model — users never trapped.
User confirmed sync permissionless redeem as alternative path.

### Recorded
1. ✓ Arithmetic NAV validation → expectedDelta check
2. ✓ Interest accrual before snapshot → _forceAccrue() must have
3. ✓ Reentrancy lock → vault-level EIP-1153
4. ✓ Guardian unwind → guardian provides calldata
5. ✓ Sync permissionless redeem → always available, user provides calldata
6. ✓ New lending protocols → Strategy subclass + beacon + factory
7. ✓ New flash loan providers → new FlashLoanRouter + admin registers
Auto-closed: ✓ Oracle protection, ✓ Reentrancy, ✓ Force-unwind, ✓ Protocol extensibility, ✓ Leveraged YBT Vault Architecture (ROOT)

### Check
Pending (final check below).

---

## Round 7 — Gap Resolution (Batch 1)

### Presented
Resolving 7 of 12 gaps found during summarization:
1. → Base token vs debt token? → Always the same token
2. → Post-force-unwind redeem? → Same as usual redeem (idle cash returned)
3. → guardianUnwindDelay and permissionless escalation? → Not needed with sync redeem
4. → MigrationRouter upgrade path? → Immutable, Factory.setMigrationRouter
5. → Epoch queue separation? → Separate processEpoch per direction
6. → Tolerance ceiling? → Hard ceiling, 500 bps suggested
7. → Keeper rebalance flow? → Partial unwind/re-leverage via flash loan

### User response
1 Y. 2 same as usual redeem, no extra mechanism needed. 3 don't need delays — sync redeem + async redeemRequest are exit paths. 4 Y. 5 Y. 6 ok but 500 bps too much, 100 bps. 7 no rebalance at all — only emergency unwind by keeper on drawdown/low HF. 3 clarification: exit = sync redeem or redeemRequest.

### Discussion
User simplified emergency model further: no force-unwind delays or permissionless escalation needed since sync redeem is always available. Emergency unwind replaces rebalance — keeper triggers full unwind on health factor issues, no partial LTV adjustment.

### Recorded
1. ✓ Base token = debt token → always identical
2. ✓ Post-unwind redeem → same as usual redeem, returns idle cash
3. ✓ Force-unwind delays → not needed, sync redeem + redeemRequest sufficient
4. ✓ MigrationRouter upgrade → immutable, Factory.setMigrationRouter
5. ✓ Epoch separation → separate processEpoch calls per direction
6. ✓ Tolerance ceiling → 100 bps hard ceiling
7. ✓ Risk management → no rebalance, emergency unwind only (keeper on drawdown/low HF)
Auto-closed: none (gap resolution, no parent changes)

### Check
No consistency issues. Changes are simplifications — removal of complexity (delays, rebalance) rather than new features.

---

## Round 7 — Gap Resolution (Batch 2)

### Presented
Resolving remaining 5 gaps:
1. → Vault upgradeability? → Beacon proxy, same as Strategy
2. → Admin transfer/renounce? → OZ Ownable2Step, renounce disabled
3. → Sync redeem idle mode? → Skip flash loan, return shares/totalSupply * idleBase
4. → Partial migration? → Yes, user specifies share count
5. → Factory deployment validation? → Oracle reachable, market valid, tolerance <= ceiling, token match

### User response
1 Y. 2 Y. 3 yes, if only idle then no flash loan needed. 4 Y. 5 asked for details, then accepted.

### Recorded
1. ✓ Vault upgradeability → beacon proxy
2. ✓ Admin transfer → Ownable2Step, renounce disabled
3. ✓ Sync redeem idle mode → skip flash loan, pro-rata idle
4. ✓ Partial migration → yes, user specifies share count
5. ✓ Factory validation → oracle, market, tolerance, token match
Auto-closed: none

### Check
No consistency issues. All 12 gaps from summarization are now resolved.

---

## Round 8 — Gap Resolution (SUMMARIZE #2)

### Presented
Re-ran SUMMARIZE phase. 14 gaps found: 11 implementation-level (access control guards), 3 architecture-level:
1. → First-depositor / donation attack? → Virtual shares + minimum first deposit
2. → Rounding direction? → Round down mint, round up burn
3. → Minimum deposit/withdrawal? → Admin-settable minimum deposit

### User response
1 virtual shares don't work for delta NAV — better to track balances internally (not balanceOf). 2 Y. 3 minimum for withdrawal too (anti-dust for keeper gas). Asked what other purpose — answered: anti-dust + rounding protection, nothing else.

### Discussion
Internal balance tracking: with delta NAV, donation attack = manipulating reported balances between navBefore/navAfter. Internal tracking neutralizes this. Virtual shares irrelevant because shares aren't priced via totalAssets/totalSupply.

### Recorded
1. ✓ Donation attack protection → internal balance tracking (not balanceOf)
2. ✓ Rounding → round down mint, round up burn (favor vault)
3. ✓ Minimum amounts → admin-settable min for both deposit and withdrawal
Auto-closed: none

### Check
No consistency issues.

---

## Round 8 — Gap Resolution (continued)

### Presented
1. → First-depositor rounding protection? → Dead shares (mint to address(1))

### User response
Asked: "А minimum deposit не покроет этот риск?" — whether minimum deposit is sufficient instead of dead shares.

### Discussion
Analyzed: classic ERC4626 donation attack doesn't apply (delta NAV + internal tracking). Remaining risk = rounding precision in pro-rata when totalSupply small. With 18-decimal shares, minimum deposit of 1 base unit creates ~1e18 shares — sufficient precision. Dead shares unnecessary. Edge case of totalSupply returning to 0 is safe under delta NAV.

### Recorded
1. ✓ First-depositor protection → minimum deposit sufficient, dead shares not needed
Auto-closed: none

### Check
No consistency issues. Last architecture gap resolved.

---

## Round 9 — Gap Resolution (SUMMARIZE #3)

### Presented
Re-ran SUMMARIZE with updated summarizer (interfaces.md, state vars, postconditions, parameter sufficiency check). 5 gaps found, all FlashLoanRouter/MigrationRouter flash loan mechanics:
1. → FlashLoanRouter invariants
2. → FlashLoanRouter state
3. → Flash loan callback flow
4. → Migration flash loan source
5. → Migration flash loan amount

### User response
1 asked for details, then accepted. 2 Y. 3 Y + noted MigrationRouter also uses flash loan (both callers). 4 Y. 5 Y.

### Discussion
FlashLoanRouter callback needs to support two callers: Strategy and MigrationRouter. Initiator stored in transient storage, callback forwards to initiator.onFlashLoan(). Both implement same callback interface.

Also recorded separately (user-initiated, not from gap): depositCustom needs explicit debtAmount parameter — MigrationRouter knows flash loan amount, Strategy shouldn't guess.

### Recorded
1. ✓ FlashLoanRouter invariants → no residual, validated callback, single at a time
2. ✓ FlashLoanRouter state → transient storage only, no persistent state
3. ✓ Flash loan callback → Provider → FlashLoanRouter → initiator.onFlashLoan() (Strategy or MigrationRouter)
4. ✓ Migration flash loan source → MigrationRouter calls FlashLoanRouter directly
5. ✓ Migration flash loan amount → shares/totalSupply * trackedDebt from source vault
Auto-closed: none

### Check
No consistency issues.

---

## Round 10 — Architecture Revision (internal tracking removal)

### Discussion
User questioned whether _forceAccrue and balanceOf are conflated. Led to analysis: with internal tracking, _forceAccrue doesn't affect tracked values, but then interest isn't reflected in NAV. Tension between donation protection and accurate interest accounting.

User proposed: can we remove internal tracking entirely? Analysis of donation attack vectors with delta NAV:
- Donation before navBefore: inflates both navBefore and navAfter equally → delta unchanged. Not exploitable.
- Donation between navBefore/navAfter: impossible (same tx, reentrancy lock).
- Donation for sync redeem profit: attacker net gain = donation * (shares/totalSupply - 1) → negative. Attacker loses.
- totalSupply = 0 cases: no attack vector with delta NAV + minimum deposit.

Conclusion: internal tracking unnecessary. Delta NAV + min deposit + reentrancy lock sufficient.

### Recorded
- ✗ Internal balance tracking → REMOVED, unnecessary with delta NAV architecture
- ✓ _forceAccrue scope expanded → required before ALL position reads (not just delta NAV snapshots)
- ✓ Migration flash loan amount → uses actualDebt (after _forceAccrue), not trackedDebt
- NAV now reads actual position from lending protocol after _forceAccrue

### Check
No consistency issues. Simplification — fewer concepts, interest automatically reflected.

---

## Round 11 — Naming + fraction argument

### Presented
User requested: (1) sync naming with deposit/redeem throughout Vault and Strategy, (2) Strategy should receive fraction of 1e18 instead of shares/totalSupply pair.

### User response
Y. Only record the core ideas (naming + fraction), not the full derived interface.

### Recorded
1. ✓ Naming convention → deposit/redeem terminology throughout Vault and Strategy
2. ✓ Strategy fraction argument → fraction (of 1e18) instead of shares/totalSupply

### Check
No consistency issues.

---

## Round 12 — Flash loan fee + swap calldata margin

### Discussion
User raised: callers construct swap calldata off-chain for specific amounts, but on-chain amounts may differ (interest accrual, rounding). Analysis identified affected flows: processDeposits, processRedeems, syncRedeem, forceRedeem, emergencyRedeem, migration YBT conversion.

User immediately clarified: flash loan fee is not a factor — only zero-fee providers are used. Leverage/unwind on every epoch makes non-zero fees prohibitively expensive.

### Recorded
1. ✓ Flash loan providers → zero-fee only (Balancer, Morpho, etc.)
2. ✓ Swap calldata margin → caller builds calldata with margin, oracle-floor check validates output

### Check
No consistency issues. Zero-fee simplifies FlashLoanRouter invariants (removed fee accounting).

---

## Round 13 — Partial epoch processing + per-user timeout

### Discussion
User asked about slippage protection. Analysis: sync redeem and migration — user controls calldata. Async deposit/redeem — only oracle-floor (100 bps ceiling). Options discussed: per-user minOut, opt-out, cancel window. Decided: oracle-floor sufficient for MVP, sync redeem available for users who want control.

Then user asked about processing requests partially (not full epoch). Identified risks: keeper cherry-picking, censorship, different prices for same-time requests. Mitigations: FIFO mandatory, per-user timeout.

User added: requests can be partially filled (e.g., large deposit split across multiple calls).

Per-user timeout: low complexity increase — each request stores timestamp, reclaim checks per-request, keeper skips reclaimed entries in FIFO.

### Recorded
1. ✓ Partial epoch processing → FIFO, including partial fills of individual requests
2. ✓ Per-user timeout → each request has own deadline, replaces epoch-level timeout

### Check
No consistency issues. Per-user timeout supersedes epoch-level timeout from [d:keeper-timeout].

---

## Round 14

### Presented
Gap resolution (7 gaps from SUMMARIZE):
1. → Keeper emergency redeem entry point? → Via Vault.forceRedeem, keeper+guardian both allowed
2. → Max leverage ratio enforcement? → Strategy.deposit checks post-leverage LTV, per-vault param
3. → FlashLoanRouter per-provider callback signatures? → Implementation detail
4. → Oracle interface? → Implementation detail (ADR DT-002)
5. → FlashLoanRouter.executeFlashLoan access? → Open, transient storage sufficient
6. → Beacon ownership? → Same admin as Factory
7. → redeemCustom token flow? → MigrationRouter transfers baseToken to Strategy before call

### User response
1. "может, лучше сделать оба через strategy? Зачем vault про это знать вообще?" — both keeper and guardian call Strategy.emergencyRedeem directly, remove Vault.forceRedeem.
2-7: accepted.

### Discussion
#1: User pointed out Vault doesn't need to know about emergency unwind — it's a Strategy concern. NAV dynamically computed from getPosition(), so unwound state reflected automatically. Agreed: remove Vault.forceRedeem, both roles call Strategy.emergencyRedeem directly.
#3: Explained FlashLoanRouter normalizes per-provider callbacks (Aave executeOperation, Balancer receiveFlashLoan, Morpho onMorphoFlashLoan) into unified initiator.onFlashLoan(). Provider-side signatures are implementation detail.

### Recorded
1. ✓ Emergency redeem → Strategy.emergencyRedeem directly, no Vault wrapper
2. ✓ Max LTV → Strategy.deposit checks, per-vault param, admin-settable
3. ✓ FlashLoanRouter callbacks → implementation detail, normalized interface
4. ✓ Oracle interface → implementation detail (ADR DT-002)
5. ✓ FlashLoanRouter.executeFlashLoan → open access, transient storage sufficient
6. ✓ Beacon ownership → same admin as Factory
7. ✓ redeemCustom token flow → MigrationRouter transfers baseToken to Strategy before call

### Check
No consistency issues. Vault.forceRedeem removed from naming convention, emergency handled at Strategy level.

[Round 14] Resolved: 69 | Suggested: 0 | Open: 0

---

## Round 15

### Presented
User-initiated questions (not from EXPAND):
1. "reclaimDeposit/reclaimRedeem нужны ли? Это не то же самое, что cancel?"
2. "processDeposits/processRedeems — как именно partial processing работает?"

### User response
1. "да, убираем" — reclaim redundant with cancel, per-user timeout removed.
2. Выбрал вариант B (amount-based с partial fill). Naming: processDeposits(amount, ...), processRedeems(shares, ...).

### Discussion
Reclaim vs cancel: with partial epoch processing (FIFO, amount-based), no "in flight" state for unprocessed requests. Cancel always available → reclaim/timeout redundant.

Partial processing mechanics: three options presented (count-based, amount-based with partial fill, amount-based without partial fill). User chose amount-based with partial fill — keeper specifies exact volume, contract iterates FIFO, last request may be partially filled.

### Recorded
1. ✗ Per-user timeout → removed, cancel covers all scenarios
2. ✓ Partial epoch processing → amount-based (processDeposits(amount), processRedeems(shares)), FIFO, partial fills

### Check
No consistency issues. reclaimDeposit/reclaimRedeem removed from interfaces.

[Round 15] Resolved: 68 | Suggested: 0 | Open: 0

---

## Round 16

### Presented
User-initiated: FlashLoanRouter contradiction
1. "FlashLoanRouter per-provider, но Strategy хранит один адрес — противоречие"
2. "Нужно ли хранить адрес или keeper может выбирать? Есть ли атака?"

### User response
Keeper выбирает per-call, но из зарегистрированного списка (Factory registry). Не stored на Strategy, не произвольный.

### Discussion
- Strategy storing single FlashLoanRouter = unnecessary limitation (provider down → stuck)
- Keeper-provided from open set = attack vector (fake router → arbitrary callback)
- Solution: Factory registry of admin-approved routers, keeper picks per-call, validated at call time
- User also asked how to improve summarizer to catch such issues → user will fix skill prompts separately

### Recorded
1. ✓ FlashLoanRouter selection → keeper picks per-call from Factory registry, not stored on Strategy
2. Updated [d:new-flashloan] to reflect registry model instead of admin-switch-per-vault

### Check
Consistency update needed: [d:new-flashloan] previously said "admin function on Strategy to switch". Now Strategy has no stored router. FlashLoanRouter is parameter + registry check.

[Round 16] Resolved: 69 | Suggested: 0 | Open: 0

---
