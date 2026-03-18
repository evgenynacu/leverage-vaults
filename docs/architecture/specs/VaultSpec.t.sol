// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IFactory.sol";

// === Traceability ===
//
// Source                                                             → Spec function                                  Status
// --- call-diagrams.md POST: lines (Vault) ---
// POST: requestDeposit amount >= minDepositAmount                   → testFail_requestDepositBelowMin                ✓
// POST: requestDeposit vault not paused                             → testFail_requestDepositWhenPaused               ✓
// POST: requestDeposit idle balance += amount, NAV unchanged        → check_requestDepositIdleIncreases               ✓
// POST: requestDeposit request appended to depositQueue tail        → [GAP] needs internal queue inspection
// POST: cancelDeposit msg.sender == request.owner                   → [GAP] needs requestId from event
// POST: cancelDeposit user's unfilled deposit returned              → [GAP] needs requestId from event
// POST: requestRedeem shares >= minRedeemAmount                     → testFail_requestRedeemBelowMin                  ✓
// POST: requestRedeem vault not paused                              → testFail_requestRedeemWhenPaused                ✓
// POST: requestRedeem user balance -= shares, vault holds escrowed  → check_requestRedeemEscrowsShares                ✓
// POST: processDeposits caller is keeper                            → testFail_processDepositsByNonKeeper              ✓
// POST: processDeposits factory.isRegisteredRouter == true           → testFail_processDepositsWithUnregisteredRouter   ✓
// POST: processDeposits navAfter > navBefore                        → [GAP] requires Strategy integration
// POST: processDeposits shares minted round down                    → [GAP] requires Strategy integration
// POST: processDeposits partial fill remainder stays at head        → [GAP] needs internal queue inspection
// POST: processRedeems caller is keeper                             → testFail_processRedeemsByNonKeeper               ✓
// POST: processRedeems factory.isRegisteredRouter == true            → testFail_processRedeemsWithUnregisteredRouter    ✓
// POST: processRedeems escrowed shares burned                       → [GAP] requires Strategy integration
// POST: processRedeems each redeemer receives proportional base     → [GAP] requires Strategy integration
// POST: syncRedeem shares >= minRedeemAmount                        → testFail_syncRedeemBelowMin                      ✓
// POST: syncRedeem always available even when paused                → check_syncRedeemWorksWhenPaused                  ✓
// POST: syncRedeem factory.isRegisteredRouter == true                → testFail_syncRedeemWithUnregisteredRouter        ✓
// POST: syncRedeem user balance -= shares, totalSupply -= shares    → check_syncRedeemBurnsShares                      ✓
// POST: syncRedeem user received base token                         → [GAP] requires Strategy integration
// POST: depositCustom caller is migrationRouter                     → testFail_depositCustomByNonMigrationRouter       ✓
// POST: depositCustom vault not paused                              → testFail_depositCustomWhenPaused                 ✓
// POST: depositCustom arithmetic NAV check                          → [GAP] requires Strategy integration
// POST: depositCustom shares minted round down                      → [GAP] requires Strategy integration
// POST: redeemCustom caller is migrationRouter                      → testFail_redeemCustomByNonMigrationRouter        ✓
// POST: redeemCustom user has no pending redeem requests            → [GAP] needs queue inspection getter
// POST: redeemCustom vault not paused                               → testFail_redeemCustomWhenPaused                  ✓
// POST: redeemCustom shares burned                                  → [GAP] requires Strategy integration
// POST: pause caller is admin                                       → testFail_pauseByNonAdmin                         ✓
// POST: guardianPause caller is guardian or admin                   → check_guardianCanPause                            ✓
// POST: unpause caller is admin (not guardian)                      → testFail_unpauseByGuardian                        ✓
// POST: setTolerance <= 100                                         → testFail_setToleranceAboveCeiling                 ✓
// POST: setGuardian caller is admin                                 → testFail_setGuardianByNonAdmin                    ✓
// POST: setKeeper caller is admin                                   → testFail_setKeeperByNonAdmin                      ✓
// --- invariants.md (Vault) ---
// I1: totalSupply > 0 → totalAssets > 0                             → invariant_noSharesWithoutAssets                  ✓
// I4: toleranceBps <= 100                                           → invariant_toleranceBelowCeiling                  ✓
// I5: swap oracle-floor check                                       → [GAP] requires observing swap execution
// I8: syncRedeem available regardless of pause                      → check_syncRedeemWorksWhenPaused                  ✓
// I14: reentrancy lock mutual exclusion                             → [GAP] requires reentrant callback test
// I17: FIFO order enforced                                          → [GAP] needs internal queue inspection
// I21: flashLoanRouter validated against Factory registry           → testFail_*WithUnregisteredRouter (x3)            ✓
// --- access-control.md (Vault restricted functions) ---
// processDeposits: keeper only                                      → testFail_processDepositsByNonKeeper              ✓
// processRedeems: keeper only                                       → testFail_processRedeemsByNonKeeper               ✓
// depositCustom: migrationRouter only                               → testFail_depositCustomByNonMigrationRouter       ✓
// redeemCustom: migrationRouter only                                → testFail_redeemCustomByNonMigrationRouter        ✓
// pause: admin only                                                 → testFail_pauseByNonAdmin                         ✓
// guardianPause: guardian or admin                                  → check_guardianCanPause                            ✓
// unpause: admin only (not guardian)                                → testFail_unpauseByGuardian                        ✓
// setTolerance: admin only                                          → testFail_setToleranceByNonAdmin                   ✓
// setMigrationRouter: admin only                                    → testFail_setMigrationRouterByNonAdmin             ✓
// setMinDepositAmount: admin only                                   → testFail_setMinDepositAmountByNonAdmin            ✓
// setMinRedeemAmount: admin only                                    → testFail_setMinRedeemAmountByNonAdmin             ✓
// setGuardian: admin only                                           → testFail_setGuardianByNonAdmin                    ✓
// setKeeper: admin only                                             → testFail_setKeeperByNonAdmin                      ✓
// --- state-machines.md (Vault) ---
// Deposit Request: Pending→Cancelled via cancelDeposit              → [GAP] needs requestId from event
// Deposit Request: Pending→Filled via processDeposits               → [GAP] requires Strategy integration
// Deposit Request: Pending→PartiallyFilled                          → [GAP] requires Strategy integration
// Redeem Request: same transitions                                  → [GAP] requires Strategy integration
// Vault Position: Empty→Active, Active→Unwound                     → [GAP] requires Strategy integration
// Pause → Unpause: only admin                                      → check_onlyAdminCanUnpause                         ✓
// --- risks.md (mitigations on Vault) ---
// Reentrancy via flash loan callback                                → [GAP] requires reentrant callback test
// Fund lockup when paused                                           → check_syncRedeemWorksWhenPaused                  ✓
// Double-exit (async + sync)                                        → check_requestRedeemEscrowsShares                  ✓
// Malicious FlashLoanRouter injection                               → testFail_*WithUnregisteredRouter (x3)            ✓

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

abstract contract VaultSpec is Test {

    // --- Helpers (implement in your test contract) ---

    function _vault() internal view virtual returns (address);
    function _strategy() internal view virtual returns (address);
    function _factory() internal view virtual returns (address);
    function _token() internal view virtual returns (address);
    function _keeper() internal view virtual returns (address);
    function _guardian() internal view virtual returns (address);
    function _admin() internal view virtual returns (address);
    function _user() internal view virtual returns (address);
    function _migrationRouter() internal view virtual returns (address);
    function _flashLoanRouter() internal view virtual returns (address);

    // === Invariants (from invariants.md) ===

    // I1: totalSupply > 0 implies totalAssets > 0
    function invariant_noSharesWithoutAssets() public view {
        uint256 shares = IVault(_vault()).totalSupply();
        uint256 assets = IVault(_vault()).totalAssets();
        if (shares > 0) assert(assets > 0);
    }

    // I4: toleranceBps <= 100
    function invariant_toleranceBelowCeiling() public view {
        uint256 tol = IVault(_vault()).toleranceBps();
        assert(tol <= 100);
    }

    // I5: swap oracle-floor check
    // [GAP] Cannot express swap invariant statically — requires observing swap execution

    // I8: syncRedeem available regardless of pause state
    function check_syncRedeemWorksWhenPaused(uint256 shares, bytes calldata swapCalldata, address swapRouter) public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        // should not revert due to pause
        vm.prank(_user());
        IVault(_vault()).syncRedeem(shares, swapCalldata, swapRouter, _flashLoanRouter());
    }

    // I14: reentrancy lock (mutual exclusion)
    // [GAP] Cannot express transient storage reentrancy check from spec alone

    // I17: FIFO order enforced
    // [GAP] Cannot express FIFO ordering invariant without internal queue inspection

    // I21: flashLoanRouter validated against Factory registry
    function testFail_processDepositsWithUnregisteredRouter() public {
        address unregistered = address(0xbad);
        vm.prank(_keeper());
        IVault(_vault()).processDeposits(1e18, "", address(0), unregistered);
    }

    function testFail_processRedeemsWithUnregisteredRouter() public {
        address unregistered = address(0xbad);
        vm.prank(_keeper());
        IVault(_vault()).processRedeems(1e18, "", address(0), unregistered);
    }

    function testFail_syncRedeemWithUnregisteredRouter() public {
        address unregistered = address(0xbad);
        vm.prank(_user());
        IVault(_vault()).syncRedeem(1e18, "", address(0), unregistered);
    }

    // === Access control (from access-control.md) ===

    // processDeposits: keeper only
    function testFail_processDepositsByNonKeeper() public {
        vm.prank(_user());
        IVault(_vault()).processDeposits(1e18, "", address(0), _flashLoanRouter());
    }

    // processRedeems: keeper only
    function testFail_processRedeemsByNonKeeper() public {
        vm.prank(_user());
        IVault(_vault()).processRedeems(1e18, "", address(0), _flashLoanRouter());
    }

    // depositCustom: migrationRouter only
    function testFail_depositCustomByNonMigrationRouter() public {
        vm.prank(_user());
        IVault(_vault()).depositCustom(_user(), 1e18, 1e18);
    }

    // redeemCustom: migrationRouter only
    function testFail_redeemCustomByNonMigrationRouter() public {
        vm.prank(_user());
        IVault(_vault()).redeemCustom(_user(), 1e18);
    }

    // pause: admin only
    function testFail_pauseByNonAdmin() public {
        vm.prank(_user());
        IVault(_vault()).pause();
    }

    // guardianPause: guardian or admin
    function check_guardianCanPause() public {
        vm.prank(_guardian());
        IVault(_vault()).guardianPause();
        assert(IVault(_vault()).paused());
    }

    // unpause: admin only (not guardian)
    function testFail_unpauseByGuardian() public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        vm.prank(_guardian());
        IVault(_vault()).unpause();
    }

    // setTolerance: admin only
    function testFail_setToleranceByNonAdmin() public {
        vm.prank(_user());
        IVault(_vault()).setTolerance(50);
    }

    // setTolerance: ceiling 100 bps
    function testFail_setToleranceAboveCeiling() public {
        vm.prank(_admin());
        IVault(_vault()).setTolerance(101);
    }

    // setMigrationRouter: admin only
    function testFail_setMigrationRouterByNonAdmin() public {
        vm.prank(_user());
        IVault(_vault()).setMigrationRouter(address(1));
    }

    // setMinDepositAmount: admin only
    function testFail_setMinDepositAmountByNonAdmin() public {
        vm.prank(_user());
        IVault(_vault()).setMinDepositAmount(1e18);
    }

    // setMinRedeemAmount: admin only
    function testFail_setMinRedeemAmountByNonAdmin() public {
        vm.prank(_user());
        IVault(_vault()).setMinRedeemAmount(1e18);
    }

    // setGuardian: admin only
    function testFail_setGuardianByNonAdmin() public {
        vm.prank(_user());
        IVault(_vault()).setGuardian(address(1));
    }

    // setKeeper: admin only
    function testFail_setKeeperByNonAdmin() public {
        vm.prank(_user());
        IVault(_vault()).setKeeper(address(1));
    }

    // requestDeposit blocked when paused
    function testFail_requestDepositWhenPaused() public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        vm.prank(_user());
        IVault(_vault()).requestDeposit(1e18);
    }

    // requestRedeem blocked when paused
    function testFail_requestRedeemWhenPaused() public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        vm.prank(_user());
        IVault(_vault()).requestRedeem(1e18);
    }

    // depositCustom blocked when paused
    function testFail_depositCustomWhenPaused() public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        vm.prank(_migrationRouter());
        IVault(_vault()).depositCustom(_user(), 1e18, 1e18);
    }

    // redeemCustom blocked when paused
    function testFail_redeemCustomWhenPaused() public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        vm.prank(_migrationRouter());
        IVault(_vault()).redeemCustom(_user(), 1e18);
    }

    // cancelDeposit allowed when paused
    function check_cancelDepositAllowedWhenPaused(uint256 requestId) public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        vm.prank(_user());
        IVault(_vault()).cancelDeposit(requestId);
    }

    // cancelRedeem allowed when paused
    function check_cancelRedeemAllowedWhenPaused(uint256 requestId) public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        vm.prank(_user());
        IVault(_vault()).cancelRedeem(requestId);
    }

    // requestDeposit below minimum
    function testFail_requestDepositBelowMin() public {
        uint256 minAmount = IVault(_vault()).minDepositAmount();
        vm.prank(_user());
        IVault(_vault()).requestDeposit(minAmount - 1);
    }

    // requestRedeem below minimum
    function testFail_requestRedeemBelowMin() public {
        uint256 minShares = IVault(_vault()).minRedeemAmount();
        vm.prank(_user());
        IVault(_vault()).requestRedeem(minShares - 1);
    }

    // syncRedeem below minimum
    function testFail_syncRedeemBelowMin() public {
        uint256 minShares = IVault(_vault()).minRedeemAmount();
        vm.prank(_user());
        IVault(_vault()).syncRedeem(minShares - 1, "", address(0), _flashLoanRouter());
    }

    // === Postconditions (from call-diagrams.md) ===

    // requestDeposit: idle balance increases, NAV unchanged
    function check_requestDepositIdleIncreases(uint256 amount) public {
        uint256 navBefore = IVault(_vault()).totalAssets();
        uint256 vaultBalBefore = IERC20(_token()).balanceOf(_vault());
        vm.prank(_user());
        IVault(_vault()).requestDeposit(amount);
        uint256 vaultBalAfter = IERC20(_token()).balanceOf(_vault());
        uint256 navAfter = IVault(_vault()).totalAssets();
        assert(vaultBalAfter == vaultBalBefore + amount);
        assert(navAfter == navBefore); // idle excluded from NAV
    }

    // requestRedeem: shares escrowed
    function check_requestRedeemEscrowsShares(uint256 shares) public {
        uint256 userBalBefore = IVault(_vault()).balanceOf(_user());
        uint256 vaultBalBefore = IVault(_vault()).balanceOf(_vault());
        vm.prank(_user());
        IVault(_vault()).requestRedeem(shares);
        uint256 userBalAfter = IVault(_vault()).balanceOf(_user());
        uint256 vaultBalAfter = IVault(_vault()).balanceOf(_vault());
        assert(userBalAfter == userBalBefore - shares);
        assert(vaultBalAfter == vaultBalBefore + shares);
    }

    // syncRedeem: shares burned from user, totalSupply decreases
    function check_syncRedeemBurnsShares(uint256 shares, bytes calldata swapCalldata, address swapRouter) public {
        uint256 totalBefore = IVault(_vault()).totalSupply();
        uint256 userSharesBefore = IVault(_vault()).balanceOf(_user());
        vm.prank(_user());
        IVault(_vault()).syncRedeem(shares, swapCalldata, swapRouter, _flashLoanRouter());
        uint256 totalAfter = IVault(_vault()).totalSupply();
        uint256 userSharesAfter = IVault(_vault()).balanceOf(_user());
        assert(totalAfter == totalBefore - shares);
        assert(userSharesAfter == userSharesBefore - shares);
    }

    // processDeposits: shares minted, navAfter > navBefore
    // [GAP] Full postcondition requires observing Strategy.deposit and delta NAV within same tx

    // processRedeems: shares burned, base distributed
    // [GAP] Full postcondition requires observing Strategy.redeem return value distribution

    // redeemCustom: reverts if user has pending redeem requests
    // [GAP] Cannot check pending redeem state for user without queue inspection getter

    // === State machine (from state-machines.md) ===

    // Pause -> Unpause: only admin can unpause
    function check_onlyAdminCanUnpause() public {
        vm.prank(_admin());
        IVault(_vault()).pause();
        vm.prank(_admin());
        IVault(_vault()).unpause();
        assert(!IVault(_vault()).paused());
    }

    // setGuardian: admin sets new guardian
    function check_adminCanSetGuardian() public {
        address newGuardian = address(0x999);
        vm.prank(_admin());
        IVault(_vault()).setGuardian(newGuardian);
        assert(IVault(_vault()).guardian() == newGuardian);
    }

    // setKeeper: admin sets new keeper
    function check_adminCanSetKeeper() public {
        address newKeeper = address(0x888);
        vm.prank(_admin());
        IVault(_vault()).setKeeper(newKeeper);
        assert(IVault(_vault()).keeper() == newKeeper);
    }

    // Deposit request: Pending -> Cancelled via cancelDeposit
    // [GAP] Need requestId from event or return value to cancel — cannot express without queue getter

    // Vault position: Empty -> Active via processDeposits, Active -> Unwound via emergencyRedeem
    // [GAP] Position state transitions tested in integration tests (requires Strategy interaction)
}
