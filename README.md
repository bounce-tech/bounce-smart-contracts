# Bounce Contracts

## Overview

Bounce is the first Leveraged Token product on HyperEVM, powered by Hyperliquid Perpetual Futures. At its core, Bounce is a modular, composable DeFi protocol that enables users to mint and redeem leveraged tokens that track the performance of underlying assets with leverage. The leveraged tokens are ERC20 tokens, allowing them to be freely traded, and used in other protocols in DeFi.

## Protocol Architecture

- **GlobalStorage**: The central registry and configuration hub for the protocol. It stores addresses of all major modules and key parameters (fees, minimums, etc.).
- **LeveragedToken**: ERC20 tokens representing leveraged positions on underlying assets. Minting and redemption are handled via this contract, with all accounting and fee logic.
- **Factory**: Deploys new leveraged tokens via proxies, allowing for upgradability and modularity.
- **Referrals**: Manages the referral system, allowing users to register codes, join with referrals, and claim rebates.
- **HyperliquidHandler**: Provides on-chain read access to off-chain or precompiled data (e.g., market prices, positions) for leveraged token valuation.
- **Ownable**: Minimal ownable pattern for access control.
- **Utilities/Constants**: Math helpers (`ScaledNumber`), config values, and address constants.

## Off Chain Automation Layer

While it is out of scope of the Solidity side of the protocol, it's probably useful to note how the off chain automation layer works and integrates with the Smart contracts. The automation side is responsible for two main functions:

- Moving funds between the Leveraged Tokens and the HyperCore (i.e. processing deposits and redemptions)
- Rebalancing the leveraged tokens to maintain their target leverage

The rebalancing doesn't have any touch points with the smart contracts, other than querying the `targetLeverage`. However the moving of funds has some overlap. Because the funds will be deposited in HyperLiquid, there won't be idle funds to redeem by default. Users first call `prepareRedeem`. Which the automation scripts then pick up on and send funds back to the smart contract, which can then be redeemed with `executeRedemptions`. Similarly, the automation scripts listen out for mint events, and then call `bridgeToPerp` or `bridgeFromPerp` to handle this for processing.


## Redeem Flow

We will keep a percent of assets idle in the smart contract to allow for atomic redemptions for smaller amounts. If the user is redeeming an amount less than the idle assets, they can use the atomic `redeem` flow. Otherwise they will use the two step flow `prepareRedeem` and `executeRedemptions`. Where the automation layer will move funds across based on these events to free up capital for redemption.

## Contract Breakdown

Anything in `helpers` is considered out of the scope of the core protocol

### GlobalStorage

- **Purpose**: Central registry for all protocol modules and configuration parameters.
- **Integration**: All modules reference `GlobalStorage` for addresses and settings. Owner can update module addresses and parameters.
- **Key Functions**:
  - `setLtImplementation`, `setBaseAsset`, etc.: Update module addresses.
  - `setMinTransactionSize`, `setRedemptionFee`, etc.: Update protocol parameters.

### LeveragedToken

- **Purpose**: ERC20 token representing a leveraged position on an underlying asset.
- **Integration**: Minted via `Factory`, interacts with `HyperliquidHandler` for price/position data.
- **Key Functions**:
  - `mint`, `redeem`, `prepareRedeem`, `executeRedemptions`: Mint/redeem leveraged tokens, handling all accounting and fees.
  - `exchangeRate`, `totalAssets`, `baseToLtAmount`, `ltToBaseAmount`: Core math for token valuation.
  - `hyperliquidNotional`: Returns the notional value of the leveraged token's underlying position on Hyperliquid, scoped to its `perpDexIndex` (HIP-3 aware).
  - `perpDexIndex`: The Hyperliquid perp dex index this leveraged token routes to (0 for the validator-operated dex, non-zero for HIP-3 dexes).
  - `_checkpoint`: Accrues streaming fees over time.

### Factory

- **Purpose**: Deploys new leveraged tokens as upgradeable proxies.
- **Integration**: Only owner can deploy; uses `LeveragedTokenProxy` and initializes new tokens with market data from `HyperliquidHandler`.
- **Key Functions**:
  - `createLt`: Deploys a new leveraged token contract.
  - `redeployLt`: Redeploys an existing leveraged token (e.g. to upgrade its proxy/implementation).
  - `deleteLt`: Removes a leveraged token from the factory's registry (only when it has no remaining margin).
  - `importFromFactory`: Imports the set of leveraged tokens from a previous `Factory` deployment, used for migrations.
  - `lts`: Returns all deployed leveraged token addresses.

### LeveragedTokenProxy

- **Purpose**: Minimal proxy for upgradeable leveraged tokens.
- **Integration**: Points to implementation address in `GlobalStorage`.
- **Key Functions**:
  - `_implementation`: Returns current implementation address.

### Referrals

- **Purpose**: Referral system for user growth and fee rebates.
- **Integration**: Used by `LeveragedToken` for fee rebates. Users register codes, join with referrals, and claim rebates.
- **Key Functions**:
  - `addReferrer`, `removeReferrer`: Owner manages referrers and codes.
  - `joinWithReferral`: User joins with a referral code.
  - `donateRebates`, `claimRebates`: Handle and claim fee rebates.

### HyperliquidHandler

- **Purpose**: On-chain interface to off-chain/precompiled data (e.g., market prices, positions, asset info).
- **Integration**: Used by `LeveragedToken` and `Factory` for real-time market data.
- **Key Functions**:
  - `spotUsdc`: Returns the value that the user holds in spot USDC in Hyperliquid in USDC denomination
  - `perpUsdc(user, perpDexIndex)`: Returns the amount of value in the user's Hyperliquid perp position on the given perp dex (HIP-3 aware) in USDC denomination
  - `notionalUsdc(user, perpDexIndex)`: Returns the notional value of the user's positions on the given perp dex in USDC denomination
  - `coreUserExists`: Checks if a user exists on HyperCore
  - Legacy helpers `hyperliquidUsdc`, `perpUsdc(user)`, `marginUsedUsdc`, and `notionalUsdc(user)` are retained for backwards compatibility but are deprecated; they hardcode the validator-operated perp dex (index 0) and should not be used for HIP-3 markets. Prefer composing `spotUsdc` with the `perpDexIndex_`-aware overloads above.

### Ownable

- **Purpose**: Minimal ownable pattern for access control.
- **Integration**: Used by all major modules for admin functions.

### Utilities & Constants

- **ScaledNumber**: Math helpers for scaling and precision math.
