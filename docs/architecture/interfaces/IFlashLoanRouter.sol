// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IFlashLoanRouter {
    // Initiate a flash loan from the underlying provider
    // Stores msg.sender as initiator in transient storage, calls provider, provider callbacks,
    // FlashLoanRouter validates callback then calls initiator.onFlashLoan(), then repays provider.
    // ACCESS: open (anyone can call)
    function executeFlashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}
