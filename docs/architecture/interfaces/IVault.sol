// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IVault {
    // --- User actions ---

    // Request async deposit of baseToken; returns requestId for cancellation
    // ACCESS: anyone (whenNotPaused)
    function requestDeposit(uint256 amount) external returns (uint256 requestId);

    // Cancel a pending unprocessed deposit request; refunds baseToken to caller
    // ACCESS: request owner only
    function cancelDeposit(uint256 requestId) external;

    // Request async redeem; shares escrowed to vault; returns requestId for cancellation
    // ACCESS: anyone (whenNotPaused)
    function requestRedeem(uint256 shares) external returns (uint256 requestId);

    // Cancel a pending unprocessed redeem request; returns escrowed shares to caller
    // ACCESS: request owner only
    function cancelRedeem(uint256 requestId) external;

    // Sync permissionless redeem: user provides calldata, burns shares, receives baseToken
    // Always available even when paused
    // ACCESS: anyone
    function syncRedeem(
        uint256 shares,
        bytes calldata swapCalldata,
        address swapRouter,
        address flashLoanRouter
    ) external returns (uint256 baseTokenOut);

    // --- Keeper actions ---

    // Process pending deposit requests FIFO; keeper provides swap calldata and amount to deploy
    // ACCESS: onlyKeeper
    function processDeposits(
        uint256 amount,
        bytes calldata swapCalldata,
        address swapRouter,
        address flashLoanRouter
    ) external;

    // Process pending redeem requests FIFO; keeper provides swap calldata and shares to unwind
    // ACCESS: onlyKeeper
    function processRedeems(
        uint256 shares,
        bytes calldata swapCalldata,
        address swapRouter,
        address flashLoanRouter
    ) external;

    // --- Migration actions (MigrationRouter only) ---

    // Accept collateral from migration, supply + borrow, mint shares to user
    // ACCESS: onlyMigrationRouter
    function depositCustom(
        address user,
        uint256 collateralAmount,
        uint256 debtAmount
    ) external returns (uint256 sharesMinted);

    // Burn user shares, repay debt + withdraw collateral to MigrationRouter
    // Vault computes fraction = shares/totalSupply, passes to Strategy
    // Precondition: MigrationRouter has transferred baseToken to Strategy before this call
    // ACCESS: onlyMigrationRouter
    function redeemCustom(
        address user,
        uint256 shares
    ) external returns (uint256 collateralOut);

    // --- Admin actions ---

    // Pause deposits, async redeems, and migrations (sync redeem unaffected)
    // ACCESS: onlyGuardianOrAdmin
    function pause() external;

    // Unpause the vault
    // ACCESS: onlyAdmin
    function unpause() external;

    // Set swap tolerance in basis points (max toleranceCeiling)
    // ACCESS: onlyAdmin
    function setTolerance(uint256 newToleranceBps) external;

    // Set minimum deposit amount
    // ACCESS: onlyAdmin
    function setMinDeposit(uint256 newMinDeposit) external;

    // Set minimum redeem shares
    // ACCESS: onlyAdmin
    function setMinRedeem(uint256 newMinRedeem) external;

    // Set MigrationRouter address
    // ACCESS: onlyAdmin
    function setMigrationRouter(address newMigrationRouter) external;

    // Set guardian address
    // ACCESS: onlyAdmin
    function setGuardian(address newGuardian) external;

    // Set keeper address
    // ACCESS: onlyAdmin
    function setKeeper(address newKeeper) external;

    // --- View (used by other contracts or specs) ---

    // Total NAV: oracleValue(actualCollateral) - actualDebt + idleBaseToken
    // Used by: delta NAV calculation in processDeposits/depositCustom, specs
    function totalAssets() external view returns (uint256);

    // ERC-20 totalSupply of shares
    function totalSupply() external view returns (uint256);

    // ERC-20 share balance of account
    function balanceOf(address account) external view returns (uint256);

    // Whether vault is paused
    function paused() external view returns (bool);

    // Strategy address
    function strategy() external view returns (address);

    // Factory address
    function factory() external view returns (address);
}
