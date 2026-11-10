import { keccak_256 } from "@noble/hashes/sha3";
import { bytesToHex as b2h, hexToBytes as h2b } from "@noble/hashes/utils";
import { secp256k1 } from "@noble/curves/secp256k1";

export type Hex = `0x${string}`;

export const N = secp256k1.CURVE.n;
export const Point = secp256k1.ProjectivePoint;

export const strip0x = (h: string): string => (h.startsWith("0x") || h.startsWith("0X") ? h.slice(2) : h);
export const toBytes = (h: string): Uint8Array => h2b(strip0x(h));
export const toHex = (b: Uint8Array): Hex => `0x${b2h(b)}`;
export const keccak = (b: Uint8Array): Uint8Array => keccak_256(b);

export const bytesToBigInt = (b: Uint8Array): bigint => BigInt("0x" + (b2h(b) || "0"));
export const bigIntToBytes32 = (x: bigint): Uint8Array => h2b(x.toString(16).padStart(64, "0"));
export const mod = (a: bigint, m: bigint = N): bigint => ((a % m) + m) % m;

/** EIP-55 checksummed address from a secp256k1 point. */
export function pointToAddress(point: InstanceType<typeof Point>): Hex {
  const uncompressed = point.toRawBytes(false); // 0x04 ‖ X ‖ Y
  const addr = b2h(keccak(uncompressed.slice(1)).slice(12));
  return checksum(addr);
}

export function checksum(addressHex: string): Hex {
  const a = strip0x(addressHex).toLowerCase();
  const hash = b2h(keccak(new TextEncoder().encode(a)));
  let out = "0x";
  for (let i = 0; i < a.length; i++) out += parseInt(hash[i], 16) >= 8 ? a[i].toUpperCase() : a[i];
  return out as Hex;
}

export const sameAddress = (a: string, b: string): boolean => strip0x(a).toLowerCase() === strip0x(b).toLowerCase();
