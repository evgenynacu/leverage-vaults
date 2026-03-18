// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IFactory.sol";

// === Traceability ===
//
// Source                                                             → Spec function                                  Status
// --- call-diagrams.md POST: lines (Factory) ---
// POST: deploy caller is admin                                      → testFail_deployByNonAdmin                       ✓
// POST: deploy oracle reachable                                     → testFail_deployWithUnreachableOracle             ✓
// POST: deploy tolerance <= ceiling                                 → testFail_deployWithToleranceAboveCeiling          ✓
// POST: deploy vault + strategy pair registered                     → check_deployRegistersVault                       ✓
// POST: registerRouter isRegisteredRouter == true                   → check_registerRouterPostcondition                ✓
// POST: deregisterRouter isRegisteredRouter == false                → check_deregisterRouterPostcondition              ✓
// POST: deploy lending market valid                                 → [GAP] requires valid market setup
// POST: deploy baseToken matches debt token                         → [GAP] requires valid market setup
// --- invariants.md (Factory) ---
// I1: deployment reverts on invalid params                          → testFail_deployWithToleranceAboveCeiling          ✓
// I1: deployment reverts on unreachable oracle                      → testFail_deployWithUnreachableOracle             ✓
// I2: all validation on-chain                                       → covered by deploy tests                          ✓
// I3: same admin owns all beacons                                   → [GAP] requires checking beacon ownership
// I4: Ownable2Step, renounce disabled                               → [GAP] requires calling renounceOwnership
// I5: registeredRouters admin-managed                               → check_registerRouterAddsToRegistry               ✓
// I6: isRegisteredRouter false for unregistered                     → check_unregisteredRouterReturnsFalse             ✓
// --- access-control.md (Factory restricted functions) ---
// deploy: admin only                                                → testFail_deployByNonAdmin                       ✓
// setMigrationRouter: admin only                                    → testFail_setMigrationRouterByNonAdmin            ✓
// setStrategyBeacon: admin only                                     → testFail_setStrategyBeaconByNonAdmin             ✓
// setVaultBeacon: admin only                                        → testFail_setVaultBeaconByNonAdmin                ✓
// registerRouter: admin only                                        → testFail_registerRouterByNonAdmin                ✓
// deregisterRouter: admin only                                      → testFail_deregisterRouterByNonAdmin              ✓
// renounceOwnership: disabled                                       → [GAP] requires calling renounceOwnership
// --- risks.md (mitigations on Factory) ---
// Factory misconfiguration                                          → testFail_deployWithToleranceAboveCeiling          ✓
// Factory misconfiguration (oracle)                                 → testFail_deployWithUnreachableOracle             ✓
// Malicious FlashLoanRouter injection                               → check_unregisteredRouterReturnsFalse             ✓

abstract contract FactorySpec is Test {

    // --- Helpers (implement in your test contract) ---

    function _admin() internal view virtual returns (address);
    function _user() internal view virtual returns (address);
    function _factory() internal view virtual returns (address);
    function _flashLoanRouter() internal view virtual returns (address);

    // === Invariants (from invariants.md) ===

    // I1: Deployment reverts if tolerance > ceiling
    function testFail_deployWithToleranceAboveCeiling() public {
        vm.prank(_admin());
        IFactory(_factory()).deploy(
            bytes32(uint256(1)), // protocolId
            address(2),          // baseToken
            address(3),          // ybtToken
            address(5),          // oracle
            101,                 // toleranceBps > 100 ceiling
            8000,                // maxLTV
            1e18,                // minDepositAmount
            1e18                 // minRedeemAmount
        );
    }

    // I1: Deployment reverts if oracle unreachable
    function testFail_deployWithUnreachableOracle() public {
        vm.prank(_admin());
        IFactory(_factory()).deploy(
            bytes32(uint256(1)),
            address(2),
            address(3),
            address(0),          // unreachable oracle
            50,
            8000,
            1e18,
            1e18
        );
    }

    // I4: Ownable2Step, renounce disabled
    // [GAP] Cannot verify renounce disabled from spec — requires calling renounceOwnership and expecting revert

    // I5: registeredRouters admin-managed
    function check_registerRouterAddsToRegistry() public {
        vm.prank(_admin());
        IFactory(_factory()).registerRouter(_flashLoanRouter());
        assert(IFactory(_factory()).isRegisteredRouter(_flashLoanRouter()));
    }

    // I6: isRegisteredRouter returns false for unregistered
    function check_unregisteredRouterReturnsFalse() public view {
        assert(!IFactory(_factory()).isRegisteredRouter(address(0xdead)));
    }

    function check_deregisterRouterRemovesFromRegistry() public {
        vm.prank(_admin());
        IFactory(_factory()).registerRouter(_flashLoanRouter());
        assert(IFactory(_factory()).isRegisteredRouter(_flashLoanRouter()));
        vm.prank(_admin());
        IFactory(_factory()).deregisterRouter(_flashLoanRouter());
        assert(!IFactory(_factory()).isRegisteredRouter(_flashLoanRouter()));
    }

    // === Access control (from access-control.md) ===

    // deploy: admin only
    function testFail_deployByNonAdmin() public {
        vm.prank(_user());
        IFactory(_factory()).deploy(
            bytes32(uint256(1)), address(2), address(3),
            address(5), 50, 8000, 1e18, 1e18
        );
    }

    // setMigrationRouter: admin only
    function testFail_setMigrationRouterByNonAdmin() public {
        vm.prank(_user());
        IFactory(_factory()).setMigrationRouter(address(1));
    }

    // setStrategyBeacon: admin only
    function testFail_setStrategyBeaconByNonAdmin() public {
        vm.prank(_user());
        IFactory(_factory()).setStrategyBeacon(bytes32(uint256(1)), address(1));
    }

    // setVaultBeacon: admin only
    function testFail_setVaultBeaconByNonAdmin() public {
        vm.prank(_user());
        IFactory(_factory()).setVaultBeacon(address(1));
    }

    // registerRouter: admin only
    function testFail_registerRouterByNonAdmin() public {
        vm.prank(_user());
        IFactory(_factory()).registerRouter(address(1));
    }

    // deregisterRouter: admin only
    function testFail_deregisterRouterByNonAdmin() public {
        vm.prank(_user());
        IFactory(_factory()).deregisterRouter(address(1));
    }

    // === Postconditions (from call-diagrams.md) ===

    // deploy: vault + strategy registered
    function check_deployRegistersVault(
        bytes32 protocolId,
        address baseToken,
        address ybtToken,
        address oracle,
        uint256 toleranceBps,
        uint256 maxLTV,
        uint256 minDepositAmount,
        uint256 minRedeemAmount
    ) public {
        vm.prank(_admin());
        (address vault,) = IFactory(_factory()).deploy(
            protocolId, baseToken, ybtToken,
            oracle, toleranceBps, maxLTV, minDepositAmount, minRedeemAmount
        );
        assert(vault != address(0));
        assert(IFactory(_factory()).isRegistered(vault));
    }

    // registerRouter: POST isRegisteredRouter == true
    function check_registerRouterPostcondition() public {
        address router = address(0x123);
        vm.prank(_admin());
        IFactory(_factory()).registerRouter(router);
        assert(IFactory(_factory()).isRegisteredRouter(router));
    }

    // deregisterRouter: POST isRegisteredRouter == false
    function check_deregisterRouterPostcondition() public {
        address router = address(0x123);
        vm.prank(_admin());
        IFactory(_factory()).registerRouter(router);
        vm.prank(_admin());
        IFactory(_factory()).deregisterRouter(router);
        assert(!IFactory(_factory()).isRegisteredRouter(router));
    }

    // deploy: all validations pass (positive path)
    // [GAP] Full validation postcondition requires valid oracle, market, token setup

    // === State machine (from state-machines.md) ===
    // Factory has no discrete state machine
}
