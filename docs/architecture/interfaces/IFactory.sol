// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IFactory {
    // --- Deployment ---

    // Deploy a new Vault + Strategy pair as beacon proxies
    // Validates: oracle reachable, market valid, tolerance <= ceiling, token match
    // ACCESS: onlyAdmin
    function deploy(
        bytes32 protocolId,
        address baseToken,
        address ybtToken,
        address oracle,
        uint256 toleranceBps,
        uint256 maxLTV,
        uint256 minDeposit,
        uint256 minRedeem,
        bytes calldata lendingConfig
    ) external returns (address vault, address strategy);

    // --- Router registry ---

    // Register an approved FlashLoanRouter address
    // ACCESS: onlyAdmin
    function registerRouter(address router) external;

    // Remove a FlashLoanRouter from the approved set
    // ACCESS: onlyAdmin
    function deregisterRouter(address router) external;

    // Check if a FlashLoanRouter is registered (used by Strategy for per-call validation)
    function isRegisteredRouter(address router) external view returns (bool);

    // --- Configuration ---

    // Set MigrationRouter for new deployments
    // ACCESS: onlyAdmin
    function setMigrationRouter(address newMigrationRouter) external;

    // --- View ---

    // Current MigrationRouter address
    function migrationRouter() external view returns (address);

    // Tolerance ceiling constant (100 bps)
    function toleranceCeiling() external view returns (uint256);
}
