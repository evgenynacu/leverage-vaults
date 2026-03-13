# Interfaces

## Vault

```solidity
// --- User actions ---
function requestDeposit(uint256 amount) external
function cancelDeposit(uint256 requestId) external
function cancelRedeem(uint256 requestId) external
function requestRedeem(uint256 shares) external
function syncRedeem(uint256 shares, bytes calldata swapCalldata, address swapRouter) external
function reclaimDeposit(uint256 requestId) external
function reclaimRedeem(uint256 requestId) external

// --- Keeper actions ---
function processDeposits(uint256 count, bytes calldata leverageCalldata, address swapRouter) external onlyKeeper
function processRedeems(uint256 count, bytes calldata unwindCalldata, address swapRouter) external onlyKeeper

// --- Migration (MigrationRouter only) ---
function depositCustom(address user, uint256 collateralAmount, uint256 debtAmount) external onlyMigrationRouter
function redeemCustom(address user, uint256 shares) external onlyMigrationRouter

// --- Admin actions ---
function pause() external onlyAdminOrGuardian
function unpause() external onlyAdmin
function setTolerance(uint256 newToleranceBps) external onlyAdmin
function setMigrationRouter(address newRouter) external onlyAdmin
function setMinDepositAmount(uint256 amount) external onlyAdmin
function setMinRedeemAmount(uint256 amount) external onlyAdmin
function setGuardian(address newGuardian) external onlyAdmin
function setKeeper(address newKeeper) external onlyAdmin

// --- View ---
function totalAssets() external view returns (uint256)
function nav() external view returns (uint256)
function pendingDeposit(address user) external view returns (uint256)
function pendingRedeem(address user) external view returns (uint256)
```

### Parameter sufficiency notes

- **requestDeposit(amount)**: amount + msg.sender sufficient. Vault knows baseToken, does transferFrom, creates FIFO request with (msg.sender, amount, block.timestamp).
- **cancelDeposit(requestId)**: requestId identifies the specific request in FIFO queue. Vault checks msg.sender == request.owner and request not yet processed. Returns baseToken.
- **cancelRedeem(requestId)**: requestId identifies the request. Returns escrowed shares to msg.sender.
- **requestRedeem(shares)**: shares + msg.sender sufficient. Vault escrows shares (transfer to self), creates FIFO request with (msg.sender, shares, block.timestamp).
- **syncRedeem(shares, swapCalldata, swapRouter)**: shares (from msg.sender wallet) + swap calldata/router sufficient. Vault computes fraction = shares * 1e18 / totalSupply, calls _forceAccrue() then passes fraction + calldata to Strategy.redeem(). In idle mode (zero position), calldata/router ignored, pro-rata of idle base returned.
- **reclaimDeposit(requestId)**: requestId sufficient. Vault checks block.timestamp > request.timestamp + requestTimeout, marks request as reclaimed (keeper skips), returns baseToken.
- **reclaimRedeem(requestId)**: requestId sufficient. Same timeout check, returns escrowed shares.
- **processDeposits(count, leverageCalldata, swapRouter)**: count = number of requests from FIFO head (including partial fills). Vault sums amounts, calls _forceAccrue, measures delta NAV, passes totalAmount to Strategy.deposit(). Mints shares proportionally per request.
- **processRedeems(count, unwindCalldata, swapRouter)**: count = number of requests from FIFO head. Vault sums escrowed shares, computes fraction = totalShares * 1e18 / totalSupply, passes fraction to Strategy.redeem(). Burns shares, distributes base pro-rata.
- **depositCustom(user, collateralAmount, debtAmount)**: user = share recipient. collateralAmount = YBT to supply (already transferred by MigrationRouter to Strategy). debtAmount = MigrationRouter knows flash loan size, passes explicitly. Vault calls Strategy.depositCustom(collateralAmount, debtAmount). Arithmetic NAV validation: expectedDelta = oracleValue(collateralAmount) - debtAmount. Mints shares via delta NAV.
- **redeemCustom(user, shares)**: user = share owner. shares = amount to burn. Vault computes fraction = shares * 1e18 / totalSupply, passes fraction to Strategy.redeemCustom(fraction). Strategy uses baseToken already transferred by MigrationRouter to repay proportional debt, withdraws proportional collateral (YBT), sends YBT to MigrationRouter. Vault burns user's shares. No debtAmount needed — Strategy reads actual position.

## Strategy (abstract)

```solidity
// --- Called by Vault (epoch flows) ---
function deposit(uint256 baseAmount, bytes calldata swapCalldata, address swapRouter) external onlyVault
function redeem(uint256 fraction, bytes calldata swapCalldata, address swapRouter) external onlyVault returns (uint256 baseReturned)

// --- Called by Vault (migration flows) ---
function depositCustom(uint256 collateralAmount, uint256 debtAmount) external onlyVault returns (uint256 debtSent)
function redeemCustom(uint256 fraction) external onlyVault returns (uint256 collateralWithdrawn, uint256 debtRepaid)

// --- Called directly by keeper or guardian (emergency) ---
function emergencyRedeem(bytes calldata unwindCalldata, address swapRouter) external onlyKeeperOrGuardian

// --- Admin ---
function setFlashLoanRouter(address newRouter) external onlyAdmin
function setMaxLTV(uint256 newMaxLTV) external onlyAdmin

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

- **deposit(baseAmount, swapCalldata, swapRouter)**: baseAmount (total pending from vault idle) + swap calldata/router sufficient. Strategy knows its own flashLoanRouter, baseToken, ybtToken. Internally: executeFlashLoan -> onFlashLoan callback -> swap -> supply -> borrow -> repay flash loan. Oracle-floor check uses vault's oracle. Post-leverage LTV checked against maxLTV — reverts if exceeded.
- **redeem(fraction, swapCalldata, swapRouter)**: fraction (1e18-scaled portion of position to unwind) + swap calldata/router sufficient. Strategy calls _forceAccrue, reads actual position, computes proRataDebt = fraction * actualDebt / 1e18 (same for collateral). Returns baseToken amount to Vault.
- **depositCustom(collateralAmount, debtAmount)**: collateralAmount (YBT to supply) + debtAmount (explicit from MigrationRouter via Vault). Strategy supplies collateral, borrows debtAmount, sends baseToken to Vault (which sends to MigrationRouter). Post-leverage LTV checked against maxLTV. Returns amount sent.
- **redeemCustom(fraction)**: fraction (1e18-scaled). Strategy calls _forceAccrue, reads actual position, applies fraction to compute pro-rata debt/collateral. Uses baseToken already transferred by MigrationRouter to repay proRataDebt, withdraws proRataCollateral (YBT), sends YBT to MigrationRouter. Returns (collateralWithdrawn, debtRepaid). **Note:** Vault computes fraction from (user, shares) and passes only fraction to Strategy — Strategy does not need to know shares or totalSupply.
- **emergencyRedeem(unwindCalldata, swapRouter)**: calldata/router sufficient. Called directly by keeper or guardian on Strategy (not through Vault). Internally uses fraction = 1e18 (full position). Strategy calls _forceAccrue, reads position, unwinds everything. Remaining baseToken sent to Vault as idle balance. NAV automatically reflects unwound position.
- **setMaxLTV(newMaxLTV)**: newMaxLTV sufficient. Admin-settable per-vault parameter stored on Strategy.
- **onFlashLoan(token, amount, fee, data)**: called by FlashLoanRouter after provider callback. token, amount, fee from provider (fee always 0 for zero-fee providers). data contains encoded swap calldata and operation context. Sufficient.
- **getPosition()**: calls _forceAccrue() internally, then reads actual position from lending protocol. NOT a view function (forces accrual). Returns (actualCollateral, actualDebt).

## FlashLoanRouter

```solidity
// --- Called by anyone (open access) ---
function executeFlashLoan(address token, uint256 amount, bytes calldata data) external

// --- Called by flash loan provider (signature varies per provider — implementation detail) ---
function onFlashLoanCallback(address token, uint256 amount, uint256 fee, bytes calldata data) external

// --- View ---
function provider() external view returns (address)
```

### Parameter sufficiency notes

- **executeFlashLoan(token, amount, data)**: token + amount + data sufficient. Open access — anyone can call. FlashLoanRouter stores msg.sender as initiator in transient storage, sets active flag, calls provider-specific flash loan function. data forwarded through provider callback back to initiator.onFlashLoan(). Zero fee enforced. Security relies on transient storage callback validation, not caller restriction.
- **onFlashLoanCallback(token, amount, fee, data)**: called by provider. Per-provider callback signatures are implementation detail (Aave executeOperation, Balancer receiveFlashLoan, Morpho onMorphoFlashLoan). FlashLoanRouter validates active flag in transient storage, resolves initiator from transient storage, calls initiator.onFlashLoan(token, amount, fee, data). After initiator returns, FlashLoanRouter handles repayment to provider (token + amount, fee = 0).

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

- **migrate(sourceVault, destinationVault, shares, flashLoanRouter, ybtConversionCalldata, conversionRouter)**: sourceVault + destinationVault (knows both vaults to call redeemCustom/depositCustom). shares (how many to migrate). flashLoanRouter (which provider to use). ybtConversionCalldata + conversionRouter (for YBT-A -> YBT-B swap; empty if same YBT). MigrationRouter computes flashAmount = shares * actualDebt / totalSupply by calling sourceVault.strategy().getPosition() (which calls _forceAccrue internally) and sourceVault.totalSupply(). This flashAmount becomes debtAmount passed to destinationVault.depositCustom(). User must be owner or approved for shares in source vault. Sufficient.
- **onFlashLoan(token, amount, fee, data)**: called by FlashLoanRouter during migration flash loan. MigrationRouter is the initiator. Inside callback: transfers baseToken to source Strategy, calls sourceVault.redeemCustom(user, shares) to burn shares and get YBT collateral back, optionally swaps YBT, transfers YBT to destination Strategy, calls destinationVault.depositCustom(user, collateralAmount, debtAmount=flashAmount) to supply + borrow, receives baseToken back to repay flash loan. data contains encoded parameters (user, sourceVault, destinationVault, shares, conversion params). Sufficient.

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
    uint256 minRedeemAmount,
    uint256 maxLTV
) external onlyAdmin returns (address vault, address strategy)

function setMigrationRouter(address newRouter) external onlyAdmin
function registerFlashLoanRouter(address router) external onlyAdmin

// --- View ---
function getVault(address strategy) external view returns (address)
function isRegistered(address vault) external view returns (bool)
```

### Parameter sufficiency notes

- **deploy(...)**: all configuration provided as parameters, including maxLTV for Strategy. Factory has vaultBeacon and migrationRouter in its own state. Creates beacon proxies, links vault<->strategy, sets migrationRouter on vault, sets maxLTV on strategy, runs on-chain validation (oracle reachable, market valid, tolerance <= ceiling, baseToken matches market debt token), registers pair.
- **setMigrationRouter(newRouter)**: newRouter sufficient. Updates Factory state for future deployments.
- **registerFlashLoanRouter(router)**: router address sufficient. Adds to Factory's known routers.
