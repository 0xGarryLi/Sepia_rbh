# Contributing

Thanks for looking. Sepia is early, so the most useful contributions right now are reviews of the protocol docs and the contracts.

1. Open an issue before large changes, so we can agree on the approach.
2. Contracts: `cd contracts && forge fmt && forge test`. New behaviour needs a test.
3. SDK: `cd sdk && npm test`. Keep zero runtime dependencies beyond `@noble/*`.
4. Docs: plain language, short sentences, real numbers. If a design choice has a privacy cost, say so in `docs/privacy-model.md`.
5. Security issues go through [SECURITY.md](SECURITY.md), not public issues.

By contributing you agree your work is released under the MIT license.
