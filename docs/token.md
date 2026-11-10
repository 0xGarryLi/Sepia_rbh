# $SEPIA

| | |
| --- | --- |
| Name | Sepia |
| Ticker | `$SEPIA` |
| Chain | Robinhood Chain (4663) |
| Launchpad | Pons |
| Supply | Fixed at launch, no mint function |
| Liquidity | Locked by Pons |
| Contract | Published at launch on the website and on [@sepia_rbh](https://x.com/sepia_rbh). Not in this repo until it exists. |

`$SEPIA` carries no claim on revenue and no governance over user funds. It does four things inside the product.

## 1. Cheaper withdrawals

The relayer fee is quoted per withdrawal. A valid tier pass ([privacy-model.md](privacy-model.md#tier-passes)) lowers or removes it.

## 2. Tiers

| Tier | Holding | Unlocks |
| --- | --- | --- |
| Open | none | 1 payment link, ETH and USDC, standard relayer fee |
| Ink | set at launch | reduced relayer fee, more links, any Pons token |
| Cloud | set at launch | zero relayer fee, recurring payments, custom link names |
| Abyss | set at launch | everything in Cloud, team cashboxes, early access |

Thresholds in `$SEPIA` are set after launch, once the market has priced the token, and published in `deployments/` and on the website.

## 3. Buyback and burn

```
withdrawal → protocol fee → FeeCollector
   ├── ops share (≤ 30%, published) → relayer gas, infrastructure, development
   └── rest → swap to $SEPIA → 0x000000000000000000000000000000000000dEaD
```

- Every burn emits `Burned(tokenIn, amountIn, sepiaBurned)` and increases `totalBurned`.
- The swap is done by an allow-listed keeper with a minimum-out set from a fresh quote; the adapter checks that the route ends in `$SEPIA`, so fees cannot be swapped into anything else.
- The ops share and its wallet are public and changeable only by the multisig, with an on-chain event.

## 4. Relayer staking (Phase 3)

Independent relayers stake `$SEPIA` to be listed in the app. They earn relayer fees. A relayer that censors withdrawals it accepted, or submits invalid transactions, loses part of its stake. Exact parameters will be specified in a separate design doc before Phase 3.

## What $SEPIA does not do

- It is not needed to receive payments. Open tier is free of `$SEPIA`.
- It does not give anyone access to user funds or keys.
- It does not entitle holders to fees. Fees are burned, not distributed.
