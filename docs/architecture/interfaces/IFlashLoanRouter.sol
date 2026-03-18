// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IFlashLoanRouter {
    // --- Flash loan execution (open access) ---

    // Anyone can call; initiator stored in transient storage for callback validation
    // Calls provider, provider calls back, router validates and forwards to initiator.onFlashLoan()
    function executeFlashLoan(address token, uint256 amount, bytes calldata data) external;

    // --- View ---

    // Flash loan provider address
    function provider() external view returns (address);
}
