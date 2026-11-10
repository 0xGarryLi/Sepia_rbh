# Sepia relayer

The relayer lets a one-time address move its funds without ever holding ETH from its owner. It has no custody: every withdrawal it submits is bound by a signature from the one-time key, and `SepiaRouter` rejects anything else.

API: [`openapi.yaml`](openapi.yaml) · Flow details: [`../docs/withdrawals.md`](../docs/withdrawals.md)

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/v1/health` | Liveness, current gas price, hot-wallet balance band |
| `POST` | `/v1/quote` | Fee quote for a withdrawal (path B or C), valid 120 s |
| `POST` | `/v1/withdraw` | Submit a signed permit withdrawal (B) or request a gas top-up (C) |
| `GET` | `/v1/withdraw/{id}` | Status: `pending`, `submitted`, `confirmed`, `failed` |
| `POST` | `/v1/tier-pass` | Exchange a main-wallet signature for a 24 h tier pass |

## Fee formula

```
relayerFee  = gasUnits × gasPrice × (1 + margin) converted to the token at a DEX quote
              × tierMultiplier            (Open 1.0 · Ink 0.5 · Cloud 0 · Abyss 0)
protocolFee = amount × protocolBps / 10_000   (protocolBps ≤ router.maxFeeBps ≤ 100)
```

Path A (ETH) never touches the relayer and pays no relayer fee.

## Operating rules

1. **No custody.** The hot wallet only holds ETH for gas. It never receives user funds except the signed `relayerFee`.
2. **Sanctions screening.** The `to` address of every withdrawal is checked against public sanctions lists. A match returns `403` and nothing is submitted.
3. **No address logging.** Request logs keep: endpoint, status code, latency, token, rounded amount bucket. Not: IP (beyond a 10-minute rate-limit window), `owner`, `to`, tier-pass ids.
4. **Top-up limits (path C).** One top-up per quote, capped at the gas for two transactions, quotes expire in 120 s, per-IP and per-pass rate limits.
5. **Open source.** The relayer client is published in Phase 3 so anyone can run one.

## Tier passes

`POST /v1/tier-pass` takes `{ address, signature, issuedAt }`, checks the `$SEPIA` balance of `address` on Robinhood Chain, and returns `{ pass, tier, expiresAt }`. The pass is a random 128-bit id signed by the relayer; it contains no address. Read the trade-off in [`../docs/privacy-model.md`](../docs/privacy-model.md#tier-passes) before using one.
