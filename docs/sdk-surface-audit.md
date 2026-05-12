# SDK Surface Audit

This is a last-pass audit of `whop_mock` against the published `whop_sdk` resource surface that is most relevant to the current repo.

Audit basis:

- published gem: `whop_sdk 0.0.38`
- current mock verification:
  - `spec/whop_mock_spec.rb`
  - `spec/whop_sdk_integration_spec.rb`
  - `spec/stress/speckel_style_stress_spec.rb`

This audit is intentionally blunt. It separates:

- resources/methods we actively cover
- resources/methods that exist in the SDK but are currently out of scope
- the highest-value remaining parity gaps inside the billing-focused surface

## Current Billing-Focused Coverage

The current mock is strongest on the billing-heavy surface the customer is most likely to care about:

- `account_links`
- `companies`
- `checkout_configurations`
- `dispute_alerts`
- `disputes`
- `fee_markups`
- `ledger_accounts`
- `members`
- `products`
- `plans`
- `memberships`
- `payment_methods`
- `payout_accounts`
- `payout_methods`
- `payments`
- `invoices`
- `promo_codes`
- `refunds`
- `setup_intents`
- `transfers`
- `topups`
- `webhooks`
- `withdrawals`

For those resources, the mock now covers:

- real `WhopSDK::Client` interception
- stateful create/retrieve/update/list/action behavior where those SDK methods exist
- list/filter support for the higher-value billing params we modeled
- create/update/action validation on the highest-risk billing paths
- webhook fabrication/signing and real SDK `unwrap`
- multi-step adversarial flows through the billing graph

## Published SDK Resources Observed

These resource accessors exist on `WhopSDK::Client` in `0.0.38`:

- `account_links`
- `affiliates`
- `apps`
- `chat_channels`
- `companies`
- `checkout_configurations`
- `dispute_alerts`
- `disputes`
- `fee_markups`
- `invoices`
- `ledger_accounts`
- `memberships`
- `payment_methods`
- `payments`
- `plans`
- `promo_codes`
- `products`
- `refunds`
- `setup_intents`
- `topups`
- `webhooks`

There are many more SDK client accessors beyond those, but these were the resource families inspected directly for public method surface in this audit.

## Public Methods Observed

### Covered now

- `account_links`: `create`
- `companies`: `create`, `list`, `retrieve`, `update`
- `checkout_configurations`: `create`, `list`, `retrieve`
- `dispute_alerts`: `list`, `retrieve`
- `disputes`: `list`, `retrieve`, `submit_evidence`, `update_evidence`
- `fee_markups`: `create`, `list`, `delete`
- `invoices`: `create`, `delete`, `list`, `mark_paid`, `mark_uncollectible`, `retrieve`, `update`, `void`
- `ledger_accounts`: `retrieve`
- `members`: `list`, `retrieve`
- `memberships`: `add_free_days`, `cancel`, `list`, `pause`, `resume`, `retrieve`, `uncancel`, `update`
- `payment_methods`: `list`, `retrieve`
- `payout_accounts`: `retrieve`
- `payout_methods`: `list`, `retrieve`
- `payments`: `create`, `list`, `list_fees`, `refund`, `retrieve`, `retry_`, `void`
- `plans`: `create`, `delete`, `list`, `retrieve`, `update`
- `promo_codes`: `create`, `delete`, `list`, `retrieve`
- `products`: `create`, `delete`, `list`, `retrieve`, `update`
- `refunds`: `list`, `retrieve`
- `setup_intents`: `list`, `retrieve`
- `topups`: `create`
- `transfers`: `create`, `list`, `retrieve`
- `webhooks`: `create`, `delete`, `list`, `retrieve`, `unwrap`, `update`
- `withdrawals`: `create`, `list`, `retrieve`

### Not currently covered

- `affiliates`: `archive`, `create`, `list`, `overrides`, `retrieve`, `unarchive`
- `apps`: `create`, `list`, `retrieve`, `update`
- `chat_channels`: `list`, `retrieve`, `update`
- `users`: `check_access`, `list`, `retrieve`, `update`

## What This Means

The mock should still not be described as broad SDK parity.

The more accurate description is:

- strong parity on the billing-oriented and payout-adjacent subset we intentionally targeted
- limited or no parity on adjacent product/application/chat/affiliate/user resource families
- no mock-only Stripe-shaped resource surfaces carried as SDK parity

That is not a flaw in the architecture. It is a scope fact.

## Highest-Value Remaining Gaps Inside The Covered Surface

Even within the covered billing subset, these are the biggest remaining realism gaps:

### 1. Request validation is still targeted, not schema-wide

We validate many important billing create/update/action paths, but we do not enforce:

- general schema-wide required-field checks
- broad enum validation
- broad nested object validation
- automatic unknown-field rejection

### 2. Filter parity is still selective

We now support the important billing filters we implemented, but not exhaustive SDK list-param parity across every supported resource.

### 3. Webhook convenience names exceed typed SDK union coverage

Some fabricated convenience events are useful for tests but do not map to typed SDK webhook models.

Examples:

- `payment.refunded`
- `payment.voided`
- `invoice.marked_paid`

In those cases, the mock can still fabricate realistic payloads, but callers should not expect a dedicated typed `WhopSDK::Models::*WebhookEvent` class to exist unless the SDK actually exposes one.

### 4. Lifecycle behavior is still modeled, not upstream-proven

The payment/invoice/membership coupling is coherent and much stronger than earlier revisions, but it is still an inferred system.

## If We Wanted One More Parity Push

The next most sensible expansions would be:

1. strict schema-derived validation across the covered billing subset
2. broader list-param parity for covered billing resources
3. optional expansion into one adjacent SDK family only if customer evidence justifies it:
   - `affiliates` if partnership/commission tests matter
   - `apps` if internal app provisioning is part of the migration
   - `users` if first-class identity-management flows become part of the migration
   - `chat_channels` only if customer workflows touch chat state

## Recommendation

For the current customer problem, the repo should continue to present itself as:

- a stateful billing-focused Whop mock
- verified against the published Ruby SDK on the billing graph
- not yet a whole-SDK mock replacement

That is the honest positioning and it matches the current implementation much better than “full SDK parity”.
