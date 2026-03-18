// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IMigrationRouter {
    // Migrate shares from source vault to destination vault atomically via flash loan
    // User specifies share count for partial migration
    // Precondition: user must have approved MigrationRouter to transfer shares (or vault handles escrow)
    // swapCalldata/swapRouter used for YBT conversion if source and dest YBT differ
    // ACCESS: anyone (user initiates for own shares, or approved address)
    function migrate(
        address sourceVault,
        address destVault,
        uint256 shares,
        bytes calldata swapCalldata,
        address swapRouter,
        address flashLoanRouter
    ) external;
}
