# @sepia-rbh/sdk

TypeScript implementation of ERC-5564 **scheme 1** (secp256k1 with view tags) as used by Sepia on Robinhood Chain.
Two dependencies, both widely used in wallets: [`@noble/curves`](https://github.com/paulmillr/noble-curves) and [`@noble/hashes`](https://github.com/paulmillr/noble-hashes). No network calls.

> Alpha. Unaudited. API may change before Phase 1.

```bash
npm install
npm test          # unit tests
npm run example   # Bob publishes, Alice pays, Bob scans 2,000 announcements and finds his
```

## Usage

```ts
import {
  KEY_MESSAGE, keysFromSignature,
  generateStealthAddress, encodeMetadata,
  checkAnnouncement, computeStealthPrivateKey,
} from "@sepia-rbh/sdk";

// Recipient: one signature → spending + viewing keys → public meta-address
const signature = await wallet.signMessage({ message: KEY_MESSAGE });
const me = keysFromSignature(signature);
me.metaAddress; // "st:rbh:0x02…03…"  share this as a link / QR, or register it in ERC-6538

// Payer: compute a one-time address and the announcement payload
const { stealthAddress, ephemeralPublicKey, viewTag } = generateStealthAddress(me.metaAddress);
const metadata = encodeMetadata(viewTag, "ETH", amountWei);
// router.sendETH{value: amountWei}(stealthAddress, ephemeralPublicKey, metadata)

// Recipient: scan Announcement events with the viewing key
if (checkAnnouncement({ stealthAddress, ephemeralPublicKey, viewTag }, me.viewingPrivateKey, me.spendingPublicKey)) {
  const stealthPriv = computeStealthPrivateKey(ephemeralPublicKey, me.viewingPrivateKey, me.spendingPrivateKey);
  // sign withdrawals locally with stealthPriv — see withdrawTypedData()
}
```

## API

| Function | Side | What it does |
| --- | --- | --- |
| `keysFromSignature(sig)` | recipient | Spending + viewing keys and the `st:rbh:` meta-address from one 65-byte signature |
| `parseMetaAddress(meta)` | payer | Validates and splits a meta-address into two compressed public keys |
| `generateStealthAddress(meta)` | payer | One-time address, ephemeral public key, view tag |
| `encodeMetadata(tag, token, amount)` | payer | 57-byte ERC-5564 metadata |
| `checkAnnouncement(ann, viewPriv, spendPub)` | recipient | `true` if the payment is yours (view tag first, then full check) |
| `computeStealthPrivateKey(ephPub, viewPriv, spendPriv)` | recipient | Private key of the one-time address |
| `withdrawTypedData(router, intent)` | recipient | EIP-712 payload for `SepiaRouter.Withdraw` |
| `withdrawalPath(asset)` | app | Picks path A (ETH), B (permit) or C (top-up) |
