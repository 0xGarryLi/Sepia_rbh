# Sepia contracts

Foundry project. Draft, unaudited, not deployed.

```bash
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts --no-commit
forge build
forge test -vv
```

| Contract | Purpose |
| --- | --- |
| [`SepiaRouter`](src/SepiaRouter.sol) | `sendETH` / `sendToken` pay a stealth address and announce in one tx. `sweepETH`, `withdrawWithPermit`, `sweepToken` move funds out (paths A, B, C). Protocol fee capped at `maxFeeBps` ≤ 100. |
| [`FeeCollector`](src/FeeCollector.sol) | Takes the published ops share (≤ 30%), swaps the rest to `$SEPIA` through an adapter and sends it to `0x…dEaD`. Tracks `totalBurned`. |
| [`UniswapV3Adapter`](src/adapters/UniswapV3Adapter.sol) | Swap adapter for a v3-style router. Rejects routes that do not start at the fee token and end at `$SEPIA`. |
| [`ERC5564Announcer`](src/ERC5564Announcer.sol) | Minimal announcer, deployed only if the canonical singleton is missing on Robinhood Chain. |

## Invariants the tests cover

- The router keeps no balance after `sendETH` / `sendToken`.
- The protocol fee can never exceed `maxFeeBps`, and `maxFeeBps` can never exceed 100.
- A relayer cannot change `to`, `amount` or fees of a signed withdrawal, cannot replay it, and cannot submit someone else's quote.
- Fee-on-transfer tokens are paid out from what actually arrived.

## Deploy

```bash
cp .env.example .env   # fill in
forge script script/Deploy.s.sol --rpc-url robinhood --broadcast --verify
```
