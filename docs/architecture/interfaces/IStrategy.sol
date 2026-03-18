// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IStrategy {
    // --- Called by Vault (processDeposits) ---

    // onlyVault
    // Leverage: flash loan -> swap base->YBT -> supply collateral -> borrow to repay flash loan
    // Checks post-leverage LTV <= maxLTV, reverts if exceeded
    // flashLoanRouter already validated against Factory registry by Vault
    function deposit(uint256 amount, bytes calldata swapCalldata, address swapRouter, address flashLoanRouter) external;

    // --- Called by Vault (processRedeems) ---

    // onlyVault
    // Unwind: flash loan repays fraction of debt -> withdraw fraction of collateral -> swap YBT->base -> repay flash loan
    // fraction = 1e18-scaled proportion of position to unwind
    // flashLoanRouter already validated against Factory registry by Vault
    function redeem(uint256 fraction, bytes calldata swapCalldata, address swapRouter, address flashLoanRouter) external returns (uint256 baseTokenOut);

    // --- Called by Vault (syncRedeem) ---

    // onlyVault
    // Same as redeem but user-provided calldata; always available even when paused
    // Idle mode: if no position, skip flash loan and return fraction of idle base directly
    // flashLoanRouter already validated against Factory registry by Vault
    function syncRedeem(uint256 fraction, bytes calldata swapCalldata, address swapRouter, address flashLoanRouter) external returns (uint256 baseTokenOut);

    // --- Called by Vault (depositCustom) ---

    // onlyVault
    // Migration deposit: supply collateral to lending, borrow debtAmount, send debt back to msg.sender (MigrationRouter via Vault)
    // Checks post-leverage LTV <= maxLTV
    function depositCustom(uint256 collateralAmount, uint256 debtAmount) external;

    // --- Called by Vault (redeemCustom) ---

    // onlyVault
    // Migration redeem: use baseToken (already transferred by MigrationRouter) to repay fraction of debt, withdraw fraction of collateral, send YBT to msg.sender (MigrationRouter via Vault)
    // fraction = 1e18-scaled, computed by Vault from shares/totalSupply
    function redeemCustom(uint256 fraction) external returns (uint256 collateralOut);

    // --- Called directly by keeper/guardian ---

    // onlyKeeperOrGuardian
    // Emergency full unwind: fraction=1e18, flash loan -> repay all debt -> withdraw all collateral -> swap YBT->base
    // Callable directly on Strategy, not through Vault
    // flashLoanRouter validated against Factory registry by Strategy
    function emergencyRedeem(bytes calldata swapCalldata, address swapRouter, address flashLoanRouter) external;

    // --- Flash loan callback ---

    // Called by FlashLoanRouter during flash loan execution
    function onFlashLoan(address token, uint256 amount, uint256 fee, bytes calldata data) external;

    // --- Admin ---

    // onlyAdmin
    // Set maximum post-leverage LTV ratio
    function setMaxLTV(uint256 newMaxLTV) external;

    // --- View ---

    // Actual lending position after _forceAccrue: (collateral in YBT terms, debt in baseToken terms)
    function getPosition() external returns (uint256 collateral, uint256 debt);

    // Base token (deposit and debt token, always the same)
    function baseToken() external view returns (address);

    // Yield-bearing token address
    function ybtToken() external view returns (address);

    // Current max LTV parameter
    function maxLTV() external view returns (uint256);

    // Associated vault address
    function vault() external view returns (address);

    // Factory address (for FlashLoanRouter registry validation)
    function factory() external view returns (address);

    // Keeper address
    function keeper() external view returns (address);

    // Guardian address
    function guardian() external view returns (address);
}
