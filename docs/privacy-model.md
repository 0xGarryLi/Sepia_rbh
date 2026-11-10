# Privacy model

Sepia hides **who received a payment**. It does not hide that a payment happened, how much it was, or who sent it. This page lists exactly what an observer can and cannot learn, so users can make informed choices.

## What is hidden

| Fact | Hidden from the public? |
| --- | --- |
| That the one-time address belongs to you | **Yes**, without your viewing key |
| That two payments went to the same person | **Yes**, every payment uses a fresh address |
| Your main wallet's balance and history | **Yes**, as long as you never link it (see below) |

## What is visible

| Fact | Visible to | Notes |
| --- | --- | --- |
| The payer's address | Everyone | Sepia protects recipients. A payer who wants privacy should pay from a fresh address too. |
| Amount and token | Everyone | Visible in the transfer and in the announcement metadata. |
| Time of payment | Everyone | Block timestamp. |
| That the payment used Sepia | Everyone | It goes through `SepiaRouter` and emits an announcement. |
| Your payments | Anyone holding your viewing key | Share it only with people you would show your statement to. |

## How privacy gets lost, and how the app prevents it

**1. Funding the one-time address from your main wallet.**
The classic mistake. Sepia's withdrawal paths exist so you never need to do this ([withdrawals.md](withdrawals.md)).

**2. Withdrawing to your main wallet.**
This links the payment to you publicly. The app warns before you do it and suggests keeping funds in the one-time address or withdrawing to a fresh address.

**3. Amount and timing correlation.**
If you receive exactly 1,337 USDC and two minutes later your known wallet receives 1,337 USDC, the link is obvious. The app suggests waiting and splitting withdrawals, and never batches your own withdrawals into a pattern.

**4. Consolidating many one-time addresses into one.**
Sweeping ten payments into one address in a burst links them to each other. The app spaces out sweeps and shows a warning when you consolidate.

**5. Network-level metadata.**
Your IP address is visible to the RPC provider, the indexer and the relayer you talk to. Use a VPN or Tor if that matters to you. Sepia's services do not log IP addresses beyond short-lived rate limiting.

## Tier passes

Discounts depend on how much `$SEPIA` you hold. Your one-time addresses hold no `$SEPIA`, so the relayer has to learn your tier some other way. In Phase 1 and 2 this works like this:

1. Your **main wallet** signs a short message once a day.
2. The relayer checks its `$SEPIA` balance and returns a **tier pass**: a signed token saying "tier Cloud, valid 24 h", with **no address inside**.
3. You attach the pass to withdrawal quotes.

Trade-off, stated plainly: at the moment it issues the pass, **the relayer could link your main wallet to the passes it hands out**, and through them to the withdrawals that use them. The relayer does not store that link, and passes are random tokens rotated daily, but you are trusting the relayer operator on this point.

If you do not want that trust, **do not use a tier pass**. You pay the standard fee, and nothing about your main wallet ever reaches the relayer.

Phase 3 replaces the tier pass with a zero-knowledge proof of holding (prove "my balance is above X" without revealing the wallet). This is listed under research in the [roadmap](../ROADMAP.md).

## What Sepia is not

- **Not a mixer.** No contract pools users' funds; nothing is shuffled. Each payment sits in an address owned by its recipient.
- **Not anonymity for payers.** See the table above.
- **Not a way around the law.** The relayer refuses withdrawals to addresses on public sanctions lists, and users can always prove a payment by sharing their viewing key.
