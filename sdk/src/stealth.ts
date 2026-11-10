import { secp256k1 } from "@noble/curves/secp256k1";
import { parseMetaAddress } from "./keys.js";
import { Hex, Point, bytesToBigInt, bigIntToBytes32, keccak, mod, pointToAddress, sameAddress, toBytes, toHex } from "./utils.js";

/** ERC-5564 scheme id for secp256k1 with view tags. */
export const SCHEME_ID = 1;

export interface GeneratedStealthAddress {
  stealthAddress: Hex;
  ephemeralPublicKey: Hex; // 33 bytes, compressed — goes into the announcement
  viewTag: number; // first byte of the hashed shared secret — goes into metadata[0]
}

/**
 * Sender side. From the recipient's meta-address, compute a one-time address only they can recognise.
 *   S = ephemeralPriv · viewingPub ; h = keccak256(S) ; stealthPub = spendingPub + h·G
 */
export function generateStealthAddress(metaAddress: string, ephemeralPrivateKey?: string): GeneratedStealthAddress {
  const { spendingPublicKey, viewingPublicKey } = parseMetaAddress(metaAddress);
  const ephPriv = ephemeralPrivateKey ? toBytes(ephemeralPrivateKey) : secp256k1.utils.randomPrivateKey();
  const ephPub = secp256k1.getPublicKey(ephPriv, true);

  const shared = secp256k1.getSharedSecret(ephPriv, toBytes(viewingPublicKey), true); // 33 bytes
  const h = keccak(shared);
  const hScalar = mod(bytesToBigInt(h));

  const stealthPub = Point.fromHex(toBytes(spendingPublicKey)).add(Point.BASE.multiply(hScalar));
  return { stealthAddress: pointToAddress(stealthPub), ephemeralPublicKey: toHex(ephPub), viewTag: h[0] };
}

export interface AnnouncementLike {
  stealthAddress: string;
  ephemeralPublicKey: string;
  /** metadata[0] from the event. If omitted, the view tag shortcut is skipped. */
  viewTag?: number;
}

/**
 * Recipient side. Is this announcement a payment to me?
 * Needs only the viewing private key and the spending public key, so it can run on an untrusted scanner.
 */
export function checkAnnouncement(a: AnnouncementLike, viewingPrivateKey: string, spendingPublicKey: string): boolean {
  const shared = secp256k1.getSharedSecret(toBytes(viewingPrivateKey), toBytes(a.ephemeralPublicKey), true);
  const h = keccak(shared);
  if (a.viewTag !== undefined && h[0] !== a.viewTag) return false; // ~255/256 of foreign payments stop here
  const stealthPub = Point.fromHex(toBytes(spendingPublicKey)).add(Point.BASE.multiply(mod(bytesToBigInt(h))));
  return sameAddress(pointToAddress(stealthPub), a.stealthAddress);
}

/**
 * Recipient side. Private key that controls the one-time address: (spendingPriv + h) mod n.
 * Never send this anywhere; sign withdrawals locally.
 */
export function computeStealthPrivateKey(
  ephemeralPublicKey: string,
  viewingPrivateKey: string,
  spendingPrivateKey: string,
): Hex {
  const shared = secp256k1.getSharedSecret(toBytes(viewingPrivateKey), toBytes(ephemeralPublicKey), true);
  const h = mod(bytesToBigInt(keccak(shared)));
  const priv = mod(bytesToBigInt(toBytes(spendingPrivateKey)) + h);
  if (priv === 0n) throw new Error("Degenerate stealth key");
  return toHex(bigIntToBytes32(priv));
}

/** Address controlled by a private key (handy for double-checking a derived key). */
export function addressOf(privateKey: string): Hex {
  return pointToAddress(Point.fromHex(secp256k1.getPublicKey(toBytes(privateKey), true)));
}
