// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IStrategy {
    // --- Called by Vault (keeper path via processDeposits) ---

    // Leverage: flash loan -> swap base->YBT -> supply -> borrow -> repay flash loan
    // Checks post-leverage LTV against maxLTV
    // ACCESS: onlyVault
    function deposit(
        uint256 amount,
        bytes calldata swapCalldata,
        address swapRouter,
        address flashLoanRouter
    ) external;

    // Unwind: flash loan -> repay debt -> withdraw collateral -> swap YBT->base -> repay flash loan
    // fraction = shares * 1e18 / totalSupply, computed by Vault
    // ACCESS: onlyVault
    function redeem(
        uint256 fraction,
        bytes calldata swapCalldata,
        address swapRouter,
        address flashLoanRouter
    ) external returns (uint256 baseTokenOut);

    // --- Called by Vault (migration path via depositCustom/redeemCustom) ---

    // Supply collateral to lending protocol, borrow debtAmount, send debt to caller (MigrationRouter via Vault)
    // Checks post-leverage LTV against maxLTV
    // ACCESS: onlyVault
    function depositCustom(
        uint256 collateralAmount,
        uint256 debtAmount
    ) external;

    // Repay proportional debt (using baseToken already transferred to Strategy), withdraw proportional collateral
    // Sends collateral (YBT) to caller (MigrationRouter via Vault)
    // fraction = shares * 1e18 / totalSupply, computed by Vault
    // ACCESS: onlyVault
    function redeemCustom(uint256 fraction) external returns (uint256 collateralOut);

    // --- Called by Vault (sync redeem path) ---

    // User-initiated proportional unwind with user-provided calldata
    // fraction = shares * 1e18 / totalSupply, computed by Vault
    // ACCESS: onlyVault
    function syncRedeem(
        uint256 fraction,
        bytes calldata swapCalldata,
        address swapRouter,
        address flashLoanRouter
    ) external returns (uint256 baseTokenOut);

    // --- Keeper / Guardian direct call ---

    // Full position emergency unwind (fraction = 1e18)
    // ACCESS: onlyKeeperOrGuardian
    function emergencyRedeem(
        bytes calldata swapCalldata,
        address swapRouter,
        address flashLoanRouter
    ) external;

    // --- Admin ---

    // Set maximum post-leverage LTV
    // ACCESS: onlyAdmin
    function setMaxLTV(uint256 newMaxLTV) external;

    // --- View (used by other contracts: MigrationRouter, Vault, specs) ---

    // Current lending position after _forceAccrue: (collateral in YBT, debt in baseToken)
    // Used by: MigrationRouter to compute flash loan amount, Vault for NAV
    function getPosition() external returns (uint256 collateral, uint256 debt);

    // Base token address
    function baseToken() external view returns (address);

    // YBT token address
    function ybtToken() external view returns (address);

    // Vault address
    function vault() external view returns (address);

    // Max LTV parameter
    function maxLTV() external view returns (uint256);
}
