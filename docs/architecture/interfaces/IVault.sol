// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IVault {
    // --- User actions ---

    // Request async deposit of baseToken into the vault
    function requestDeposit(uint256 amount) external;

    // Cancel a pending (unprocessed) deposit request, returns baseToken to user
    function cancelDeposit(uint256 requestId) external;

    // Request async redeem; shares escrowed (transferred to vault) at request time
    function requestRedeem(uint256 shares) external;

    // Cancel a pending (unprocessed) redeem request, returns escrowed shares to user
    function cancelRedeem(uint256 requestId) external;

    // Sync permissionless redeem: user provides calldata, burns shares, unwinds proportional position
    // Always available even when paused; skip flash loan if position fully unwound (idle mode)
    // flashLoanRouter validated against Factory registry
    function syncRedeem(uint256 shares, bytes calldata swapCalldata, address swapRouter, address flashLoanRouter) external;

    // --- Keeper actions ---

    // onlyKeeper
    // Process deposit queue FIFO: leverage up to `amount` of baseToken, mint shares via delta NAV
    // flashLoanRouter validated against Factory registry
    function processDeposits(uint256 amount, bytes calldata swapCalldata, address swapRouter, address flashLoanRouter) external;

    // onlyKeeper
    // Process redeem queue FIFO: unwind up to `shares` worth of position, distribute baseToken pro-rata
    // flashLoanRouter validated against Factory registry
    function processRedeems(uint256 shares, bytes calldata swapCalldata, address swapRouter, address flashLoanRouter) external;

    // --- Migration actions (MigrationRouter only) ---

    // onlyMigrationRouter
    // Sync deposit for migration: supply collateral, borrow debtAmount, send debt to caller, mint shares via arithmetic NAV validation
    function depositCustom(address user, uint256 collateralAmount, uint256 debtAmount) external;

    // onlyMigrationRouter
    // Sync redeem for migration: caller transfers baseToken to Strategy first, then burns shares, repays proportional debt, withdraws proportional collateral to caller
    // Reverts if user has pending redeem requests
    function redeemCustom(address user, uint256 shares) external;

    // --- Admin actions ---

    // onlyAdmin
    // Pause deposits, new requests, and migrations; sync redeem + keeper remain active
    function pause() external;

    // onlyAdmin
    // Unpause vault
    function unpause() external;

    // onlyAdmin
    // Set swap tolerance in basis points (ceiling enforced: <= 100 bps)
    function setTolerance(uint256 newToleranceBps) external;

    // onlyAdmin
    // Set minimum deposit amount
    function setMinDepositAmount(uint256 newMin) external;

    // onlyAdmin
    // Set minimum redeem amount (in shares)
    function setMinRedeemAmount(uint256 newMin) external;

    // onlyAdmin
    // Update MigrationRouter address for this vault
    function setMigrationRouter(address newRouter) external;

    // onlyAdmin
    // Set guardian address (can pause)
    function setGuardian(address newGuardian) external;

    // onlyAdmin
    // Set keeper address (processes epochs)
    function setKeeper(address newKeeper) external;

    // --- Guardian actions ---

    // onlyGuardianOrAdmin
    // Pause vault (guardian can pause but not unpause per standard pattern)
    function guardianPause() external;

    // --- View ---

    // Total NAV: oracleValue(actualCollateral) - actualDebt (after _forceAccrue)
    function totalAssets() external view returns (uint256);

    // Total shares outstanding
    function totalSupply() external view returns (uint256);

    // Share balance of an account
    function balanceOf(address account) external view returns (uint256);

    // Strategy address paired with this vault
    function strategy() external view returns (address);

    // Factory address (for FlashLoanRouter registry validation)
    function factory() external view returns (address);

    // Current oracle address
    function oracle() external view returns (address);

    // Current tolerance in basis points
    function toleranceBps() external view returns (uint256);

    // Whether the vault is paused
    function paused() external view returns (bool);

    // Current MigrationRouter address
    function migrationRouter() external view returns (address);

    // Guardian address
    function guardian() external view returns (address);

    // Keeper address
    function keeper() external view returns (address);

    // Minimum deposit amount
    function minDepositAmount() external view returns (uint256);

    // Minimum redeem amount in shares
    function minRedeemAmount() external view returns (uint256);
}
