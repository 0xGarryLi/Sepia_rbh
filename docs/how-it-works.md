# How Sepia works

Sepia implements **ERC-5564 scheme 1**: stealth addresses on secp256k1 with 1-byte view tags. This document walks through every step with the exact math the SDK uses.

Notation: `G` is the secp256k1 generator, `n` its order, `·` scalar multiplication, `+` point addition, `‖` concatenation, `H` is `keccak256`.

## 1. Keys: one signature, two key pairs

A user never manages extra seed phrases. The app asks the wallet to sign a fixed message once:

```
Sepia stealth keys v1

Sign this message to generate your Sepia keys for Robinhood Chain (4663).
Only sign this on sepia's official site. This does not cost gas.
```

The 65-byte signature `(r, s, v)` is split and hashed:

```
spendingPriv = H(r) mod n        viewingPriv = H(s) mod n
spendingPub  = spendingPriv · G  viewingPub  = viewingPriv · G
```

The wallet must produce deterministic signatures (RFC 6979). All mainstream wallets do; the SDK signs twice on first setup and refuses to continue if the two signatures differ.

| Key | Who holds it | What it can do |
| --- | --- | --- |
| Spending key | You only | Move funds out of your one-time addresses |
| Viewing key | You, and anyone you share it with | See which payments are yours. Cannot move funds |

## 2. The stealth meta-address

Your public meta-address is both compressed public keys, 66 bytes:

```
st:rbh:0x 02a7c4…(33 bytes spendingPub) 03b91f…(33 bytes viewingPub)
```

`st:rbh:` is a chain hint for humans and wallets; the bytes are standard ERC-5564. You can publish the meta-address as a link or QR, and register it on-chain in the ERC-6538 registry so payers can look it up from your address:

```solidity
registry.registerKeys(1, spendingPub ‖ viewingPub);
```

## 3. Paying: the sender computes a fresh address

The payer's wallet (through the Sepia pay page or the SDK) does:

```
ephemeralPriv  = random scalar in [1, n)
ephemeralPub   = ephemeralPriv · G                    (33 bytes, compressed)
sharedSecret   = ephemeralPriv · viewingPub           (33 bytes, compressed)
h              = H(sharedSecret)                      (32 bytes)
viewTag        = h[0]
stealthPub     = spendingPub + (h mod n) · G
stealthAddress = last 20 bytes of H(uncompressed(stealthPub) without the 0x04 prefix)
```

The funds and the announcement go out in one transaction through `SepiaRouter`:

```solidity
router.sendETH{value: amount}(stealthAddress, ephemeralPub, metadata);
// or, after approve:
router.sendToken(token, amount, stealthAddress, ephemeralPub, metadata);
```

The router forwards the funds straight to `stealthAddress` and calls the ERC-5564 announcer, which emits:

```solidity
event Announcement(
    uint256 indexed schemeId,        // 1
    address indexed stealthAddress,
    address indexed caller,          // SepiaRouter
    bytes ephemeralPubKey,
    bytes metadata
);
```

## 4. Announcement metadata

Sepia follows the layout recommended by ERC-5564:

| Bytes | Field | ETH payment | Token payment |
| --- | --- | --- | --- |
| 0 | view tag | `h[0]` | `h[0]` |
| 1–4 | function selector | `0xeeeeeeee` | `0xa9059cbb` (`transfer`) |
| 5–24 | token address | `0xeeee…eeee` | token contract |
| 25–56 | amount | wei | token units |

## 5. Receiving: scanning with the viewing key

Your scanner reads `Announcement` events with `schemeId = 1` and, for each one:

```
sharedSecret = viewingPriv · ephemeralPub
h            = H(sharedSecret)
if h[0] != metadata[0]: skip                 // view tag mismatch: 255 of 256 strangers' payments stop here
stealthPub   = spendingPub + (h mod n) · G
if address(stealthPub) == announcement.stealthAddress: it is yours
```

The view tag check costs one elliptic-curve multiplication and one hash per announcement, which keeps scanning fast enough to run in a browser. The heavy step (point addition and address derivation) runs only for about 1 in 256 announcements.

Scanning needs only the viewing key, so you can run it on a server you trust, or hand the viewing key to an accountant without giving them the power to spend.

## 6. Spending: the one-time private key

For a matched payment:

```
stealthPriv = (spendingPriv + h) mod n
```

`stealthPriv` controls `stealthAddress` like any normal EOA. The app never sends it anywhere; it signs withdrawals locally. How the funds leave without linking back to you is covered in [withdrawals.md](withdrawals.md).

## 7. Why this is private

- An observer sees a payment to `stealthAddress`, a fresh address with no history.
- Linking it to you requires `viewingPriv` (to recognise it) and `spendingPriv` (to prove it). Neither is ever published.
- Each payment uses a new random `ephemeralPriv`, so two payments to the same person produce unrelated addresses.

What remains visible, and how to avoid leaking it at withdrawal time, is listed in [privacy-model.md](privacy-model.md).

## Reference

- ERC-5564: Stealth Addresses — https://eips.ethereum.org/EIPS/eip-5564
- ERC-6538: Stealth Meta-Address Registry — https://eips.ethereum.org/EIPS/eip-6538
- SDK implementation: [`sdk/src/stealth.ts`](../sdk/src/stealth.ts)
