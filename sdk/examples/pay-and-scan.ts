/**
 * End-to-end, fully local: Bob publishes a meta-address, Alice pays it, Bob scans 2,000 announcements
 * (1,999 belong to strangers) and finds the one that is his.
 *
 *   npm install && npm run example
 */
import { secp256k1 } from "@noble/curves/secp256k1";
import { bytesToHex } from "@noble/hashes/utils";
import {
  keysFromSignature,
  generateStealthAddress,
  checkAnnouncement,
  computeStealthPrivateKey,
  addressOf,
  encodeMetadata,
  decodeMetadata,
} from "../src/index.js";

// 1. Bob signs KEY_MESSAGE once in his wallet. Here we fake a 65-byte signature.
const fakeSignature = "0x" + bytesToHex(secp256k1.utils.randomPrivateKey()) + bytesToHex(secp256k1.utils.randomPrivateKey()) + "1b";
const bob = keysFromSignature(fakeSignature);
console.log("Bob's meta-address:", bob.metaAddress.slice(0, 32) + "…");

// 2. Alice opens Bob's Sepia link and pays 250 USDC.
const USDC = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"; // placeholder token address for the example
const pay = generateStealthAddress(bob.metaAddress);
const metadata = encodeMetadata(pay.viewTag, USDC, 250_000_000n);
console.log("Alice pays one-time address:", pay.stealthAddress);

// 3. The chain is full of other people's payments.
type Ann = { stealthAddress: string; ephemeralPublicKey: string; metadata: string };
const feed: Ann[] = [];
for (let i = 0; i < 1999; i++) {
  const stranger = keysFromSignature("0x" + bytesToHex(secp256k1.utils.randomPrivateKey()) + bytesToHex(secp256k1.utils.randomPrivateKey()) + "1c");
  const p = generateStealthAddress(stranger.metaAddress);
  feed.push({ stealthAddress: p.stealthAddress, ephemeralPublicKey: p.ephemeralPublicKey, metadata: encodeMetadata(p.viewTag, "ETH", 1n) });
}
feed.splice(1234, 0, { stealthAddress: pay.stealthAddress, ephemeralPublicKey: pay.ephemeralPublicKey, metadata });

// 4. Bob scans with his viewing key only.
let tagHits = 0;
const t0 = performance.now();
const mine = feed.filter((a) => {
  const { viewTag } = decodeMetadata(a.metadata);
  const hit = checkAnnouncement({ ...a, viewTag }, bob.viewingPrivateKey, bob.spendingPublicKey);
  if (hit) tagHits++;
  return hit;
});
console.log(`Scanned ${feed.length} announcements in ${(performance.now() - t0).toFixed(0)} ms, found ${mine.length} for Bob`);

// 5. Bob derives the private key of the one-time address and checks it.
const priv = computeStealthPrivateKey(mine[0].ephemeralPublicKey, bob.viewingPrivateKey, bob.spendingPrivateKey);
const ok = addressOf(priv).toLowerCase() === pay.stealthAddress.toLowerCase();
console.log("Derived key controls the one-time address:", ok);
const meta = decodeMetadata(mine[0].metadata);
console.log("Payment:", meta.amount, "units of", meta.token);
if (!ok || mine.length !== 1) process.exit(1);
