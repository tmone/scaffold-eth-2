# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- Build/Compile: `yarn compile` or `yarn hardhat:compile`
- Run blockchain: `yarn chain`
- Deploy contracts: `yarn deploy`
- Start frontend: `yarn start`
- Run tests: `yarn test` or `yarn hardhat:test` (for single test: `yarn hardhat test --network hardhat path/to/test.js`)
- Lint: `yarn lint` (combines frontend and contract linting)
- Format: `yarn format`
- Type check: `yarn hardhat:check-types` and `yarn next:check-types`

## Code Style Guidelines
- **TypeScript/JavaScript**: 2 space indentation, 120 character width, arrow functions without parentheses for single params
- **Solidity**: 4 space indentation, double quotes, bracket spacing enabled
- **Imports order**: React → Next.js → third-party → Heroicons → project imports (with `~~/` prefix)
- **Contract interactions**: Always use SE-2 hooks (`useScaffoldReadContract` for reading, `useScaffoldWriteContract` for writing)
- **UI Components**: Use provided components like `Address`, `AddressInput`, `Balance`, `EtherInput` for common patterns
- **Error handling**: Components should gracefully handle loading/error states
- **File organization**: Organize code by component function and follow existing project patterns