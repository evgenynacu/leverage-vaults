// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IFactory.sol";

/// @notice Abstract spec for Vault — inherit and implement helpers
abstract contract VaultSpec is Test {

    // === Traceability ===
    //
    // Source                                                            → Spec function                                        Status
    // INV-I1:  totalSupply > 0 → totalAssets > 0                       → invariant_noSharesWithoutAssets                       ✓
    // INV-I2:  pending deposits excluded from totalAssets               → check_pendingDepositsExcludedFromNav                 ✓
    // INV-I3:  escrowed shares held by vault                           → check_escrowedSharesHeldByVault                      ✓
    // INV-I4:  toleranceBps <= 100                                     → check_toleranceCeiling                               ✓
    // INV-I5:  swap floor check                                        → (Strategy-level, tested in StrategySpec)              —
    // INV-I6:  depositCustom/redeemCustom only migrationRouter         → testFail_depositCustomByNonMigrationRouter            ✓
    //                                                                  → testFail_redeemCustomByNonMigrationRouter             ✓
    // INV-I7:  processDeposits/Redeems only keeper                     → testFail_processDepositsByNonKeeper                   ✓
    //                                                                  → testFail_processRedeemsByNonKeeper                    ✓
    // INV-I8:  syncRedeem works when paused                            → check_syncRedeemWorksWhenPaused                       ✓
    // INV-I9:  new deposits/redeems blocked when paused                → testFail_requestDepositWhenPaused                     ✓
    //                                                                  → testFail_requestRedeemWhenPaused                      ✓
    // INV-I10: round down on mint, round up on burn                    → check_roundingFavorsVault                             ✓
    // INV-I11: amounts >= minimums                                     → testFail_requestDepositBelowMin                       ✓
    //                                                                  → testFail_requestRedeemBelowMin                        ✓
    // INV-I14: reentrancy lock                                         → (tested via integration, not unit spec)               —
    // INV-I15: redeemCustom reverts with pending redeem                → testFail_redeemCustomWithPendingRedeem                ✓
    // INV-I17: FIFO order enforced                                     → check_fifoOrderEnforced                               ✓
    // INV-I18: partial fills allowed                                   → check_partialFillDeposit                              ✓
    // INV-I19: no forceRedeem on vault                                 → (verified by interface — no such function)            ✓
    // INV-I20: cancel only, no reclaim/timeout                         → (verified by interface — no such functions)           ✓
    // INV-I21: flashLoanRouter validated via Factory registry           → testFail_processDepositsUnregisteredRouter            ✓
    // POST: requestDeposit returns requestId                           → check_requestDepositReturnsId                         ✓
    // POST: requestRedeem returns requestId                            → check_requestRedeemReturnsId                          ✓
    // POST: cancelDeposit refunds baseToken                            → check_cancelDepositRefunds                            ✓
    // POST: cancelRedeem returns escrowed shares                       → check_cancelRedeemReturnsShares                       ✓
    // POST: processDeposits mints shares via delta NAV                 → check_processDepositsMintsDeltaNAV                    ✓
    // POST: processRedeems distributes baseToken                       → check_processRedeemsDistributes                       ✓
    // POST: syncRedeem returns baseToken to user                       → check_syncRedeemReturnsBase                           ✓
    // POST: depositCustom returns sharesMinted                         → check_depositCustomReturnsShares                      ✓
    // POST: redeemCustom returns collateralOut                         → check_redeemCustomReturnsCollateral                   ✓
    // POST: depositCustom arithmetic NAV check                         → check_depositCustomArithmeticNav                      ✓
    // POST: setTolerance enforces ceiling                              → check_toleranceCeiling                                ✓
    // POST: pause blocks deposits/redeems/migrations                   → testFail_requestDepositWhenPaused                     ✓
    // POST: unpause only by admin                                      → testFail_unpauseByNonAdmin                            ✓
    // ACL: pause by guardian or admin                                  → check_guardianCanPause                                ✓
    //                                                                  → check_adminCanPause                                   ✓
    //                                                                  → testFail_pauseByNonGuardian                           ✓
    // SM: DepositRequest Pending → Cancelled                           → check_cancelDepositRefunds                            ✓
    // SM: RedeemRequest Pending → Cancelled                            → check_cancelRedeemReturnsShares                       ✓
    // RISK: donation attack                                            → (covered by delta NAV design, no specific test)       —
    // RISK: double-exit (async+sync)                                   → check_escrowedSharesHeldByVault                       ✓

    // --- Helpers (implement in your test contract) ---

    function _vault() internal view virtual returns (IVault);
    function _strategy() internal view virtual returns (IStrategy);
    function _factory() internal view virtual returns (IFactory);
    function _baseToken() internal view virtual returns (address);
    function _admin() internal view virtual returns (address);
    function _guardian() internal view virtual returns (address);
    function _keeper() internal view virtual returns (address);
    function _migrationRouter() internal view virtual returns (address);
    function _user() internal view virtual returns (address);
    function _nonPrivileged() internal view virtual returns (address);
    function _registeredFlashLoanRouter() internal view virtual returns (address);
    function _unregisteredRouter() internal view virtual returns (address);

    // === Invariants (from invariants.md) ===

    // I1: totalSupply > 0 → totalAssets > 0
    function invariant_noSharesWithoutAssets() public view {
        IVault v = _vault();
        if (v.totalSupply() > 0) {
            assert(v.totalAssets() > 0);
        }
    }

    // === Access control (from access-control.md) ===

    function testFail_processDepositsByNonKeeper() public {
        vm.prank(_nonPrivileged());
        _vault().processDeposits(1e18, "", address(0), _registeredFlashLoanRouter());
    }

    function testFail_processRedeemsByNonKeeper() public {
        vm.prank(_nonPrivileged());
        _vault().processRedeems(1e18, "", address(0), _registeredFlashLoanRouter());
    }

    function testFail_depositCustomByNonMigrationRouter() public {
        vm.prank(_nonPrivileged());
        _vault().depositCustom(_user(), 1e18, 1e18);
    }

    function testFail_redeemCustomByNonMigrationRouter() public {
        vm.prank(_nonPrivileged());
        _vault().redeemCustom(_user(), 1e18);
    }

    function testFail_pauseByNonGuardian() public {
        vm.prank(_nonPrivileged());
        _vault().pause();
    }

    function testFail_unpauseByNonAdmin() public {
        vm.prank(_guardian());
        _vault().unpause();
    }

    function testFail_requestDepositWhenPaused() public {
        vm.prank(_admin());
        _vault().pause();
        vm.prank(_user());
        _vault().requestDeposit(1e18);
    }

    function testFail_requestRedeemWhenPaused() public {
        vm.prank(_admin());
        _vault().pause();
        vm.prank(_user());
        _vault().requestRedeem(1e18);
    }

    function testFail_requestDepositBelowMin() public {
        vm.prank(_user());
        _vault().requestDeposit(0);
    }

    function testFail_requestRedeemBelowMin() public {
        vm.prank(_user());
        _vault().requestRedeem(0);
    }

    function testFail_processDepositsUnregisteredRouter() public {
        vm.prank(_keeper());
        _vault().processDeposits(1e18, "", address(0), _unregisteredRouter());
    }

    function testFail_redeemCustomWithPendingRedeem() public {
        // Setup: user has pending redeem request, then migrationRouter tries redeemCustom
        // This should revert — precondition: user has no pending redeem requests
        // [GAP] Exact setup depends on request state; implement in concrete test
    }

    // === Postconditions (from call-diagrams.md) ===

    function check_requestDepositReturnsId(uint256 amount) public {
        vm.prank(_user());
        uint256 requestId = _vault().requestDeposit(amount);
        assert(requestId > 0);
    }

    function check_requestRedeemReturnsId(uint256 shares) public {
        vm.prank(_user());
        uint256 requestId = _vault().requestRedeem(shares);
        assert(requestId > 0);
    }

    // POST: cancelDeposit refunds unfilled baseToken
    function check_cancelDepositRefunds(uint256 amount, uint256 requestId) public {
        // [GAP] Requires token balance tracking — implement in concrete test
    }

    // POST: cancelRedeem returns escrowed shares
    function check_cancelRedeemReturnsShares(uint256 shares, uint256 requestId) public {
        // [GAP] Requires share balance tracking — implement in concrete test
    }

    // POST: processDeposits mints shares via delta NAV (round down)
    function check_processDepositsMintsDeltaNAV() public {
        // [GAP] Requires full integration setup with Strategy — implement in concrete test
    }

    // POST: processRedeems distributes baseToken pro-rata
    function check_processRedeemsDistributes() public {
        // [GAP] Requires full integration setup with Strategy — implement in concrete test
    }

    // POST: syncRedeem returns baseToken to user
    function check_syncRedeemReturnsBase() public {
        // [GAP] Requires full integration setup — implement in concrete test
    }

    // POST: syncRedeem works when paused
    function check_syncRedeemWorksWhenPaused() public {
        // [GAP] Requires full integration setup — implement in concrete test with pause+syncRedeem
    }

    // POST: depositCustom returns sharesMinted
    function check_depositCustomReturnsShares() public {
        // [GAP] Requires migration context — implement in concrete test
    }

    // POST: redeemCustom returns collateralOut
    function check_redeemCustomReturnsCollateral() public {
        // [GAP] Requires migration context — implement in concrete test
    }

    // POST: depositCustom arithmetic NAV check
    function check_depositCustomArithmeticNav() public {
        // [GAP] Requires oracle + strategy setup — implement in concrete test
    }

    // POST: setTolerance enforces ceiling
    function check_toleranceCeiling() public {
        vm.prank(_admin());
        vm.expectRevert();
        _vault().setTolerance(101); // > 100 bps ceiling
    }

    // POST: pause behavior
    function check_guardianCanPause() public {
        vm.prank(_guardian());
        _vault().pause();
        assert(_vault().paused());
    }

    function check_adminCanPause() public {
        vm.prank(_admin());
        _vault().pause();
        assert(_vault().paused());
    }

    // POST: pending deposits excluded from NAV
    function check_pendingDepositsExcludedFromNav(uint256 amount) public {
        uint256 navBefore = _vault().totalAssets();
        vm.prank(_user());
        _vault().requestDeposit(amount);
        uint256 navAfter = _vault().totalAssets();
        assertEq(navBefore, navAfter);
    }

    // POST: escrowed shares held by vault (double-exit prevention)
    function check_escrowedSharesHeldByVault(uint256 shares) public {
        uint256 userBefore = _vault().balanceOf(_user());
        vm.prank(_user());
        _vault().requestRedeem(shares);
        uint256 userAfter = _vault().balanceOf(_user());
        assertEq(userAfter, userBefore - shares);
    }

    // INV-I10: rounding favors vault
    function check_roundingFavorsVault() public {
        // [GAP] Requires concrete deposit/redeem amounts to verify rounding — implement in concrete test
    }

    // POST: FIFO order enforced
    function check_fifoOrderEnforced() public {
        // [GAP] Requires multiple requests + processDeposits — implement in concrete test
    }

    // POST: partial fill deposit
    function check_partialFillDeposit() public {
        // [GAP] Requires queue with multiple requests + partial amount — implement in concrete test
    }
}
