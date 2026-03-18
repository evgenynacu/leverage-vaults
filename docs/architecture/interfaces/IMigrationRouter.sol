// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IMigrationRouter {
    // --- User actions ---

    // Migrate shares from source vault to destination vault via flash loan
    // User must approve MigrationRouter to transfer their source vault shares (or be msg.sender)
    // Partial migration supported: user specifies share count
    // Source and destination vaults must share the same baseToken (debt token)
    // flashLoanRouter validated against Factory registry
    function migrate(
        address sourceVault,
        address destVault,
        uint256 shares,
        address flashLoanRouter,
        bytes calldata swapCalldata,
        address swapRouter
    ) external;

    // --- Flash loan callback ---

    // Called by FlashLoanRouter during migration flash loan execution
    function onFlashLoan(address token, uint256 amount, uint256 fee, bytes calldata data) external;
}
