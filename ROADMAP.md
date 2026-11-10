# Roadmap

Each phase ends with a **gate**. The next phase starts only when the gate is met. Dates are announced on [@sepia_rbh](https://x.com/sepia_rbh) as each gate gets close.

Legend: ✅ done · 🔄 in progress · ⬜ planned

## Phase 0 — Launch 🔄

| | Deliverable |
| --- | --- |
| ✅ | Brand: Sepia the cuttlefish, logo, banner |
| ✅ | Concept and token design: stealth payments, relayer, tiers, buyback and burn |
| ✅ | Website with roadmap, token page and app preview |
| ✅ | Link reservation: connect a wallet, sign once, get a Sepia ID |
| ✅ | X account [@sepia_rbh](https://x.com/sepia_rbh) |
| ✅ | This repository: protocol docs, router and fee contracts (draft), SDK (alpha), relayer API spec |
| 🔄 | `$SEPIA` launch on Pons, contract address published on the site and X |

**Gate →** `$SEPIA` trading on Pons with the contract address verified on the website and on X.

## Phase 1 — Private links ⬜

| | Deliverable |
| --- | --- |
| ⬜ | Contracts: deploy `SepiaRouter`, `FeeCollector`, adapter; announcer and registry (canonical or own) |
| ⬜ | Key setup in the app (one signature, double-signed determinism check) |
| ⬜ | Meta-address registration in ERC-6538 |
| ⬜ | Pay page: link + QR, works in any EVM wallet, payer needs no account |
| ⬜ | ETH and USDC |
| ⬜ | In-browser scanner with view tags; indexer for announcements |
| ⬜ | Relayer: path A, B and C withdrawals, sanctions screening |
| ⬜ | Buyback and burn live; public burn counter on the website |

**Gate →** security review of `SepiaRouter` and `FeeCollector` finished and published; first real payments processed end to end.

## Phase 2 — Cashboxes ⬜

| | Deliverable |
| --- | --- |
| ⬜ | Holder tiers and tier passes |
| ⬜ | Any token traded on Pons |
| ⬜ | Recurring payments to a Sepia link |
| ⬜ | Team cashboxes: shared links with roles for withdrawal |
| ⬜ | Auditor access: export a viewing key, read-only dashboard |
| ⬜ | CSV export for accounting; installable mobile web app |

**Gate →** external audit of all Sepia contracts published.

## Phase 3 — Network ⬜

| | Deliverable |
| --- | --- |
| ⬜ | Relayer staking in `$SEPIA`, slashing for censorship and invalid submissions |
| ⬜ | Open-source relayer client; app picks among staked relayers |
| ⬜ | SDK v1 and a checkout button for Robinhood Chain dApps and shops |
| ⬜ | Public stats: payments, active links, total burned |
| ⬜ | Research: ZK proof of holding to replace tier passes |
| ⬜ | Research: privacy pools with association sets, only where compliance allows |

**Done when →** independent staked relayers serve withdrawals alongside the Sepia relayer.
