# Interfaces

## Vault

```solidity
// --- User actions ---
function requestDeposit(uint256 amount) external
function cancelDeposit() external
function requestWithdrawal(uint256 shares) external
function syncRedeem(uint256 shares, bytes calldata swapCalldata, address swapRouter) external
function reclaimDeposit() external  // after keeper timeout

// --- Keeper actions ---
function processDepositEpoch(bytes calldata leverageCalldata, address swapRouter) external onlyKeeper
function processWithdrawalEpoch(bytes calldata unwindCalldata, address swapRouter) external onlyKeeper

// --- Migration (MigrationRouter only) ---
function depositCustom(address user, uint256 collateralAmount, uint256 debtAmount) external onlyMigrationRouter
function withdrawCustom(address user, uint256 shares) external onlyMigrationRouter

// --- Admin actions ---
function pause() external onlyAdminOrGuardian
function unpause() external onlyAdmin
function setTolerance(uint256 newToleranceBps) external onlyAdmin
function setMigrationRouter(address newRouter) external onlyAdmin
function setMinDepositAmount(uint256 amount) external onlyAdmin
function setMinWithdrawalAmount(uint256 amount) external onlyAdmin
function setGuardian(address newGuardian) external onlyAdmin
function setKeeper(address newKeeper) external onlyAdmin

// --- Guardian actions ---
function forceUnwind(bytes calldata unwindCalldata, address swapRouter) external onlyGuardian

// --- View ---
function totalAssets() external view returns (uint256)
function nav() external view returns (uint256)
function pendingDeposit(address user) external view returns (uint256)
function pendingWithdrawal(address user) external view returns (uint256)
```

### Parameter sufficiency notes

- **requestDeposit**: amount + msg.sender sufficient. Vault knows baseToken, does transferFrom, records in depositQueue[msg.sender][currentEpoch].
- **cancelDeposit**: msg.sender + stored depositQueue state sufficient. Vault knows the pending amount from queue.
- **requestWithdrawal**: shares + msg.sender sufficient. Vault escrows shares (transfer to self), records in withdrawalQueue.
- **syncRedeem**: shares (from msg.sender wallet) + swap calldata/router sufficient. Vault calls Strategy._forceAccrue() then reads actual position via getPosition() for pro-rata. In idle mode (zero position), calldata/router ignored.
- **processDepositEpoch**: leverageCalldata + swapRouter sufficient. Vault knows total pending from queue, calls _forceAccrue, measures delta NAV, passes to Strategy.leverage().
- **processWithdrawalEpoch**: unwindCalldata + swapRouter sufficient. Vault knows total escrowed shares from queue, calls _forceAccrue, passes to Strategy.unwind().
- **depositCustom**: user (share recipient), collateralAmount (YBT to supply, already transferred by MigrationRouter to Strategy), debtAmount (MigrationRouter knows flash loan size). Strategy supplies collateral, borrows debtAmount, sends baseToken back to msg.sender (MigrationRouter). Vault computes delta NAV and mints shares.
- **withdrawCustom**: user (share owner), shares (amount to burn). Strategy computes pro-rata from shares/totalSupply * actualDebt and actualCollateral (read from protocol after _forceAccrue). Returns YBT collateral to msg.sender (MigrationRouter). No debtAmount param needed -- derived from actual position.
- **forceUnwind**: calldata + router sufficient. Strategy reads actual position from protocol after _forceAccrue for full unwind.
- **reclaimDeposit**: msg.sender sufficient. Vault checks timeout against epoch timestamp, returns stored pending amount.

## Strategy (abstract)

```solidity
// --- Called by Vault ---
function leverage(uint256 baseAmount, bytes calldata swapCalldata, address swapRouter) external onlyVault
function unwind(uint256 shares, uint256 totalSupply, bytes calldata swapCalldata, address swapRouter) external onlyVault returns (uint256 baseReturned)
function supplyAndBorrow(uint256 collateralAmount, uint256 debtAmount) external onlyVault returns (uint256 debtSent)
function repayAndWithdraw(uint256 shares, uint256 totalSupply) external onlyVault returns (uint256 collateralWithdrawn, uint256 debtRepaid)

// --- Keeper/Guardian ---
function emergencyUnwind(bytes calldata unwindCalldata, address swapRouter) external onlyKeeperOrGuardian

// --- Admin ---
function setFlashLoanRouter(address newRouter) external onlyAdmin

// --- Internal (implemented by subclasses) ---
function _supply(uint256 amount) internal virtual
function _borrow(uint256 amount) internal virtual
function _repay(uint256 amount) internal virtual
function _withdraw(uint256 amount) internal virtual
function _forceAccrue() internal virtual
function _getPosition() internal virtual returns (uint256 collateral, uint256 debt)

// --- Flash loan callback ---
function onFlashLoan(address token, uint256 amount, uint256 fee, bytes calldata data) external onlyFlashLoanRouter

// --- View ---
function getPosition() external returns (uint256 collateral, uint256 debt)
```

### Parameter sufficiency notes

- **leverage**: baseAmount (total pending from vault idle) + swap calldata/router sufficient. Strategy knows its own flashLoanRouter, baseToken, ybtToken. Internally: executeFlashLoan -> onFlashLoan callback -> swap -> supply -> borrow -> repay flash loan.
- **unwind**: shares + totalSupply sufficient to compute pro-rata (shares/totalSupply * actualDebt, shares/totalSupply * actualCollateral, read from protocol after _forceAccrue). calldata/router for YBT->baseToken swap. Returns baseToken amount to Vault.
- **supplyAndBorrow**: collateralAmount (YBT to supply, already transferred by MigrationRouter to Strategy) + debtAmount (explicit from MigrationRouter via Vault). Strategy supplies collateral, borrows debtAmount, sends baseToken to Vault (which sends to MigrationRouter). Returns amount sent.
- **repayAndWithdraw**: shares + totalSupply sufficient. Strategy reads actual position from protocol after _forceAccrue and computes pro-rata debt/collateral. BaseToken for repayment comes from MigrationRouter (via flash loan, held by Strategy). Returns collateral (YBT) to Vault (which sends to MigrationRouter).
- **emergencyUnwind**: calldata/router sufficient. Strategy reads actual position from protocol after _forceAccrue for full unwind.
- **onFlashLoan**: called by FlashLoanRouter after provider callback. token, amount, fee from provider. data contains encoded swap calldata and operation context. Strategy knows what operation is in progress from its own transient/memory state.
- **getPosition**: calls _forceAccrue() internally, then reads actual position from lending protocol. NOT a view function (forces accrual). Returns (actualCollateral, actualDebt).

## FlashLoanRouter

```solidity
// --- Called by Strategy or MigrationRouter ---
function executeFlashLoan(address token, uint256 amount, bytes calldata data) external

// --- Called by flash loan provider ---
function onFlashLoanCallback(address token, uint256 amount, uint256 fee, bytes calldata data) external

// --- View ---
function provider() external view returns (address)
```

### Parameter sufficiency notes

- **executeFlashLoan**: token + amount + data sufficient. FlashLoanRouter stores msg.sender as initiator in transient storage, sets active flag, calls provider-specific flash loan function. data forwarded through provider callback back to initiator.onFlashLoan().
- **onFlashLoanCallback**: called by provider. FlashLoanRouter validates active flag in transient storage, resolves initiator from transient storage, calls initiator.onFlashLoan(token, amount, fee, data). After initiator returns, FlashLoanRouter handles repayment to provider (token + amount + fee).

## MigrationRouter

```solidity
// --- User actions ---
function migrate(
    address sourceVault,
    address destinationVault,
    uint256 shares,
    address flashLoanRouter,
    bytes calldata ybtConversionCalldata,
    address conversionRouter
) external

// --- Flash loan callback ---
function onFlashLoan(address token, uint256 amount, uint256 fee, bytes calldata data) external
```

### Parameter sufficiency notes

- **migrate**: sourceVault + destinationVault (knows both vaults to call withdrawCustom/depositCustom). shares (how many to migrate). flashLoanRouter (which provider to use). ybtConversionCalldata + conversionRouter (for YBT-A -> YBT-B swap; empty if same YBT). MigrationRouter computes flashAmount = shares/totalSupply * actualDebt by calling sourceVault.strategy().getPosition() (which calls _forceAccrue internally) and sourceVault.totalSupply(). User must be owner or approved for shares in source vault.
- **onFlashLoan**: called by FlashLoanRouter during migration flash loan. MigrationRouter is the initiator. Inside callback: calls sourceVault.withdrawCustom(user, shares) to get YBT + burn shares, optionally swaps YBT, calls destinationVault.depositCustom(user, collateralAmount, debtAmount) to supply + borrow, receives baseToken back to repay flash loan. data contains encoded parameters (user, sourceVault, destinationVault, shares, conversion params).

## Factory

```solidity
// --- Admin actions ---
function deploy(
    address strategyBeacon,
    address baseToken,
    address ybtToken,
    address lendingMarket,
    address oracle,
    uint256 toleranceBps,
    uint256 minDepositAmount,
    uint256 minWithdrawalAmount
) external onlyAdmin returns (address vault, address strategy)

function setMigrationRouter(address newRouter) external onlyAdmin
function registerFlashLoanRouter(address router) external onlyAdmin

// --- View ---
function getVault(address strategy) external view returns (address)
function isRegistered(address vault) external view returns (bool)
```

### Parameter sufficiency notes

- **deploy**: all configuration provided as parameters. Factory has vaultBeacon and migrationRouter in its own state. Creates beacon proxies, links vault<->strategy, sets migrationRouter on vault, runs on-chain validation (oracle reachable, market valid, tolerance <= ceiling, baseToken matches market debt token), registers pair.
- **setMigrationRouter**: newRouter sufficient. Updates Factory state for future deployments.
- **registerFlashLoanRouter**: router address sufficient. Adds to Factory's known routers.
