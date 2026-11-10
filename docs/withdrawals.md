# Withdrawals

A one-time address is a normal EOA that holds the payment and **no ETH for gas**. If you funded it from your main wallet, the funding transaction would link the two forever. Sepia avoids that with three paths, chosen automatically by the app based on what the address holds.

All three end in `SepiaRouter`, which enforces the same rules:

- the destination, amount and fees are signed by the **one-time key** (EIP-712 `Withdraw` struct), so a relayer cannot redirect funds or raise its fee;
- the protocol fee can never exceed `maxFeeBps` (hard-coded ceiling: 100 bps = 1%);
- each signature carries a per-address `nonce` and a `deadline`.

```solidity
struct Withdraw {
    address owner;        // the one-time address
    address token;        // 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE for ETH
    address to;           // where the funds go
    uint256 amount;       // total taken from the one-time address
    address relayer;      // who gets relayerFee (and who may submit, for path B)
    uint256 relayerFee;   // to `relayer`, in `token`
    uint256 protocolFee;  // to FeeCollector, in `token`
    uint256 nonce;
    uint256 deadline;
}
```

`to` receives `amount - relayerFee - protocolFee`.

## Path A: ETH

The one-time address holds ETH, so it can pay its own gas. The app builds one transaction from the one-time address:

```solidity
router.sweepETH{value: balance - gasCost}(to, protocolFee);
```

No relayer is involved, so there is no relayer fee. The router sends `protocolFee` to the FeeCollector and the rest to `to`. Gas is estimated with a safety margin; any dust left after the transaction (usually a few gwei) stays in the address.

## Path B: tokens with EIP-2612 permit (fully gasless)

Applies to USDC if the version deployed on Robinhood Chain implements `permit`, and to any other token that does.

1. The app signs two messages with the one-time key, off-chain:
   - an EIP-2612 `Permit(owner = oneTime, spender = SepiaRouter, value = amount, …)` on the token;
   - a Sepia `Withdraw` struct as above.
2. It sends both signatures to the relayer (`POST /v1/withdraw`, type `permit`).
3. The relayer submits:

```solidity
router.withdrawWithPermit(w, permitDeadline, pv, pr, ps, withdrawSig);
```

The router calls `permit`, pulls `amount` from the one-time address, pays `relayerFee` to the relayer, `protocolFee` to the FeeCollector and the rest to `to`. One transaction, paid by the relayer, repaid in the token. The one-time address never needs ETH.

## Path C: other ERC-20 (gas top-up)

Most memecoins launched on Pons are plain ERC-20s without `permit`. For these:

1. The app asks the relayer for a quote and signs a `Withdraw` intent with the one-time key.
2. The relayer sends a small top-up of ETH (enough for two transactions) **from the relayer's hot wallet** to the one-time address. This links the one-time address to the relayer, which serves everyone, not to you.
3. The one-time address sends `approve(router, amount)` and then `router.sweepToken(w, withdrawSig)`.
4. The router splits the token amount: the relayer is repaid (top-up value plus fee, in the token), the FeeCollector gets the protocol fee, `to` gets the rest.

Risk for the relayer: a user could take the top-up and never sweep. The relayer limits this with per-quote top-up caps, quote expiry and rate limits per IP and per tier pass. The amount at stake per abuse is the gas for two transactions.

When Robinhood Chain supports EIP-7702 (set-code transactions for EOAs), path C collapses into a single sponsored transaction like path B. The router is designed so that this needs no migration: the `Withdraw` struct and fee rules stay the same.

## Where should `to` be?

The safest destination is **not your main wallet**. Options the app offers, from most to least private:

1. Keep funds in the one-time address and spend from it directly (the app tracks every one-time address you own).
2. Withdraw to a fresh address you will use for spending.
3. Withdraw to your main wallet. Convenient, but it publicly links this payment to you. The app shows a warning before you do this.

See [privacy-model.md](privacy-model.md) for amount and timing correlation.

## Failure handling

| Situation | What happens |
| --- | --- |
| Relayer offline | ETH (path A) still works. Tokens wait in the one-time address; nothing is lost. You can always fund it yourself as a last resort. |
| Permit signature rejected by the token | The app falls back to path C. |
| Quote expired | The app requests a new quote; old signatures are useless after `deadline`. |
| Relayer submits a different `to` | Impossible: `to` is inside the signed struct and the router checks the signature. |
