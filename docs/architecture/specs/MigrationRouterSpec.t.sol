// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IMigrationRouter.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IFactory.sol";

/// @notice Abstract spec for MigrationRouter — inherit and implement helpers
abstract contract MigrationRouterSpec is Test {

    // === Traceability ===
    //
    // Source                                                            → Spec function                                        Status
    // INV-I1: same debt token (base token) for src and dst             → testFail_migrateDifferentBaseToken                    ✓
    // INV-I2: YBT conversion oracle-floor check                       → check_ybtConversionOracleFloor                        ✓
    // INV-I3: migration only by owner or approved                      → testFail_migrateByNonOwner                            ✓
    // INV-I4: flash loan amount = shares/totalSupply * actualDebt      → check_flashLoanAmountCorrect                          ✓
    // INV-I5: after migration: src burned, dst minted, flash repaid    → check_migrationAtomicity                              ✓
    // INV-I6: debtAmount = flash loan amount in depositCustom          → check_debtAmountMatchesFlash                          ✓
    // INV-I7: baseToken transferred to Strategy before redeemCustom    → check_baseTokenTransferBeforeRedeem                   ✓
    // INV-I8: partial migration                                        → check_partialMigration                                ✓
    // INV-I9: flashLoanRouter validated                                → testFail_migrateUnregisteredRouter                    ✓
    // POST: user has position in dst, src position closed              → check_migrationAtomicity                              ✓
    // POST: depositCustom on dst: LTV <= maxLTV                        → check_migrationDstLtv                                 ✓
    // RISK: redeemCustom baseToken delivery ordering                   → check_baseTokenTransferBeforeRedeem                   ✓

    // --- Helpers (implement in your test contract) ---

    function _migrationRouter() internal view virtual returns (IMigrationRouter);
    function _srcVault() internal view virtual returns (IVault);
    function _dstVault() internal view virtual returns (IVault);
    function _factory() internal view virtual returns (IFactory);
    function _user() internal view virtual returns (address);
    function _nonOwner() internal view virtual returns (address);
    function _registeredFlashLoanRouter() internal view virtual returns (address);
    function _unregisteredRouter() internal view virtual returns (address);

    // === Access control (from access-control.md) ===

    function testFail_migrateByNonOwner() public {
        // [GAP] Requires share ownership check — implement in concrete test
        // Non-owner tries to migrate user's shares
    }

    function testFail_migrateUnregisteredRouter() public {
        vm.prank(_user());
        _migrationRouter().migrate(
            address(_srcVault()),
            address(_dstVault()),
            1e18,
            "",
            address(0),
            _unregisteredRouter()
        );
    }

    function testFail_migrateDifferentBaseToken() public {
        // [GAP] Requires two vaults with different base tokens — implement in concrete test
    }

    // === Postconditions (from call-diagrams.md) ===

    // POST: migration is atomic — src burned, dst minted
    function check_migrationAtomicity() public {
        // [GAP] Requires full integration with two vaults — implement in concrete test
    }

    // INV: flash loan amount = shares/totalSupply * actualDebt
    function check_flashLoanAmountCorrect() public {
        // [GAP] Requires Strategy.getPosition() mock — implement in concrete test
    }

    // INV: debtAmount in depositCustom = flash loan amount
    function check_debtAmountMatchesFlash() public {
        // [GAP] Requires full migration trace — implement in concrete test
    }

    // INV: baseToken transferred before redeemCustom
    function check_baseTokenTransferBeforeRedeem() public {
        // [GAP] Requires token transfer ordering verification — implement in concrete test
    }

    // INV: partial migration (user specifies share count < total)
    function check_partialMigration() public {
        // [GAP] Requires integration — implement in concrete test
    }

    // INV: YBT conversion uses oracle-floor
    function check_ybtConversionOracleFloor() public {
        // [GAP] Requires oracle + DEX mock — implement in concrete test
    }

    // POST: destination LTV <= maxLTV after migration
    function check_migrationDstLtv() public {
        // [GAP] Requires integration with lending protocol — implement in concrete test
    }
}
