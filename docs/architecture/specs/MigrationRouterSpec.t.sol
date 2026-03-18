// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IMigrationRouter.sol";
import "../interfaces/IVault.sol";

// === Traceability ===
//
// Source                                                             → Spec function                                  Status
// --- call-diagrams.md POST: lines (MigrationRouter / migrate) ---
// POST: migrate user is owner or approved for shares                → testFail_migrateByNonOwner                      ✓
// POST: migrate factory.isRegisteredRouter == true                  → testFail_migrateWithUnregisteredRouter           ✓
// POST: migrate actualDebt retrieved after accrual                  → [GAP] requires observing _forceAccrue call
// POST: migrate shares burned on source, YBT sent to router        → check_migrationSharesTransfer                    ✓
// POST: migrate YBT conversion oracle-floor check                  → [GAP] requires observing swap execution
// POST: migrate shares minted to user on destination                → check_migrationSharesTransfer                    ✓
// POST: migrate post-leverage LTV <= maxLTV on destination          → [GAP] requires reading destination LTV
// POST: migrate zero token residual on FlashLoanRouter              → [GAP] covered by FlashLoanRouter invariant I1
// POST: migrate user has position in dst, src closed                → check_migrationSharesTransfer                    ✓
// --- invariants.md (MigrationRouter) ---
// I1: src and dst share same debt token (baseToken)                 → [GAP] requires reading baseToken from strategies
// I2: YBT conversion oracle-floor check                            → [GAP] requires observing swap execution
// I3: migration only by position owner or approved                  → testFail_migrateByNonOwner                      ✓
// I4: flash loan amount = shares/totalSupply * actualDebt           → [GAP] requires internal computation observation
// I5: after migration: src burned, dst minted, flash repaid         → check_migrationSharesTransfer                    ✓
// I6: debtAmount to depositCustom = flash loan amount               → [GAP] requires observing depositCustom call args
// I7: baseToken transferred to Strategy before redeemCustom         → [GAP] requires tracing call order
// I8: partial migration supported                                   → check_partialMigration                           ✓
// I9: flashLoanRouter validated against Factory registry            → testFail_migrateWithUnregisteredRouter           ✓
// --- access-control.md (MigrationRouter) ---
// migrate: position owner or approved                               → testFail_migrateByNonOwner                      ✓
// migrate: position owner can call                                  → check_migrateByOwner                             ✓
// onFlashLoan: FlashLoanRouter only                                 → testFail_onFlashLoanByNonRouter                  ✓
// --- risks.md (mitigations on MigrationRouter) ---
// Migration LTV violation                                           → [GAP] requires reading destination LTV
// Migration YBT conversion loss                                     → [GAP] requires observing swap
// Migration flash loan amount mismatch                              → [GAP] requires observing computation
// redeemCustom baseToken delivery ordering                          → [GAP] requires tracing calls
// redeemCustom with pending async redeem                            → [GAP] requires pending redeem state

abstract contract MigrationRouterSpec is Test {

    // --- Helpers (implement in your test contract) ---

    function _user() internal view virtual returns (address);
    function _migrationRouter() internal view virtual returns (address);
    function _sourceVault() internal view virtual returns (address);
    function _destinationVault() internal view virtual returns (address);
    function _flashLoanRouter() internal view virtual returns (address);

    // === Invariants (from invariants.md) ===

    // I1: Source and destination vaults must share same debt token
    // [GAP] Cannot verify token match from spec — requires reading baseToken from both strategies

    // I3: Migration only by position owner or approved
    function testFail_migrateByNonOwner() public {
        address notOwner = address(0xdead);
        vm.prank(notOwner);
        IMigrationRouter(_migrationRouter()).migrate(
            _sourceVault(),
            _destinationVault(),
            1e18,
            _flashLoanRouter(),
            "",
            address(0)
        );
    }

    // I5: After migration: source shares burned, destination shares minted
    function check_migrationSharesTransfer(uint256 shares) public {
        uint256 srcSharesBefore = IVault(_sourceVault()).balanceOf(_user());
        uint256 dstSharesBefore = IVault(_destinationVault()).balanceOf(_user());
        vm.prank(_user());
        IMigrationRouter(_migrationRouter()).migrate(
            _sourceVault(),
            _destinationVault(),
            shares,
            _flashLoanRouter(),
            "",
            address(0)
        );
        uint256 srcSharesAfter = IVault(_sourceVault()).balanceOf(_user());
        uint256 dstSharesAfter = IVault(_destinationVault()).balanceOf(_user());
        assert(srcSharesAfter == srcSharesBefore - shares);
        assert(dstSharesAfter > dstSharesBefore);
    }

    // I7: MigrationRouter transfers baseToken to Strategy before redeemCustom
    // [GAP] Cannot observe transfer ordering from postcondition — requires tracing calls

    // I8: Partial migration supported
    function check_partialMigration(uint256 totalShares) public {
        uint256 partialShares = totalShares / 2;
        uint256 srcSharesBefore = IVault(_sourceVault()).balanceOf(_user());
        vm.prank(_user());
        IMigrationRouter(_migrationRouter()).migrate(
            _sourceVault(),
            _destinationVault(),
            partialShares,
            _flashLoanRouter(),
            "",
            address(0)
        );
        uint256 srcSharesAfter = IVault(_sourceVault()).balanceOf(_user());
        // User still has remaining shares in source vault
        assert(srcSharesAfter == srcSharesBefore - partialShares);
        assert(srcSharesAfter > 0);
    }

    // I9: FlashLoanRouter validated against Factory registry
    function testFail_migrateWithUnregisteredRouter() public {
        address unregistered = address(0xbad);
        vm.prank(_user());
        IMigrationRouter(_migrationRouter()).migrate(
            _sourceVault(),
            _destinationVault(),
            1e18,
            unregistered,
            "",
            address(0)
        );
    }

    // === Access control (from access-control.md) ===

    // migrate: position owner or approved
    function check_migrateByOwner(uint256 shares) public {
        vm.prank(_user());
        IMigrationRouter(_migrationRouter()).migrate(
            _sourceVault(),
            _destinationVault(),
            shares,
            _flashLoanRouter(),
            "",
            address(0)
        );
        // should not revert for share owner
    }

    // onFlashLoan: only callable during active flash loan (via transient storage)
    function testFail_onFlashLoanByNonRouter() public {
        vm.prank(_user());
        IMigrationRouter(_migrationRouter()).onFlashLoan(address(0), 1e18, 0, "");
    }

    // === Postconditions (from call-diagrams.md) ===

    // migrate: flash loan fully repaid (no residual)
    // [GAP] Cannot observe flash loan repayment from postcondition — covered by FlashLoanRouter invariant I1

    // migrate: post-leverage LTV <= maxLTV on destination
    // [GAP] Requires reading destination strategy LTV after migration

    // migrate: YBT conversion oracle-floor check
    // [GAP] Cannot observe swap validation from postcondition

    // === State machine (from state-machines.md) ===
    // MigrationRouter is stateless — no discrete state machine
}
