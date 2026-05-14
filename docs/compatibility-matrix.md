# Compatibility Matrix

This repo is currently verified against the following environment:

| Component | Version | Status |
| --- | --- | --- |
| Ruby | `3.4.5` | Verified in local test suite |
| `whop_sdk` | `0.0.38` | Verified in real `WhopSDK::Client` integration tests |

## Verified Command

```bash
mise exec ruby@3.4.5 -- bundle exec rspec
```

## Scope Of That Verification

The verification above covers:

- billing-oriented resources:
  - `companies`
  - `members`
  - `memberships`
  - `payment_methods`
  - `payments`
  - `invoices`
  - `refunds`
  - `setup_intents`
  - `webhooks`
- payout-adjacent resources:
  - `payout_accounts`
  - `payout_methods`
  - `transfers`
  - `withdrawals`

It does not imply full published SDK parity.

For the current covered vs uncovered SDK surface, see:

- [Coverage Matrix](coverage-matrix.md)

## Upgrade Guidance

If you move the SDK or Ruby version forward:

1. run the full suite
2. review [Coverage Matrix](coverage-matrix.md)
3. re-check webhook unwrap behavior and any typed webhook model assumptions
