import { secp256k1 } from "@noble/curves/secp256k1";
import { Hex, N, bytesToBigInt, bigIntToBytes32, keccak, mod, toBytes, toHex } from "./utils.js";

/** The one message a user signs to create their Sepia keys. Changing it changes everyone's keys. */
export const KEY_MESSAGE =
  "Sepia stealth keys v1\n\n" +
  "Sign this message to generate your Sepia keys for Robinhood Chain (4663).\n" +
  "Only sign this on Sepia's official site. This does not cost gas.";

/** Prefix for human-readable meta-addresses. The 66 bytes after it are plain ERC-5564. */
export const META_PREFIX = "st:rbh:";

export interface SepiaKeys {
  spendingPrivateKey: Hex;
  viewingPrivateKey: Hex;
  spendingPublicKey: Hex; // 33 bytes, compressed
  viewingPublicKey: Hex; // 33 bytes, compressed
  metaAddress: string; // st:rbh:0x<spending><viewing>
}

/**
 * Derive spending and viewing keys from a 65-byte wallet signature over KEY_MESSAGE.
 * spendingPriv = keccak256(r) mod n, viewingPriv = keccak256(s) mod n.
 * Wallets must sign deterministically (RFC 6979); callers should sign twice and compare.
 */
export function keysFromSignature(signature: string): SepiaKeys {
  const sig = toBytes(signature);
  if (sig.length !== 65) throw new Error(`Expected a 65-byte signature, got ${sig.length} bytes`);
  const spend = mod(bytesToBigInt(keccak(sig.slice(0, 32))));
  const view = mod(bytesToBigInt(keccak(sig.slice(32, 64))));
  if (spend === 0n || view === 0n) throw new Error("Degenerate key, sign again");
  return keysFromPrivate(spend, view);
}

export function keysFromPrivate(spend: bigint, view: bigint): SepiaKeys {
  if (spend <= 0n || spend >= N || view <= 0n || view >= N) throw new Error("Private key out of range");
  const spendPriv = bigIntToBytes32(spend);
  const viewPriv = bigIntToBytes32(view);
  const spendPub = secp256k1.getPublicKey(spendPriv, true);
  const viewPub = secp256k1.getPublicKey(viewPriv, true);
  return {
    spendingPrivateKey: toHex(spendPriv),
    viewingPrivateKey: toHex(viewPriv),
    spendingPublicKey: toHex(spendPub),
    viewingPublicKey: toHex(viewPub),
    metaAddress: META_PREFIX + toHex(new Uint8Array([...spendPub, ...viewPub])),
  };
}

/** Parse `st:<chain>:0x<66 bytes>` (or the raw 66-byte hex) into its two compressed public keys. */
export function parseMetaAddress(meta: string): { spendingPublicKey: Hex; viewingPublicKey: Hex } {
  const hex = meta.includes(":") ? meta.slice(meta.lastIndexOf(":") + 1) : meta;
  const bytes = toBytes(hex);
  if (bytes.length !== 66) throw new Error(`Meta-address must be 66 bytes, got ${bytes.length}`);
  const spendingPublicKey = toHex(bytes.slice(0, 33));
  const viewingPublicKey = toHex(bytes.slice(33));
  // Validates that both are points on the curve.
  secp256k1.ProjectivePoint.fromHex(bytes.slice(0, 33));
  secp256k1.ProjectivePoint.fromHex(bytes.slice(33));
  return { spendingPublicKey, viewingPublicKey };
}
