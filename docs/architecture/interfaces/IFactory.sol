// SPDX-License-Identifier: UNLICENSED
// GENERATED FROM: docs/architecture/ — do not edit, regenerate from q-tree
pragma solidity ^0.8.0;

interface IFactory {
    // --- Deployment ---

    // onlyAdmin
    // Deploy a new Vault + Strategy pair as beacon proxies
    // Validates: oracle reachable, lending market valid, tolerance <= ceiling, baseToken matches debt token
    function deploy(
        bytes32 protocolId,
        address baseToken,
        address ybtToken,
        address oracle,
        uint256 toleranceBps,
        uint256 maxLTV,
        uint256 minDepositAmount,
        uint256 minRedeemAmount
    ) external returns (address vault, address strategy);

    // --- Admin configuration ---

    // onlyAdmin
    // Register or update a Strategy beacon for a lending protocol
    function setStrategyBeacon(bytes32 protocolId, address beacon) external;

    // onlyAdmin
    // Set the Vault beacon
    function setVaultBeacon(address beacon) external;

    // onlyAdmin
    // Update MigrationRouter address (used for new deployments)
    function setMigrationRouter(address newRouter) external;

    // --- FlashLoanRouter registry ---

    // onlyAdmin
    // Add a FlashLoanRouter to the approved set
    function registerRouter(address router) external;

    // onlyAdmin
    // Remove a FlashLoanRouter from the approved set
    function deregisterRouter(address router) external;

    // Check if a FlashLoanRouter is approved
    function isRegisteredRouter(address router) external view returns (bool);

    // --- View ---

    // Current MigrationRouter address
    function migrationRouter() external view returns (address);

    // Vault beacon address
    function vaultBeacon() external view returns (address);

    // Strategy beacon for a given protocol
    function strategyBeacons(bytes32 protocolId) external view returns (address);

    // Check if a vault address was deployed by this factory
    function isRegistered(address vault) external view returns (bool);
}
