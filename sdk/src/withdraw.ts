import { Hex } from "./utils.js";

export const ROBINHOOD_CHAIN_ID = 4663;

export interface WithdrawIntent {
  owner: Hex; // one-time address
  token: Hex;
  to: Hex;
  amount: bigint;
  relayer: Hex;
  relayerFee: bigint;
  protocolFee: bigint;
  nonce: bigint;
  deadline: bigint;
}

/**
 * EIP-712 typed data for SepiaRouter.Withdraw. Sign it with the one-time private key
 * (e.g. viem's `privateKeyToAccount(stealthPriv).signTypedData(typedData)`).
 */
export function withdrawTypedData(router: Hex, intent: WithdrawIntent, chainId = ROBINHOOD_CHAIN_ID) {
  return {
    domain: { name: "SepiaRouter", version: "1", chainId, verifyingContract: router },
    primaryType: "Withdraw" as const,
    types: {
      Withdraw: [
        { name: "owner", type: "address" },
        { name: "token", type: "address" },
        { name: "to", type: "address" },
        { name: "amount", type: "uint256" },
        { name: "relayer", type: "address" },
        { name: "relayerFee", type: "uint256" },
        { name: "protocolFee", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    },
    message: intent,
  };
}

/** Pick the withdrawal path the app should use for an asset. See docs/withdrawals.md. */
export function withdrawalPath(asset: { isEth: boolean; supportsPermit: boolean }): "A-sweepETH" | "B-permit" | "C-topup" {
  if (asset.isEth) return "A-sweepETH";
  return asset.supportsPermit ? "B-permit" : "C-topup";
}
