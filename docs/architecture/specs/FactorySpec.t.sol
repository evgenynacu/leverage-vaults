// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IFactory.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IStrategy.sol";

/// @notice Abstract spec for Factory — inherit and implement helpers
abstract contract FactorySpec is Test {

    // === Traceability ===
    //
    // Source                                                            → Spec function                                        Status
    // INV-I1: deploy reverts if oracle/market/tolerance/token invalid  → testFail_deployInvalidOracle                          ✓
    //                                                                  → testFail_deployToleranceAboveCeiling                  ✓
    //                                                                  → testFail_deployTokenMismatch                          ✓
    // INV-I2: all validation on-chain in deploy tx                     → (covered by deploy revert tests)                      ✓
    // INV-I3: same admin owns all beacons                              → (deployment constraint, not unit-testable)            —
    // INV-I4: Ownable2Step, renounce disabled                          → testFail_renounceOwnership                            ✓
    // INV-I5: registeredRouters admin-managed                          → check_registerRouter                                  ✓
    //                                                                  → check_deregisterRouter                                ✓
    // INV-I6: isRegisteredRouter only for registered                   → check_unregisteredRouterReturnsFalse                  ✓
    // POST: deploy returns (vault, strategy)                           → check_deployReturnsAddresses                          ✓
    // POST: registerRouter makes isRegisteredRouter true               → check_registerRouter                                  ✓
    // POST: deregisterRouter makes isRegisteredRouter false            → check_deregisterRouter                                ✓
    // ACL: deploy onlyAdmin                                           → testFail_deployByNonAdmin                              ✓
    // ACL: registerRouter onlyAdmin                                   → testFail_registerRouterByNonAdmin                      ✓
    // ACL: deregisterRouter onlyAdmin                                 → testFail_deregisterRouterByNonAdmin                    ✓
    // ACL: setMigrationRouter onlyAdmin                               → testFail_setMigrationRouterByNonAdmin                  ✓

    // --- Helpers (implement in your test contract) ---

    function _factory() internal view virtual returns (IFactory);
    function _admin() internal view virtual returns (address);
    function _nonAdmin() internal view virtual returns (address);
    function _validRouter() internal view virtual returns (address);

    // === Access control (from access-control.md) ===

    function testFail_deployByNonAdmin() public {
        vm.prank(_nonAdmin());
        _factory().deploy(bytes32(0), address(0), address(0), address(0), 50, 8000, 1e6, 1e6, "");
    }

    function testFail_registerRouterByNonAdmin() public {
        vm.prank(_nonAdmin());
        _factory().registerRouter(_validRouter());
    }

    function testFail_deregisterRouterByNonAdmin() public {
        vm.prank(_nonAdmin());
        _factory().deregisterRouter(_validRouter());
    }

    function testFail_setMigrationRouterByNonAdmin() public {
        vm.prank(_nonAdmin());
        _factory().setMigrationRouter(address(1));
    }

    function testFail_renounceOwnership() public {
        // Ownable2Step with renounce disabled — should revert
        // [GAP] Exact function depends on OZ implementation — implement in concrete test
    }

    // === Postconditions (from call-diagrams.md) ===

    function check_deployReturnsAddresses() public {
        // [GAP] Requires valid deployment params (oracle, market, etc.) — implement in concrete test
    }

    function testFail_deployInvalidOracle() public {
        // [GAP] Requires mock oracle that fails — implement in concrete test
    }

    function testFail_deployToleranceAboveCeiling() public {
        vm.prank(_admin());
        _factory().deploy(bytes32(0), address(0), address(0), address(0), 101, 8000, 1e6, 1e6, "");
    }

    function testFail_deployTokenMismatch() public {
        // [GAP] Requires mock lending market with different debt token — implement in concrete test
    }

    // POST: registerRouter / deregisterRouter
    function check_registerRouter() public {
        vm.prank(_admin());
        _factory().registerRouter(_validRouter());
        assertTrue(_factory().isRegisteredRouter(_validRouter()));
    }

    function check_deregisterRouter() public {
        vm.prank(_admin());
        _factory().registerRouter(_validRouter());
        vm.prank(_admin());
        _factory().deregisterRouter(_validRouter());
        assertFalse(_factory().isRegisteredRouter(_validRouter()));
    }

    function check_unregisteredRouterReturnsFalse() public view {
        assertFalse(_factory().isRegisteredRouter(address(0xdead)));
    }
}
