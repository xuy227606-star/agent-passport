# Agent Passport

Daily check-in passport for Agent ID holders, built for the Binance Agent ID Hackathon.

- Only addresses holding a SPACE ID Agent ID (ERC-721, `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Chain) can check in.
- Check in once a day. Each check-in stamps a random destination visa (12 destinations). A missed day resets the streak.
- Badges are soulbound (non-transferable) ERC-721 tokens, minted in the same transaction as the check-in that earns them, gas only:
  - Genesis — first 100 check-ins overall
  - 7-day streak
  - 30-day streak
  - Referrer Bronze / Silver / Gold — 1 / 3 / 10 successful referrals
- On the first check-in, each user picks one of 5 art styles (0 Black-Gold Holo, 1 Cyberpunk, 2 Anime, 3 Pixel, 4 Fantasy). The style is stored on-chain and cannot be changed afterwards.
- Referral rewards are badges only, never money. A referral counts only when the referred address (a different Agent ID holder) makes its first check-in, and the referrer claims the badge in their own transaction.
- No admin functions: no owner, no pause, no fee, no token, no promised return, no monetary value. The contract never holds funds (no payable functions). Check-in costs gas only.

## Contract

- `contracts/AgentPassport.sol` — Solidity 0.8.20, OpenZeppelin ERC-721 + ERC721URIStorage, MIT licensed.
- Agent ID contract: `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (BNB Chain)

## Build

Requires Node.js.

```sh
npm install
node compile.js
```

This compiles `contracts/AgentPassport.sol` with solc 0.8.28 (optimizer on, viaIR) and writes `build/AgentPassport.abi.json` and `build/AgentPassport.bytecode.txt`.

## Status

Contract written and compiled, not yet deployed. Deployment needs the owner's confirmation of the exact preview first — once deployed, the contract cannot be changed.
