// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IFactory.sol";

/// @notice Abstract spec for Strategy — inherit and implement helpers
abstract contract StrategySpec is Test {

    // === Traceability ===
    //
    // Source                                                            → Spec function                                        Status
    // INV-I1:  NAV = oracleValue(collateral) - debt after accrual      → check_navReflectsActualPosition                      ✓
    // INV-I2:  no internal balance tracking                            → (design constraint, not testable as spec)             —
    // INV-I3:  proportional exit preserves LTV                         → check_proportionalExitPreservesLtv                    ✓
    // INV-I4:  post-leverage LTV <= maxLTV on deposit                  → check_depositEnforcesMaxLtv                           ✓
    // INV-I5:  strategy owns position                                  → (deployment constraint)                               —
    // INV-I6:  emergencyRedeem = full position (fraction=1e18)         → check_emergencyRedeemFullPosition                     ✓
    // INV-I7:  _forceAccrue before every position read                 → (internal, verified by integration tests)             —
    // INV-I8:  fraction = shares*1e18/totalSupply                      → (Vault computes, tested in VaultSpec)                 —
    // INV-I9:  emergencyRedeem only keeper/guardian                    → testFail_emergencyRedeemByNonKeeper                   ✓
    // INV-I10: maxLTV is admin-settable                                → check_adminCanSetMaxLtv                               ✓
    // INV-I11: swap dust stays in Strategy                             → check_swapDustRemainsInStrategy                       ✓
    // INV-I12: no stored flashLoanRouter                               → (design constraint, verified by interface)            ✓
    // INV-I13: emergencyRedeem validates flashLoanRouter               → testFail_emergencyRedeemUnregisteredRouter            ✓
    // POST: deposit leverages position                                 → check_depositIncreasesPosition                        ✓
    // POST: redeem unwinds proportional position                       → check_redeemDecreasesPosition                         ✓
    // POST: syncRedeem unwinds proportional position                   → check_syncRedeemDecreasesPosition                     ✓
    // POST: depositCustom supplies and borrows                         → check_depositCustomSuppliesToLending                  ✓
    // POST: redeemCustom repays and withdraws                          → check_redeemCustomRepaysAndWithdraws                  ✓
    // POST: emergencyRedeem position = (0,0)                           → check_emergencyRedeemFullPosition                     ✓
    // POST: swap floor check on all swaps                              → check_swapFloorEnforced                               ✓
    // POST: getPosition calls _forceAccrue                             → check_getPositionAccrues                              ✓
    // ACL: deposit/redeem/syncRedeem/depositCustom/redeemCustom onlyVault → testFail_depositByNonVault                         ✓
    // ACL: setMaxLTV onlyAdmin                                        → testFail_setMaxLtvByNonAdmin                           ✓

    // --- Helpers (implement in your test contract) ---

    function _strategy() internal view virtual returns (IStrategy);
    function _factory() internal view virtual returns (IFactory);
    function _vault() internal view virtual returns (address);
    function _admin() internal view virtual returns (address);
    function _keeper() internal view virtual returns (address);
    function _guardian() internal view virtual returns (address);
    function _nonPrivileged() internal view virtual returns (address);
    function _registeredFlashLoanRouter() internal view virtual returns (address);
    function _unregisteredRouter() internal view virtual returns (address);

    // === Access control (from access-control.md) ===

    function testFail_depositByNonVault() public {
        vm.prank(_nonPrivileged());
        _strategy().deposit(1e18, "", address(0), _registeredFlashLoanRouter());
    }

    function testFail_emergencyRedeemByNonKeeper() public {
        vm.prank(_nonPrivileged());
        _strategy().emergencyRedeem("", address(0), _registeredFlashLoanRouter());
    }

    function testFail_setMaxLtvByNonAdmin() public {
        vm.prank(_nonPrivileged());
        _strategy().setMaxLTV(9000);
    }

    function testFail_emergencyRedeemUnregisteredRouter() public {
        vm.prank(_keeper());
        _strategy().emergencyRedeem("", address(0), _unregisteredRouter());
    }

    // === Postconditions (from call-diagrams.md) ===

    // POST: deposit increases position (collateral > 0, debt > 0 after)
    function check_depositIncreasesPosition() public {
        // [GAP] Requires full integration with lending protocol — implement in concrete test
    }

    // POST: redeem decreases position proportionally
    function check_redeemDecreasesPosition() public {
        // [GAP] Requires full integration — implement in concrete test
    }

    // POST: syncRedeem decreases position proportionally
    function check_syncRedeemDecreasesPosition() public {
        // [GAP] Requires full integration — implement in concrete test
    }

    // POST: depositCustom supplies collateral and borrows debt
    function check_depositCustomSuppliesToLending() public {
        // [GAP] Requires full integration — implement in concrete test
    }

    // POST: redeemCustom repays debt and withdraws collateral
    function check_redeemCustomRepaysAndWithdraws() public {
        // [GAP] Requires full integration — implement in concrete test
    }

    // POST: emergencyRedeem fully unwinds position to (0,0)
    function check_emergencyRedeemFullPosition() public {
        // [GAP] Requires full integration — implement in concrete test
        // After emergencyRedeem: getPosition() should return (0, 0)
    }

    // POST: deposit enforces maxLTV
    function check_depositEnforcesMaxLtv() public {
        // [GAP] Requires integration with lending protocol to measure LTV — implement in concrete test
    }

    // INV: NAV reflects actual position after accrual
    function check_navReflectsActualPosition() public {
        // [GAP] Requires oracle + lending protocol integration — implement in concrete test
    }

    // INV: proportional exit preserves LTV
    function check_proportionalExitPreservesLtv() public {
        // [GAP] Requires integration — implement in concrete test
    }

    // INV: swap floor enforced
    function check_swapFloorEnforced() public {
        // [GAP] Requires DEX mock — implement in concrete test
    }

    // INV: swap dust remains in Strategy
    function check_swapDustRemainsInStrategy() public {
        // [GAP] Requires integration — implement in concrete test
    }

    // POST: getPosition calls _forceAccrue
    function check_getPositionAccrues() public {
        // [GAP] Requires lending protocol mock — implement in concrete test
    }

    // INV: admin can set maxLTV
    function check_adminCanSetMaxLtv() public {
        vm.prank(_admin());
        _strategy().setMaxLTV(8000);
        assertEq(_strategy().maxLTV(), 8000);
    }
}
