// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IStrategy.sol";

// === Traceability ===
//
// Source                                                             → Spec function                                  Status
// --- call-diagrams.md POST: lines (Strategy) ---
// POST: processDeposits swap received >= oracle floor               → [GAP] requires observing swap execution
// POST: processDeposits post-leverage LTV <= maxLTV                 → [GAP] requires reading LTV from lending protocol
// POST: processRedeems swap received >= oracle floor                → [GAP] requires observing swap execution
// POST: syncRedeem swap received >= oracle floor                    → [GAP] requires observing swap execution
// POST: depositCustom collateral supplied, debt borrowed            → [GAP] requires observing lending protocol state
// POST: depositCustom post-leverage LTV <= maxLTV                   → [GAP] requires reading LTV from lending protocol
// POST: redeemCustom pro-rata debt repaid, collateral withdrawn     → [GAP] requires observing lending protocol state
// POST: emergencyRedeem caller is keeper or guardian                → testFail_emergencyRedeemByNonKeeperOrGuardian    ✓
// POST: emergencyRedeem factory.isRegisteredRouter == true          → testFail_emergencyRedeemWithUnregisteredRouter   ✓
// POST: emergencyRedeem fraction = 1e18 (full position)             → check_emergencyRedeemFullUnwind                  ✓
// POST: emergencyRedeem actual position = (0, 0)                    → check_emergencyRedeemPositionZero                ✓
// POST: emergencyRedeem syncRedeem enters idle mode                 → [GAP] requires Vault integration
// POST: FlashLoanRouter.onFlashLoan callback validated              → testFail_onFlashLoanByNonRouter                  ✓
// --- invariants.md (Strategy) ---
// I1: NAV = oracleValue(collateral) - debt after _forceAccrue      → [GAP] requires oracle + lending protocol
// I2: No internal balance tracking                                  → [GAP] implementation concern, code review
// I3: Proportional exit preserves LTV                               → [GAP] requires pre/post LTV from lending protocol
// I4: Post-leverage LTV <= maxLTV after deposit/depositCustom       → [GAP] requires LTV from lending protocol
// I5: Strategy is position owner                                    → [GAP] protocol-specific check
// I6: emergencyRedeem = full unwind, fraction = 1e18                → check_emergencyRedeemFullUnwind                  ✓
// I7: _forceAccrue before every position read                       → [GAP] internal implementation concern
// I8: fraction argument scaling                                     → [GAP] requires Vault integration
// I9: emergencyRedeem only keeper or guardian                       → testFail_emergencyRedeemByNonKeeperOrGuardian    ✓
// I10: maxLTV admin-settable                                        → check_adminCanSetMaxLTV                           ✓
// I11: swap calldata margin, dust in Strategy                       → [GAP] requires observing swap execution
// I12: Strategy does NOT store FlashLoanRouter                      → verified structurally (no flashLoanRouter() view)  ✓
// I13: emergencyRedeem validates flashLoanRouter vs Factory          → testFail_emergencyRedeemWithUnregisteredRouter   ✓
// --- access-control.md (Strategy restricted functions) ---
// deposit: vault only                                               → testFail_depositByNonVault                       ✓
// redeem: vault only                                                → testFail_redeemByNonVault                        ✓
// syncRedeem: vault only                                            → testFail_syncRedeemByNonVault                    ✓
// depositCustom: vault only                                         → testFail_depositCustomByNonVault                 ✓
// redeemCustom: vault only                                          → testFail_redeemCustomByNonVault                  ✓
// emergencyRedeem: keeper or guardian                               → testFail_emergencyRedeemByNonKeeperOrGuardian    ✓
// emergencyRedeem: keeper can call                                  → check_emergencyRedeemByKeeper                     ✓
// emergencyRedeem: guardian can call                                → check_emergencyRedeemByGuardian                   ✓
// setMaxLTV: admin only                                             → testFail_setMaxLTVByNonAdmin                      ✓
// onFlashLoan: FlashLoanRouter only                                 → testFail_onFlashLoanByNonRouter                  ✓
// getPosition: anyone                                               → check_getPositionOpenAccess                       ✓
// --- state-machines.md (Strategy via Vault Position) ---
// Active → Unwound via emergencyRedeem                              → check_activeToUnwoundViaEmergencyRedeem           ✓
// --- risks.md (mitigations on Strategy) ---
// Excessive leverage / liquidation risk (maxLTV)                    → [GAP] requires LTV from lending protocol
// LTV degradation from partial exit                                 → [GAP] requires pre/post LTV comparison
// Bad keeper/user calldata (oracle-floor check)                     → [GAP] requires observing swap execution

interface IERC20Bal {
    function balanceOf(address account) external view returns (uint256);
}

abstract contract StrategySpec is Test {

    // --- Helpers (implement in your test contract) ---

    function _vault() internal view virtual returns (address);
    function _strategy() internal view virtual returns (address);
    function _factory() internal view virtual returns (address);
    function _token() internal view virtual returns (address);
    function _keeper() internal view virtual returns (address);
    function _guardian() internal view virtual returns (address);
    function _admin() internal view virtual returns (address);
    function _user() internal view virtual returns (address);
    function _flashLoanRouter() internal view virtual returns (address);

    // === Invariants (from invariants.md) ===

    // I2: No internal balance tracking — position always read from protocol
    // [GAP] Cannot verify absence of internal tracking from spec — implementation concern

    // I3: Proportional exit preserves LTV
    // [GAP] Requires pre/post LTV comparison during redeem with active position

    // I4: Post-leverage LTV <= maxLTV after deposit
    // [GAP] Requires reading LTV from lending protocol after deposit execution

    // I5: Strategy contract is position owner in lending protocol
    // [GAP] Requires checking lending protocol position ownership — protocol-specific

    // I6: emergencyRedeem = full unwind (fraction = 1e18)
    function check_emergencyRedeemFullUnwind(bytes calldata swapCalldata, address swapRouter) public {
        vm.prank(_keeper());
        IStrategy(_strategy()).emergencyRedeem(swapCalldata, swapRouter, _flashLoanRouter());
        (uint256 collateral, uint256 debt) = IStrategy(_strategy()).getPosition();
        assert(collateral == 0);
        assert(debt == 0);
    }

    // I7: _forceAccrue called before every position read
    // [GAP] Internal implementation concern — cannot observe from spec

    // I10: maxLTV is admin-settable
    function check_adminCanSetMaxLTV(uint256 newMaxLTV) public {
        vm.prank(_admin());
        IStrategy(_strategy()).setMaxLTV(newMaxLTV);
        assert(IStrategy(_strategy()).maxLTV() == newMaxLTV);
    }

    // I12: Strategy does NOT store FlashLoanRouter — receives as parameter
    // Verified structurally: IStrategy has no flashLoanRouter() view function
    // deposit/redeem/syncRedeem/emergencyRedeem all take flashLoanRouter as parameter

    // I13: emergencyRedeem validates flashLoanRouter against Factory registry
    function testFail_emergencyRedeemWithUnregisteredRouter() public {
        address unregistered = address(0xbad);
        vm.prank(_keeper());
        IStrategy(_strategy()).emergencyRedeem("", address(0), unregistered);
    }

    // === Access control (from access-control.md) ===

    // deposit: vault only
    function testFail_depositByNonVault() public {
        vm.prank(_user());
        IStrategy(_strategy()).deposit(1e18, "", address(0), _flashLoanRouter());
    }

    // redeem: vault only
    function testFail_redeemByNonVault() public {
        vm.prank(_user());
        IStrategy(_strategy()).redeem(1e18, "", address(0), _flashLoanRouter());
    }

    // syncRedeem: vault only
    function testFail_syncRedeemByNonVault() public {
        vm.prank(_user());
        IStrategy(_strategy()).syncRedeem(1e18, "", address(0), _flashLoanRouter());
    }

    // depositCustom: vault only
    function testFail_depositCustomByNonVault() public {
        vm.prank(_user());
        IStrategy(_strategy()).depositCustom(1e18, 1e18);
    }

    // redeemCustom: vault only
    function testFail_redeemCustomByNonVault() public {
        vm.prank(_user());
        IStrategy(_strategy()).redeemCustom(1e18);
    }

    // emergencyRedeem: keeper or guardian only
    function testFail_emergencyRedeemByNonKeeperOrGuardian() public {
        vm.prank(_user());
        IStrategy(_strategy()).emergencyRedeem("", address(0), _flashLoanRouter());
    }

    // emergencyRedeem: keeper can call
    function check_emergencyRedeemByKeeper(bytes calldata swapCalldata, address swapRouter) public {
        vm.prank(_keeper());
        IStrategy(_strategy()).emergencyRedeem(swapCalldata, swapRouter, _flashLoanRouter());
        // should not revert
    }

    // emergencyRedeem: guardian can call
    function check_emergencyRedeemByGuardian(bytes calldata swapCalldata, address swapRouter) public {
        vm.prank(_guardian());
        IStrategy(_strategy()).emergencyRedeem(swapCalldata, swapRouter, _flashLoanRouter());
        // should not revert
    }

    // setMaxLTV: admin only
    function testFail_setMaxLTVByNonAdmin() public {
        vm.prank(_user());
        IStrategy(_strategy()).setMaxLTV(8000);
    }

    // onFlashLoan: FlashLoanRouter only
    function testFail_onFlashLoanByNonRouter() public {
        vm.prank(_user());
        IStrategy(_strategy()).onFlashLoan(address(0), 1e18, 0, "");
    }

    // getPosition: anyone can call
    function check_getPositionOpenAccess() public {
        vm.prank(_user());
        IStrategy(_strategy()).getPosition();
        // should not revert
    }

    // === Postconditions (from call-diagrams.md) ===

    // deposit: post-leverage LTV <= maxLTV
    // [GAP] Requires reading LTV from lending protocol after execution

    // redeem: returns baseToken to vault
    function check_redeemReturnsBaseToken(uint256 fraction, bytes calldata swapCalldata, address swapRouter) public {
        uint256 vaultBalBefore = IERC20Bal(_token()).balanceOf(_vault());
        vm.prank(_vault());
        uint256 returned = IStrategy(_strategy()).redeem(fraction, swapCalldata, swapRouter, _flashLoanRouter());
        uint256 vaultBalAfter = IERC20Bal(_token()).balanceOf(_vault());
        assert(returned > 0);
        assert(vaultBalAfter >= vaultBalBefore + returned);
    }

    // emergencyRedeem: position fully unwound
    function check_emergencyRedeemPositionZero(bytes calldata swapCalldata, address swapRouter) public {
        vm.prank(_keeper());
        IStrategy(_strategy()).emergencyRedeem(swapCalldata, swapRouter, _flashLoanRouter());
        (uint256 collateral, uint256 debt) = IStrategy(_strategy()).getPosition();
        assert(collateral == 0);
        assert(debt == 0);
    }

    // depositCustom: supply collateral + borrow debtAmount
    // [GAP] Full postcondition requires observing lending protocol state changes

    // redeemCustom: repay pro-rata debt + withdraw pro-rata collateral
    // [GAP] Full postcondition requires observing lending protocol state and YBT transfer

    // === State machine (from state-machines.md) ===

    // Active -> Unwound via emergencyRedeem
    function check_activeToUnwoundViaEmergencyRedeem(bytes calldata swapCalldata, address swapRouter) public {
        // Assumes position is Active (collateral > 0, debt > 0) — setup in test contract
        vm.prank(_keeper());
        IStrategy(_strategy()).emergencyRedeem(swapCalldata, swapRouter, _flashLoanRouter());
        (uint256 collateral, uint256 debt) = IStrategy(_strategy()).getPosition();
        assert(collateral == 0);
        assert(debt == 0);
    }
}
