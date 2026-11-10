import { test } from "node:test";
import assert from "node:assert/strict";
import { secp256k1 } from "@noble/curves/secp256k1";
import { bytesToHex } from "@noble/hashes/utils";
import {
  keysFromSignature,
  parseMetaAddress,
  generateStealthAddress,
  checkAnnouncement,
  computeStealthPrivateKey,
  addressOf,
  encodeMetadata,
  decodeMetadata,
} from "../src/index.js";

const sig = () => "0x" + bytesToHex(secp256k1.utils.randomPrivateKey()) + bytesToHex(secp256k1.utils.randomPrivateKey()) + "1b";

test("keys are deterministic for the same signature", () => {
  const s = sig();
  assert.equal(keysFromSignature(s).metaAddress, keysFromSignature(s).metaAddress);
});

test("meta-address round-trips", () => {
  const k = keysFromSignature(sig());
  const p = parseMetaAddress(k.metaAddress);
  assert.equal(p.spendingPublicKey, k.spendingPublicKey);
  assert.equal(p.viewingPublicKey, k.viewingPublicKey);
});

test("recipient recognises and controls the stealth address", () => {
  const bob = keysFromSignature(sig());
  const g = generateStealthAddress(bob.metaAddress);
  assert.ok(checkAnnouncement({ ...g }, bob.viewingPrivateKey, bob.spendingPublicKey));
  const priv = computeStealthPrivateKey(g.ephemeralPublicKey, bob.viewingPrivateKey, bob.spendingPrivateKey);
  assert.equal(addressOf(priv), g.stealthAddress);
});

test("a stranger does not recognise the payment", () => {
  const bob = keysFromSignature(sig());
  const eve = keysFromSignature(sig());
  const g = generateStealthAddress(bob.metaAddress);
  assert.equal(checkAnnouncement({ ...g }, eve.viewingPrivateKey, eve.spendingPublicKey), false);
});

test("two payments to the same person use unrelated addresses", () => {
  const bob = keysFromSignature(sig());
  assert.notEqual(generateStealthAddress(bob.metaAddress).stealthAddress, generateStealthAddress(bob.metaAddress).stealthAddress);
});

test("metadata encodes the ERC-5564 layout", () => {
  const m = encodeMetadata(0x7a, "0x1111111111111111111111111111111111111111", 42n);
  const d = decodeMetadata(m);
  assert.equal(d.viewTag, 0x7a);
  assert.equal(d.isEth, false);
  assert.equal(d.amount, 42n);
  assert.equal((m.length - 2) / 2, 57);
});
