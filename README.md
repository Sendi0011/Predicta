# 🎯 Predicta - AI-Powered Prediction Markets

> A decentralized prediction market platform powered by AI-driven resolution oracles Build with stacks.

[![Next.js](https://img.shields.io/badge/Next.js-16.0-black?style=flat-square&logo=next.js)](https://nextjs.org/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.23-363636?style=flat-square&logo=solidity)](https://soliditylang.org/)
[![Base](https://img.shields.io/badge/Base-Sepolia-0052FF?style=flat-square)](https://base.org/)

## 📖 Overview

TruthBase is a next-generation prediction market platform where users can create and trade on the outcomes of real-world events. The platform leverages AI-powered oracles for transparent and accurate market resolution.

### Key Features

- 🎲 **Binary Prediction Markets** - Trade on YES/NO outcomes of future events
- 🤖 **AI-Powered Resolution** - Automated market resolution using AI oracles with multi-signer verification
- 💰 **USDC Staking** - Stake with stablecoins for predictable payouts
- 🏆 **Dynamic Odds** - Real-time probability updates based on market activity
- 🔒 **Role-Based Access** - Permissioned market creation with admin controls
- ⚡ **Gas Efficient** - EIP-1167 minimal proxy pattern for market deployment

## 🏗️ Architecture

### Smart Contracts

```
contracts/
├── MarketFactory.sol    # Market creation and management
├── Market.sol           # Individual market logic (ERC-1155)
├── AIOracle.sol         # AI-powered resolution oracle
└── MarketTypes.sol      # Shared types and structs
```

**Deployed Contracts (Base Sepolia):**
- Factory: `0xDb657bC5A74A81E919f9d671035dB0b6370c9d16`
- Oracle: `0xfc70C42bC2355Cbc98Bc575032dA8Dc33F0a11F4`
- Market Implementation: `0x7F0ba204385d2f0c5d42572ed4ceEc622441A451`
- USDC: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

### Frontend

```
frontend/
├── app/
│   ├── markets/         # Market browsing and detail pages
│   ├── dashboard/       # User portfolio and positions
│   ├── admin/           # Market creation (requires CREATOR_ROLE)
│   └── how-it-works/    # Documentation
├── components/
│   ├── ui/              # shadcn/ui components
│   └── navbar.tsx       # Navigation
├── hooks/
│   ├── use-market.ts    # Market contract interactions
│   ├── use-factory.ts   # Factory contract interactions
│   ├── use-oracle.ts    # Oracle contract interactions
│   └── use-usdc.ts      # USDC token operations
└── lib/
    ├── contracts.ts     # Contract ABIs and addresses
    └── web3-utils.ts    # Web3 utility functions
```

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ 
- npm or pnpm
- MetaMask or compatible Web3 wallet

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/truthbase.git
   cd truthbase
   ```

2. **Install frontend dependencies:**
   ```bash
   cd frontend
   npm install
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.example .env.local
   ```

   Edit `.env.local`:
   ```env
   NEXT_PUBLIC_PRIVY_APP_ID=your_privy_app_id
   ```

4. **Run the development server:**
   ```bash
   npm run dev
   ```

5. **Open your browser:**
   ```
   http://localhost:3000
   ```

## 💡 How It Works

### For Users

1. **Browse Markets** - Explore prediction markets across categories (Crypto, Economy, Sports, etc.)
2. **Stake USDC** - Choose YES or NO and stake USDC on your prediction
3. **Track Positions** - Monitor your active positions in the dashboard
4. **Claim Winnings** - After market resolution, claim your share of the winning pool

### For Market Creators

1. **Get Creator Role** - Request CREATOR_ROLE from admin
2. **Create Market** - Define question, category, and end date
3. **Set Parameters** - Configure fees, stake limits (or use defaults)
4. **Launch** - Market goes live for users to trade

### Market Resolution

Markets are resolved through a multi-step process:

1. **Submission** - Authorized signers submit resolution with signatures
2. **Voting** - Multiple signers must agree (requires 3/5 confirmations)
3. **Challenge Period** - 24-hour window for disputes
4. **Finalization** - After challenge period, resolution is finalized
5. **Payout** - Winners can claim their share of the pool

## 🎮 User Guide

### Staking on a Market

```typescript
// 1. Approve USDC (handled automatically)
// 2. Place stake
await stake('yes', 100) // Stake 100 USDC on YES

// View your position
const position = await getUserStake(marketAddress, userAddress)
// { yesStake: 100, noStake: 0, totalStake: 100, side: 0 }
```

### Creating a Market (Requires CREATOR_ROLE)

```typescript
// Simple market with defaults
await createSimpleMarket(
  "Will Bitcoin reach $100k by end of 2025?",
  "Crypto",
  1735660800 // Unix timestamp
)

// Advanced market with custom parameters
await createMarket(
  "Will Bitcoin reach $100k by end of 2025?",
  "Crypto",
  ["CoinMarketCap", "CoinGecko"], // Sources
  1735660800,
  200, // 2% fee
  10000 * 1e6, // Max 10k USDC per user
  1000000 * 1e6 // Max 1M USDC total pool
)
```

### Claiming Winnings

```typescript
// Check if you can claim
const canUserClaim = await canClaim(userAddress)

// Claim winnings
if (canUserClaim) {
  await claim()
}
```

## 🛠️ Development

### Project Structure

```
.
├── frontend/              # Next.js frontend
│   ├── app/              # Next.js 13+ app directory
│   ├── components/       # React components
│   ├── hooks/            # Custom React hooks
│   ├── lib/              # Utilities and configurations
│   └── contracts/abi/    # Smart contract ABIs
├── contracts/            # Solidity smart contracts
└── docs/                # Additional documentation
```

### Technology Stack

**Frontend:**
- Next.js 16.0 (App Router)
- React 19
- TypeScript
- Tailwind CSS + shadcn/ui
- Privy (Authentication & Embedded Wallets)
- Wagmi + Viem (Web3 interactions)

**Smart Contracts:**
- Solidity 0.8.23
- OpenZeppelin Contracts
- EIP-1167 Minimal Proxy Pattern
- ERC-1155 Position Tokens

**Infrastructure:**
- Base Sepolia (Testnet)
- IPFS (Metadata storage - planned)
- The Graph (Indexing - planned)

### Key Hooks

```typescript
// Market operations
const { stake, claim, getMarketInfo } = useMarket(marketAddress)

// Factory operations
const { createMarket, getAllMarkets } = useFactory()

// Oracle operations
const { getResolution, isResolutionFinalized } = useOracle()

// USDC operations
const { approve, getBalance } = useUSDC(userAddress)
```

### Running Tests

```bash
# Frontend tests
cd frontend
npm test

# Contract tests (if using Hardhat/Foundry)
cd contracts
npx hardhat test
# or
forge test
```

## 🔐 Security

### Smart Contract Security

- ✅ OpenZeppelin battle-tested contracts
- ✅ ReentrancyGuard on all state-changing functions
- ✅ Access control with role-based permissions
- ✅ Input validation and sanity checks
- ⚠️ Audit pending - use at your own risk on testnet

### Frontend Security

- ✅ No private keys stored in frontend
- ✅ Privy embedded wallets for secure key management
- ✅ Input sanitization
- ✅ Rate limiting on API calls (planned)

### Known Limitations

- **Testnet Only** - Currently deployed on Base Sepolia (testnet)
- **Centralized Resolution** - Oracle signers are centralized (decentralization planned)
- **No Slippage Protection** - Fixed price based on pool ratio

## 🎯 Roadmap

### Phase 1: MVP (Current)
- [x] Core market creation and staking
- [x] User dashboard and positions
- [x] Basic AI oracle resolution
- [x] Admin panel

### Phase 2: Enhanced Features
- [ ] Advanced market types (scalar, categorical)
- [ ] Liquidity provision
- [ ] Market maker incentives
- [ ] Mobile app

### Phase 3: Decentralization
- [ ] Decentralized oracle network
- [ ] Governance token
- [ ] DAO for platform decisions
- [ ] Mainnet deployment

### Phase 4: Scaling
- [ ] Layer 2 optimizations
- [ ] Cross-chain markets
- [ ] Advanced analytics
- [ ] API for third-party integrations

## 📚 Additional Resources

- **Smart Contract Documentation**: [contracts/README.md](./contracts/README.md)
- **API Documentation**: [docs/API.md](./docs/API.md)
- **Integration Guide**: [docs/INTEGRATION_GUIDE.md](./docs/INTEGRATION_GUIDE.md)
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Contribution Guidelines

- Follow the existing code style
- Add tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting PR

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

- **Core Team** - Building the future of prediction markets
- **Contributors** - See [CONTRIBUTORS.md](./CONTRIBUTORS.md)

## 📞 Contact & Support

- **Website**: [truthbase.xyz](https://truthbase.xyz)
- **Twitter**: [@truthbase](https://twitter.com/truthbase)
- **Discord**: [Join our community](https://discord.gg/truthbase)
- **Email**: support@truthbase.xyz

## 🙏 Acknowledgments

- OpenZeppelin for secure contract primitives
- Base for the L2 infrastructure
- Privy for seamless authentication
- shadcn/ui for beautiful components
- The prediction market community

---

**⚠️ Disclaimer**: This is experimental software deployed on testnet. Use at your own risk. Not financial advice.

**Built with ❤️ by the Predicta Team**