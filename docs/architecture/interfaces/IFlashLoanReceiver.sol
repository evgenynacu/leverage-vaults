// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

/// Callback interface for flash loan receivers.
/// Both Strategy and MigrationRouter implement this.
/// Called by FlashLoanRouter after receiving funds from the provider.
interface IFlashLoanReceiver {
    // Called by FlashLoanRouter during flash loan execution
    // Receiver must execute its logic and ensure repayment funds are available
    // fee is always 0 (zero-fee providers only)
    function onFlashLoan(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}
