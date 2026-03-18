// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../interfaces/IFlashLoanRouter.sol";

/// @notice Abstract spec for FlashLoanRouter — inherit and implement helpers
abstract contract FlashLoanRouterSpec is Test {

    // === Traceability ===
    //
    // Source                                                            → Spec function                                        Status
    // INV-I1: no token residual after flash loan                       → invariant_zeroTokenResidual                           ✓
    // INV-I2: callback only when active                                → testFail_spoofedCallback                              ✓
    // INV-I3: single flash loan at a time                              → testFail_nestedFlashLoan                              ✓
    // INV-I4: zero fee                                                 → check_zeroFee                                         ✓
    // INV-I5: initiator from transient storage                         → check_callbackToInitiator                             ✓
    // INV-I6: executeFlashLoan open access                             → check_anyoneCanCallExecute                            ✓
    // POST: transient storage cleared after completion                 → invariant_zeroTokenResidual                           ✓

    // --- Helpers (implement in your test contract) ---

    function _flashLoanRouter() internal view virtual returns (IFlashLoanRouter);
    function _token() internal view virtual returns (address);
    function _anyUser() internal view virtual returns (address);

    // === Invariants (from invariants.md) ===

    // I1: no token residual after flash loan completes
    function invariant_zeroTokenResidual() public view {
        // After any sequence of calls, FlashLoanRouter should hold zero tokens
        // [GAP] Requires ERC20 balance check on _flashLoanRouter address — implement in concrete test
    }

    // === Access control (from access-control.md) ===

    // I6: anyone can call executeFlashLoan
    function check_anyoneCanCallExecute() public {
        // [GAP] Requires flash loan provider mock — implement in concrete test
    }

    // === Postconditions (from call-diagrams.md) ===

    // I2: spoofed callback reverts (no active flag set)
    function testFail_spoofedCallback() public {
        // [GAP] Requires calling provider callback on FlashLoanRouter without active flash loan — implement in concrete test
    }

    // I3: nested flash loan reverts
    function testFail_nestedFlashLoan() public {
        // [GAP] Requires initiator that tries to re-enter executeFlashLoan during callback — implement in concrete test
    }

    // I4: zero fee on all flash loans
    function check_zeroFee() public {
        // [GAP] Requires provider mock — implement in concrete test
        // onFlashLoan callback receives fee=0
    }

    // I5: callback routed to correct initiator
    function check_callbackToInitiator() public {
        // [GAP] Requires mock initiator implementing IFlashLoanReceiver — implement in concrete test
    }
}
