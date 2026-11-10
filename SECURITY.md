# Security policy

## Status

Everything in this repository is **pre-audit and not deployed**. There is no bug bounty yet; one will be announced with the Phase 1 deployment.

## Reporting a vulnerability

- Do **not** open a public issue for security problems.
- Use GitHub's **private vulnerability reporting** on this repository (Security → Report a vulnerability), or DM [@sepia_rbh](https://x.com/sepia_rbh) asking for a secure channel.
- Include: affected file and function, impact, and steps to reproduce (a Foundry test is ideal).

We aim to acknowledge reports within 72 hours.

## Scope

| In scope | Out of scope |
| --- | --- |
| `contracts/src/**` | Third-party contracts (Pons, DEXes, USDC) |
| `sdk/src/**` (key derivation, stealth math, metadata) | The website's marketing pages |
| Relayer API design in `relayer/` | Social engineering, phishing of users |

## Known design trade-offs (not vulnerabilities)

- Tier passes let the relayer operator link a main wallet to discounted withdrawals at issuance time. Documented in [docs/privacy-model.md](docs/privacy-model.md#tier-passes); optional for users.
- Path C gas top-ups can be taken without a follow-up sweep. Bounded by per-quote caps and rate limits.
- Payer address, amount and time are public by design.

## Scam warning

The only `$SEPIA` contract address is the one on the official website and on @sepia_rbh. Sepia will never DM you an address, run a presale, or ask for a seed phrase or the Sepia key signature outside the official site.
