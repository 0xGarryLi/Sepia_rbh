import { Hex, bigIntToBytes32, bytesToBigInt, checksum, toBytes, toHex } from "./utils.js";

/** ERC-5564 recommended metadata layout:
 *  [0] view tag · [1..4] selector · [5..24] token · [25..56] amount */
export const ETH_SELECTOR = "0xeeeeeeee";
export const TRANSFER_SELECTOR = "0xa9059cbb";
export const ETH_TOKEN = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

export function encodeMetadata(viewTag: number, token: string | "ETH", amount: bigint): Hex {
  if (viewTag < 0 || viewTag > 255) throw new Error("viewTag must be one byte");
  const isEth = token === "ETH" || token.toLowerCase() === ETH_TOKEN.toLowerCase();
  const selector = toBytes(isEth ? ETH_SELECTOR : TRANSFER_SELECTOR);
  const tokenBytes = toBytes(isEth ? ETH_TOKEN : token);
  if (tokenBytes.length !== 20) throw new Error("token must be a 20-byte address");
  return toHex(new Uint8Array([viewTag, ...selector, ...tokenBytes, ...bigIntToBytes32(amount)]));
}

export interface DecodedMetadata {
  viewTag: number;
  isEth: boolean;
  token?: Hex;
  amount?: bigint;
}

export function decodeMetadata(metadata: string): DecodedMetadata {
  const b = toBytes(metadata);
  if (b.length < 1) throw new Error("Empty metadata");
  const out: DecodedMetadata = { viewTag: b[0], isEth: false };
  if (b.length >= 5) out.isEth = toHex(b.slice(1, 5)) === ETH_SELECTOR;
  if (b.length >= 25) out.token = checksum(toHex(b.slice(5, 25)));
  if (b.length >= 57) out.amount = bytesToBigInt(b.slice(25, 57));
  return out;
}
