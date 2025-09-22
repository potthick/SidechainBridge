# SidechainBridge

A decentralized cross-chain AMM liquidity pool connecting Bitcoin sidechains with the Stacks blockchain. SidechainBridge enables seamless asset transfers and automated market maker functionality between different blockchain networks.

## Overview

SidechainBridge is a comprehensive smart contract system built on Stacks that provides:
- Cross-chain asset bridging between Bitcoin sidechains and Stacks
- Automated Market Maker (AMM) functionality with liquidity pools
- Decentralized liquidity provision and trading
- Secure cross-chain proof verification

## Features

- **Cross-Chain Bridging**: Transfer assets between Bitcoin sidechains and Stacks with cryptographic proof verification
- **AMM Liquidity Pools**: Create and manage liquidity pools with constant product formula
- **Liquidity Provision**: Add and remove liquidity to earn trading fees
- **Token Swapping**: Execute trades with automatic slippage protection
- **Multi-Sidechain Support**: Support for multiple Bitcoin sidechains with configurable parameters
- **Admin Controls**: Pausable bridge functionality and sidechain management
- **Fee Collection**: Built-in 0.3% trading fee mechanism

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Contract Version**: 1.0.0
- **Clarity Version**: 2
- **Epoch**: 2.5
- **Trading Fee**: 0.3% (30 basis points)
- **Minimum Liquidity**: 1,000 units

### Supported Operations

1. **Pool Management**
   - Create new liquidity pools
   - Add/remove liquidity
   - Query pool information

2. **Trading**
   - Token swaps with slippage protection
   - Automatic price discovery via constant product formula

3. **Cross-Chain Operations**
   - Initiate bridge transfers
   - Complete transfers with proof verification
   - Track transaction status

4. **Administration**
   - Add/remove supported sidechains
   - Pause/unpause bridge operations
   - Configure sidechain parameters

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks smart contract development tool
- [Node.js](https://nodejs.org/) v16 or higher
- [Git](https://git-scm.com/)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd SidechainBridge
```

2. Install dependencies:
```bash
cd SidechainBridge_contract
npm install
```

3. Verify installation:
```bash
clarinet check
```

## Usage Examples

### Creating a Liquidity Pool

```clarity
;; Create a new pool for token-a and token-b
(contract-call? .SidechainBridge create-pool
    'SP1234...TOKEN-A
    'SP5678...TOKEN-B
    u1000000  ;; 1,000,000 units of token-a
    u2000000  ;; 2,000,000 units of token-b
)
```

### Adding Liquidity

```clarity
;; Add liquidity to pool ID 1
(contract-call? .SidechainBridge add-liquidity
    u1         ;; pool-id
    u100000    ;; amount-a to add
    u200000    ;; amount-b to add
    u90000     ;; minimum liquidity tokens expected
)
```

### Token Swap

```clarity
;; Swap 10,000 units of token-a for token-b in pool 1
(contract-call? .SidechainBridge swap
    u1                      ;; pool-id
    'SP1234...TOKEN-A       ;; token to swap
    u10000                  ;; amount to swap
    u19500                  ;; minimum amount out (accounting for slippage)
)
```

### Cross-Chain Bridge Transfer

```clarity
;; Initiate transfer to sidechain ID 1
(contract-call? .SidechainBridge bridge-transfer
    u1                      ;; to-chain (sidechain ID)
    'SP9876...RECIPIENT     ;; recipient address
    u50000                  ;; amount to bridge
    'SP1234...TOKEN         ;; token to bridge
)
```

## Contract Functions Documentation

### Public Functions

#### Pool Management

- `create-pool(token-a, token-b, initial-a, initial-b)` - Creates a new liquidity pool
- `add-liquidity(pool-id, amount-a, amount-b, min-liquidity)` - Adds liquidity to existing pool
- `remove-liquidity(pool-id, liquidity, min-amount-a, min-amount-b)` - Removes liquidity from pool

#### Trading

- `swap(pool-id, token-in, amount-in, min-amount-out)` - Executes token swap with slippage protection

#### Cross-Chain Operations

- `bridge-transfer(to-chain, recipient, amount, token)` - Initiates cross-chain transfer
- `complete-bridge-transfer(tx-id, proof)` - Completes transfer with proof verification

#### Administration

- `add-sidechain(sidechain-id, name, min-confirmations)` - Adds supported sidechain (owner only)
- `set-bridge-paused(paused)` - Pauses/unpauses bridge operations (owner only)

### Read-Only Functions

- `get-pool(pool-id)` - Returns pool information
- `get-liquidity-position(pool-id, user)` - Returns user's LP token balance
- `get-amount-out(amount-in, reserve-in, reserve-out)` - Calculates swap output amount
- `get-bridge-transaction(tx-id)` - Returns bridge transaction details
- `get-sidechain(sidechain-id)` - Returns sidechain information
- `is-bridge-paused()` - Returns bridge pause status
- `get-total-pools()` - Returns total number of pools

### Error Codes

- `ERR_UNAUTHORIZED` (100) - Caller not authorized for operation
- `ERR_INSUFFICIENT_BALANCE` (101) - Insufficient token balance
- `ERR_INVALID_AMOUNT` (102) - Invalid amount provided
- `ERR_POOL_NOT_EXISTS` (103) - Pool does not exist
- `ERR_SLIPPAGE_EXCEEDED` (104) - Slippage tolerance exceeded
- `ERR_INVALID_SIDECHAIN` (105) - Unsupported sidechain
- `ERR_BRIDGE_PAUSED` (106) - Bridge operations paused
- `ERR_INVALID_PROOF` (107) - Invalid cross-chain proof

## Testing

Run the test suite:

```bash
npm test
```

Run tests with coverage:

```bash
npm run test:report
```

Watch mode for development:

```bash
npm run test:watch
```

## Deployment Guide

### Local Development

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy contracts:
```clarity
::deploy_contracts
```

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`

2. Deploy to testnet:
```bash
clarinet deployments apply --network=testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`

2. Deploy to mainnet:
```bash
clarinet deployments apply --network=mainnet
```

## Security Considerations

### Smart Contract Security

- **Reentrancy Protection**: All state changes occur before external calls
- **Integer Overflow Protection**: Clarity's built-in safe arithmetic prevents overflows
- **Access Control**: Admin functions restricted to contract owner
- **Slippage Protection**: All trading functions include minimum output parameters

### Cross-Chain Security

- **Proof Verification**: Bridge transfers require cryptographic proof verification
- **Transaction Uniqueness**: Bridge transaction IDs prevent replay attacks
- **Confirmation Requirements**: Configurable minimum confirmations per sidechain
- **Pause Mechanism**: Emergency pause functionality for bridge operations

### Best Practices

1. **Always specify slippage tolerance** when calling swap functions
2. **Verify pool reserves** before large trades to avoid price impact
3. **Use minimum output parameters** for all liquidity operations
4. **Monitor bridge transaction status** before considering transfers complete
5. **Keep private keys secure** for admin operations

### Known Limitations

- Cross-chain proof verification uses simplified implementation (production requires full merkle proof validation)
- No automatic price oracles (relies on arbitrageurs for price discovery)
- Single contract owner model (consider multi-sig for production)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the ISC License - see the LICENSE file for details.

## Contact

For questions, issues, or contributions, please open an issue on the GitHub repository.